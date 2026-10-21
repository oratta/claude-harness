#!/usr/bin/env bats
# epic-launch-tmux.sh（tmux の起動部品）の各サブコマンドの stdout・exit code・呼び出しを、
# tmux / git / orca / sleep を PATH 上のスタブにして確かめる。
#
# スタブは自分の名前と引数（printf '%q'）を共通のログ（${STUB_LOG}）に 1 行ずつ追記する。
# 返り値は $STUB_CFG の設定ファイルで切り替える:
#   tmux: new_window_out（既定 %5）/ new_window_exit / send_exit / screen（capture-pane の出力。既定は入力待ちの表示）
#         / pane_cmd（display-message の出力。既定 node）/ panes（list-panes の出力。1 行 <ペイン ID>TAB<パス>TAB<コマンド>）
#         / list_exit / kill_stuck（あれば kill-pane が panes を減らさない）
#   git : common_<パスの / を _ にしたもの>（rev-parse --git-common-dir の出力。既定は <パス>/.git）/ common_exit
#         / show_ref_exit（既定 1 = ブランチ無し）/ wtadd_exit / wtrm_exit
#   orca: 呼ばれたら失敗する（tmux の部品は orca を呼ばない）
# 会話ログは $CLAUDE_PROJECTS_DIR の下に置く。スクリプトは PATH="<スタブ置き場>:/usr/bin:/bin" で走らせる（jq は実物）。
#
# spec: dev-workflow-epic-state（tmux の部品は子を独立した Claude Code のセッションとして tmux のウィンドウに起動する）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/epic-launch-tmux.sh"
  STUB_BIN="${BATS_TEST_TMPDIR}/bin"
  export STUB_CFG="${BATS_TEST_TMPDIR}/cfg"
  export STUB_LOG="${BATS_TEST_TMPDIR}/calls.log"
  export CLAUDE_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
  mkdir -p "$STUB_BIN" "$STUB_CFG" "$CLAUDE_PROJECTS_DIR"
  : > "$STUB_LOG"
  export TMUX=/tmp/tmux-stub,1,0
  export EPIC_DISPATCH_READY_TIMEOUT_MS=3000 EPIC_DISPATCH_SUBMIT_WAIT=2 EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT=1
  WT="${BATS_TEST_TMPDIR}/repo/.claude/worktrees/issue-5"
  mkdir -p "$WT"
  make_stub tmux; make_stub git; make_stub orca; make_stub sleep
}

make_stub() {
  local name="$1" body
  case "$name" in
    tmux) body='
case "$1" in
  new-window)
    cat "$STUB_CFG/new_window_out" 2>/dev/null || echo %5
    exit "$(cat "$STUB_CFG/new_window_exit" 2>/dev/null || echo 0)" ;;
  send-keys) exit "$(cat "$STUB_CFG/send_exit" 2>/dev/null || echo 0)" ;;
  capture-pane)
    n="$(cat "$STUB_CFG/captures" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" > "$STUB_CFG/captures"
    if [ -e "$STUB_CFG/screen2" ] && [ "$n" -ge "$(cat "$STUB_CFG/switch_at")" ]; then cat "$STUB_CFG/screen2"
    elif [ -e "$STUB_CFG/screen" ]; then cat "$STUB_CFG/screen"; else echo "  ? for shortcuts"; fi ;;
  display-message) cat "$STUB_CFG/pane_cmd" 2>/dev/null || echo node ;;
  list-panes)
    cat "$STUB_CFG/panes" 2>/dev/null
    exit "$(cat "$STUB_CFG/list_exit" 2>/dev/null || echo 0)" ;;
  kill-pane)
    if [ ! -e "$STUB_CFG/kill_stuck" ] && [ -e "$STUB_CFG/panes" ]; then
      grep -v "^$3" "$STUB_CFG/panes" > "$STUB_CFG/panes.tmp"; mv "$STUB_CFG/panes.tmp" "$STUB_CFG/panes"
    fi ;;
esac
exit 0' ;;
    git) body='
