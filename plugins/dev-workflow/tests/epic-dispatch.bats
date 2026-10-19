#!/usr/bin/env bats
# epic-dispatch.sh（エピックの子の経路判定・起動・待ち受け）の振る舞いを、
# orca / gh / git / sleep を PATH 上のスタブにして確かめる。あわせて develop の SKILL.md
# 「エピックの扱い」の回し方と「前提」表に、この経路の記述があることを確かめる。
#
# スタブは自分の名前と引数（printf '%q'）を共通のログ（${STUB_LOG}）に 1 行ずつ追記する。
# 返り値は $STUB_CFG の設定ファイルで切り替える:
#   orca: current_exit / current_json / list_exit / list_json（list_json_<回数> があればその回だけ
#         それを返す。回数は listcount）/ set_exit / set_comment_exit（--comment 付きの set だけの終了コード。既定は set_exit。
#         --comment が成功したら current_json と list_json* の同じ path の comment をその値に書き換える）
#         / close_exit / rm_exit / rm_err（rm の stderr）/ create_fail_<N>
#         / tlist_exit / tlist_json_<N>（terminal list。<N> は --worktree の path の issue-<N>。既定は端末 0 個）
#           / tlist_after_<N>（term-<N> に terminal send が届いたあとの terminal list。無ければ tlist_json_<N> のまま）
#         / create_json_<N>（既定は result.worktree.path が /work/issue-<N> の JSON）
#         / tcreate_fail_<N> / tcreate_json_<N>（terminal create。<N> は --worktree の path の issue-<N>。
#         既定は result.terminal.handle が term-<N> の JSON。--command は tcmd_<N> に書き出す）
#         / wait_exit_<handle> / send_exit_<handle> / send_json_<handle>
#         （既定は stages に turn_started を含む JSON）。
#         create に --prompt が渡されたら prompt_<N> に、terminal send の --text は sent_<handle> に書き出す
#   git : toplevel（rev-parse --show-toplevel の出力）/ fetch_exit / status_exit / status_out
#         （-C <パス> status --porcelain）/ head（-C <パス> rev-parse HEAD。既定 aaa111）/ branch_tip
#         （rev-parse --verify --quiet refs/heads/<b> の出力。無ければ exit 1）/ branchd_exit（branch -D）
#         / wtlist_out・wtlist_out_<回数>・wtlist_exit（worktree list --porcelain。既定は空・0。回数は wtcount）
#           wtlist_sleep（1 回の worktree list にかかる実時間の秒数）/ wttip_<回数>（その回の呼び出しで branch_tip をこの内容にする）
#           branch -D が成功すると branch_tip を消す（ブランチが消えたことの表現）
#   gh  : issue comment <N> --body <本文> は本文を comment_<N> に追記し（1 件ごとに "---" の行で区切る）、
#         comment_exit_<N>（無ければ comment_exit）で終わる（既定 0）。成功（exit 0）のときは実物の gh と同じに投稿先の URL を stdout に出す。pr list は pr_out を出して pr_exit で終わる（--search 付きは pr_search_out と pr_search_exit。既定は空・0）。それ以外は gh_<N> に 1 呼び出し 1 行の返り値（open / closed / FAIL / 空行）。最後の行を繰り返す。
#         呼び出し回数は ghcount_<N>。FAIL は stderr に "gh: mock failure for issue <N> (poll <count>)" も出す
# スクリプトは PATH="<スタブ置き場>:/usr/bin:/bin" で走らせる（jq は実物）。
# テストの途中に素の [[ ]] を置かない（bash 3.2 では偽でも素通りする）。
#
# spec: dev-workflow-develop（epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/epic-dispatch.sh"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  STUB_BIN="${BATS_TEST_TMPDIR}/bin"
  export STUB_CFG="${BATS_TEST_TMPDIR}/cfg"
  export STUB_LOG="${BATS_TEST_TMPDIR}/calls.log"
  mkdir -p "$STUB_BIN" "$STUB_CFG"
  : > "$STUB_LOG"
  printf '%s\n' '{"result":{"worktree":{"repoId":"repo-a","path":"/work/parent"}}}' > "$STUB_CFG/current_json"
  printf '%s\n' '{"result":{"worktrees":[]}}' > "$STUB_CFG/list_json"
  printf '%s\n' '/work/parent' > "$STUB_CFG/toplevel"
  make_stub gh
  make_stub git
  make_stub sleep
  # 外の環境（並列起動された子のセッション）の値をテストに漏らさない
  unset EPIC_DISPATCH_PARENT_EPIC
}

# 共通の前半（ログへの追記）と、名前ごとの返り値の処理を持つスタブを置く
make_stub() {
  local name="$1" body
  case "$name" in
    orca) body='
case "$1 $2" in
  "worktree current")
    rc=$(cat "$STUB_CFG/current_exit" 2>/dev/null || echo 0)
    [ "$rc" -eq 0 ] && cat "$STUB_CFG/current_json"
    exit "$rc" ;;
  "worktree list")
    lc=$(( $(cat "$STUB_CFG/listcount" 2>/dev/null || echo 0) + 1 ))
    echo "$lc" > "$STUB_CFG/listcount"
    rc=$(cat "$STUB_CFG/list_exit" 2>/dev/null || echo 0)
    if [ "$rc" -eq 0 ]; then
      if [ -e "$STUB_CFG/list_json_$lc" ]; then cat "$STUB_CFG/list_json_$lc"; else cat "$STUB_CFG/list_json"; fi
    fi
    exit "$rc" ;;
  "worktree rm")
    cat "$STUB_CFG/rm_err" >&2 2>/dev/null
    exit "$(cat "$STUB_CFG/rm_exit" 2>/dev/null || echo 0)" ;;
  "terminal close")
    cc=$(( $(cat "$STUB_CFG/closecount" 2>/dev/null || echo 0) + 1 ))
    echo "$cc" > "$STUB_CFG/closecount"
    if [ -e "$STUB_CFG/close_exit_$cc" ]; then exit "$(cat "$STUB_CFG/close_exit_$cc")"; fi
    exit "$(cat "$STUB_CFG/close_exit" 2>/dev/null || echo 0)" ;;
  "terminal list")
    issue=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --worktree) issue="${2##*issue-}"; shift ;;
      esac
      shift
    done
    rc=$(cat "$STUB_CFG/tlist_exit" 2>/dev/null || echo 0)
    if [ "$rc" -eq 0 ]; then
      if [ -e "$STUB_CFG/tlist_after_$issue" ] && [ -e "$STUB_CFG/sent_term-$issue" ]; then cat "$STUB_CFG/tlist_after_$issue"
      elif [ -e "$STUB_CFG/tlist_json_$issue" ]; then cat "$STUB_CFG/tlist_json_$issue"; else echo "{\"ok\":true,\"result\":{\"terminals\":[]}}"; fi
    fi
    exit "$rc" ;;
  "worktree set")
    echo "{\"ok\":true}"
    rc=$(cat "$STUB_CFG/set_exit" 2>/dev/null || echo 0)
    wt=""; cm=""; hasc=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --worktree) wt="$2"; shift ;;
        --comment) cm="$2"; hasc=1; shift ;;
      esac
      shift
    done
    if [ "$hasc" -eq 1 ]; then
      rc=$(cat "$STUB_CFG/set_comment_exit" 2>/dev/null || echo "$rc")
      if [ "$rc" -eq 0 ]; then
        case "$wt" in
          current) p=$(jq -r ".result.worktree.path // empty" "$STUB_CFG/current_json") ;;
          path:*) p="${wt#path:}" ;;
          *) p="" ;;
        esac
        for f in "$STUB_CFG"/current_json "$STUB_CFG"/list_json*; do
          [ -e "$f" ] || continue
          jq -c --arg p "$p" --arg c "$cm" \
            "if .result.worktree.path? == \$p then .result.worktree.comment = \$c else . end
             | if (.result.worktrees? | type) == \"array\" then .result.worktrees |= map(if .path == \$p then .comment = \$c else . end) else . end" \
            "$f" > "$f.tmp" && mv "$f.tmp" "$f"
        done
      fi
    fi
    exit "$rc" ;;
  "worktree create")
    issue=""; prompt=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --issue) issue="$2"; shift ;;
        --prompt) prompt="$2"; shift ;;
      esac
      shift
    done
    [ -n "$prompt" ] && printf "%s" "$prompt" > "$STUB_CFG/prompt_$issue"
    if [ -e "$STUB_CFG/create_json_$issue" ]; then
      cat "$STUB_CFG/create_json_$issue"
    else
      echo "{\"ok\":true,\"result\":{\"worktree\":{\"path\":\"/work/issue-$issue\"}}}"
    fi
    [ -e "$STUB_CFG/create_fail_$issue" ] && exit 1
    exit 0 ;;
  "terminal create")
    issue=""; cmd=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --worktree) issue="${2##*issue-}"; shift ;;
        --command) cmd="$2"; shift ;;
      esac
      shift
    done
    printf "%s" "$cmd" > "$STUB_CFG/tcmd_$issue"
    if [ -e "$STUB_CFG/tcreate_json_$issue" ]; then
      cat "$STUB_CFG/tcreate_json_$issue"
    else
      echo "{\"ok\":true,\"result\":{\"terminal\":{\"handle\":\"term-$issue\"}}}"
    fi
    [ -e "$STUB_CFG/tcreate_fail_$issue" ] && exit 1
    exit 0 ;;
  "terminal wait"|"terminal send")
    sub="$2"; handle=""; text=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --terminal) handle="$2"; shift ;;
        --text) text="$2"; shift ;;
      esac
      shift
    done
    if [ "$sub" = wait ]; then
      echo "{\"ok\":true}"
      exit "$(cat "$STUB_CFG/wait_exit_$handle" 2>/dev/null || echo 0)"
    fi
    printf "%s" "$text" > "$STUB_CFG/sent_$handle"
    if [ -e "$STUB_CFG/send_json_$handle" ]; then
      cat "$STUB_CFG/send_json_$handle"
    else
      echo "{\"ok\":true,\"result\":{\"stages\":[\"input_accepted\",\"turn_started\"]}}"
    fi
    exit "$(cat "$STUB_CFG/send_exit_$handle" 2>/dev/null || echo 0)" ;;
esac
exit 0' ;;
    git) body='
if [ "$1" = "-C" ]; then
  shift 2
  case "$1 ${2-}" in
    "status --porcelain")
      cat "$STUB_CFG/status_out" 2>/dev/null
      exit "$(cat "$STUB_CFG/status_exit" 2>/dev/null || echo 0)" ;;
    "rev-parse HEAD") cat "$STUB_CFG/head" 2>/dev/null || echo aaa111; exit 0 ;;
    "merge-base --is-ancestor") exit "$(cat "$STUB_CFG/ancestor_exit" 2>/dev/null || echo 0)" ;;
  esac
  exit 0
fi
case "$1 ${2-}" in
  "worktree list")
    wc=$(( $(cat "$STUB_CFG/wtcount" 2>/dev/null || echo 0) + 1 ))
    echo "$wc" > "$STUB_CFG/wtcount"
    [ -e "$STUB_CFG/wtlist_sleep" ] && /bin/sleep "$(cat "$STUB_CFG/wtlist_sleep")"
    [ -e "$STUB_CFG/wttip_$wc" ] && cp "$STUB_CFG/wttip_$wc" "$STUB_CFG/branch_tip"
    rc=$(cat "$STUB_CFG/wtlist_exit" 2>/dev/null || echo 0)
    if [ "$rc" -eq 0 ]; then
      if [ -e "$STUB_CFG/wtlist_out_$wc" ]; then cat "$STUB_CFG/wtlist_out_$wc"; else cat "$STUB_CFG/wtlist_out" 2>/dev/null; fi
    fi
    exit "$rc" ;;
  "rev-parse --verify")
    [ -e "$STUB_CFG/branch_tip" ] || exit 1
    cat "$STUB_CFG/branch_tip"; exit 0 ;;
  "ls-remote origin")
    if [ -e "$STUB_CFG/lsremote_out" ]; then cat "$STUB_CFG/lsremote_out"; else printf "ccc3330000000000000000000000000000000000\t%s\n" "$3"; fi
    exit "$(cat "$STUB_CFG/lsremote_exit" 2>/dev/null || echo 0)" ;;
  "cat-file -e")
    cc=$(( $(cat "$STUB_CFG/catfile_count" 2>/dev/null || echo 0) + 1 ))
    echo "$cc" > "$STUB_CFG/catfile_count"
    exit "$(cat "$STUB_CFG/catfile_exit_$cc" 2>/dev/null || cat "$STUB_CFG/catfile_exit" 2>/dev/null || echo 0)" ;;
  "branch -D")
    rc="$(cat "$STUB_CFG/branchd_exit" 2>/dev/null || echo 0)"
    [ "$rc" -eq 0 ] && rm -f "$STUB_CFG/branch_tip"
    exit "$rc" ;;
esac
case "$1" in
  rev-parse) cat "$STUB_CFG/toplevel"; exit 0 ;;
  fetch) exit "$(cat "$STUB_CFG/fetch_exit" 2>/dev/null || echo 0)" ;;
esac
exit 0' ;;
    gh) body='
if [ "$1 $2" = "issue comment" ]; then
  printf "%s\n---\n" "$5" >> "$STUB_CFG/comment_$3"
  rc="$(cat "$STUB_CFG/comment_exit_$3" 2>/dev/null || cat "$STUB_CFG/comment_exit" 2>/dev/null || echo 0)"
  [ "$rc" -eq 0 ] && echo "https://github.com/o/r/issues/$3#issuecomment-1"
  exit "$rc"
fi
if [ "$1 $2" = "pr list" ]; then
  for a in "$@"; do
    if [ "$a" = "--search" ]; then
      cat "$STUB_CFG/pr_search_out" 2>/dev/null
      exit "$(cat "$STUB_CFG/pr_search_exit" 2>/dev/null || echo 0)"
    fi
    if [ "$a" = "all" ]; then
      cat "$STUB_CFG/pr_all_out" 2>/dev/null
      exit "$(cat "$STUB_CFG/pr_all_exit" 2>/dev/null || echo 0)"
    fi
  done
  cat "$STUB_CFG/pr_out" 2>/dev/null
  exit "$(cat "$STUB_CFG/pr_exit" 2>/dev/null || echo 0)"
