#!/usr/bin/env bash
# Aider agent-loop on qwen3-coder:30b via ollama. Same 2 tasks as gemma4.
set -uo pipefail
source "$HOME/llm/eval/.venv/bin/activate"
export OLLAMA_API_BASE="http://172.28.192.1:11434"
git config --global user.email "eval@local" >/dev/null 2>&1 || true
git config --global user.name  "eval"        >/dev/null 2>&1 || true

WORK="$HOME/llm/eval/qwen_aider_playground"
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"; git init -q

MODEL="ollama_chat/qwen3-coder:30b"
OPTS="--model $MODEL --yes-always --no-auto-commits --no-check-update --no-stream --map-tokens 0 --no-show-model-warnings"

cat > mathutils.py <<'EOF'
def add(a, b):
    """Return the sum of a and b."""
    return a + b
EOF
git add -A; git commit -qm seed1
echo "########## TASK 1 (add multiply, edit-format=diff) ##########"
aider $OPTS --edit-format diff -m "Add a function multiply(a, b) that returns a*b with a one-line docstring. Keep the existing add function unchanged." mathutils.py 2>&1 | tail -n 18
echo "----- mathutils.py after -----"; cat mathutils.py
echo "----- verify -----"
python3 -c "import mathutils; print('multiply(6,7)=',mathutils.multiply(6,7)); assert mathutils.multiply(6,7)==42 and mathutils.add(2,3)==5; print('TASK1_PASS')" 2>&1

cat > buggy.py <<'EOF'
def average(nums):
    total = 0
    for n in nums:
        total += n
    return total / len(nums)   # crashes on empty list
EOF
git add -A; git commit -qm seed2
echo "########## TASK 2 (fix empty-list bug, edit-format=diff) ##########"
aider $OPTS --edit-format diff -m "In buggy.py make average([]) return 0.0 instead of crashing on division by zero. Non-empty lists must keep returning their mean." buggy.py 2>&1 | tail -n 18
echo "----- buggy.py after -----"; cat buggy.py
echo "----- verify -----"
python3 -c "import buggy; print('avg([])=',buggy.average([]),'avg([2,4])=',buggy.average([2,4])); assert buggy.average([])==0.0 and buggy.average([2,4])==3.0; print('TASK2_PASS')" 2>&1
echo "QWEN_AIDER_DONE"
