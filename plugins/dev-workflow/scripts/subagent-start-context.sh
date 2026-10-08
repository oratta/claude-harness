#!/usr/bin/env bash
# SubagentStart hook: dev-workflow の 3 役（worker / reviewer / gate-runner）に、親セッションにしか
# 届いていなかった運用情報を additionalContext で渡す（issue #715）。
#
#   worker / gate-runner: Fable 残量モード・共有枠モード（session-tripwires.sh の
#                         TRIPWIRES_SCOPE=subagent-budget の出力）＋途中計測の閾値の現在値
#   reviewer:             途中計測の閾値の現在値だけ（モデルを選ばないので残量モードは渡さない）
#
# 残量モードの導出式は session-tripwires.sh の 1 か所だけに置き、ここに複製しない。
# 途中計測の扱いの規則は decision-criteria.md「コンテキスト上限（サブエージェントの手渡し）」が
# 正本なので、ここでは hook 実行時の値と案内だけを出し、規則を言い換えない。
#
# agent_type は matcher に加えてここでも照合する（matcher が効かない・手で実行された・別の設定から
# 流用された経路で対象外の役に返さないため）。Agent Teams の teammate 化や命名変更で agent_type が
# 変わる経路、hook が発火しない経路は守らない。
#
# fail-open: 判定できなければ無出力・exit 0（サブエージェントの起動を止めない）。
set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
payload="$(cat)" || exit 0

# 役を判定する（payload は環境変数や引数に載せず stdin で渡す）
role="$(printf '%s' "$payload" | python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
t = d.get("agent_type") if isinstance(d, dict) else None
if isinstance(t, str):
    m = re.fullmatch(r"dev-workflow:(worker|reviewer|gate-runner)", t)
    if m:
        print(m.group(1))
' 2>/dev/null)" || exit 0
[ -n "$role" ] || exit 0

budget=""
if [ "$role" != "reviewer" ] && [ -x "${ROOT}/scripts/session-tripwires.sh" ]; then
  budget="$(TRIPWIRES_SCOPE=subagent-budget "${ROOT}/scripts/session-tripwires.sh" 2>/dev/null)" || budget=""
fi

BUDGET="$budget" python3 <<'PY' 2>/dev/null || exit 0
import json, os

def shown(name, default):
    v = (os.environ.get(name) or "").strip()
    if v == "":
        return f"{name}={default}（既定）"
    if v.isdigit() and int(v) > 0:
        return f"{name}={v}（env）"
    return f"{name}={v!r}（不正な値。途中計測は働かない）"

tripwire = (os.environ.get("DEV_WORKFLOW_CONTEXT_TRIPWIRE") or "on").strip()
lines = ["## 途中計測（このサブエージェント自身のコンテキスト）"]
if tripwire == "off":
    lines.append("- DEV_WORKFLOW_CONTEXT_TRIPWIRE=off（途中計測は全解除されている）")
else:
    lines.append(f"- {shown('DEV_WORKFLOW_CONTEXT_CAP', 150000)} / "
                 f"{shown('DEV_WORKFLOW_CONTEXT_HARD_CAP', 220000)}")
# サブエージェントは ${CLAUDE_PLUGIN_ROOT} を展開できないので、解決済みのパスで案内する
root = os.environ.get("CLAUDE_PLUGIN_ROOT") or "${CLAUDE_PLUGIN_ROOT}"
lines.append("- 通知や強制停止に当たったときの扱いと return の 1 行目の書式の正本は "
             f"`{root}/skills/develop/references/decision-criteria.md`"
             "「コンテキスト上限（サブエージェントの手渡し）」")

parts = []
budget = (os.environ.get("BUDGET") or "").strip()
if budget:
    parts.append(budget)
parts.append("\n".join(lines))

print(json.dumps({"hookSpecificOutput": {"hookEventName": "SubagentStart",
                                         "additionalContext": "\n\n".join(parts)}},
                 ensure_ascii=False))
PY