[ "$1" = "-C" ] || exit 0
cpath="$2"; shift 2
case "$1 ${2-}" in
  "rev-parse --path-format=absolute")
    [ -e "$STUB_CFG/common_exit" ] && exit "$(cat "$STUB_CFG/common_exit")"
    f="$STUB_CFG/common_$(printf "%s" "$cpath" | tr / _)"
    if [ -e "$f" ]; then cat "$f"; else echo "$cpath/.git"; fi ;;
  "show-ref --verify") exit "$(cat "$STUB_CFG/show_ref_exit" 2>/dev/null || echo 1)" ;;
  "worktree add") exit "$(cat "$STUB_CFG/wtadd_exit" 2>/dev/null || echo 0)" ;;
  "worktree remove") exit "$(cat "$STUB_CFG/wtrm_exit" 2>/dev/null || echo 0)" ;;
esac
exit 0' ;;
    orca) body='exit 99' ;;
    sleep) body='exit 0' ;;
  esac
  {
    echo '#!/bin/bash'
    echo "{ printf '%s' '$name'; printf ' %q' \"\$@\"; echo; } >> \"\$STUB_LOG\""
    echo "$body"
  } > "$STUB_BIN/$name"
  chmod +x "$STUB_BIN/$name"
}

# stdout だけを $output に取る（stderr は別ファイル）
tm() { PATH="$STUB_BIN:/usr/bin:/bin" bash "$SCRIPT" "$@" 2>"$BATS_TEST_TMPDIR/stderr"; }

calls() { LC_ALL=C grep -c -- "$1" "$STUB_LOG" || true; }

# 子のワークツリーの会話ログに user の行を 1 つ置く（<timestamp> <本文>）
put_log() {
  local key d
  key="$(printf '%s' "$WT" | sed 's/[^A-Za-z0-9]/-/g')"
  d="$CLAUDE_PROJECTS_DIR/$key"
  mkdir -p "$d"
  jq -cn --arg t "$1" --arg c "$2" '{type: "user", timestamp: $t, message: {role: "user", content: $c}}' >> "$d/s.jsonl"
}

# 子のワークツリーのペインを置く（<ペイン ID> <コマンド>）
put_pane() { printf '%s\t%s\t%s\n' "$1" "${3-$WT}" "$2" >> "$STUB_CFG/panes"; }

@test "unknown subcommand prints usage to stderr and exits 2" {
  run tm nosuch
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  grep -q usage "$BATS_TEST_TMPDIR/stderr"
}

@test "wrong argument count exits 2" {
  run tm create a b c
  [ "$status" -eq 2 ]
  run tm available extra
  [ "$status" -eq 2 ]
}

@test "available: exits 0 inside tmux and 1 with the reason when TMUX is empty" {
  run tm available
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  TMUX="" run tm available
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -q 'tmux is not available (run inside a tmux session)' "$BATS_TEST_TMPDIR/stderr"
}

@test "available: exits 1 when tmux is not on PATH" {
  rm "$STUB_BIN/tmux"
  run tm available
  [ "$status" -eq 1 ]
  grep -q 'tmux is not available' "$BATS_TEST_TMPDIR/stderr"
}

@test "here: prints the empty-id line inside tmux and exits 1 outside" {
  run tm here
  [ "$status" -eq 0 ]
  [ "$output" = '{"repo_id":"","worktree_id":""}' ]
  TMUX="" run tm here
  [ "$status" -eq 1 ]
}

@test "prepare list repos mirror print nothing and exit 0; unregistered prints ok" {
  run tm prepare /work/parent 1122
  [ "$status" -eq 0 ]; [ -z "$output" ]
  run tm list
  [ "$status" -eq 0 ]; [ -z "$output" ]
  run tm repos
  [ "$status" -eq 0 ]; [ -z "$output" ]
  run tm mirror current done /rec.json
  [ "$status" -eq 0 ]; [ -z "$output" ]
  run tm unregistered /other/clone
  [ "$status" -eq 0 ]; [ "$output" = ok ]
}

