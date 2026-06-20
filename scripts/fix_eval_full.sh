#!/usr/bin/env bash
# "Fixed" EvalPlus: full 164, self-contained prompt + retry-on-empty, official evaluate (base + plus).
set -uo pipefail
source "$HOME/llm/eval/.venv/bin/activate"
RES="$HOME/llm/eval/results/gemma4-coder"
mkdir -p "$RES"
OUT="$RES/humaneval_full_samples.jsonl"

python3 - "$OUT" <<'PY'
import sys, json, re, time, urllib.request
from evalplus.data import get_human_eval_plus
OUT=sys.argv[1]
probs=get_human_eval_plus(); ids=list(probs)
base="http://127.0.0.1:8080"

def call(prompt, strong=False):
    instr=("Complete the following Python problem. Return ONLY a single ```python code block "
           "with the COMPLETE, self-contained solution: re-state EVERY function, helper, and import "
           "shown in the snippet, and keep the given signature exactly. No prose outside the block.")
    if strong: instr += " You MUST output exactly one ```python code block."
    msg=[{"role":"user","content":instr+"\n\n```python\n"+prompt+"\n```"}]
    body=json.dumps({"messages":msg,"temperature":0,"top_p":1.0,"max_tokens":2048}).encode()
    req=urllib.request.Request(base+"/v1/chat/completions",data=body,
                               headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=600) as r:
        return json.load(r)["choices"][0]["message"].get("content") or ""

def extract(t):
    b=re.findall(r"```(?:python)?\s*(.*?)```", t, re.DOTALL)
    return (max(b,key=len).strip() if b else t.strip())

t0=time.time(); empties=0
with open(OUT,"w") as f:
    for i,tid in enumerate(ids):
        code=""
        for attempt in range(2):
            try: code=extract(call(probs[tid]["prompt"], strong=(attempt==1)))
            except Exception as e: code=""
            if code.strip(): break
        if not code.strip(): empties+=1
        f.write(json.dumps({"task_id":tid,"solution":code})+"\n"); f.flush()
        print(f"[{i+1}/{len(ids)}] {tid} {len(code)}c t={time.time()-t0:.0f}s", flush=True)
print(f"GEN_DONE total={time.time()-t0:.0f}s empties={empties}", flush=True)
PY

echo "=== EVALUATE full 164 (base + plus) ==="
python -m evalplus.evaluate humaneval --samples "$OUT" 2>&1 | tee "$RES/evalplus_full_score.txt" | tail -n 20
echo "FIX_EVAL_DONE"
