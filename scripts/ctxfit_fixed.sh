#!/usr/bin/env bash
# Fase 2 corrigida: contexto maximo que carrega -ngl 99 (full GPU). Usa -no-cnv (sem modo interativo).
set -uo pipefail
CLI="$HOME/llm/infer/llama.cpp/build/bin/llama-cli"
OUT="$HOME/llm/eval/results/speed-context"; mkdir -p "$OUT"
GEMMA_IT=$(ls "$HOME"/.cache/huggingface/hub/models--ggml-org--gemma-4-12B-it-GGUF/snapshots/*/gemma-4-12B-it-Q4_K_M.gguf 2>/dev/null | head -1)
QWEN14=$(ls "$HOME"/.cache/huggingface/hub/models--bartowski--Qwen_Qwen3-14B-GGUF/snapshots/*/Qwen_Qwen3-14B-Q4_K_M.gguf 2>/dev/null | head -1)
G6="$HOME/llm/infer/models/gemma4-coder/gemma4-coding-Q6_K.gguf"
G8="$HOME/llm/infer/models/gemma4-coder/gemma4-coding-Q8_0.gguf"
: > "$OUT/ctxfit.txt"
ctxfit () {
  local name="$1" m="$2" best=0
  for c in 16384 32768 65536 131072 262144; do
    if timeout 200 "$CLI" -m "$m" -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -c "$c" -n 1 -p "hi" -no-cnv >/dev/null 2>&1; then
      best=$c; echo "  $name @ $c OK"
    else
      echo "  $name @ $c FALHOU (OOM ou nao coube)"; break
    fi
  done
  echo "$name: ctx maximo full-GPU = $best" | tee -a "$OUT/ctxfit.txt"
}
for pair in "gemma-4-it-Q4|$GEMMA_IT" "gemma4coder-Q6|$G6" "gemma4coder-Q8|$G8" "qwen3-14b-Q4|$QWEN14"; do
  name="${pair%%|*}"; m="${pair#*|}"
  [ -f "$m" ] && ctxfit "$name" "$m"
done
echo "CTXFIT_DONE"; cat "$OUT/ctxfit.txt"