@test "create: empty clone builds in the repository of the parent worktree and prints path and branch" {
  echo /repo/.git > "$STUB_CFG/common__work_parent"
  run tm create '' '' 5 main /work/parent
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r .path)" = /repo/.claude/worktrees/issue-5 ]
  [ "$(printf '%s' "$output" | jq -r .branch)" = worktree-issue-5 ]
  [ "$(calls "^git -C /repo worktree add -b worktree-issue-5 /repo/.claude/worktrees/issue-5 origin/main")" -eq 1 ]
}

@test "create: another repository child is built from clone with an empty repo_id and never in the parent repository" {
  run tm create /other/clone '' 5 main /work/parent
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r .path)" = /other/clone/.claude/worktrees/issue-5 ]
  [ "$(calls '^git -C /other/clone worktree add -b worktree-issue-5 /other/clone/.claude/worktrees/issue-5 origin/main')" -eq 1 ]
  [ "$(calls '/work/parent worktree add')" -eq 0 ]
}

@test "create: an existing branch of the same name is not overwritten (exit 1)" {
  echo 0 > "$STUB_CFG/show_ref_exit"
  run tm create /other/clone '' 5 main /work/parent
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls 'worktree add')" -eq 0 ]
}

@test "create: an existing worktree path of the same name is not overwritten (exit 1)" {
  d="$BATS_TEST_TMPDIR/clone"
  mkdir -p "$d/.claude/worktrees/issue-5"
  run tm create "$d" '' 5 main /work/parent
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree add')" -eq 0 ]
}