fi
n="${2##*/}"
count=$(( $(cat "$STUB_CFG/ghcount_$n" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$STUB_CFG/ghcount_$n"
total=$(wc -l < "$STUB_CFG/gh_$n" | tr -d " ")
idx="$count"
[ "$idx" -gt "$total" ] && idx="$total"
val=$(sed -n "${idx}p" "$STUB_CFG/gh_$n")
[ "$val" = "FAIL" ] && { echo "gh: mock failure for issue $n (poll $count)" >&2; exit 1; }
echo "$val"
exit 0' ;;
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
dispatch() { PATH="$STUB_BIN:/usr/bin:/bin" "$SCRIPT" "$@" 2>"$BATS_TEST_TMPDIR/stderr"; }

# jq の無い PATH で走らせる（スタブのほかは bash と cat だけ）
dispatch_nojq() {
  local d="$BATS_TEST_TMPDIR/nojq"
  mkdir -p "$d"
  ln -sf "$(command -v bash)" "$d/bash"
  ln -sf "$(command -v cat)" "$d/cat"
  PATH="$STUB_BIN:$d" "$SCRIPT" "$@" 2>"$BATS_TEST_TMPDIR/stderr"
}

# 子 N の gh の返り値の並びを置く（1 引数 1 呼び出し）
gh_seq() { local n="$1"; shift; printf '%s\n' "$@" > "$STUB_CFG/gh_$n"; }

# ログの呼び出し回数（grep -c が 0 件で exit 1 になるのを吸収する）
calls() { LC_ALL=C grep -c -- "$1" "$STUB_LOG" || true; }

# 前方一致（失敗したら両方を出す）
starts_with() {
  case "$1" in
    "$2"*) return 0 ;;
  esac
  echo "expected prefix: $2" >&2
  echo "actual:          $1" >&2
  return 1
}

# 一覧の 1 件（<N> <workspaceStatus> [parentWorktreeId] [repoId] [isArchived] [comment]）。パスは実在のディレクトリ
wt_entry() {
  local n="$1" st="$2" par="${3-repo-a::/work/parent}" repo="${4-repo-a}" arch="${5-false}" cm="${6-}"
  local p="$BATS_TEST_TMPDIR/work/issue-$n"
  mkdir -p "$p"
  printf '{"id":"%s::%s","repoId":"%s","path":"%s","branch":"refs/heads/oratta/issue-%s","linkedIssue":%s,"isArchived":%s,"isMainWorktree":false,"workspaceStatus":"%s","parentWorktreeId":"%s","comment":"%s"}' \
    "$repo" "$p" "$repo" "$p" "$n" "$n" "$arch" "$st" "$par" "$cm"
}

# 一覧を置く（引数は wt_entry の出力。<file> の既定は list_json）
set_list() { local f="$1"; shift; local IFS=,; printf '{"result":{"worktrees":[%s]}}\n' "$*" > "$STUB_CFG/$f"; }

# 今のワークツリー（id と linkedIssue を持つ。2 番目の引数はコメント欄。既定は空）
set_current() {
  printf '{"result":{"worktree":{"id":"repo-a::/work/parent","repoId":"repo-a","path":"/work/parent","linkedIssue":%s,"comment":"%s"}}}\n' "$1" "${2-}" > "$STUB_CFG/current_json"
}

# 今のワークツリーを、親ワークツリー（linkedIssue が <1>。null も可）を持つ子にする
set_child_of() {
  printf '%s\n' '{"result":{"worktree":{"id":"repo-a::/work/issue-460","repoId":"repo-a","path":"/work/issue-460","linkedIssue":460,"parentWorktreeId":"repo-a::/work/parent"}}}' > "$STUB_CFG/current_json"
  printf '{"result":{"worktrees":[{"id":"repo-a::/work/parent","repoId":"repo-a","path":"/work/parent","linkedIssue":%s,"isArchived":false,"parentWorktreeId":null}]}}\n' "$1" > "$STUB_CFG/list_json"
}

# ログで最初に一致した行の番号
first_line() { LC_ALL=C awk -v re="$1" '$0 ~ re { print NR; exit }' "$STUB_LOG"; }

# reap の条件をすべて満たす子 11 の環境
reap_ready() {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 completed)"
  echo aaa111 > "$STUB_CFG/pr_out"
}

# PR の無い子 11 の環境（reap_ready から merged PR を消し、issue 11 を closed にする）
reap_prless_ready() {
  reap_ready
  : > "$STUB_CFG/pr_out"
  gh_seq 11 closed
}

# SKILL.md の「## <見出し>」から次の「## 」まで
section() { awk -v h="## $1" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$SKILL"; }
# 「エピックの扱い」の「### 回し方」から次の「### 」まで
run_section() { section 'エピックの扱い' | awk '/^### 回し方/{f=1; print; next} /^### /{f=0} f'; }

# --- route ---

@test "route: without orca on PATH, two children go to subagent" {
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
}

@test "route: orca present but not an Orca-managed worktree goes to subagent" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
}

@test "route: one child under Orca goes to orca" {
  make_stub orca
  run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree current')" -eq 1 ]
}

@test "route: one child without orca on PATH goes to subagent" {
  run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
}

@test "route: one child outside an Orca-managed worktree goes to subagent" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
}

@test "route: no children under Orca still goes to subagent" {
  make_stub orca
  run dispatch route
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
}

@test "route: EPIC_DISPATCH_PARENT_EPIC with one child is nested without calling orca" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "route: two children under Orca go to orca" {
  make_stub orca
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree current')" -eq 1 ]
}

@test "route: a non-numeric child is rejected" {
  make_stub orca
  run dispatch route '#12' 13
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "route: EPIC_DISPATCH_PARENT_EPIC goes to nested without calling orca" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "route: EPIC_DISPATCH_PARENT_EPIC still rejects a non-numeric child" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch route '#11'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
}

@test "route: EPIC_DISPATCH_PARENT_EPIC prints the parent epic on stderr" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  grep -qxF 'parent epic: #420' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "route: a parent worktree with a linked issue goes to nested without the variable" {
  make_stub orca
  set_child_of 420
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  grep -qxF 'parent epic: #420' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree current')" -eq 1 ]
}

@test "route: one child or none is nested too when the parent worktree has a linked issue" {
  make_stub orca
  set_child_of 420
  run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  run dispatch route
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
}

@test "route: a parent worktree without a linked issue routes as before" {
  make_stub orca
  set_child_of null
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(grep -c 'parent epic' "$BATS_TEST_TMPDIR/stderr" || true)" -eq 0 ]
}

@test "route: a parent worktree missing from the list routes as before" {
  make_stub orca
  set_child_of 420
  printf '%s\n' '{"result":{"worktrees":[]}}' > "$STUB_CFG/list_json"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
}

@test "route: no parent worktree and no variable routes as before without reading the list" {
  make_stub orca
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree current')" -eq 1 ]
  run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree current')" -eq 2 ]
  printf '%s\n' '{"result":{"worktree":{"id":"repo-a::/work/parent","repoId":"repo-a","path":"/work/parent","parentWorktreeId":null}}}' > "$STUB_CFG/current_json"
  run dispatch route 11 12
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree list')" -eq 0 ]
}

@test "route: an unreadable list means not a child, with a warning" {
  make_stub orca
  set_child_of 420
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
  rm "$STUB_CFG/list_exit"
  printf '%s\n' '{"result":{}}' > "$STUB_CFG/list_json"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
}

@test "route: without jq the parent is not read and the route is as before, with a warning" {
  make_stub orca
  set_child_of 420
  run dispatch_nojq route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree list')" -eq 0 ]
}

# --- launch ---

@test "launch: call order is current, toplevel, fetch, set, list, then create, terminal create, wait and send per child" {
  make_stub orca
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
  log=()
  while IFS= read -r l; do log+=("$l"); done < "$STUB_LOG"
  [ "${#log[@]}" -eq 15 ]
  [ "${log[0]}" = "orca worktree current --json" ]
  [ "${log[1]}" = "git rev-parse --show-toplevel" ]
  [ "${log[2]}" = "git fetch origin main" ]
  [ "${log[3]}" = "orca worktree set --worktree path:/work/parent --issue 400" ]
  [ "${log[4]}" = "orca worktree list --json" ]
  [ "${log[5]}" = "orca worktree create --name issue-11 --issue 11 --base-branch origin/main --parent-worktree path:/work/parent --json" ]
  [ "${log[6]}" = "orca terminal list --worktree path:/work/issue-11 --json" ]
  starts_with "${log[7]}" "orca terminal create --worktree path:/work/issue-11 --command "
  case "${log[7]}" in *' --json') ;; *) echo "terminal create must end with --json" >&2; false ;; esac
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'" ]
  [ "${log[8]}" = "orca terminal wait --terminal term-11 --for tui-idle --timeout-ms 60000 --json" ]
  starts_with "${log[9]}" "orca terminal send --terminal term-11 --text "
  case "${log[9]}" in *' --enter --wait-submit 30 --json') ;; *) echo "send must end with --enter --wait-submit 30 --json" >&2; false ;; esac
  [ "${log[10]}" = "orca worktree create --name issue-12 --issue 12 --base-branch origin/main --parent-worktree path:/work/parent --json" ]
  [ "${log[11]}" = "orca terminal list --worktree path:/work/issue-12 --json" ]
  starts_with "${log[12]}" "orca terminal create --worktree path:/work/issue-12 --command "
  [ "${log[13]}" = "orca terminal wait --terminal term-12 --for tui-idle --timeout-ms 60000 --json" ]
  starts_with "${log[14]}" "orca terminal send --terminal term-12 --text "
  [ "$(calls '--prompt')" -eq 0 ]
  [ "$(calls '--agent')" -eq 0 ]
}

# worktree create が空のシェルの端末（Terminal 1）を 1 つ作る実物の Orca の場面
@test "launch: the shell terminal from worktree create is reused, so the child has exactly one terminal running the session" {
  make_stub orca
  set_terms 11 term-11
  mv "$STUB_CFG/tlist_json_11" "$STUB_CFG/tlist_after_11"
  set_terms 11 term-11:shell
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
  # 起動コマンドを同じ端末に打ち込み、そのあと指示を送る。環境変数の意味は従来の terminal create と同じ
  first_send="$(grep -m1 '^orca terminal send --terminal term-11 ' "$STUB_LOG")"
  case "$first_send" in *"EPIC_DISPATCH_PARENT_EPIC=400"*"CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000"*"cld"*"--model"*" --enter --json") ;; *) echo "$first_send" >&2; false ;; esac
  [ "$(calls '^orca terminal send --terminal term-11 ')" -eq 2 ]
  [ "$(calls '^orca terminal wait --terminal term-11 --for tui-idle')" -eq 1 ]
  case "$(cat "$STUB_CFG/sent_term-11")" in "/develop #11 "*) ;; *) false ;; esac
  # 最後の端末一覧は 1 行で、その端末が Claude Code
  [ "$(jq '.result.terminals | length' "$STUB_CFG/tlist_after_11")" -eq 1 ]
  [ "$(jq -r '.result.terminals[0].agentIdentity' "$STUB_CFG/tlist_after_11")" = claude ]
}

@test "launch: the shell terminal never becomes Claude Code means failed without a second terminal" {
  make_stub orca
  set_terms 11 term-11:shell
  EPIC_DISPATCH_READY_TIMEOUT_MS=2000 run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^orca terminal wait')" -eq 0 ]
  grep -qF 'did not become Claude Code' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: a second terminal appearing after the start command is typed is failed without sending the prompt" {
  make_stub orca
  set_terms 11 term-11 term-x:shell
  mv "$STUB_CFG/tlist_json_11" "$STUB_CFG/tlist_after_11"
  set_terms 11 term-11:shell
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^orca terminal wait')" -eq 0 ]
  [ "$(calls '^orca terminal send --terminal term-11 ')" -eq 1 ]
  grep -qF 'terminals' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: two or more terminals in the new worktree is failed without creating another" {
  make_stub orca
  set_terms 11 term-11:shell term-x
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^orca terminal send')" -eq 0 ]
}

@test "launch: an unreadable terminal list is failed without creating a terminal" {
  make_stub orca
  echo 1 > "$STUB_CFG/tlist_exit"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
}

@test "launch: EPIC_DISPATCH_MODEL changes the model passed to --model" {
  make_stub orca
  EPIC_DISPATCH_MODEL='opus[1m]' run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus[1m]'" ]
}

@test "launch: EPIC_DISPATCH_CLAUDE_CMD replaces the command as is" {
  make_stub orca
  EPIC_DISPATCH_CLAUDE_CMD='cld-account b' run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld-account b --model 'opus'" ]
}

@test "launch: an empty EPIC_DISPATCH_CLAUDE_CMD creates nothing" {
  make_stub orca
  EPIC_DISPATCH_CLAUDE_CMD= run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: an empty EPIC_DISPATCH_MODEL creates nothing" {
  make_stub orca
  EPIC_DISPATCH_MODEL= run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS changes the idle compaction threshold" {
  make_stub orca
  EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=150000 run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=150000 cld --model 'opus'" ]
}

@test "launch: an empty EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS calls neither orca nor git" {
  make_stub orca
  make_stub git
  EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS= run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -qF 'EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS' "$BATS_TEST_TMPDIR/stderr"
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
  [ ! -s "$STUB_LOG" ]
}

@test "launch: a non-numeric EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS calls neither orca nor git" {
  make_stub orca
  make_stub git
  for v in 120k 1.2e5 120,000 '120000 x'; do
    EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS="$v" run dispatch launch 400 11
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    grep -qF 'EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS' "$BATS_TEST_TMPDIR/stderr"
    grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
  done
  [ ! -s "$STUB_LOG" ]
}

@test "launch: a failing terminal create is failed and prints the terminal create and send commands" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(calls '^orca terminal wait ')" -eq 1 ]
  [ "$(calls '^orca terminal send ')" -eq 1 ]
  grep -F 'orca terminal create --worktree path:/work/issue-11' "$BATS_TEST_TMPDIR/stderr" | grep -qF 'cld --model'
  grep -F 'orca terminal send' "$BATS_TEST_TMPDIR/stderr" | grep -qF '/develop #11'
  grep -qF -- '--terminal <handle from create>' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: the recreate hint first tells to check for a terminal already running there" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch launch 420 11
  [ "$status" -eq 1 ]
  chk="$(grep -nF 'orca terminal list --worktree path:/work/issue-11 --json' "$BATS_TEST_TMPDIR/stderr" | head -1 | cut -d: -f1)"
  mk="$(grep -nF 'create: orca terminal create --worktree' "$BATS_TEST_TMPDIR/stderr" | head -1 | cut -d: -f1)"
  [ -n "$chk" ]
  [ -n "$mk" ]
  [ "$chk" -lt "$mk" ]
}

@test "launch: the recreate command carries the EPIC_DISPATCH_PARENT_EPIC prefix" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch launch 420 11
  [ "$status" -eq 1 ]
  grep -F 'orca terminal create --worktree path:/work/issue-11' "$BATS_TEST_TMPDIR/stderr" \
    | grep -qF -- "--command 'EPIC_DISPATCH_PARENT_EPIC=420 "
}

@test "launch: EPIC_DISPATCH_PARENT_EPIC creates nothing and calls neither orca nor git" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca ')" -eq 0 ]
  [ "$(calls '^git ')" -eq 0 ]
  grep -qF '420' "$BATS_TEST_TMPDIR/stderr"
  grep -qF 'child epics are not expanded here' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: a parent worktree with a linked issue creates nothing, before git and set" {
  make_stub orca
  set_child_of 420
  run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^git ')" -eq 0 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  grep -F '420' "$BATS_TEST_TMPDIR/stderr" | grep -qF 'child epics are not expanded here'
}

@test "launch: an unreadable list under a parent worktree stops before git and set" {
  make_stub orca
  set_child_of 420
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^git ')" -eq 0 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  [ "$(calls '^orca worktree list')" -eq 1 ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
  rm "$STUB_CFG/list_exit"
  : > "$STUB_LOG"
  printf '%s\n' '{"result":{}}' > "$STUB_CFG/list_json"
  run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^git ')" -eq 0 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: without a parent worktree a failing list still comes after fetch and set" {
  make_stub orca
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls '^git fetch ')" -eq 1 ]
  [ "$(calls '^orca worktree set')" -eq 1 ]
  [ "$(calls '^orca worktree list')" -eq 1 ]
  [ "$(first_line '^orca worktree set')" -lt "$(first_line '^orca worktree list')" ]
}

@test "launch: a parent worktree without a linked issue launches as before" {
  make_stub orca
  set_child_of null
  run dispatch launch 460 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
}

@test "launch: no worktree path in create means failed without terminal create" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{}}' > "$STUB_CFG/create_json_11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(calls '^orca terminal create ')" -eq 0 ]
}

@test "launch: prompt starts with /develop #N and names the epic" {
  make_stub orca
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  p="$(cat "$STUB_CFG/sent_term-11")"
  starts_with "$p" "/develop #11 "
  printf '%s' "$p" | grep -qF '#400'
  printf '%s' "$p" | grep -qF '/work/parent'
}

@test "launch: --note text is appended to every child prompt" {
  make_stub orca
  run dispatch launch --note "do not touch the follow-up scope" 400 11 12
  [ "$status" -eq 0 ]
  grep -qF 'do not touch the follow-up scope' "$STUB_CFG/sent_term-11"
  grep -qF 'do not touch the follow-up scope' "$STUB_CFG/sent_term-12"
}

@test "launch: --note is posted once per child as an issue comment, before the terminal is created" {
  make_stub orca
  run dispatch launch --note "後続の範囲に手を出さない" 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "$(calls '^gh issue comment 11 --body ')" -eq 1 ]
  [ "$(calls '^gh issue comment 12 --body ')" -eq 1 ]
  [ "$(calls '^gh issue comment ')" -eq 2 ]
  for n in 11 12; do
    [ "$(sed -n 1p "$STUB_CFG/comment_$n")" = "親エピックからの注意書き: #400" ]
    [ -z "$(sed -n 2p "$STUB_CFG/comment_$n")" ]
    [ "$(sed -n 3p "$STUB_CFG/comment_$n")" = "後続の範囲に手を出さない" ]
    [ "$(first_line "^gh issue comment $n ")" -lt "$(first_line "^orca terminal create --worktree path:/work/issue-$n ")" ]
    [ "$(first_line "^gh issue comment $n ")" -gt "$(first_line "^orca worktree create --name issue-$n ")" ]
  done
}

