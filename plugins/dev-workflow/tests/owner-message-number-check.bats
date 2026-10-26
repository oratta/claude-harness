#!/usr/bin/env bats
#
# Stop hook: 主に判断・確認・操作を求める発言の区切りより上に issue・PR の番号が残っているか、
# 番号を書いたのに issue・PR の URL が無いとき、1 ターンに 1 回だけ差し戻す（issue #1215）。
# どの入力でもセッションを止め続けない（判定できなければ無出力・exit 0）。
#
# spec: dev-workflow-owner-message-number-check
#
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。
# 否定検査と単独の [[ ]] は書かず、has / lacks / silent の関数で検査する
# （openspec/specs/bats-assertion-guard/spec.md）。

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/owner-message-number-check.sh"
  CANON="${REPO_ROOT}/output-styles/readable.md"
  PAYLOAD="${BATS_TEST_TMPDIR}/payload.json"
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$HOME"
  unset DEV_WORKFLOW_OWNER_NUMBER_CHECK
}

NO_URL='issue・PR の URL が 1 本も無い'

# msg_of <本文> [stop_hook_active (0|1)] [agent (0|1)] — Stop の payload を書く（本文は標準入力で渡す）
msg_of() {
  printf '%s' "$1" | SHA="${2:-0}" AGENT="${3:-0}" python3 -I -c '
import json, os, sys
msg = sys.stdin.buffer.read().decode("utf-8")
d = {"session_id": "s1", "hook_event_name": "Stop", "transcript_path": "/tmp/x.jsonl",
     "cwd": "/tmp", "permission_mode": "default", "prompt_id": "p1",
     "stop_hook_active": os.environ["SHA"] == "1", "last_assistant_message": msg}
if os.environ["AGENT"] == "1":
    d["agent_id"] = "a1"
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
' "$PAYLOAD"
}

raw() {
  printf '%s' "$1" > "$PAYLOAD"
}

run_hook() {
  run --separate-stderr bash -c "'$SCRIPT' < '$PAYLOAD'"
}

# reason_of — 直前の run の標準出力から reason を取り出す。
# exit 0・標準エラー空・1 行・キーの集合が decision と reason だけ・decision が block、も確かめる。
reason_of() {
  [ "$status" -eq 0 ] || { echo "status=$status" >&2; return 1; }
  [ -z "$stderr" ] || { echo "stderr=$stderr" >&2; return 1; }
  [ "${#lines[@]}" -eq 1 ] || { echo "lines=${#lines[@]} output=$output" >&2; return 1; }
  printf '%s' "$output" | python3 -I -c '
import json, sys
d = json.loads(sys.stdin.read())
assert isinstance(d, dict), d
assert set(d) == {"decision", "reason"}, sorted(d)
assert d["decision"] == "block", d
r = d["reason"]
assert isinstance(r, str) and r.strip(), d
sys.stdout.write(r)
'
}

silent() {
  [ "$status" -eq 0 ] || { echo "status=$status" >&2; return 1; }
  [ -z "$output" ] || { echo "output=$output" >&2; return 1; }
  [ -z "$stderr" ] || { echo "stderr=$stderr" >&2; return 1; }
}

has() {
  case "$1" in *"$2"*) return 0 ;; esac
  echo "missing: $2 in: $1" >&2
  return 1
}

lacks() {
  case "$1" in *"$2"*) echo "unexpected: $2 in: $1" >&2; return 1 ;; esac
  return 0
}

nl() { printf '%s\n' "$@"; }

# ---------- 配線 ----------

@test "hooks.json: Stop has exactly one entry that runs the check without matcher or timeout" {
  python3 -I - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]["Stop"]
assert len(d) == 1, d
e = d[0]
assert "matcher" not in e and "timeout" not in e, e
assert len(e["hooks"]) == 1, e
h = e["hooks"][0]
assert h["type"] == "command", h
assert "${CLAUDE_PLUGIN_ROOT}" in h["command"], h
assert "scripts/owner-message-number-check.sh" in h["command"], h
assert "matcher" not in h and "timeout" not in h, h
PY
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "script: python3 is started with -I" {
  run grep -nE '(^|[^[:alnum:]_./-])python3([[:space:]]|$)' "$SCRIPT"
  [ "$status" -eq 0 ]
  local line body
  while IFS= read -r line; do
    body="${line#*:}"
    body="${body#"${body%%[![:space:]]*}"}"
    case "$body" in '#'*) continue ;; esac
    case "$line" in
      *"command -v python3"*) ;;
      *"python3 -I"*) ;;
      *) echo "python3 without -I: $line" >&2; return 1 ;;
    esac
  done <<< "$output"
}

