#!/usr/bin/env bash
set -uo pipefail
A="$HOME/llm/eval/aider-src"
PY="$HOME/llm/eval/.venv/bin/python"
mkdir -p "$A/tmp.benchmarks"
[ -e "$A/tmp.benchmarks/polyglot-benchmark" ] || ln -s "$HOME/llm/eval/polyglot-benchmark" "$A/tmp.benchmarks/polyglot-benchmark"
echo "=== exercicios python linkados ==="; ls "$A/tmp.benchmarks/polyglot-benchmark/python/exercises/practice" 2>/dev/null | wc -l
echo "=== EXERCISES_DIR_DEFAULT ==="; grep -n "EXERCISES_DIR_DEFAULT *=" "$A/benchmark/benchmark.py" | head
echo "=== requirements do benchmark ==="; ls "$A/benchmark/"*.txt 2>/dev/null; head -20 "$A/benchmark/requirements.txt" 2>/dev/null
echo "=== instalando deps na eval venv ==="
uv pip install --python "$PY" -q typer pandas matplotlib lox imgcat 2>&1 | tail -4
echo "=== benchmark.py --help ==="
cd "$A" && "$PY" benchmark/benchmark.py --help 2>&1 | head -25
