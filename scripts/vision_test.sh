#!/usr/bin/env bash
set -uo pipefail
MODEL=$(ls "$HOME"/.cache/huggingface/hub/models--ggml-org--gemma-4-12B-it-GGUF/snapshots/*/gemma-4-12B-it-Q4_K_M.gguf 2>/dev/null | head -1)
MMPROJ=$(ls "$HOME"/.cache/huggingface/hub/models--ggml-org--gemma-4-12B-it-GGUF/snapshots/*/mmproj-gemma-4-12B-it-Q8_0.gguf 2>/dev/null | head -1)
IMG="$HOME/llm/eval/vision_test.png"

echo "=== gerando imagem de teste (conteudo conhecido) ==="
"$HOME/llm/vision/.venv/bin/python" - "$IMG" <<'PY'
import sys, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle
fig,ax=plt.subplots(figsize=(5,5)); ax.set_xlim(0,10); ax.set_ylim(0,10); ax.axis('off')
ax.add_patch(Circle((3,7),1.6,color='red'))
ax.add_patch(Rectangle((6,5.4),3.2,3.2,color='blue'))
ax.text(5,2,"VISION 1337",ha='center',va='center',fontsize=30,weight='bold',color='black')
fig.savefig(sys.argv[1],dpi=100,bbox_inches='tight',facecolor='white')
print("ok:",sys.argv[1])
PY

echo "=== modelo : $MODEL"
echo "=== mmproj : $MMPROJ"
echo "=== rodando llama-mtmd-cli (visao) ==="
"$HOME/llm/infer/llama.cpp/build/bin/llama-mtmd-cli" \
  -m "$MODEL" --mmproj "$MMPROJ" -ngl 99 --jinja --image "$IMG" \
  -p "List exactly what is in this image: every shape with its color, and any text read verbatim." \
  -n 220 2>&1 | tail -35
echo "=== VISION_TEST_DONE ==="
