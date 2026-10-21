#!/usr/bin/env bats
#
# UserPromptSubmit hook: 主の発言に、直前の説明が伝わっていないことを示す語があるときだけ、
# 正本（~/.claude/output-styles/readable.md の節 3）の型での言い直しを促す文を差し込む（issue #1184）。
# どの入力でも発言の送信を止めない（無出力・exit 0）。
#
# spec: dev-workflow-unclear-reply-rephrase
#
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。
# 否定検査と単独の [[ ]] は書かず、has / lacks / silent の関数で検査する
# （openspec/specs/bats-assertion-guard/spec.md）。

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/unclear-reply-rephrase.sh"
  PAYLOAD="${BATS_TEST_TMPDIR}/payload.json"
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$HOME"
}

# 語の一覧（spec の「語の一覧の順」）
WORDS=(意味わから 意味分から 意味がわから 意味が分から 意味不明 わからん 分からん 解らん わかんない 分かんない 説明して 読みにくい 読み難い 伝わらない 伝わってない 何言って なに言って)

# prompt_of <文字列> — その文字列を prompt に持つ入力を payload に書く（日本語はそのまま UTF-8）
prompt_of() {
  python3 -I -c '
import json, sys
json.dump({"session_id": "s1", "hook_event_name": "UserPromptSubmit", "prompt": sys.argv[1]},
          open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
' "$1" "$PAYLOAD"
}

# raw <文字列> — payload をそのままの文字列にする（壊れた入力・逃がした入力用）
raw() {
  printf '%s' "$1" > "$PAYLOAD"
}

run_hook() {
  run --separate-stderr bash -c "'$SCRIPT' < '$PAYLOAD'"
}

# ctx_of — 直前の run の標準出力から additionalContext を取り出す。
# exit 0・標準エラー空・1 行・キーの集合が hookSpecificOutput だけ・hookEventName・空でない文字列、も確かめる。
ctx_of() {
  [ "$status" -eq 0 ] || { echo "status=$status" >&2; return 1; }
  [ -z "$stderr" ] || { echo "stderr=$stderr" >&2; return 1; }
  [ "${#lines[@]}" -eq 1 ] || { echo "lines=${#lines[@]} output=$output" >&2; return 1; }
  printf '%s' "$output" | python3 -I -c '
import json, sys
d = json.loads(sys.stdin.read())
assert isinstance(d, dict), d
assert set(d) == {"hookSpecificOutput"}, sorted(d)
h = d["hookSpecificOutput"]
assert h.get("hookEventName") == "UserPromptSubmit", h
c = h.get("additionalContext")
assert isinstance(c, str) and c.strip(), h
sys.stdout.write(c)
'
}

# silent — 直前の run が exit 0 で、標準出力と標準エラーがどちらも空
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

# ---------- 配線 ----------

@test "hooks.json: UserPromptSubmit has the rephrase hook as the second entry and keeps the first" {
  python3 -I - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]["UserPromptSubmit"]
assert len(d) == 2, d
assert "prompt-tripwires-refresh.sh" in d[0]["hooks"][0]["command"], d[0]
e = d[1]
assert "matcher" not in e and "timeout" not in e, e
assert len(e["hooks"]) == 1, e
h = e["hooks"][0]
assert h["type"] == "command", h
assert "${CLAUDE_PLUGIN_ROOT}" in h["command"], h
assert "scripts/unclear-reply-rephrase.sh" in h["command"], h
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
    # コメントの行は見ない（grep -n の「行番号:」を外してから判定する）
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

# ---------- 語の判定 ----------

@test "detect: every word in the list triggers the injection and is shown" {
  local w c
  for w in "${WORDS[@]}"; do
    prompt_of "ねえ、${w}。"
    run_hook
    c="$(ctx_of)" || { echo "word=$w" >&2; return 1; }
    has "$c" "「${w}」" || return 1
  done
}

@test "detect: prompts without any word stay silent" {
  local p
  for p in "進めて" "原因がわからない、調べて" "やる意味がない" "分からない点は無い" "意味が違う"; do
    prompt_of "$p"
    run_hook
    silent || { echo "prompt=$p" >&2; return 1; }
  done
}

@test "detect: words inside a fenced block or a quote line are ignored" {
  prompt_of "$(printf 'このログを見て\n```\nエラー: 説明してください\n```\n> 意味不明')"
  run_hook
  silent
}

@test "detect: an indented quote line is ignored" {
  prompt_of "$(printf 'これ\n   > 説明して')"
  run_hook
  silent
}

@test "detect: a block opened with a language name and closed is ignored" {
  prompt_of "$(printf '見て\n```bash\n説明して\n```')"
  run_hook
  silent
}

@test "detect: an indented fence is ignored" {
  prompt_of "$(printf '見て\n  ```\n説明して\n  ```')"
  run_hook
  silent
}

# GNU grep -q は一致した時点で入力を読み切らずに終わる（macOS の grep は読み切るので起きない）。
# その動きを、先頭だけ読んで本物の grep に渡す代役で真似て、64KB を超える prompt の先頭に語を置く。
# 入力をパイプで grep に渡していると、書き手が SIGPIPE で落ち、pipefail で差し込みが消える。
@test "detect: a word at the head of a prompt over 64KB triggers even with an early-exit grep" {
  local bin="${BATS_TEST_TMPDIR}/earlygrep"
  mkdir -p "$bin"
  printf '#!/bin/bash\nhead -c 4096 | %q "$@"\n' "$(command -v grep)" > "$bin/grep"
  chmod +x "$bin/grep"
  prompt_of "説明して $(head -c 200000 /dev/zero | tr '\0' 'a')"
  run --separate-stderr bash -c "PATH='$bin':\"\$PATH\" '$SCRIPT' < '$PAYLOAD'"
  local c
  c="$(ctx_of)"
  has "$c" "「説明して」"
}

@test "detect: an unclosed block runs to the end of the prompt" {
  prompt_of "$(printf '見て\n```\n意味不明')"
  run_hook
  silent
}

@test "detect: a word after the closing fence triggers" {
  local c
  prompt_of "$(printf '```bash\nls\n```\nこれ説明して')"
  run_hook
  c="$(ctx_of)"
  has "$c" "「説明して」"
}

@test "detect: a word outside the quote triggers" {
  local c
  prompt_of "$(printf '> 前の説明の引用\nこれ意味わからん')"
  run_hook
  c="$(ctx_of)"
  has "$c" "「意味わから」"
}

@test "detect: with several words the first one in the list order is shown" {
  local c
  prompt_of "意味わからん"
  run_hook
  c="$(ctx_of)"
  has "$c" "「意味わから」" || return 1
  lacks "$c" "「わからん」"
}

@test "detect: list order wins over the order in the prompt" {
  local c
  prompt_of "説明して、意味不明"
  run_hook
  c="$(ctx_of)"
  has "$c" "「意味不明」"
}

@test "detect: an escaped prompt (\\uXXXX) is decoded before matching" {
  local c
  raw '{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"\u8aac\u660e\u3057\u3066"}'
  run_hook
  c="$(ctx_of)"
  has "$c" "「説明して」"
}

@test "detect: an escaped prompt without any word stays silent" {
  raw '{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"\u9032\u3081\u3066"}'
  run_hook
  silent
}

# ---------- 差し込む文 ----------

@test "text: points to the canonical file and section without copying its contents" {
  local c t
  prompt_of "説明して"
  run_hook
  c="$(ctx_of)"
  has "$c" "~/.claude/output-styles/readable.md" || return 1
  has "$c" "節 3" || return 1
  has "$c" "新しい依頼" || return 1
  has "$c" "子の作業の言葉" || return 1
  for t in 主に聞く理由 いま困っていること 推奨と根拠 受け入れるリスク 答え方 \
           主の側にしか答えが無い 決まりで主の承認が要る 主の手でしかできない操作; do
    lacks "$c" "$t" || return 1
  done
  # リポジトリ相対パスで指さない（~/.claude/ を外した形が単独で現れない）
  lacks "${c//\~\/.claude\/output-styles\/readable.md/}" "output-styles/readable.md"
}

@test "text: the canonical file still has section 3" {
  run grep -c '^## 3\. 判断を求めるときは' "${REPO_ROOT}/output-styles/readable.md"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

# ---------- 止めない ----------

@test "fail-soft: broken or unexpected input is silent with exit 0" {
  local p
  for p in '' '{' '{"session_id":"s1"}' '{"prompt":123}' '{"prompt":null}' '[]' '{"prompt":"説明して' '{"prompt":"\u8aac\u660e'; do
    raw "$p"
    run_hook
    silent || { echo "payload=$p" >&2; return 1; }
  done
}

@test "fail-soft: no python3 on PATH is silent with exit 0" {
  prompt_of "説明して"
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
  prompt_of "説明して"
  run --separate-stderr bash -c "cd '$fake' && PYTHONPATH='$fake' '$SCRIPT' < '$PAYLOAD'"
  local c
  c="$(ctx_of)"
  has "$c" "「説明して」"
}
