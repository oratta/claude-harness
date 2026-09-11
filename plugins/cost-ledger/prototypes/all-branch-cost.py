#!/usr/bin/env python3
import json, os, glob, time
from collections import defaultdict
P = {"claude-fable-5-1":(10,50,12.5,20,0.25),"claude-fable-5":(10,50,12.5,20,1.0),
     "claude-opus-5":(5,25,6.25,10,0.5),"claude-opus-4-8":(5,25,6.25,10,0.5),
     "claude-opus-4-7":(5,25,6.25,10,0.5),"claude-opus-4-6":(5,25,6.25,10,0.5),
     "claude-sonnet-5":(2,10,2.5,4,0.2),"claude-sonnet-4-6":(3,15,3.75,6,0.3),
     "claude-haiku-4-5":(1,5,1.25,2,0.1)}
def rate(m):
    for k,v in P.items():
        if m.startswith(k): return v
t0=time.time()
cost=defaultdict(float); msgs=defaultdict(int); seen=set(); nf=0; nl=0
for f in glob.glob(os.path.expanduser("~/.claude/projects/**/*.jsonl"), recursive=True):
    nf+=1
    with open(f,encoding="utf-8",errors="replace") as fh:
        for line in fh:
            nl+=1
            if '"assistant"' not in line: continue
            try: d=json.loads(line)
            except Exception: continue
            if d.get("type")!="assistant": continue
            rid=d.get("requestId") or d.get("uuid")
            if rid in seen: continue
            seen.add(rid)
            m=d.get("message",{}); u=m.get("usage") or {}
            r=rate(m.get("model","") or "")
            if not r: continue
            cc=u.get("cache_creation") or {}
            cw5=cc.get("ephemeral_5m_input_tokens",0); cw1=cc.get("ephemeral_1h_input_tokens",0)
            if not (cw5 or cw1): cw5=u.get("cache_creation_input_tokens",0)
            b=d.get("gitBranch") or "(no-branch)"
            cost[b]+=(u.get("input_tokens",0)*r[0]+u.get("output_tokens",0)*r[1]
                      +cw5*r[2]+cw1*r[3]+u.get("cache_read_input_tokens",0)*r[4])/1e6
            msgs[b]+=1
el=time.time()-t0
print(f"files={nf} lines={nl:,} elapsed={el:.1f}s total=${sum(cost.values()):,.2f}")
for b,c in sorted(cost.items(),key=lambda x:-x[1])[:25]:
    print(f"  ${c:9.2f}  msgs={msgs[b]:6d}  {b}")