@test "launch: stdout stays launched|skipped|failed lines only even though gh prints the comment URL on stdout" {
  make_stub orca
  run dispatch launch --note "x" 400 11 12
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ] || return 1
  for l in "${lines[@]}"; do
    printf '%s\n' "$l" | grep -Eq '^(launched|skipped|failed) [0-9]+$' || return 1
  done
  [ "$(calls '^gh issue comment ')" -eq 2 ] || return 1
}

@test "launch: without --note no comment is posted" {
  make_stub orca
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "launch: skipped children and children whose worktree create failed get no comment" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[{"repoId":"repo-a","linkedIssue":11,"isArchived":false}]}}' > "$STUB_CFG/list_json"
  touch "$STUB_CFG/create_fail_12"
  run dispatch launch --note "x" 400 11 12 13 13
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "skipped 11" ]
  [ "${lines[1]}" = "failed 12" ]
  [ "${lines[2]}" = "launched 13" ]
  [ "${lines[3]}" = "skipped 13" ]
  [ "$(calls '^gh issue comment ')" -eq 1 ]
  [ "$(calls '^gh issue comment 13 ')" -eq 1 ]
}

@test "launch: a child whose terminal could not be created still gets the comment" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch launch --note "x" 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(calls '^gh issue comment 11 ')" -eq 1 ]
}

@test "launch: a child with no worktree path in create still gets the comment" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{}}' > "$STUB_CFG/create_json_11"
  run dispatch launch --note "x" 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(calls '^gh issue comment 11 ')" -eq 1 ]
}

@test "launch: a failing comment does not change the result and prints the command to post it" {
  make_stub orca
  echo 1 > "$STUB_CFG/comment_exit"
  run dispatch launch --note "don't touch" 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  grep -qF 'note not posted to #11' "$BATS_TEST_TMPDIR/stderr"
  grep -qF "gh issue comment 11 --body '親エピックからの注意書き: #400" "$BATS_TEST_TMPDIR/stderr"
  grep -qF "don'\\''t touch'" "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: EPIC_DISPATCH_BASE changes the base for fetch and --base-branch" {
  make_stub orca
  EPIC_DISPATCH_BASE=develop run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^git fetch origin develop$')" -eq 1 ]
  [ "$(calls '--base-branch origin/develop ')" -eq 1 ]
}

@test "launch: --base wins over EPIC_DISPATCH_BASE" {
  make_stub orca
  EPIC_DISPATCH_BASE=develop run dispatch launch --base trunk 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^git fetch origin trunk$')" -eq 1 ]
  [ "$(calls '--base-branch origin/trunk ')" -eq 1 ]
  [ "$(calls 'origin develop')" -eq 0 ]
  [ "$(calls 'origin/develop')" -eq 0 ]
}

@test "launch: an existing worktree for the same repo and issue is skipped" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[{"repoId":"repo-a","path":"/w/issue-11","linkedIssue":11,"isArchived":false}]}}' > "$STUB_CFG/list_json"
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "skipped 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 0 ]
  [ "$(calls '^orca worktree create --name issue-12 ')" -eq 1 ]
}

@test "launch: a duplicate child number in the same call is skipped after the first" {
  make_stub orca
  run dispatch launch 420 11 11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "skipped 11" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
}

@test "launch: list-based skipped and same-call duplicate skipped coexist" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[{"repoId":"repo-a","path":"/w/issue-12","linkedIssue":12,"isArchived":false}]}}' > "$STUB_CFG/list_json"
  run dispatch launch 420 11 12 11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "skipped 12" ]
  [ "${lines[2]}" = "skipped 11" ]
  [ "${#lines[@]}" -eq 3 ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
  [ "$(calls '^orca worktree create --name issue-12 ')" -eq 0 ]
}

@test "launch: a failed first attempt still skips a later duplicate of the same number" {
  make_stub orca
  touch "$STUB_CFG/create_fail_11"
  run dispatch launch 420 11 11
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "skipped 11" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
}

@test "launch: a worktree of another repo or an archived one does not count as launched" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[{"repoId":"repo-b","path":"/w/x","linkedIssue":11,"isArchived":false},{"repoId":"repo-a","path":"/w/y","linkedIssue":12,"isArchived":true}]}}' > "$STUB_CFG/list_json"
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "launched 12" ]
}

@test "launch: failing worktree current creates nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: failing fetch creates nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/fetch_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: failing set creates nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/set_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: failing list creates nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: one failed create still launches the rest and exits 1" {
  make_stub orca
  touch "$STUB_CFG/create_fail_11"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "launch: no terminal handle means failed without wait or send" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{}}' > "$STUB_CFG/tcreate_json_11"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "$(calls '^orca terminal wait --terminal term-12 ')" -eq 1 ]
  [ "$(calls '^orca terminal wait ')" -eq 1 ]
  [ "$(calls '^orca terminal send ')" -eq 1 ]
}

@test "launch: a failing send is failed and prints a resend command with a read hint" {
  make_stub orca
  echo 1 > "$STUB_CFG/send_exit_term-11"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
  grep -F "orca terminal send --terminal 'term-11' --text" "$BATS_TEST_TMPDIR/stderr" | grep -qF '/develop #11'
  grep -qF "orca terminal read --terminal 'term-11'" "$BATS_TEST_TMPDIR/stderr"
  [ "$(grep -c -- '--retry-request' "$BATS_TEST_TMPDIR/stderr" || true)" -eq 0 ]
}

@test "launch: a retry request id from send is added to the resend command" {
  make_stub orca
  echo 1 > "$STUB_CFG/send_exit_term-11"
  printf '%s\n' '{"ok":false,"result":{"retryRequestId":"rq-1","stages":["input_accepted"]}}' > "$STUB_CFG/send_json_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  grep -F "orca terminal send --terminal 'term-11'" "$BATS_TEST_TMPDIR/stderr" | grep -qF -- '--retry-request rq-1'
  grep -qF "orca terminal read --terminal 'term-11'" "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: a send without turn_started is failed" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{"stages":["input_accepted"]}}' > "$STUB_CFG/send_json_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
}

@test "launch: turn_started in a nested stages array counts" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{"receipt":{"stages":["input_accepted","turn_started"]}}}' > "$STUB_CFG/send_json_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
}

@test "launch: a failing tui-idle wait is failed without send" {
  make_stub orca
  echo 1 > "$STUB_CFG/wait_exit_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(calls '^orca terminal send ')" -eq 0 ]
}

@test "launch: EPIC_DISPATCH_READY_TIMEOUT_MS and EPIC_DISPATCH_SUBMIT_WAIT set the waits" {
  make_stub orca
  EPIC_DISPATCH_READY_TIMEOUT_MS=5000 EPIC_DISPATCH_SUBMIT_WAIT=7 run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal wait --terminal term-11 --for tui-idle --timeout-ms 5000 --json$')" -eq 1 ]
  [ "$(calls ' --enter --wait-submit 7 --json$')" -eq 1 ]
}

@test "launch: a non-numeric wait variable creates nothing" {
  make_stub orca
  EPIC_DISPATCH_SUBMIT_WAIT=abc run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
  EPIC_DISPATCH_READY_TIMEOUT_MS=1s run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: without orca on PATH nothing is called" {
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ ! -s "$STUB_LOG" ]
}

@test "launch: a non-numeric epic or child is rejected before anything is called" {
  make_stub orca
  run dispatch launch '#400' 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch launch 400 '#11'
  [ "$status" -eq 1 ]
  [ ! -s "$STUB_LOG" ]
}

@test "launch: orca output goes to stderr, stdout has only the per-child lines" {
  make_stub orca
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  grep -q '"ok":true' "$BATS_TEST_TMPDIR/stderr"
}

# --- mark ---

@test "mark: done on the linked workspace sets completed" {
  make_stub orca
  set_current 11
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 done" ]
  [ "$(calls '^orca worktree set --worktree current --workspace-status completed$')" -eq 1 ]
}

@test "mark: waiting sets in-review" {
  make_stub orca
  set_current 11
  run dispatch mark waiting 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 waiting" ]
  [ "$(calls '^orca worktree set --worktree current --workspace-status in-review$')" -eq 1 ]
}

@test "mark: another issue's workspace is not marked" {
  make_stub orca
  set_current 400
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 not-linked" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "mark: a workspace without a linked issue is not marked" {
  make_stub orca
  set_current null
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 not-linked" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "mark: outside Orca and without orca it does nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 no-workspace" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  rm -f "$STUB_BIN/orca"; : > "$STUB_LOG"
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 no-workspace" ]
  [ ! -s "$STUB_LOG" ]
}

@test "mark: EPIC_DISPATCH_PARENT_EPIC does not change it" {
  make_stub orca
  set_current 11
  EPIC_DISPATCH_PARENT_EPIC=400 run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 done" ]
  [ "$(calls '^orca worktree set --worktree current --workspace-status completed$')" -eq 1 ]
}

@test "mark: a failing set ends with failed" {
  make_stub orca
  set_current 11
  echo 1 > "$STUB_CFG/set_exit"
  run dispatch mark done 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
}

@test "mark: orca's own output goes to stderr" {
  make_stub orca
  set_current 11
  run dispatch mark done 11
  [ "${#lines[@]}" -eq 1 ]
  grep -qF '"ok":true' "$BATS_TEST_TMPDIR/stderr"
}

@test "mark: bad arguments are rejected without calling orca" {
  make_stub orca
  set_current 11
  run dispatch mark completed 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark done
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark done '#11'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark done 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark stop 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark resumed
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark stopped 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca')" -eq 0 ]
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
}

# spec: dev-workflow-develop（epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す）

@test "mark: stopped on the linked workspace sets the comment, not the board column" {
  make_stub orca
  set_current 460
  run dispatch mark stopped 460
  [ "$status" -eq 0 ]
  [ "$output" = "marked 460 stopped" ]
  [ "$(calls '^orca worktree set --worktree current --comment epic-stopped$')" -eq 1 ]
  [ "$(calls 'workspace-status')" -eq 0 ]
}

@test "mark: stopped on another issue's workspace is not marked" {
  make_stub orca
  set_current 461
  run dispatch mark stopped 460
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 460 not-linked" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "mark: resumed rewrites only a stopped or seen comment" {
  make_stub orca
  set_current 460 epic-stopped
  run dispatch mark resumed 460
  [ "$status" -eq 0 ]
  [ "$output" = "marked 460 resumed" ]
  [ "$(calls '^orca worktree set --worktree current --comment epic-resumed$')" -eq 1 ]
  : > "$STUB_LOG"
  set_current 460 epic-stopped-seen
  run dispatch mark resumed 460
  [ "$status" -eq 0 ]
  [ "$output" = "marked 460 resumed" ]
  [ "$(calls '^orca worktree set --worktree current --comment epic-resumed$')" -eq 1 ]
  : > "$STUB_LOG"
  set_current 460 メモ
  run dispatch mark resumed 460
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 460 not-stopped" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ "$(calls '^orca worktree current --json$')" -eq 1 ]
}

@test "mark: resumed on another issue's workspace is not marked" {
  make_stub orca
  set_current 461 epic-stopped
  run dispatch mark resumed 460
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 460 not-linked" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "mark: a failing stopped or resumed set ends with failed" {
  make_stub orca
  set_current 460 epic-stopped
  echo 1 > "$STUB_CFG/set_exit"
  run dispatch mark stopped 460
  [ "$status" -eq 1 ]
  [ "$output" = "failed 460" ]
  run dispatch mark resumed 460
  [ "$status" -eq 1 ]
  [ "$output" = "failed 460" ]
}

@test "mark: stopped and resumed outside Orca do nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch mark stopped 460
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 460 no-workspace" ]
  run dispatch mark resumed 460
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 460 no-workspace" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

# --- wait ---

@test "wait: a child closing on the second poll ends with closed" {
  gh_seq 11 open
  gh_seq 12 open closed
  run dispatch wait --interval 0 --timeout 60 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "closed 12" ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "wait: all open with --timeout 0 ends with timeout after one poll" {
  gh_seq 11 open
  gh_seq 12 open
  run dispatch wait --interval 0 --timeout 0 11 12
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout 11 12" ]
  [ "${#lines[@]}" -eq 1 ]
  [ "$(calls '^gh ')" -eq 2 ]
  [ "$(calls '^sleep')" -eq 0 ]
}

@test "wait: the interval is passed to sleep" {
  gh_seq 11 open open closed
  run dispatch wait --interval 7 --timeout 100 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  [ "$(calls '^sleep 7$')" -eq 2 ]
}

@test "wait: gh uses the REST issues endpoint with --jq .state" {
  gh_seq 11 closed
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  grep -q '^gh api repos/.*owner.*/.*repo.*/issues/11 --jq .state$' "$STUB_LOG"
}

@test "wait: EPIC_DISPATCH_TIMEOUT=0 alone times out" {
  gh_seq 11 open
  EPIC_DISPATCH_TIMEOUT=0 run dispatch wait --interval 0 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout 11" ]
}

@test "wait: --timeout wins over EPIC_DISPATCH_TIMEOUT" {
  gh_seq 11 open closed
  EPIC_DISPATCH_TIMEOUT=0 run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
}

@test "wait: EPIC_DISPATCH_INTERVAL sets the default and --interval wins" {
  gh_seq 11 open closed
  EPIC_DISPATCH_INTERVAL=5 run dispatch wait --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$(calls '^sleep 5$')" -eq 1 ]
  : > "$STUB_LOG"; rm -f "$STUB_CFG/ghcount_11"
  EPIC_DISPATCH_INTERVAL=5 run dispatch wait --interval 3 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$(calls '^sleep 3$')" -eq 1 ]
  [ "$(calls '^sleep 5$')" -eq 0 ]
}

@test "wait: gh failing every poll ends with error after three polls" {
  gh_seq 11 FAIL
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 11" ]
  [ "${#lines[@]}" -eq 1 ]
  [ "$(calls '^gh ')" -eq 3 ]
}

@test "wait: gh's stderr is shown right before the error line" {
  gh_seq 11 FAIL
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 11" ]
  grep -qF 'gh: mock failure for issue 11' "$BATS_TEST_TMPDIR/stderr"
  grep -qF '(poll 3)' "$BATS_TEST_TMPDIR/stderr"
  [ "$(grep -c 'mock failure' "$BATS_TEST_TMPDIR/stderr")" -eq 1 ]
}

@test "wait: one child failing while another stays open still ends with error" {
  gh_seq 11 FAIL
  gh_seq 12 open
  run dispatch wait --interval 0 --timeout 60 11 12
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 11" ]
  [ "$(calls 'issues/11 ')" -eq 3 ]
}

@test "wait: an empty state counts as a failure" {
  gh_seq 11 ""
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 11" ]
}

@test "wait: a clean poll resets the failure count" {
  gh_seq 11 FAIL FAIL open FAIL FAIL closed
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  [ "$(calls '^gh ')" -eq 6 ]
}

@test "wait: a closed child wins over another child's failure" {
  gh_seq 11 FAIL
  gh_seq 12 closed
  run dispatch wait --interval 0 --timeout 60 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "closed 12" ]
}

@test "wait: timeout lists children that failed on the last poll too" {
  gh_seq 11 FAIL
  gh_seq 12 open
  run dispatch wait --interval 0 --timeout 0 11 12
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout 11 12" ]
}

@test "wait: no children, a non-numeric child, or a bad interval is rejected" {
  run dispatch wait --interval 0 --timeout 0
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval 0 --timeout 0 '#11'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval -1 --timeout 0 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval 1.5 --timeout 0 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval 0 --timeout abc 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait: --watch-done ends with done when the mark appears while the issue stays open" {
  make_stub orca
  set_current 400
  gh_seq 11 open
  set_list list_json_1 "$(wt_entry 11 in-review)"
  set_list list_json "$(wt_entry 11 completed)"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "done 11" ]
  [ "$(calls '^gh ')" -eq 2 ]
  [ "$(calls '^orca worktree list --json$')" -eq 2 ]
}

