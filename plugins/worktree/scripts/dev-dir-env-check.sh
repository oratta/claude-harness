#!/usr/bin/env bash
# dev-dir-env-check.sh — SessionStart hook (#1234)
#
# CLAUDE_HARNESS_DEV_DIR（開発用 clone の場所）が未設定か空のとき、harness のリポジトリ
# （marketplace.json の name が oratta-claude-harness）でだけ 1 行警告する。
# それ以外は無出力。fail-soft: 何が起きても exit 0。

set -uo pipefail

cat >/dev/null 2>&1 || true

[ -n "${CLAUDE_HARNESS_DEV_DIR:-}" ] && exit 0

TOP=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
MP="$TOP/.claude-plugin/marketplace.json"
[ -f "$MP" ] || exit 0

command -v python3 >/dev/null 2>&1 || exit 0
MP="$MP" python3 -I -c '
import json, os, sys
try:
    name = json.load(open(os.environ["MP"])).get("name")
except Exception:
    sys.exit(0)
if name != "oratta-claude-harness":
    sys.exit(0)
msg = ("環境変数 CLAUDE_HARNESS_DEV_DIR（harness の開発用 clone の場所）が未設定です。"
       "worktree を切る手順が止まるので、README の「ローカル開発」の節を見て ~/.claude/settings.json の env に入れてください。")
print(json.dumps({"systemMessage": msg}, ensure_ascii=False))
' 2>/dev/null || true

exit 0
