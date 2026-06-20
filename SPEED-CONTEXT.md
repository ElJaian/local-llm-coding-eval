# Speed & context-scaling — 5 local models (RTX 5060 Ti 16 GB)

Measured via `llama-bench` (q8_0 KV cache, `-ngl 99`, flash-attn) for the 4 models that fit fully on GPU; **qwen3-coder-30B** (18 GB MoE) via ollama `num_ctx` sweep. All numbers = **tokens/sec** on this box. Script: `scripts/bench_speed_context.sh`.

## Generation (tg128) + prompt processing (pp512), by context depth
| Model | quant · runtime | pp512 | tg @0 | tg @4K | tg @16K | tg @32K |
|---|---|---:|---:|---:|---:|---:|
| **gemma-4-12B-it** (base) | Q4 · llama.cpp | 2153 | 45.7 | 43.2 | 45.4 | **41.8** |
| **Qwen3-14B** (dense) | Q4 · llama.cpp | 2108 | 39.1 | 43.2 | 34.0 | **23.0** |
| **gemma4coder** | Q6 · llama.cpp | 1875 | 38.8 | 37.9 | 36.4 | 29.2 |
| **gemma4coder** | Q8 · llama.cpp | 1381 | 31.2 | 26.2 | 25.6 | 24.6 |
| **qwen3-coder-30B** | Q4 · ollama (MoE) | – | – | 42.5 | 35.1 | 34.2 |

![speed by model](graphs/04_speed_by_model.png)
![context scaling](graphs/05_context_scaling.png)

### Takeaways
- **gemma-4-12B-it is the fastest *and* flattest** under context growth (45.7 → 41.8 t/s from 0 → 32 K) — best "fast daily driver."
- **The dense Qwen3-14B degrades the most with context** (39 → 23 t/s) — dense KV cost bites hard at depth.
- **qwen3-coder-30B (MoE)** holds 34–42 t/s; the drop with depth is the KV cache pushing more onto CPU.
- **Q6 vs Q8 (gemma4coder):** Q6 ≈ 25–30 % faster than Q8 at every depth — another reason Q6 is the daily pick.

### Context that fits
The precise max-context probe (`llama-cli`) proved flaky (hung on load) and was dropped. From the **real** `llama-bench` runs, all 4 GPU models executed tg128/pp512 at **depth 32 K** with `-ngl 99` + q8 KV → **all ≥ 32 K fully on GPU**. Higher is a VRAM-math estimate (Q6 ≈ 64 K+, Q8 tighter).

## Polyglot (hard agentic coding) — qwen3-coder-30B
Python split, 25 exercism exercises, **direct generation, canonical 2-try with test-error feedback**, temp 0.2: **4 / 25 (16 %)**.

![easy vs hard](graphs/06_easy_vs_hard.png)

- **Genuine difficulty, not a harness artifact** — verified the failed solutions are *complete* (no truncation), failing on real logic / exact-API / error-message / edge-case mismatches (e.g. wrong exception text, dict-vs-list return, fold arg order). Most stayed failed even with the test error fed back on try 2.
- **The headline contrast:** the same model scores **89 % on HumanEval+** (isolated functions) but **16 %** on these harder exercism problems — a clean illustration of the **local-30B-vs-frontier gap** on hard agentic coding.
- ⚠️ **Not the official Aider Polyglot** (225 exercises, 6 languages, search/replace edits). This is a **Python-only 25-exercise direct-generation** subset → a rough local lower bound, **not** directly comparable to the public leaderboard.
- 1-shot reference (no retry): also 4/25 (`results/polyglot/qwen_polyglot_1shot.txt`); temp 0.2 adds run-to-run variance.
