#!/usr/bin/env bash
# Orca の起動部品。エピックの子のワークツリーを作る・セッションを開く・指示を送る・閉じる・消す・
# Orca の画面へ状態を写す処理を、orca のコマンドで行う。epic-dispatch.sh が
# `bash <同じディレクトリ>/epic-launch-orca.sh <サブコマンド> <引数...>` で別のプロセスとして呼ぶ。
#
#   epic-launch-orca.sh available
#   epic-launch-orca.sh here
#   epic-launch-orca.sh prepare <親のワークツリー> <エピックの番号>
#   epic-launch-orca.sh list
#   epic-launch-orca.sh repos
#   epic-launch-orca.sh unregistered <clone>
#   epic-launch-orca.sh create <clone> <repo_id> <子の番号> <起点> <親のワークツリー>
#   epic-launch-orca.sh start <ワークツリー> <起動コマンド> <最初の指示> <子の呼び方>
#   epic-launch-orca.sh deliver <ワークツリー> <relaunch 0|1> <送る文> <起動コマンド> <起動し直しの指示>
#   epic-launch-orca.sh close <ワークツリー> <子の呼び方>
#   epic-launch-orca.sh remove <ワークツリー>
#   epic-launch-orca.sh mirror <current|ワークツリー> <done|waiting|stopped|resumed|stopped-seen> <記録のパス>
#
# orca のコマンドを呼ぶのはこのスクリプトだけ。状態の記録は読み書きしない（記録・見張り・上限・片付けの前の
# 確認は epic-dispatch.sh）。stdout にはサブコマンドごとに決めた行だけを出し、orca の出力のうち切り出す前の
# epic-dispatch.sh が stderr に出していたもの（worktree set・worktree create・terminal create・send・wait・
# close の出力、閉じ直しのときの terminal list、worktree rm の stdout と stderr）と、失敗の理由・手で続けるための案内の文
# だけを stderr に出す。中で解釈するだけの JSON（worktree current・worktree list・repo list・閉じ直し以外の
# terminal list）はどこにも出さない。
# 待ち時間（EPIC_DISPATCH_READY_TIMEOUT_MS・EPIC_DISPATCH_SUBMIT_WAIT・EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT）は
# epic-dispatch.sh が検査して既定を当てた値を受け取り、ここでは検査し直さない。
# 知らないサブコマンドと引数の数の違いは、stderr に使い方を出して exit 2。
# サブコマンドと出力の契約の正本は openspec の dev-workflow-epic-state spec
# 「起動部品は epic-launch-<名前>.sh の 1 本ずつで、同じサブコマンドと出力の契約を持つ」。
set -uo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  epic-launch-orca.sh available
  epic-launch-orca.sh here
  epic-launch-orca.sh prepare <parent worktree> <epic>
  epic-launch-orca.sh list
  epic-launch-orca.sh repos
  epic-launch-orca.sh unregistered <clone>
  epic-launch-orca.sh create <clone> <repo_id> <child number> <base> <parent worktree>
  epic-launch-orca.sh start <worktree> <start command> <first prompt> <child label>
  epic-launch-orca.sh deliver <worktree> <relaunch 0|1> <text> <start command> <relaunch prompt>
  epic-launch-orca.sh close <worktree> <child label>
  epic-launch-orca.sh remove <worktree>
  epic-launch-orca.sh mirror <current|worktree> <done|waiting|stopped|resumed|stopped-seen> <state record>
EOF
  exit 2
}

# 引数の数を確かめる（<期待する数> <実際の数>）
argc() { [ "$2" -eq "$1" ] || usage; }

ready="${EPIC_DISPATCH_READY_TIMEOUT_MS:-60000}"
submit="${EPIC_DISPATCH_SUBMIT_WAIT:-30}"

# シェルに貼れる形の単一引用符で囲む
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# 指示が届かなかった子の送り直しのコマンドを stderr に出す（<handle> <prompt> [<retry id>]）
resend_hint() {
  local cmd
  cmd="orca terminal send --terminal $(shq "$1") --text $(shq "$2") --enter --wait-submit $submit --json"
  [ -n "${3-}" ] && cmd="$cmd --retry-request $3"
  {
    echo "the first prompt may not have reached terminal $1."
    echo "check the input line and whether a turn started before resending: orca terminal read --terminal $(shq "$1")"
    echo "resend: $cmd"
  } >&2
}

