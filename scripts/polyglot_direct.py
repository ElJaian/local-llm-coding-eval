#!/usr/bin/env python3
# Polyglot (Python split) via DIRECT ollama generation (no aider reflection loop).
# For each exercise: gen full solution -> write file -> pytest. Reliable + bounded.
import json, re, subprocess, os, sys, urllib.request, glob
HOST = subprocess.run(["bash","-lc","ip route show default|awk '{print $3}'|head -1"],
                      capture_output=True, text=True).stdout.strip() or "127.0.0.1"
POLY = "/home/dev/llm/eval/polyglot-benchmark/python/exercises/practice"
RES  = "/home/dev/llm/eval/results/polyglot"; os.makedirs(RES, exist_ok=True)
WORK = "/home/dev/llm/eval/polyglot-run"
RESULTS = f"{RES}/qwen_polyglot_results.txt"
N = int(sys.argv[1]) if len(sys.argv) > 1 else 25
MODEL = "qwen3-coder:30b"

def gen(prompt):
    body = json.dumps({"model":MODEL,"messages":[{"role":"user","content":prompt}],
                       "stream":False,"options":{"temperature":0.2,"num_ctx":8192,"num_predict":2048}}).encode()
    req = urllib.request.Request(f"http://{HOST}:11434/v1/chat/completions", data=body,
                                 headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)["choices"][0]["message"].get("content") or ""

def extract(t):
    b = re.findall(r"```(?:python)?\s*(.*?)```", t, re.DOTALL)
    return (max(b, key=len).strip() if b else t.strip())

open(RESULTS, "w").close()
exs = sorted(os.listdir(POLY))[:N]
npass = 0; tot = 0
for ex in exs:
    d = f"{POLY}/{ex}"
    stubs = [f for f in glob.glob(f"{d}/*.py") if not f.endswith("_test.py") and "test_utils" not in f]
    tests = glob.glob(f"{d}/*_test.py")
    if not stubs or not tests:
        open(RESULTS,"a").write(f"[{ex}] SKIP\n"); print(f"[{ex}] SKIP", flush=True); continue
    stub, test = stubs[0], tests[0]; tot += 1
    ed = f"{WORK}/{ex}"; subprocess.run(["rm","-rf",ed]); os.makedirs(ed, exist_ok=True)
    for f in glob.glob(f"{d}/*.py"): subprocess.run(["cp",f,ed])
    instr = open(f"{d}/.docs/instructions.md").read() if os.path.exists(f"{d}/.docs/instructions.md") else ""
    sb = os.path.basename(stub)
    prompt = (f"{instr}\n\nHere is the file `{sb}` to complete:\n```python\n{open(stub).read()}\n```\n"
              f"Reply with ONLY the complete `{sb}` (the entire file) in a single ```python code block. "
              f"Implement it so all tests pass.")
    ok = False
    try:
        code = extract(gen(prompt))
        if code.strip():
            open(f"{ed}/{sb}","w").write(code)
            r = subprocess.run([sys.executable,"-m","pytest","-q",os.path.basename(test)],
                               cwd=ed, capture_output=True, timeout=120)
            ok = (r.returncode == 0)
    except Exception as e:
        print(f"   {ex} erro: {e}", flush=True)
    if ok: npass += 1
    open(RESULTS,"a").write(f"[{ex}] {'PASS' if ok else 'FAIL'}\n")
    print(f"[{tot}/{N}] {ex} {'PASS' if ok else 'FAIL'}  ({npass}/{tot})", flush=True)
open(RESULTS,"a").write(f"==== POLYGLOT (python split, direct-gen, temp 0.2) qwen3-coder:30b: {npass}/{tot} ====\n")
print(f"POLYGLOT_DONE {npass}/{tot}", flush=True)
