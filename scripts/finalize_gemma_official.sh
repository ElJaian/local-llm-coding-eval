#!/usr/bin/env bash
# gemma4-coder Q6 via llama-server + Aider polyglot oficial (full Python, whole, 2-try).
set -uo pipefail
BIN="$HOME/llm/infer/llama.cpp/build/bin/llama-server"
G6="$HOME/llm/infer/models/gemma4-coder/gemma4-coding-Q6_K.gguf"
RB="/mnt/c/Users/jeanc/AppData/Local/Temp/claude/D--Repositories-local-llm-local-llm-inference-and-small-model-training-with-maximum-efficiency/78b584a8-a419-4099-890b-8ca48d421b2b/scratchpad/run_official_bench.sh"
pkill -9 -x llama-server 2>/dev/null; sleep 1
"$BIN" -m "$G6" -c 8192 -ngl 99 -fa 1 --no-mmap -np 1 --cache-type-k q8_0 --cache-type-v q8_0 --jinja \
  --temp 1.0 --top-p 0.95 --top-k 64 --host 127.0.0.1 --port 8080 > /home/dev/g6-bench-server.log 2>&1 &
SV=$!
echo "esperando server gemma4-coder..."
for i in $(seq 1 300); do
  if curl -s http://127.0.0.1:8080/health 2>/dev/null | grep -q '"status":"ok"'; then echo "ready ${i}s"; break; fi
  if ! kill -0 "$SV" 2>/dev/null; then echo "server morreu"; tail -5 /home/dev/g6-bench-server.log; exit 2; fi
  sleep 1
done
bash "$RB" "gemma4coder-poly-full" 34 "openai/gemma4-coder" "whole"
kill "$SV" 2>/dev/null; sleep 2; pkill -9 -x llama-server 2>/dev/null
echo "GEMMA_OFFICIAL_DONE"
