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

# Claude Code が入力待ちのとき、ペインの画面の最下部に出ている文字列（grep -E の式）。Claude Code の版で変わりうるので
# ここ 1 か所に置く。変わると start は failed ready になり、黙って誤送信しない
# 実機で確かめた画面（Claude Code 2.1.305）: 既定の画面は「? for shortcuts」、状態行を持つ環境では「<モード> on (shift+tab to cycle)」
READY_PATTERN='\? for shortcuts|\(shift\+tab to cycle\)'
# 許可・選択・信頼の確認画面が出ているときの文字列（grep -E の式）。最下部にこれが出ている間は何も送らない。
# 実機で確かめた画面（2.1.305）: フォルダの信頼の確認は「Enter to confirm · Esc to cancel」と選択肢の行、許可の確認は
# 「Do you want to ...?」と番号付きの選択肢の行。版で文言が変わると見逃すので、変わったら送らずに止まる側（READY_PATTERN が当たらない）に倒れる
DIALOG_PATTERN='Enter to confirm|Esc to cancel|Do you want to |^[[:space:]]*(❯ )?[0-9]+\. (Yes|No)\b'
# 画面の最下部として読む行数（空行を除いた末尾の行数。入力欄と状態行が入る長さ）
SCREEN_TAIL_LINES=12
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

# ペインの画面の最下部（空行を除いた末尾 SCREEN_TAIL_LINES 行）を出す（<ペイン ID>）
screen_tail() {
  tmux capture-pane -p -t "$1" 2>/dev/null | awk 'NF' | tail -n "$SCREEN_TAIL_LINES"
}

# 最下部が入力待ちで、確認画面が出ていないか（<ペイン ID>）。画面の上のほうにだけ入力待ちの印があっても入力待ちとは見ない
pane_ready() {
  local tail
  tail="$(screen_tail "$1")"
  printf '%s\n' "$tail" | grep -Eq -- "$READY_PATTERN" || return 1
  ! printf '%s\n' "$tail" | grep -Eq -- "$DIALOG_PATTERN"
}

# ペインで Claude Code が動き、入力待ちの画面か（<ペイン ID> <前面のコマンド>）
is_claude_pane() {
  case "$SHELL_COMMANDS" in *" $2 "*) return 1 ;; esac
  pane_ready "$1"
}

