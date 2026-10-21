#!/usr/bin/env bash
# 名前付きサブエージェント（Agent ツールで name を付けて spawn したもの）の
# 現在のコンテキスト量を、そのトランスクリプトの最後の usage から測る。
#
#   subagent-context.sh <agent-name> [--cap <tokens>] [--projects <dir>]
#   subagent-context.sh <agent-name> --stop-since <epoch秒>   # 停止確認が返らないときの終端の判定
#
# 出力（stdout, 1 行 JSON）:
#   {"agent":"W-123","file":"...jsonl","context_tokens":181234,"calls":57,
#    "cap":150000,"over_cap":true}
# exit code: 0 = 上限以内 / 2 = 上限超過（over_cap）/ 1 = トランスクリプトが見つからない・読めない
#            3 = （--stop-since 指定時のみ）停止確認が返らないときの終端に達した
# --stop-since: 前任へ停止を指示した時刻。経過時間とトランスクリプトの無更新時間が、どちらも
#   閾値（DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT / DEV_WORKFLOW_STOP_CONFIRM_STALL の秒数）以上なら exit 3。
#   この指定時は上限超過で exit 2 にしない（over_cap は出力に残る）。終端の帰結は正本（下）に従う。
#
# 測り方: トランスクリプトの最後の assistant レコードの
#   input_tokens + cache_creation_input_tokens + cache_read_input_tokens
# ＝ そのリクエストがモデルに読ませたコンテキスト全量。develop の本体は W / G を
# SendMessage で再開する前にこれを実行する（上限は既定 DEV_WORKFLOW_CONTEXT_CAP=150000）。
# exit 2 を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい
# 条件・return の 1 行目の宣言・前任が動作中のまま交代させる手順）の正本は
# skills/develop/references/decision-criteria.md「コンテキスト上限（サブエージェントの手渡し）」。
# このスクリプトには書かない。正本を読むまで手渡さない。
#
# 探索: ${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*<name>*.jsonl
# `--file <path>` はそのファイルを直接測る（worktree 隔離はファイル名に名前が入らず名前 glob で見つからない）。
# 同名が複数あれば、cwd が現在のディレクトリと一致するものを優先し、次に更新時刻が新しいもの。
set -uo pipefail

name=""
file=""
cap="${DEV_WORKFLOW_CONTEXT_CAP:-150000}"
stop_since=""
stop_timeout="${DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT:-1800}"
stop_stall="${DEV_WORKFLOW_STOP_CONFIRM_STALL:-600}"
projects="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
while [ $# -gt 0 ]; do
  case "$1" in
    --cap)
      if [ -z "${2-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then echo '{"error":"--cap needs a positive integer"}'; exit 1; fi
      cap="$2"; shift 2 ;;
    --stop-since)
      if [ -z "${2-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then echo '{"error":"--stop-since needs epoch seconds"}'; exit 1; fi
      stop_since="$2"; shift 2 ;;
    --projects)
      if [ -z "${2-}" ]; then echo '{"error":"--projects needs a directory"}'; exit 1; fi
      projects="$2"; shift 2 ;;
    --file)
      if [ -z "${2-}" ]; then echo '{"error":"--file needs a path"}'; exit 1; fi
      file="$2"; shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) if [ -z "$name" ]; then name="$1"; shift; else echo "unknown arg: $1" >&2; exit 1; fi ;;
  esac
done
if [ -n "$file" ] && [ -z "$name" ]; then
  # agent はファイル名から導く: agent-<何か>.jsonl → <何か>
  name="$(basename "$file")"; name="${name#agent-}"; name="${name%.jsonl}"
fi
if [ -z "$name" ]; then echo "usage: subagent-context.sh <agent-name> [--cap N] | --file <path> [--cap N]" >&2; exit 1; fi
if ! [[ "$cap" =~ ^[0-9]+$ ]]; then echo '{"error":"DEV_WORKFLOW_CONTEXT_CAP must be a positive integer"}'; exit 1; fi
for v in "$stop_timeout" "$stop_stall"; do
  if ! [[ "$v" =~ ^[0-9]+$ ]]; then echo '{"error":"DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT / _STALL must be positive integers"}'; exit 1; fi
done
command -v python3 >/dev/null 2>&1 || { echo '{"error":"python3 not found"}'; exit 1; }

NAME="$name" CAP="$cap" PROJECTS="$projects" CWD="$PWD" FILE="$file" STOP_SINCE="$stop_since" STOP_TIMEOUT="$stop_timeout" STOP_STALL="$stop_stall" python3 <<'PY'
import glob, json, os, sys

name = os.environ["NAME"]
cap = int(os.environ["CAP"])
projects = os.environ["PROJECTS"]
cwd = os.environ["CWD"]

direct = os.environ.get("FILE") or ""
if direct:
    # --file: 名前 glob を使わずそのファイルを測る（worktree 隔離では名前で引けない。#243）
    if not os.path.isfile(direct):
        print(json.dumps({"agent": name, "error": "transcript not found", "file": direct}))
        sys.exit(1)
    files = [direct]
else:
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
                if isinstance(d, dict) and d.get("cwd"):
                    return d["cwd"]
    except Exception:
        pass
    return None

chosen = files[0] if direct else next((p for p in files if first_cwd(p) == cwd), files[0])

ctx = None
calls = 0
try:
    with open(chosen, encoding="utf-8") as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            # 壊れた行・辞書でないレコード（null 等）は読み飛ばす。最後の usage を取り逃がさないため
            if not isinstance(d, dict) or d.get("type") != "assistant":
                continue
            msg = d.get("message")
            u = msg.get("usage") if isinstance(msg, dict) else None
            if not isinstance(u, dict):
                continue
            def n(k):
                v = u.get(k)
                return int(v) if isinstance(v, (int, float)) else 0
            calls += 1
            ctx = n("input_tokens") + n("cache_creation_input_tokens") + n("cache_read_input_tokens")
except Exception as e:
    print(json.dumps({"agent": name, "file": chosen, "error": str(e)}))
    sys.exit(1)

if ctx is None:
    print(json.dumps({"agent": name, "file": chosen, "error": "no assistant usage yet", "calls": 0}))
    sys.exit(1)

over = ctx > cap
out = {"agent": name, "file": chosen, "context_tokens": ctx, "calls": calls,
       "cap": cap, "over_cap": over}
stop_since = os.environ.get("STOP_SINCE") or ""
if stop_since:
    import time
    now = time.time()
    since_stop = int(now - int(stop_since))
    idle = int(now - os.path.getmtime(chosen))
    timeout = int(os.environ["STOP_TIMEOUT"])
    stall = int(os.environ["STOP_STALL"])
    terminal = since_stop >= timeout and idle >= stall
    out.update({"since_stop_sec": since_stop, "transcript_idle_sec": idle,
                "stop_timeout": timeout, "stop_stall": stall, "unconfirmed_terminal": terminal})
    print(json.dumps(out, ensure_ascii=False))
    sys.exit(3 if terminal else 0)
print(json.dumps(out, ensure_ascii=False))
sys.exit(2 if over else 0)
PY
