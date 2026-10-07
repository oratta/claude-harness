#!/usr/bin/env bash
# owner-reply-check.sh — 主が会話で返した許容の発言が、そのセッションの会話ログに主の発言として実在するかを確かめる。
#
# 使い方: owner-reply-check.sh <セッション ID> <原文>
#   読むのは ${OWNER_REPLY_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/<セッション ID>.jsonl だけ
#   （<セッション ID>/subagents/ の下は読まない）。OWNER_REPLY_PROJECTS_DIR はテスト用の差し替え口。
# 比べ方: 原文と各発言の本文の連続する空白（改行を含む）を 1 個の空白にまとめ、前後の空白を落として部分一致。
# 主の発言として数える行（すべて満たすもの）:
#   1. type が "user"            2. isSidechain が true でない      3. isMeta が true でない
#   4. origin があるなら origin.kind が "human"
#   5. message.content が文字列、または type:"text" の要素だけの配列（tool_result を含む配列は数えない）
#   6. 本文が "Another Claude session sent a message" で始まらず、"<teammate-message" を含まない
#   7. 本文が <bash-stdout> / <bash-stderr> / <local-command-stdout> / <local-command-stderr> で始まらない
#   <command-args>（スラッシュコマンドの引数）と <bash-input>（主が ! で打った入力）はタグごと本文として比べる。
# 出力: 一致した発言ごとに "MATCH: <timestamp> <空白をまとめた本文の全文>"、最後に "MATCHES=<件数>"
# 終了コード: 0 = 1 件以上一致 / 1 = 一致なし / 2 = 引数の不備・UUID でない ID・空の原文・会話ログなし・python3 なし
#   （2 は「確かめられない」。呼び出し側は 1 と同じく通さない側に倒す）
#
# 許容の意思は見ない（部分一致なので「許容しない」の一部の「許容」も一致する）。呼び出し側（pr-review-gate 手順 5）が
# 記録の日時と同じ timestamp の MATCH 行の全文で読む。会話ログの改変と、Orca の親セッションが子のターミナルに
# 打ち込んだ文（origin.kind が human で残る）は区別できない（spec の守備範囲を参照）。
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <session-id> <excerpt>" >&2
  exit 2
fi

session_id="$1"
excerpt="$2"

if ! [[ "$session_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  echo "owner-reply-check: session id is not a UUID: $session_id" >&2
  exit 2
fi

if [ -z "${excerpt//[[:space:]]/}" ]; then
  echo "owner-reply-check: excerpt is blank" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "owner-reply-check: python3 not found" >&2
  exit 2
fi

projects_dir="${OWNER_REPLY_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}"

logs=()
for f in "$projects_dir"/*/"$session_id".jsonl; do
  [ -f "$f" ] && logs+=("$f")
done
if [ "${#logs[@]}" -eq 0 ]; then
  echo "owner-reply-check: no conversation log for session $session_id under $projects_dir" >&2
  exit 2
fi

PYTHONDONTWRITEBYTECODE=1 python3 -I - "$excerpt" "${logs[@]}" <<'PY'
import json
import re
import sys

FORWARD_PREFIX = "Another Claude session sent a message"
OUTPUT_PREFIXES = ("<bash-stdout>", "<bash-stderr>", "<local-command-stdout>", "<local-command-stderr>")


def norm(text):
    return re.sub(r"\s+", " ", text).strip()


def owner_text(rec):
    """主の発言なら本文を、そうでなければ None を返す。"""
    if not isinstance(rec, dict) or rec.get("type") != "user":
        return None
    if rec.get("isSidechain") is True or rec.get("isMeta") is True:
        return None
    if "origin" in rec and rec.get("origin") is not None:
        origin = rec.get("origin")
        if not isinstance(origin, dict) or origin.get("kind") != "human":
            return None
    message = rec.get("message")
    if not isinstance(message, dict):
        return None
    content = message.get("content")
    if isinstance(content, str):
        text = content
    elif isinstance(content, list) and content:
        parts = []
        for item in content:
            if not isinstance(item, dict) or item.get("type") != "text" or not isinstance(item.get("text"), str):
                return None
            parts.append(item["text"])
        text = "\n".join(parts)
    else:
        return None
    stripped = text.lstrip()
    if stripped.startswith(FORWARD_PREFIX) or "<teammate-message" in text:
        return None
    if stripped.startswith(OUTPUT_PREFIXES):
        return None
    return text


excerpt = norm(sys.argv[1])
matches = 0
for path in sys.argv[2:]:
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            text = owner_text(rec)
            if text is None:
                continue
            body = norm(text)
            if excerpt in body:
                matches += 1
                print("MATCH: %s %s" % (rec.get("timestamp", ""), body))
print("MATCHES=%d" % matches)
sys.exit(0 if matches else 1)
PY
