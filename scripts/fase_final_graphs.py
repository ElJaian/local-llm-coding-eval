import os, re, json, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
RES="/home/dev/llm/eval/results"
OUT="/mnt/d/Repositories/local-llm/local-llm-coding-eval/graphs"; os.makedirs(OUT,exist_ok=True)
plt.rcParams.update({"figure.dpi":130,"font.size":11,"axes.grid":True,"grid.alpha":0.25,
   "axes.spines.top":False,"axes.spines.right":False,"figure.autolayout":True})

def he40(name):
    try:
        t=open(f"{RES}/humaneval-{name}/base_score.txt").read()
        m=re.search(r"pass\s+(\d+)/(\d+)\s*=\s*([\d.]+)%",t);
        return float(m.group(3)) if m else None
    except Exception: return None
def poly(fname):
    try:
        t=open(f"{RES}/polyglot/{fname}").read()
        m=re.search(r":\s*(\d+)/(\d+)\s*====",t)
        return 100*int(m.group(1))/int(m.group(2)) if m else None
    except Exception: return None

g_it=he40("gemma-4-it-Q4"); g_co=he40("gemma4coder-Q6-he40"); q14=he40("qwen3-14b-Q4")
qc_full=92.1  # qwen3-coder full-164 base (referencia)
print("HE40:", g_it, g_co, q14, "| qwen3-coder(full164)=",qc_full)
pg_qc=poly("qwen_polyglot_results.txt"); pg_g=poly("gemma4coder_polyglot_results.txt")
print("POLYGLOT: qwen3-coder=",pg_qc,"gemma4coder=",pg_g)

# 07: HumanEval-40 base, 4 models
labels=["gemma-4-it\nBASE","gemma4coder\nQ6","Qwen3-14B\nQ4","qwen3-coder-30B\n(full 164)*"]
vals=[g_it or 0, g_co or 0, q14 or 0, qc_full]
cols=["#9ca3af","#7c3aed","#0ea5e9","#0284c7"]
fig,ax=plt.subplots(figsize=(7.5,4.4)); b=ax.bar(labels,vals,color=cols,width=0.6)
ax.set_ylabel("pass@1 (base HumanEval, %)"); ax.set_ylim(0,100)
ax.set_title("Code correctness — HumanEval (40-subset, same prompt)")
for r in b: ax.annotate(f"{r.get_height():.1f}%",(r.get_x()+r.get_width()/2,r.get_height()),ha="center",va="bottom",fontsize=9)
fig.text(0.01,0.01,"*qwen3-coder = full 164 (greedy); others = 40-subset, simple prompt, base tests",fontsize=7,color="#888")
fig.savefig(f"{OUT}/07_humaneval40_compare.png"); plt.close(fig)

# 08: fine-tune impact (base -> coder)
fig,ax=plt.subplots(figsize=(5.5,4.4))
b=ax.bar(["gemma-4-it\n(base)","gemma4coder\n(fable5/composer)"],[g_it or 0, g_co or 0],color=["#9ca3af","#22c55e"],width=0.5)
ax.set_ylabel("pass@1 (base HumanEval-40, %)"); ax.set_ylim(0,100)
ax.set_title("Did the coder fine-tune help? (gemma-4)")
for r in b: ax.annotate(f"{r.get_height():.1f}%",(r.get_x()+r.get_width()/2,r.get_height()),ha="center",va="bottom")
fig.savefig(f"{OUT}/08_finetune_impact.png"); plt.close(fig)

# 09: polyglot head-to-head
if pg_g is not None and pg_qc is not None:
    fig,ax=plt.subplots(figsize=(5.5,4.4))
    b=ax.bar(["gemma4coder\n12B","qwen3-coder\n30B"],[pg_g,pg_qc],color=["#7c3aed","#0284c7"],width=0.5)
    ax.set_ylabel("polyglot py-25 pass@1 (%)"); ax.set_ylim(0,40)
    ax.set_title("Hard agentic coding (polyglot py-25, 2-try)")
    for r in b: ax.annotate(f"{r.get_height():.0f}%",(r.get_x()+r.get_width()/2,r.get_height()),ha="center",va="bottom")
    fig.savefig(f"{OUT}/09_polyglot_h2h.png"); plt.close(fig)
    print("09 polyglot h2h gerado")
print("graphs:", sorted(os.listdir(OUT)))
