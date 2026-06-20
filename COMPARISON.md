# Local coding-agent head-to-head: gemma4-coder-12B vs qwen3-coder-30B

_RTX 5060 Ti 16 GB · WSL2 · 2026-06-20 · same eval suite on both, measured on this machine_
_gemma4 served via llama.cpp (`serve.sh gemma4coder`); qwen3-coder served via ollama (`qwen3-coder:30b`, MoE qwen3moe A3B)._

## Verdict
**For agentic coding alongside Claude, `qwen3-coder:30b` is the better local backend** — it's **faster (41.5 vs 33.5 t/s), more correct (esp. HumanEval+ 89.0% vs 85.4%)**, purpose-built for agents, and despite spilling 25% to CPU it beats the 12B because it's MoE-A3B (only ~3B active/token, so offload is cheap).
**Use `gemma4-coder Q6` when you need the GPU mostly free** (qwen eats all 16 GB → ~0 free; gemma leaves ~5 GB), want **fast cold-load** (~14 s vs ~48 s), or prefer a thinking/reasoning style.

## Full comparison
| Dimension | gemma4-coder-12B (Q6_K, llama.cpp) | qwen3-coder-30B (Q4_K_M, ollama) |
|---|---|---|
| Params | 11.9 B dense | 30.5 B MoE (~3 B active) |
| Disk / VRAM | 9.1 GB · fits fully (~5 GB free) | 19 GB · **25% CPU / 75% GPU** (~0 free) |
| **Generation speed** | 33.5 t/s | **41.5 t/s** |
| Cold load | **~14 s** | ~48 s |
| **HumanEval (base) pass@1** | 91.5% | **92.1%** |
| **HumanEval+ pass@1** | 85.4% | **89.0%** |
| EvalPlus empties | 1/164 | **0/164** |
| Tool-calling | 8/11 — misses = look-before-leap (sensible) | 8/10 — misses = `write_file` emitted as `<function=>` text, ollama didn't parse |
| Aider (2 edit tasks, search/replace) | 2/2 ✅ | 2/2 ✅ |
| Native context | 256K | 256K |
| Style | reasoning/"thinks" before answering | direct instruct coder |

## Notes & honesty
- **Runtime differs** (llama.cpp vs ollama). The eval measures model outputs (correctness, edits, tool intent), largely runtime-independent; sampling was greedy (temp 0) for EvalPlus on both. The ollama setup is how qwen is actually run here, so it's the realistic number.
- **HumanEval is saturated/contamination-prone** — both scores are "clears the bar," not proof of elite agentic skill. The Aider live tasks (novel, written by hand) are the more trustworthy capability signal; both passed 2/2 on simple edits.
- We did **not** run a large agentic benchmark (SWE-bench / Aider polyglot). On those, both would rank far below frontier models — neither replaces Claude for hard reasoning/architecture/cross-file debugging. Local model value = cheap + private + parallel grunt work.
- qwen `write_file`-as-text is an ollama+qwen tool-parse quirk, not model incapacity (it emitted the call intent). Tool-centric agents may need the ollama tool-parser tuned; Aider-style (search/replace) works for both.

## Artifacts
- gemma4: `~/llm/eval/results/gemma4-coder/` + `eval-results/gemma4-coder/` (RESULTS.md, results.json)
- qwen3-coder: `~/llm/eval/results/qwen3-coder/` (logs, samples, scores, scripts)
