#!/usr/bin/env bash
# Aider polyglot — PYTHON split subset — on qwen3-coder:30b via ollama.
# Drives aider (diff/search-replace) on each exercise, runs pytest, up to 2 tries.
set -uo pipefail
source "$HOME/llm/eval/.venv/bin/activate"
HOST=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1)
export OLLAMA_API_BASE="http://$HOST:11434"
git config --global user.email "eval@local" >/dev/null 2>&1 || true
git config --global user.name  "eval"        >/dev/null 2>&1 || true
python -c "import pytest" 2>/dev/null || uv pip install -q pytest 2>/dev/null || true

POLY="$HOME/llm/eval/polyglot-benchmark/python/exercises/practice"
WORK="$HOME/llm/eval/polyglot-run"; rm -rf "$WORK"; mkdir -p "$WORK"
RES="$HOME/llm/eval/results/polyglot"; mkdir -p "$RES"
MODEL="ollama_chat/qwen3-coder:30b"
N="${1:-25}"; TRIES=2
LOG="$RES/qwen_polyglot_results.txt"; : > "$LOG"

pass=0; total=0
for ex in $(ls "$POLY" | head -n "$N"); do
  d="$POLY/$ex"
  stub=$(ls "$d"/*.py 2>/dev/null | grep -v '_test.py' | grep -v 'test_utils' | head -1)
  test=$(ls "$d"/*_test.py 2>/dev/null | head -1)
  [ -z "$stub" ] || [ -z "$test" ] && { echo "[$ex] SKIP (no stub/test)" | tee -a "$LOG"; continue; }
  total=$((total+1))
  ed="$WORK/$ex"; rm -rf "$ed"; mkdir -p "$ed"
  cp "$d"/*.py "$ed"/ 2>/dev/null; [ -d "$d/.docs" ] && cp -r "$d/.docs" "$ed/" 2>/dev/null
  ( cd "$ed" && git init -q && git add -A && git commit -qm seed >/dev/null 2>&1 )
  sb=$(basename "$stub"); tb=$(basename "$test")
  prompt="$(cat "$d/.docs/instructions.md" 2>/dev/null)

Implement the solution in $sb so that ALL tests in $tb pass. Do not modify the test file."
  ok=0; used=0
  for try in $(seq 1 $TRIES); do
    used=$try
    ( cd "$ed" && timeout 600 aider --model "$MODEL" --yes-always --no-auto-commits \
        --no-check-update --no-stream --map-tokens 0 --no-show-model-warnings \
        --edit-format diff -m "$prompt" "$sb" >/dev/null 2>&1 )
    if ( cd "$ed" && timeout 120 python -m pytest -q "$tb" >/dev/null 2>&1 ); then ok=1; break; fi
    prompt="The tests still fail. Fix $sb so every test in $tb passes. Do not modify the test file."
  done
  if [ "$ok" = 1 ]; then pass=$((pass+1)); echo "[$ex] PASS (try $used)" | tee -a "$LOG"; else echo "[$ex] FAIL" | tee -a "$LOG"; fi
done
echo "==== POLYGLOT (python subset, 2 tries) qwen3-coder:30b: $pass/$total ====" | tee -a "$LOG"
echo "POLYGLOT_DONE $pass/$total"
