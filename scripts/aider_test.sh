#!/usr/bin/env bash
# Real agent-loop test: drive aider against the local server on :8080.
set -uo pipefail
source "$HOME/llm/eval/.venv/bin/activate"
export OPENAI_API_BASE="http://127.0.0.1:8080/v1"
export OPENAI_API_KEY="sk-local"
export AIDER_CHECK_UPDATE="false"
git config --global user.email "eval@local"  >/dev/null 2>&1 || true
git config --global user.name  "eval"        >/dev/null 2>&1 || true

WORK="$HOME/llm/eval/aider_playground"
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"; git init -q

MODEL="openai/gemma4-coder"
OPTS="--model $MODEL --yes-always --no-auto-commits --no-check-update --no-stream --map-tokens 0 --no-show-model-warnings"

# ---------- TASK 1: add a function (diff/search-replace edit format) ----------
cat > mathutils.py <<'EOF'
def add(a, b):
    """Return the sum of a and b."""
    return a + b
EOF
git add -A; git commit -qm seed1
echo "########## TASK 1 (add multiply, edit-format=diff) ##########"
aider $OPTS --edit-format diff -m "Add a function multiply(a, b) that returns a*b with a one-line docstring. Keep the existing add function unchanged." mathutils.py 2>&1 | tail -n 20
echo "----- mathutils.py after -----"; cat mathutils.py
echo "----- git changed? -----"; git --no-pager diff --stat
echo "----- verify -----"
python3 -c "import importlib,mathutils; importlib.reload(mathutils); print('multiply(6,7)=',mathutils.multiply(6,7)); assert mathutils.multiply(6,7)==42 and mathutils.add(2,3)==5; print('TASK1_PASS')" 2>&1

# ---------- TASK 2: fix a bug ----------
cat > buggy.py <<'EOF'
def average(nums):
    total = 0
    for n in nums:
        total += n
    return total / len(nums)   # crashes on empty list
EOF
git add -A; git commit -qm seed2
echo "########## TASK 2 (fix empty-list bug, edit-format=diff) ##########"
aider $OPTS --edit-format diff -m "In buggy.py make average([]) return 0.0 instead of crashing on division by zero. Non-empty lists must keep returning their mean." buggy.py 2>&1 | tail -n 20
echo "----- buggy.py after -----"; cat buggy.py
echo "----- verify -----"
python3 -c "import buggy; print('avg([])=',buggy.average([]),'avg([2,4])=',buggy.average([2,4])); assert buggy.average([])==0.0 and buggy.average([2,4])==3.0; print('TASK2_PASS')" 2>&1

echo "AIDER_DONE"
