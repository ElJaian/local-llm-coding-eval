#!/usr/bin/env bash
# Fase 1+2 do lote noturno: velocidade + prompt-processing + scaling de contexto
# + contexto máximo que cabe em 16GB. Roda os 5 modelos locais. NÃO usa download.
set -uo pipefail
BIN="$HOME/llm/infer/llama.cpp/build/bin/llama-bench"
CLI="$HOME/llm/infer/llama.cpp/build/bin/llama-cli"
OUT="$HOME/llm/eval/results/speed-context"; mkdir -p "$OUT"
OLLAMA_HOST=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1)
echo "ollama host (auto): $OLLAMA_HOST"

GEMMA_IT=$(ls "$HOME"/.cache/huggingface/hub/models--ggml-org--gemma-4-12B-it-GGUF/snapshots/*/gemma-4-12B-it-Q4_K_M.gguf 2>/dev/null | head -1)
QWEN14=$(ls "$HOME"/.cache/huggingface/hub/models--bartowski--Qwen_Qwen3-14B-GGUF/snapshots/*/Qwen_Qwen3-14B-Q4_K_M.gguf 2>/dev/null | head -1)
G6="$HOME/llm/infer/models/gemma4-coder/gemma4-coding-Q6_K.gguf"
G8="$HOME/llm/infer/models/gemma4-coder/gemma4-coding-Q8_0.gguf"

echo "===== FASE 1: llama-bench (pp512, pp2048, tg128 @ depth 0/4K/16K/32K) ====="
run_bench () {
  local name="$1" m="$2"
  echo "######## $name :: $m :: $(date +%H:%M:%S) ########" | tee -a "$OUT/table.txt"
  "$BIN" -m "$m" -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 \
     -p 512 -p 2048 -n 128 -d 0,4096,16384,32768 -r 3 -o json > "$OUT/$name.json" 2> "$OUT/$name.err" || true
  echo "  -> $name.json ($(wc -c < "$OUT/$name.json" 2>/dev/null) bytes) | errtail: $(tail -1 "$OUT/$name.err" 2>/dev/null)" | tee -a "$OUT/table.txt"
}
for pair in "gemma-4-it-Q4|$GEMMA_IT" "gemma4coder-Q6|$G6" "gemma4coder-Q8|$G8" "qwen3-14b-Q4|$QWEN14"; do
  name="${pair%%|*}"; m="${pair#*|}"
  if [ -f "$m" ]; then run_bench "$name" "$m"; else echo "SKIP $name (nao achei: $m)" | tee -a "$OUT/table.txt"; fi
done

echo "===== FASE 1b: qwen3-coder-30B via ollama (sweep num_ctx) ====="
for ctx in 4096 16384 32768; do
  python3 - "$ctx" "$OLLAMA_HOST" <<'PY' | tee -a "$OUT/table.txt"
import sys,json,urllib.request
ctx=int(sys.argv[1]); host=sys.argv[2]
body=json.dumps({"model":"qwen3-coder:30b",
  "prompt":"Write a Python function to merge two sorted lists efficiently, with a docstring.",
  "stream":False,"options":{"num_ctx":ctx,"num_predict":256}}).encode()
req=urllib.request.Request(f"http://{host}:11434/api/generate",data=body,
                           headers={"Content-Type":"application/json"})
try:
  with urllib.request.urlopen(req,timeout=900) as r: d=json.load(r)
  ec=d.get("eval_count",0); ed=d.get("eval_duration",1) or 1
  print(f"qwen3-coder-30B num_ctx={ctx}: tg={ec/(ed/1e9):.1f} t/s ({ec} tok)")
except Exception as e:
  print(f"qwen3-coder-30B num_ctx={ctx}: ERRO {e}")
PY
done

echo "===== FASE 2: contexto maximo que cabe (-ngl 99, full GPU) ====="
ctxfit () {
  local name="$1" m="$2" best=0
  for c in 16384 32768 65536 131072 262144; do
    if timeout 240 "$CLI" -m "$m" -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -c "$c" -n 1 -p "hi" >/dev/null 2>&1; then best=$c; else break; fi
  done
  echo "$name: ctx maximo full-GPU = $best" | tee -a "$OUT/ctxfit.txt"
}
for pair in "gemma-4-it-Q4|$GEMMA_IT" "gemma4coder-Q6|$G6" "gemma4coder-Q8|$G8" "qwen3-14b-Q4|$QWEN14"; do
  name="${pair%%|*}"; m="${pair#*|}"
  [ -f "$m" ] && ctxfit "$name" "$m"
done
echo "BENCH_SPEED_CONTEXT_DONE"
cat "$OUT/ctxfit.txt" 2>/dev/null
