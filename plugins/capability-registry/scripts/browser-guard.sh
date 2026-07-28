#!/usr/bin/env bash
# PreToolUse hook: ブラウザ系 MCP ツール呼び出しのセッション初回に、
# CLI 代替の検討を促す注意喚起を additionalContext で注入する。
# deny はしない（permissionDecision: allow）。全経路 fail-soft（exit 0）で
# ツール実行を絶対にブロックしない。
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"

SESSION_ID="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("session_id") or "")
except Exception:
    pass' 2>/dev/null || true)"
# マーカーファイル名に使うため英数と - _ . 以外を落とす
SESSION_ID="$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9._-')"

# session_id が取れなければ重複抑止できないため注入しない
[ -n "$SESSION_ID" ] || exit 0

MARKER="${TMPDIR:-/tmp}/capability-registry-warned-${SESSION_ID}"
[ -e "$MARKER" ] && exit 0
touch "$MARKER" 2>/dev/null || exit 0

python3 <<'PY'
import json
ctx = (
    "ブラウザツールを使おうとしています。実行前に capability-registry スキルの索引で確認してください: "
    "(1) この操作に CLI 代替は無いか（索引に無いサービスならネガティブエントリも見る）、"
    "(2) 認証・トークンは ${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh <service> で取れないか"
    "（未登録は exit 44 → ブラウザに行かず主に登録を依頼）、"
    "(3) それでもブラウザが必要なら『CLI で不可能な理由』を一言明示してから進むこと。"
    "索引のブラウザ必須例外に該当する操作なら、そのまま進んで構いません。"
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "additionalContext": ctx,
    }
}, ensure_ascii=False))
PY
exit 0