@test "wait: closed and done in the same poll print two lines, closed first" {
  make_stub orca
  set_current 400
  gh_seq 12 closed
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 12 in-review)"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 --watch-done 12 12
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "closed 12" ]
  [ "${lines[1]}" = "done 11" ]
}

@test "wait: --watch-done alone waits without gh and times out with a bare timeout" {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 in-review)"
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout" ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait: without --watch-done orca is never called" {
  make_stub orca
  gh_seq 11 closed
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "wait: marks on another repo or on archived worktrees do not count" {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 completed repo-b::/x repo-b)" "$(wt_entry 11 completed repo-a::/work/parent repo-a true)"
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
}

@test "wait: three polls without a readable list end with error workspaces" {
  make_stub orca
  set_current 400
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 1 ]
  [ "$output" = "error workspaces" ]
  [ "$(calls '^orca worktree list')" -eq 3 ]
}

@test "wait: an unreadable list with a failing gh child ends with error gh" {
  make_stub orca
  set_current 400
  echo 1 > "$STUB_CFG/list_exit"
  gh_seq 12 FAIL
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 12
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 12" ]
}

@test "wait: --watch-done fails with no stdout when the current worktree cannot be read" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^gh ')" -eq 0 ]
  rm -f "$STUB_BIN/orca"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "wait: a non-numeric --watch-done is rejected" {
  make_stub orca
  run dispatch wait --interval 0 --timeout 0 --watch-done '#11' 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval 0 --timeout 0 --watch-done
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca')" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
}

# --- wait --watch-stopped ---
# spec: dev-workflow-develop（epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す）

@test "wait: --watch-stopped rewrites a stopped child to seen and ends with stopped" {
  make_stub orca
  set_current 400
  gh_seq 11 open
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(calls "^orca worktree set --worktree path:$BATS_TEST_TMPDIR/work/issue-11 --comment epic-stopped-seen\$")" -eq 1 ]
  [ "$(calls '^orca worktree set')" -eq 1 ]
  [ "$(calls 'workspace-status')" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "wait: --watch-stopped does not wake on seen or resumed comments" {
  make_stub orca
  set_current 400
  gh_seq 11 open
  gh_seq 12 open
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped-seen)" \
    "$(wt_entry 12 in-review repo-a::/work/parent repo-a false epic-resumed)"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11 12
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11 12" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait: closed, done and stopped in the same poll print three lines in that order" {
  make_stub orca
  set_current 400
  gh_seq 12 closed
  gh_seq 13 open
  set_list list_json "$(wt_entry 11 completed)" \
    "$(wt_entry 13 in-review repo-a::/work/parent repo-a false epic-stopped)"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 --watch-stopped 12 13
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "closed 12" ]
  [ "${lines[1]}" = "done 11" ]
  [ "${lines[2]}" = "stopped 13" ]
  [ "$(calls '^orca worktree list --json$')" -eq 1 ]
  [ "$(calls '^gh ')" -eq 2 ]
}

@test "wait: a closed child is not counted as stopped" {
  make_stub orca
  set_current 400
  gh_seq 11 closed
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait: stopped comments on another repo or on archived worktrees do not count" {
  make_stub orca
  set_current 400
  gh_seq 11 open
  set_list list_json "$(wt_entry 11 in-review repo-b::/x repo-b false epic-stopped)" \
    "$(wt_entry 11 in-review repo-a::/work/parent repo-a true epic-stopped)"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait: three polls failing to rewrite to seen end with error workspaces" {
  make_stub orca
  set_current 400
  gh_seq 11 open
  echo 1 > "$STUB_CFG/set_comment_exit"
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 1 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "error workspaces" ]
  [ "$(calls '^orca worktree set')" -eq 3 ]
  [ "$(calls '^orca worktree list --json$')" -eq 3 ]
}

@test "wait: without --watch-stopped the comment is never read" {
  make_stub orca
  set_current 400
  gh_seq 11 open
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)"
  run dispatch wait --interval 0 --timeout 0 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11" ]
  [ "$(calls '^orca')" -eq 0 ]
  run dispatch wait --interval 0 --timeout 0 --watch-done 12 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait: --watch-stopped with --watch-done and no positional child looks at no comment" {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)"
  run dispatch wait --interval 0 --timeout 0 --watch-done 11 --watch-stopped
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait: a seen stop does not wake the parent again, a stop marked again does" {
  make_stub orca
  printf '{"result":{"worktree":{"id":"repo-a::%s","repoId":"repo-a","path":"%s","linkedIssue":11,"comment":""}}}\n' \
    "$BATS_TEST_TMPDIR/work/issue-11" "$BATS_TEST_TMPDIR/work/issue-11" > "$STUB_CFG/current_json"
  gh_seq 11 open
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ] || { echo "1st: status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(calls '^orca worktree set')" -eq 1 ]
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 2 ] || { echo "2nd: status=$status output=$output"; cat "$STUB_CFG/list_json"; false; }
  [ "$output" = "timeout 11" ]
  [ "$(calls '^orca worktree set')" -eq 1 ]
  run dispatch mark stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 stopped" ]
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ] || { echo "3rd: status=$status output=$output"; cat "$STUB_CFG/list_json"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(calls '^orca worktree set')" -eq 3 ]
}

@test "wait: --watch-stopped alone without children prints usage and calls nothing" {
  make_stub orca
  run dispatch wait --interval 0 --timeout 0 --watch-stopped
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca')" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
}

# --- reap ---

@test "reap: a child meeting every condition is closed then removed, without --force" {
  reap_ready
  run dispatch reap 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "reaped 11" ]
  p="$BATS_TEST_TMPDIR/work/issue-11"
  close_line="$(grep -n "^orca terminal close --worktree path:$p --all$" "$STUB_LOG" | cut -d: -f1)"
  rm_line="$(grep -n "^orca worktree rm --worktree path:$p$" "$STUB_LOG" | cut -d: -f1)"
  [ -n "$close_line" ] && [ -n "$rm_line" ]
  [ "$close_line" -lt "$rm_line" ]
  [ "$(calls '^orca terminal close')" -eq 1 ]
  [ "$(calls '^orca worktree rm')" -eq 1 ]
  [ "$(calls '^orca .*--force')" -eq 0 ]
  grep -qF -- 'gh pr list --head oratta/issue-11 --state merged --json headRefOid' "$STUB_LOG"
}

@test "reap: a child off by one condition is kept with the reason" {
  p="$BATS_TEST_TMPDIR/work/issue-11"
  for c in not-done head-mismatch dirty llm-logs not-child; do
    rm -rf "$STUB_CFG" "$p"; mkdir -p "$STUB_CFG"; : > "$STUB_LOG"
    printf '%s\n' '/work/parent' > "$STUB_CFG/toplevel"
    reap_ready
    case "$c" in
      not-done) set_list list_json "$(wt_entry 11 in-review)" ;;
      head-mismatch) echo bbb222 > "$STUB_CFG/head" ;;
      dirty) echo ' M a.txt' > "$STUB_CFG/status_out" ;;
      llm-logs) mkdir -p "$p/LLM" ;;
      not-child) set_list list_json "$(wt_entry 11 completed repo-a::/work/other)" ;;
    esac
    echo aaa111 > "$STUB_CFG/branch_tip"
    run dispatch reap 11
    [ "$status" -eq 0 ] || { echo "$c: status=$status"; false; }
    [ "$output" = "kept 11 $c" ] || { echo "$c: output=$output"; false; }
    [ "$(calls '^orca terminal close')" -eq 0 ]
    [ "$(calls '^orca worktree rm')" -eq 0 ]
    [ "$(calls '^git branch -D')" -eq 0 ]
  done
}

@test "reap: a main worktree, a failing git status, and a detached HEAD are kept" {
  reap_ready
  p="$BATS_TEST_TMPDIR/work/issue-11"
  set_list list_json "$(wt_entry 11 completed | sed 's/"isMainWorktree":false/"isMainWorktree":true/')"
  run dispatch reap 11
  [ "$output" = "kept 11 not-child" ]
  set_list list_json "$(wt_entry 11 completed)"
  echo 128 > "$STUB_CFG/status_exit"
  run dispatch reap 11
  [ "$output" = "kept 11 git-failed" ]
  rm -f "$STUB_CFG/status_exit"
  set_list list_json "$(wt_entry 11 completed | sed 's#"branch":"refs/heads/oratta/issue-11"#"branch":""#')"
  run dispatch reap 11
  [ "$output" = "kept 11 no-branch" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: no merged PR or a failing PR lookup keeps the child" {
  reap_ready
  : > "$STUB_CFG/pr_out"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 no-merged-pr" ]
  echo 1 > "$STUB_CFG/pr_exit"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 pr-lookup-failed" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: any of several merged PR heads may match" {
  reap_ready
  printf '%s\n' ccc333 aaa111 > "$STUB_CFG/pr_out"
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
}

@test "reap: a child with no worktree is gone, two candidates are ambiguous" {
  reap_ready
  set_list list_json
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "gone 11" ]
  [ "$(calls '^git ')" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 11 completed)"
  run dispatch reap 11
  [ "$output" = "kept 11 ambiguous" ]
}

@test "reap: a branch left behind is deleted only when its tip is the PR head" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11" ]
  [ "$(calls '^git branch -D oratta/issue-11$')" -eq 1 ]
  [ ! -e "$STUB_CFG/branch_tip" ]
  : > "$STUB_LOG"
  echo bbb222 > "$STUB_CFG/branch_tip"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11 branch-kept" ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: waits until the worktree leaves git worktree list, then deletes the branch" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  printf 'worktree %s\nHEAD aaa111\n\n' "$BATS_TEST_TMPDIR/work/issue-11" > "$STUB_CFG/wtlist_out_1"
  cp "$STUB_CFG/wtlist_out_1" "$STUB_CFG/wtlist_out_2"
  printf 'worktree /work/other\n\n' > "$STUB_CFG/wtlist_out"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11" ]
  [ "$(calls '^git worktree list --porcelain')" -eq 3 ]
  [ "$(calls '^git branch -D oratta/issue-11$')" -eq 1 ]
  [ "$(first_line '^orca worktree rm')" -lt "$(first_line '^git worktree list')" ]
  [ "$(first_line '^git worktree list')" -lt "$(first_line '^git branch -D')" ]
  [ ! -e "$STUB_CFG/branch_tip" ]
}

@test "reap: a branch tip that moved while waiting is not deleted" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  printf 'worktree %s\n\n' "$BATS_TEST_TMPDIR/work/issue-11" > "$STUB_CFG/wtlist_out_1"
  printf 'worktree /work/other\n\n' > "$STUB_CFG/wtlist_out"
  echo bbb222 > "$STUB_CFG/wttip_2"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11 branch-kept" ]
  [ "$(calls '^git branch -D')" -eq 0 ]
  [ "$(cat "$STUB_CFG/branch_tip")" = "bbb222" ]
}

@test "reap: the wait also stops by elapsed seconds when each check is slow" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  printf 'worktree %s\n\n' "$BATS_TEST_TMPDIR/work/issue-11" > "$STUB_CFG/wtlist_out"
  echo 3 > "$STUB_CFG/wtlist_sleep"
  export EPIC_DISPATCH_REAP_DETACH_TIMEOUT=2 EPIC_DISPATCH_REAP_DETACH_INTERVAL=1
  run dispatch reap 11
  [ "$output" = "reaped 11 branch-kept" ]
  [ "$(calls '^git worktree list --porcelain')" -eq 1 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: a worktree that never leaves git worktree list gives branch-kept after the limit" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  printf 'worktree %s\n\n' "$BATS_TEST_TMPDIR/work/issue-11" > "$STUB_CFG/wtlist_out"
  export EPIC_DISPATCH_REAP_DETACH_TIMEOUT=3 EPIC_DISPATCH_REAP_DETACH_INTERVAL=1
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11 branch-kept" ]
  [ "$(calls '^git worktree list --porcelain')" -ge 2 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: a failing git worktree list counts as still attached" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/wtlist_exit"
  export EPIC_DISPATCH_REAP_DETACH_TIMEOUT=2 EPIC_DISPATCH_REAP_DETACH_INTERVAL=1
  run dispatch reap 11
  [ "$output" = "reaped 11 branch-kept" ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: a tip that differs from HEAD is not waited for and not deleted" {
  reap_ready
  echo bbb222 > "$STUB_CFG/branch_tip"
  printf 'worktree %s\n\n' "$BATS_TEST_TMPDIR/work/issue-11" > "$STUB_CFG/wtlist_out"
  run dispatch reap 11
  [ "$output" = "reaped 11 branch-kept" ]
  [ "$(calls '^git worktree list')" -eq 0 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: only other paths in git worktree list (even a prefix match) do not make it wait" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  printf 'worktree %s0\n\nworktree /work/other\n\n' "$BATS_TEST_TMPDIR/work/issue-11" > "$STUB_CFG/wtlist_out"
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
  [ "$(calls '^git worktree list --porcelain')" -eq 1 ]
  [ "$(calls '^git branch -D oratta/issue-11$')" -eq 1 ]
}

@test "reap: a failing branch -D is reported as branch-kept" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/branchd_exit"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11 branch-kept" ]
}

@test "reap: no branch left means no git branch -D" {
  reap_ready
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
  [ "$(calls '^git rev-parse --verify --quiet refs/heads/oratta/issue-11$')" -eq 1 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: a merged PR under another branch name matches by HEAD through --search" {
  reap_ready
  : > "$STUB_CFG/pr_out"
  echo aaa111 > "$STUB_CFG/pr_search_out"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11" ]
  grep -qF -- 'gh pr list --state merged --search aaa111 --json headRefOid' "$STUB_LOG"
  [ "$(calls '^orca worktree rm')" -eq 1 ]
  [ "$(calls '^orca .*--force')" -eq 0 ]
}

@test "reap: a --head PR that does not match HEAD still falls through to --search" {
  reap_ready
  echo ccc333 > "$STUB_CFG/pr_out"
  echo aaa111 > "$STUB_CFG/pr_search_out"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11" ]
}

@test "reap: --search is not called when --head already matches" {
  reap_ready
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
  [ "$(calls '^gh pr list .*--search')" -eq 0 ]
}

@test "reap: --search finding nothing, another tip, or failing keeps the child" {
  reap_ready
  : > "$STUB_CFG/pr_out"
  echo ccc333 > "$STUB_CFG/pr_search_out"
  run dispatch reap 11
  [ "$output" = "kept 11 head-mismatch" ]
  : > "$STUB_CFG/pr_search_out"
  run dispatch reap 11
  [ "$output" = "kept 11 no-merged-pr" ]
  echo aaa111 > "$STUB_CFG/pr_search_out"
  echo 1 > "$STUB_CFG/pr_search_exit"
  run dispatch reap 11
  [ "$output" = "kept 11 pr-lookup-failed" ]
  echo ccc333 > "$STUB_CFG/pr_out"
  : > "$STUB_CFG/pr_search_out"
  rm -f "$STUB_CFG/pr_search_exit"
  run dispatch reap 11
  [ "$output" = "kept 11 head-mismatch" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: a terminal sweep failure in rm is told apart, never forced or retried" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/rm_exit"
  echo "Error: terminal sweep failed: connect ECONNREFUSED" > "$STUB_CFG/rm_err"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 rm-failed-terminal-sweep" ]
  grep -qF "terminal sweep failed" "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree rm')" -eq 1 ]
  [ "$(calls '^orca .*--force')" -eq 0 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: another rm failure stays rm-failed" {
  reap_ready
  echo 1 > "$STUB_CFG/rm_exit"
  echo "Error: worktree has uncommitted changes" > "$STUB_CFG/rm_err"
  run dispatch reap 11
  [ "$output" = "kept 11 rm-failed" ]
  [ "$(calls '^orca worktree rm')" -eq 1 ]
  [ "$(calls '^orca .*--force')" -eq 0 ]
}

@test "reap: a terminal close that keeps failing is retried once, then keeps the worktree and tells the owner what to do" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/close_exit"
  export EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT=0
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 close-failed" ]
  [ "$(calls '^orca terminal close')" -eq 2 ]
  [ "$(calls '^orca terminal list --worktree path:.*issue-11 --json')" -eq 1 ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
  grep -qF 'issue-11' "$BATS_TEST_TMPDIR/stderr"
  grep -qF 'epic-dispatch.sh reap 11' "$BATS_TEST_TMPDIR/stderr"
}

@test "reap: a first incomplete terminal close is retried after the wait and the child is reaped" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/close_exit_1"
  echo 0 > "$STUB_CFG/close_exit_2"
  export EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT=0
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11" ]
  [ "$(calls '^orca terminal close')" -eq 2 ]
  [ "$(calls '^orca terminal list --worktree path:.*issue-11 --json')" -eq 1 ]
  [ "$(calls '^orca worktree rm')" -eq 1 ]
}

@test "reap: the retry waits EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT seconds between the two closes" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/close_exit_1"
  export EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT=2
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
  [ "$(calls '^sleep 2$')" -eq 1 ]
  # 待ちは 1 回目の close と 2 回目の close の間に入る
  [ "$(first_line '^sleep 2$')" -gt "$(first_line '^orca terminal close')" ]
}

@test "reap: a failing worktree rm keeps the branch" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/rm_exit"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 rm-failed" ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: several children are judged one by one, duplicates once" {
  reap_ready
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 12 in-review)"
  run dispatch reap 11 12 11
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "reaped 11" ]
  [ "${lines[1]}" = "kept 12 not-done" ]
  [ "$(calls '^orca worktree rm')" -eq 1 ]
  [ "$(calls "^orca worktree rm --worktree path:$BATS_TEST_TMPDIR/work/issue-11$")" -eq 1 ]
  [ "$(calls '^orca worktree list')" -eq 1 ]
}