# ---------- 受け入れ条件 ----------

@test "AC1: a question starting with PR #1712 and no link is sent back and names #1712" {
  msg_of "$(nl 'PR #1712 のリスクを許容しますか？' 'よければ『OK』と打ってください。')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 1: #1712'
  has "$r" "$NO_URL"
}

@test "AC2: numbers only below the separator and inside a full URL are not sent back" {
  msg_of "$(nl '子が書いた手順書をマージしてよいですか？' 'よければ『OK』と打ってください。' '---' '経緯: #1209 で決まりを直した。' 'https://github.com/oratta/claude-harness/pull/1712')"
  run_hook
  silent
}

@test "AC3: a no-action report without numbers is not sent back" {
  msg_of "$(nl '主がすること: なし' '手順書をマージした。')"
  run_hook
  silent
}

@test "AC4: the second stop in the same turn is not sent back" {
  msg_of "$(nl 'PR #1712 のリスクを許容しますか？' 'よければ『OK』と打ってください。')"
  run_hook
  reason_of >/dev/null
  msg_of "$(nl 'PR #1712 のリスクを許容しますか？' 'よければ『OK』と打ってください。')" 1
  run_hook
  silent
}

# ---------- 本文の読み方 ----------

@test "body: lines in a backtick fence count neither as the first line nor as numbers" {
  msg_of "$(nl '```' '#42 をどうしますか？' '```' 'テストは通った。')"
  run_hook
  silent
}

@test "body: an unclosed fence hides the rest of the message" {
  msg_of "$(nl 'この変更を入れてよいですか？' 'https://github.com/o/r/pull/1' '```bash' 'echo #42')"
  run_hook
  silent
}

@test "body: numbers on a quoted line are counted" {
  msg_of "$(nl 'この手順書を入れてよいですか？' '> #1712 の手順')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 2: #1712'
}

@test "body: blank lines are not counted in the line order" {
  msg_of "$(nl 'この手順書を入れてよいですか？' '' '   ' '#7 を見て。' 'https://github.com/o/r/issues/7')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 2: #7'
  lacks "$r" "$NO_URL"
}

@test "first line: a bold question is treated as a question" {
  msg_of '**PR #1712 を入れてよいですか？**'
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 1: #1712'
}

@test "first line: an ASCII question mark also counts" {
  msg_of 'Merge #3?'
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 1: #3'
}

@test "first line: a question followed by more sentences on the same line is a target" {
  msg_of "$(nl 'PR #1330 を GitHub でマージしてもらえますか？ マージすると、子 #1303 の修正が main に入ります。' 'よければ下の PR のページでマージしてください。')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 1: #1330 #1303'
}

@test "first line: a report sentence before a final question stays a target" {
  msg_of '#1330 をマージした。続けて #1303 も見ますか？'
  run_hook
  reason_of >/dev/null
}

@test "first line: a question quoted inside an answer is not a target" {
  msg_of '表示は「PR #1330 をマージしますか？」です。'
  run_hook
  silent
}

@test "first line: a question quoted inside a report is not a target" {
  msg_of '#1330 に「マージしますか？」という確認を追加しました。'
  run_hook
  silent
}

@test "first line: a URL inside a quoted question does not break the quote" {
  msg_of '表示は「PR #1330 をマージしますか？ https://example.com/x」です。'
  run_hook
  silent
}

@test "first line: a quote that closes on a later line hides its question mark" {
  msg_of "$(nl '表示は「PR #1330 をマージしますか？ マージすると' '子 #1303 の修正が入ります。」です。')"
  run_hook
  silent
}

@test "first line: a question mark inside a nested quote is not a sentence end" {
  msg_of '表示は「確認「PR #1330 をマージしますか？」の結果？」です。'
  run_hook
  silent
}

