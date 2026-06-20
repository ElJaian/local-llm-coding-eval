#!/usr/bin/env bash
# runtest.sh <gguf-path> <ngl: 99|auto> <ctx>
set -uo pipefail
GGUF="$1"; NGL="${2:-99}"; CTX="${3:-8192}"
PORT=8090
BIN="$HOME/llm/infer/llama.cpp/build/bin/llama-server"
LOG="$HOME/gemma4-test.log"
source "$HOME/llm/infer/.venv/bin/activate" 2>/dev/null || true

echo "=== VRAM free before ==="; nvidia-smi --query-gpu=memory.free --format=csv,noheader

NGL_ARGS=(-ngl 99)
[ "$NGL" = "auto" ] && NGL_ARGS=()   # omit -ngl => llama.cpp auto-fit offloads spillover to RAM

echo "=== launch: $(basename "$GGUF")  ngl=$NGL  ctx=$CTX ==="
"$BIN" -m "$GGUF" -c "$CTX" "${NGL_ARGS[@]}" -fa 1 --no-mmap -np 1 \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --temp 1.0 --top-p 0.95 --top-k 64 \
  --jinja --host 127.0.0.1 --port "$PORT" > "$LOG" 2>&1 &
SVPID=$!
echo "server pid=$SVPID"

python - "$PORT" "$SVPID" <<'PY'
import sys, json, time, urllib.request, urllib.error, os, signal
port, svpid = sys.argv[1], int(sys.argv[2])
base=f"http://127.0.0.1:{port}"
# poll health (model loads from HDD, allow generous time)
ready=False
for i in range(420):
    try:
        with urllib.request.urlopen(base+"/health", timeout=2) as r:
            if json.load(r).get("status")=="ok":
                print(f"[ready after ~{i}s]"); ready=True; break
    except Exception:
        pass
    try: os.kill(svpid,0)
    except ProcessLookupError:
        print("!! server process died during load"); break
    time.sleep(1)
if not ready:
    print("!! server not ready (timeout/death)"); sys.exit(2)

prompt=("Write a Python function `longest_palindromic_substring(s: str) -> str` "
        "that returns the longest palindromic substring of s. Then state its time "
        "and space complexity in one line.")
body=json.dumps({"messages":[{"role":"user","content":prompt}],
                 "temperature":1.0,"top_p":0.95,"top_k":64,
                 "max_tokens":1200,"stream":False}).encode()
req=urllib.request.Request(base+"/v1/chat/completions",data=body,
                           headers={"Content-Type":"application/json"})
t=time.time()
try:
    with urllib.request.urlopen(req,timeout=600) as r:
        resp=json.load(r)
except urllib.error.HTTPError as e:
    print("HTTP",e.code,e.read().decode()[:800]); sys.exit(3)
dt=time.time()-t
msg=resp["choices"][0]["message"]
rc=msg.get("reasoning_content")
print("\n===== REASONING (thought channel) =====")
print((rc or "(none returned in reasoning_content — may be inline in content)")[:1800])
print("\n===== ANSWER (content) =====")
print((msg.get("content") or "")[:2200])
print("\n===== usage =====", resp.get("usage"), f"| wall={dt:.1f}s")
PY

echo "=== server timing (from log) ==="
grep -E "prompt eval time|eval time|tokens per second|n_ctx|offloaded|CUDA0 model buffer" "$LOG" | tail -n 10
echo "=== shutdown ==="
kill "$SVPID" 2>/dev/null; sleep 2
echo "done."
