# Coding correctness matrix — base vs fine-tune, dense vs MoE, easy vs hard

All measured on the **RTX 5060 Ti 16 GB**. HumanEval comparison uses the **same 40-problem subset, same simple prompt, same base-test scorer** across models (qwen3-coder shown at its full-164 number for reference).

## HumanEval (base tests, 40-subset)
| Model | pass@1 | notes |
|---|---:|---|
| **gemma-4-12B-it** (BASE) | **42.5%** | ⚠️ 10/40 empty — the base over-thinks past the token budget; attempted-only ≈ 57% |
| **gemma4coder** Q6 (fable5/composer) | **95.0%** | 0 empty |
| **Qwen3-14B** (dense) | **95.0%** | 0 empty |
| **qwen3-coder-30B** | 92.1% | *(full 164; HumanEval+ = 89.0%)* |

![HumanEval-40](graphs/07_humaneval40_compare.png)

### Finding 1 — the coder fine-tune helps a LOT
**gemma-4-12B-it base 42.5% → gemma4coder 95.0%** on the *same* problems. The fable5/composer training is a big, real win for isolated-function coding (even being generous to the base's empties, ~57% → 95%).

![fine-tune impact](graphs/08_finetune_impact.png)

## Polyglot (hard agentic, Python-25, 2-try w/ test feedback)
| Model | pass@1 |
|---|---:|
| **gemma4coder-12B** | **4%** (1/25) |
| **qwen3-coder-30B** | **16%** (4/25) |

![polyglot head-to-head](graphs/09_polyglot_h2h.png)

### Finding 2 — easy ≠ hard, and on hard problems size matters
Both coders **ace HumanEval (~95%)** but **crater on the hard exercism polyglot** problems. The **30B does ~4× better than the 12B** there (16% vs 4%) despite tying on HumanEval. Verified genuine (complete code, real logic/API failures — not truncation). This is the **local-vs-frontier gap**: strong on textbook functions, weak on real multi-part problems.

## Caveats (read before quoting)
- HumanEval is saturated / contamination-prone; this is a **40-subset**, **base** tests (not HumanEval+).
- The **gemma-4-it base** empties (over-thinking) drag its number; even attempted-only (~57%) is far below the coders.
- Polyglot here is a **Python-25 direct-generation** subset, **not** the official Aider Polyglot (225 ex, 6 langs, search/replace) → a rough local lower bound, not leaderboard-comparable.
- Runtimes differ (llama.cpp for gemma-4-it / gemma4coder / Qwen3-14B; ollama for qwen3-coder). Greedy/temp-0 for HumanEval; temp 0.2 for polyglot.
