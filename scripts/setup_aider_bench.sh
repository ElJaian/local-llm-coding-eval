#!/usr/bin/env bash
set -uo pipefail
cd "$HOME/llm/eval"
if [ ! -d aider-src ]; then
  echo "=== clonando Aider-AI/aider (fonte, p/ benchmark.py) ==="
  git clone --depth 1 https://github.com/Aider-AI/aider aider-src 2>&1 | tail -3
fi
echo "=== benchmark/ existe? ==="
ls "$HOME/llm/eval/aider-src/benchmark/" 2>/dev/null | head
echo
echo "=== benchmark/README (uso, primeiras linhas) ==="
sed -n '1,60p' "$HOME/llm/eval/aider-src/benchmark/README.md" 2>/dev/null
echo
echo "=== args do benchmark.py (grep) ==="
grep -nE "add_argument|typer|def main|exercises|num.?tests|edit.?format|languages|--model" "$HOME/llm/eval/aider-src/benchmark/benchmark.py" 2>/dev/null | head -40
