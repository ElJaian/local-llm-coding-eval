#!/usr/bin/env bash
# humaneval_model.sh <gguf> <name> : sobe llama-server do modelo, gera HumanEval+ 164 (greedy),
# avalia (base+plus), derruba o server. Mesmo prompt/harness dos coders.
set -uo pipefail
GGUF="$1"; NAME="$2"; N="${3:-40}"
source "$HOME/llm/eval/.venv/bin/activate"
BIN="$HOME/llm/infer/llama.cpp/build/bin/llama-server"
RES="$HOME/llm/eval/results/humaneval-$NAME"; mkdir -p "$RES"
OUT="$RES/humaneval_full_samples.jsonl"

pkill -9 -x llama-server 2>/dev/null; sleep 1
echo "=== subindo server: $NAME ==="
"$BIN" -m "$GGUF" -c 8192 -ngl 99 -fa 1 --no-mmap -np 1 \
  --cache-type-k q8_0 --cache-type-v q8_0 --jinja \
  --host 127.0.0.1 --port 8080 > "$RES/server.log" 2>&1 &
SV=$!

python3 - "$OUT" "$SV" "$N" <<'PY'
import sys, json, re, time, urllib.request, os
OUT=sys.argv[1]; SV=int(sys.argv[2]); N=int(sys.argv[3])
from evalplus.data import get_human_eval_plus
probs=get_human_eval_plus(); ids=list(probs)[:N]
base="http://127.0.0.1:8080"
for i in range(480):
    try:
        with urllib.request.urlopen(base+"/health",timeout=2) as r:
            if json.load(r).get("status")=="ok": print(f"[ready {i}s]",flush=True); break
    except Exception: pass
    try: os.kill(SV,0)
    except ProcessLookupError: print("!! server morreu no load",flush=True); sys.exit(2)
    time.sleep(1)
def call(p,strong=False):
    instr="Complete this Python function. Reply with ONLY the completed code in a single ```python code block, no explanation."
    if strong: instr+=" Output the ```python block now."
    body=json.dumps({"messages":[{"role":"user","content":instr+"\n\n```python\n"+p+"\n```"}],
                     "temperature":0,"top_p":1.0,"max_tokens":3072}).encode()
    req=urllib.request.Request(base+"/v1/chat/completions",data=body,headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=600) as r: return json.load(r)["choices"][0]["message"].get("content") or ""
def extract(t):
    b=re.findall(r"```(?:python)?\s*(.*?)```",t,re.DOTALL); return (max(b,key=len).strip() if b else t.strip())
t0=time.time(); empties=0
with open(OUT,"w") as f:
    for i,tid in enumerate(ids):
        code=""
        for a in range(2):
            try: code=extract(call(probs[tid]["prompt"], strong=(a==1)))
            except Exception: code=""
            if code.strip(): break
        if not code.strip(): empties+=1
        f.write(json.dumps({"task_id":tid,"solution":code})+"\n"); f.flush()
        print(f"[{i+1}/{len(ids)}] {tid} {len(code)}c t={time.time()-t0:.0f}s",flush=True)
print(f"GEN_DONE empties={empties} t={time.time()-t0:.0f}s",flush=True)
PY

kill "$SV" 2>/dev/null; sleep 2; pkill -9 -x llama-server 2>/dev/null
echo "=== SCORE (base HumanEval, subset N) $NAME ==="
python3 - "$OUT" <<'PY' | tee "$RES/base_score.txt"
import sys, json, subprocess
from evalplus.data import get_human_eval_plus
d=get_human_eval_plus()
P=0; T=0; fails=[]
for line in open(sys.argv[1]):
    o=json.loads(line); tid=o["task_id"]; sol=o["solution"]; T+=1
    if not sol.strip(): fails.append((tid,"EMPTY")); continue
    p=d[tid]; prog=sol+"\n\n"+p["test"]+f"\n\ncheck({p['entry_point']})\n"
    try:
        r=subprocess.run(["python3","-c",prog], capture_output=True, timeout=15, text=True)
        if r.returncode==0: P+=1
        else: fails.append((tid,(r.stderr.strip().splitlines() or ['?'])[-1][:70]))
    except subprocess.TimeoutExpired: fails.append((tid,"TIMEOUT"))
print(f"BASE-HumanEval pass {P}/{T} = {100*P/max(T,1):.1f}%")
for tid,e in fails[:10]: print("  FAIL", tid, e)
PY
echo "HUMANEVAL_DONE_$NAME"
