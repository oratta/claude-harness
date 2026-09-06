#!/usr/bin/env bash
# 名前付きサブエージェント（Agent ツールで name を付けて spawn したもの）の
# 現在のコンテキスト量を、そのトランスクリプトの最後の usage から測る。
#
#   subagent-context.sh <agent-name> [--cap <tokens>] [--projects <dir>]
#
# 出力（stdout, 1 行 JSON）:
#   {"agent":"W-123","file":"...jsonl","context_tokens":181234,"calls":57,
#    "cap":150000,"over_cap":true}
# exit code: 0 = 上限以内 / 2 = 上限超過（over_cap）/ 1 = トランスクリプトが見つからない・読めない
#
# 測り方: トランスクリプトの最後の assistant レコードの
#   input_tokens + cache_creation_input_tokens + cache_read_input_tokens
# ＝ そのリクエストがモデルに読ませたコンテキスト全量。develop の本体は W / G を
# SendMessage で再開する前にこれを実行し、上限（既定 DEV_WORKFLOW_CONTEXT_CAP=150000）を
# 超えていたら再開せず、手渡し（前回 return を引き継いだ新しい W）に切り替える
# （正本: skills/develop/references/decision-criteria.md「コンテキスト上限」）。
#
# 探索: ${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*<name>*.jsonl
# 同名が複数あれば、cwd が現在のディレクトリと一致するものを優先し、次に更新時刻が新しいもの。
set -uo pipefail

name=""
cap="${DEV_WORKFLOW_CONTEXT_CAP:-150000}"
projects="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
while [ $# -gt 0 ]; do
  case "$1" in
    --cap) cap="$2"; shift 2 ;;
    --projects) projects="$2"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) if [ -z "$name" ]; then name="$1"; shift; else echo "unknown arg: $1" >&2; exit 1; fi ;;
  esac
done
if [ -z "$name" ]; then echo "usage: subagent-context.sh <agent-name> [--cap N]" >&2; exit 1; fi
command -v python3 >/dev/null 2>&1 || { echo '{"error":"python3 not found"}'; exit 1; }

NAME="$name" CAP="$cap" PROJECTS="$projects" CWD="$PWD" python3 <<'PY'
import glob, json, os, sys

name = os.environ["NAME"]
cap = int(os.environ["CAP"])
projects = os.environ["PROJECTS"]
cwd = os.environ["CWD"]

# Agent ツールはトランスクリプトを agent-<prefix><name>-<hash>.jsonl に置く（prefix は 1 文字のことがある）
pattern = os.path.join(projects, "*", "*", "subagents", f"agent-*{name}-*.jsonl")
files = glob.glob(pattern) + glob.glob(os.path.join(projects, "*", "*", "subagents", f"agent-*{name}.jsonl"))
files = sorted(set(files), key=lambda p: os.path.getmtime(p), reverse=True)
if not files:
    print(json.dumps({"agent": name, "error": "transcript not found", "pattern": pattern}))
    sys.exit(1)

def first_cwd(path):
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                if d.get("cwd"):
                    return d["cwd"]
    except Exception:
        pass
    return None

chosen = next((p for p in files if first_cwd(p) == cwd), files[0])

ctx = None
calls = 0
try:
    with open(chosen, encoding="utf-8") as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("type") != "assistant":
                continue
            u = (d.get("message") or {}).get("usage") or {}
            if not u:
                continue
            calls += 1
            ctx = int(u.get("input_tokens") or 0) + int(u.get("cache_creation_input_tokens") or 0) \
                + int(u.get("cache_read_input_tokens") or 0)
except Exception as e:
    print(json.dumps({"agent": name, "file": chosen, "error": str(e)}))
    sys.exit(1)

if ctx is None:
    print(json.dumps({"agent": name, "file": chosen, "error": "no assistant usage yet", "calls": 0}))
    sys.exit(1)

over = ctx > cap
print(json.dumps({"agent": name, "file": chosen, "context_tokens": ctx, "calls": calls,
                  "cap": cap, "over_cap": over}, ensure_ascii=False))
sys.exit(2 if over else 0)
PY
