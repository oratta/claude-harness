#!/usr/bin/env bash
# SessionStart hook: 昇格トリップワイヤーの常駐ルールをセッション文脈に注入する。
# 本文の single source of truth は templates/escalation-tripwires.md（複製を持たない）。
# テンプレート欠損・節の抽出失敗時は無出力・exit 0（セッション開始をブロックしない）。
set -euo pipefail

TEMPLATE="${CLAUDE_PLUGIN_ROOT:-}/templates/escalation-tripwires.md"
[ -f "$TEMPLATE" ] || exit 0

python3 - "$TEMPLATE" <<'PY'
import json, re, sys
try:
    text = open(sys.argv[1], encoding="utf-8").read()
    m = re.search(r"^## 昇格トリップワイヤー.*", text, flags=re.S | re.M)
    if m:
        body = m.group(0).strip()
        if body:
            print(json.dumps({"additionalContext": body}, ensure_ascii=False))
except Exception:
    pass  # fail-soft
PY