@test "reap: EPIC_DISPATCH_PARENT_EPIC does not change it" {
  reap_ready
  EPIC_DISPATCH_PARENT_EPIC=400 run dispatch reap 11
  [ "$output" = "reaped 11" ]
}

@test "reap: an unreadable list or current worktree removes nothing and prints nothing" {
  reap_ready
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  rm -f "$STUB_CFG/list_exit"
  echo '{"result":{}}' > "$STUB_CFG/list_json"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
  rm -f "$STUB_BIN/orca"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "reap: no children or a non-numeric child is rejected" {
  reap_ready
  run dispatch reap
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch reap '#11'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca')" -eq 0 ]
}

# --- reap: PR の無い、issue を閉じた子 ---

@test "reap: a PR-less closed child whose HEAD is in the remote's current base is reaped, judged against ls-remote" {
  reap_prless_ready
  run dispatch reap 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "reaped 11" ]
  p="$BATS_TEST_TMPDIR/work/issue-11"
  close_line="$(grep -n "^orca terminal close --worktree path:$p --all$" "$STUB_LOG" | cut -d: -f1)"
  rm_line="$(grep -n "^orca worktree rm --worktree path:$p$" "$STUB_LOG" | cut -d: -f1)"
  [ -n "$close_line" ] && [ -n "$rm_line" ] && [ "$close_line" -lt "$rm_line" ]
  [ "$(calls '^orca .*--force')" -eq 0 ]
  grep -qF -- 'gh pr list --head oratta/issue-11 --state all --json number' "$STUB_LOG"
  grep -qF -- 'git ls-remote origin refs/heads/main' "$STUB_LOG"
  grep -qF -- 'merge-base --is-ancestor aaa111 ccc3330000000000000000000000000000000000' "$STUB_LOG"
  [ "$(calls 'refs/remotes/origin')" -eq 0 ]
  [ "$(calls '^git fetch')" -eq 0 ]
}

@test "reap: a PR found by searching HEAD does not stop a PR-less child" {
  reap_prless_ready
  echo bbb222 > "$STUB_CFG/pr_search_out"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11" ]
  [ "$(calls '^orca worktree rm')" -eq 1 ]
}

@test "reap: a child that has a PR in any state keeps the old reason" {
  reap_prless_ready
  echo 77 > "$STUB_CFG/pr_all_out"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 no-merged-pr" ]
  [ "$(calls '^gh api')" -eq 0 ]
  [ "$(calls 'merge-base')" -eq 0 ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: an open issue, an unreadable issue and an unreadable PR list keep a PR-less child" {
  reap_prless_ready
  gh_seq 11 open
  run dispatch reap 11
  [ "$output" = "kept 11 no-merged-pr" ]
  rm -f "$STUB_CFG/ghcount_11"
  gh_seq 11 FAIL
  run dispatch reap 11
  [ "$output" = "kept 11 issue-lookup-failed" ]
  gh_seq 11 closed
  rm -f "$STUB_CFG/ghcount_11"
  echo 1 > "$STUB_CFG/pr_all_exit"
  run dispatch reap 11
  [ "$output" = "kept 11 pr-lookup-failed" ]
  [ "$(calls 'merge-base')" -eq 0 ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: commits not in the base and an undecidable ancestry keep the child" {
  reap_prless_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/ancestor_exit"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 unmerged-commits" ]
  echo 128 > "$STUB_CFG/ancestor_exit"
  run dispatch reap 11
  [ "$output" = "kept 11 git-failed" ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: a rewound base keeps a child whose HEAD equals the stale tracking ref" {
  reap_prless_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  printf 'ddd4440000000000000000000000000000000000\trefs/heads/main\n' > "$STUB_CFG/lsremote_out"
  echo 1 > "$STUB_CFG/ancestor_exit"
  run dispatch reap 11
  [ "$output" = "kept 11 unmerged-commits" ]
  grep -qF -- 'merge-base --is-ancestor aaa111 ddd4440000000000000000000000000000000000' "$STUB_LOG"
  [ "$(calls '^orca worktree rm')" -eq 0 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: an unreadable remote base keeps a PR-less child as base-lookup-failed" {
  p="$BATS_TEST_TMPDIR/work/issue-11"
  for c in lsremote-fail lsremote-empty fetch-fail fetch-ok; do
    rm -rf "$STUB_CFG" "$p"; mkdir -p "$STUB_CFG"; : > "$STUB_LOG"
    printf '%s\n' '/work/parent' > "$STUB_CFG/toplevel"
    reap_prless_ready
    case "$c" in
      lsremote-fail) echo 128 > "$STUB_CFG/lsremote_exit" ;;
      lsremote-empty) : > "$STUB_CFG/lsremote_out" ;;
      fetch-fail) echo 1 > "$STUB_CFG/catfile_exit"; echo 1 > "$STUB_CFG/fetch_exit" ;;
      fetch-ok) echo 1 > "$STUB_CFG/catfile_exit" ;;
    esac
    run dispatch reap 11
    [ "$status" -eq 0 ] || { echo "$c: status=$status"; false; }
    [ "$output" = "kept 11 base-lookup-failed" ] || { echo "$c: output=$output"; false; }
    [ "$(calls 'merge-base')" -eq 0 ]
    [ "$(calls '^orca worktree rm')" -eq 0 ]
  done
}

@test "reap: a base tip missing locally is fetched once, ls-remote runs once for two children" {
  reap_prless_ready
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 12 completed)"
  gh_seq 12 closed
  echo 1 > "$STUB_CFG/catfile_exit_1"
  run dispatch reap 11 12
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; false; }
  [ "$output" = "$(printf 'reaped 11\nreaped 12')" ]
  [ "$(calls '^git ls-remote')" -eq 1 ]
  [ "$(calls '^git fetch origin main')" -eq 1 ]
}

@test "reap: a second child does not fetch again when the base tip is still missing" {
  reap_prless_ready
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 12 completed)"
  gh_seq 12 closed
  echo 1 > "$STUB_CFG/catfile_exit"
  run dispatch reap 11 12
  [ "$output" = "$(printf 'kept 11 base-lookup-failed\nkept 12 base-lookup-failed')" ]
  [ "$(calls '^git ls-remote')" -eq 1 ]
  [ "$(calls '^git fetch')" -eq 1 ]
}

@test "reap: the base branch follows EPIC_DISPATCH_BASE" {
  reap_prless_ready
  EPIC_DISPATCH_BASE=develop run dispatch reap 11
  [ "$output" = "reaped 11" ]
  grep -qF -- 'git ls-remote origin refs/heads/develop' "$STUB_LOG"
}

@test "reap: a child matched by a merged PR never runs the PR-less checks" {
  reap_ready
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
  [ "$(calls '--state all')" -eq 0 ]
  [ "$(calls '^gh api')" -eq 0 ]
  [ "$(calls '^git ls-remote')" -eq 0 ]
  [ "$(calls '^git fetch')" -eq 0 ]
  [ "$(calls 'merge-base')" -eq 0 ]
}

# --- SKILL.md ---

@test "skill: epic run section names route, launch, wait and background waiting" {
  r="$(run_section)"
  [ -n "$r" ]
  printf '%s\n' "$r" | grep -qF 'epic-dispatch.sh route'
  printf '%s\n' "$r" | grep -qF 'launch'
  printf '%s\n' "$r" | grep -qF 'wait'
  printf '%s\n' "$r" | grep -qF 'run_in_background'
}

@test "skill: epic run section's launch line documents --base and EPIC_DISPATCH_BASE" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF -- 'epic-dispatch.sh launch [--note <text>] [--base <branch>] <エピック番号> <子>...'
  printf '%s\n' "$r" | grep -qF -- '起点は `origin/main`'
  printf '%s\n' "$r" | grep -qF -- '--base <既定ブランチ>'
  printf '%s\n' "$r" | grep -qF -- 'EPIC_DISPATCH_BASE'
}

@test "skill: epic run section states the routing conditions and the subagent fallback" {
  r="$(run_section)"
  p="$(printf '%s\n' "$r" | awk '/^\*\*経路の決め方\*\*/{f=1; print; next} /^$/{f=0} f')"
  [ -n "$p" ]
  if printf '%s\n' "$p" | grep -qF '件以上'; then false; fi
  nl=$'\n'
  printf '%s\n' "${p//。/$nl}" | grep -F '0 件' | grep -qF 'subagent'
  printf '%s\n' "$r" | grep -qF '`orca`'
  printf '%s\n' "$r" | grep -qF 'Orca 管理のワークツリー'
  printf '%s\n' "$r" | grep -qF 'サブエージェント方式'
}

@test "skill: route is fixed at the first start, resumed from the comment, and unmanned uses subagents" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF '途中で変えない'
  printf '%s\n' "$r" | grep -qF '回し方:'
  printf '%s\n' "$r" | grep -F 'unmanned' | grep -qF 'サブエージェント方式'
}

@test "skill: Orca route reacts to closed, timeout and error" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF 'state_reason'
  printf '%s\n' "$r" | grep -qF '子 #N マージ → 残り k 件'
  printf '%s\n' "$r" | grep -qF '見送り'
  printf '%s\n' "$r" | grep -F 'timeout' | grep -qF '再び'
  printf '%s\n' "$r" | grep -qF '子のタブ'
  printf '%s\n' "$r" | grep -qF '検知できない'
  printf '%s\n' "$r" | grep -qF 'skipped'
  printf '%s\n' "$r" | grep -qF '親ワークツリーで開き直す'
}

@test "skill: child sessions skip permissions and the parent never merges" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -F -- '--dangerously-skip-permissions' | grep -qF 'cld'
  printf '%s\n' "$r" | grep -F 'EPIC_DISPATCH_CLAUDE_CMD' | grep -qF 'cld'
  printf '%s\n' "$r" | grep -F 'EPIC_DISPATCH_CLAUDE_CMD' | grep -qF '合わせて変える'
  printf '%s\n' "$r" | grep -qF 'EPIC_DISPATCH_MODEL'
  printf '%s\n' "$r" | grep -F 'EPIC_DISPATCH_MODEL' | grep -qF 'opus'
  printf '%s\n' "$r" | grep -qF 'pr-review-gate'
  printf '%s\n' "$r" | grep -F '直接マージしない' | grep -qF 'gh pr merge'
}

@test "skill: prerequisites table has an orca row with the subagent fallback" {
  p="$(section '前提' | grep -F '**`orca`**')"
  [ -n "$p" ]
  printf '%s\n' "$p" | grep -qF 'Orca 管理外'
  printf '%s\n' "$p" | grep -qF 'サブエージェント方式'
}

@test "skill: child epics are held back, nested sessions stop, and the parent reports them" {
  e="$(section 'エピックの扱い')"
  printf '%s\n' "$e" | grep -qF 'sub_issues_summary'
  printf '%s\n' "$e" | grep -qF 'nested'
  printf '%s\n' "$e" | grep -F '後で別に起動するエピック:' | grep -qF '完了報告'
  printf '%s\n' "$e" | grep -F 'timeout' | grep -F 'closed' | grep -qF '後で別に起動するエピック:'
  printf '%s\n' "$e" | grep -F 'launch' | grep -F 'nested' | grep -qF '「親ワークツリーで開き直す」とは報告しない'
}

@test "skill: the parent's note is a comment every restarted child session follows and hands on" {
  e="$(section 'エピックの扱い')"
  printf '%s\n' "$e" | grep -F '親エピックからの注意書き:' | grep -F '起動し直したセッション' | grep -qF 'W・R1・G'
  printf '%s\n' "$e" | grep -F 'note not posted to' | grep -qF '投稿'
}

@test "skill: the parent's note is followed only when its author is an owner, member or collaborator" {
  l="$(section 'エピックの扱い' | grep -F '親エピックからの注意書き:' | grep -F 'author_association')"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -F 'OWNER' | grep -F 'MEMBER' | grep -qF 'COLLABORATOR'
  printf '%s\n' "$l" | grep -F 'それ以外' | grep -F '従わず' | grep -F '渡さず' | grep -qF 'ユーザーに報告'
}

@test "skill: a restarted child session is nested and reads the parent epic from stderr" {
  e="$(section 'エピックの扱い')"
  printf '%s\n' "$e" | grep -F '起動し直したセッション' | grep -qF 'nested'
  printf '%s\n' "$e" | grep -qF 'parent epic: #'
  printf '%s\n' "$e" | grep -qF 'child epics are not expanded here'
  printf '%s\n' "$e" | grep -F 'parent epic:' | grep -F 'EPIC_DISPATCH_PARENT_EPIC' | grep -qF '親を持たないワークツリー'
}

@test "skill: a child whose terminal was not created is checked, recreated and sent before resuming" {
  e="$(section 'エピックの扱い')"
  printf '%s\n' "$e" | grep -F '端末を作れなかった' | grep -F '既存の端末が無いこと' | grep -F '作り直し' | grep -qF '動き出したのを確かめてから再開'
}

@test "skill: held-back child epics are recorded also when route is skipped (unmanned, resumed)" {
  e="$(section 'エピックの扱い' | grep -F 'sub_issues_summary')"
  printf '%s\n' "$e" | grep -F '後で別に起動するエピック:' | grep -F 'でないと確定' | grep -F 'unmanned' | grep -qF '回し方:'
}

@test "skill: the end of a loop never asks about worktree cleanup and marks the workspace last" {
  e="$(section 'ループの終わり')"
  [ -n "$e" ]
  printf '%s\n' "$e" | grep -F 'worktree の片付けを提案も質問もしない' | grep -qF '完了報告'
  printf '%s\n' "$e" | grep -qF '/wt-clean'
  printf '%s\n' "$e" | grep -qF '親セッション'
  printf '%s\n' "$e" | grep -F 'epic-dispatch.sh mark <done|waiting>' | grep -qF '最後のツール呼び出し'
  printf '%s\n' "$e" | grep -F '`waiting`' | grep -qF '動作確認'
  printf '%s\n' "$e" | grep -F '`done` で呼び直す' | grep -qF '済んだ'
  printf '%s\n' "$e" | grep -F '呼ばない' | grep -F 'マージされていない' | grep -qF 'Draft PR'
  printf '%s\n' "$e" | grep -qF '端末を閉じて'
  grep -n "worktree" "$SKILL" | grep -qF 'worktree の片付けを提案も質問もしない'
}

@test "skill: the end of a loop tells what the parent's reap needs to clean a PR-less child" {
  e="$(section 'ループの終わり')"
  l="$(printf '%s\n' "$e" | grep -F 'epic-dispatch.sh reap')"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -F 'PR が無く' | grep -F 'issue が閉じて' | grep -qF 'リモートの今の main'
  printf '%s\n' "$l" | grep -qF 'unmerged-commits'
}

# spec: dev-workflow-develop（エピックの子の完了報告は、主がこのセッションで次にすることを 1 行目に書く）

