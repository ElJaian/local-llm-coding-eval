#!/usr/bin/env bash
set -uo pipefail
source "$HOME/llm/eval/.venv/bin/activate"
N="${1:-40}"
OUT="$HOME/llm/eval/humaneval_samples.jsonl"

python3 - "$N" "$OUT" <<'PY'
import sys, json, re, time, urllib.request
from evalplus.data import get_human_eval_plus
N=int(sys.argv[1]); OUT=sys.argv[2]
probs=get_human_eval_plus(); ids=list(probs)[:N]
base="http://127.0.0.1:8080"

def gen(prompt):
    msg=[{"role":"user","content":
      "Complete the following Python function. Reply with ONLY the complete, runnable "
      "function (keep the given signature and imports) inside a single ```python code block.\n\n"
      "```python\n"+prompt+"\n```"}]
    body=json.dumps({"messages":msg,"temperature":0,"top_p":1.0,
                     "max_tokens":2048,"stream":False}).encode()
    req=urllib.request.Request(base+"/v1/chat/completions",data=body,
                               headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=600) as r:
        return json.load(r)["choices"][0]["message"].get("content") or ""

def extract(txt):
    blocks=re.findall(r"```(?:python)?\s*(.*?)```", txt, re.DOTALL)
    return (max(blocks,key=len).strip() if blocks else txt.strip())

t0=time.time()
with open(OUT,"w") as f:
    for i,tid in enumerate(ids):
        try:
            code=extract(gen(probs[tid]["prompt"]))
        except Exception as e:
            code=""; print(f"  !! {tid} ERROR {e}", flush=True)
        f.write(json.dumps({"task_id":tid,"solution":code})+"\n"); f.flush()
        print(f"[{i+1}/{len(ids)}] {tid}  {len(code)}c  t={time.time()-t0:.0f}s", flush=True)
print(f"GEN_DONE {OUT}  total={time.time()-t0:.0f}s", flush=True)
PY

echo "=== EVALPLUS EVALUATE (base + plus tests) ==="
python -m evalplus.evaluate humaneval --samples "$OUT" 2>&1 | tail -n 30
echo "EVAL_DONE"
