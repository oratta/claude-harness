#!/usr/bin/env bats
#
# PreModelSwitch hook: モデル切替の直前に、読み直すトークン数とキャッシュ書き込みの推定費用を
# systemMessage だけで知らせる（issue #714）。切替は止めない（どの失敗でも無出力・exit 0）。
#
# spec: dev-workflow-model-switch-recache-notice
#
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。
# 否定検査と単独の [[ ]] は書かず、has / lacks / assert_silent の関数で検査する
# （openspec/specs/bats-assertion-guard/spec.md）。

bats_require_minimum_version 1.5.0

# 基準の入力（spec「基準の入力」。公式ドキュメントの入力例）。各テストは書いた項目だけを変える。
BASE='{"session_id":"abc123","transcript_path":"/tmp/t.jsonl","cwd":"/tmp","hook_event_name":"PreModelSwitch","from_model":"claude-sonnet-5","to_model":"claude-opus-5","requested_model":"opus","source":"command","context_tokens":182340,"prompt_cache_warm":true,"cache_ttl":"5m","estimated_cache_write_usd":1.1396,"pricing":"catalog"}'

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/model-switch-recache-notice.sh"
  PAYLOAD="${BATS_TEST_TMPDIR}/payload.json"
}

# mk [python の文] — 基準の入力を d として読み、文を実行した結果を payload に書く
mk() {
  printf '%s' "$BASE" | python3 -c '
import json, sys
d = json.load(sys.stdin)
exec(sys.argv[1])
with open(sys.argv[2], "w") as f:
    json.dump(d, f)
' "${1:-pass}" "$PAYLOAD"
}

# raw <文字列> — payload をそのままの文字列にする（壊れた入力用）
raw() {
  printf '%s' "$1" > "$PAYLOAD"
}

# run_hook — payload を stdin に渡してスクリプトを実行する（標準出力と標準エラーを分けて受ける）
run_hook() {
  run --separate-stderr bash -c "'$SCRIPT' < '$PAYLOAD'"
}

# msg_of — 直前の run の標準出力から systemMessage を取り出す。
# exit 0・標準エラー空・1 行・キーの集合が systemMessage だけ・空でない文字列、も確かめる。
msg_of() {
  [ "$status" -eq 0 ] || { echo "status=$status" >&2; return 1; }
  [ -z "$stderr" ] || { echo "stderr=$stderr" >&2; return 1; }
  [ "${#lines[@]}" -eq 1 ] || { echo "lines=${#lines[@]} output=$output" >&2; return 1; }
  printf '%s' "$output" | python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
assert isinstance(d, dict), d
assert set(d) == {"systemMessage"}, sorted(d)
m = d["systemMessage"]
assert isinstance(m, str) and m.strip(), d
sys.stdout.write(m)
'
}

# notice [python の文] — mk → run_hook → msg_of をまとめ、systemMessage を M に入れる
notice() {
  mk "${1:-pass}"
  run_hook
  M="$(msg_of)"
}

has() {
  case "$1" in *"$2"*) return 0 ;; esac
  echo "expected to contain '$2': $1" >&2
  return 1
}

lacks() {
  case "$1" in *"$2"*) echo "expected not to contain '$2': $1" >&2; return 1 ;; esac
  return 0
}

assert_silent() {
  [ "$status" -eq 0 ] || { echo "status=$status" >&2; return 1; }
  [ -z "$output" ] || { echo "stdout=$output" >&2; return 1; }
  [ -z "$stderr" ] || { echo "stderr=$stderr" >&2; return 1; }
}

# silent_for [python の文] — mk → run_hook → 無出力・exit 0・標準エラー空
silent_for() {
  mk "${1:-pass}"
  run_hook
  assert_silent
}

# ---------- 1. systemMessage だけを返す ----------

@test "output: the documented input returns systemMessage only (no decision, no hookSpecificOutput)" {
  mk
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s' "$output" | python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
assert isinstance(d, dict), d
assert set(d) == {"systemMessage"}, sorted(d)
for k in ("decision", "hookSpecificOutput", "permissionDecision", "continue"):
    assert k not in d, k
assert isinstance(d["systemMessage"], str) and d["systemMessage"].strip(), d
'
}

@test "output: source picker and sdk return the same shape" {
  notice 'd["source"] = "picker"'
  has "$M" '182,340'
  notice 'd["source"] = "sdk"'
  has "$M" '182,340'
}

@test "output: the wording does not ask for confirmation" {
  notice
  lacks "$M" '?'
  lacks "$M" '？'
  lacks "$M" '続けますか'
  lacks "$M" 'よろしいですか'
}

# ---------- 2. トークン数と推定費用 ----------

@test "content: tokens, cost, pricing note, both model names and the warm-cache sentence" {
  notice
  has "$M" '182,340'
  has "$M" '$1.14'
  has "$M" '定価'
  has "$M" 'claude-sonnet-5'
  has "$M" 'claude-opus-5'
  has "$M" '使えなくなります'
}

@test "content: without a usable cost only the tokens are shown" {
  for stmt in 'del d["estimated_cache_write_usd"]' \
              'd["estimated_cache_write_usd"] = None' \
              'd["estimated_cache_write_usd"] = "1.14"' \
              'd["estimated_cache_write_usd"] = True'; do
    notice "$stmt"
    has "$M" '182,340'
    lacks "$M" '$'
  done
}

@test "content: without usable tokens only the cost is shown" {
  for stmt in 'del d["context_tokens"]' 'd["context_tokens"] = "182340"'; do
    notice "$stmt"
    has "$M" '$1.14'
    lacks "$M" 'トークン'
  done
}

