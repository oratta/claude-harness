#!/usr/bin/env python3
"""ブランチ内のコストを「投稿(gh pr/issue comment/create)ごとの区間」に割る"""
import json, os, sys, subprocess, time
P={"claude-fable-5-1":(10,50,12.5,20,0.25),"claude-fable-5":(10,50,12.5,20,1.0),
   "claude-opus-5":(5,25,6.25,10,0.5),"claude-opus-4-8":(5,25,6.25,10,0.5),
   "claude-opus-4-7":(5,25,6.25,10,0.5),"claude-opus-4-6":(5,25,6.25,10,0.5),
   "claude-sonnet-5":(2,10,2.5,4,0.2),"claude-sonnet-4-6":(3,15,3.75,6,0.3),
   "claude-haiku-4-5":(1,5,1.25,2,0.1)}
def rate(m):
    for k,v in P.items():
        if (m or "").startswith(k): return v
branch=sys.argv[1]
root=os.path.expanduser("~/.claude/projects")
files=subprocess.run(["grep","-rl","--include=*.jsonl","-F",branch,root],capture_output=True,text=True).stdout.split()
ev=[]; seen=set()
for f in files:
    for line in open(f,encoding="utf-8",errors="replace"):
        if '"assistant"' not in line: continue
        try: d=json.loads(line)
        except Exception: continue
        if d.get("type")!="assistant" or d.get("gitBranch")!=branch: continue
        rid=d.get("requestId") or d.get("uuid")
        if rid in seen: continue
        seen.add(rid)
        m=d.get("message",{}); u=m.get("usage") or {}; r=rate(m.get("model"))
        c=0.0
        if r:
            cc=u.get("cache_creation") or {}
            cw5=cc.get("ephemeral_5m_input_tokens",0); cw1=cc.get("ephemeral_1h_input_tokens",0)
            if not (cw5 or cw1): cw5=u.get("cache_creation_input_tokens",0)
            c=(u.get("input_tokens",0)*r[0]+u.get("output_tokens",0)*r[1]+cw5*r[2]+cw1*r[3]
               +u.get("cache_read_input_tokens",0)*r[4])/1e6
        mark=None
        for b in (m.get("content") or []):
            if isinstance(b,dict) and b.get("type")=="tool_use" and b.get("name")=="Bash":
                cmd=(b.get("input") or {}).get("command","")
                for pat in ("gh pr comment","gh issue comment","gh pr create","gh pr ready"):
                    if pat in cmd: mark=pat; break
            if mark: break
        ev.append((d.get("timestamp",""),c,mark))
ev.sort()
acc=0.0; n=0; out=[]
for ts,c,mark in ev:
    acc+=c; n+=1
    if mark:
        out.append((ts[:16],mark,acc,n)); acc=0.0; n=0
print(f"branch={branch}  投稿イベント {len(out)} 件")
for ts,mark,c,n in out:
    print(f"  {ts}  {mark:18s}  直前の投稿以降 ${c:6.2f}  ({n:4d} messages)")
print(f"  残り（最後の投稿以降） ${acc:.2f} ({n} messages)")
