# Environment — exact stack used for these benchmarks

Reproducibility matters, and getting this Blackwell + WSL2 stack working was painful — so here's everything, plus the gotchas that cost us the most time.

## Hardware
| | |
|---|---|
| GPU | NVIDIA **RTX 5060 Ti 16 GB** — Blackwell, **compute capability 12.0 (sm_120)**, GDDR7 128-bit |
| CPU | AMD Ryzen 5 7600X (6c/12t) |
| RAM | 16 GB DDR5-4800 |
| Storage | models on HDD (only affects *load time*, not inference once weights are in VRAM) |

## OS & drivers
| | |
|---|---|
| Host OS | Windows 11 Pro for Workstations **10.0.26200.8655** |
| Linux | **WSL2 · Ubuntu 24.04.1 LTS** · kernel `6.6.114.1-microsoft-standard-WSL2` |
| NVIDIA driver | **591.86** (Windows) |
| CUDA runtime (exposed to WSL) | **13.1** |
| CUDA Toolkit (build) | **12.8** (Blackwell needs ≥ 12.8) |

## Inference engines
| | |
|---|---|
| **llama.cpp** | build `98d5e8b` · GCC 13.3.0 · `CUDA ARCHS=1200` · `USE_GRAPHS=1` · `BLACKWELL_NATIVE_FP4=1` · flash-attn · built with libcurl/OpenSSL (needed for `-hf`) |
| **ollama** | `0.17.7` (used for the MoE qwen3-coder-30B) |

## Eval tooling (dedicated venv, isolated from inference/training venvs)
| | |
|---|---|
| Python | **3.11.15** (uv `0.11.19`) |
| evalplus | 0.3.1 |
| aider-chat | 0.86.2 |
| openai | 2.20.0 |
| litellm | 1.81.10 |
| huggingface-hub | 1.4.1 (eval venv) · model downloads done with `hf` in the inference venv |
| datasets | 5.0.0 |
| fire | 0.7.1 |
| gcc (system) | 13.3.0 |

## Gotchas that cost us time (save yourself the pain)
- **Blackwell (sm_120) needs CUDA ≥ 12.8 everywhere.** Older toolkits won't generate `sm_120` and you get silent CPU fallback or build errors. Use **Python 3.11** for the widest prebuilt wheels.
- **llama.cpp `-hf` (pull from HF) needs HTTPS** → build with **libcurl/OpenSSL** (`-DLLAMA_CURL=ON` / OpenSSL dev headers). Without it: *"HTTPS is not supported."* Workaround: `hf download …` then `-m`.
- **WSL2 ↔ Windows networking:** `localhost` from WSL does **not** reach a Windows-hosted ollama — use the **Windows host gateway IP** (e.g. `172.28.x.1:11434`, from `ip route show default`).
- **WSL paths:** Windows paths don't work inside WSL — use `/mnt/d/...`, not `D:\...`.
- **Node/npm leaking from Windows** into WSL → *"WSL 1 not supported"*. Fix: install native Linux Node (NodeSource).
- **HF downloads:** the Xet backend stalled on this machine → force classic HTTPS (`HF_HUB_DISABLE_XET=1`). Single-stream ~8 MB/s here.
- **Use the official `uv` installer** (not snap); it lands in `~/.local/bin`. `uv venv` does **not** include `pip` — query versions via `importlib.metadata` / `uv pip`.
- **MoE offload ≠ slow:** an 18 GB MoE-A3B on a 16 GB card spills ~25% to CPU but stays fast (~3 B active params/token). "Offload = slow" is a *dense*-model rule.

## Serving flags (for reference)
- llama.cpp: `-ngl 99 -fa 1 --no-mmap -np 1 --cache-type-k q8_0 --cache-type-v q8_0 --jinja` + per-model sampling.
- ollama: defaults (qwen3-coder: temp 0.7 / top-p 0.8 / top-k 20); greedy (`temperature 0`) for EvalPlus.
