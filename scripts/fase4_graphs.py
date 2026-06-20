import json, os, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
SC  = "/home/dev/llm/eval/results/speed-context"
OUT = "/mnt/d/Repositories/local-llm/local-llm-coding-eval/graphs"; os.makedirs(OUT, exist_ok=True)
plt.rcParams.update({"figure.dpi":130,"font.size":11,"axes.grid":True,"grid.alpha":0.25,
   "axes.spines.top":False,"axes.spines.right":False,"figure.autolayout":True})

def load(name):
    p=f"{SC}/{name}.json"
    if not os.path.exists(p): return None
    d=json.load(open(p)); pp={}; tg={}
    for r in d:
        if r["n_prompt"]==512 and r["n_gen"]==0: pp[r["n_depth"]]=round(r["avg_ts"],1)
        if r["n_gen"]==128 and r["n_prompt"]==0: tg[r["n_depth"]]=round(r["avg_ts"],1)
    return {"pp":pp,"tg":tg}

M = {"gemma-4-it-Q4":load("gemma-4-it-Q4"),
     "gemma4coder-Q6":load("gemma4coder-Q6"),
     "gemma4coder-Q8":load("gemma4coder-Q8"),
     "qwen3-14b-Q4":load("qwen3-14b-Q4")}
QC_TG = {4096:42.5, 16384:35.1, 32768:34.2}   # qwen3-coder-30B via ollama sweep

print("== SPEED/CONTEXT (t/s) ==")
print(f"{'model':18s} pp512@0  tg@0  tg@4k tg@16k tg@32k")
for m,v in M.items():
    if not v: print(f"{m:18s} (sem json)"); continue
    print(f"{m:18s} {v['pp'].get(0,0):7.0f} {v['tg'].get(0,0):5.1f} {v['tg'].get(4096,0):5.1f} {v['tg'].get(16384,0):6.1f} {v['tg'].get(32768,0):6.1f}")
print(f"{'qwen3-coder-30B':18s}     -     -  {QC_TG[4096]:5.1f} {QC_TG[16384]:6.1f} {QC_TG[32768]:6.1f}")

# ---- graph 04: tg128 (generation) by model ----
order=["gemma-4-it-Q4","qwen3-14b-Q4","gemma4coder-Q6","gemma4coder-Q8"]
labels=["gemma-4-it\nQ4","Qwen3-14B\nQ4","gemma4coder\nQ6","gemma4coder\nQ8","qwen3-coder-30B\nQ4 (ollama)"]
vals=[M[m]["tg"].get(0,0) for m in order]+[QC_TG[4096]]
fig,ax=plt.subplots(figsize=(7.5,4.4))
cols=["#a78bfa","#0ea5e9","#7c3aed","#6d28d9","#0284c7"]
b=ax.bar(labels,vals,color=cols,width=0.6)
ax.set_ylabel("generation tokens/sec"); ax.set_title("Generation speed by model — RTX 5060 Ti 16GB")
for r in b: ax.annotate(f"{r.get_height():.1f}",(r.get_x()+r.get_width()/2,r.get_height()),ha="center",va="bottom",fontsize=9)
fig.savefig(f"{OUT}/04_speed_by_model.png"); plt.close(fig)

# ---- graph 05: context scaling (tg vs depth) ----
fig,ax=plt.subplots(figsize=(7.5,4.6))
depths=[0,4096,16384,32768]
for m,c in zip(order,["#a78bfa","#0ea5e9","#7c3aed","#6d28d9"]):
    ys=[M[m]["tg"].get(d) for d in depths]
    ax.plot([d//1024 for d in depths],ys,"o-",label=m,color=c)
ax.plot([4,16,32],[QC_TG[4096],QC_TG[16384],QC_TG[32768]],"s--",label="qwen3-coder-30B (ollama)",color="#0284c7")
ax.set_xlabel("context depth (K tokens)"); ax.set_ylabel("generation tokens/sec")
ax.set_title("Context scaling — tg128 vs context depth"); ax.legend(fontsize=8); ax.set_ylim(0,55)
fig.savefig(f"{OUT}/05_context_scaling.png"); plt.close(fig)

# ---- graph 06: easy vs hard (qwen3-coder) ----
fig,ax=plt.subplots(figsize=(6,4.4))
b=ax.bar(["HumanEval+\n(functions)","Polyglot py-25\n(hard, 2-try)"],[89.0,16.0],color=["#22c55e","#ef4444"],width=0.5)
ax.set_ylabel("% solved"); ax.set_ylim(0,100)
ax.set_title("qwen3-coder-30B: easy vs hard coding")
for r in b: ax.annotate(f"{r.get_height():.0f}%",(r.get_x()+r.get_width()/2,r.get_height()),ha="center",va="bottom")
fig.savefig(f"{OUT}/06_easy_vs_hard.png"); plt.close(fig)

print("graphs ->", sorted(os.listdir(OUT)))