@test "create: git worktree add failure exits 1" {
  echo 1 > "$STUB_CFG/wtadd_exit"
  run tm create /other/clone '' 5 main /work/parent
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "start: opens a shell without a command, types with send-keys -l, and prints started when the log shows the prompt" {
  put_log 2999-01-01T00:00:00.000Z '/develop #5 の指示'
  run tm start "$WT" 'cld --model opus' '/develop #5 の指示' 5
  [ "$status" -eq 0 ]
  [ "$output" = 'started %5' ]
  [ "$(grep -F 'tmux new-window' "$STUB_LOG")" = "tmux new-window -d -P -F \\#\\{pane_id\\} -c $WT" ]
  [ "$(calls 'tmux send-keys -t %5 -l -- cld\\ --model\\ opus')" -eq 1 ]
  [ "$(calls 'tmux send-keys -t %5 -l -- .*develop')" -eq 1 ]
  [ "$(calls 'tmux send-keys -t %5 C-m')" -eq 2 ]
  [ "$(calls '^orca')" -eq 0 ]
}

# 入力欄に送った文が残っている画面（<最後の行の前に足す行>）
screen_with_input() {
  printf '%s\n' '❯ /develop #5 の指示' '  ⏸ plan mode on (shift+tab to cycle)' > "$STUB_CFG/screen"
  [ -z "${1-}" ] || printf '%s\n' "$1" >> "$STUB_CFG/screen"
}

@test "start: only Enter is resent every 4 seconds while the prompt stays in the input line" {
  screen_with_input
  EPIC_DISPATCH_SUBMIT_WAIT=5 run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed send %5' ]
  [ "$(calls 'tmux send-keys -t %5 C-m')" -eq 3 ]
  [ "$(calls 'tmux send-keys -t %5 -l -- .*develop')" -eq 1 ]
}

@test "start: no Enter is resent when the screen shows a permission or trust dialog" {
  printf '%s\n' '❯ /develop #5 の指示' '  Do you want to proceed?' '  ❯ 1. Yes' '    2. No' '  Esc to cancel' '  ⏸ plan mode on (shift+tab to cycle)' > "$STUB_CFG/screen"
  EPIC_DISPATCH_SUBMIT_WAIT=5 run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed ready %5' ]
  [ "$(calls 'tmux send-keys -t %5 -l -- .*develop')" -eq 0 ]
}

@test "start: a dialog that appears after typing stops the resending" {
  screen_with_input
  # capture-pane の 5 回目（2 回目の重ね送りの判定）から確認画面になる。1 回目の重ね送りまでは入力欄に文が残る画面
  { cat "$STUB_CFG/screen"; printf '%s\n' '  Do you want to proceed?' '  ❯ 1. Yes' '  Esc to cancel'; } > "$STUB_CFG/screen2"
  echo 5 > "$STUB_CFG/switch_at"
  EPIC_DISPATCH_SUBMIT_WAIT=9 run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed send %5' ]
  [ "$(calls 'tmux send-keys -t %5 C-m')" -eq 3 ]
}

@test "start: no Enter is resent once the prompt is gone from the input line" {
  printf '%s\n' '  ⏸ plan mode on (shift+tab to cycle)' > "$STUB_CFG/screen"
  EPIC_DISPATCH_SUBMIT_WAIT=5 run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed send %5' ]
  [ "$(calls 'tmux send-keys -t %5 C-m')" -eq 2 ]
}

@test "start: a ready mark only in the upper part of the screen does not count as the input prompt" {
  { echo '  ? for shortcuts'; for i in $(seq 1 20); do echo "output line $i"; done; } > "$STUB_CFG/screen"
  run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed ready %5' ]
  [ "$(calls 'tmux send-keys -t %5 -l -- .*develop')" -eq 0 ]
}

@test "start: failed send when no user line follows" {
  run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed send %5' ]
}

@test "start: an old user line or a line with a different body is not counted as the submission" {
  put_log 2000-01-01T00:00:00.000Z '/develop #5 の指示'
  put_log 2999-01-01T00:00:00.000Z '別のセッションが入力した全く違う文'
  run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed send %5' ]
}

@test "start: a slash command expanded in the log is matched by the first 40 characters of its arguments" {
  put_log 2999-01-01T00:00:00.000Z $'<command-message>dev-workflow:develop</command-message>\n<command-name>/dev-workflow:develop</command-name>\n<command-args>#5 （エピック #1 の子。親ワークツリー /tmp/p から tmux で起動）</command-args>'
  run tm start "$WT" 'cld' '/develop #5 （エピック #1 の子。親ワークツリー /tmp/p から tmux で起動）' 5
  [ "$status" -eq 0 ]
  [ "$output" = 'started %5' ]
}

@test "start: only the first 40 characters are compared" {
  long='0123456789012345678901234567890123456789ABCDEFG'
  put_log 2999-01-01T00:00:00.000Z '0123456789012345678901234567890123456789'
  run tm start "$WT" 'cld' "$long" 5
  [ "$status" -eq 0 ]
  [ "$output" = 'started %5' ]
}

@test "start: failed ready without sending when the input prompt never shows" {
  echo "loading..." > "$STUB_CFG/screen"
  run tm start "$WT" 'cld' '/develop #5' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed ready %5' ]
  [ "$(calls 'send-keys -t %5 -l -- /develop')" -eq 0 ]
}

@test "start: a status-line screen with the mode hint also counts as the input prompt" {
  printf '%s\n' '  ⏸ plan mode on (shift+tab to cycle) · ← 2 agents' > "$STUB_CFG/screen"
  put_log 2999-01-01T00:00:00.000Z '/develop #5'
  run tm start "$WT" 'cld' '/develop #5' 5
  [ "$status" -eq 0 ]
  [ "$output" = 'started %5' ]
}

@test "start: failed ready without sending while the shell is still in front" {
  echo zsh > "$STUB_CFG/pane_cmd"
  run tm start "$WT" 'cld' '/develop #5' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed ready %5' ]
  [ "$(calls 'send-keys -t %5 -l -- /develop')" -eq 0 ]
}

@test "start: failed terminal with an empty pane id when new-window fails" {
  echo 1 > "$STUB_CFG/new_window_exit"
  run tm start "$WT" 'cld' '/develop #5' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed terminal' ]
}

@test "start: failed terminal with the pane id when the start command cannot be typed" {
  echo 1 > "$STUB_CFG/send_exit"
  run tm start "$WT" 'cld' '/develop #5' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed terminal %5' ]
}

@test "deliver: never sends to a shell-only pane (failed ambiguous-terminal)" {
  put_pane %7 zsh
  run tm deliver "$WT" 0 'こんにちは' 'cld' '/develop #5'
  [ "$status" -eq 1 ]
  [ "$output" = 'failed ambiguous-terminal' ]
  [ "$(calls 'send-keys')" -eq 0 ]
  [ "$(calls 'kill-pane')" -eq 0 ]
}

@test "deliver: sends to the single Claude Code pane and prints sent" {
  put_pane %7 zsh
  put_pane %8 node
  put_log 2999-01-01T00:00:00.000Z 'こんにちは'
  run tm deliver "$WT" 0 'こんにちは' 'cld' '/develop #5'
  [ "$status" -eq 0 ]
  [ "$output" = sent ]
  [ "$(calls 'send-keys -t %8 -l -- ')" -eq 1 ]
  [ "$(calls 'send-keys -t %7')" -eq 0 ]
}

@test "deliver: two Claude Code panes fail with ambiguous-terminal and nothing is sent" {
  put_pane %7 node
  put_pane %8 node
  run tm deliver "$WT" 0 'こんにちは' 'cld' '/develop #5'
  [ "$status" -eq 1 ]
  [ "$output" = 'failed ambiguous-terminal' ]
  [ "$(calls 'send-keys')" -eq 0 ]
}

@test "deliver: failed send when the log never shows the text" {
  put_pane %8 node
  run tm deliver "$WT" 0 'こんにちは' 'cld' '/develop #5'
  [ "$status" -eq 1 ]
  [ "$output" = 'failed send' ]
}

@test "deliver: no pane relaunches and prints relaunched with the pane id" {
  put_log 2999-01-01T00:00:00.000Z '/develop #5 again'
  run tm deliver "$WT" 0 'こんにちは' 'cld' '/develop #5 again'
  [ "$status" -eq 0 ]
  [ "$output" = 'relaunched %5' ]
  [ "$(calls 'send-keys -t %5 -l -- cld')" -eq 1 ]
  [ "$(calls 'kill-pane')" -eq 0 ]
}

@test "deliver: relaunch 1 kills the existing pane then starts again" {
  put_pane %8 node
  put_log 2999-01-01T00:00:00.000Z '/develop #5 again'
  run tm deliver "$WT" 1 'こんにちは' 'cld' '/develop #5 again'
  [ "$status" -eq 0 ]
  [ "$output" = 'relaunched %5' ]
  [ "$(calls 'kill-pane -t %8')" -eq 1 ]
}

@test "deliver: failed terminal-list when list-panes fails" {
  echo 1 > "$STUB_CFG/list_exit"
  run tm deliver "$WT" 0 'こんにちは' 'cld' '/develop #5'
  [ "$status" -eq 1 ]
  [ "$output" = 'failed terminal-list' ]
}

@test "deliver: failed close when the pane cannot be closed on relaunch" {
  put_pane %8 node
  touch "$STUB_CFG/kill_stuck"
  run tm deliver "$WT" 1 'こんにちは' 'cld' '/develop #5'
  [ "$status" -eq 1 ]
  [ "$output" = 'failed close' ]
}

@test "close: kills only the panes of the child worktree" {
  put_pane %7 node
  put_pane %9 zsh /somewhere/else
  run tm close "$WT" 5
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(calls 'kill-pane -t %7')" -eq 1 ]
  [ "$(calls 'kill-pane -t %9')" -eq 0 ]
}

@test "close: succeeds when there is no pane" {
  run tm close "$WT" 5
  [ "$status" -eq 0 ]
  [ "$(calls 'kill-pane')" -eq 0 ]
}

@test "close: exits 1 when the pane survives one retry (retried once)" {
  put_pane %7 node
  touch "$STUB_CFG/kill_stuck"
  run tm close "$WT" 5
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls 'kill-pane -t %7')" -eq 2 ]
  grep -q 'was incomplete for #5' "$BATS_TEST_TMPDIR/stderr"
}

