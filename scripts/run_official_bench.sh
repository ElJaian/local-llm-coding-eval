#!/usr/bin/env bash
# Aider polyglot OFICIAL. args: <run-name> <num-tests> <model> <edit-format>
set -uo pipefail
A="$HOME/llm/eval/aider-src"
PY="$HOME/llm/eval/.venv/bin/python"
RUN="${1:-qwen3coder-val}"; N="${2:-2}"; MODEL="${3:-ollama_chat/qwen3-coder:30b}"; EF="${4:-whole}"
export OLLAMA_API_BASE="http://$(ip route show default 2>/dev/null | awk '{print $3}' | head -1):11434"
export OPENAI_API_BASE="http://127.0.0.1:8080/v1"  # p/ caso de modelo via llama-server
export OPENAI_API_KEY="sk-local"
export AIDER_CHECK_UPDATE=false
export AIDER_DOCKER=1   # bypassa o gate de docker (host run; exercicios benignos, WSL)
source "$HOME/llm/eval/.venv/bin/activate"   # poe 'pytest' no PATH (o runner chama pytest direto)
cd "$A"
echo "RUN=$RUN N=$N MODEL=$MODEL EF=$EF OLLAMA_API_BASE=$OLLAMA_API_BASE"
"$PY" benchmark/benchmark.py "$RUN" \
  --model "$MODEL" --edit-format "$EF" --languages python \
  --num-tests "$N" --tries 2 --threads 1 --new 2>&1 | tail -50
echo "OFFICIAL_BENCH_DONE $RUN"