# 端末を作れなかった子の、端末の作り直しと最初の指示の送信のコマンドを stderr に出す
# （<子のパス> <起動コマンド> <prompt>）
recreate_hint() {
  {
    echo "no agent terminal was started in $1 (relaunching launch skips this child)."
    echo "check that no terminal is already running claude there before creating one: orca terminal list --worktree path:$1 --json"
    echo "create: orca terminal create --worktree path:$1 --command $(shq "$2") --json"
    echo "then send: orca terminal send --terminal <handle from create> --text $(shq "$3") --enter --wait-submit $submit --json"
  } >&2
}

# send の出力にターンの開始（stages の turn_started）があるか
turn_started() {
  printf '%s' "$1" | jq -e '[.. | objects | .stages? | arrays | .[]] | index("turn_started") != null' >/dev/null 2>&1
}

# send の出力から再試行の ID を取り出す（無ければ空）
retry_id() {
  printf '%s' "$1" | jq -r 'first(.. | objects | (.retryRequestId // .retryRequest) | strings) // empty' 2>/dev/null
}

# 端末の一覧の JSON から子のセッションの端末を 1 つ選ぶ。Orca は子のワークツリーにシェルの端末
# （Terminal 1）も作るので、agentIdentity が claude の端末、それが無ければタイトルに Claude Code を
# 含む端末（Claude Code はタイトルを書き換えるので agentIdentity を先に見る）がちょうど 1 つのときだけ
# そのハンドルを stdout に出す。決められなければ何も出さない
pick_session_term() {
  printf '%s' "$1" | jq -r '[.result.terminals[] | select(.agentIdentity == "claude")] as $a
    | (if ($a | length) > 0 then $a
       else [.result.terminals[] | select((.title // "") | tostring | contains("Claude Code"))] end)
    | [.[] | .handle // empty | strings | select(. != "")]
    | if length == 1 then .[0] else empty end' 2>/dev/null
  return 0
}

# 子のワークツリーに worktree create が作った空のシェルの端末がちょうど 1 つあれば、そこへ起動
# コマンドを打ち込み、端末が Claude Code になる（agentIdentity か タイトル）まで待つ（<子のパス> <起動コマンド>）。
# 戻り値 0 = 起動した（SHELL_HANDLE にハンドル）/ 1 = 端末が 0 個（呼び出し側が terminal create で作る）/
# 3 = 失敗（理由と手で続けるコマンドを stderr に出した。端末を増やすと二重になるので作らない）
SHELL_HANDLE=""
shell_start() {
  local terms cnt h out tries i
  SHELL_HANDLE=""
  if ! terms="$(orca terminal list --worktree "path:$1" --json)" \
    || ! cnt="$(printf '%s' "$terms" | jq -e '.result.terminals | if type == "array" then length else error("x") end' 2>/dev/null)"; then
    echo "orca terminal list --worktree path:$1 --json is not readable" >&2
    echo "check the terminals before creating one: orca terminal list --worktree path:$1 --json" >&2
    return 3
  fi
  [ "$cnt" -eq 0 ] && return 1
  h="$(printf '%s' "$terms" | jq -r '.result.terminals | select(length == 1) | .[0].handle // empty' 2>/dev/null)"
  if [ -z "$h" ]; then
    echo "terminals in $1: $cnt (expected the one empty shell from worktree create); not starting a second one" >&2
    echo "check: orca terminal list --worktree path:$1 --json" >&2
    return 3
  fi
  if ! out="$(orca terminal send --terminal "$h" --text "$2" --enter --json)"; then
    printf '%s\n' "$out" >&2
    echo "could not type the start command into terminal $h. type it by hand: $2" >&2
    return 3
  fi
  tries=$(( ready / 1000 )); [ "$tries" -ge 1 ] || tries=1
  for (( i = 0; i < tries; i++ )); do
    if terms="$(orca terminal list --worktree "path:$1" --json)"; then
      cnt="$(printf '%s' "$terms" | jq -r '.result.terminals | if type == "array" then length else empty end' 2>/dev/null)"
      if [ -n "$cnt" ] && [ "$cnt" -ge 2 ]; then
        echo "terminals in $1: $cnt after typing the start command (expected 1); not sending the prompt" >&2
        echo "check: orca terminal list --worktree path:$1 --json" >&2
        return 3
      fi
      if [ "$(pick_session_term "$terms")" = "$h" ]; then
        SHELL_HANDLE="$h"; return 0
      fi
    fi
    sleep 1
  done
  echo "terminal $h did not become Claude Code within ${tries}s. check: orca terminal read --terminal $(shq "$h")" >&2
  return 3
}

# 部品が使えるか（orca が PATH にあるか）
cmd_available() {
  argc 0 "$#"
  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
}

# 今のワークツリーが Orca 管理か。管理下の判定は orca worktree current --json の exit だけで決め、
# 識別子は読めなければ空にする（jq が無くても管理下なら exit 0）
cmd_here() {
  argc 0 "$#"
  local current rid="" wid=""
  command -v orca >/dev/null 2>&1 || { echo "not in an Orca-managed worktree" >&2; exit 1; }
  current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
  if command -v jq >/dev/null 2>&1; then
    rid="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty' 2>/dev/null)" || rid=""
    wid="$(printf '%s' "$current" | jq -r '.result.worktree.id // empty' 2>/dev/null)" || wid=""
    jq -cn --arg r "$rid" --arg w "$wid" '{repo_id: $r, worktree_id: $w}'
  else
    printf '%s\n' '{"repo_id":"","worktree_id":""}'
  fi
}

# 親のワークツリーをエピックに紐づける
cmd_prepare() {
  argc 2 "$#"
  orca worktree set --worktree "path:$1" --issue "$2" >&2 \
    || { echo "orca worktree set failed" >&2; exit 1; }
}

# Orca が知っている子のワークツリーを 1 行 1 件の JSON で出す（archive 済みは出さない。Orca の印を記録の語に読み替える）
cmd_list() {
  argc 0 "$#"
  local list rows
  list="$(orca worktree list --json)" || { echo "orca worktree list failed" >&2; exit 1; }
  printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1 \
    || { echo "orca worktree list --json is not readable" >&2; exit 1; }
  rows="$(printf '%s' "$list" | jq -c '.result.worktrees
    | .[] | objects | select(.isArchived != true)
    | {repo_id: (.repoId // "" | tostring), issue: (.linkedIssue // "" | tostring),
       path: (.path // "" | tostring), branch: (.branch // "" | tostring | sub("^refs/heads/"; "")),
       parent_id: (.parentWorktreeId // "" | tostring),
       status: (.workspaceStatus // "" | if . == "completed" then "done" elif . == "in-review" then "waiting" else "running" end),
       stop: (.comment // "" | if . == "epic-stopped" then "stopped" elif . == "epic-stopped-seen" then "stopped-seen"
         elif . == "epic-resumed" then "resumed" else "" end)}' 2>/dev/null)" \
    || { echo "orca worktree list --json is not readable" >&2; exit 1; }
  [ -z "$rows" ] || printf '%s\n' "$rows"
}

# Orca に登録された clone を 1 行 1 件の JSON {"id","path"} で出す（読めなければ何も出さず exit 1）
cmd_repos() {
  argc 0 "$#"
  local out rows
  out="$(orca repo list --json 2>/dev/null)" || exit 1
  printf '%s' "$out" | jq -e '.result.repos | type == "array"' >/dev/null 2>&1 || exit 1
  rows="$(printf '%s' "$out" | jq -c '.result.repos
    | .[] | objects | {id: (.id // "" | tostring),
       path: (.path // "" | tostring | if . == "/" then . else rtrimstr("/") end)}' 2>/dev/null)" || exit 1
  [ -z "$rows" ] || printf '%s\n' "$rows"
}

# clone が Orca に登録されていないときの理由の語と、登録の仕方
cmd_unregistered() {
  argc 1 "$#"
  echo "$1 is not registered in Orca. Add it (launch does not add repositories): orca repo add --path $1" >&2
  echo not-in-orca
}

# 子のワークツリーを作る（repo_id が空なら親と同じリポジトリ。clone は使わない）
cmd_create() {
  argc 5 "$#"
  local rid="$2" num="$3" base="$4" parent="$5" out rc path branch
  if [ -n "$rid" ]; then
    out="$(orca worktree create --repo "id:$rid" --name "issue-$num" --issue "$num" --base-branch "origin/$base" \
      --parent-worktree "path:$parent" --json)"
    rc=$?
  else
    out="$(orca worktree create --name "issue-$num" --issue "$num" --base-branch "origin/$base" \
      --parent-worktree "path:$parent" --json)"
    rc=$?
  fi
  printf '%s\n' "$out" >&2
  [ "$rc" -eq 0 ] || exit 1
  path="$(printf '%s' "$out" | jq -r '.result.worktree.path // empty' 2>/dev/null)"
  [ -n "$path" ] || exit 2
  branch="$(printf '%s' "$out" | jq -r '.result.worktree.branch // empty' 2>/dev/null)"
  jq -cn --arg p "$path" --arg b "${branch#refs/heads/}" '{path: $p, branch: $b}'
}

# 子のワークツリーでセッションを起動して最初の指示を送る。worktree create が作った空のシェルの端末が
# あればそこで起動し（端末が 2 つになると deliver が ambiguous-terminal で止まる）、0 個なら端末を作る
cmd_start() {
  argc 4 "$#"
  local child="$1" agent_cmd="$2" prompt="$3" label="$4" handle="" shell_rc=0 stage="" out rc sent
  shell_start "$child" "$agent_cmd" || shell_rc=$?
  if [ "$shell_rc" -eq 0 ]; then
    handle="$SHELL_HANDLE"
  elif [ "$shell_rc" -eq 3 ]; then
    stage=terminal
  else
    out="$(orca terminal create --worktree "path:$child" --command "$agent_cmd" --json)"
    rc=$?
    printf '%s\n' "$out" >&2
    [ "$rc" -eq 0 ] && handle="$(printf '%s' "$out" | jq -r '.result.terminal.handle // empty' 2>/dev/null)"
    if [ -z "$handle" ]; then
      echo "no terminal handle for #$label from orca terminal create --json" >&2
      recreate_hint "$child" "$agent_cmd" "$prompt"
      stage=terminal
    fi
  fi
  if [ -z "$stage" ] && ! orca terminal wait --terminal "$handle" --for tui-idle --timeout-ms "$ready" --json >&2; then
    resend_hint "$handle" "$prompt"
    stage=ready
  fi
  if [ -z "$stage" ]; then
    sent="$(orca terminal send --terminal "$handle" --text "$prompt" --enter --wait-submit "$submit" --json)"
    rc=$?
    printf '%s\n' "$sent" >&2
    if [ "$rc" -eq 0 ] && turn_started "$sent"; then
      echo "started $handle"; exit 0
    fi
    resend_hint "$handle" "$prompt" "$(retry_id "$sent")"
    stage=send
  fi
  echo "failed $stage${handle:+ $handle}"
  exit 1
}

# 子のセッションに文を届ける。端末の一覧は 1 回だけ読み、送るか、閉じて起動し直すかをその場で決める
cmd_deliver() {
  argc 5 "$#"
  local path="$1" relaunch="$2" msg="$3" agent_cmd="$4" prompt="$5" terms tcount handle out rc sent
  if ! terms="$(orca terminal list --worktree "path:$path" --json)" \
    || ! tcount="$(printf '%s' "$terms" \
      | jq -e '.result.terminals | if type == "array" then length else error("terminals is not an array") end' 2>/dev/null)"; then
    # terminals が欠落・null・配列以外なら 0 個と数えない（0 個として作り直すと、動いている子が二重に起動する）
    echo "orca terminal list --worktree path:$path --json is not readable" >&2
    echo "failed terminal-list"; exit 1
  fi
  # 端末があれば、子のセッションの端末（Claude Code の端末 1 つ）に送る
  # （止まっている子の入力欄に打ち込み、ターンの開始まで確かめる）。Orca は子のワークツリーにシェルの
  # 端末も作るので、端末の数では決めない。決められなければ送らない（シェルの端末だけのときも、
  # それが子のセッションでないと一覧から言い切れないので起動し直さない。主の判断で relaunch 1 を使う）
  if [ "$relaunch" = 0 ] && [ "$tcount" -gt 0 ]; then
    handle="$(pick_session_term "$terms")"
    if [ -z "$handle" ]; then
      echo "terminals in $path: $tcount, but not exactly one is Claude Code (cannot tell which one runs the child session; use reply --relaunch to start it over)" >&2
      echo "failed ambiguous-terminal"; exit 1
    fi
    sent="$(orca terminal send --terminal "$handle" --text "$msg" --enter --wait-submit "$submit" --json)"
    rc=$?
    printf '%s\n' "$sent" >&2
    if [ "$rc" -eq 0 ] && turn_started "$sent"; then
      echo sent; exit 0
    fi
    resend_hint "$handle" "$msg" "$(retry_id "$sent")"
    echo "failed send"; exit 1
  fi
  # 端末が無いか relaunch 1: 古いセッションを残したまま二重に起動しないよう、先に全部閉じてから作る
  if [ "$tcount" -gt 0 ]; then
    orca terminal close --worktree "path:$path" --all --json >&2 || { echo "failed close"; exit 1; }
  fi
  out="$(orca terminal create --worktree "path:$path" --command "$agent_cmd" --json)"
  rc=$?
  printf '%s\n' "$out" >&2
  handle=""
  [ "$rc" -eq 0 ] && handle="$(printf '%s' "$out" | jq -r '.result.terminal.handle // empty' 2>/dev/null)"
  if [ -z "$handle" ]; then
    recreate_hint "$path" "$agent_cmd" "$prompt"
    echo "failed create"; exit 1
  fi
  if ! orca terminal wait --terminal "$handle" --for tui-idle --timeout-ms "$ready" --json >&2; then
    resend_hint "$handle" "$prompt"
    echo "failed ready"; exit 1
  fi
  sent="$(orca terminal send --terminal "$handle" --text "$prompt" --enter --wait-submit "$submit" --json)"
  rc=$?
  printf '%s\n' "$sent" >&2
  if [ "$rc" -eq 0 ] && turn_started "$sent"; then
    echo "relaunched $handle"; exit 0
  fi
  resend_hint "$handle" "$prompt" "$(retry_id "$sent")"
  echo "failed send"; exit 1
}

# 子のワークツリーの端末をすべて閉じる。閉じが失敗したら（子のターンが終わっておらず terminal_close_incomplete に
# なることがある）、原因の手がかりに端末の一覧を stderr に出し、待ってから 1 回だけ閉じ直す
cmd_close() {
  argc 2 "$#"
  local path="$1" cw="${EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT:-10}"
  orca terminal close --worktree "path:$path" --all >&2 && exit 0
  echo "terminal close was incomplete for #$2; listing terminals, waiting ${cw}s and retrying once" >&2
  orca terminal list --worktree "path:$path" --json >&2 || true
  sleep "$cw"
  orca terminal close --worktree "path:$path" --all >&2 || exit 1
}

# 子のワークツリーを消す。--force は付けない（未コミットの変更があれば rm が止まる）。
# 端末の片付けの失敗（stderr に terminal sweep failed）は別の理由で返す。再試行もしない
cmd_remove() {
  argc 1 "$#"
  local rmerr
  rmerr="$(mktemp)" || { echo rm-failed; exit 1; }
  if ! orca worktree rm --worktree "path:$1" >&2 2>"$rmerr"; then
    cat "$rmerr" >&2
    if grep -qF -- 'terminal sweep failed' "$rmerr"; then
      echo rm-failed-terminal-sweep
    else
      echo rm-failed
    fi
    rm -f "$rmerr"; exit 1
  fi
  cat "$rmerr" >&2; rm -f "$rmerr"
}

# 記録の状態を Orca の画面の印へ写す。写せなくても成功扱いで、stderr に出す。orca が無ければ何もしない
cmd_mirror() {
  argc 3 "$#"
  local wt rec="$3"
  local -a args
  case "$2" in
    done) args=(--workspace-status completed) ;;
    waiting) args=(--workspace-status in-review) ;;
    stopped) args=(--comment epic-stopped) ;;
    resumed) args=(--comment epic-resumed) ;;
    stopped-seen) args=(--comment epic-stopped-seen) ;;
    *) usage ;;
  esac
  case "$1" in current) wt=current ;; *) wt="path:$1" ;; esac
  command -v orca >/dev/null 2>&1 || exit 0
  orca worktree set --worktree "$wt" "${args[@]}" >&2 \
    || echo "could not mirror the state to Orca (orca worktree set --worktree $wt ${args[*]}); the state record is still written: $rec" >&2
  exit 0
}

[ "$#" -ge 1 ] || usage
sub="$1"; shift
case "$sub" in
  available) cmd_available "$@" ;;
  here) cmd_here "$@" ;;
  prepare) cmd_prepare "$@" ;;
  list) cmd_list "$@" ;;
  repos) cmd_repos "$@" ;;
  unregistered) cmd_unregistered "$@" ;;
  create) cmd_create "$@" ;;
  start) cmd_start "$@" ;;
  deliver) cmd_deliver "$@" ;;
  close) cmd_close "$@" ;;
  remove) cmd_remove "$@" ;;
  mirror) cmd_mirror "$@" ;;
  *) usage ;;
esac