@test "remove: runs git worktree remove without --force in the repository that owns the worktree" {
  echo /other/clone/.git > "$STUB_CFG/common_$(printf '%s' "$WT" | tr / _)"
  run tm remove "$WT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(calls "^git -C /other/clone worktree remove $WT\$")" -eq 1 ]
  [ "$(calls 'force')" -eq 0 ]
}

@test "remove: prints rm-failed and exits 1 when git fails" {
  echo 1 > "$STUB_CFG/wtrm_exit"
  run tm remove "$WT"
  [ "$status" -eq 1 ]
  [ "$output" = rm-failed ]
}

@test "remove: prints rm-failed and exits 1 when the repository cannot be found" {
  echo 1 > "$STUB_CFG/common_exit"
  run tm remove "$WT"
  [ "$status" -eq 1 ]
  [ "$output" = rm-failed ]
  [ "$(calls 'worktree remove')" -eq 0 ]
}

@test "no subcommand calls orca" {
  put_pane %7 node
  put_log 2999-01-01T00:00:00.000Z 'x'
  tm available; tm here; tm prepare /p 1; tm list; tm repos; tm unregistered /c
  tm create /c '' 5 main /p; tm start "$WT" cld x 5; tm deliver "$WT" 0 x cld x
  tm close "$WT" 5; tm remove "$WT"; tm mirror current done /r
  [ "$(calls '^orca')" -eq 0 ]
}

