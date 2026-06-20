#!/usr/bin/env python3
# Polyglot (Python split) — CANONICAL 2-try protocol: gen -> pytest -> on fail, feed test
# error back -> regen -> pytest. Direct ollama API (reliable). Records pass + which try.
import json, re, subprocess, os, sys, urllib.request, glob
HOST = subprocess.run(["bash","-lc","ip route show default|awk '{print $3}'|head -1"],
                      capture_output=True, text=True).stdout.strip() or "127.0.0.1"
POLY = "/home/dev/llm/eval/polyglot-benchmark/python/exercises/practice"
RES  = "/home/dev/llm/eval/results/polyglot"; os.makedirs(RES, exist_ok=True)
WORK = "/home/dev/llm/eval/polyglot-run2"
RESULTS = f"{RES}/qwen_polyglot_results.txt"   # mesmo arquivo (dashboard le isso)
N = int(sys.argv[1]) if len(sys.argv) > 1 else 25
MODEL = "qwen3-coder:30b"

def gen(messages):
    body = json.dumps({"model":MODEL,"messages":messages,"stream":False,
                       "options":{"temperature":0.2,"num_ctx":8192,"num_predict":3072}}).encode()
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
    sb, tb = os.path.basename(stub), os.path.basename(test)
    msgs = [{"role":"user","content":
             f"{instr}\n\nComplete the file `{sb}`:\n```python\n{open(stub).read()}\n```\n"
             f"Reply with ONLY the complete `{sb}` (entire file) in one ```python code block. "
             f"Match the exact API/exceptions the tests expect."}]
    ok = False; used = 0
    for tryn in (1, 2):
        used = tryn
        try:
            code = extract(gen(msgs))
        except Exception as e:
            print(f"   {ex} gen erro: {e}", flush=True); break
        if not code.strip(): break
        open(f"{ed}/{sb}","w").write(code)
        try:
            r = subprocess.run([sys.executable,"-m","pytest","-q",tb], cwd=ed,
                               capture_output=True, text=True, timeout=120)
        except Exception:
            r = None
        if r is not None and r.returncode == 0:
            ok = True; break
        # feedback p/ try 2
        err = ((r.stdout if r else "") + (r.stderr if r else ""))[-1600:]
        msgs.append({"role":"assistant","content":"```python\n"+code+"\n```"})
        msgs.append({"role":"user","content":
                     f"Those tests FAILED:\n```\n{err}\n```\nFix `{sb}` to pass all tests. "
                     f"Reply with ONLY the complete corrected `{sb}` in one ```python block."})
    if ok: npass += 1
    open(RESULTS,"a").write(f"[{ex}] {'PASS' if ok else 'FAIL'} (try {used})\n")
    print(f"[{tot}/{N}] {ex} {'PASS' if ok else 'FAIL'} (try {used})  ({npass}/{tot})", flush=True)
open(RESULTS,"a").write(f"==== POLYGLOT (python split, 2-try w/ test-feedback, temp 0.2) qwen3-coder:30b: {npass}/{tot} ====\n")
print(f"POLYGLOT_DONE {npass}/{tot}", flush=True)
