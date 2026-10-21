#!/usr/bin/env bash
# tmux の起動部品。エピックの子のワークツリーを作る・tmux のウィンドウに Claude Code のセッションを開く・指示を送る・
# 閉じる・消す処理を、tmux と git のコマンドだけで行う。epic-dispatch.sh が
# `bash <同じディレクトリ>/epic-launch-tmux.sh <サブコマンド> <引数...>` で別のプロセスとして呼ぶ。
#
#   epic-launch-tmux.sh available
#   epic-launch-tmux.sh here
#   epic-launch-tmux.sh prepare <親のワークツリー> <エピックの番号>
#   epic-launch-tmux.sh list
#   epic-launch-tmux.sh repos
#   epic-launch-tmux.sh unregistered <clone>
#   epic-launch-tmux.sh create <clone> <repo_id> <子の番号> <起点> <親のワークツリー>
#   epic-launch-tmux.sh start <ワークツリー> <起動コマンド> <最初の指示> <子の呼び方>
#   epic-launch-tmux.sh deliver <ワークツリー> <relaunch 0|1> <送る文> <起動コマンド> <起動し直しの指示>
#   epic-launch-tmux.sh close <ワークツリー> <子の呼び方>
#   epic-launch-tmux.sh remove <ワークツリー>
#   epic-launch-tmux.sh mirror <current|ワークツリー> <done|waiting|stopped|resumed|stopped-seen> <記録のパス>
#
# orca は呼ばない。状態の記録は読み書きしない（記録は epic-dispatch.sh が持ち、この部品は子を知らない）。
# 親が tmux で常駐していること（TMUX が空でなく tmux が PATH にある）が前提。
# ワークツリーは <リポジトリ>/.claude/worktrees/issue-<N>、ブランチは worktree-issue-<N>（worktree プラグインの
# 置き場と名前の決まりに合わせる）。待ち時間（EPIC_DISPATCH_READY_TIMEOUT_MS・EPIC_DISPATCH_SUBMIT_WAIT・
# EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT）は epic-dispatch.sh が検査して既定を当てた値を受け取る。
# サブコマンドと出力の契約の正本は openspec の dev-workflow-epic-state spec
# 「起動部品は epic-launch-<名前>.sh の 1 本ずつで…」と「tmux の部品は…」。
set -uo pipefail

# Claude Code が入力待ちのとき、ペインの画面に出ている文字列（grep -E の式）。Claude Code の版で変わりうるので
# ここ 1 か所に置く。変わると start は failed ready になり、黙って誤送信しない
READY_PATTERN='\? for shortcuts'
# ペインの前面がこれらのコマンドなら、Claude Code ではなくシェル（指示を送るとシェルコマンドとして実行される）
SHELL_COMMANDS=' sh bash zsh fish dash ksh tcsh csh '

usage() {
  cat >&2 <<'EOF'
usage:
  epic-launch-tmux.sh available
  epic-launch-tmux.sh here
  epic-launch-tmux.sh prepare <parent worktree> <epic>
  epic-launch-tmux.sh list
  epic-launch-tmux.sh repos
  epic-launch-tmux.sh unregistered <clone>
  epic-launch-tmux.sh create <clone> <repo_id> <child number> <base> <parent worktree>
  epic-launch-tmux.sh start <worktree> <start command> <first prompt> <child label>
  epic-launch-tmux.sh deliver <worktree> <relaunch 0|1> <text> <start command> <relaunch prompt>
  epic-launch-tmux.sh close <worktree> <child label>
  epic-launch-tmux.sh remove <worktree>
  epic-launch-tmux.sh mirror <current|worktree> <done|waiting|stopped|resumed|stopped-seen> <state record>
EOF
  exit 2
}

# 引数の数を確かめる（<期待する数> <実際の数>）
argc() { [ "$2" -eq "$1" ] || usage; }

ready="${EPIC_DISPATCH_READY_TIMEOUT_MS:-60000}"
submit="${EPIC_DISPATCH_SUBMIT_WAIT:-30}"
close_wait="${EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT:-2}"

TAB=$'\t'
is_available() { command -v tmux >/dev/null 2>&1 && [ -n "${TMUX-}" ]; }