@test "content: a tiny cost is shown as under one cent" {
  notice 'd["context_tokens"] = 900; d["estimated_cache_write_usd"] = 0.004'
  has "$M" '900'
  has "$M" '$0.01 未満'
}

@test "content: a zero cost with tokens is shown as 0.00" {
  notice 'd["estimated_cache_write_usd"] = 0'
  has "$M" '182,340'
  has "$M" '$0.00'
}

@test "content: fractional tokens are rounded to an integer" {
  notice 'd["context_tokens"] = 1234.6'
  has "$M" '1,235 トークン'
}

@test "content: NaN and infinity are not treated as numbers" {
  notice 'd["context_tokens"] = float("nan")'
  has "$M" '$1.14'
  lacks "$M" 'トークン'
  notice 'd["estimated_cache_write_usd"] = float("inf")'
  has "$M" '182,340'
  lacks "$M" '$'
}

@test "content: the pricing note follows the pricing value" {
  notice 'd["pricing"] = "configured"'
  has "$M" '組織の設定単価'
  notice 'd["pricing"] = "default"'
  has "$M" '既定の単価'
  notice 'd["pricing"] = "something_else"'
  lacks "$M" '定価'
  lacks "$M" '単価'
  notice 'del d["pricing"]'
  lacks "$M" '定価'
  lacks "$M" '単価'
}

@test "content: prompt_cache_warm missing or non-boolean drops only the warm-cache sentence" {
  for stmt in 'del d["prompt_cache_warm"]' 'd["prompt_cache_warm"] = "yes"'; do
    notice "$stmt"
    has "$M" '182,340'
    has "$M" '$1.14'
    lacks "$M" '使えなくなります'
  done
}

@test "content: model names are omitted when either one is missing or empty" {
  for stmt in 'del d["from_model"]' 'd["to_model"] = ""'; do
    notice "$stmt"
    has "$M" '182,340'
    lacks "$M" '→'
  done
}

@test "content: control characters in a model name are removed" {
  mk 'd["to_model"] = "claude\x1b[31m-opus\n-5\x7f\x00"'
  run_hook
  M="$(msg_of)"
  has "$M" '182,340'
  printf '%s' "$output" | python3 -c '
import json, sys
m = json.loads(sys.stdin.read())["systemMessage"]
bad = [hex(ord(c)) for c in m if ord(c) <= 0x1F or ord(c) == 0x7F]
assert bad == [], bad
assert "claude[31m-opus-5" in m, m
'
}

# ---------- 3. 出さない条件 ----------

@test "silent: a cold cache" {
  silent_for 'd["prompt_cache_warm"] = False'
}

@test "silent: before the first response (context_tokens is 0)" {
  silent_for 'd["context_tokens"] = 0'
  silent_for 'd["context_tokens"] = 0; d["estimated_cache_write_usd"] = 0'
}

@test "silent: no usable number" {
  silent_for 'del d["context_tokens"]; del d["estimated_cache_write_usd"]'
  silent_for 'd["context_tokens"] = -5; d["estimated_cache_write_usd"] = -1'
  silent_for 'del d["context_tokens"]; d["estimated_cache_write_usd"] = 0'
}

@test "silent: another hook event" {
  silent_for 'd["hook_event_name"] = "PostModelSwitch"'
  silent_for 'del d["hook_event_name"]'
}

# ---------- 4. どの失敗でも切替を止めない ----------

@test "fail-open: broken input is silent with exit 0" {
  for body in '' 'not json' '[1,2]' '"text"' 'null'; do
    raw "$body"
    run_hook
    assert_silent
  done
}

@test "fail-open: python3 missing is silent with exit 0" {
  mk
  shim="${BATS_TEST_TMPDIR}/shim"
  mkdir -p "$shim"
  for c in bash cat dirname env; do ln -s "$(command -v "$c")" "${shim}/${c}"; done
  run --separate-stderr env PATH="$shim" "${shim}/bash" -c "'$SCRIPT' < '$PAYLOAD'"
  assert_silent
}

@test "fail-open: transcript_path is never read (missing and existing paths give the same output)" {
  mk 'd["transcript_path"] = sys.argv[2] + ".does-not-exist"'
  run_hook
  M="$(msg_of)"
  first="$output"
  real="${BATS_TEST_TMPDIR}/transcript.jsonl"
  printf '{"type":"assistant"}\n' > "$real"
  REAL="$real" mk 'import os; d["transcript_path"] = os.environ["REAL"]'
  run_hook
  M="$(msg_of)"
  [ "$output" = "$first" ]
}

@test "fail-open: the script has no network or file commands" {
  [ -f "$SCRIPT" ]
  run bash -c "grep -v '^[[:space:]]*#' '$SCRIPT' | grep -nE 'curl|wget|urllib|http|socket|open\('"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

# ---------- 5. hooks.json と権限 ----------

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "hooks.json: PreModelSwitch runs the notice script without matcher or timeout" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
entries = d["PreModelSwitch"]
assert len(entries) == 1, entries
e = entries[0]
assert len(e["hooks"]) == 1, e
h = e["hooks"][0]
assert h["type"] == "command", h
assert "${CLAUDE_PLUGIN_ROOT}" in h["command"], h
assert "scripts/model-switch-recache-notice.sh" in h["command"], h
for obj in (e, h):
    assert "matcher" not in obj, obj
    assert "timeout" not in obj, obj
PY
}

@test "hooks.json: the six pre-existing events remain next to PreModelSwitch" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
for name in ("SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
             "SubagentStart", "SubagentStop", "PreModelSwitch"):
    assert name in d, (name, sorted(d))
PY
}
