#!/usr/bin/env bash
# Deep-dive on agent tool-calling against the persistent server on :8080.
set -uo pipefail
source "$HOME/llm/infer/.venv/bin/activate" 2>/dev/null || true
python3 - <<'PY'
import json, time, urllib.request, urllib.error
base="http://127.0.0.1:8080"
# wait for shared server
for i in range(420):
    try:
        with urllib.request.urlopen(base+"/health",timeout=2) as r:
            if json.load(r).get("status")=="ok": print(f"[server ready ~{i}s]"); break
    except Exception: pass
    time.sleep(1)
else:
    print("server never came up"); raise SystemExit(2)

def chat(messages, tools=None, tool_choice=None, max_tokens=700, temp=0.3):
    body={"messages":messages,"max_tokens":max_tokens,"temperature":temp,"top_p":0.95}
    if tools is not None: body["tools"]=tools
    if tool_choice is not None: body["tool_choice"]=tool_choice
    req=urllib.request.Request(base+"/v1/chat/completions",
        data=json.dumps(body).encode(),headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=300) as r: return json.load(r),None
    except urllib.error.HTTPError as e: return None,f"HTTP {e.code}: {e.read().decode()[:200]}"

def tcs(m): return m.get("tool_calls") or []
def aj(tc):
    try: return json.loads(tc["function"]["arguments"])
    except Exception: return None

FS=[
 {"type":"function","function":{"name":"read_file","description":"Read a file",
   "parameters":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}}},
 {"type":"function","function":{"name":"write_file","description":"Create/overwrite a file with content",
   "parameters":{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}}},
 {"type":"function","function":{"name":"run_shell","description":"Run a shell command, return stdout",
   "parameters":{"type":"object","properties":{"cmd":{"type":"string"}},"required":["cmd"]}}},
 {"type":"function","function":{"name":"edit_file","description":"Replace a string in a file",
   "parameters":{"type":"object","properties":{"path":{"type":"string"},"old":{"type":"string"},"new":{"type":"string"}},"required":["path","old","new"]}}},
]
WEATHER=[{"type":"function","function":{"name":"get_weather","description":"Weather for a city",
  "parameters":{"type":"object","properties":{
     "location":{"type":"string"},
     "unit":{"type":"string","enum":["celsius","fahrenheit"]}},"required":["location","unit"]}}}]

res=[]
def rec(n,ok,d): res.append((n,ok,d)); print(f"[{'PASS' if ok else 'FAIL'}] {n}\n        {d}")

# A) write_file gap — capture what it does instead
r,e=chat([{"role":"user","content":"Create a file named hello.py that prints 'hello world'."}],tools=FS)
m=r["choices"][0]["message"] if r else {}
c=tcs(m); called = c and c[0]["function"]["name"]=="write_file"
content=(m.get("content") or "")
code_in_text = ("def " in content) or ("print(" in content) or ("```" in content)
rec("A write_file via tool", bool(called), f"tool={c[0]['function']['name'] if c else None} | code_in_text={code_in_text} | content[:90]={content[:90]!r}")

# B) Same task but tool_choice=required (force a call)
r,e=chat([{"role":"user","content":"Create a file named hello.py that prints 'hello world'."}],tools=FS,tool_choice="required")
m=r["choices"][0]["message"] if r else {}
c=tcs(m); a=aj(c[0]) if c else None
ok = bool(c) and c[0]["function"]["name"]=="write_file" and a and a.get("path","").endswith("hello.py")
rec("B write_file with tool_choice=required", ok, (e or f"tool={c[0]['function']['name'] if c else None} args={(c[0]['function']['arguments'][:120]) if c else None}"))

# C) run_shell
r,e=chat([{"role":"user","content":"Run the project's unit tests using pytest."}],tools=FS)
m=r["choices"][0]["message"] if r else {}
c=tcs(m); a=aj(c[0]) if c else None
ok = bool(c) and c[0]["function"]["name"]=="run_shell" and a and "pytest" in str(a.get("cmd",""))
rec("C run_shell(pytest)", ok, (e or f"tool={c[0]['function']['name'] if c else None} args={c[0]['function']['arguments'] if c else None}"))

# D) parallel/multiple reads
r,e=chat([{"role":"user","content":"Read the contents of both a.py and b.py."}],tools=FS)
m=r["choices"][0]["message"] if r else {}
c=tcs(m)
names=[x["function"]["name"] for x in c]
ok = len(c)>=2 and all(n=="read_file" for n in names)
rec("D parallel tool calls (read a.py + b.py)", ok, f"num_calls={len(c)} names={names}")

# E) edit_file with precise args
r,e=chat([{"role":"user","content":"In server.py, change the port from 8000 to 9000."}],tools=FS)
m=r["choices"][0]["message"] if r else {}
c=tcs(m); a=aj(c[0]) if c else None
ok = bool(c) and c[0]["function"]["name"]=="edit_file" and a and "8000" in str(a.get("old","")) and "9000" in str(a.get("new",""))
rec("E edit_file (8000->9000)", ok, (e or f"tool={c[0]['function']['name'] if c else None} args={(c[0]['function']['arguments'][:160]) if c else None}"))

# F) enum + multi required args
r,e=chat([{"role":"user","content":"What's the weather in Berlin in fahrenheit?"}],tools=WEATHER)
m=r["choices"][0]["message"] if r else {}
c=tcs(m); a=aj(c[0]) if c else None
ok = bool(c) and c[0]["function"]["name"]=="get_weather" and a and "berlin" in str(a.get("location","")).lower() and a.get("unit")=="fahrenheit"
rec("F enum arg (Berlin/fahrenheit)", ok, (e or f"args={c[0]['function']['arguments'] if c else None}"))

p=sum(1 for _,ok,_ in res if ok)
print(f"\n==== TOOL DEEP-DIVE: {p}/{len(res)} passed ====")
PY
echo "done."
