#!/usr/bin/env bash
# Probe whether the model can drive an agent loop: native OpenAI tool-calling.
set -uo pipefail
GGUF="/home/dev/llm/infer/models/gemma4-coder/gemma4-coding-Q6_K.gguf"
PORT=8091
BIN="$HOME/llm/infer/llama.cpp/build/bin/llama-server"
LOG="$HOME/gemma4-tool-probe.log"
source "$HOME/llm/infer/.venv/bin/activate" 2>/dev/null || true

echo "=== launch (Q6, --jinja => tool parsing on) ==="
"$BIN" -m "$GGUF" -c 8192 -ngl 99 -fa 1 --no-mmap -np 1 \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --temp 0.7 --top-p 0.95 --top-k 64 \
  --jinja --host 127.0.0.1 --port "$PORT" > "$LOG" 2>&1 &
SVPID=$!

python3 - "$PORT" "$SVPID" <<'PY'
import sys, json, time, urllib.request, urllib.error, os
port, svpid = sys.argv[1], int(sys.argv[2])
base=f"http://127.0.0.1:{port}"
for i in range(300):
    try:
        with urllib.request.urlopen(base+"/health",timeout=2) as r:
            if json.load(r).get("status")=="ok": print(f"[ready ~{i}s]"); break
    except Exception: pass
    try: os.kill(svpid,0)
    except ProcessLookupError: print("!! server died"); sys.exit(2)
    time.sleep(1)

def chat(messages, tools=None, tool_choice=None, max_tokens=600, temp=0.4):
    body={"messages":messages,"max_tokens":max_tokens,"temperature":temp,"top_p":0.95}
    if tools is not None: body["tools"]=tools
    if tool_choice is not None: body["tool_choice"]=tool_choice
    req=urllib.request.Request(base+"/v1/chat/completions",
        data=json.dumps(body).encode(),headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=300) as r: return json.load(r), None
    except urllib.error.HTTPError as e:
        return None, f"HTTP {e.code}: {e.read().decode()[:300]}"

WEATHER=[{"type":"function","function":{"name":"get_weather",
  "description":"Get current weather for a city",
  "parameters":{"type":"object","properties":{"location":{"type":"string","description":"City name"}},"required":["location"]}}}]
FS=[
 {"type":"function","function":{"name":"read_file","description":"Read a file from disk",
   "parameters":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}}},
 {"type":"function","function":{"name":"write_file","description":"Write text to a file",
   "parameters":{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}}},
 {"type":"function","function":{"name":"run_shell","description":"Run a shell command and return stdout",
   "parameters":{"type":"object","properties":{"cmd":{"type":"string"}},"required":["cmd"]}}},
]
def tcs(m): return m.get("tool_calls") or []
def args_of(tc):
    try: return json.loads(tc["function"]["arguments"])
    except Exception: return None

results=[]
def record(name, passed, detail): results.append((name,passed,detail))

# 1) Single tool: should call get_weather(Paris)
r,err=chat([{"role":"user","content":"What's the current weather in Paris?"}],tools=WEATHER)
if err: record("1 single tool call",False,err)
else:
    m=r["choices"][0]["message"]; c=tcs(m)
    ok=len(c)>=1 and c[0]["function"]["name"]=="get_weather"
    a=args_of(c[0]) if ok else None
    ok2=bool(a) and "paris" in str(a.get("location","")).lower()
    record("1 single tool call (get_weather/Paris)", ok and ok2,
           f"name={c[0]['function']['name'] if c else None} args={c[0]['function']['arguments'] if c else None}")

# 2) Pick the RIGHT tool among many: read_file(config.yaml)
r,err=chat([{"role":"user","content":"Show me what's inside the file config.yaml."}],tools=FS)
if err: record("2 choose right tool",False,err)
else:
    m=r["choices"][0]["message"]; c=tcs(m)
    ok=len(c)>=1 and c[0]["function"]["name"]=="read_file"
    a=args_of(c[0]) if ok else None
    ok2=bool(a) and "config.yaml" in str(a.get("path",""))
    record("2 choose right tool (read_file/config.yaml)", ok and ok2,
           f"name={c[0]['function']['name'] if c else None} args={c[0]['function']['arguments'] if c else None}")

# 3) Multi-arg tool: write_file(hello.py, prints hello world)
r,err=chat([{"role":"user","content":"Create a file named hello.py that prints 'hello world'."}],tools=FS)
if err: record("3 multi-arg tool",False,err)
else:
    m=r["choices"][0]["message"]; c=tcs(m)
    ok=len(c)>=1 and c[0]["function"]["name"]=="write_file"
    a=args_of(c[0]) if ok else None
    ok2=bool(a) and a.get("path","").endswith("hello.py") and "print" in str(a.get("content","")).lower()
    record("3 multi-arg tool (write_file hello.py)", ok and ok2,
           f"name={c[0]['function']['name'] if c else None} args={(c[0]['function']['arguments'][:160]) if c else None}")

# 4) Knows when NOT to call a tool (tools available but unneeded)
r,err=chat([{"role":"user","content":"What is 17 * 23? Reply with just the number."}],tools=FS)
if err: record("4 no spurious call",False,err)
else:
    m=r["choices"][0]["message"]; c=tcs(m)
    content=(m.get("content") or "")
    ok = len(c)==0 and "391" in content
    record("4 no spurious tool call (17*23=391)", ok,
           f"tool_calls={len(c)} content={content[:80]!r}")

# 5) Multi-turn: feed a tool result back, expect a final answer
msgs=[{"role":"user","content":"What's the weather in Tokyo?"}]
r,err=chat(msgs,tools=WEATHER)
if err: record("5 multi-turn after tool result",False,err)
else:
    m=r["choices"][0]["message"]; c=tcs(m)
    if not c:
        record("5 multi-turn after tool result",False,"no initial tool_call to continue from")
    else:
        msgs.append({"role":"assistant","content":m.get("content") or "","tool_calls":c})
        msgs.append({"role":"tool","tool_call_id":c[0].get("id","call_0"),
                     "name":"get_weather","content":json.dumps({"location":"Tokyo","temp_c":21,"cond":"clear"})})
        r2,err2=chat(msgs,tools=WEATHER)
        if err2: record("5 multi-turn after tool result",False,err2)
        else:
            fm=r2["choices"][0]["message"]; fc=tcs(fm); txt=(fm.get("content") or "")
            ok = len(fc)==0 and ("21" in txt or "tokyo" in txt.lower())
            record("5 multi-turn (uses tool result in answer)", ok, f"final={txt[:120]!r}")

print("\n================ TOOL-CALLING PROBE ================")
p=sum(1 for _,ok,_ in results if ok)
for name,ok,detail in results:
    print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    print(f"        {detail}")
print(f"---- {p}/{len(results)} passed ----")
PY

echo "=== server log (tool-format hints) ==="
grep -iE "tool|jinja|template|grammar|chat format" "$LOG" | head -n 8
kill "$SVPID" 2>/dev/null; sleep 2
echo "done."
