#!/usr/bin/env bash
# Polyglot py-25, 2-try, no gemma4-coder Q6 (servido via llama.cpp :8080). Head-to-head com qwen3-coder.
set -uo pipefail
source "$HOME/llm/eval/.venv/bin/activate"
BIN="$HOME/llm/infer/llama.cpp/build/bin/llama-server"
G6="$HOME/llm/infer/models/gemma4-coder/gemma4-coding-Q6_K.gguf"
POLY="$HOME/llm/eval/polyglot-benchmark/python/exercises/practice"
RES="$HOME/llm/eval/results/polyglot"; mkdir -p "$RES"
OUTRES="$RES/gemma4coder_polyglot_results.txt"
WORK="$HOME/llm/eval/polyglot-run-gemma"
N=25

pkill -9 -x llama-server 2>/dev/null; sleep 1
"$BIN" -m "$G6" -c 8192 -ngl 99 -fa 1 --no-mmap -np 1 --cache-type-k q8_0 --cache-type-v q8_0 --jinja \
  --temp 1.0 --top-p 0.95 --top-k 64 --host 127.0.0.1 --port 8080 > "$RES/gemma4coder-server.log" 2>&1 &
SV=$!

python3 - "$SV" "$POLY" "$OUTRES" "$WORK" "$N" <<'PY'
import sys, json, re, subprocess, os, glob, time, urllib.request
SV=int(sys.argv[1]); POLY=sys.argv[2]; OUTRES=sys.argv[3]; WORK=sys.argv[4]; N=int(sys.argv[5])
base="http://127.0.0.1:8080"
for i in range(420):
    try:
        with urllib.request.urlopen(base+"/health",timeout=2) as r:
            if json.load(r).get("status")=="ok": print(f"[ready {i}s]",flush=True); break
    except Exception: pass
    try: os.kill(SV,0)
    except ProcessLookupError: print("server morreu",flush=True); sys.exit(2)
    time.sleep(1)
def gen(msgs):
    body=json.dumps({"messages":msgs,"temperature":0.2,"top_p":0.95,"max_tokens":3072}).encode()
    req=urllib.request.Request(base+"/v1/chat/completions",data=body,headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=600) as r: return json.load(r)["choices"][0]["message"].get("content") or ""
def extract(t):
    b=re.findall(r"```(?:python)?\s*(.*?)```",t,re.DOTALL); return (max(b,key=len).strip() if b else t.strip())
open(OUTRES,"w").close()
exs=sorted(os.listdir(POLY))[:N]; npass=0; tot=0
for ex in exs:
    d=f"{POLY}/{ex}"
    stubs=[f for f in glob.glob(f"{d}/*.py") if not f.endswith("_test.py") and "test_utils" not in f]
    tests=glob.glob(f"{d}/*_test.py")
    if not stubs or not tests: open(OUTRES,"a").write(f"[{ex}] SKIP\n"); continue
    stub,test=stubs[0],tests[0]; tot+=1
    ed=f"{WORK}/{ex}"; subprocess.run(["rm","-rf",ed]); os.makedirs(ed,exist_ok=True)
    for f in glob.glob(f"{d}/*.py"): subprocess.run(["cp",f,ed])
    instr=open(f"{d}/.docs/instructions.md").read() if os.path.exists(f"{d}/.docs/instructions.md") else ""
    sb,tb=os.path.basename(stub),os.path.basename(test)
    msgs=[{"role":"user","content":f"{instr}\n\nComplete `{sb}`:\n```python\n{open(stub).read()}\n```\nReply with ONLY the complete `{sb}` in one ```python block. Match the exact API/exceptions the tests expect."}]
    ok=False; used=0
    for tryn in (1,2):
        used=tryn
        try: code=extract(gen(msgs))
        except Exception as e: print(f"  {ex} gen erro {e}",flush=True); break
        if not code.strip(): break
        open(f"{ed}/{sb}","w").write(code)
        try: r=subprocess.run([sys.executable,"-m","pytest","-q",tb],cwd=ed,capture_output=True,text=True,timeout=120)
        except Exception: r=None
        if r is not None and r.returncode==0: ok=True; break
        err=((r.stdout if r else "")+(r.stderr if r else ""))[-1600:]
        msgs.append({"role":"assistant","content":"```python\n"+code+"\n```"})
        msgs.append({"role":"user","content":f"Tests FAILED:\n```\n{err}\n```\nFix `{sb}`; reply ONLY the complete corrected file in one ```python block."})
    if ok: npass+=1
    open(OUTRES,"a").write(f"[{ex}] {'PASS' if ok else 'FAIL'} (try {used})\n")
    print(f"[{tot}/{N}] {ex} {'PASS' if ok else 'FAIL'} (try {used}) ({npass}/{tot})",flush=True)
open(OUTRES,"a").write(f"==== POLYGLOT (py-25, 2-try) gemma4-coder Q6: {npass}/{tot} ====\n")
print(f"POLYGLOT_GEMMA_DONE {npass}/{tot}",flush=True)
PY
kill "$SV" 2>/dev/null; sleep 2; pkill -9 -x llama-server 2>/dev/null
echo GEMMA_POLYGLOT_DONE
