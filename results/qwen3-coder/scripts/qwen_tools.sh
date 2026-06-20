#!/usr/bin/env bash
# Same tool-calling suite as gemma4, but against ollama /v1 (qwen3-coder:30b).
set -uo pipefail
python3 - <<'PY'
import json, time, urllib.request, urllib.error
BASE="http://172.28.192.1:11434/v1"
MODEL="qwen3-coder:30b"

def chat(messages, tools=None, tool_choice=None, max_tokens=700, temp=0.3):
    body={"model":MODEL,"messages":messages,"max_tokens":max_tokens,"temperature":temp,"top_p":0.8}
    if tools is not None: body["tools"]=tools
    if tool_choice is not None: body["tool_choice"]=tool_choice
    req=urllib.request.Request(BASE+"/chat/completions",data=json.dumps(body).encode(),
                               headers={"Content-Type":"application/json","Authorization":"Bearer x"})
    try:
        with urllib.request.urlopen(req,timeout=300) as r: return json.load(r),None
    except urllib.error.HTTPError as e: return None,f"HTTP {e.code}: {e.read().decode()[:200]}"
    except Exception as e: return None,str(e)[:200]

def tcs(m): return m.get("tool_calls") or []
def aj(tc):
    try: return json.loads(tc["function"]["arguments"])
    except Exception:
        a=tc["function"].get("arguments")
        return a if isinstance(a,dict) else None

WEATHER=[{"type":"function","function":{"name":"get_weather","description":"Weather for a city",
  "parameters":{"type":"object","properties":{"location":{"type":"string"},
     "unit":{"type":"string","enum":["celsius","fahrenheit"]}},"required":["location"]}}}]
WEATHER_U=[{"type":"function","function":{"name":"get_weather","description":"Weather for a city",
  "parameters":{"type":"object","properties":{"location":{"type":"string"},
     "unit":{"type":"string","enum":["celsius","fahrenheit"]}},"required":["location","unit"]}}}]
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
res=[]
def rec(n,ok,d): res.append((n,ok)); print(f"[{'PASS' if ok else 'FAIL'}] {n}\n        {d}")

print("(warming up / loading model on first call...)")
# 1 single
r,e=chat([{"role":"user","content":"What's the current weather in Paris?"}],tools=WEATHER)
m=r["choices"][0]["message"] if r else {}; c=tcs(m); a=aj(c[0]) if c else None
rec("1 single call (get_weather/Paris)", bool(c) and c[0]["function"]["name"]=="get_weather" and a and "paris" in str(a.get("location","")).lower(), (e or f"{[x['function']['name'] for x in c]} {c[0]['function']['arguments'] if c else None}"))
# 2 choose among many
r,e=chat([{"role":"user","content":"Show me what's inside the file config.yaml."}],tools=FS)
m=r["choices"][0]["message"] if r else {}; c=tcs(m); a=aj(c[0]) if c else None
rec("2 choose right tool (read_file/config.yaml)", bool(c) and c[0]["function"]["name"]=="read_file" and a and "config.yaml" in str(a.get("path","")), (e or f"{[x['function']['name'] for x in c]} {c[0]['function']['arguments'] if c else None}"))
# 3 abstain
r,e=chat([{"role":"user","content":"What is 17 * 23? Reply with just the number."}],tools=FS)
m=r["choices"][0]["message"] if r else {}; c=tcs(m); content=(m.get("content") or "")
rec("3 abstain (17*23=391, no tool)", len(c)==0 and "391" in content, (e or f"tool_calls={len(c)} content={content[:60]!r}"))
# 4 multi-turn
msgs=[{"role":"user","content":"What's the weather in Tokyo?"}]
r,e=chat(msgs,tools=WEATHER)
m=r["choices"][0]["message"] if r else {}; c=tcs(m)
if c:
    msgs.append({"role":"assistant","content":m.get("content") or "","tool_calls":c})
    msgs.append({"role":"tool","tool_call_id":c[0].get("id","call_0"),"name":"get_weather",
                 "content":json.dumps({"location":"Tokyo","temp_c":21,"cond":"clear"})})
    r2,e2=chat(msgs,tools=WEATHER); fm=r2["choices"][0]["message"] if r2 else {}
    txt=(fm.get("content") or "")
    rec("4 multi-turn (uses tool result)", len(tcs(fm))==0 and ("21" in txt or "tokyo" in txt.lower()), (e2 or f"final={txt[:90]!r}"))
else:
    rec("4 multi-turn (uses tool result)", False, (e or "no initial tool call"))
# 5 write_file
r,e=chat([{"role":"user","content":"Create a file named hello.py that prints 'hello world'."}],tools=FS)
m=r["choices"][0]["message"] if r else {}; c=tcs(m)
rec("5 write_file via tool", bool(c) and c[0]["function"]["name"]=="write_file", (e or f"{[x['function']['name'] for x in c] if c else None} content={(m.get('content') or '')[:60]!r}"))
# 6 write_file required
r,e=chat([{"role":"user","content":"Create a file named hello.py that prints 'hello world'."}],tools=FS,tool_choice="required")
m=r["choices"][0]["message"] if r else {}; c=tcs(m); a=aj(c[0]) if c else None
rec("6 write_file tool_choice=required", bool(c) and c[0]["function"]["name"]=="write_file" and a and a.get("path","").endswith("hello.py"), (e or f"{c[0]['function']['arguments'][:120] if c else None}"))
# 7 run_shell
r,e=chat([{"role":"user","content":"Run the project's unit tests using pytest."}],tools=FS)
m=r["choices"][0]["message"] if r else {}; c=tcs(m); a=aj(c[0]) if c else None
rec("7 run_shell(pytest)", bool(c) and c[0]["function"]["name"]=="run_shell" and a and "pytest" in str(a.get("cmd","")), (e or f"{[x['function']['name'] for x in c] if c else None} {c[0]['function']['arguments'] if c else None}"))
# 8 parallel
r,e=chat([{"role":"user","content":"Read the contents of both a.py and b.py."}],tools=FS)
m=r["choices"][0]["message"] if r else {}; c=tcs(m); names=[x["function"]["name"] for x in c]
rec("8 parallel reads (a.py + b.py)", len(c)>=2 and all(n=="read_file" for n in names), (e or f"num={len(c)} names={names}"))
# 9 edit_file
r,e=chat([{"role":"user","content":"In server.py, change the port from 8000 to 9000."}],tools=FS)
m=r["choices"][0]["message"] if r else {}; c=tcs(m); a=aj(c[0]) if c else None
rec("9 edit_file (8000->9000)", bool(c) and c[0]["function"]["name"]=="edit_file" and a and "8000" in str(a.get("old","")) and "9000" in str(a.get("new","")), (e or f"{[x['function']['name'] for x in c] if c else None} {c[0]['function']['arguments'][:140] if c else None}"))
# 10 enum
r,e=chat([{"role":"user","content":"What's the weather in Berlin in fahrenheit?"}],tools=WEATHER_U)
m=r["choices"][0]["message"] if r else {}; c=tcs(m); a=aj(c[0]) if c else None
rec("10 enum arg (Berlin/fahrenheit)", bool(c) and a and "berlin" in str(a.get("location","")).lower() and a.get("unit")=="fahrenheit", (e or f"{c[0]['function']['arguments'] if c else None}"))

p=sum(1 for _,ok in res if ok)
print(f"\n==== QWEN3-CODER TOOL SUITE: {p}/{len(res)} passed ====")
PY
echo done.