# 失敗時の stderr の案内（共通手順 6 が参照する作り直し・送り直しのコマンド）。
# 確認のコマンドが先、やり直しのコマンドが後の順であること（二重起動・二重送信を避けるため）

# stderr の中で固定文字列の最初に現れる行番号
err_line() { grep -nF -- "$1" "$BATS_TEST_TMPDIR/stderr" | head -1 | cut -d: -f1; }

@test "start: failed send prints check first (capture-pane) then the deliver command that resends" {
  run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$status" -eq 1 ]
  [ "$output" = 'failed send %5' ]
  c="$(err_line 'tmux capture-pane -p -t %5')"
  r="$(err_line 'resend:')"
  [ -n "$c" ] && [ -n "$r" ] && [ "$c" -lt "$r" ]
  grep -qF "deliver '$WT' 0" "$BATS_TEST_TMPDIR/stderr"
  grep -qF "'/develop #5 の指示'" "$BATS_TEST_TMPDIR/stderr"
}

@test "start: failed ready prints the pane check, then the close of the stuck pane, then the start command that recreates" {
  echo "  \$ " > "$STUB_CFG/screen"
  echo zsh > "$STUB_CFG/pane_cmd"
  run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$output" = 'failed ready %5' ]
  c="$(err_line 'tmux list-panes -a')"
  k="$(err_line 'tmux kill-pane -t %5')"
  r="$(err_line 'create:')"
  [ -n "$c" ] && [ -n "$k" ] && [ -n "$r" ]
  [ "$c" -lt "$k" ] && [ "$k" -lt "$r" ]
  grep -qF "start '$WT'" "$BATS_TEST_TMPDIR/stderr"
  grep -q 'launch skips\|skipped' "$BATS_TEST_TMPDIR/stderr"
}

@test "start: failed terminal (new-window fails) prints the check then the start command that recreates" {
  echo 1 > "$STUB_CFG/new_window_exit"
  run tm start "$WT" 'cld' '/develop #5 の指示' 5
  [ "$output" = 'failed terminal' ]
  c="$(err_line 'tmux list-panes -a')"
  r="$(err_line 'create:')"
  [ -n "$c" ] && [ -n "$r" ] && [ "$c" -lt "$r" ]
  grep -qF "start '$WT'" "$BATS_TEST_TMPDIR/stderr"
  [ -z "$(err_line 'tmux kill-pane')" ]
}

@test "deliver: failed send prints check first then the deliver command" {
  put_pane %8 node
  run tm deliver "$WT" 0 'こんにちは' 'cld' '/develop #5'
  [ "$output" = 'failed send' ]
  c="$(err_line 'tmux capture-pane -p -t %8')"
  r="$(err_line 'resend:')"
  [ -n "$c" ] && [ -n "$r" ] && [ "$c" -lt "$r" ]
  grep -qF "deliver '$WT' 0" "$BATS_TEST_TMPDIR/stderr"
  grep -qF "こんにちは" "$BATS_TEST_TMPDIR/stderr"
}