@test "skill: an epic child's completion report starts with what the owner does next in this session" {
  e="$(section 'ループの終わり')"
  l="$(printf '%s\n' "$e" | grep -F '主がこのセッションで次にすること:')"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -F '`nested`' | grep -qF '1 行目'
  printf '%s\n' "$l" | grep -qF '`主がこのセッションで次にすること: なし`'
  printf '%s\n' "$l" | grep -qF 'どの画面で何をするか'
  printf '%s\n' "$l" | grep -F '`なし` なら `done`' | grep -qF '`waiting`'
  printf '%s\n' "$l" | grep -qF 'エピックの子でないセッション'
}

# spec: dev-workflow-develop（エピックの親が主に出す報告は、主がすることを 1 行目に書く）

@test "skill: Orca route parent reports start with what the owner does" {
  r="$(run_section)"
  l="$(printf '%s\n' "$r" | grep -F '主がすること: なし' | grep -v '^8\. ' | head -1)"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -qF '<どの画面・入力欄で> <何を打つ・押す>'
  printf '%s\n' "$l" | grep -qF 'ターンを終えるとき'
  printf '%s\n' "$l" | grep -qF '主がこのセッションで次にすること:'
  for n in 2 3 4 5 6; do
    printf '%s\n' "$r" | grep "^$n\. " | grep -qF '主がすること:'
  done
  s8="$(printf '%s\n' "$r" | grep '^8\. ')"
  printf '%s\n' "$s8" | grep -qF '主がすること:'
  printf '%s\n' "$s8" | grep -qF '親のタブ'
  printf '%s\n' "$s8" | grep -qF '別の発言を挟まず'
  printf '%s\n' "$s8" | grep -qF '1 行目は `主がすること: 子のタブで'
  printf '%s\n' "$s8" | grep -qF '`failed <N> <段>` なら主に報告する（1 行目は `主がすること:`'
  printf '%s\n' "$r" | grep -qF '手順 7 と完了条件で待ちを終えるときの報告、**マージ待ちの子** の `reply` の `failed` の報告'
  printf '%s\n' "$r" | grep '^2\. ' | grep -qF '同じターンで主の操作が要る報告（手順 4〜6・8）を出したときは、待ちに入る通知の 1 行目にもその報告の `主がすること:` を繰り返す'
}

@test "skill: Orca route watches for done marks and reaps marked children" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF -- '--watch-done'
  printf '%s\n' "$r" | grep -qF 'epic-dispatch.sh reap <N>...'
  printf '%s\n' "$r" | grep -qF '子 #N のワークツリーを残した（<理由>）'
  printf '%s\n' "$r" | grep -qF '子 #N のローカルブランチを残した'
  printf '%s\n' "$r" | grep -F 'not-done' | grep -qF '待ちを続ける'
  printf '%s\n' "$r" | grep -F '`kept <N> not-done` は待ちを続ける' | grep -qF 'wt-clean は呼ばず'
  ! printf '%s\n' "$r" | grep -qF 'オーナーの判断に残し' || return 1
  ! printf '%s\n' "$r" | grep -qF '手で消し直さない' || return 1
  l="$(printf '%s\n' "$r" | grep '^3\. ')"
  printf '%s\n' "$l" | grep -qF 'git -C <path> status --porcelain'
  printf '%s\n' "$l" | grep -qF '<path>/LLM'
  printf '%s\n' "$l" | grep -qF 'EPIC_DISPATCH_BASE'
  printf '%s\n' "$l" | grep -qF 'headRefOid'
  printf '%s\n' "$l" | grep -qF 'orca worktree rm --worktree path:<path>'
  printf '%s\n' "$l" | grep -qF '子 #N のワークツリーを確かめて消した（<理由>）'
  printf '%s\n' "$l" | grep -qF '子 #N のワークツリーを残した（<理由>） — '
  printf '%s\n' "$l" | grep -qF 'ambiguous'
  printf '%s\n' "$l" | grep -qF '主に消すかを聞かない'
  printf '%s\n' "$l" | grep -F 'close-failed' | grep -qF '子 #N のワークツリーを残した（close-failed） — <reap の stderr の owner action の行>'
  printf '%s\n' "$r" | grep '^2\. ' | grep -qF '確かめて消した子'
  printf '%s\n' "$r" | grep -F '開いている子が無くなったら' | grep -qF '待ちをやめる'
  printf '%s\n' "$r" | grep -F '再開したら' | grep -qF '`launch` の前に'
  printf '%s\n' "$r" | grep -qF 'error workspaces'
  printf '%s\n' "$r" | grep -F -- '--watch-done' | grep -qF '親ワークツリーで開き直す'
  printf '%s\n' "$r" | grep -F 'stdout に何も出さず exit 1' | grep -F -- '`--watch-done` か `--watch-stopped` を付けた `wait`' | grep -qF '親ワークツリーで開き直す'
  printf '%s\n' "$r" | grep -F 'stdout に何も出さず exit 1' | grep -F 'not in an Orca-managed worktree' | grep -qF 'stderr が `usage:` を含むときは、stderr を添えて設定の誤りとして報告して止まる'
}

@test "skill: Orca route drops reaped and gone children from the done-watch set" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -F '片付け待ちの子は' | grep -F '`reaped <N>`' | grep -F '`gone <N>`' | grep -qF '除いた'
  printf '%s\n' "$r" | grep -F '片付け待ちの子は' | grep -F 'branch-kept' | grep -qF '`launched <N>`'
  printf '%s\n' "$r" | grep -F '`reaped <N>` と `gone <N>`' | grep -qF '片付け待ちから外す'
  printf '%s\n' "$r" | grep -F '開いている子が無くなったら' | grep -F '0 件' | grep -qF '`wait` を呼ばず'
  printf '%s\n' "$r" | grep -F '開いている子が無くなったら' | grep -F '`kept <N> not-done` の子だけ' | grep -qF -- '--watch-done'
  printf '%s\n' "$r" | grep -F '再開したら' | grep -qF '片付け待ちから外す'
}

# 全 issue が閉じたあと `kept <N> not-done` を待っている間に最後の done が来ると、
# 読まれるのは手順 3（done で起こされた行）だけで、手順 4 の「0 件なら」は読まれない。
# だから 0 件で終える分岐を、手順 3 の行そのものと、再開時の手順 7 の行で確かめる。
@test "skill: Orca route ends the wait without calling wait when the last done leaves no child" {
  r="$(run_section)"
  s3="$(printf '%s\n' "$r" | grep -F '`done <N>...` で起こされたら')"
  [ "$(printf '%s\n' "$s3" | grep -c .)" -eq 1 ]
  printf '%s\n' "$s3" | grep -qF '動いている子か片付け待ちの子があれば 2 に戻る'
  printf '%s\n' "$s3" | grep -F 'どちらも 0 件なら' | grep -F '`wait` を呼ばず' | grep -qF '完了条件の確認と報告がまだなら行う'
  s7="$(printf '%s\n' "$r" | grep -F '再開したら')"
  [ "$(printf '%s\n' "$s7" | grep -c .)" -eq 1 ]
  printf '%s\n' "$s7" | grep -F 'どちらも 0 件なら' | grep -F '`wait` を呼ばず' | grep -qF '完了条件の確認と報告がまだなら行う'
}

# 手順書に書いてよい orca のコマンドは、手順 3 で親が確かめて消すときの 1 件だけ（#1095）。
# 許可した書き方を出現ごとに 1 回だけ取り除いてから orca <subcommand> を探すので、
# 同じ行に別の orca のコマンドを置いても見逃さない。許可した書き方の出現は全体で 1 回まで。
ORCA_DOC_ALLOWED='orca worktree rm --worktree path:<path>'
orca_doc_violations() {
  grep -rnE 'orca [a-z]+' "$1" | sed "s|$ORCA_DOC_ALLOWED||" | grep -E 'orca [a-z]+'
  n="$(grep -rhoF "$ORCA_DOC_ALLOWED" "$1" | grep -c .)"
  [ "$n" -le 1 ] || echo "allowed command appears $n times"
}

@test "orca_doc_violations flags another orca command on the allowed line and a second allowed command" {
  d="$BATS_TEST_TMPDIR/docs"
  mkdir -p "$d"
  printf '%s\n' "消す: \`$ORCA_DOC_ALLOWED\`" > "$d/ok.md"
  [ -z "$(orca_doc_violations "$d")" ]
  printf '%s\n' "消す: \`$ORCA_DOC_ALLOWED\` と \`orca terminal close --all\`" > "$d/ok.md"
  orca_doc_violations "$d" | grep -qF 'orca terminal close'
  printf '%s\n' "消す: \`$ORCA_DOC_ALLOWED\`" > "$d/ok.md"
  printf '%s\n' "もう一度: \`$ORCA_DOC_ALLOWED\`" > "$d/two.md"
  [ -n "$(orca_doc_violations "$d")" ]
  rm "$d/two.md"
  printf '%s\n' "\`orca worktree rm --force --worktree path:<path>\`" > "$d/force.md"
  [ -n "$(orca_doc_violations "$d")" ]
}

@test "skill: develop's docs run no orca subcommand and only epic-dispatch.sh calls orca" {
  [ -z "$(orca_doc_violations "$PLUGIN_DIR/skills/develop")" ]
  [ "$(grep -rhoF "$ORCA_DOC_ALLOWED" "$PLUGIN_DIR/skills/develop" | grep -c .)" -eq 1 ]
  run grep -rlw orca "$PLUGIN_DIR" --include='*.sh'
  [ "$status" -eq 0 ]
  [ "$output" = "$PLUGIN_DIR/scripts/epic-dispatch.sh" ]
}

# spec: dev-workflow-develop（エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する）

@test "skill: an epic child records its stop before marking it, in both waiting orders" {
  r="$(section 'エピックの子が主の返事を待って止まるとき')"
  [ -n "$r" ]
  printf '%s\n' "$r" | grep -F 'route' | grep -qF '`nested`'
  printf '%s\n' "$r" | grep -qF '`子の停止: 主の返事待ち`'
  printf '%s\n' "$r" | grep -qF 'scripts/epic-dispatch.sh mark stopped <記録先の issue 番号>'
  printf '%s\n' "$r" | grep -qF 'scripts/epic-dispatch.sh mark resumed <記録先の issue 番号>'
  printf '%s\n' "$r" | grep -F '本文で質問してターンを終えるとき' | grep -F '最後のツール呼び出し' | grep -qF '最初のツール呼び出し'
  printf '%s\n' "$r" | grep -F '質問ツール' | grep -qF '記録 → `mark stopped` → 質問ツール'
  printf '%s\n' "$r" | grep -F '回答を受けたら' | grep -qF '`mark resumed`'
  printf '%s\n' "$r" | grep -F '引き継ぎを先に投稿' | grep -qF '引き継ぎのコメントの URL'
  printf '%s\n' "$r" | grep -F '`failed`' | grep -qF '親に止まったことが伝わっていない'
}

# spec: dev-workflow-develop（エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く）

@test "skill: an epic child's stop record lists the six items in order" {
  r="$(section 'エピックの子が主の返事を待って止まるとき')"
  [ -n "$r" ]
  # 6 つの項目名が行頭の `<項目名>:` の形でこの順に出る（雛形の行で確かめる）
  prev=0
  for k in '止まった理由:' '前提:' '推奨:' '推奨の根拠:' '受け入れるリスク:' '再開に要る途中経過:'; do
    n="$(printf '%s\n' "$r" | grep -n "^${k}" | head -1 | cut -d: -f1)"
    [ -n "$n" ]
    [ "$n" -gt "$prev" ]
    prev="$n"
  done
  printf '%s\n' "$r" | grep -F '6 つの項目' | grep -qF 'どの項目も省かない'
  printf '%s\n' "$r" | grep -F '該当が無い項目' | grep -qF '`なし` と書く'
  printf '%s\n' "$r" | grep -qF '`推奨: なし（<足りない情報>）`'
  printf '%s\n' "$r" | grep -F '次の項目の行まで' | grep -qF '複数行'
  printf '%s\n' "$r" | grep -F '`再開に要る途中経過:`' | grep -qF '引き継ぎのコメントの URL'
}

@test "skill: an epic child's stop record is written for readers who have not read the child's conversation" {
  r="$(section 'エピックの子が主の返事を待って止まるとき')"
  printf '%s\n' "$r" | grep -qF '子の会話を読んでいない'
  printf '%s\n' "$r" | grep -F '「上記」' | grep -qF '「前回」'
  printf '%s\n' "$r" | grep -qF 'フル URL'
  printf '%s\n' "$r" | grep -F '専門用語' | grep -qF '言い換え'
  printf '%s\n' "$r" | grep -qF 'rules/communication-style.md'
}

@test "skill: step 8 of the Orca route reads the same item names as the stop record" {
  p="$(run_section | grep -E '^8\. ')"
  printf '%s\n' "$p" | grep -F '止まった理由' | grep -qF '推奨'
  r="$(section 'エピックの子が主の返事を待って止まるとき')"
  printf '%s\n' "$r" | grep -q '^止まった理由:'
  printf '%s\n' "$r" | grep -q '^推奨:'
}

@test "skill: Orca route waits with --watch-stopped and reports stopped children without dropping them" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -F -- '--watch-done' | grep -qF -- '--watch-stopped <動いている子>...'
  printf '%s\n' "$r" | grep -F '`stopped <N>...`' | grep -qF '1〜3 行'
  p="$(printf '%s\n' "$r" | grep -E '^8\. ')"
  printf '%s\n' "$p" | grep -qF '`stopped <N>...` で起こされたら'
  printf '%s\n' "$p" | grep -qF '`子の停止: 主の返事待ち`'
  printf '%s\n' "$p" | grep -qF '報告'
  printf '%s\n' "$p" | grep -qF '外さず'
  printf '%s\n' "$p" | grep -qF '2 に戻る'
  printf '%s\n' "$r" | grep -E '^5\. ' | grep -F '記録' | grep -F '子のタブ' | grep -qF '検知できない'
}

# spec: dev-workflow-develop（Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる）

@test "skill: Orca route resolves stopped children in wait and escalates the rest in the readable order" {
  r="$(run_section)"
  l2="$(printf '%s\n' "$r" | grep -E '^2\. ')"
  printf '%s\n' "$l2" | grep -qF -- '--resolve <エピック番号> --watch-stopped <動いている子>...'
  printf '%s\n' "$l2" | grep -F '`unrecorded <N>...`' | grep -qF '1〜4 行'
  printf '%s\n' "$l2" | grep -F '付けないときは従来どおり' | grep -qF '1〜3 行'
  printf '%s\n' "$l2" | grep -F '`unrecorded <N>...` で起こされたら' | grep -F '主に上げず' | grep -qF '投稿し直しのコマンド'
  printf '%s\n' "$l2" | grep -qF '親の判断: 子 #N 通した — 理由は記録できなかった <最新の子の停止の記録の URL>'
  printf '%s\n' "$l2" | grep -qF 'references/parent-pass-criteria.md'
  p="$(printf '%s\n' "$r" | grep -E '^8\. ')"
  printf '%s\n' "$p" | grep -F '`停止の記録:`' | grep -qF 'URL と一致する最新の `親の判断:`'
  printf '%s\n' "$p" | grep -qF '一致する `親の判断:` が無ければ、判断が無いものとして主に上げる'
  printf '%s\n' "$p" | grep -F '送信だけが失敗' | grep -qF 'reply --as parent'
  printf '%s\n' "$p" | grep -F '`親の判断: 通すが送れなかった` の件' | grep -qF 'reply --as parent'
  printf '%s\n' "$p" | grep -qF '目的 → いま取り組んでいる場所 → 起きた事実 → 決めてほしいこと 1 つ → 推奨と受け入れるリスク'
  printf '%s\n' "$p" | grep -qF 'エピックの目的と他の子との関係'
  printf '%s\n' "$p" | grep -qF '子の停止の記録の URL'
  printf '%s\n' "$p" | grep -qF 'どの子の・どの画面で・何をするか'
  printf '%s\n' "$p" | grep -F 'references/reply-after-idle.md' | grep -F 'reply --as owner' | grep -qF -- '--relaunch'
  printf '%s\n' "$p" | grep -qF 'references/parent-pass-criteria.md'
}

# spec: dev-workflow-develop（エピックの子は親から届いた返事を止まった件への返事として受け取る）