# 子のワークツリーのペインの一覧（1 行 1 件: <ペイン ID><TAB><前面のコマンド>）。読めなければ戻り値 1。
# ペインの現在のパスがワークツリーそのものか、その下にあるものを選ぶ
panes_of() {
  local wt="$1" all
  all="$(tmux list-panes -a -F "#{pane_id}${TAB}#{pane_current_path}${TAB}#{pane_current_command}")" || return 1
  printf '%s\n' "$all" | awk -F '\t' -v wt="$wt" 'NF >= 3 && ($2 == wt || index($2, wt "/") == 1) { print $1 "\t" $3 }'
}

# ペインで Claude Code が動き、入力待ちの画面か（<ペイン ID> <前面のコマンド>）
is_claude_pane() {
  case "$SHELL_COMMANDS" in *" $2 "*) return 1 ;; esac
  tmux capture-pane -p -t "$1" 2>/dev/null | grep -Eq -- "$READY_PATTERN"
}

# 送った文が会話ログに現れたか（<ワークツリー> <この時刻より後> <送った文>）。ログは
# ${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/<パスの英数字以外を - にした名前>/*.jsonl で、送る直前に控えた時刻より後の
# user の行の本文が、送った文の先頭 40 文字（短ければ全体）を含むこと
log_has_prompt() {
  local wt="$1" since="$2" text="$3" root key d phys head
  root="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
  head="${text:0:40}"
  phys="$(cd "$wt" 2>/dev/null && pwd -P)" || phys=""
  for d in "$wt" "$phys"; do
    [ -n "$d" ] || continue
    key="$(printf '%s' "$d" | sed 's/[^A-Za-z0-9]/-/g')"
    [ -d "$root/$key" ] || continue
    cat "$root/$key"/*.jsonl 2>/dev/null \
      | jq -r --arg t "$since" 'select(.type == "user" and ((.timestamp // "") > $t))
          | (.message.content | if type == "array" then map(.text? // "") | join("") elif type == "string" then . else "" end)' 2>/dev/null \
      | grep -qF -- "$head" && return 0
  done
  return 1
}

# ペインへ文字列を打ち込んで Enter を送る（<ペイン ID> <文字列>）。-l でキー名に解釈させない
type_line() {
  tmux send-keys -t "$1" -l -- "$2" && tmux send-keys -t "$1" Enter
}

# 文を送って、会話ログに届いたことを確かめる（<ペイン ID> <ワークツリー> <文>）。戻り値 0 = 届いた / 1 = 届かない
send_and_confirm() {
  local pane="$1" wt="$2" text="$3" since i tries
  since="$(date -u +%Y-%m-%dT%H:%M:%S)"
  type_line "$pane" "$text" || return 1
  tries="$submit"; [ "$tries" -ge 1 ] 2>/dev/null || tries=1
  for (( i = 0; i < tries; i++ )); do
    log_has_prompt "$wt" "$since" "$text" && return 0
    sleep 1
  done
  return 1
}

resend_hint() {
  {
    echo "the prompt may not have reached pane $1 (worktree $2)."
    echo "check the input line and whether a turn started before resending: tmux capture-pane -p -t $1"
  } >&2
}

# シェルを開いて起動コマンドを打ち、入力待ちを待ち、最初の指示を送る（<ワークツリー> <起動コマンド> <指示>）。
# 結果は START_RESULT に入れる: started <ペイン> / failed terminal|ready|send [<ペイン>]
START_RESULT=""
start_session() {
  local wt="$1" cmd="$2" prompt="$3" pane tries i cmdname
  START_RESULT=""
  if ! pane="$(tmux new-window -d -P -F '#{pane_id}' -c "$wt")" || [ -z "$pane" ]; then
    echo "tmux new-window failed in $wt" >&2
    START_RESULT="failed terminal"; return 1
  fi
  if ! type_line "$pane" "$cmd"; then
    echo "could not type the start command into pane $pane. type it by hand: $cmd" >&2
    START_RESULT="failed terminal $pane"; return 1
  fi
  tries=$(( ready / 1000 )); [ "$tries" -ge 1 ] || tries=1
  for (( i = 0; i < tries; i++ )); do
    cmdname="$(tmux display-message -p -t "$pane" '#{pane_current_command}' 2>/dev/null)"
    if is_claude_pane "$pane" "$cmdname"; then break; fi
    sleep 1
  done
  if [ "$i" -ge "$tries" ]; then
    echo "Claude Code did not reach an input prompt in pane $pane within ${ready}ms (looked for: $READY_PATTERN)" >&2
    START_RESULT="failed ready $pane"; return 1
  fi
  if ! send_and_confirm "$pane" "$wt" "$prompt"; then
    resend_hint "$pane" "$wt"
    START_RESULT="failed send $pane"; return 1
  fi
  START_RESULT="started $pane"
  return 0
}

# ワークツリーのペインをすべて閉じる（<ワークツリー>）。戻り値 0 = 残らない / 1 = 残った / 2 = 一覧を読めない
kill_panes() {
  local panes line
  panes="$(panes_of "$1")" || return 2
  while IFS=$'\t' read -r line _; do
    [ -n "$line" ] || continue
    tmux kill-pane -t "$line" >/dev/null 2>&1 || true
  done <<EOF
$panes
EOF
  panes="$(panes_of "$1")" || return 2
  [ -z "$panes" ]
}

sub="${1-}"
[ -n "$sub" ] || usage
shift

case "$sub" in
  available)
    argc 0 "$#"
    is_available || { echo "tmux is not available (run inside a tmux session)" >&2; exit 1; }
    ;;
  here)
    argc 0 "$#"
    is_available || exit 1
    echo '{"repo_id":"","worktree_id":""}'
    ;;
  prepare) argc 2 "$#" ;;
  list|repos) argc 0 "$#" ;;
  unregistered) argc 1 "$#"; echo ok ;;
  create)
    argc 5 "$#"
    clone="$1"; num="$3"; base="$4"; parent="$5"
    src="$clone"; [ -n "$src" ] || src="$parent"
    if ! common="$(git -C "$src" rev-parse --path-format=absolute --git-common-dir)" || [ -z "$common" ]; then
      echo "git -C $src rev-parse --git-common-dir failed" >&2
      exit 1
    fi
    top="${common%/.git}"; top="${top%/}"
    branch="worktree-issue-$num"
    path="$top/.claude/worktrees/issue-$num"
    if [ -e "$path" ] || git -C "$top" show-ref --verify --quiet "refs/heads/$branch"; then
      echo "worktree or branch already exists: $path / $branch" >&2
      exit 1
    fi
    git -C "$top" worktree add -b "$branch" "$path" "origin/$base" >&2 || exit 1
    jq -cn --arg p "$path" --arg b "$branch" '{path: $p, branch: $b}' || exit 2
    ;;
  start)
    argc 4 "$#"
    start_session "$1" "$2" "$3" && rc=0 || rc=1
    echo "$START_RESULT"
    exit "$rc"
    ;;
  deliver)
    argc 5 "$#"
    wt="$1"; relaunch="$2"; text="$3"; cmd="$4"; rprompt="$5"
    if ! panes="$(panes_of "$wt")"; then
      echo "failed terminal-list"; exit 1
    fi
    if [ "$relaunch" = 0 ] && [ -n "$panes" ]; then
      cand=""; ncand=0
      while IFS=$'\t' read -r pid pcmd; do
        [ -n "$pid" ] || continue
        if is_claude_pane "$pid" "$pcmd"; then cand="$pid"; ncand=$(( ncand + 1 )); fi
      done <<EOF
$panes
EOF
      if [ "$ncand" -ne 1 ]; then echo "failed ambiguous-terminal"; exit 1; fi
      if send_and_confirm "$cand" "$wt" "$text"; then echo sent; exit 0; fi
      resend_hint "$cand" "$wt"
      echo "failed send"; exit 1
    fi
    if [ -n "$panes" ]; then
      kill_panes "$wt" || { echo "failed close"; exit 1; }
    fi
    if start_session "$wt" "$cmd" "$rprompt"; then
      echo "relaunched ${START_RESULT#started }"; exit 0
    fi
    stage="${START_RESULT#failed }"; stage="${stage%% *}"
    [ "$stage" = terminal ] && stage=create
    echo "failed $stage"; exit 1
    ;;
  close)
    argc 2 "$#"
    kill_panes "$1"; rc=$?
    if [ "$rc" -ne 0 ]; then
      sleep "$close_wait"
      kill_panes "$1"; rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
      echo "tmux kill-pane was incomplete for #$2; check: tmux list-panes -a" >&2
      exit 1
    fi
    ;;
  remove)
    argc 1 "$#"
    if ! common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)" || [ -z "$common" ]; then
      echo rm-failed; exit 1
    fi
    top="${common%/.git}"; top="${top%/}"
    git -C "$top" worktree remove "$1" >&2 || { echo rm-failed; exit 1; }
    ;;
  mirror) argc 3 "$#" ;;
  *) usage ;;
esac
exit 0
