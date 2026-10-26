#!/usr/bin/env bash
# Stop hook: 主に判断・確認・操作を求める発言の区切りより上に issue・PR の番号（#数字）が残っているか、
# 番号を書いたのに issue・PR の URL が 1 本も無いとき、ターンを終える前に 1 回だけ差し戻す（issue #1215）。
#
# spec: dev-workflow-owner-message-number-check（設計の理由は openspec の change owner-message-number-check-hook の design）
#
# なぜ unclear-reply-rephrase.sh と別のスクリプトか:
#   あちらは主の発言の前（UserPromptSubmit）に文を差し込む hook で、こちらは Claude の発言のあと（Stop）に
#   停止を拒否する hook。起きる時点も入力の形も返し方も違うので混ぜない。
#
# 判定の要点:
#   - 本文は payload の last_assistant_message。逆引用符 3 つのブロック（閉じが無ければ最後まで）と空の行を除いて並べる。
#     `>` の引用の行は除かない（全行を主が読むので、引用の中の番号も主が探す手間になる）
#   - 1 行目（前後の空白と * を除く）が「主がすること: なし」なら対象外。1 行目が ？/? で終わるか、
#     1 行目の最初の文（URL と引用の中身を除き、。！!？? の最初まで）が ？/? で終わるか、
#     区切り（- が 3 つ以上だけの行）より上の最後の行が答え方の語を含むときだけ対象
#   - URL を取り除いてから #数字 を探す。区切りより上に番号がある（条件 1）か、番号があるのに
#     /issues/<数字> か /pull/<数字> を含む URL が無い（条件 2）と差し戻す
#   - 理由の文は事実と正本の場所だけを書き、正本の文言を写さない（正本を直すときの直す場所を 1 か所に保つ）
#
# 契約:
#   - 1 ターンに 1 回: stop_hook_active が真なら通す（差し戻しで続けたあとの停止）
#   - 全解除: DEV_WORKFLOW_OWNER_NUMBER_CHECK=off
#   - 全経路 fail-soft（判定できなければ無出力・exit 0・標準エラーなし）。セッションを止め続けない
set -uo pipefail

[ "${DEV_WORKFLOW_OWNER_NUMBER_CHECK:-on}" = "off" ] && exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

# --- 速い道: 生の入力に #数字 が無ければ終わる（# と数字は JSON で逃がされない） ---
# パイプで渡さない: GNU grep -q は一致で先に終わり、書き手が SIGPIPE で落ちると pipefail で失敗扱いになる
LC_ALL=C grep -qE '#[0-9]' 2>/dev/null <<<"$INPUT" || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

# Python 本体はヒアドキュメントで変数に読み、-c の引数で渡す。payload は stdin のまま読ませる
# （長い入力を環境変数や引数に載せると ARG_MAX を超える）。/dev/fd/3 で読ませる形は Python 3.9 で
# 複数行の本体が実行されないので使わない（#869）。-I で PYTHON* の環境変数とカレントディレクトリを読まない。
PY_SRC=""
{ IFS= read -r -d '' PY_SRC <<'PY' || true
import json, re, sys

try:
    d = json.loads(sys.stdin.read())
except Exception:
    raise SystemExit(0)
if not isinstance(d, dict):
    raise SystemExit(0)
if d.get("stop_hook_active") is True or "agent_id" in d:
    raise SystemExit(0)
msg = d.get("last_assistant_message")
if not isinstance(msg, str) or not msg:
    raise SystemExit(0)

ANSWER_WORDS = ("と打って", "と打つ", "を押して", "と返して", "と答えて")
URL_RE = re.compile(r"https?://\S+")
ISSUE_URL_RE = re.compile(r"https?://\S*/(?:issues|pull)/[0-9]")
QUOTE_RE = re.compile(r"「[^」]*」|『[^』]*』|“[^”]*”|\"[^\"]*\"")
FIRST_END_RE = re.compile(r"[。！!？?]")
NUM_RE = re.compile(r"#[0-9]+")
SEP_RE = re.compile(r"-{3,}")
NO_ACTION_RE = re.compile(r"主がすること[:：]\s*なし")

# 逆引用符のブロックを除き、空白だけでない行を並べる
lines = []
in_fence = False
for line in msg.splitlines():
    if line.lstrip().startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence or not line.strip():
        continue
    lines.append(line)
if not lines:
    raise SystemExit(0)

first = lines[0].strip().strip("*").strip()
if NO_ACTION_RE.match(first):
    raise SystemExit(0)

sep = next((i for i, l in enumerate(lines) if SEP_RE.fullmatch(l.strip())), None)
above = lines if sep is None else lines[:sep]

# 1 行目の最初の文が質問で終わる場合も質問として数える（従来の「1 行目の末尾が ？/?」は狭めない）。
# URL と引用（「」『』“”""）の中身を除いてから、最初の。！!？? までを最初の文として見る
first_plain = QUOTE_RE.sub("", URL_RE.sub(" ", first))
m_end = FIRST_END_RE.search(first_plain)
is_question = first.endswith(("？", "?")) or bool(m_end and m_end.group(0) in ("？", "?"))
has_answer_line = bool(above) and any(w in above[-1] for w in ANSWER_WORDS)
if not (is_question or has_answer_line):
    raise SystemExit(0)

def numbers(line):
    return NUM_RE.findall(URL_RE.sub(" ", line))

hits = [(i + 1, numbers(l)) for i, l in enumerate(above)]
hits = [(n, nums) for n, nums in hits if nums]
any_number = bool(hits) or any(numbers(l) for l in lines)
no_url = any_number and not any(ISSUE_URL_RE.search(l) for l in lines)

if not hits and not no_url:
    raise SystemExit(0)

parts = ["[dev-workflow 主への発言の差し戻し] 主に判断・確認・操作を求める発言に、次の点がある。"]
if hits:
    parts.append("区切りより上に issue・PR の番号がある: " + " / ".join(
        "行 %d: %s" % (n, " ".join(nums)) for n, nums in hits) + "（逆引用符のブロックと空の行を除いて上から数えた順）。")
if no_url:
    parts.append("issue・PR の URL が 1 本も無い。")
parts.append(
    "~/.claude/output-styles/readable.md（Output Style readable）の節 3 の「ほかの決まり」の段落と、"
    "1 行目の書き分けの段落に従って、発言全体を書き直して出し直す。"
    "この差し戻しはこのターンで 1 回だけで、出し直した発言は確かめない。"
    "主に判断・確認・操作を求める発言でなければ、そのまま終えてよい。"
)
print(json.dumps({"decision": "block", "reason": "\n".join(parts)}, ensure_ascii=False))
PY
} 2>/dev/null
# 本体を読めなかった（ヒアドキュメントの一時ファイルを作れない等）ときは判定せずに通す（fail-soft）
[ -n "$PY_SRC" ] || exit 0

printf '%s' "$INPUT" | python3 -I -c "$PY_SRC" 2>/dev/null || true
exit 0
