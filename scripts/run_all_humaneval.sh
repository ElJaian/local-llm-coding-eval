#!/usr/bin/env bash
# Roda HumanEval (base, N=40, prompt simples) em 3 modelos via mesmo harness, sequencial.
set -uo pipefail
# limpa qualquer run anterior (seguro: este script eh run_all_*, nao humaneval_model)
pkill -9 -f humaneval_model.sh 2>/dev/null
pkill -9 -x llama-server 2>/dev/null
sleep 3
HM="/mnt/c/Users/jeanc/AppData/Local/Temp/claude/D--Repositories-local-llm-local-llm-inference-and-small-model-training-with-maximum-efficiency/78b584a8-a419-4099-890b-8ca48d421b2b/scratchpad/humaneval_model.sh"
GIT="/home/dev/.cache/huggingface/hub/models--ggml-org--gemma-4-12B-it-GGUF/snapshots/44ee90c4b61e888ac5b318a54ec7a94df61e9cd7/gemma-4-12B-it-Q4_K_M.gguf"
Q14="/home/dev/.cache/huggingface/hub/models--bartowski--Qwen_Qwen3-14B-GGUF/snapshots/bd080f768a6401c2d5a7fa53a2e50cd8218a9ce2/Qwen_Qwen3-14B-Q4_K_M.gguf"
G6="/home/dev/llm/infer/models/gemma4-coder/gemma4-coding-Q6_K.gguf"

echo "######## 1/3 gemma-4-it (base) ########"; bash "$HM" "$GIT" "gemma-4-it-Q4" 40
echo "######## 2/3 gemma4coder-Q6 ########";   bash "$HM" "$G6"  "gemma4coder-Q6-he40" 40
echo "######## 3/3 Qwen3-14B (denso) ########"; bash "$HM" "$Q14" "qwen3-14b-Q4" 40
echo "ALL_HUMANEVAL_DONE"
