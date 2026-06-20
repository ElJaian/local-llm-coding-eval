#!/usr/bin/env bash
set -uo pipefail
BENCH="$HOME/llm/infer/llama.cpp/build/bin/llama-bench"
DEST="$HOME/llm/infer/models/gemma4-coder"
echo "=== bench binary ==="; ls -la "$BENCH" 2>/dev/null || { echo "NO llama-bench in build"; exit 1; }
nvidia-smi --query-gpu=memory.free --format=csv,noheader

for q in Q6_K Q8_0; do
  echo
  echo "################## gemma4-coding-$q ##################"
  # pp512 = prompt processing 512 tok; tg128 = generation 128 tok; -fa flash attn; -ngl all on GPU
  "$BENCH" -m "$DEST/gemma4-coding-$q.gguf" -ngl 99 -fa 1 -p 512 -n 128 -r 3 2>&1
done
echo
echo "=== done ==="
