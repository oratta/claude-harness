#!/usr/bin/env python3
"""ブランチ名 -> API換算コスト。~/.claude/projects/**/*.jsonl を読む。"""
import json, os, sys, glob, subprocess, time
from collections import defaultdict

# $/MTok: (input, output, cache_write_5m, cache_write_1h, cache_read)
P = {
    "claude-fable-5-1": (10, 50, 12.5, 20, 0.25),
    "claude-fable-5":   (10, 50, 12.5, 20, 1.0),
    "claude-opus-5":    (5, 25, 6.25, 10, 0.5),
    "claude-opus-4-8":  (5, 25, 6.25, 10, 0.5),
    "claude-opus-4-7":  (5, 25, 6.25, 10, 0.5),
    "claude-opus-4-6":  (5, 25, 6.25, 10, 0.5),
    "claude-sonnet-5":  (2, 10, 2.5, 4, 0.2),
    "claude-sonnet-4-6":(3, 15, 3.75, 6, 0.3),
    "claude-haiku-4-5": (1, 5, 1.25, 2, 0.1),
}
def rate(m):
    for k, v in P.items():
        if m.startswith(k): return v
    return None

branch = sys.argv[1]
root = os.path.expanduser("~/.claude/projects")
t0 = time.time()
# 事前絞り込み: ブランチ名を含むファイルだけ開く
files = subprocess.run(["grep","-rl","--include=*.jsonl","-F",branch,root],
                       capture_output=True, text=True).stdout.split()
t_grep = time.time()-t0

agg = defaultdict(lambda: [0,0,0,0,0,0.0,0])  # in,out,cw5,cw1h,cr,cost,msgs
seen = set()
for f in files:
    with open(f, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"assistant"' not in line: continue
            try: d = json.loads(line)
            except Exception: continue
            if d.get("type") != "assistant" or d.get("gitBranch") != branch: continue
            rid = d.get("requestId") or d.get("uuid")
            if rid in seen: continue
            seen.add(rid)
            m = d.get("message", {}); u = m.get("usage") or {}
            r = rate(m.get("model",""))
            if not r: continue
            cc = u.get("cache_creation") or {}
            cw5 = cc.get("ephemeral_5m_input_tokens", 0)
            cw1 = cc.get("ephemeral_1h_input_tokens", 0)
            if not (cw5 or cw1): cw5 = u.get("cache_creation_input_tokens", 0)
            i = u.get("input_tokens",0); o = u.get("output_tokens",0)
            cr = u.get("cache_read_input_tokens",0)
            cost = (i*r[0] + o*r[1] + cw5*r[2] + cw1*r[3] + cr*r[4]) / 1e6
            a = agg[m.get("model")]
            a[0]+=i; a[1]+=o; a[2]+=cw5; a[3]+=cw1; a[4]+=cr; a[5]+=cost; a[6]+=1
el = time.time()-t0
tot = sum(a[5] for a in agg.values())
print(f"branch={branch}  files_scanned={len(files)}  grep={t_grep:.2f}s  total={el:.2f}s")
for m, a in sorted(agg.items(), key=lambda x:-x[1][5]):
    print(f"  {m:22s} msgs={a[6]:5d}  in={a[0]:>9,}  out={a[1]:>9,}  cw={a[2]+a[3]:>11,}  cr={a[4]:>13,}  ${a[5]:8.2f}")
print(f"  TOTAL ${tot:.2f}  (¥{tot*150:,.0f} @150)")
