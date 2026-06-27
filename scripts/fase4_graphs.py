import os, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
# Self-contained: numbers are the published, measured values from SPEED-CONTEXT.md
# (llama-bench, idle RTX 5060 Ti 16GB; qwen3-coder-30B via ollama num_ctx sweep).
# tg = generation tokens/sec at context depth.  Regenerates graphs 04, 05, 06.
OUT = "/mnt/d/Repositories/local-llm/local-llm-coding-eval/graphs"; os.makedirs(OUT, exist_ok=True)
plt.rcParams.update({"figure.dpi":130,"font.size":11,"axes.grid":True,"grid.alpha":0.25,
   "axes.spines.top":False,"axes.spines.right":False,"figure.autolayout":True})

DATA = {
  "gemma-4-it\nQ4":               {"tg":{0:45.7,4096:43.2,16384:45.4,32768:41.8}, "c":"#a78bfa"},
  "Qwen3-14B\nQ4":                {"tg":{0:39.1,4096:43.2,16384:34.0,32768:23.0}, "c":"#0ea5e9"},
  "gemma4coder\nQ6":              {"tg":{0:38.8,4096:37.9,16384:36.4,32768:29.2}, "c":"#7c3aed"},
  "gemma4coder\nQ8":              {"tg":{0:31.2,4096:26.2,16384:25.6,32768:24.6}, "c":"#6d28d9"},
  "qwen3-coder-30B\nQ4 (ollama)": {"tg":{4096:42.5,16384:35.1,32768:34.2},        "c":"#0284c7"},
  "Qwen3.6-35B-A3B\nQ3_K_XL":     {"tg":{0:57.6,4096:51.0,16384:49.9,32768:53.3}, "c":"#10b981"},
}

# ---- graph 04: generation speed by model (tg @ depth 0; 30B has no depth-0 -> its 4K point) ----
labels=list(DATA.keys())
vals=[d["tg"].get(0, d["tg"].get(4096,0)) for d in DATA.values()]
cols=[d["c"] for d in DATA.values()]
fig,ax=plt.subplots(figsize=(9,4.7))
b=ax.bar(labels,vals,color=cols,width=0.62)
ax.set_ylabel("generation tokens/sec"); ax.set_title("Generation speed by model — RTX 5060 Ti 16GB")
ax.tick_params(axis="x", labelsize=8)
for r in b: ax.annotate(f"{r.get_height():.1f}",(r.get_x()+r.get_width()/2,r.get_height()),ha="center",va="bottom",fontsize=9)
fig.savefig(f"{OUT}/04_speed_by_model.png"); plt.close(fig)

# ---- graph 05: context scaling (tg vs depth) ----
fig,ax=plt.subplots(figsize=(8,4.8))
depths=[0,4096,16384,32768]
for name,d in DATA.items():
    lbl=name.replace("\n"," ")
    if "30B" in name:
        ax.plot([4,16,32],[d["tg"][4096],d["tg"][16384],d["tg"][32768]],"s--",label=lbl,color=d["c"])
    else:
        ax.plot([x//1024 for x in depths],[d["tg"].get(x) for x in depths],"o-",label=lbl,color=d["c"])
ax.set_xlabel("context depth (K tokens)"); ax.set_ylabel("generation tokens/sec")
ax.set_title("Context scaling — tg128 vs context depth"); ax.legend(fontsize=8); ax.set_ylim(0,70)
fig.savefig(f"{OUT}/05_context_scaling.png"); plt.close(fig)

# ---- graph 06: easy vs hard (qwen3-coder) — unchanged ----
fig,ax=plt.subplots(figsize=(6,4.4))
b=ax.bar(["HumanEval+\n(functions)","Polyglot py-25\n(hard, 2-try)"],[89.0,16.0],color=["#22c55e","#ef4444"],width=0.5)
ax.set_ylabel("% solved"); ax.set_ylim(0,100); ax.set_title("qwen3-coder-30B: easy vs hard coding")
for r in b: ax.annotate(f"{r.get_height():.0f}%",(r.get_x()+r.get_width()/2,r.get_height()),ha="center",va="bottom")
fig.savefig(f"{OUT}/06_easy_vs_hard.png"); plt.close(fig)

print("graphs ->", sorted(os.listdir(OUT)))
