# Vision / multimodal (bonus)

The two **coders** benchmarked in this repo are text-only. But the **base `gemma-4-12B-it`** on the same box is a **vision-language model**, and this llama.cpp build runs it. Documented here for completeness (vision isn't the focus of a *coding*-agent framework, but it's a real capability of the stack).

## Which of the local models see images
| Model | Vision |
|---|---|
| **gemma-4-12B-it** (base) | ✅ yes — vision tower via `mmproj` |
| gemma-4-12B-coder | ❌ no — keeps `<\|image\|>` in template but ships **no mmproj** |
| Qwen3-Coder-30B | ❌ text-only |
| Qwen3-14B | ❌ text-only |

## Working command (verified on this box)
```bash
llama-mtmd-cli \
  -m gemma-4-12B-it-Q4_K_M.gguf \
  --mmproj mmproj-gemma-4-12B-it-Q8_0.gguf \
  --jinja -ngl 99 \
  --image photo.jpg \
  -p "Describe the image"
```
- **`--jinja` is required** — without it: `this custom template is not supported, try using --jinja`.
- The vision projector (`mmproj-gemma-4-12B-it-Q8_0.gguf`, 151 MB) ships in the same HF repo: `ggml-org/gemma-4-12B-it-GGUF`.
- Build also accepts **audio** input (`init_audio: experimental stage`) → image **and** audio multimodal.

## Smoke test (in this repo)
`scripts/vision_test.sh` renders an image (red circle + blue square + the text **"VISION 1337"**) and asks the model to list shapes, colors and text. Result:
> red circle ✓ · blue square ✓ · read **"VISION 1337"** verbatim ✓ — and it reasoned in its thought channel first.

Evidence: `results/vision/vision_test.png`. Run it yourself: `bash scripts/vision_test.sh`.

## Note
For **classical CV** (object detection, segmentation, diffusion), use a CV stack (YOLO/Ultralytics/timm/diffusers) — not these LLMs.
