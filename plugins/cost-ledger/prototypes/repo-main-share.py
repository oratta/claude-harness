#!/usr/bin/env python3
import json, os, glob, subprocess, time
from collections import defaultdict
P={"claude-fable-5-1":(10,50,12.5,20,0.25),"claude-fable-5":(10,50,12.5,20,1.0),
   "claude-opus-5":(5,25,6.25,10,0.5),"claude-opus-4-8":(5,25,6.25,10,0.5),
   "claude-opus-4-7":(5,25,6.25,10,0.5),"claude-opus-4-6":(5,25,6.25,10,0.5),
   "claude-sonnet-5":(2,10,2.5,4,0.2),"claude-sonnet-4-6":(3,15,3.75,6,0.3),
   "claude-haiku-4-5":(1,5,1.25,2,0.1)}
def rate(m):
    for k,v in P.items():
        if (m or "").startswith(k): return v
_cache={}
def repo_of(cwd):
    if cwd in _cache: return _cache[cwd]
    r=None
    try:
        out=subprocess.run(["git","-C",cwd,"rev-parse","--path-format=absolute","--git-common-dir"],
                           capture_output=True,text=True,timeout=5)
        if out.returncode==0:
            r=os.path.dirname(out.stdout.strip()).replace(os.path.expanduser("~"),"~")
    except Exception: pass
    if not r:
        # 消えた worktree 等はパス規則で推定
        parts=cwd.split("/")
        if "workspaces" in parts:
            i=parts.index("workspaces")
            r=parts[i+1] if len(parts)>i+1 else "?"
        else:
            r="(unresolved)"
    _cache[cwd]=r
    return r
t0=time.time()
main_c=defaultdict(float); br_c=defaultdict(float); non_c=defaultdict(float); branches=defaultdict(set); seen=set()
for f in glob.glob(os.path.expanduser("~/.claude/projects/**/*.jsonl"),recursive=True):
    for line in open(f,encoding="utf-8",errors="replace"):
        if '"assistant"' not in line: continue
        try: d=json.loads(line)
        except Exception: continue
        if d.get("type")!="assistant": continue
        rid=d.get("requestId") or d.get("uuid")
        if rid in seen: continue
        seen.add(rid)
        m=d.get("message",{}); u=m.get("usage") or {}; r=rate(m.get("model"))
        if not r: continue
        cc=u.get("cache_creation") or {}
        cw5=cc.get("ephemeral_5m_input_tokens",0); cw1=cc.get("ephemeral_1h_input_tokens",0)
        if not (cw5 or cw1): cw5=u.get("cache_creation_input_tokens",0)
        c=(u.get("input_tokens",0)*r[0]+u.get("output_tokens",0)*r[1]+cw5*r[2]+cw1*r[3]
           +u.get("cache_read_input_tokens",0)*r[4])/1e6
        b=d.get("gitBranch") or ""
        repo=repo_of(d.get("cwd") or "")
        if b=="": non_c[repo]+=c
        elif b in ("main","master"): main_c[repo]+=c
        else:
            br_c[repo]+=c; branches[repo].add(b)
print(f"elapsed={time.time()-t0:.1f}s  unique cwd={len(_cache)}")
print(f"{'repo':44s} {'total':>9s} {'main':>9s} {'nobr':>8s} {'branch':>9s} {'main%':>6s} {'#br':>4s}")
rows=sorted(set(list(main_c)+list(br_c)+list(non_c)),key=lambda r:-(main_c[r]+br_c[r]+non_c[r]))
for r in rows[:22]:
    t=main_c[r]+br_c[r]+non_c[r]
    print(f"{r[-44:]:44s} ${t:8.2f} ${main_c[r]:8.2f} ${non_c[r]:7.2f} ${br_c[r]:8.2f} {main_c[r]/t*100:5.0f}% {len(branches[r]):4d}")