@test "first line: a question after a closed quote stays a target" {
  msg_of '「確認「マージ」の結果」を PR #1330 に出しますか？ 出すと main に入ります。'
  run_hook
  reason_of >/dev/null
}

@test "first line: a question mark inside a URL query is not a sentence end" {
  msg_of '#1330 を見た。https://example.com/a?b=1 に出ている。'
  run_hook
  silent
}

# ---------- 対象の見分け方 ----------

@test "target: a no-action report is skipped even with numbers" {
  msg_of "$(nl '主がすること: なし' '#1712 をマージした')"
  run_hook
  silent
}

@test "target: a bold no-action report without a space is skipped" {
  msg_of "$(nl '**主がすること:なし**' '#1712 をマージした。')"
  run_hook
  silent
}

@test "target: a full-width colon in the no-action report is skipped" {
  msg_of "$(nl '主がすること：  なし' '#1712 をマージした。')"
  run_hook
  silent
}

@test "target: a message that is neither a question nor has an answer line is skipped" {
  msg_of "$(nl 'テストは通った。' '#1712 を直した。')"
  run_hook
  silent
}

@test "target: an answer line above the separator makes it a target" {
  local w
  for w in 'と打って' 'と打つ' 'を押して' 'と返して' 'と答えて'; do
    msg_of "$(nl '次の変更を入れる。' '#1712 の続き。' "よければ『OK』${w}。")"
    run_hook
    reason_of >/dev/null || { echo "word=$w" >&2; return 1; }
  done
}

@test "target: an answer line below the separator does not make it a target" {
  msg_of "$(nl '次の変更を入れる。' '#1712 の続き。' '---' 'よければ『OK』と打ってください。')"
  run_hook
  silent
}

@test "target: 'to kaite' is not an answer word" {
  msg_of "$(nl '次の変更を入れる。' '#1712 の続き。' '手順書にそう書いてある、と書いておいた。')"
  run_hook
  silent
}

# ---------- 止める条件 ----------

@test "condition 1: a number outside a URL above the separator is sent back even with a URL" {
  msg_of "$(nl '#1712 をマージしてよいですか？' 'https://github.com/oratta/claude-harness/pull/1712')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 1: #1712'
  lacks "$r" "$NO_URL"
}

@test "condition 1: a bare number on the same line as its URL is sent back" {
  msg_of "$(nl 'この変更を入れてよいですか？' '#1712 https://github.com/oratta/claude-harness/pull/1712')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 2: #1712'
  lacks "$r" "$NO_URL"
}

@test "reason: the line order note says fenced blocks and empty lines are skipped" {
  msg_of 'PR #1712 のリスクを許容しますか？'
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '（逆引用符のブロックと空の行を除いて上から数えた順）'
}

@test "condition 1: every numbered line above the separator is listed" {
  msg_of "$(nl '#1 と #2 を入れてよいですか？' '#3 は後で。' 'https://github.com/o/r/pull/9' '---' '#4')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 1: #1 #2'
  has "$r" '行 2: #3'
  lacks "$r" '#4'
}

@test "condition 2: a number below the separator without an issue or PR URL is sent back" {
  msg_of "$(nl '手順書をマージしてよいですか？' '---' '経緯: #1209')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" "$NO_URL"
  lacks "$r" '行 '
}

@test "condition 2: an issue URL on a host other than GitHub counts as a link" {
  msg_of "$(nl 'この変更を入れてよいですか？' '---' '経緯: #1209' 'https://gitlab.example.com/o/r/-/issues/1209')"
  run_hook
  silent
}

@test "condition 2: a non issue or PR URL does not count as a link" {
  msg_of "$(nl '手順書をマージしてよいですか？' '---' '経緯: #1209' 'https://dash.example.com/runs/5')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" "$NO_URL"
}

@test "numbers: a fragment inside a URL and a number in a fence are not counted" {
  msg_of "$(nl 'この変更を入れてよいですか？' 'https://github.com/o/r/issues/5#issuecomment-123' '```' '#42' '```')"
  run_hook
  silent
}

@test "numbers: owner/repo#N counts as a number" {
  msg_of "$(nl 'oratta/claude-harness#88 を入れてよいですか？' 'https://github.com/oratta/claude-harness/pull/88')"
  run_hook
  local r
  r="$(reason_of)"
  has "$r" '行 1: #88'
}

