#!/usr/bin/env bash
set -uo pipefail
source "$HOME/llm/eval/.venv/bin/activate"
python3 <<'PY'
import json, subprocess, os
from evalplus.data import get_human_eval_plus
d=get_human_eval_plus()
samples={}
for line in open(os.path.expanduser("~/llm/eval/humaneval_samples.jsonl")):
    o=json.loads(line); samples[o["task_id"]]=o["solution"]
passed=[]; failed=[]
for tid,sol in samples.items():
    p=d[tid]
    prog = sol + "\n\n" + p["test"] + f"\n\ncheck({p['entry_point']})\n"
    if not sol.strip():
        failed.append((tid,"EMPTY (no code block returned)")); continue
    try:
        r=subprocess.run(["python3","-c",prog],capture_output=True,timeout=15,text=True)
        if r.returncode==0: passed.append(tid)
        else:
            last=(r.stderr.strip().splitlines() or ['?'])[-1][:90]
            failed.append((tid,last))
    except subprocess.TimeoutExpired:
        failed.append((tid,"TIMEOUT (likely infinite loop)"))
n=len(samples)
print(f"\n==== BASE HumanEval pass@1 (greedy): {len(passed)}/{n} = {100*len(passed)/n:.1f}%  [40-problem subset] ====")
print("\nFAILURES:")
for tid,err in failed: print(f"  {tid:16s} {err}")
PY
