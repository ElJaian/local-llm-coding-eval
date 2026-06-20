# Gemma 4 12B Coder (fable5 / composer 2.5) — coding-agent usability eval

_RTX 5060 Ti 16 GB · WSL2 · llama.cpp `98d5e8b` · 2026-06-20_
_Model: `yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF` · 11.91 B · gemma4 arch · native 256K ctx · `peg-gemma4` chat format (thinking on)_

> Raw logs, generated samples, probe outputs, and all eval scripts: `~/llm/eval/results/gemma4-coder/` (WSL). Machine-readable summary: `results.json`.

## TL;DR verdict
**Usable as a coding-agent backend — yes, with the right harness.** It scores **HumanEval 91.5% / HumanEval+ 85.4%**, drives native tool-calling reliably (8/11, misses benign), and completes real edit tasks in Aider via search/replace (2/2). Best fit: **Aider-style agents** (code blocks + search/replace edits) on the **Q6_K** quant. Tool-centric agents (Cline/Continue) also work but watch its instinct to *emit code* rather than always wrap edits in a `write_file` call. Speed (~33 tok/s) is fine for interactive use, slower for long autonomous loops.

## 1. Speed (see RESULTADOS-HARDWARE.md)
| Quant | Disk | pp512 (llama-bench) | tg128 (llama-bench) | serving gen |
|---|---|---|---|---|
| Q6_K | 9.10 GiB | 1844 ± 86 t/s | 37.6 ± 0.3 t/s | 33.5 t/s |
| Q8_0 | 11.78 GiB | 1352 ± 119 t/s | 28.0 ± 8.1 t/s | 30.5 t/s |

## 2. Tool-calling (agent mechanics) — 8/11, all misses benign
- ✅ Correct tool selection, valid JSON args, enums, multi-arg, **parallel calls**, **abstains** when no tool needed, **multi-turn** (uses returned tool result).
- ⚠️ "Misses" were sensible agent behavior: `ls -R` before `pytest`, `read_file` before editing. A real loop allows these.
- ⚠️ Coding-fine-tune instinct: for "write code to a file" it may emit a ```python block instead of a `write_file` call (forced fine with `tool_choice=required`).

## 3. Code correctness (EvalPlus)
- **Base HumanEval, 40-problem subset, greedy: 37/40 = 92.5%.**
  - 2 of 3 failures were harness artifacts (empty extraction `/36`, dropped helper `/38`); true attempted rate ~95%.
- **Full 164 (fixed harness, official evalplus.evaluate, greedy): HumanEval base = 91.5%, HumanEval+ = 85.4%** (1 empty generation, counted as fail).

## 4. Agent loop (Aider, search/replace edits) — 2/2 ✅
- Add `multiply(a,b)` → SEARCH/REPLACE applied → `multiply(6,7)=42` ✓
- Fix `average([])` div-by-zero → SEARCH/REPLACE applied → `avg([])=0.0`, `avg([2,4])=3.0` ✓

## Full EvalPlus (full 164, base + plus) ✅
Corrected harness (self-contained prompt + retry-on-empty), greedy, official `evalplus.evaluate`:
- **HumanEval (base) pass@1 = 0.915 (91.5%)**
- **HumanEval+ (base + extra tests) pass@1 = 0.854 (85.4%)**
- Generation: 164/164 in 2082 s; only 1 empty (counted as fail → true rate marginally higher).
- Confirms the 40-subset estimate (92.5% base → 91.5% full). These are strong scores for a 12B
  (HumanEval+ ≥ 85% puts it in the range of much larger general models).

## How to reproduce
Scripts in `~/llm/eval/results/gemma4-coder/scripts/`. Serve with `./serve.sh gemma4coder 1`, then:
`bench.sh` (speed) · `tool_deepdive.sh` (tools) · `fix_eval_full.sh` (HumanEval+) · `aider_test.sh` (agent loop).
Eval venv: `~/llm/eval/.venv` (evalplus, aider 0.86.2) — kept separate from the inference venv.
