#!/usr/bin/env bash
# UserPromptSubmit hook: 主の発言に、直前の説明が伝わっていないことを示す語があるときだけ、
# 正本（~/.claude/output-styles/readable.md の節 3）の型で言い直すよう促す文を差し込む（issue #1184）。
#
# spec: dev-workflow-unclear-reply-rephrase（設計の理由は openspec の change unclear-reply-rephrase-hook の design）
#
# なぜ prompt-tripwires-refresh.sh と別のスクリプトか:
#   あちらはプラグインの更新を見て再注入する別の責務で、状態ファイルを持つ。混ぜると片方を直すときに
#   もう片方のテストが巻き込まれる。この hook は状態を持たない。
#
# 語の選び方の要点:
#   - 語は下の WORDS に 1 か所だけ置く（python 側にも同じ一覧を渡す）。並びが「語の一覧の順」で、
#     複数の語に当たったときは、この順で最初に当たった語を示す（長くて意味の分かる「意味…」を先頭に置く）
#   - 「わからない」だけの形と「意味が」だけの形は入れない（調査の依頼や「意味がない」で当たるため）
#   - 誤って当たったとき（「この関数を説明して」など）の害は、差し込む文の最後の
#     「新しい依頼ならその依頼に答える」で抑える。取りこぼした言い方が見つかったら WORDS に足す
#   - 逆引用符 3 つのブロック（閉じが無ければ発言の終わりまで）と `>` の引用の行は探さない
#
# 契約:
#   - 毎発言で走るので、生の入力に grep を当て、語にも \u の逃がしにも当たらなければ python3 を起動しない
#   - 全経路 fail-soft（無出力・exit 0・標準エラーなし）。発言の送信は絶対に止めない
set -uo pipefail

WORDS='意味わから
意味分から
意味がわから
意味が分から
意味不明
わからん
分からん
解らん
わかんない
分かんない
説明して
読みにくい
読み難い
伝わらない
伝わってない
何言って
なに言って'

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

# --- 速い道: 生の入力に語も \u の逃がしも無ければ終わる ---
WORDS_RE="$(printf '%s' "$WORDS" | tr '\n' '|')"
printf '%s' "$INPUT" | LC_ALL=C grep -qE -e "$WORDS_RE" -e '\\u[0-9a-fA-F]{4}' 2>/dev/null || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

PY_CODE='
import json, os, sys

try:
    d = json.loads(sys.stdin.read())
except Exception:
    raise SystemExit(0)
if not isinstance(d, dict):
    raise SystemExit(0)
prompt = d.get("prompt")
if not isinstance(prompt, str) or not prompt:
    raise SystemExit(0)

words = [w for w in os.environ.get("UNCLEAR_WORDS", "").split("\n") if w]

# 探す行を集める。逆引用符 3 つで始まる行から次の同じ条件の行まで（閉じが無ければ最後まで）と、
# `>` で始まる引用の行を外す。
kept = []
in_fence = False
for line in prompt.splitlines():
    head = line.lstrip()
    if head.startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence or head.startswith(">"):
        continue
    kept.append(line)
text = "\n".join(kept)

hit = next((w for w in words if w in text), None)
if hit is None:
    raise SystemExit(0)

ctx = (
    "主の発言に、直前の説明が伝わっていないことを示す語（「" + hit + "」）がある。"
    "直前の説明は伝わっていないものとして扱い、~/.claude/output-styles/readable.md"
    "（Output Style readable）の節 3 の型で、子の作業の言葉や仕組みの名前を使わずに言い直す。"
    "主の発言が新しい依頼なら、その依頼に答える。"
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": ctx,
    }
}, ensure_ascii=False))
'

printf '%s' "$INPUT" | UNCLEAR_WORDS="$WORDS" python3 -I -c "$PY_CODE" 2>/dev/null || true
exit 0