@test "numbers: a target message without any number is silent" {
  msg_of "$(nl '手順書をマージしてよいですか？' 'よければ『OK』と打ってください。')"
  run_hook
  silent
}

# ---------- 理由の文 ----------

@test "reason: states the facts and points to the canonical paragraphs" {
  msg_of "$(nl 'PR #1712 のリスクを許容しますか？' 'よければ『OK』と打ってください。')"
  run_hook
  local r
  r="$(reason_of)"
  case "$r" in '[dev-workflow 主への発言の差し戻し]'*) ;; *) echo "head: $r" >&2; return 1 ;; esac
  has "$r" '~/.claude/output-styles/readable.md'
  has "$r" '節 3'
  has "$r" 'ほかの決まり'
  has "$r" '1 行目'
  has "$r" '1 回'
}

@test "reason: does not copy the canonical wording" {
  msg_of "$(nl 'PR #1712 のリスクを許容しますか？' 'よければ『OK』と打ってください。')"
  run_hook
  local r
  r="$(reason_of)"
  lacks "$r" '中身で書'
  lacks "$r" '末尾の URL にだけ置く'
  lacks "$r" '番号で物を指さ'
  local stripped="${r//\~\/.claude\/output-styles\/readable.md/}"
  lacks "$stripped" 'output-styles/readable.md'
}

@test "canon: section 3 still has the paragraphs the reason points to" {
  python3 -I - "$CANON" <<'PY'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
start = next(i for i, l in enumerate(lines) if l.startswith("## 3. 判断を求めるときは"))
end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
sec = lines[start:end]
assert any(l.startswith("ほかの決まり") for l in sec), "no ほかの決まり paragraph"
body = "\n".join(sec)
assert "番号は末尾の URL にだけ置く" in body
assert "主がすること: なし" in body
PY
}

# ---------- 止め続けない ----------

@test "off: DEV_WORKFLOW_OWNER_NUMBER_CHECK=off disables the check" {
  msg_of 'PR #1712 のリスクを許容しますか？'
  run --separate-stderr bash -c "DEV_WORKFLOW_OWNER_NUMBER_CHECK=off '$SCRIPT' < '$PAYLOAD'"
  silent
}

@test "agent: a payload with agent_id is not sent back" {
  msg_of 'PR #1712 のリスクを許容しますか？' 0 1
  run_hook
  silent
}

@test "fail-soft: broken or unexpected input is silent with exit 0" {
  local p
  for p in '' '{' '[]' '{"session_id":"s1"}' '{"last_assistant_message":123}' '{"last_assistant_message":null}' '{"last_assistant_message":"PR #1712 を許容しますか？"' '{"last_assistant_message":"PR #1712 を許容しますか？","stop_hook_active":true}' \
    '"#1"' '["#1"]' '{"session_id":"#1"}' '{"last_assistant_message":1,"n":"#1"}' '{"last_assistant_message":null,"n":"#1"}' \
    '{"last_assistant_message":"","n":"#1"}' '{"last_assistant_message":["#1"]}' '{"last_assistant_message":"\n\n","n":"#1"}' '{"x":"#1"'; do
    raw "$p"
    run_hook
    silent || { echo "payload=$p" >&2; return 1; }
  done
}

@test "fail-soft: no python3 on PATH is silent with exit 0" {
  msg_of 'PR #1712 のリスクを許容しますか？'
  local bin="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$bin"
  local c
  for c in bash cat grep sed tr head printf env; do
    if command -v "$c" >/dev/null 2>&1; then ln -sf "$(command -v "$c")" "$bin/$c"; fi
  done
  run --separate-stderr env PATH="$bin" bash "$SCRIPT" < "$PAYLOAD"
  silent
}

@test "fail-soft: does not load a fake json.py from the cwd or PYTHONPATH" {
  local fake="${BATS_TEST_TMPDIR}/fake"
  mkdir -p "$fake"
  printf 'raise SystemExit("fake json loaded")\n' > "$fake/json.py"
  msg_of 'PR #1712 のリスクを許容しますか？'
  run --separate-stderr bash -c "cd '$fake' && PYTHONPATH='$fake' '$SCRIPT' < '$PAYLOAD'"
  local r
  r="$(reason_of)"
  has "$r" '行 1: #1712'
}
