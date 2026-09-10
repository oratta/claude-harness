#!/usr/bin/env python3
"""main ブランチのコストが「issue 参照あり」のセッションでどれだけ回収できるか"""
import json, os, glob, re, time
from collections import defaultdict
P={"claude-fable-5-1":(10,50,12.5,20,0.25),"claude-fable-5":(10,50,12.5,20,1.0),
   "claude-opus-5":(5,25,6.25,10,0.5),"claude-opus-4-8":(5,25,6.25,10,0.5),
   "claude-opus-4-7":(5,25,6.25,10,0.5),"claude-opus-4-6":(5,25,6.25,10,0.5),
   "claude-sonnet-5":(2,10,2.5,4,0.2),"claude-sonnet-4-6":(3,15,3.75,6,0.3),
   "claude-haiku-4-5":(1,5,1.25,2,0.1)}
def rate(m):
    for k,v in P.items():
        if (m or "").startswith(k): return v
ISSUE=re.compile(r'gh issue (?:view|comment|edit|close|develop)\s+(\d+)')
sess_cost=defaultdict(float); sess_issue=defaultdict(set); sess_repo={}
seen=set(); t0=time.time()
for f in glob.glob(os.path.expanduser("~/.claude/projects/**/*.jsonl"),recursive=True):
    for line in open(f,encoding="utf-8",errors="replace"):
        if '"assistant"' not in line: continue
        try: d=json.loads(line)
        except Exception: continue
        if d.get("type")!="assistant": continue
        cwd=d.get("cwd") or ""
        if "flatmate" not in cwd: continue
        if (d.get("gitBranch") or "") not in ("main","master"): continue
        rid=d.get("requestId") or d.get("uuid")
        if rid in seen: continue
        seen.add(rid)
        sid=d.get("sessionId") or f
        m=d.get("message",{}); u=m.get("usage") or {}; r=rate(m.get("model"))
        if r:
            cc=u.get("cache_creation") or {}
            cw5=cc.get("ephemeral_5m_input_tokens",0); cw1=cc.get("ephemeral_1h_input_tokens",0)
            if not (cw5 or cw1): cw5=u.get("cache_creation_input_tokens",0)
            sess_cost[sid]+=(u.get("input_tokens",0)*r[0]+u.get("output_tokens",0)*r[1]+cw5*r[2]
                             +cw1*r[3]+u.get("cache_read_input_tokens",0)*r[4])/1e6
        for b in (m.get("content") or []):
            if isinstance(b,dict) and b.get("type")=="tool_use":
                s=json.dumps(b.get("input") or {})
                for n in ISSUE.findall(s): sess_issue[sid].add(n)
with_i=sum(c for s,c in sess_cost.items() if sess_issue[s])
without=sum(c for s,c in sess_cost.items() if not sess_issue[s])
n_i=sum(1 for s in sess_cost if sess_issue[s]); n_o=len(sess_cost)-n_i
print(f"elapsed={time.time()-t0:.1f}s")
print(f"flatmate の main/master 上のコスト  合計 ${with_i+without:,.2f}")
print(f"  issue 参照ありのセッション : ${with_i:8.2f}  ({n_i} sessions)")
print(f"  issue 参照なしのセッション : ${without:8.2f}  ({n_o} sessions)")
top=sorted(((c,s) for s,c in sess_cost.items() if sess_issue[s]),reverse=True)[:5]
for c,s in top:
    print(f"    ${c:7.2f}  issues={sorted(sess_issue[s])[:6]}")