@test "skill: an epic child takes a reply from the parent as the answer to its stop" {
  r="$(section 'エピックの子が主の返事を待って止まるとき')"
  l="$(printf '%s\n' "$r" | grep -F '親から届いた返事')"
  printf '%s\n' "$l" | grep -qF '`親エピック #<E> の判断（主の承認ではない）:`'
  printf '%s\n' "$l" | grep -qF '`主の返事（親エピック #<E> 経由）:`'
  printf '%s\n' "$l" | grep -qF '`mark resumed`'
  printf '%s\n' "$l" | grep -qF '完了報告に書く'
  printf '%s\n' "$l" | grep -F '聖域' | grep -F '破壊的な操作' | grep -qF '承認として扱わない'
}

# spec: dev-workflow-develop（親が通してよい範囲の基準を 1 つのファイルに置く）

@test "criteria: the file states the nine conditions, the examples and the output form" {
  f="$PLUGIN_DIR/skills/develop/references/parent-pass-criteria.md"
  [ -f "$f" ]
  for c in '既存の規則が主に聞く止まりでない' '推奨がある' '範囲の内側' '聖域でない' '戻せる' \
    '主の側の情報が要らない' '実機操作でない' '配役表で主の観点が無い' '繰り返していない'; do
    grep -qF "| $c |" "$f" || { echo "missing condition: $c"; false; }
  done
  [ "$(grep -cE '^\| [^-|][^|]* \| .* \|$' "$f")" -eq 10 ]
  grep -F '9 つ' "$f" | grep -qF 'すべて'
  grep -F '判断できなければ' "$f" | grep -qF '主に上げる'
  grep -qF '通る例' "$f"
  grep -qF '通らない例' "$f"
  grep -F 'トークン上限の引き上げ' "$f" | grep -F 'exit 2' | grep -qF '記録が作られない'
  grep -F 'マージの可否' "$f" | grep -qF '通さない'
  grep -F '既存の規則が主に聞くと定めている止まりも' "$f" | grep -qF '通さない'
  grep -qx '判断: 通す' "$f"
  grep -qF '`判断: 主に上げる`' "$f"
  grep -qF '理由: <1 行' "$f"
  grep -qF '返事: <1 行' "$f"
  grep -qF '#1030' "$f"
  grep -F '案' "$f" | grep -qF 'PR'
}

@test "reply-after-idle: the restore table has the parent's pass decisions and the terminal check is in reply" {
  f="$PLUGIN_DIR/skills/develop/references/reply-after-idle.md"
  grep -E '^\| 親が通した判断 \|' "$f" | grep -qF '`親の判断: 子 #N 通した`'
  grep -F '子の端末の有無' "$f" | grep -qF 'epic-dispatch.sh reply'
  run grep -F 'まだエピックに記録されない' "$f"; [ "$status" -eq 1 ]
}

@test "reply-after-idle: the rule file states the thresholds and where they are set" {
  f="$PLUGIN_DIR/skills/develop/references/reply-after-idle.md"
  [ -f "$f" ]
  grep -F '120,000' "$f" | grep -qF '子'
  grep -F '100,000' "$f" | grep -qF '親'
  grep -qF 'CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=100000' "$f"
  grep -qF 'EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS' "$f"
  grep -F 'settings.json' "$f" | grep -qF '置かない'
}

@test "reply-after-idle: the rule file states when to send as is and when to relaunch" {
  f="$PLUGIN_DIR/skills/develop/references/reply-after-idle.md"
  grep -F '端末が無' "$f" | grep -qF '起動し直す'
  grep -F '60 分未満' "$f" | grep -qF 'そのまま送る'
  grep -F 'コンパクトが走' "$f" | grep -qF 'そのまま送る'
  grep -F '150,000' "$f" | grep -qF '起動し直す'
  grep -qF 'compact_boundary' "$f"
  grep -qF 'subagent-context.sh --file' "$f"
  grep -qF '#1034' "$f"
}

@test "reply-after-idle: the rule file covers the parent, its restorable state, the basis and the recount" {
  f="$PLUGIN_DIR/skills/develop/references/reply-after-idle.md"
  grep -qF '回し方:' "$f"
  grep -qF '子 #N マージ → 残り k 件' "$f"
  grep -qF '後で別に起動するエピック:' "$f"
  grep -qF '子 #N のワークツリーを残した' "$f"
  grep -qF 'https://github.com/oratta/claude-harness/issues/1039#issuecomment-6182988861' "$f"
  grep -F '1〜2 週間' "$f" | grep -qF '集計'
  grep -qF '合否に使わ' "$f"
}

@test "skill: the Orca route puts the idle compaction threshold on child sessions and points to reply-after-idle.md" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -F 'CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS' | grep -qF 'EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS'
  printf '%s\n' "$r" | grep -F 'references/reply-after-idle.md' | grep -qF '起動し直す'
}

# --- reply ---
# spec: dev-workflow-develop（epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける）

# 子 <N> のワークツリーの端末を置く（引数はハンドル。0 個なら端末なし）。Orca の実際の一覧の形に合わせ、
# <h> は Claude Code の端末（agentIdentity が claude、タイトルは Claude Code が書き換えたもの）、
# <h>:shell はシェルの端末（タイトル Terminal 1、agentIdentity なし）、
# <h>:title は agentIdentity がまだ無くタイトルが ✳ Claude Code の端末
set_terms() {
  local n="$1"; shift
  local t="" h e
  for h in "$@"; do
    case "$h" in
      *:shell) e="{\"handle\":\"${h%:shell}\",\"title\":\"Terminal 1\",\"connected\":true}" ;;
      *:title) e="{\"handle\":\"${h%:title}\",\"title\":\"✳ Claude Code\",\"connected\":true}" ;;
      *) e="{\"handle\":\"$h\",\"title\":\"◑ 子の作業\",\"connected\":true,\"agentIdentity\":\"claude\"}" ;;
    esac
    t="$t${t:+,}$e"
  done
  printf '{"ok":true,"result":{"terminals":[%s]}}\n' "$t" > "$STUB_CFG/tlist_json_$n"
}

# 子 11 のワークツリーが 1 件ある環境（端末は引数のハンドル）
reply_ready() {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 in-review)"
  set_terms 11 "$@"
}

@test "reply: one terminal gets the owner's answer with its header" {
  reply_ready term-a-11
  run dispatch reply --as owner 400 11 'A で進めて'
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
  [ "$output" = "sent 11" ]
  [ "$(cat "$STUB_CFG/sent_term-a-11")" = "主の返事（親エピック #400 経由）: A で進めて" ]
  [ "$(calls "^orca terminal list --worktree path:$BATS_TEST_TMPDIR/work/issue-11 --json\$")" -eq 1 ]
  [ "$(calls '^orca terminal send --terminal term-a-11 ')" -eq 1 ]
  [ "$(calls '^orca terminal send .*--enter --wait-submit 30 --json')" -eq 1 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
}

@test "reply: the parent's decision is headed as not the owner's approval" {
  reply_ready term-a-11
  run dispatch reply --as parent 400 11 '推奨どおり'
  [ "$status" -eq 0 ]
  [ "$output" = "sent 11" ]
  [ "$(cat "$STUB_CFG/sent_term-a-11")" = "親エピック #400 の判断（主の承認ではない）: 推奨どおり" ]
}

@test "reply: no terminal relaunches the child with the launch command and the reply after /develop" {
  reply_ready
  run dispatch reply --as parent 400 11 '推奨どおり'
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "relaunched 11" ]
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'" ]
  s="$(cat "$STUB_CFG/sent_term-11")"
  starts_with "$s" "/develop #11 "
  case "$s" in *"親エピック #400 の判断（主の承認ではない）: 推奨どおり") ;; *) echo "sent: $s"; false ;; esac
  [ "$(calls '^orca terminal wait --terminal term-11 --for tui-idle')" -eq 1 ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
}

@test "reply: the relaunch command follows EPIC_DISPATCH_CLAUDE_CMD, EPIC_DISPATCH_MODEL and the threshold" {
  reply_ready
  EPIC_DISPATCH_CLAUDE_CMD='cld-account b' EPIC_DISPATCH_MODEL=sonnet EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=150000 \
    run dispatch reply --as owner 400 11 'B で'
  [ "$status" -eq 0 ]
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=150000 cld-account b --model 'sonnet'" ]
}

@test "reply: --relaunch closes the terminals before creating one" {
  reply_ready term-a-11
  run dispatch reply --relaunch --as owner 400 11 'B で'
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "relaunched 11" ]
  [ "$(calls "^orca terminal close --worktree path:$BATS_TEST_TMPDIR/work/issue-11 --all")" -eq 1 ]
  [ "$(first_line '^orca terminal close')" -lt "$(first_line '^orca terminal create')" ]
  case "$(cat "$STUB_CFG/sent_term-11")" in *"主の返事（親エピック #400 経由）: B で") ;; *) false ;; esac
  [ ! -e "$STUB_CFG/sent_term-a-11" ]
}

@test "reply: Orca's shell terminal and the Claude Code terminal send to the Claude Code one" {
  reply_ready term-sh-11:shell term-cc-11
  run dispatch reply --as parent 400 11 '推奨どおり'
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "sent 11" ]
  [ "$(cat "$STUB_CFG/sent_term-cc-11")" = "親エピック #400 の判断（主の承認ではない）: 推奨どおり" ]
  [ ! -e "$STUB_CFG/sent_term-sh-11" ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
}

@test "reply: a single Claude Code terminal (the shape after #1055) gets the reply" {
  reply_ready term-cc-11
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 0 ]
  [ "$output" = "sent 11" ]
  [ -e "$STUB_CFG/sent_term-cc-11" ]
}

@test "reply: an agentIdentity of claude wins over a title that mentions Claude Code" {
  reply_ready term-t-11:title term-cc-11
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 0 ]
  [ "$output" = "sent 11" ]
  [ -e "$STUB_CFG/sent_term-cc-11" ]
  [ ! -e "$STUB_CFG/sent_term-t-11" ]
}

@test "reply: without agentIdentity, the terminal titled Claude Code is the child session" {
  reply_ready term-sh-11:shell term-cc-11:title
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 0 ]
  [ "$output" = "sent 11" ]
  [ -e "$STUB_CFG/sent_term-cc-11" ]
  [ ! -e "$STUB_CFG/sent_term-sh-11" ]
}

@test "reply: two Claude Code terminals or only a shell terminal send nothing and relaunch nothing" {
  reply_ready term-a-11 term-b-11
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 ambiguous-terminal" ]
  set_terms 11 term-sh-11:shell
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 ambiguous-terminal" ]
  grep -qF -- '--relaunch' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca terminal send')" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
}

@test "reply: no worktree or two worktrees send nothing; archived and other-repo worktrees do not count" {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 in-review repo-b::/x repo-b)" "$(wt_entry 11 in-review repo-a::/work/parent repo-a true)"
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 no-worktree" ]
  set_list list_json "$(wt_entry 11 in-review)" "$(wt_entry 11 completed)"
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 ambiguous-worktree" ]
  [ "$(calls '^orca terminal')" -eq 0 ]
}

@test "reply: a send that fails or starts no turn is failed with a resend hint" {
  reply_ready term-a-11
  echo 1 > "$STUB_CFG/send_exit_term-a-11"
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 send" ]
  grep -qF 'resend: orca terminal send --terminal' "$BATS_TEST_TMPDIR/stderr"
  rm -f "$STUB_CFG/send_exit_term-a-11"
  echo '{"ok":true,"result":{"stages":["input_accepted"]}}' > "$STUB_CFG/send_json_term-a-11"
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 send" ]
}

@test "reply: a failing create, close, ready wait or terminal list is failed with the stage" {
  reply_ready
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 create" ]
  grep -qF 'create: orca terminal create --worktree' "$BATS_TEST_TMPDIR/stderr"
  rm -f "$STUB_CFG/tcreate_fail_11"
  echo 1 > "$STUB_CFG/wait_exit_term-11"
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 ready" ]
  grep -qF 'resend: orca terminal send --terminal' "$BATS_TEST_TMPDIR/stderr"
  set_terms 11 term-a-11
  echo 1 > "$STUB_CFG/close_exit"
  : > "$STUB_LOG"
  run dispatch reply --relaunch --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 close" ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  echo 1 > "$STUB_CFG/tlist_exit"
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 terminal-list" ]
}

@test "reply: a terminal list without a terminals array sends and creates nothing" {
  for body in '{"ok":true,"result":{}}' '{"ok":true,"result":{"terminals":null}}' \
              '{"ok":true,"result":{"terminals":{"handle":"x"}}}' '{"ok":true,"result":{"terminals":"x"}}' '{"ok":true}'; do
    reply_ready
    printf '%s\n' "$body" > "$STUB_CFG/tlist_json_11"
    : > "$STUB_LOG"
    run dispatch reply --as owner 400 11 'A'
    [ "$status" -eq 1 ] || { echo "$body: status=$status output=$output"; false; }
    [ "$output" = "failed 11 terminal-list" ] || { echo "$body: output=$output"; false; }
    [ "$(calls '^orca terminal send')" -eq 0 ] || { echo "$body: sent"; false; }
    [ "$(calls '^orca terminal create')" -eq 0 ] || { echo "$body: created"; false; }
    [ "$(calls '^orca terminal close')" -eq 0 ] || { echo "$body: closed"; false; }
  done
}

@test "reply: wrong arguments print usage and call no orca" {
  make_stub orca
  for args in "400 11 A" "--as 400 11 A" "--as boss 400 11 A" "--as owner x 11 A" "--as owner 400 y A" \
    "--as owner 400 11" "--as owner 400 11 A B" "--bogus --as owner 400 11 A"; do
    # shellcheck disable=SC2086
    run dispatch reply $args
    [ "$status" -eq 1 ] || { echo "$args: status=$status"; false; }
    grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr" || { echo "$args: no usage"; false; }
  done
  run dispatch reply --as owner 400 11 ''
  [ "$status" -eq 1 ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "reply: an empty EPIC_DISPATCH_MODEL or a bad threshold calls no orca" {
  make_stub orca
  EPIC_DISPATCH_MODEL= run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=120k run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$(calls '^orca')" -eq 0 ]
}

# --- wait --resolve ---
# spec: dev-workflow-develop（epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける）

STOP_URL="https://github.com/o/r/issues/11#issuecomment-5"

# 判断のスタブ（judge_out_<child> か judge_out を出し、judge_exit で終わる）を EPIC_DISPATCH_JUDGE に置く
make_judge() {
  cat > "$STUB_BIN/judge" <<'EOF'
#!/bin/bash
{ printf '%s' judge; printf ' %q' "$@"; echo; } >> "$STUB_LOG"
if [ -e "$STUB_CFG/judge_out_$2" ]; then cat "$STUB_CFG/judge_out_$2"; else cat "$STUB_CFG/judge_out" 2>/dev/null; fi
exit "$(cat "$STUB_CFG/judge_exit" 2>/dev/null || echo 0)"
EOF
  chmod +x "$STUB_BIN/judge"
  export EPIC_DISPATCH_JUDGE="$STUB_BIN/judge"
}

# 判断の出力を置く（<file> <判断> <理由> <返事> [<記録>]）
judge_says() {
  local f="$1"; shift
  printf '判断: %s\n理由: %s\n返事: %s\n記録: %s\n' "$1" "$2" "$3" "${4-$STOP_URL}" > "$STUB_CFG/$f"
}

# 子 11 が止まっていて端末が 1 つある環境（2 回目のポーリングで子 11 が閉じる）
resolve_ready() {
  make_stub orca
  make_judge
  set_current 400
  gh_seq 11 open closed
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)"
  set_terms 11 term-a-11
}

@test "wait --resolve: a pass is sent to the child, recorded on the epic, and the wait goes on" {
  resolve_ready
  judge_says judge_out 通す 範囲の内側 推奨どおり進めてよい
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
  [ "$output" = "closed 11" ]
  [ "$(calls '^judge 400 11$')" -eq 1 ]
  [ "$(cat "$STUB_CFG/sent_term-a-11")" = "親エピック #400 の判断（主の承認ではない）: 推奨どおり進めてよい" ]
  [ "$(head -1 "$STUB_CFG/comment_400")" = "親の判断: 子 #11 通した — 範囲の内側 $STOP_URL" ]
  [ "$(first_line '^orca terminal send')" -lt "$(first_line '^gh issue comment 400')" ]
  [ ! -e "$STUB_CFG/comment_11" ]
}

@test "wait --resolve: a pass through a relaunch is recorded too" {
  resolve_ready
  set_terms 11
  judge_says judge_out 通す 範囲の内側 推奨どおり
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "closed 11" ]
  starts_with "$(cat "$STUB_CFG/sent_term-11")" "/develop #11 "
  [ "$(head -1 "$STUB_CFG/comment_400")" = "親の判断: 子 #11 通した — 範囲の内側 $STOP_URL" ]
}