# 送った文が会話ログに現れたか（<ワークツリー> <この時刻より後> <送った文>）。ログは
# ${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/<パスの英数字以外を - にした名前>/*.jsonl で、送る直前に控えた時刻より後の
# user の行の本文が、送った文の先頭 40 文字（短ければ全体）を含むこと
log_has_prompt() {
  local wt="$1" since="$2" text="$3" root key d phys
  root="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
  phys="$(cd "$wt" 2>/dev/null && pwd -P)" || phys=""
  for d in "$wt" "$phys"; do
    [ -n "$d" ] || continue
    key="$(printf '%s' "$d" | sed 's/[^A-Za-z0-9]/-/g')"
    [ -d "$root/$key" ] || continue
    # 先頭 40 文字は jq で数える（文字単位。ロケールに左右されない）。送った文が /<コマンド> で始まるときは、会話ログの
    # user 行が <command-name>/<名前空間付きコマンド></command-name><command-args>引数</command-args> に展開されて
    # 先頭のコマンド名が文面に残らないので、コマンド名のうしろの引数の先頭 40 文字で照合する（実機 Claude Code 2.1.305）
    cat "$root/$key"/*.jsonl 2>/dev/null \
      | jq -r --arg t "$since" --arg x "$text" '
          ($x | if startswith("/") then (sub("^/[^ ]*[ ]*"; "") | if . == "" then $x else . end) else . end | .[0:40]) as $h
          | select(.type == "user" and ((.timestamp // "") > $t))
          | (.message.content | if type == "array" then map(.text? // "") | join("") elif type == "string" then . else "" end)
          | select(contains($h))' 2>/dev/null \
      | grep -q . && return 0
  done
  return 1
}

# ペインへ文字列を打ち込んで Enter（C-m = 改行コード 1 つ）を送る（<ペイン ID> <文字列>）。-l でキー名に解釈させない。
# キー名の Enter は、長い文を打ち込んだあとの入力欄に無視される（実機 Claude Code 2.1.305。C-m は届く）
type_line() {
  tmux send-keys -t "$1" -l -- "$2" && tmux send-keys -t "$1" C-m
}

# 文を送って、会話ログに届いたことを確かめる（<ペイン ID> <ワークツリー> <文>）。戻り値 0 = 届いた / 1 = 届かない
# 打ち込む前に最下部が入力待ちで確認画面が出ていないことを確かめ、そうでなければ何も打たずに 1 を返す
send_and_confirm() {
  local pane="$1" wt="$2" text="$3" since i tries head20 resend=1
  pane_ready "$pane" || return 1
  head20="$(printf '%s' "$text" | jq -Rr '.[0:20]')"
  since="$(date -u +%Y-%m-%dT%H:%M:%S)"
  type_line "$pane" "$text" || return 1
  tries="$submit"; [ "$tries" -ge 1 ] 2>/dev/null || tries=1
  for (( i = 0; i < tries; i++ )); do
    log_has_prompt "$wt" "$since" "$text" && return 0
    sleep 1
    # 起動して間もない Claude Code は最初の Enter を取りこぼすことがある（実機 2.1.305。指示は入力欄に残る）。
    # 文は打ち直さず、届くまで 4 秒ごとに Enter だけを重ねる（空の入力欄への Enter は何もしない）。重ねる前に毎回画面の
    # 最下部を読み、入力待ちで・確認画面が出ておらず・送った文の先頭がまだ入力欄に残っているときだけ重ねる。
    # 一度でも満たさなければ重ね送りをやめる（会話ログの確認は続ける。確認画面に Enter が選択として届くのを避けるため）
    if [ "$resend" -eq 1 ] && [ $(( i % 4 )) -eq 3 ]; then
      if pane_ready "$pane" && screen_tail "$pane" | grep -qF -- "$head20"; then
        tmux send-keys -t "$pane" C-m
      else
        resend=0
      fi
    fi
  done
  return 1
}

# シェルに貼れる形の単一引用符で囲む
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# 指示が届かなかった子の送り直しの案内を stderr に出す（<ペイン ID> <ワークツリー> <送る文> <起動コマンド> <起動し直しの指示>）。
# 先にペインと入力欄の状態を確かめる（届いているのに送ると二重に送る）。送り直しは deliver（relaunch 0。Claude Code が
# 動いているペインがちょうど 1 つのときだけ、入力待ちを確かめてから送る）
resend_hint() {
  {
    echo "the prompt may not have reached pane $1 (worktree $2)."
    echo "check the input line and whether a turn started before resending: tmux capture-pane -p -t $1"
    echo "resend: bash $(shq "$0") deliver $(shq "$2") 0 $(shq "$3") $(shq "$4") $(shq "$5")"
  } >&2
}

# ペインを作れなかった・起動できなかった子の作り直しの案内を stderr に出す（<ワークツリー> <起動コマンド> <最初の指示> [<残ったペイン ID>]）。
# 記録とワークツリーは残るので launch の再実行では skipped になる。先にワークツリーのペインを確かめる（Claude Code が
# 既に動いていれば作らず、上の送り直しにする。作ると同じ子が二重に走る）。残ったペインがシェルだけなら閉じてから start で作り直す
recreate_hint() {
  {
    echo "no agent session is running in $1 (relaunching launch skips this child: the record and worktree remain)."
    echo "check that no pane is already running claude there before creating one: tmux list-panes -a -F '#{pane_id} #{pane_current_path} #{pane_current_command}'"
    [ -z "${4-}" ] || echo "close the stuck pane if it is not running claude: tmux kill-pane -t $4"
    echo "create: bash $(shq "$0") start $(shq "$1") $(shq "$2") $(shq "$3") $(shq "${1##*/}")"
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
    recreate_hint "$wt" "$cmd" "$prompt"
    START_RESULT="failed terminal"; return 1
  fi
  if ! type_line "$pane" "$cmd"; then
    echo "could not type the start command into pane $pane. type it by hand: $cmd" >&2
    recreate_hint "$wt" "$cmd" "$prompt" "$pane"
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
    recreate_hint "$wt" "$cmd" "$prompt" "$pane"
    START_RESULT="failed ready $pane"; return 1
  fi
  if ! send_and_confirm "$pane" "$wt" "$prompt"; then
    resend_hint "$pane" "$wt" "$prompt" "$cmd" "$prompt"
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
      resend_hint "$cand" "$wt" "$text" "$cmd" "$rprompt"
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