@test "wait --resolve: a sent pass that cannot be posted on the epic wakes the parent with unrecorded" {
  resolve_ready
  judge_says judge_out 通す 範囲の内側 推奨どおり
  echo 1 > "$STUB_CFG/comment_exit_400"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "unrecorded 11" ]
  grep -F 'gh issue comment 400' "$BATS_TEST_TMPDIR/stderr" | grep -qF '親の判断: 子 #11 通した'
  [ -e "$STUB_CFG/sent_term-a-11" ]
}

@test "wait --resolve: an escalation is posted on the child with the stop record and wakes the parent" {
  resolve_ready
  judge_says judge_out 主に上げる 主の好みが要る ''
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 主に上げる" ]
  [ "$(sed -n 2p "$STUB_CFG/comment_11")" = "停止の記録: $STOP_URL" ]
  grep -qF '主の好みが要る' "$STUB_CFG/comment_11"
  [ "$(calls '^orca terminal')" -eq 0 ]
  [ ! -e "$STUB_CFG/comment_400" ]
}

@test "wait --resolve: a failing post on the child still wakes the parent with stopped" {
  resolve_ready
  judge_says judge_out 主に上げる 実機操作 ''
  echo 1 > "$STUB_CFG/comment_exit_11"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  grep -qF 'gh issue comment 11' "$BATS_TEST_TMPDIR/stderr"
}

@test "wait --resolve: a failing judge is posted as could-not-decide with an unknown record" {
  resolve_ready
  echo 1 > "$STUB_CFG/judge_exit"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 判断できなかった" ]
  [ "$(sed -n 2p "$STUB_CFG/comment_11")" = "停止の記録: 不明" ]
  [ "$(calls '^orca terminal')" -eq 0 ]
}

@test "wait --resolve: a malformed decision or an empty reply to pass is could-not-decide" {
  resolve_ready
  judge_says judge_out たぶん通す x y
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 判断できなかった" ]
  [ "$(sed -n 2p "$STUB_CFG/comment_11")" = "停止の記録: $STOP_URL" ]
  [ "$(calls '^orca terminal')" -eq 0 ]
  resolve_ready
  rm -f "$STUB_CFG/comment_11" "$STUB_CFG/ghcount_11"
  judge_says judge_out 通す x ''
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 判断できなかった" ]
  [ "$(calls '^orca terminal')" -eq 0 ]
}

@test "wait --resolve: a could-not-decide comment does not paste the judge's output" {
  resolve_ready
  printf '%s\n' '判断: たぶん通す' '理由: 配役表 local.md の中身 SECRET-1' '返事: y' "記録: $STOP_URL" 'おまけの行 SECRET-2' > "$STUB_CFG/judge_out"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 判断できなかった" ]
  run grep -F 'SECRET' "$STUB_CFG/comment_11"; [ "$status" -eq 1 ]
  run grep -F '判断の出力:' "$STUB_CFG/comment_11"; [ "$status" -eq 1 ]
  resolve_ready
  rm -f "$STUB_CFG/comment_11" "$STUB_CFG/ghcount_11"
  printf '%s\n' 'モデルの生の出力 SECRET-3' > "$STUB_CFG/judge_out"
  echo 1 > "$STUB_CFG/judge_exit"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 判断できなかった" ]
  run grep -F 'SECRET' "$STUB_CFG/comment_11"; [ "$status" -eq 1 ]
  rm -f "$STUB_CFG/judge_exit"
  resolve_ready
  rm -f "$STUB_CFG/comment_11" "$STUB_CFG/ghcount_11"
  judge_says judge_out 通す '理由の中身 SECRET-4' 推奨どおり進めてよい
  echo 1 > "$STUB_CFG/send_exit_term-a-11"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  grep -qF '送るはずだった返事: 推奨どおり進めてよい' "$STUB_CFG/comment_11"
  run grep -F 'SECRET' "$STUB_CFG/comment_11"; [ "$status" -eq 1 ]
}

@test "wait --resolve: a failing send is posted as passed-but-not-sent with the reply it meant to send, and nothing on the epic" {
  resolve_ready
  judge_says judge_out 通す 範囲の内側 推奨どおり進めてよい
  echo 1 > "$STUB_CFG/send_exit_term-a-11"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 通すが送れなかった" ]
  [ "$(sed -n 2p "$STUB_CFG/comment_11")" = "停止の記録: $STOP_URL" ]
  grep -qF '推奨どおり進めてよい' "$STUB_CFG/comment_11"
  grep -qF 'failed 11 send' "$STUB_CFG/comment_11"
  [ ! -e "$STUB_CFG/comment_400" ]
}

@test "wait --resolve: closed, done, stopped and unrecorded print in that order" {
  make_stub orca
  make_judge
  set_current 400
  gh_seq 12 closed
  gh_seq 13 open
  gh_seq 14 open
  set_list list_json "$(wt_entry 11 completed)" \
    "$(wt_entry 13 in-review repo-a::/work/parent repo-a false epic-stopped)" \
    "$(wt_entry 14 in-review repo-a::/work/parent repo-a false epic-stopped)"
  set_terms 14 term-a-14
  judge_says judge_out_13 主に上げる 実機操作 ''
  judge_says judge_out_14 通す 範囲の内側 進めて
  echo 1 > "$STUB_CFG/comment_exit_400"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 --watch-stopped --resolve 400 12 13 14
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[0]}" = "closed 12" ]
  [ "${lines[1]}" = "done 11" ]
  [ "${lines[2]}" = "stopped 13" ]
  [ "${lines[3]}" = "unrecorded 14" ]
}

@test "wait: without --resolve the judge is never called and there is no unrecorded line" {
  resolve_ready
  judge_says judge_out 通す 範囲の内側 推奨どおり
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(calls '^judge')" -eq 0 ]
  [ "$(calls '^orca terminal')" -eq 0 ]
  [ "$(calls '^gh issue comment')" -eq 0 ]
}

@test "wait: --resolve without --watch-stopped does nothing" {
  resolve_ready
  gh_seq 11 open
  judge_says judge_out 通す 範囲の内側 推奨どおり
  run dispatch wait --interval 0 --timeout 0 --resolve 400 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11" ]
  [ "$(calls '^judge')" -eq 0 ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "wait: a non-numeric or missing --resolve value prints usage and calls nothing" {
  make_stub orca
  make_judge
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve x 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11 --resolve
  [ "$status" -eq 1 ]
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve
  [ "$status" -eq 1 ]
  [ "$(calls '^orca')" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
  [ "$(calls '^judge')" -eq 0 ]
}

# spec: dev-workflow-develop（Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る）
CLOSED_STOP_URL="https://github.com/o/r/issues/11#issuecomment-7"
CLOSED_MSG_HEAD="親エピック #400 の判断（主の承認ではない）: 記録先の issue #11 は completed で閉じた。完了報告を書き、mark done で終える"

# 子 11 が completed で閉じ、ワークツリーのコメント欄が <comment>（既定 epic-stopped-seen）・
# workspaceStatus が <status>（既定 in-review）で、端末が 1 つある環境
closed_ready() {
  make_stub orca
  set_current 400
  gh_seq 11 "closed completed https://github.com/o/r/issues/11"
  gh_seq comments "$CLOSED_STOP_URL"
  set_list list_json "$(wt_entry 11 "${2-in-review}" repo-a::/work/parent repo-a false "${1-epic-stopped-seen}")"
  set_terms 11 term-a-11
}

# 子に何も送らず、どこにも投稿していない
nothing_sent() {
  [ "$(calls '^orca terminal send')" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^gh issue comment')" -eq 0 ]
}

@test "notify-closed: a child closed as completed with the stopped mark gets the reply and the epic gets the line" {
  for mark in epic-stopped-seen epic-stopped; do
    : > "$STUB_LOG"; rm -f "$STUB_CFG"/comment_* "$STUB_CFG"/sent_* "$STUB_CFG"/ghcount_* "$STUB_CFG"/listcount
    closed_ready "$mark"
    run dispatch notify-closed 400 11
    [ "$status" -eq 0 ] || { echo "mark=$mark status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
    [ "$output" = "notified 11" ]
    [ "$(cat "$STUB_CFG/sent_term-a-11")" = "${CLOSED_MSG_HEAD}（停止の記録: ${CLOSED_STOP_URL}）" ]
    [ "$(head -1 "$STUB_CFG/comment_400")" = "親の判断: 子 #11 通した — 記録先が completed で閉じたので、完了報告と mark done を促した $CLOSED_STOP_URL" ]
    [ "$(first_line '^orca terminal send')" -lt "$(first_line '^gh issue comment 400')" ]
    [ ! -e "$STUB_CFG/comment_11" ]
    [ "$(calls '^gh issue comment')" -eq 1 ]
  done
}

@test "notify-closed: the stop record is read only from trusted authors' stop comments" {
  closed_ready
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ]
  line="$(grep -F 'issues/11/comments' "$STUB_LOG")"
  case "$line" in *OWNER*MEMBER*COLLABORATOR*) ;; *) echo "$line"; false ;; esac
}

@test "notify-closed: without a stop record the child issue URL is used" {
  closed_ready
  gh_seq comments ""
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "notified 11" ]
  [ "$(cat "$STUB_CFG/sent_term-a-11")" = "${CLOSED_MSG_HEAD}（停止の記録: https://github.com/o/r/issues/11）" ]
  [ "$(head -1 "$STUB_CFG/comment_400")" = "親の判断: 子 #11 通した — 記録先が completed で閉じたので、完了報告と mark done を促した https://github.com/o/r/issues/11" ]
}

@test "notify-closed: no terminal relaunches the child, and --relaunch closes the terminals first" {
  closed_ready
  set_terms 11
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "notified 11" ]
  s="$(cat "$STUB_CFG/sent_term-11")"
  starts_with "$s" "/develop #11 "
  case "$s" in *"$CLOSED_MSG_HEAD"*) ;; *) echo "sent: $s"; false ;; esac
  [ "$(head -1 "$STUB_CFG/comment_400")" = "親の判断: 子 #11 通した — 記録先が completed で閉じたので、完了報告と mark done を促した $CLOSED_STOP_URL" ]

  : > "$STUB_LOG"; rm -f "$STUB_CFG"/comment_* "$STUB_CFG"/sent_* "$STUB_CFG"/ghcount_*
  closed_ready
  run dispatch notify-closed --relaunch 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "notified 11" ]
  [ "$(calls '^orca terminal close')" -eq 1 ]
  [ "$(first_line '^orca terminal close')" -lt "$(first_line '^orca terminal create')" ]
  starts_with "$(cat "$STUB_CFG/sent_term-11")" "/develop #11 "
}

@test "notify-closed: a child that is not stopped gets nothing" {
  for mark in "" epic-resumed; do
    : > "$STUB_LOG"; rm -f "$STUB_CFG"/ghcount_*
    closed_ready "$mark"
    run dispatch notify-closed 400 11
    [ "$status" -eq 0 ] || { echo "mark=$mark status=$status output=$output"; false; }
    [ "$output" = "skipped 11 not-stopped" ]
    nothing_sent
  done
}

@test "notify-closed: a child that already marked done gets nothing" {
  closed_ready epic-stopped-seen completed
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 already-done" ]
  nothing_sent
}

@test "notify-closed: a child closed as not planned or still open gets nothing and orca is not asked" {
  closed_ready epic-stopped
  gh_seq 11 "closed not_planned https://github.com/o/r/issues/11"
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 not-completed" ]
  nothing_sent
  [ "$(calls '^orca worktree list')" -eq 0 ]

  : > "$STUB_LOG"; rm -f "$STUB_CFG"/ghcount_*
  gh_seq 11 "open  https://github.com/o/r/issues/11"
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 not-closed" ]
  nothing_sent
}

@test "notify-closed: a child without a worktree gets nothing" {
  closed_ready
  set_list list_json "$(wt_entry 12 in-review repo-a::/work/parent repo-a false epic-stopped)" \
    "$(wt_entry 11 in-review repo-a::/work/parent repo-a true epic-stopped)" \
    "$(wt_entry 11 in-review repo-a::/work/parent repo-b false epic-stopped)"
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 no-worktree" ]
  nothing_sent
}

@test "notify-closed: two worktrees, an unreadable list or a failing gh is failed" {
  closed_ready
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)" \
    "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped)"
  run dispatch notify-closed 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 ambiguous-worktree" ]
  nothing_sent

  : > "$STUB_LOG"; rm -f "$STUB_CFG"/ghcount_*
  closed_ready
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch notify-closed 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 list" ]
  nothing_sent
  rm -f "$STUB_CFG/list_exit"

  : > "$STUB_LOG"; rm -f "$STUB_CFG"/ghcount_*
  closed_ready
  gh_seq 11 FAIL
  run dispatch notify-closed 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 issue" ]
  nothing_sent
}

@test "notify-closed: a sent reply that cannot be posted on the epic is unrecorded with the repost command" {
  closed_ready
  echo 1 > "$STUB_CFG/comment_exit_400"
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "unrecorded 11" ]
  grep -F 'gh issue comment 400' "$BATS_TEST_TMPDIR/stderr" | grep -qF '親の判断: 子 #11 通した'
}

@test "notify-closed: a failing send is failed and nothing is posted on the epic" {
  closed_ready
  echo 1 > "$STUB_CFG/send_exit_term-a-11"
  run dispatch notify-closed 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 send" ]
  [ "$(calls '^gh issue comment')" -eq 0 ]
}

@test "notify-closed: wrong arguments print usage and call neither orca nor gh" {
  make_stub orca
  for args in "400 abc" "400" "abc 11" "400 11 12" "--force 400 11" ""; do
    # shellcheck disable=SC2086
    run dispatch notify-closed $args
    [ "$status" -eq 1 ] || { echo "args=$args status=$status"; false; }
    [ -z "$output" ]
    grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
  done
  EPIC_DISPATCH_SUBMIT_WAIT=x run dispatch notify-closed 400 11
  [ "$status" -eq 1 ]
  [ "$(calls '^orca')" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "skill: Orca route step 4 nudges a stopped child closed as completed with notify-closed" {
  r="$(run_section)"
  l4="$(printf '%s\n' "$r" | grep -E '^4\. ')"
  printf '%s\n' "$l4" | grep -F '`completed`' | grep -qF 'scripts/epic-dispatch.sh notify-closed'
  printf '%s\n' "$l4" | grep -F 'references/reply-after-idle.md' | grep -qF -- '--relaunch'
  printf '%s\n' "$l4" | grep -F '`unrecorded <N>`' | grep -qF '投稿し直しのコマンド'
  printf '%s\n' "$l4" | grep -F '`failed <N> <段>`' | grep -qF '主に報告'
  printf '%s\n' "$l4" | grep -qF '`completed` 以外の子には `notify-closed` を呼ばない'
  printf '%s\n' "$r" | grep -F '主がすること: なし' | grep -qF '`notify-closed` の `failed` の報告'
}

@test "skill: Orca route step 4 calls notify-closed before launching the unblocked children" {
  # 後続の子の launch が failed を返すと親は手順 6 で止まり、再開の手順 7 も notify-closed を呼ばない。
  # launch より後ろに書くと閉じた子に送られないまま残るので、手順 4 の中で launch より先に現れること
  r="$(run_section)"
  l4="$(printf '%s\n' "$r" | grep -E '^4\. ')"
  [ -n "$l4" ]
  n="$(printf '%s' "$l4" | awk '{ print index($0, "scripts/epic-dispatch.sh notify-closed") }')"
  l="$(printf '%s' "$l4" | awk '{ print index($0, "解けた子を件数にかかわらず `launch`") }')"
  [ "$n" -gt 0 ]
  [ "$l" -gt 0 ]
  [ "$n" -lt "$l" ]
  printf '%s\n' "$l4" | grep -qF '`launch` が `failed` を返しても'
}
