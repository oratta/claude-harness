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
#   git : toplevel（rev-parse --show-toplevel の出力）/ origin_url・origin_exit（remote get-url origin。
#         既定は git@github.com:oratta/claude-harness.git・0）/ fetch_exit / status_exit / status_out
#         （-C <パス> status --porcelain）/ head（-C <パス> rev-parse HEAD。既定 aaa111）/ branch_tip
#         （rev-parse --verify --quiet refs/heads/<b> の出力。無ければ exit 1）/ branchd_exit（branch -D）
#         / wtlist_out・wtlist_out_<回数>・wtlist_exit（worktree list --porcelain。既定は空・0。回数は wtcount）
#           wtlist_sleep（1 回の worktree list にかかる実時間の秒数）/ wttip_<回数>（その回の呼び出しで branch_tip をこの内容にする）
#           branch -D が成功すると branch_tip を消す（ブランチが消えたことの表現）
#   sysctl: -n hw.memsize は memsize の内容を出して sysctl_exit（既定 0）で終わる。memsize が無ければ exit 1
#   gh  : issue comment <N> --body <本文> は本文を comment_<N> に追記し（1 件ごとに "---" の行で区切る）、
#         comment_exit_<N>（無ければ comment_exit）で終わる（既定 0）。成功（exit 0）のときは実物の gh と同じに投稿先の URL を stdout に出す。pr list は pr_out を出して pr_exit で終わる（--search 付きは pr_search_out と pr_search_exit。既定は空・0）。それ以外は gh_<N> に 1 呼び出し 1 行の返り値（open / closed / FAIL / 空行）。最後の行を繰り返す。
#         呼び出し回数は ghcount_<N>。hook_<N>_<回数> があればその回の呼び出しで bash で走らせる（on_poll）。FAIL は stderr に "gh: mock failure for issue <N> (poll <count>)" も出す
# スクリプトは PATH="<スタブ置き場>:/usr/bin:/bin" で走らせる（jq は実物）。
# テストの途中に素の [[ ]] を置かない（bash 3.2 では偽でも素通りする）。
#
# spec: dev-workflow-develop（epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/epic-dispatch.sh"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  # エピックの 2 節は SKILL.md から references/ へ移した（#1219）
  EPIC="${PLUGIN_DIR}/skills/develop/references/epic.md"
  EPIC_CHILD_STOP="${PLUGIN_DIR}/skills/develop/references/epic-child-stop.md"
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
  make_stub sysctl
  # 外の環境（並列起動された子のセッション）の値をテストに漏らさない
  unset EPIC_DISPATCH_PARENT_EPIC EPIC_STATE_LOCK_TIMEOUT EPIC_DISPATCH_LAUNCHER TMUX
  # 既存の launch のテストが上限に当たらないよう大きくする（上限のテストだけで上書き・unset する）。
  # 物理メモリは sysctl のスタブ（memsize / sysctl_exit）だけから読ませ、実物の /proc/meminfo を読ませない
  export EPIC_DISPATCH_MAX_PARALLEL=99
  export EPIC_DISPATCH_MEMINFO_FILE="${BATS_TEST_TMPDIR}/no-meminfo"
  # 状態の記録は実在のホームの下に書かない
  export EPIC_STATE_ROOT="${BATS_TEST_TMPDIR}/state"
}

# 状態の記録を置く（<子の番号> [項目=値...]）。既定はエピック oratta/claude-harness#1122 の同じリポジトリの子で、
# 親は /work/parent、worktree は実在の $BATS_TEST_TMPDIR/work/issue-<N>、status は running、stop は空。
# epic= や child= を変えるとファイルの置き場もそれに合わせる。値が数のときは number=・schema= だけ数として書く
put_record() {
  local n="$1" j kv f
  shift
  mkdir -p "$BATS_TEST_TMPDIR/work/issue-$n"
  j="$(jq -cn --argjson n "$n" --arg w "$BATS_TEST_TMPDIR/work/issue-$n" '{schema: 1, epic: "oratta/claude-harness#1122",
    child: "oratta/claude-harness#\($n)", repo: "oratta/claude-harness", number: $n, launcher: "orca",
    parent_worktree: "/work/parent", worktree: $w, branch: "oratta/issue-\($n)", base: "main", session: "",
    launch_failed: "", status: "running", stop: "", created_at: "2026-01-01T00:00:00Z", updated_at: "2026-01-01T00:00:00Z"}')"
  for kv in "$@"; do
    j="$(printf '%s' "$j" | jq -c --arg k "${kv%%=*}" --arg v "${kv#*=}" \
      '.[$k] = (if $k == "number" or $k == "schema" then ($v | tonumber) else $v end)')"
  done
  f="$(rec_of "$(printf '%s' "$j" | jq -r .epic)" "$(printf '%s' "$j" | jq -r .child)")"
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "$j" > "$f"
}

# 記録のパス（<エピック o/r#E> <子 o/r#N>。既定はエピック oratta/claude-harness#1122 の子 <N> を番号だけで渡す形も可）
rec_of() {
  local e="$1" c="$2"
  case "$c" in *"#"*) ;; *) c="oratta/claude-harness#$c" ;; esac
  case "$e" in *"#"*) ;; *) e="oratta/claude-harness#$e" ;; esac
  printf '%s/%s-%s/%s-%s.json' "$EPIC_STATE_ROOT" "$(printf '%s' "${e%%#*}" | sed 's#/#.#')" "${e##*#}" \
    "$(printf '%s' "${c%%#*}" | sed 's#/#.#')" "${c##*#}"
}

# 子 <N>（エピック 1122）の記録の項目を読む
rec_get() { jq -r ".$2" "$(rec_of 1122 "$1")"; }

# 子 <N> の gh の <回数> 回目の呼び出しのときに、子 <N> の記録の項目を書き換える（<N> <回数> <項目>=<値>）。
# ポーリングの途中で子が印を付けたことの表現
on_poll() {
  local f; f="$(rec_of 1122 "$1")"
  printf 'jq -c --arg v %q %q %q > %q.tmp && mv %q.tmp %q\n' "${3#*=}" ".${3%%=*} = \$v" "$f" "$f" "$f" "$f" \
    > "$STUB_CFG/hook_$1_$2"
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
  "repo list")
    rc=$(cat "$STUB_CFG/repo_list_exit" 2>/dev/null || echo 0)
    if [ "$rc" -eq 0 ]; then
      if [ -e "$STUB_CFG/repo_list_json" ]; then cat "$STUB_CFG/repo_list_json"; else echo "{\"result\":{\"repos\":[]}}"; fi
    fi
    exit "$rc" ;;
  "worktree rm")
    cat "$STUB_CFG/rm_out" 2>/dev/null
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
  cpath="$2"
  shift 2
  case "$1 ${2-}" in
    "remote get-url")
      of="$STUB_CFG/origin_for_$(printf "%s" "$cpath" | tr / _)"
      [ -e "$of" ] || exit 1
      cat "$of"; exit 0 ;;
    "fetch origin") exit "$(cat "$STUB_CFG/cfetch_exit" 2>/dev/null || echo 0)" ;;
    "status --porcelain")
      cat "$STUB_CFG/status_out" 2>/dev/null
      exit "$(cat "$STUB_CFG/status_exit" 2>/dev/null || echo 0)" ;;
    "rev-parse HEAD") cat "$STUB_CFG/head" 2>/dev/null || echo aaa111; exit 0 ;;
    "merge-base --is-ancestor") exit "$(cat "$STUB_CFG/ancestor_exit" 2>/dev/null || echo 0)" ;;
    "rev-parse --path-format=absolute")
      if [ -e "$STUB_CFG/commondir_out" ]; then cat "$STUB_CFG/commondir_out"; else echo /stub/common/.git; fi
      exit "$(cat "$STUB_CFG/commondir_exit" 2>/dev/null || echo 0)" ;;
    "show-ref --verify") exit "$(cat "$STUB_CFG/show_ref_exit" 2>/dev/null || echo 1)" ;;
    "ls-remote origin"|"cat-file -e"|"worktree list"|"rev-parse --verify"|"branch -D") ;;
    *) exit 0 ;;
  esac
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
if [ "$1 ${2-} ${3-}" = "remote get-url origin" ]; then
  [ -e "$STUB_CFG/origin_exit" ] && exit "$(cat "$STUB_CFG/origin_exit")"
  if [ -e "$STUB_CFG/origin_url" ]; then cat "$STUB_CFG/origin_url"; else echo git@github.com:oratta/claude-harness.git; fi
  exit 0
fi
case "$1" in
  rev-parse) cat "$STUB_CFG/toplevel"; exit 0 ;;
  fetch) exit "$(cat "$STUB_CFG/fetch_exit" 2>/dev/null || echo 0)" ;;
esac
exit 0' ;;
    gh) body='
if [ "$1 $2" = "api user" ]; then echo "stub-user"; exit 0; fi
case "$1 $2" in
  "api repos/"*/*)
    case "${2#repos/}" in
      */*/*) ;;
      *)
        rf="$STUB_CFG/repoinfo_$(printf "%s" "${2#repos/}" | tr / _)"
        rc=$(cat "$STUB_CFG/repoinfo_exit" 2>/dev/null || echo 0)
        if [ "$rc" -eq 0 ]; then
          if [ -e "$rf" ]; then cat "$rf"; else echo "{\"permissions\":{\"push\":true},\"default_branch\":\"main\"}"; fi
        fi
        exit "$rc" ;;
    esac ;;
esac
if [ "$1 $2" = "issue comment" ]; then
  cbody=""; prev=""
  for a in "$@"; do [ "$prev" = "--body" ] && cbody="$a"; prev="$a"; done
  printf "%s\n---\n" "$cbody" >> "$STUB_CFG/comment_$3"
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
[ -e "$STUB_CFG/hook_${n}_$count" ] && bash "$STUB_CFG/hook_${n}_$count"
total=$(wc -l < "$STUB_CFG/gh_$n" | tr -d " ")
idx="$count"
[ "$idx" -gt "$total" ] && idx="$total"
val=$(sed -n "${idx}p" "$STUB_CFG/gh_$n")
[ "$val" = "FAIL" ] && { echo "gh: mock failure for issue $n (poll $count)" >&2; exit 1; }
echo "$val"
exit 0' ;;
    tmux) body='
case "$1" in
  new-window)
    cat "$STUB_CFG/new_window_out" 2>/dev/null || echo %5
    exit "$(cat "$STUB_CFG/new_window_exit" 2>/dev/null || echo 0)" ;;
  send-keys)
    # -l で打った文を、子の会話ログ（tmux_log_file）に user の行として残す（送信の確かめ）
    if [ "$4" = -l ] && [ -e "$STUB_CFG/tmux_log_file" ]; then
      jq -cn --arg c "$6" "{type: \"user\", timestamp: \"2999-01-01T00:00:00\", message: {role: \"user\", content: \$c}}" >> "$(cat "$STUB_CFG/tmux_log_file")"
    fi
    exit 0 ;;
  capture-pane) echo "  ? for shortcuts" ;;
  display-message) echo node ;;
  list-panes) cat "$STUB_CFG/panes" 2>/dev/null ;;
  kill-pane) : > "$STUB_CFG/panes" ;;
esac
exit 0' ;;
    sleep) body='exit 0' ;;
    sysctl) body='
[ "$*" = "-n hw.memsize" ] || exit 1
[ -e "$STUB_CFG/memsize" ] || { echo "sysctl: unknown oid" >&2; exit 1; }
cat "$STUB_CFG/memsize"
exit "$(cat "$STUB_CFG/sysctl_exit" 2>/dev/null || echo 0)"' ;;
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
  put_record 11 status=done
  echo aaa111 > "$STUB_CFG/pr_out"
}

# PR の無い子 11 の環境（reap_ready から merged PR を消し、issue 11 を closed にする）
reap_prless_ready() {
  reap_ready
  : > "$STUB_CFG/pr_out"
  gh_seq 11 closed
}

# SKILL.md の「## <見出し>」から次の「## 」まで
# 第 2 引数で読むファイルを変えられる（既定は SKILL.md）
section() { awk -v h="## $1" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "${2:-$SKILL}"; }
# 「エピックの扱い」の「### 回し方」から次の「### 」まで
run_section() { section 'エピックの扱い' "$EPIC" | awk '/^### 回し方/{f=1; print; next} /^### /{f=0} f'; }

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

# spec: dev-workflow-epic-state（子の側は今いるワークツリーのパスで自分の記録を探す）

@test "route: a worktree with a state record goes to nested without the variable or the Orca list" {
  make_stub orca
  put_record 460
  echo "$BATS_TEST_TMPDIR/work/issue-460" > "$STUB_CFG/toplevel"
  run dispatch route 5
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  grep -qxF 'parent epic: #1122' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree list')" -eq 0 ]
  run dispatch route
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
}

@test "route: a record whose epic is in another repository prints the epic with its repository" {
  make_stub orca
  put_record 460 epic=genetta-inc/flatmate#1500
  echo "$BATS_TEST_TMPDIR/work/issue-460" > "$STUB_CFG/toplevel"
  run dispatch route 5
  [ "$output" = "nested" ]
  grep -qxF 'parent epic: genetta-inc/flatmate#1500' "$BATS_TEST_TMPDIR/stderr"
}

@test "route: Orca's parentWorktreeId alone does not make a child" {
  make_stub orca
  set_child_of 420
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree list')" -eq 0 ]
}

@test "route: an unreadable record is not a candidate and the route is as before" {
  make_stub orca
  put_record 460
  echo '{' > "$(rec_of 1122 460)"
  echo "$BATS_TEST_TMPDIR/work/issue-460" > "$STUB_CFG/toplevel"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  grep -qF "$(rec_of 1122 460)" "$BATS_TEST_TMPDIR/stderr"
}

@test "route: without jq the record is not read and the route is as before" {
  make_stub orca
  put_record 460
  echo "$BATS_TEST_TMPDIR/work/issue-460" > "$STUB_CFG/toplevel"
  run dispatch_nojq route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
}

@test "route: a record of another worktree does not make this one a child" {
  make_stub orca
  put_record 460
  run dispatch route 11 12
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree current')" -eq 1 ]
}

# --- launch ---

@test "launch: call order is current, toplevel, origin, fetch, set, list, then create, terminal create, wait and send per child" {
  make_stub orca
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
  log=()
  while IFS= read -r l; do log+=("$l"); done < "$STUB_LOG"
  [ "${#log[@]}" -eq 16 ]
  [ "${log[0]}" = "orca worktree current --json" ]
  [ "${log[1]}" = "git rev-parse --show-toplevel" ]
  [ "${log[2]}" = "git remote get-url origin" ]
  [ "${log[3]}" = "git fetch origin main" ]
  [ "${log[4]}" = "orca worktree set --worktree path:/work/parent --issue 400" ]
  [ "${log[5]}" = "orca worktree list --json" ]
  [ "${log[6]}" = "orca worktree create --name issue-11 --issue 11 --base-branch origin/main --parent-worktree path:/work/parent --json" ]
  [ "${log[7]}" = "orca terminal list --worktree path:/work/issue-11 --json" ]
  starts_with "${log[8]}" "orca terminal create --worktree path:/work/issue-11 --command "
  case "${log[8]}" in *' --json') ;; *) echo "terminal create must end with --json" >&2; false ;; esac
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'" ]
  [ "${log[9]}" = "orca terminal wait --terminal term-11 --for tui-idle --timeout-ms 60000 --json" ]
  starts_with "${log[10]}" "orca terminal send --terminal term-11 --text "
  case "${log[10]}" in *' --enter --wait-submit 30 --json') ;; *) echo "send must end with --enter --wait-submit 30 --json" >&2; false ;; esac
  [ "${log[11]}" = "orca worktree create --name issue-12 --issue 12 --base-branch origin/main --parent-worktree path:/work/parent --json" ]
  [ "${log[12]}" = "orca terminal list --worktree path:/work/issue-12 --json" ]
  starts_with "${log[13]}" "orca terminal create --worktree path:/work/issue-12 --command "
  [ "${log[14]}" = "orca terminal wait --terminal term-12 --for tui-idle --timeout-ms 60000 --json" ]
  starts_with "${log[15]}" "orca terminal send --terminal term-12 --text "
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

@test "launch: a session whose worktree has a state record creates nothing, before origin, fetch and set" {
  make_stub orca
  put_record 460 epic=oratta/claude-harness#420 worktree=/work/parent parent_worktree=/work/root
  run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^git ')" -eq 1 ]
  [ "$(calls '^git remote')" -eq 0 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  grep -F '420' "$BATS_TEST_TMPDIR/stderr" | grep -qF 'child epics are not expanded here'
  [ ! -e "$(rec_of 460 11)" ]
}

@test "launch: Orca's parent worktree alone does not make the session a child" {
  make_stub orca
  set_child_of 420
  run dispatch launch 460 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "launched 11" ]
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
  [ ! -e "$(rec_of 400 11)" ]
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

# --- max-parallel と launch の上限 ---
# spec: dev-workflow-develop（epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める /
# epic-dispatch.sh launch は空いた枠の分だけ子を起動し、残りを deferred で出す）

@test "max-parallel: without the variable 16 GiB of memory gives 4 and calls neither orca, gh nor git" {
  make_stub orca
  unset EPIC_DISPATCH_MAX_PARALLEL
  echo 17179869184 > "$STUB_CFG/memsize"
  run dispatch max-parallel
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]
  [ "$(calls '^orca')" -eq 0 ]
  [ "$(calls '^gh')" -eq 0 ]
  [ "$(calls '^git')" -eq 0 ]
}

@test "max-parallel: 2 GiB of memory still gives 1" {
  unset EPIC_DISPATCH_MAX_PARALLEL
  echo 2147483648 > "$STUB_CFG/memsize"
  run dispatch max-parallel
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "max-parallel: unreadable memory gives 2 and says so on stderr" {
  unset EPIC_DISPATCH_MAX_PARALLEL
  run dispatch max-parallel
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
  grep -q 'physical memory' "$BATS_TEST_TMPDIR/stderr"
}

@test "max-parallel: a non-numeric sysctl output falls back to MemTotal in the meminfo file" {
  unset EPIC_DISPATCH_MAX_PARALLEL
  echo garbage > "$STUB_CFG/memsize"
  printf 'MemTotal:       33554432 kB\nMemFree:  1 kB\n' > "$BATS_TEST_TMPDIR/meminfo"
  EPIC_DISPATCH_MEMINFO_FILE="$BATS_TEST_TMPDIR/meminfo" run dispatch max-parallel
  [ "$status" -eq 0 ]
  [ "$output" = "8" ]
}

@test "max-parallel: a sysctl that prints a number but exits non-zero falls back to MemTotal" {
  unset EPIC_DISPATCH_MAX_PARALLEL
  echo 17179869184 > "$STUB_CFG/memsize"
  echo 1 > "$STUB_CFG/sysctl_exit"
  printf 'MemTotal:       33554432 kB\n' > "$BATS_TEST_TMPDIR/meminfo"
  EPIC_DISPATCH_MEMINFO_FILE="$BATS_TEST_TMPDIR/meminfo" run dispatch max-parallel
  [ "$status" -eq 0 ]
  [ "$output" = "8" ]
}

@test "max-parallel: EPIC_DISPATCH_MAX_PARALLEL wins over the memory" {
  echo 17179869184 > "$STUB_CFG/memsize"
  EPIC_DISPATCH_MAX_PARALLEL=3 run dispatch max-parallel
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "max-parallel: 0, two or an empty EPIC_DISPATCH_MAX_PARALLEL prints the usage and exits 1" {
  local v
  for v in 0 two ''; do
    EPIC_DISPATCH_MAX_PARALLEL="$v" run dispatch max-parallel
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    grep -q 'EPIC_DISPATCH_MAX_PARALLEL' "$BATS_TEST_TMPDIR/stderr"
    grep -q 'usage:' "$BATS_TEST_TMPDIR/stderr"
  done
}

@test "launch: with max 2 and five startable children, two are launched and three deferred" {
  make_stub orca
  set_current 400
  EPIC_DISPATCH_MAX_PARALLEL=2 run dispatch launch 400 11 12 13 14 15
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'launched 11\nlaunched 12\ndeferred 13\ndeferred 14\ndeferred 15')" ]
  [ "$(calls '^orca worktree create')" -eq 2 ]
  [ "$(calls '^orca worktree create .*--issue 1[345] ')" -eq 0 ]
  grep -q 'max parallel 2 (EPIC_DISPATCH_MAX_PARALLEL); in use 0' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: one running child closing frees one slot for a deferred child" {
  make_stub orca
  set_current 400
  put_record 11
  put_record 12
  gh_seq 11 closed
  gh_seq 12 open
  EPIC_DISPATCH_MAX_PARALLEL=2 run dispatch launch 1122 12 13 14 15
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'skipped 12\nlaunched 13\ndeferred 14\ndeferred 15')" ]
  [ "$(calls '^orca worktree create')" -eq 1 ]
  [ "$(calls '^orca worktree create .*--issue 13 ')" -eq 1 ]
  grep -q 'in use 1: #12' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: children with the done mark or the stopped mark do not use a slot" {
  make_stub orca
  set_current 400
  put_record 11 status=done
  put_record 12 stop=stopped-seen
  put_record 16 stop=stopped
  gh_seq 11 open
  gh_seq 12 open
  gh_seq 16 open
  EPIC_DISPATCH_MAX_PARALLEL=2 run dispatch launch 400 13 14 15
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'launched 13\nlaunched 14\ndeferred 15')" ]
}

@test "launch: a resumed child uses a slot" {
  make_stub orca
  set_current 400
  put_record 11 stop=resumed
  gh_seq 11 open
  EPIC_DISPATCH_MAX_PARALLEL=2 run dispatch launch 400 13 14
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'launched 13\ndeferred 14')" ]
}

@test "launch: a child whose issue state cannot be read is counted as using a slot" {
  make_stub orca
  set_current 400
  put_record 11
  gh_seq 11 FAIL
  EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch 400 13
  [ "$status" -eq 0 ]
  [ "$output" = "deferred 13" ]
  grep -q '#11' "$BATS_TEST_TMPDIR/stderr"
  grep -q 'could not read the state of #11' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: records of another parent worktree are not counted, records of another epic under this parent are" {
  make_stub orca
  set_current 400
  put_record 11 parent_worktree=/work/other
  gh_seq 11 open
  EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch 400 13
  [ "$status" -eq 0 ]
  [ "$output" = "launched 13" ]
  # 1 回目で作った子 13 の記録（エピック 400）と、同じ親のエピック 900 の子 12 の記録を数える。
  # 別の親の子 11 は数えない。並びは置き場のディレクトリの順（-400 → -900）
  [ -f "$(rec_of 400 13)" ]
  put_record 12 epic=oratta/claude-harness#900
  gh_seq 12 open
  gh_seq 13 open
  EPIC_DISPATCH_MAX_PARALLEL=2 run dispatch launch 400 14 15
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'deferred 14\ndeferred 15')" ]
  grep -q 'in use 2: #13 #12$' "$BATS_TEST_TMPDIR/stderr" || { cat "$BATS_TEST_TMPDIR/stderr"; false; }
}

@test "launch: an unreadable record of another child uses one slot" {
  make_stub orca
  set_current 400
  put_record 11
  printf '{\n' >| "$(rec_of 1122 11)"
  EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch 400 13
  [ "$status" -eq 0 ]
  [ "$output" = "deferred 13" ]
  grep -q 'in use 1: ' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: the in-use count follows the records (running counts, done and stopped-seen do not)" {
  make_stub orca
  set_current 400
  put_record 11
  put_record 12 status=done
  put_record 16 stop=stopped-seen
  gh_seq 11 open
  EPIC_DISPATCH_MAX_PARALLEL=2 run dispatch launch 1122 21 22
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'launched 21\ndeferred 22')" ]
  grep -q 'in use 1: #11$' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: more children in use than the max defers everything without create" {
  make_stub orca
  set_current 400
  put_record 11
  put_record 12
  put_record 13
  gh_seq 11 open
  gh_seq 12 open
  gh_seq 13 open
  EPIC_DISPATCH_MAX_PARALLEL=2 run dispatch launch 400 14 15
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'deferred 14\ndeferred 15')" ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
}

@test "launch: a failed child also uses a free slot" {
  make_stub orca
  set_current 400
  touch "$STUB_CFG/create_fail_11"
  EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$output" = "$(printf 'failed 11\ndeferred 12')" ]
}

@test "launch: a deferred child gets no note" {
  make_stub orca
  set_current 400
  EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch --note 注意 400 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'launched 11\ndeferred 12')" ]
  [ -e "$STUB_CFG/comment_11" ]
  [ ! -e "$STUB_CFG/comment_12" ]
}

@test "launch: a wrong EPIC_DISPATCH_MAX_PARALLEL calls neither orca nor git" {
  make_stub orca
  EPIC_DISPATCH_MAX_PARALLEL=abc run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca')" -eq 0 ]
  [ "$(calls '^git')" -eq 0 ]
  grep -q 'EPIC_DISPATCH_MAX_PARALLEL' "$BATS_TEST_TMPDIR/stderr"
  grep -q 'usage:' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: an Orca worktree without a record does not use a slot" {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 '' 'repo-a::/work/parent')"
  gh_seq 11 open
  EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch 400 13
  [ "$status" -eq 0 ]
  [ "$output" = "launched 13" ]
  grep -q 'in use 0' "$BATS_TEST_TMPDIR/stderr"
}

# --- launch: 状態の記録 ---
# spec: dev-workflow-epic-state（記録の置き場・項目・launch は子のワークツリーを作る前に記録を書く・別のリポジトリの子は作らない）

@test "launch: the record is written under EPIC_STATE_ROOT with the fixed fields, nothing under ~/.claude/projects" {
  make_stub orca
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  printf '%s\n' '{"result":{"worktree":{"path":"/work/issue-1123","branch":"refs/heads/oratta/issue-1123"}}}' > "$STUB_CFG/create_json_1123"
  run dispatch launch 1122 1123
  [ "$status" -eq 0 ]
  [ "$output" = "launched 1123" ]
  f="$EPIC_STATE_ROOT/oratta.claude-harness-1122/oratta.claude-harness-1123.json"
  [ -f "$f" ]
  [ ! -e "$HOME/.claude/projects" ]
  [ "$(jq -c '{schema, epic, child, repo, number, launcher, parent_worktree, worktree, branch, base, session, launch_failed, status, stop}' "$f")" = \
    '{"schema":1,"epic":"oratta/claude-harness#1122","child":"oratta/claude-harness#1123","repo":"oratta/claude-harness","number":1123,"launcher":"orca","parent_worktree":"/work/parent","worktree":"/work/issue-1123","branch":"oratta/issue-1123","base":"main","session":"term-1123","launch_failed":"","status":"running","stop":""}' ]
  jq -e '(.created_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")) and (.updated_at | test("Z$"))' "$f" >/dev/null
  # 一時ファイルもロックも残らない
  [ "$(find "$EPIC_STATE_ROOT" -mindepth 2 | wc -l | tr -d ' ')" -eq 1 ]
}

@test "launch: without EPIC_STATE_ROOT the record goes under HOME/.claude/epic-state, not projects" {
  make_stub orca
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset EPIC_STATE_ROOT
  run dispatch launch 1122 1123
  [ "$output" = "launched 1123" ]
  [ -f "$HOME/.claude/epic-state/oratta.claude-harness-1122/oratta.claude-harness-1123.json" ]
  [ ! -e "$HOME/.claude/projects" ]
}

@test "launch: the three origin forms and upper case owners give the same record path" {
  make_stub orca
  for url in ssh://git@github.com/Oratta/claude-harness git@github.com:oratta/claude-harness https://github.com/oratta/claude-harness.git/; do
    rm -rf "$EPIC_STATE_ROOT"
    printf '%s\n' "$url" > "$STUB_CFG/origin_url"
    run dispatch launch 1122 1123
    [ "$status" -eq 0 ] || { echo "$url" >&2; false; }
    [ -f "$EPIC_STATE_ROOT/oratta.claude-harness-1122/oratta.claude-harness-1123.json" ] || { echo "$url" >&2; false; }
    [ "$(jq -r .epic "$EPIC_STATE_ROOT/oratta.claude-harness-1122/oratta.claude-harness-1123.json")" = "oratta/claude-harness#1122" ]
  done
}

@test "launch: without origin no record and no worktree are made, exit 1" {
  make_stub orca
  echo 2 > "$STUB_CFG/origin_exit"
  run dispatch launch 1122 1123
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ ! -e "$EPIC_STATE_ROOT/oratta.claude-harness-1122" ]
  grep -q 'cannot read the epic repository from origin: no origin' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: a gitlab origin makes nothing and names the URL on stderr" {
  make_stub orca
  echo git@gitlab.com:oratta/claude-harness.git > "$STUB_CFG/origin_url"
  run dispatch launch 1122 1123
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  [ ! -e "$EPIC_STATE_ROOT" ] || [ -z "$(find "$EPIC_STATE_ROOT" -type f)" ]
  grep -q 'cannot read the epic repository from origin: git@gitlab.com:oratta/claude-harness.git' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: a failing worktree create leaves no record" {
  make_stub orca
  touch "$STUB_CFG/create_fail_11"
  run dispatch launch 1122 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ ! -e "$(rec_of 1122 11)" ]
}

@test "launch: create without a path keeps the record with launch_failed create" {
  make_stub orca
  printf '%s\n' '{"result":{"worktree":{}}}' > "$STUB_CFG/create_json_11"
  run dispatch launch 1122 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(rec_get 11 launch_failed)" = create ]
  [ "$(rec_get 11 worktree)" = "" ]
}

@test "launch: a failing send keeps the record with launch_failed send and the next launch skips it" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{"stages":["input_accepted"]}}' > "$STUB_CFG/send_json_term-11"
  run dispatch launch 1122 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(rec_get 11 launch_failed)" = send ]
  [ "$(rec_get 11 worktree)" = /work/issue-11 ]
  [ "$(rec_get 11 session)" = term-11 ]
  gh_seq 11 open
  run dispatch launch 1122 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11" ]
  [ "$(calls '^orca worktree create')" -eq 1 ]
}

@test "launch: terminal and ready failures are written to launch_failed" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  echo 1 > "$STUB_CFG/wait_exit_term-12"
  run dispatch launch 1122 11 12
  [ "$status" -eq 1 ]
  [ "$output" = "$(printf 'failed 11\nfailed 12')" ]
  [ "$(rec_get 11 launch_failed)" = terminal ]
  [ "$(rec_get 12 launch_failed)" = ready ]
}

@test "launch: a record with an empty worktree is overwritten and the worktree is made" {
  make_stub orca
  put_record 11 worktree= created_at=2020-01-01T00:00:00Z
  gh_seq 11 open
  run dispatch launch 1122 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
  [ "$(rec_get 11 worktree)" = /work/issue-11 ]
  [ "$(rec_get 11 created_at)" != 2020-01-01T00:00:00Z ]
}

@test "launch: an unreadable own record is failed state-unreadable and left as is" {
  make_stub orca
  mkdir -p "$(dirname "$(rec_of 1122 11)")"
  printf '{\n' > "$(rec_of 1122 11)"
  run dispatch launch 1122 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 state-unreadable" ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  [ "$(cat "$(rec_of 1122 11)")" = "{" ]
  grep -q "$(rec_of 1122 11)" "$BATS_TEST_TMPDIR/stderr"
  # schema の版違いと必須項目の欠けも読めない記録
  put_record 11 schema=2
  run dispatch launch 1122 11
  [ "$output" = "failed 11 state-unreadable" ]
  put_record 11
  jq -c 'del(.worktree)' "$(rec_of 1122 11)" > "$(rec_of 1122 11).x" && mv "$(rec_of 1122 11).x" "$(rec_of 1122 11)"
  run dispatch launch 1122 11
  [ "$output" = "failed 11 state-unreadable" ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
}

@test "launch: an empty-worktree record with an existing Orca worktree is filled and skipped" {
  make_stub orca
  put_record 11 worktree=
  set_list list_json "$(wt_entry 11 '')"
  run dispatch launch 1122 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11" ]
  [ "$(rec_get 11 worktree)" = "$BATS_TEST_TMPDIR/work/issue-11" ]
  [ "$(rec_get 11 branch)" = oratta/issue-11 ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
}

@test "launch: the own empty-worktree record uses its own slot under a limit of 1" {
  make_stub orca
  put_record 11 worktree=
  gh_seq 11 open
  EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch 1122 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
}

@test "launch: the same child by number and by owner/repo#N is launched once" {
  make_stub orca
  run dispatch launch 1122 11 oratta/claude-harness#11
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'launched 11\nskipped oratta/claude-harness#11')" ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
}

# --- mark ---
# spec: dev-workflow-epic-state（子の側は今いるワークツリーのパスで自分の記録を探す・Orca の部品は記録を書いたあとに Orca の印へ写す）

# 今のワークツリーを子 <N> の記録の worktree にする
in_child() { echo "$BATS_TEST_TMPDIR/work/issue-$1" > "$STUB_CFG/toplevel"; }

@test "mark: done and waiting write status and mirror to the board column" {
  make_stub orca
  put_record 11; in_child 11
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 done" ]
  [ "$(rec_get 11 status)" = done ]
  [ "$(rec_get 11 stop)" = "" ]
  [ "$(calls '^orca worktree set --worktree current --workspace-status completed$')" -eq 1 ]
  run dispatch mark waiting 11
  [ "$output" = "marked 11 waiting" ]
  [ "$(rec_get 11 status)" = waiting ]
  [ "$(calls '^orca worktree set --worktree current --workspace-status in-review$')" -eq 1 ]
}

@test "mark: the record is written through a temporary file and nothing is left behind" {
  make_stub orca
  put_record 11; in_child 11
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$(ls -A "$(dirname "$(rec_of 1122 11)")")" = "oratta.claude-harness-11.json" ]
  [ "$(rec_get 11 updated_at)" != "2026-01-01T00:00:00Z" ]
  rec_get 11 updated_at | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

@test "mark: unknown fields in the record are kept" {
  make_stub orca
  put_record 1123 extra=1; in_child 1123
  run dispatch mark done 1123
  [ "$output" = "marked 1123 done" ]
  [ "$(rec_get 1123 status)" = done ]
  [ "$(rec_get 1123 extra)" = 1 ]
}

@test "mark: a worktree without a record does nothing and creates no record" {
  make_stub orca
  put_record 12
  in_child 11
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 no-workspace" ]
  [ "$(find "$EPIC_STATE_ROOT" -type f | wc -l | tr -d ' ')" -eq 1 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  rm -f "$STUB_BIN/orca"
  run dispatch mark stopped 11
  [ "$output" = "skipped 11 no-workspace" ]
}

@test "mark: another issue's record is not marked" {
  make_stub orca
  put_record 461; in_child 461
  run dispatch mark stopped 460
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 460 not-linked" ]
  [ "$(rec_get 461 stop)" = "" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  run dispatch mark done other/repo#461
  [ "$output" = "skipped other/repo#461 not-linked" ]
  run dispatch mark done Oratta/Claude-Harness#461
  [ "$output" = "marked Oratta/Claude-Harness#461 done" ]
}

@test "mark: two records with this worktree is failed without writing" {
  make_stub orca
  put_record 11; put_record 11 epic=oratta/claude-harness#1200
  in_child 11
  run dispatch mark done 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(rec_get 11 status)" = running ]
  grep -qF "$(rec_of 1122 11)" "$BATS_TEST_TMPDIR/stderr"
  grep -qF "$(rec_of 1200 11)" "$BATS_TEST_TMPDIR/stderr"
}

@test "mark: EPIC_DISPATCH_PARENT_EPIC does not change it" {
  make_stub orca
  put_record 11; in_child 11
  EPIC_DISPATCH_PARENT_EPIC=400 run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 done" ]
}

@test "mark: a failing mirror to Orca is still marked, with a warning" {
  make_stub orca
  put_record 1123; in_child 1123
  echo 1 > "$STUB_CFG/set_exit"
  run dispatch mark done 1123
  [ "$status" -eq 0 ]
  [ "$output" = "marked 1123 done" ]
  [ "$(rec_get 1123 status)" = done ]
  grep -qF 'could not mirror' "$BATS_TEST_TMPDIR/stderr"
}

@test "mark: without orca on PATH the record is still marked" {
  put_record 1123; in_child 1123
  run dispatch mark stopped 1123
  [ "$status" -eq 0 ]
  [ "$output" = "marked 1123 stopped" ]
  [ "$(rec_get 1123 stop)" = stopped ]
}

@test "mark: a record from another launcher is not mirrored to Orca" {
  make_stub orca
  put_record 11 launcher=tmux; in_child 11
  run dispatch mark done 11
  [ "$output" = "marked 11 done" ]
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "mark: orca's own output goes to stderr" {
  make_stub orca
  put_record 11; in_child 11
  run dispatch mark done 11
  [ "${#lines[@]}" -eq 1 ]
  grep -qF '"ok":true' "$BATS_TEST_TMPDIR/stderr"
}

@test "mark: bad arguments are rejected without calling orca" {
  make_stub orca
  put_record 11; in_child 11
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
  EPIC_STATE_LOCK_TIMEOUT=x run dispatch mark done 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  EPIC_STATE_LOCK_TIMEOUT= run dispatch mark done 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca')" -eq 0 ]
  [ "$(rec_get 11 status)" = running ]
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
}

@test "mark: a leftover lock means failed without writing, and the lock is kept" {
  make_stub orca
  put_record 1123; in_child 1123
  mkdir "$(rec_of 1122 1123).lock"
  EPIC_STATE_LOCK_TIMEOUT=0 run dispatch mark stopped 1123
  [ "$status" -eq 1 ]
  [ "$output" = "failed 1123" ]
  [ "$(rec_get 1123 stop)" = "" ]
  [ -d "$(rec_of 1122 1123).lock" ]
  grep -qF "$(rec_of 1122 1123).lock" "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

# spec: dev-workflow-develop（epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す）

@test "mark: stopped sets stop, not status, and mirrors the comment" {
  make_stub orca
  put_record 460 status=waiting; in_child 460
  run dispatch mark stopped 460
  [ "$status" -eq 0 ]
  [ "$output" = "marked 460 stopped" ]
  [ "$(rec_get 460 stop)" = stopped ]
  [ "$(rec_get 460 status)" = waiting ]
  [ "$(calls '^orca worktree set --worktree current --comment epic-stopped$')" -eq 1 ]
  [ "$(calls 'workspace-status')" -eq 0 ]
}

@test "mark: done does not touch stop" {
  make_stub orca
  put_record 460 stop=stopped-seen; in_child 460
  run dispatch mark done 460
  [ "$(rec_get 460 stop)" = stopped-seen ]
  [ "$(rec_get 460 status)" = done ]
}

@test "mark: resumed rewrites only a stopped or seen stop" {
  make_stub orca
  put_record 460 stop=stopped; in_child 460
  run dispatch mark resumed 460
  [ "$status" -eq 0 ]
  [ "$output" = "marked 460 resumed" ]
  [ "$(rec_get 460 stop)" = resumed ]
  [ "$(calls '^orca worktree set --worktree current --comment epic-resumed$')" -eq 1 ]
  : > "$STUB_LOG"
  put_record 460 stop=stopped-seen
  run dispatch mark resumed 460
  [ "$output" = "marked 460 resumed" ]
  [ "$(rec_get 460 stop)" = resumed ]
  : > "$STUB_LOG"
  put_record 460
  run dispatch mark resumed 460
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 460 not-stopped" ]
  [ "$(rec_get 460 stop)" = "" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  put_record 460 stop=resumed
  run dispatch mark resumed 460
  [ "$output" = "skipped 460 not-stopped" ]
}

@test "mark: an unreadable record is not a candidate" {
  make_stub orca
  put_record 460; in_child 460
  echo '{' > "$(rec_of 1122 460)"
  run dispatch mark stopped 460
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 460 no-workspace" ]
  [ "$(cat "$(rec_of 1122 460)")" = "{" ]
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

@test "wait: --watch-done ends with done when the record's status becomes done while the issue stays open" {
  make_stub orca
  gh_seq 11 open
  put_record 11 status=waiting
  on_poll 11 2 status=done
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "done 11" ]
  [ "$(calls '^gh ')" -eq 2 ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "wait: closed and done in the same poll print two lines, closed first" {
  make_stub orca
  gh_seq 12 closed
  put_record 11 status=done
  put_record 12 status=waiting
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 --watch-done 12 12
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "closed 12" ]
  [ "${lines[1]}" = "done 11" ]
}

@test "wait: --watch-done alone waits without gh and times out with a bare timeout" {
  make_stub orca
  put_record 11 status=waiting
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout" ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait: orca is never called, with or without --watch-done" {
  make_stub orca
  gh_seq 11 closed
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  put_record 12 status=done
  run dispatch wait --interval 0 --timeout 0 --watch-done 12
  [ "$output" = "done 12" ]
  [ "$(calls '^orca')" -eq 0 ]
}

# --- wait --watch-done: 完了の推定 ---
# spec: dev-workflow-develop（epic-dispatch.sh wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する）
# spec: dev-workflow-epic-state（wait --watch-done は推定した完了を記録に書き、Orca の印へ写す）

# 子 11 のトランスクリプトに、<分> 前の timestamp を持つ行を 1 行足す（<分> [ファイル名] [type]）。
# 足した timestamp を $BATS_TEST_TMPDIR/ts_<ファイル名> に書く
put_activity() {
  local ago="$1" name="${2-s1}" type="${3-assistant}"
  local p="$BATS_TEST_TMPDIR/work/issue-11" dir ts
  dir="$BATS_TEST_TMPDIR/projects/$(printf '%s' "$p" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$dir"
  ts="$(python3 -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=$ago)).strftime('%Y-%m-%dT%H:%M:%S.000Z'))")"
  printf '{"type":"%s","timestamp":"%s"}\n' "$type" "$ts" >> "$dir/$name.jsonl"
  printf '%s\n' "$ts" > "$BATS_TEST_TMPDIR/ts_$name"
  export CLAUDE_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
}

# 推定される条件: 記録は running・stop 空・extra 付き、トランスクリプトの最後の活動が 40 分前、issue は completed で閉じた
infer_ready() {
  make_stub orca
  put_record 11 extra=1
  put_activity 50
  put_activity 40
  gh_seq 11 "closed completed 2400"
}

@test "wait infer: a closed, idle child without the done mark is inferred done" {
  infer_ready
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG" "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "done 11" ]
  [ "$(rec_get 11 status)" = done ]
  rec_get 11 done_inferred_at | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
  [ "$(rec_get 11 done_inferred_last_activity)" = "$(cat "$BATS_TEST_TMPDIR/ts_s1")" ]
  [ "$(rec_get 11 extra)" = 1 ]
  [ "$(rec_get 11 schema)" = 1 ]
  [ ! -e "$(rec_of 1122 11).lock" ]
  [ -z "$(ls -A "$(dirname "$(rec_of 1122 11)")" | grep -F .tmp)" ]
  grep -q '^inferred done 11: issue closed as completed, no transcript activity since ' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^gh ')" -eq 1 ]
  grep -F 'gh api' "$STUB_LOG" | grep -qF 'repos/\{owner\}/\{repo\}/issues/11'
}

@test "wait infer: an Orca child inferred done is mirrored to the completed mark once" {
  infer_ready
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$output" = "done 11" ]
  [ "$(calls "^orca worktree set --worktree path:$BATS_TEST_TMPDIR/work/issue-11 --workspace-status completed\$")" -eq 1 ]
}

@test "wait infer: a tmux child inferred done calls no orca" {
  infer_ready
  put_record 11 launcher=tmux
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$output" = "done 11" ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "wait infer: activity newer than the threshold is not inferred and gh is not called" {
  infer_ready
  put_activity 10
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
  [ "$(rec_get 11 status)" = running ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait infer: a newer line of any type counts as activity" {
  infer_ready
  put_activity 5 s1 user
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$output" = "timeout" ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait infer: no transcript is not inferred and gh is not called" {
  make_stub orca
  put_record 11
  export CLAUDE_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
  gh_seq 11 "closed completed 2400"
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
  [ "$(rec_get 11 status)" = running ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait infer: a transcript without any timestamp is not inferred" {
  infer_ready
  rm -rf "$BATS_TEST_TMPDIR/projects"
  put_activity 40
  sed -i.bak 's/"timestamp":"[^"]*"/"x":1/' "$BATS_TEST_TMPDIR"/projects/*/s1.jsonl
  rm -f "$BATS_TEST_TMPDIR"/projects/*/s1.jsonl.bak
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$output" = "timeout" ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait infer: two transcripts with one newer than the threshold are not inferred" {
  infer_ready
  put_activity 10 s2
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
  [ "$(rec_get 11 status)" = running ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait infer: two transcripts both older than the threshold are inferred with the newest timestamp" {
  infer_ready
  put_activity 45 s2
  put_activity 35 s2
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 0 ]
  [ "$output" = "done 11" ]
  [ "$(rec_get 11 done_inferred_last_activity)" = "$(cat "$BATS_TEST_TMPDIR/ts_s2")" ]
}

@test "wait infer: waiting, stopped and stopped-seen children are not inferred and gh is not called" {
  local kv
  for kv in status=waiting stop=stopped stop=stopped-seen; do
    infer_ready
    put_record 11 extra=1 "$kv"
    : > "$STUB_LOG"
    before="$(cat "$(rec_of 1122 11)")"
    run dispatch wait --interval 0 --timeout 0 --watch-done 11
    [ "$status" -eq 2 ] || { echo "$kv: status=$status output=$output"; false; }
    [ "$output" = "timeout" ]
    [ "$(cat "$(rec_of 1122 11)")" = "$before" ]
    [ "$(calls '^gh ')" -eq 0 ] || { echo "$kv"; cat "$STUB_LOG"; false; }
  done
}

@test "wait infer: an open issue or one closed as not_planned is not inferred" {
  local v
  for v in "open " "closed not_planned 2400"; do
    infer_ready
    gh_seq 11 "$v"
    rm -f "$STUB_CFG/ghcount_11"
    run dispatch wait --interval 0 --timeout 0 --watch-done 11
    [ "$status" -eq 2 ] || { echo "$v: status=$status output=$output"; false; }
    [ "$output" = "timeout" ]
    [ "$(rec_get 11 status)" = running ]
  done
}

@test "wait infer: an issue closed less than the threshold ago or without closed_at is not inferred" {
  local v
  for v in "closed completed 60" "closed completed "; do
    infer_ready
    gh_seq 11 "$v"
    rm -f "$STUB_CFG/ghcount_11"
    run dispatch wait --interval 0 --timeout 0 --watch-done 11
    [ "$status" -eq 2 ] || { echo "[$v]: status=$status output=$output"; false; }
    [ "$output" = "timeout" ]
    [ "$(rec_get 11 status)" = running ]
  done
  # 閾値を閉じてからの秒数より短くすれば推定する
  gh_seq 11 "closed completed 60"
  rm -f "$STUB_CFG/ghcount_11"
  EPIC_DISPATCH_DONE_IDLE_SEC=30 run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$output" = "done 11" ]
}

@test "wait infer: the inference reads closed_at with state and state_reason in one gh call" {
  infer_ready
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$output" = "done 11" ]
  [ "$(calls '^gh ')" -eq 1 ]
  grep -F 'gh api' "$STUB_LOG" | grep -F 'state_reason' | grep -qF 'closed_at'
}

@test "wait infer: a newer line only in a subagent transcript is not inferred" {
  infer_ready
  local dir="$BATS_TEST_TMPDIR/projects/$(printf '%s' "$BATS_TEST_TMPDIR/work/issue-11" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$dir/s1/subagents"
  ts="$(python3 -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=10)).strftime('%Y-%m-%dT%H:%M:%S.000Z'))")"
  printf '{"type":"assistant","timestamp":"%s"}\n' "$ts" > "$dir/s1/subagents/agent-a1.jsonl"
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; false; }
  [ "$output" = "timeout" ]
  [ "$(rec_get 11 status)" = running ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait infer: a child whose record changes before the write is not inferred" {
  infer_ready
  # 推定の gh の呼び出し（子 11 の 1 回目）の間に子が waiting の印を付けた
  on_poll 11 1 status=waiting
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "timeout" ]
  [ "$(rec_get 11 status)" = waiting ]
  [ "$(rec_get 11 done_inferred_at)" = null ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ ! -e "$(rec_of 1122 11).lock" ]
}

@test "wait infer: without CLAUDE_PROJECTS_DIR the transcripts are read under CLAUDE_CONFIG_DIR" {
  infer_ready
  mkdir -p "$BATS_TEST_TMPDIR/cfg"
  mv "$BATS_TEST_TMPDIR/projects" "$BATS_TEST_TMPDIR/cfg/projects"
  unset CLAUDE_PROJECTS_DIR
  CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg" run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "done 11" ]
}

@test "wait infer: a failing gh for the inference is neither inferred nor counted as a failed poll" {
  infer_ready
  gh_seq 11 FAIL
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; false; }
  [ "$output" = "timeout" ]
  [ "$(rec_get 11 status)" = running ]
  # 4 回続けて失敗しても error で終わらず、次に読めたポーリングで推定する
  gh_seq 11 FAIL FAIL FAIL FAIL "closed completed 2400"
  rm -f "$STUB_CFG/ghcount_11"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; false; }
  [ "$output" = "done 11" ]
  [ "$(cat "$STUB_CFG/ghcount_11")" -eq 5 ]
}

@test "wait infer: EPIC_DISPATCH_DONE_IDLE_SEC changes the threshold" {
  infer_ready
  rm -rf "$BATS_TEST_TMPDIR/projects"
  put_activity 10
  EPIC_DISPATCH_DONE_IDLE_SEC=300 run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "done 11" ]
}

@test "wait infer: a wrong EPIC_DISPATCH_DONE_IDLE_SEC prints usage and calls no gh" {
  local v
  for v in abc "" 1.5; do
    infer_ready
    : > "$STUB_LOG"
    EPIC_DISPATCH_DONE_IDLE_SEC="$v" run dispatch wait --interval 0 --timeout 60 --watch-done 11
    [ "$status" -eq 1 ] || { echo "[$v]: status=$status output=$output"; false; }
    [ -z "$output" ]
    grep -qF 'EPIC_DISPATCH_DONE_IDLE_SEC' "$BATS_TEST_TMPDIR/stderr"
    grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
    [ "$(calls '^gh ')" -eq 0 ]
    [ "$(rec_get 11 status)" = running ]
  done
}

@test "wait infer: a wrong EPIC_DISPATCH_DONE_IDLE_SEC is ignored without --watch-done" {
  make_stub orca
  gh_seq 11 closed
  EPIC_DISPATCH_DONE_IDLE_SEC=abc run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
}

@test "wait infer: a left lock fails three polls with error workspaces and the record stays running" {
  infer_ready
  mkdir "$(rec_of 1122 11).lock"
  EPIC_STATE_LOCK_TIMEOUT=0 run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 1 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "error workspaces" ]
  [ "$(rec_get 11 status)" = running ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait infer: the same child as a positional argument and --watch-done prints closed then done" {
  infer_ready
  gh_seq 11 closed "closed completed 2400"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "closed 11" ]
  [ "${lines[1]}" = "done 11" ]
  [ "$(rec_get 11 status)" = done ]
}

@test "wait infer: a child that already marked done is reported without inference" {
  infer_ready
  put_record 11 status=done
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$output" = "done 11" ]
  [ "$(calls '^gh ')" -eq 0 ]
  [ "$(rec_get 11 done_inferred_at)" = null ]
}

@test "script: the head comment of wait describes the inference" {
  h="$(sed -n '1,/^set -uo pipefail/p' "$SCRIPT")"
  printf '%s\n' "$h" | grep -qF 'EPIC_DISPATCH_DONE_IDLE_SEC'
  printf '%s\n' "$h" | grep -qF 'done_inferred_at'
  printf '%s\n' "$h" | grep -qF 'wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する'
  grep -qF 'done_inferred_last_activity' "$PLUGIN_DIR/scripts/epic-state.sh"
}

@test "wait: the done mark only on Orca's board does not wake the parent" {
  # spec: dev-workflow-epic-state（Orca の印だけでは wait は起きない）
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 12 completed)"
  put_record 12 status=running
  run dispatch wait --interval 0 --timeout 0 --watch-done 12
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
}

@test "wait: records of another parent worktree or another epic repository do not count" {
  make_stub orca
  put_record 11 status=done parent_worktree=/work/other
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
  rm -rf "$EPIC_STATE_ROOT"
  put_record 11 status=done repo=genetta-inc/flatmate child=genetta-inc/flatmate#11
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
  run dispatch wait --interval 0 --timeout 0 --watch-done genetta-inc/flatmate#11
  [ "$status" -eq 0 ]
  [ "$output" = "done genetta-inc/flatmate#11" ]
}

@test "wait: two records for the same child under the same parent are not looked at" {
  make_stub orca
  put_record 11 status=done
  put_record 11 status=done epic=oratta/claude-harness#900
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
}

@test "wait: three polls with an unreadable record end with error workspaces and leave the record" {
  # spec: dev-workflow-epic-state（読めない記録が続くと wait は error workspaces）
  make_stub orca
  gh_seq 11 open
  put_record 11 stop=paused
  before="$(cat "$(rec_of 1122 11)")"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 1 ]
  [ "$output" = "error workspaces" ]
  [ "$(cat "$(rec_of 1122 11)")" = "$before" ]
  grep -qF "$(rec_of 1122 11)" "$BATS_TEST_TMPDIR/stderr"
  mkdir -p "$EPIC_STATE_ROOT/oratta.claude-harness-1122"
  printf '{\n' > "$(rec_of 1122 12)"
  run dispatch wait --interval 0 --timeout 60 --watch-done 12
  [ "$status" -eq 1 ]
  [ "$output" = "error workspaces" ]
}

@test "wait: stop seen and an empty status are unreadable, not matched as substrings" {
  make_stub orca
  gh_seq 11 open
  put_record 11 stop=seen
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 1 ]
  [ "$output" = "error workspaces" ]
  put_record 11 status=
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 1 ]
  [ "$output" = "error workspaces" ]
}

@test "wait: an unreadable record with a failing gh child ends with error gh" {
  make_stub orca
  put_record 11 status=bogus
  gh_seq 12 FAIL
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 12
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 12" ]
}

@test "wait: --watch-done fails with no stdout when the current worktree cannot be read, but not for lack of orca" {
  make_stub orca
  printf '#!/bin/bash\nexit 1\n' > "$STUB_BIN/git"; chmod +x "$STUB_BIN/git"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^gh ')" -eq 0 ]
  make_stub git
  rm -f "$STUB_BIN/orca"
  put_record 11 status=done
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 0 ]
  [ "$output" = "done 11" ]
}

@test "wait: a malformed --watch-done is rejected" {
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

@test "wait: a child given as owner/repo#N reads that repository's issue and keeps its form" {
  # spec: dev-workflow-epic-state（owner/repo#番号 で渡した子はその形で返る）
  put_record 1615 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1615
  gh_seq 1615 closed
  run dispatch wait --interval 0 --timeout 0 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ]
  [ "$output" = "closed genetta-inc/flatmate#1615" ]
  grep -q '^gh api repos/genetta-inc/flatmate/issues/1615 --jq .state$' "$STUB_LOG"
}

@test "wait: a same-repository child with a record calls gh as before and never reads origin" {
  # spec: dev-workflow-epic-state（同じリポジトリの子は今と同じ形で gh を呼ぶ）
  put_record 11
  gh_seq 11 closed
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  grep -q '^gh api repos/.*owner.*/.*repo.*/issues/11 --jq .state$' "$STUB_LOG"
  [ "$(calls '^git remote get-url origin')" -eq 0 ]
}

@test "wait: malformed children print usage and call nothing" {
  # spec: dev-workflow-epic-state（番号でも owner/repo#番号 でもない引数は使い方を出す）
  for a in foo '#12' 'oratta/claude-harness#' 'claude-harness#12'; do
    run dispatch wait --interval 0 --timeout 0 "$a"
    [ "$status" -eq 1 ] || { echo "arg=$a status=$status"; false; }
    grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
  done
  [ "$(calls '^gh ')" -eq 0 ]
}

# --- wait --watch-stopped ---
# spec: dev-workflow-develop（epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す）
# spec: dev-workflow-epic-state（親の見張りは記録だけで子の状態を判定する）

@test "wait: --watch-stopped rewrites a stopped record to seen, mirrors it to Orca and ends with stopped" {
  make_stub orca
  gh_seq 11 open
  put_record 11 status=waiting stop=stopped
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(rec_get 11 stop)" = stopped-seen ]
  [ "$(rec_get 11 status)" = waiting ]
  [ "$(calls "^orca worktree set --worktree path:$BATS_TEST_TMPDIR/work/issue-11 --comment epic-stopped-seen\$")" -eq 1 ]
  [ "$(calls '^orca worktree set')" -eq 1 ]
  [ "$(calls '^orca worktree list')" -eq 0 ]
  [ "$(calls 'workspace-status')" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ -z "$(ls -A "$EPIC_STATE_ROOT/oratta.claude-harness-1122" | grep -v '\.json$')" ]
}

@test "wait: --watch-stopped works without orca and the Orca comment alone does not wake it" {
  gh_seq 11 open
  put_record 11 stop=stopped
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(rec_get 11 stop)" = stopped-seen ]
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 12 in-review repo-a::/work/parent repo-a false epic-stopped)"
  gh_seq 12 open
  put_record 12
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 12
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 12" ]
}

@test "wait: --watch-stopped does not wake on seen or resumed records" {
  make_stub orca
  gh_seq 11 open
  gh_seq 12 open
  put_record 11 stop=stopped-seen
  put_record 12 stop=resumed
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11 12
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11 12" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait: closed, done and stopped in the same poll print three lines in that order" {
  make_stub orca
  gh_seq 12 closed
  gh_seq 13 open
  put_record 11 status=done
  put_record 13 stop=stopped
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 --watch-stopped 12 13
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "closed 12" ]
  [ "${lines[1]}" = "done 11" ]
  [ "${lines[2]}" = "stopped 13" ]
  [ "$(calls '^gh ')" -eq 2 ]
}

@test "wait: a closed child is not counted as stopped" {
  make_stub orca
  gh_seq 11 closed
  put_record 11 stop=stopped
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  [ "$(rec_get 11 stop)" = stopped ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait: a stopped record of another parent does not count" {
  make_stub orca
  gh_seq 11 open
  put_record 11 stop=stopped parent_worktree=/work/other
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11" ]
  [ "$(rec_get 11 stop)" = stopped ]
}

@test "wait: three polls failing to take the lock end with error workspaces and the stop stays" {
  make_stub orca
  gh_seq 11 open
  put_record 11 stop=stopped
  mkdir "$(rec_of 1122 11).lock"
  EPIC_STATE_LOCK_TIMEOUT=0 run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 1 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "error workspaces" ]
  [ "$(rec_get 11 stop)" = stopped ]
  [ -d "$(rec_of 1122 11).lock" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "wait: a one-shot check that cannot take the lock ends with timeout and prints the reason to stderr" {
  make_stub orca
  gh_seq 11 open
  put_record 11 stop=stopped
  mkdir "$(rec_of 1122 11).lock"
  EPIC_STATE_LOCK_TIMEOUT=0 run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "timeout 11" ]
  grep -qF 'the state record is locked:' "$BATS_TEST_TMPDIR/stderr"
  [ "$(rec_get 11 stop)" = stopped ]
}

@test "wait: a one-shot check with nothing failing ends with timeout and an empty stderr" {
  make_stub orca
  gh_seq 11 open
  put_record 11 stop=resumed
  EPIC_STATE_LOCK_TIMEOUT=0 run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11" ]
  [ ! -s "$BATS_TEST_TMPDIR/stderr" ] || { cat "$BATS_TEST_TMPDIR/stderr"; false; }
}

@test "wait: a failing mirror to Orca still ends with stopped" {
  make_stub orca
  gh_seq 11 open
  echo 1 > "$STUB_CFG/set_comment_exit"
  put_record 11 stop=stopped
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(rec_get 11 stop)" = stopped-seen ]
  grep -qF 'could not mirror' "$BATS_TEST_TMPDIR/stderr"
}

@test "wait: without --watch-stopped the stop is never read" {
  make_stub orca
  gh_seq 11 open
  put_record 11 stop=stopped
  run dispatch wait --interval 0 --timeout 0 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11" ]
  run dispatch wait --interval 0 --timeout 0 --watch-done 12 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout 11" ]
  [ "$(rec_get 11 stop)" = stopped ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "wait: --watch-stopped with --watch-done and no positional child looks at no stop" {
  make_stub orca
  put_record 11 stop=stopped
  run dispatch wait --interval 0 --timeout 0 --watch-done 11 --watch-stopped
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
  [ "$(rec_get 11 stop)" = stopped ]
}

@test "wait: a seen stop does not wake the parent again, a stop marked again does" {
  make_stub orca
  gh_seq 11 open
  put_record 11 stop=stopped
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ] || { echo "1st: status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "stopped 11" ]
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 2 ] || { echo "2nd: status=$status output=$output"; false; }
  [ "$output" = "timeout 11" ]
  in_child 11
  run dispatch mark stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 stopped" ]
  echo /work/parent > "$STUB_CFG/toplevel"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ] || { echo "3rd: status=$status output=$output"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(rec_get 11 stop)" = stopped-seen ]
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
  for c in not-done head-mismatch dirty llm-logs; do
    rm -rf "$STUB_CFG" "$p"; mkdir -p "$STUB_CFG"; : > "$STUB_LOG"
    printf '%s\n' '/work/parent' > "$STUB_CFG/toplevel"
    reap_ready
    case "$c" in
      not-done) put_record 11 status=running ;;
      head-mismatch) echo bbb222 > "$STUB_CFG/head" ;;
      dirty) echo ' M a.txt' > "$STUB_CFG/status_out" ;;
      llm-logs) mkdir -p "$p/LLM" ;;
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

@test "reap: a failing git status and a record without a branch are kept" {
  reap_ready
  echo 128 > "$STUB_CFG/status_exit"
  run dispatch reap 11
  [ "$output" = "kept 11 git-failed" ]
  rm -f "$STUB_CFG/status_exit"
  put_record 11 status=done branch=
  run dispatch reap 11
  [ "$output" = "kept 11 no-branch" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
  [ -e "$(rec_of 1122 11)" ]
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

@test "reap: a child without a record or without its worktree directory is gone, two records are ambiguous" {
  reap_ready
  rm -f "$(rec_of 1122 11)"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "gone 11" ]
  [ "$(calls '^git -C')" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
  put_record 11 status=done
  rm -rf "$BATS_TEST_TMPDIR/work/issue-11"
  run dispatch reap 11
  [ "$output" = "gone 11" ]
  [ ! -e "$(rec_of 1122 11)" ]
  put_record 11 status=done worktree=
  run dispatch reap 11
  [ "$output" = "gone 11" ]
  [ ! -e "$(rec_of 1122 11)" ]
  put_record 11 status=done
  put_record 11 status=done epic=oratta/claude-harness#900
  run dispatch reap 11
  [ "$output" = "kept 11 ambiguous" ]
  [ -e "$(rec_of 1122 11)" ]
  [ -e "$(rec_of 900 11)" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: a broken record is kept as state-unreadable and stays as it is" {
  reap_ready
  printf '{\n' >| "$(rec_of 1122 11)"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 state-unreadable" ]
  [ "$(cat "$(rec_of 1122 11)")" = "{" ]
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "reap: a reaped child's record is removed, and a second reap of it is gone" {
  reap_ready
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
  [ ! -e "$(rec_of 1122 11)" ]
  run dispatch reap 11
  [ "$output" = "gone 11" ]
}

@test "reap: another parent's record is not looked at and the child is gone" {
  reap_ready
  put_record 11 status=done parent_worktree=/work/other
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "gone 11" ]
  [ -e "$(rec_of 1122 11)" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: an Orca completed mark alone does not reap a running child" {
  reap_ready
  put_record 11 status=running
  set_list list_json "$(wt_entry 11 completed)"
  run dispatch reap 11
  [ "$output" = "kept 11 not-done" ]
  [ "$(calls '^orca worktree list')" -eq 0 ]
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
  put_record 11 status=done
  echo bbb222 > "$STUB_CFG/branch_tip"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11 branch-kept" ]
  [ ! -e "$(rec_of 1122 11)" ]
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
  put_record 12 status=running
  run dispatch reap 11 12 11
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "reaped 11" ]
  [ "${lines[1]}" = "kept 12 not-done" ]
  [ "$(calls '^orca worktree rm')" -eq 1 ]
  [ "$(calls "^orca worktree rm --worktree path:$BATS_TEST_TMPDIR/work/issue-11$")" -eq 1 ]
  [ "$(calls '^orca worktree list')" -eq 0 ]
}

@test "reap: EPIC_DISPATCH_PARENT_EPIC does not change it" {
  reap_ready
  EPIC_DISPATCH_PARENT_EPIC=400 run dispatch reap 11
  [ "$output" = "reaped 11" ]
}

@test "reap: no worktree to stand on or no jq removes nothing and prints nothing" {
  reap_ready
  : >| "$STUB_CFG/toplevel"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  printf '%s\n' '/work/parent' >| "$STUB_CFG/toplevel"
  run dispatch_nojq reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
  [ -e "$(rec_of 1122 11)" ]
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
  put_record 12 status=done
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
  put_record 12 status=done
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
  e="$(section 'エピックの扱い' "$EPIC")"
  printf '%s\n' "$e" | grep -qF 'sub_issues_summary'
  printf '%s\n' "$e" | grep -qF 'nested'
  printf '%s\n' "$e" | grep -F '後で別に起動するエピック:' | grep -qF '完了報告'
  printf '%s\n' "$e" | grep -F 'timeout' | grep -F 'closed' | grep -qF '後で別に起動するエピック:'
  printf '%s\n' "$e" | grep -F 'launch' | grep -F 'nested' | grep -qF '「親ワークツリーで開き直す」とは報告しない'
}

@test "skill: the parent's note is a comment every restarted child session follows and hands on" {
  e="$(section 'エピックの扱い' "$EPIC")"
  printf '%s\n' "$e" | grep -F '親エピックからの注意書き:' | grep -F '起動し直したセッション' | grep -qF 'W・R1・G'
  printf '%s\n' "$e" | grep -F 'note not posted to' | grep -qF '投稿'
  # 規則は epic.md にだけあるので、起動し直した子にも SKILL.md の案内が epic.md を読ませる（#1243 の F1）
  section 'エピックの扱い' | grep -F '`親エピックからの注意書き:` で始まるコメントがあるとき' | grep -qF '起動し直した'
}

@test "skill: the parent's note is followed only when its author is an owner, member or collaborator" {
  l="$(section 'エピックの扱い' "$EPIC" | grep -F '親エピックからの注意書き:' | grep -F 'author_association')"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -F 'OWNER' | grep -F 'MEMBER' | grep -qF 'COLLABORATOR'
  printf '%s\n' "$l" | grep -F 'それ以外' | grep -F '従わず' | grep -F '渡さず' | grep -qF 'ユーザーに報告'
}

@test "skill: a restarted child session is nested and reads the parent epic from stderr" {
  e="$(section 'エピックの扱い' "$EPIC")"
  printf '%s\n' "$e" | grep -F '起動し直したセッション' | grep -qF 'nested'
  printf '%s\n' "$e" | grep -qF 'parent epic: #'
  printf '%s\n' "$e" | grep -qF 'child epics are not expanded here'
  printf '%s\n' "$e" | grep -F 'parent epic:' | grep -F 'EPIC_DISPATCH_PARENT_EPIC' | grep -qF '状態の記録の無いワークツリー'
}

@test "skill: a child whose terminal was not created is checked, recreated and sent before resuming" {
  e="$(section 'エピックの扱い' "$EPIC")"
  printf '%s\n' "$e" | grep -F '端末を作れなかった' | grep -F '既存の端末が無いこと' | grep -F '作り直し' | grep -qF '動き出したのを確かめてから再開'
}

@test "skill: held-back child epics are recorded also when route is skipped (unmanned, resumed)" {
  e="$(section 'エピックの扱い' "$EPIC" | grep -F 'sub_issues_summary')"
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

# spec: dev-workflow-develop（エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う）

@test "skill: Orca route parent statements follow the canonical first-line rule" {
  r="$(run_section)"
  l="$(printf '%s\n' "$r" | grep -F '主がすること: なし' | grep -v '^8\. ' | head -1)"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -qF 'ターンを終えるとき'
  printf '%s\n' "$l" | grep -qF '`~/.claude/output-styles/readable.md` の節 3'
  printf '%s\n' "$l" | grep -qF '答え方の行'
  printf '%s\n' "$l" | grep -qF '主がこのセッションで次にすること:'
  ! printf '%s\n' "$l" | grep -qF '<どの画面・入力欄で> <何を打つ・押す>' || return 1
  for n in 2 3 4 5 6; do
    printf '%s\n' "$r" | grep "^$n\. " | grep -qF '上の書き分けの規定に従う'
  done
  s8="$(printf '%s\n' "$r" | grep '^8\. ')"
  printf '%s\n' "$s8" | grep -F '答え方の行' | grep -qF '親のタブ'
  printf '%s\n' "$s8" | grep -qF '別の発言を挟まず'
  printf '%s\n' "$s8" | grep -qF '答え方の行には、子のタブでリスク許容を打つことを書く'
  printf '%s\n' "$s8" | grep -qF '`failed <N> <段>` なら主に報告する（主の操作が要れば問いの形にし、要らなければ 1 行目を `主がすること: なし` にする）'
  printf '%s\n' "$r" | grep -qF '手順 7 と完了条件で待ちを終えるときの報告、**マージ待ちの子** の `reply` の `failed` の報告'
  printf '%s\n' "$r" | grep '^2\. ' | grep -qF '待ちに入る通知を `主がすること: なし` で始めず、1 行目に問いの質問を、最後の行に答え方を繰り返す'
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
  printf '%s\n' "$r" | grep -F 'stdout に何も出さず exit 1' | grep -F '`adopt`' | grep -F 'not in an Orca-managed worktree' | grep -qF '親ワークツリーで開き直す'
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

# orca をコマンドとして書いた行（行頭・; & | ( ! $( と if/then/do/else/while/until のあとに orca <小文字>）を持つ
# シェルスクリプトを列挙する（<ディレクトリ>）。文字列とコメントの中の orca は拾わない
orca_cmd_scripts() {
  grep -rlE '(^|[;&|(!]|(if|then|do|else|while|until) )[[:space:]]*orca [a-z]+' "$1" --include='*.sh'
}

@test "skill: develop's docs run no orca subcommand and only the Orca launcher calls orca" {
  [ -z "$(orca_doc_violations "$PLUGIN_DIR/skills/develop")" ]
  [ "$(grep -rhoF "$ORCA_DOC_ALLOWED" "$PLUGIN_DIR/skills/develop" | grep -c .)" -eq 1 ]
  run orca_cmd_scripts "$PLUGIN_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$PLUGIN_DIR/scripts/epic-launch-orca.sh" ]
  # 記録を読み書きするスクリプトは orca の語を含まない
  # epic-state.sh は記録の launcher の値の検査（launcher == "orca"）だけに orca の語を持つ（部品のコマンドは呼ばない）
  run grep -w orca "$PLUGIN_DIR/scripts/epic-state.sh"
  [ "$(printf '%s\n' "$output" | grep -vF 'launcher == "orca"' | grep -c .)" -eq 0 ]
}

@test "skill: an orca command added to a copy of epic-dispatch.sh is found" {
  local d="$BATS_TEST_TMPDIR/copy"
  mkdir -p "$d"
  cp "$SCRIPT" "$d/epic-dispatch.sh"
  [ -z "$(orca_cmd_scripts "$d")" ]
  printf '%s\n' 'orca terminal list --json' >> "$d/epic-dispatch.sh"
  [ "$(orca_cmd_scripts "$d")" = "$d/epic-dispatch.sh" ]
}

# spec: dev-workflow-develop（エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する）

@test "skill: an epic child records its stop before marking it, in both waiting orders" {
  r="$(section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP")"
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

@test "skill: an epic child's stop record lists the seven items in order" {
  r="$(section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP")"
  [ -n "$r" ]
  # 7 つの項目名が行頭の `<項目名>:` の形でこの順に出る（雛形の行で確かめる）
  prev=0
  for k in '止まった理由:' '主に聞く理由:' '前提:' '推奨:' '推奨の根拠:' '受け入れるリスク:' '再開に要る途中経過:'; do
    n="$(printf '%s\n' "$r" | grep -n "^${k}" | head -1 | cut -d: -f1)"
    [ -n "$n" ]
    [ "$n" -gt "$prev" ]
    prev="$n"
  done
  printf '%s\n' "$r" | grep -F '7 つの項目' | grep -qF 'どの項目も省かない'
  run grep -F '6 つの項目' <<<"$r"; [ "$status" -eq 1 ]
  printf '%s\n' "$r" | grep -qF 'ほかの 6 項目も省かない'
  run grep -F 'ほかの 5 項目' <<<"$r"; [ "$status" -eq 1 ]
  printf '%s\n' "$r" | grep -F '該当が無い項目' | grep -qF '`なし` と書く'
  printf '%s\n' "$r" | grep -qF '`推奨: なし（<足りない情報>）`'
  printf '%s\n' "$r" | grep -F '次の項目の行まで' | grep -qF '複数行'
  printf '%s\n' "$r" | grep -F '`再開に要る途中経過:`' | grep -qF '引き継ぎのコメントの URL'
}

@test "skill: an epic child's stop record says why the owner is asked and how likely the risk is" {
  r="$(section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP")"
  # 雛形の止まった理由は主にしてほしいことだけで、子の側でできない理由を混ぜない
  printf '%s\n' "$r" | grep '^止まった理由:' | grep -qF '主にしてほしいこと'
  run grep -F 'それを子の側でできない理由' <<<"$r"; [ "$status" -eq 1 ]
  # 主に聞く理由は正本の 3 つの理由の語で始める
  l="$(printf '%s\n' "$r" | grep -F '`主に聞く理由:`')"
  [ -n "$l" ]
  for w in '主の側にしか答えが無い' '決まりで主の承認が要る' '主の手でしかできない操作'; do
    printf '%s\n' "$l" | grep -qF "$w" || { echo "missing reason: $w"; return 1; }
  done
  printf '%s\n' "$r" | grep -qF '`主に聞く理由: なし（<子の側で進められない理由>）`'
  printf '%s\n' "$r" | grep -F 'どれにも当たらない' | grep -F '止まらず' | grep -qF '事後報告'
  printf '%s\n' "$r" | grep -qF '~/.claude/output-styles/readable.md'
  # 受け入れるリスクに被害・頻度・根拠を含める
  k="$(printf '%s\n' "$r" | grep -F '`受け入れるリスク:`' | grep -F '頻度')"
  [ -n "$k" ]
  printf '%s\n' "$k" | grep -qF '確かめたのか見込みか'
  printf '%s\n' "$k" | grep -qF '戻せるか'
  printf '%s\n' "$k" | grep -qF '分からない'
}

@test "skill: an epic child's stop record is written for readers who have not read the child's conversation" {
  r="$(section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP")"
  printf '%s\n' "$r" | grep -qF '子の会話を読んでいない'
  printf '%s\n' "$r" | grep -F '「上記」' | grep -qF '「前回」'
  printf '%s\n' "$r" | grep -qF 'フル URL'
  printf '%s\n' "$r" | grep -F '専門用語' | grep -qF '言い換え'
  printf '%s\n' "$r" | grep -qF 'rules/communication-style.md'
}

@test "skill: step 8 of the Orca route restates the stop record in the readable steps" {
  p="$(run_section | grep -E '^8\. ')"
  [ -n "$p" ]
  run grep -F '同じ項目名のまま' <<<"$p"; [ "$status" -eq 1 ]
  # 記録の項目と正本の段の対応
  printf '%s\n' "$p" | grep -qF '`止まった理由:` を質問に'
  printf '%s\n' "$p" | grep -qF '`主に聞く理由:` を主に聞く理由に'
  printf '%s\n' "$p" | grep -qF '`前提:` をいま困っていることに'
  printf '%s\n' "$p" | grep -qF '`推奨:` と `推奨の根拠:` を推奨と根拠に'
  printf '%s\n' "$p" | grep -qF '`受け入れるリスク:` を受け入れるリスクに'
  printf '%s\n' "$p" | grep -qF '項目名を見出しや語としてそのまま主に渡さず'
  printf '%s\n' "$p" | grep -qF '主の言葉に直す'
  printf '%s\n' "$p" | grep -F '複数' | grep -qF '1 通で上げるのは 1 件'
  # 記録の節は項目名をそろえる文を持たず、置き直すことを書く
  r="$(section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP")"
  run grep -F '報告する語と同じにしてある' <<<"$r"; [ "$status" -eq 1 ]
  printf '%s\n' "$r" | grep -F '正本の段に置き直して' | grep -qF '手順 8'
  printf '%s\n' "$r" | grep -F '`止まった理由`' | grep -F '`PR のマージ待ち（`' | grep -qF '名前を変えない'
  # ファイル全体に「同じ項目名のまま」が残らない
  run grep -n '同じ項目名のまま' "$SKILL"; [ "$status" -eq 1 ]
}

@test "skill: step 8 checks repeats and casting before overturning, and step 7 pending and the leftover note follow it" {
  p="$(run_section | grep -E '^8\. ')"
  printf '%s\n' "$p" | grep -F '照らす前に' | grep -F '親の判断: 子 #N 通した' | grep -F '.claude/casting/project.md' | grep -qF '既に一度通していれば覆さずに主に上げる'
  printf '%s\n' "$p" | grep -qF '待ちに入る通知の本文に、まだ上げていない止まった子の番号を 1 行書く'
  q="$(run_section | grep -E '^7\. ')"
  printf '%s\n' "$q" | grep -qF '手順 8 と同じに扱い（照らして通すか、報告を本文で出し直す）、待ちに入る'
  r="$(section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP")"
  printf '%s\n' "$r" | grep -qF '破壊的操作や聖域を止めた hook は「決まりで主の承認が要る」に当たる'
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
  printf '%s\n' "$p" | grep -qF '一致する `親の判断:` が無ければ、判断が無いものとして扱う'
  run grep -F '判断が無いものとして主に上げる' <<<"$p"; [ "$status" -eq 1 ]
  # 主に上げる前に親が自分で基準に照らし、主に聞く理由の無い止まりは通す
  printf '%s\n' "$p" | grep -F '主に上げる前に' | grep -qF '`references/parent-pass-criteria.md` に照らす'
  printf '%s\n' "$p" | grep -F '主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作' | grep -qF 'どれにも当たらず'
  printf '%s\n' "$p" | grep -qF '親の判断: 子 #N 通した — <理由> <停止の記録の URL>'
  printf '%s\n' "$p" | grep -F '判断が「主に上げる」' | grep -qF '判断できなかった'
  printf '%s\n' "$p" | grep -F '覆して通す' | grep -qF '3 つの理由のどれにも当たらない根拠を 1 文で'
  printf '%s\n' "$p" | grep -F '主に聞く理由が成り立つか迷うときは' | grep -qF '主に上げる'
  # マージ待ちの止まりは照らし直さず、マージ待ちの子の手順に進む
  printf '%s\n' "$p" | grep -F '`PR のマージ待ち（` で始まる' | grep -F '照らし直さず' | grep -qF '**マージ待ちの子**'
  printf '%s\n' "$p" | grep -F '送信だけが失敗' | grep -qF 'reply --as parent'
  printf '%s\n' "$p" | grep -F '`親の判断: 通すが送れなかった` の件' | grep -qF 'reply --as parent'
  printf '%s\n' "$p" | grep -qF '報告は `~/.claude/output-styles/readable.md` の節 3 の型で書き'
  ! printf '%s\n' "$p" | grep -qF '目的 → いま取り組んでいる場所' || return 1
  printf '%s\n' "$p" | grep -qF 'エピックの目的と他の子との関係'
  printf '%s\n' "$p" | grep -qF '子の停止の記録の URL'
  printf '%s\n' "$p" | grep -qF 'どの子の・どの画面で・何をするか'
  printf '%s\n' "$p" | grep -F 'references/reply-after-idle.md' | grep -F 'reply --as owner' | grep -qF -- '--relaunch'
  printf '%s\n' "$p" | grep -qF 'references/parent-pass-criteria.md'
}

# spec: dev-workflow-develop（エピックの子は親から届いた返事を止まった件への返事として受け取る）

@test "skill: an epic child takes a reply from the parent as the answer to its stop" {
  r="$(section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP")"
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
  # 原則: 主に聞く理由の 3 つに当たらない止まりは親が通す
  grep -F '主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作' "$f" | grep -qF '当たらない止まりは親が通す'
  grep -qF '~/.claude/output-styles/readable.md' "$f"
  # 表の 9 行それぞれに確かめる理由の列がある
  grep -qE '^\| 条件 \| 中身 \| 確かめる理由 \|$' "$f"
  for c in '既存の規則が主に聞く止まりでない' '推奨がある' '範囲の内側' '聖域でない' '戻せる' \
    '主の側の情報が要らない' '実機操作でない' '配役表で主の観点が無い' '繰り返していない'; do
    row="$(grep -F "| $c |" "$f")"
    [ "$(printf '%s\n' "$row" | awk -F' \\| ' '{print NF}')" -ge 3 ] || { echo "no reason column: $c"; return 1; }
  done
  grep -F '| 実機操作でない |' "$f" | grep -qF '主の手でしかできない操作'
  grep -F '| 聖域でない |' "$f" | grep -qF '決まりで主の承認が要る'
  grep -F '| 推奨がある |' "$f" | grep -qF '主の側にしか答えが無い'
  grep -F '| 繰り返していない |' "$f" | grep -qF '歯止め'
  # 試しの issue は外部への公開・送信に当たらない
  grep -F '| 聖域でない |' "$f" | grep -F '試しの issue' | grep -qF '外部への公開・送信に当たらない'
  # 通る例の 3 つ
  grep -qF '実機テストのための試しの issue 作成' "$f"
  grep -qF '止まった子の起動し直し' "$f"
  grep -qF 'Mac が空いてからの CI の再実行' "$f"
  # 子の主に聞く理由の読み方
  grep -F '`主に聞く理由:`' "$f" | grep -qF '鵜呑みにしない'
  grep -F '`主に聞く理由: なし（…）`' "$f" | grep -qF '通す側で読む'
  grep -F '項目の無い記録' "$f" | grep -qF 'ほかの項目から'
  grep -F '主に聞く理由が成り立つか迷うときは' "$f" | grep -qF '成り立つ側に倒す'
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
  grep -E '^\| 親 \|' "$f" | grep -qF '120,000'
  grep -E '^\| 親 \|' "$f" | grep -qF '未設定のときだけ'
  grep -E '^\| 親 \|' "$f" | grep -qF 'CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000'
  run grep -F '=100000' "$f"; [ "$status" -eq 1 ]
  run grep -F '100,000' "$f"; [ "$status" -eq 1 ]
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
  put_record 11 status=waiting
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

@test "reply: no record, another parent's record, two records or an unreadable record send nothing" {
  make_stub orca
  set_current 400
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 no-worktree" ]
  put_record 11 parent_worktree=/work/other
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 no-worktree" ]
  put_record 11
  put_record 11 epic=oratta/claude-harness#900
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 ambiguous-worktree" ]
  rm -f "$(rec_of 900 11)"
  printf '{\n' >| "$(rec_of 1122 11)"
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 state-unreadable" ]
  [ "$(calls '^orca terminal')" -eq 0 ]
}

@test "reply: a relaunch writes the new terminal to the record's session" {
  reply_ready
  run dispatch reply --as owner 400 11 'A'
  [ "$status" -eq 0 ]
  [ "$output" = "relaunched 11" ]
  [ "$(rec_get 11 session)" = term-11 ]
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
  put_record 11 status=waiting stop=stopped
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
  put_record 11 status=done
  put_record 13 status=waiting stop=stopped
  put_record 14 status=waiting stop=stopped
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

# 子 11 が completed で閉じ、記録の stop が <stop>（既定 stopped-seen）・
# status が <status>（既定 waiting）で、端末が 1 つある環境
closed_ready() {
  make_stub orca
  set_current 400
  gh_seq 11 "closed completed https://github.com/o/r/issues/11"
  gh_seq comments "$CLOSED_STOP_URL"
  put_record 11 status="${2-waiting}" stop="${1-stopped-seen}"
  set_terms 11 term-a-11
}

# 子に何も送らず、どこにも投稿していない
nothing_sent() {
  [ "$(calls '^orca terminal send')" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(calls '^gh issue comment')" -eq 0 ]
}

@test "notify-closed: a child closed as completed with the stopped mark gets the reply and the epic gets the line" {
  for mark in stopped-seen stopped; do
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
  for mark in "" resumed; do
    : > "$STUB_LOG"; rm -f "$STUB_CFG"/ghcount_*
    closed_ready "$mark"
    run dispatch notify-closed 400 11
    [ "$status" -eq 0 ] || { echo "mark=$mark status=$status output=$output"; false; }
    [ "$output" = "skipped 11 not-stopped" ]
    nothing_sent
  done
}

@test "notify-closed: a child that already marked done gets nothing" {
  closed_ready stopped-seen done
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 already-done" ]
  nothing_sent
}

@test "notify-closed: a child closed as not planned or still open gets nothing and orca is not asked" {
  closed_ready stopped
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
  rm -f "$(rec_of 1122 11)"
  put_record 12 stop=stopped
  put_record 11 stop=stopped parent_worktree=/work/other
  run dispatch notify-closed 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 no-worktree" ]
  nothing_sent
}

@test "notify-closed: two records, an unreadable record or a failing gh is failed" {
  closed_ready
  put_record 11 stop=stopped epic=oratta/claude-harness#900
  run dispatch notify-closed 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 ambiguous-worktree" ]
  nothing_sent

  : > "$STUB_LOG"; rm -f "$STUB_CFG"/ghcount_*
  closed_ready
  rm -f "$(rec_of 900 11)"
  printf '{\n' >| "$(rec_of 1122 11)"
  run dispatch notify-closed 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 state-unreadable" ]
  nothing_sent

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

# spec: dev-workflow-develop（回し方の手順は推定した done も子の付けた done と同じに片付ける）
@test "skill: Orca route steps 2-4 describe the inferred done and reap it like the child's done" {
  r="$(run_section)"
  l2="$(printf '%s\n' "$r" | grep -E '^2\. ')"
  l3="$(printf '%s\n' "$r" | grep -E '^3\. ')"
  l4="$(printf '%s\n' "$r" | grep -E '^4\. ')"
  printf '%s\n' "$l2" | grep -F 'EPIC_DISPATCH_DONE_IDLE_SEC' | grep -F '1800' | grep -qF '推定'
  printf '%s\n' "$l2" | grep -F '`waiting`' | grep -qF '止まった印'
  printf '%s\n' "$l2" | grep -F '閉じてから' | grep -qF 'サブエージェント'
  printf '%s\n' "$l3" | grep -F '推定の `done`' | grep -qF '`reap`'
  printf '%s\n' "$l3" | grep -F '`closed` と `done` の両方' | grep -qF '4 を処理してから'
  printf '%s\n' "$l4" | grep -F '`skipped <N> not-stopped`' | grep -qF '推定'
  printf '%s\n' "$l4" | grep -qF 'ステータスを変えるよう頼まない'
}

# spec: dev-workflow-develop（エピックの子は主にマージを頼むとき、マージ後の連絡を頼まない）
@test "skill: the end of a loop tells an epic child not to ask the owner to report the merge back" {
  e="$(section 'ループの終わり')"
  l="$(printf '%s\n' "$e" | grep -F 'マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける')"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -F '`nested`' | grep -qF 'マージしたら教えてください'
  printf '%s\n' "$l" | grep -qF '推定'
}

# spec: dev-workflow-ci-watch（エピックの子はオーナーにマージを頼むとき、マージ後の連絡を頼まない）
@test "ci-watch: after ready, an epic child asking the owner to merge does not ask for a report back" {
  c="$(awk '/^### `ready` を受けたあと/{f=1; next} /^##/{f=0} f' "$PLUGIN_DIR/references/ci-watch.md")"
  l="$(printf '%s\n' "$c" | grep -F 'マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける')"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -F '`nested`' | grep -qF 'マージしたら教えてください'
  printf '%s\n' "$l" | grep -F -- '--until-merged' | grep -qF '`timeout`'
  printf '%s\n' "$l" | grep -qF 'wait --watch-done'
  grep -F '| `timeout` |' "$PLUGIN_DIR/references/ci-watch.md" | grep -qF 'エピックの子'
  # 1 と 3 の本文からもその段落を指す
  [ "$(printf '%s\n' "$c" | grep -E '^(1|3)\. ' | grep -cF 'エピックの子のセッションの頼む文面は、1〜3 のあとの段落に従う')" -eq 2 ]
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

# --- 同時に動く子の上限（SKILL.md） ---
# spec: dev-workflow-develop（epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める /
# 親は枠が空いたら後回しの子を起動し、サブエージェント方式でも同じ上限を当てる）

# 「回し方」の「**同時に動く子の上限**」の段落
limit_para() { run_section | grep -E '^\*\*同時に動く子の上限\*\*'; }
# 「回し方」の「**サブエージェント方式**」の段落
subagent_para() { run_section | grep -E '^\*\*サブエージェント方式\*\*'; }

@test "skill: the limit paragraph names the variable, the default formula and the measured RSS" {
  p="$(limit_para)"
  [ -n "$p" ]
  printf '%s\n' "$p" | grep -qF '`EPIC_DISPATCH_MAX_PARALLEL`'
  printf '%s\n' "$p" | grep -qF '物理メモリの GiB を 4 で割って切り捨てた値（最小 1。メモリ量を読めなければ 2）'
  printf '%s\n' "$p" | grep -qF '`scripts/epic-dispatch.sh max-parallel`'
  printf '%s\n' "$p" | grep -qF '146〜404 MB'
  printf '%s\n' "$p" | grep -qF '最大 564 MB'
  printf '%s\n' "$p" | grep -qF '1.5 GiB は実測ではない'
}

@test "skill: the limit paragraph does not count done, closed and stopped children, and resumed children can go over on Orca" {
  p="$(limit_para)"
  printf '%s\n' "$p" | grep -qF '完了の印（`done`）の子・閉じた子・主の返事待ちで止まった子を除いたもの'
  printf '%s\n' "$p" | grep -qF '数えると主の返事が遅れるあいだ全体が止まる'
  printf '%s\n' "$p" | grep -qF '戻った子の分だけ一時的に上限を超えうる'
  printf '%s\n' "$p" | grep -qF 'サブエージェント方式では再開を本体が行い、再開の前に空き枠を確かめるので上限を超えない'
}

@test "skill: Orca route steps 1 and 2 explain deferred children and keep them out of wait" {
  r="$(run_section)"
  l1="$(printf '%s\n' "$r" | grep -E '^1\. ')"
  l2="$(printf '%s\n' "$r" | grep -E '^2\. ')"
  printf '%s\n' "$l1" | grep -qF '`deferred <N>`'
  printf '%s\n' "$l1" | grep -qF '`EPIC_DISPATCH_MAX_PARALLEL`'
  printf '%s\n' "$l2" | grep -qF '後回しの子は動いている子にも片付け待ちの子にも入れない'
  printf '%s\n' "$l2" | grep -qF '`wait` の位置引数にも `--watch-done` にも渡さない'
}

@test "skill: Orca route steps 3, 4 and 8 launch the deferred children again" {
  r="$(run_section)"
  for k in 3 8; do
    printf '%s\n' "$r" | grep -E "^$k\\. " | grep -qF '後回しの子が残っていれば、2 に戻る前に依存の解けた開いた子'
  done
  printf '%s\n' "$r" | grep -E '^4\. ' | grep -qF '後回しの子もここに含まれる'
}

@test "skill: Orca route reports to the owner when only deferred children are left" {
  l2="$(run_section | grep -E '^2\. ')"
  printf '%s\n' "$l2" | grep -qF '動いている子も片付け待ちの子も 0 件なのに後回しの子が残るときは、`wait` を呼ばずに主に報告する'
  printf '%s\n' "$l2" | grep -qF '`launch` の stderr の `max parallel'
}

@test "skill: a relaunched parent learns the deferred children from launch, nothing is stored" {
  printf '%s\n' "$(run_section)" | grep -E '^7\. ' | grep -qF '後回しの子の一覧はどこにも保存しない'
}

@test "skill: the subagent route caps the total of W across children with max-parallel" {
  p="$(subagent_para)"
  printf '%s\n' "$p" | grep -qF '`scripts/epic-dispatch.sh max-parallel` を 1 回呼んでその値を上限にし'
  printf '%s\n' "$p" | grep -qF 'エピックの全部の子をまたいで、枠を使っている W の総数をその上限までに抑える'
  printf '%s\n' "$p" | grep -qF '担う change のループが終わる（PR がマージされる・記録先が閉じる）か、主の返事待ちで保留に入るまで 1 枠を使う'
  printf '%s\n' "$p" | grep -qF '新しい子の最初の W を起こす前・同じ子の中で別の change の W を起こす前・保留から戻る W を再開する前に'
  printf '%s\n' "$p" | grep -qF '保留から戻る W の再開 → 同じ子の中の別の change の W → 依存の解けた新しい子の最初の W の順'
}

@test "skill: the subagent route does not resume a W back from hold until a slot frees" {
  p="$(subagent_para)"
  printf '%s\n' "$p" | grep -qF '0 なら起こさず再開もせずに待ちに回す'
  printf '%s\n' "$p" | grep -qF '空き枠が 0 なので A は待ちに回し'
  printf '%s\n' "$p" | grep -qF '本体が `needs-approval` を付けて主の返事を待つ場面（W の停止・G の保留のどちらも）'
  printf '%s\n' "$p" | grep -qF 'コンテキスト上限で手渡した後任の W は前任の枠を引き継ぐ'
}

@test "skill: each W per change inside one child uses its own slot" {
  printf '%s\n' "$(subagent_para)" | grep -qF 'change ごとに W を並列に起こすときは、その W ごとに 1 枠を使う'
  grep -qF '並列可能なら W を並列に起こす（エピックの子のときは `references/epic.md` の「回し方」のサブエージェント方式の枠に従う）' "$SKILL"
}

# --- wait --resolve: 通す返事を起動し直すかを表で決める ---
# spec: dev-workflow-develop（wait --resolve は通す返事を送る前に起動し直すかを表で決める）

# 子 11 のトランスクリプトを置く（<何分前の最後のリクエスト> <会話量> [compact 1] [ファイル名]）
put_transcript() {
  local ago="$1" ctx="$2" compact="${3-0}" name="${4-s1}"
  local p="$BATS_TEST_TMPDIR/work/issue-11" dir ts
  dir="$BATS_TEST_TMPDIR/projects/$(printf '%s' "$p" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$dir"
  ts="$(python3 -c "import datetime,sys;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=$ago)).strftime('%Y-%m-%dT%H:%M:%S.000Z'))")"
  {
    printf '{"type":"assistant","timestamp":"%s","message":{"usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' "$ts" "$ctx"
    [ "$compact" = 1 ] && printf '{"type":"system","subtype":"compact_boundary","timestamp":"%s"}\n' "$ts"
  } > "$dir/$name.jsonl"
  export CLAUDE_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
}

resolve_pass() {
  resolve_ready
  judge_says judge_out 通す 範囲の内側 推奨どおり進めてよい
  # 子の判断の既定の subagent-context.sh は plugin のものを使う
}

@test "wait --resolve relaunch: 60+ minutes, no compaction, N >= 150000 relaunches the child" {
  resolve_pass
  put_transcript 90 160000
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$(calls '^orca terminal create')" -eq 1 ]
  [ "$(calls '^orca terminal send')" -ge 1 ]
  starts_with "$(cat "$STUB_CFG/sent_term-11")" "/develop #11 "
  [ "$(head -1 "$STUB_CFG/comment_400")" = "親の判断: 子 #11 通した — 範囲の内側 $STOP_URL" ]
}

@test "wait --resolve relaunch: under 60 minutes sends as is" {
  resolve_pass
  put_transcript 30 160000
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ "$(cat "$STUB_CFG/sent_term-a-11")" = "親エピック #400 の判断（主の承認ではない）: 推奨どおり進めてよい" ]
}

@test "wait --resolve relaunch: compaction during the wait or N under 150000 sends as is" {
  resolve_pass
  put_transcript 90 160000 1
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  resolve_pass
  put_transcript 90 100000
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
}

@test "wait --resolve relaunch: no transcript or two transcripts sends as is" {
  resolve_pass
  export CLAUDE_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  [ -e "$STUB_CFG/sent_term-a-11" ]
  resolve_pass
  put_transcript 90 160000 0 s1
  put_transcript 90 160000 0 s2
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
}

@test "wait --resolve relaunch: thresholds can be overridden and bad values are refused" {
  resolve_pass
  put_transcript 30 160000
  EPIC_DISPATCH_RELAUNCH_IDLE_SEC=60 run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 1 ]
  resolve_pass
  : > "$STUB_LOG"
  put_transcript 90 160000
  EPIC_DISPATCH_RELAUNCH_MIN_TOKENS=200000 run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  for v in EPIC_DISPATCH_RELAUNCH_IDLE_SEC EPIC_DISPATCH_RELAUNCH_MIN_TOKENS; do
    resolve_pass
    : > "$STUB_LOG"
    export "$v=150k"
    run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
    unset "$v"
    [ "$status" -eq 1 ]
    grep -qF "$v" "$BATS_TEST_TMPDIR/stderr"
    grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
    [ "$(calls '^orca terminal')" -eq 0 ]
  done
}

# --- pending-owner ---
# spec: dev-workflow-develop（起動し直した親は主の返事待ちの子を主に出し直す）

@test "pending-owner: only a child whose record is still stopped-seen is pending, and nothing is written" {
  make_stub orca
  set_current 400
  put_record 11 stop=stopped-seen
  put_record 12 stop=resumed
  put_record 13 stop=stopped
  put_record 14 stop=stopped-seen parent_worktree=/work/other
  put_record 15 stop=stopped-seen
  printf '{\n' >| "$(rec_of 1122 15)"
  put_record 16 stop=stopped-seen
  put_record 16 stop=stopped-seen epic=oratta/claude-harness#900
  before="$(cd "$EPIC_STATE_ROOT" && find . | sort && cat ./*/*.json)"
  run dispatch pending-owner 11 12 13 14 15 16 17
  [ "$status" -eq 0 ]
  [ "$output" = "pending 11" ]
  [ "$(calls '^orca ')" -eq 0 ]
  [ "$(cd "$EPIC_STATE_ROOT" && find . | sort && cat ./*/*.json)" = "$before" ]
}

@test "pending-owner: an Orca stopped-seen mark alone is not pending" {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 in-review repo-a::/work/parent repo-a false epic-stopped-seen)"
  put_record 11
  run dispatch pending-owner 11
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pending-owner: no children or no worktree is an error" {
  make_stub orca
  run dispatch pending-owner
  [ "$status" -eq 1 ]
  put_record 11 stop=stopped-seen
  : >| "$STUB_CFG/toplevel"
  run dispatch pending-owner 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "skill: Orca route steps 3 and 4 relaunch the deferred children with the same --note" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -E '^3\. ' | grep -qF '依存の解けた開いた子を、最初に渡したときと同じ `--note` を付けて `launch` に渡し直す'
  printf '%s\n' "$r" | grep -E '^4\. ' | grep -qF '後回しの子には最初に渡したときと同じ `--note` を付ける'
}

@test "skill: Orca route step 4 relaunches the deferred children after a close other than completed too" {
  printf '%s\n' "$(run_section)" | grep -E '^4\. ' | grep -qF '見送りの子を前提にしていた子を除いて、依存の解けた開いた子を `launch` に渡し直す'
}

@test "skill: Orca route steps 3, 4 and 7 report when only deferred children are left" {
  r="$(run_section)"
  for k in 3 4 7; do
    printf '%s\n' "$r" | grep -E "^$k\\. " | grep -qF '後回しの子だけが残るときは 2 の報告'
  done
}

@test "skill: Orca route step 2 leaves deferred children out of the done-watch set by definition" {
  printf '%s\n' "$(run_section)" | grep -E '^2\. ' | grep -qF '片付け待ちの子は、`launch` に渡して `deferred` 以外を返したことのある子（閉じた子を含む）から'
}

@test "skill: the limit paragraph says Linux MemTotal can give one step lower" {
  printf '%s\n' "$(limit_para)" | grep -qF 'Linux の `MemTotal` は物理メモリより少し小さく報告されるので、4 の倍数ちょうどの機では 1 段下がる（16 GiB 機で 3）'
}

@test "skill: the subagent route stops on a bad max-parallel setting" {
  printf '%s\n' "$(subagent_para)" | grep -qF '（exit 1 なら stderr を添えて設定の誤りとして報告して止まる。手順 6 と同じ）'
}

# --- adopt ---
# spec: dev-workflow-epic-state（adopt は記録の無い Orca の子を記録に取り込む）

@test "adopt: a stopped-seen Orca child of this parent becomes a record" {
  make_stub orca
  set_current 1122
  set_list list_json "$(wt_entry 11 '' 'repo-a::/work/parent' repo-a false epic-stopped-seen)"
  run dispatch adopt 1122 11
  [ "$status" -eq 0 ]
  [ "$output" = "adopted 11" ]
  [ "$(rec_get 11 stop)" = stopped-seen ]
  [ "$(rec_get 11 status)" = running ]
  [ "$(rec_get 11 worktree)" = "$BATS_TEST_TMPDIR/work/issue-11" ]
  [ "$(rec_get 11 branch)" = oratta/issue-11 ]
  [ "$(rec_get 11 parent_worktree)" = /work/parent ]
  [ "$(rec_get 11 launcher)" = orca ]
  [ "$(rec_get 11 base)" = main ]
  [ "$(rec_get 11 session)" = "" ]
  [ "$(rec_get 11 launch_failed)" = "" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "adopt: the board column and comment map to status and stop, EPIC_DISPATCH_BASE sets base" {
  make_stub orca
  set_current 1122
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 12 in-review 'repo-a::/work/parent' repo-a false epic-stopped)" \
    "$(wt_entry 13 '' 'repo-a::/work/parent' repo-a false epic-resumed)"
  EPIC_DISPATCH_BASE=develop run dispatch adopt 1122 11 12 13
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'adopted 11\nadopted 12\nadopted 13')" ]
  [ "$(rec_get 11 status)/$(rec_get 11 stop)" = done/ ]
  [ "$(rec_get 12 status)/$(rec_get 12 stop)" = waiting/stopped ]
  [ "$(rec_get 13 status)/$(rec_get 13 stop)" = running/resumed ]
  [ "$(rec_get 11 base)" = develop ]
}

@test "adopt: a child with a record is skipped and the record is unchanged" {
  make_stub orca
  set_current 1122
  put_record 11 stop=stopped
  set_list list_json "$(wt_entry 11 completed)"
  before="$(cat "$(rec_of 1122 11)")"
  run dispatch adopt 1122 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11" ]
  [ "$(cat "$(rec_of 1122 11)")" = "$before" ]
}

@test "max-parallel: an empty EPIC_STATE_ROOT does not stop it, which reads no record" {
  make_stub orca
  EPIC_STATE_ROOT= run dispatch max-parallel
  [ "$status" -eq 0 ]
  [ "$output" = 99 ]
}

@test "adopt: an unreadable record is failed state-unreadable and left as is" {
  make_stub orca
  set_current 1122
  set_list list_json "$(wt_entry 11 completed)"
  mkdir -p "$(dirname "$(rec_of 1122 11)")"
  printf '{\n' > "$(rec_of 1122 11)"
  run dispatch adopt 1122 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11 state-unreadable" ]
  [ "$(cat "$(rec_of 1122 11)")" = "{" ]
  grep -qF "$(rec_of 1122 11)" "$BATS_TEST_TMPDIR/stderr"
}

@test "adopt: another repoId is none and without jq it prints nothing and exits 1" {
  make_stub orca
  set_current 1122
  set_list list_json "$(wt_entry 15 '' 'repo-a::/work/parent' repo-b)"
  run dispatch adopt 1122 15
  [ "$status" -eq 0 ]
  [ "$output" = "none 15" ]
  run dispatch_nojq adopt 1122 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "adopt: no match, another parent and archived worktrees are none, two matches are failed ambiguous" {
  make_stub orca
  set_current 1122
  set_list list_json "$(wt_entry 12 '' 'repo-a::/work/other')" "$(wt_entry 13 '' 'repo-a::/work/parent' repo-a true)" \
    "$(wt_entry 14)" "$(wt_entry 14)"
  run dispatch adopt 1122 11 12 13 14
  [ "$status" -eq 1 ]
  [ "$output" = "$(printf 'none 11\nnone 12\nnone 13\nfailed 14 ambiguous')" ]
  [ ! -e "$EPIC_STATE_ROOT/oratta.claude-harness-1122" ]
}

@test "adopt: without orca, outside Orca, an unreadable list or an unreadable origin prints nothing and exits 1" {
  run dispatch adopt 1122 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  make_stub orca
  set_list list_json "$(wt_entry 11)"
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch adopt 1122 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  rm "$STUB_CFG/current_exit"
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch adopt 1122 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  rm "$STUB_CFG/list_exit"
  echo https://gitlab.com/oratta/claude-harness > "$STUB_CFG/origin_url"
  run dispatch adopt 1122 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -q 'cannot read the epic repository from origin' "$BATS_TEST_TMPDIR/stderr"
  [ ! -e "$EPIC_STATE_ROOT" ] || [ -z "$(find "$EPIC_STATE_ROOT" -type f)" ]
}

@test "adopt: a non-numeric epic or a bad child prints the usage" {
  make_stub orca
  run dispatch adopt x 11
  [ "$status" -eq 1 ]
  grep -q 'usage:' "$BATS_TEST_TMPDIR/stderr"
  run dispatch adopt 1122 '#11'
  [ "$status" -eq 1 ]
  grep -q 'usage:' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca')" -eq 0 ]
}

# --- clear ---
# spec: dev-workflow-epic-state（記録は片付けた子ごとに消し、エピックの完了時にディレクトリごと消す）

@test "clear: the state directory is removed, remaining children go to stderr, other epics stay" {
  put_record 11
  put_record 12 epic=oratta/claude-harness#900
  run dispatch clear 1122
  [ "$status" -eq 0 ]
  [ "$output" = "cleared 1122" ]
  [ ! -e "$EPIC_STATE_ROOT/oratta.claude-harness-1122" ]
  [ -f "$(rec_of 900 12)" ]
  grep -q 'oratta/claude-harness#11' "$BATS_TEST_TMPDIR/stderr"
}

@test "clear: a missing directory is none" {
  run dispatch clear 1122
  [ "$status" -eq 0 ]
  [ "$output" = "none 1122" ]
}

@test "clear: a non-numeric epic and an empty EPIC_STATE_ROOT remove nothing" {
  put_record 11
  run dispatch clear ../1122
  [ "$status" -eq 1 ]
  [ -f "$(rec_of 1122 11)" ]
  EPIC_STATE_ROOT= run dispatch clear 1122
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -f "$(rec_of 1122 11)" ]
}

@test "clear: a relative EPIC_STATE_ROOT is resolved from the working directory" {
  mkdir -p "$BATS_TEST_TMPDIR/cwd/state/oratta.claude-harness-1122"
  touch "$BATS_TEST_TMPDIR/cwd/state/oratta.claude-harness-1122/oratta.claude-harness-11.json"
  cd "$BATS_TEST_TMPDIR/cwd"
  EPIC_STATE_ROOT=state run dispatch clear 1122
  [ "$status" -eq 0 ]
  [ "$output" = "cleared 1122" ]
  [ ! -e "$BATS_TEST_TMPDIR/cwd/state/oratta.claude-harness-1122" ]
  [ -d "$BATS_TEST_TMPDIR/cwd/state" ]
}

@test "clear: EPIC_STATE_ROOT of / or the home directory itself removes nothing" {
  EPIC_STATE_ROOT=/ run dispatch clear 1122
  [ "$status" -eq 1 ]
  grep -q 'refusing to clear' "$BATS_TEST_TMPDIR/stderr"
  [ -z "$output" ]
  mkdir -p "$BATS_TEST_TMPDIR/home/oratta.claude-harness-1122"
  HOME="$BATS_TEST_TMPDIR/home" EPIC_STATE_ROOT="$BATS_TEST_TMPDIR/home/" run dispatch clear 1122
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -d "$BATS_TEST_TMPDIR/home/oratta.claude-harness-1122" ]
}

@test "clear: a symbolic link is not followed" {
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere" "$EPIC_STATE_ROOT"
  touch "$BATS_TEST_TMPDIR/elsewhere/keep.json"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$EPIC_STATE_ROOT/oratta.claude-harness-1122"
  run dispatch clear 1122
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -L "$EPIC_STATE_ROOT/oratta.claude-harness-1122" ]
  [ -f "$BATS_TEST_TMPDIR/elsewhere/keep.json" ]
}

@test "clear: an origin that is not GitHub removes nothing" {
  put_record 11
  echo git@gitlab.com:oratta/claude-harness.git > "$STUB_CFG/origin_url"
  run dispatch clear 1122
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -f "$(rec_of 1122 11)" ]
}

# --- skill: 状態の記録（adopt・clear・Orca の印は写し） ---
# spec: dev-workflow-develop（SKILL.md の回し方は再開時に adopt を呼び、待ちを終えるときに clear を呼ぶ）

@test "skill: step 7 calls adopt before reap, pending-owner and launch, and separates ambiguous from an empty exit 1" {
  p="$(run_section | grep -E '^7\. `回し方: Orca`')"
  a="${p%%epic-dispatch.sh adopt*}"
  [ "$a" != "$p" ]
  case "$a" in *'`reap`'*|*pending-owner*|*'`launch` を'*) false ;; esac
  printf '%s\n' "$p" | grep -qF '`failed <N> ambiguous` は主に聞かずにその子を残して進み'
  printf '%s\n' "$p" | grep -qF '子 #N の記録を取り込めなかった（ambiguous）'
  printf '%s\n' "$p" | grep -qF '`adopt` が stdout に何も出さず exit 1 で終わったら'
  printf '%s\n' "$p" | grep -qF '`failed <N> ambiguous` の行を出して exit 1 で終わったときは止まらない'
}

@test "skill: every place of steps 3, 4 and 7 that ends the wait without wait calls clear first" {
  n="$(run_section | grep -oF '`wait` を呼ばずに待ちを終える' | grep -c .)"
  [ "$n" -ge 3 ]
  m="$(run_section | grep -oF 'clear <エピック番号>` を 1 回呼んでから（エピックの状態ディレクトリを消す。`cleared`・`none` は何もせず、exit 1 は stderr を添えて主に報告する。エピックを閉じるのは待たない）`wait` を呼ばずに待ちを終える' | grep -c .)"
  [ "$m" -eq "$n" ]
  for s in 3 4 7; do
    run_section | grep -E "^$s\. " | grep -qF 'epic-dispatch.sh clear <エピック番号>' || { echo "step $s" >&2; false; }
  done
}

@test "skill: the Orca marks are a copy of the state records and hand edits do not reach the parent" {
  p="$(run_section | grep -E '^\*\*子の状態の正本\*\*')"
  printf '%s\n' "$p" | grep -qF 'Orca のボードの列とコメント欄は、記録を書いたあとに写したもの'
  printf '%s\n' "$p" | grep -qF 'Orca の画面で印を手で変えても、親の見張り'
  section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP" | grep -F -- '- **印**' | grep -qF 'Orca の画面には写しが出る'
}

@test "skill: step 3 no longer names not-child and keeps state-unreadable without checking" {
  p="$(run_section | grep -E '^3\. ')"
  [ -n "$p" ]
  case "$p" in *not-child*) false ;; esac
  printf '%s\n' "$p" | grep -qF '子 #N のワークツリーを残した（state-unreadable）'
}

@test "skill: step 6 reports an empty exit 1 of launch and adopt, not of wait" {
  p="$(run_section | grep -E '^6\. ')"
  printf '%s\n' "$p" | grep -qF '`adopt` が stdout に何も出さず exit 1 で終わったとき'
  case "$p" in *'`--watch-done` か `--watch-stopped` を付けた `wait` が stdout に何も出さず'*) false ;; esac
}

@test "skill: the completion check confirms the state directory is cleared" {
  section 'エピックの扱い' "$EPIC" | awk '/^### 完了条件/{f=1; next} /^### /{f=0} f' | grep -qF '`clear` で消えていることを確かめる'
}

# ---- launch: エピックと別のリポジトリの子（cross-repo-children） ----

# 別のリポジトリ genetta-inc/flatmate の clone を置く（<clone の名前> [origin の URL]）。clone の origin を返すようにする
xclone() {
  local d="$BATS_TEST_TMPDIR/$1" url="${2-git@github.com:genetta-inc/flatmate.git}"
  mkdir -p "$d"
  printf '%s\n' "$url" > "$STUB_CFG/origin_for_$(printf '%s' "$d" | tr / _)"
  printf '%s' "$d"
}

# Orca のリポジトリ一覧を置く（引数は <id>=<path>）
set_repos() {
  local out="" kv
  for kv in "$@"; do out="$out${out:+,}{\"id\":\"${kv%%=*}\",\"path\":\"${kv#*=}\"}"; done
  printf '{"result":{"repos":[%s]}}\n' "$out" > "$STUB_CFG/repo_list_json"
}

# 子のリポジトリの gh api repos/<o>/<r> の応答（<push true|false> [default_branch]）
set_repoinfo() {
  if [ -n "${2-}" ]; then
    printf '{"permissions":{"push":%s},"default_branch":"%s"}\n' "$1" "$2" > "$STUB_CFG/repoinfo_genetta-inc_flatmate"
  else
    printf '{"permissions":{"push":%s}}\n' "$1" > "$STUB_CFG/repoinfo_genetta-inc_flatmate"
  fi
}

# 作られなかったことの確認（記録・create）
xnothing_made() {
  [ "$(calls '^orca worktree create ')" -eq 0 ]
  [ ! -e "$(rec_of 1122 genetta-inc/flatmate#1615)" ]
}

@test "launch: a child in another repository is made in the clone from EPIC_DISPATCH_CLONES" {
  make_stub orca
  c="$(xclone flat)"
  set_repos "repo-b=$c"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ]
  [ "$output" = "launched genetta-inc/flatmate#1615" ]
  grep -qF -- "orca worktree create --repo id:repo-b --name issue-1615 --issue 1615 --base-branch origin/main --parent-worktree path:/work/parent --json" "$STUB_LOG"
  [ "$(rec_get genetta-inc/flatmate#1615 repo)" = genetta-inc/flatmate ]
  [ "$(rec_get genetta-inc/flatmate#1615 child)" = genetta-inc/flatmate#1615 ]
  [ "$(rec_get genetta-inc/flatmate#1615 number)" = 1615 ]
  [ "$(rec_get genetta-inc/flatmate#1615 base)" = main ]
  [ "$(rec_get genetta-inc/flatmate#1615 parent_worktree)" = /work/parent ]
  [ "$(rec_get genetta-inc/flatmate#1615 worktree)" = /work/issue-1615 ]
  grep -qF -- "git -C $c fetch origin main" "$STUB_LOG"
}

@test "launch: a clone registered in Orca is found when EPIC_DISPATCH_CLONES is empty" {
  make_stub orca
  c="$(xclone flat)"; o="$(xclone other git@github.com:someone/other.git)"
  set_repos "repo-o=$o" "repo-b=$c"
  run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ]
  [ "$output" = "launched genetta-inc/flatmate#1615" ]
  grep -qF -- "orca worktree create --repo id:repo-b " "$STUB_LOG"
}

@test "launch: EPIC_DISPATCH_CLONES wins over Orca, and an item whose path is not absolute is ignored with a message" {
  make_stub orca
  c="$(xclone flat)"; c2="$(xclone flat2)"
  set_repos "repo-b=$c" "repo-c=$c2"
  EPIC_DISPATCH_CLONES="Genetta-Inc/Flatmate=$c2;genetta-inc/flatmate=relative/path" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ]
  grep -qF -- "orca worktree create --repo id:repo-c " "$STUB_LOG"
  grep -qF 'not absolute' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: no clone found is failed no-clone with the way to tell where it is, and nothing is made" {
  make_stub orca
  run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615 no-clone" ]
  grep -qF "EPIC_DISPATCH_CLONES='genetta-inc/flatmate=" "$BATS_TEST_TMPDIR/stderr"
  grep -qF "git clone git@github.com:genetta-inc/flatmate.git" "$BATS_TEST_TMPDIR/stderr"
  xnothing_made
}

@test "launch: a clone whose origin is another repository is not used" {
  make_stub orca
  c="$(xclone flat git@github.com:someone/fork.git)"
  set_repos "repo-b=$c"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615 no-clone" ]
  xnothing_made
}

@test "launch: two clones in the same stage are failed ambiguous-clone with the candidates" {
  make_stub orca
  c="$(xclone flat)"; c2="$(xclone flat2 https://github.com/genetta-inc/flatmate)"
  set_repos "repo-b=$c" "repo-c=$c2"
  run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615 ambiguous-clone" ]
  grep -qF "$c" "$BATS_TEST_TMPDIR/stderr"
  grep -qF "$c2" "$BATS_TEST_TMPDIR/stderr"
  xnothing_made
}

@test "launch: an already launched child in another repository is skipped without looking for a clone" {
  make_stub orca
  put_record 1615 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1615
  run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ]
  [ "$output" = "skipped genetta-inc/flatmate#1615" ]
  [ "$(calls '^git -C ')" -eq 0 ]
  [ "$(calls '^orca repo list')" -eq 0 ]
  [ "$(calls '^gh api repos/genetta-inc/flatmate$')" -eq 0 ]
}

@test "launch: a clone Orca does not know is failed not-in-orca without a record or a slot" {
  make_stub orca
  c="$(xclone flat)"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615 not-in-orca" ]
  grep -qF 'orca repo add' "$BATS_TEST_TMPDIR/stderr"
  xnothing_made
}

@test "launch: no push permission is failed no-push before anything is made" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"; set_repoinfo false develop
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615 no-push" ]
  grep -qF 'genetta-inc/flatmate' "$BATS_TEST_TMPDIR/stderr"
  grep -qF 'stub-user' "$BATS_TEST_TMPDIR/stderr"
  xnothing_made
}

@test "launch: an unreadable permission is failed permission-lookup-failed" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  echo 1 > "$STUB_CFG/repoinfo_exit"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615 permission-lookup-failed" ]
  xnothing_made
}

@test "launch: a response without permissions is permission-lookup-failed, not base-lookup-failed" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  echo '{"default_branch":"develop"}' > "$STUB_CFG/repoinfo_genetta-inc_flatmate"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$output" = "failed genetta-inc/flatmate#1615 permission-lookup-failed" ]
}

@test "launch: no default_branch in the response is failed base-lookup-failed without a record or a slot" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"; set_repoinfo true
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615 base-lookup-failed" ]
  xnothing_made
}

@test "launch: --base does not hide a missing default_branch (base-lookup-failed)" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"; set_repoinfo true
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch --base staging 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615 base-lookup-failed" ]
  xnothing_made
}

@test "launch: the base is the default branch of the child's repository, or --base" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"; set_repoinfo true develop
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$output" = "launched genetta-inc/flatmate#1615" ]
  grep -qF -- "git -C $c fetch origin develop" "$STUB_LOG"
  grep -qF -- "--base-branch origin/develop " "$STUB_LOG"
  [ "$(rec_get genetta-inc/flatmate#1615 base)" = develop ]
  rm -f "$(rec_of 1122 genetta-inc/flatmate#1615)"
  : > "$STUB_LOG"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch --base staging 1122 genetta-inc/flatmate#1615
  [ "$output" = "launched genetta-inc/flatmate#1615" ]
  grep -qF -- "--base-branch origin/staging " "$STUB_LOG"
  [ "$(rec_get genetta-inc/flatmate#1615 base)" = staging ]
}

@test "launch: a failing fetch in the child's clone removes the record and does not create" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  echo 1 > "$STUB_CFG/cfetch_exit"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 1 ]
  [ "$output" = "failed genetta-inc/flatmate#1615" ]
  xnothing_made
}

@test "launch: only children in another repository do not fetch the parent's clone but still bind the epic" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch --base develop 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ]
  [ "$(calls '^git fetch origin')" -eq 0 ]
  [ "$(calls '^orca worktree set --worktree path:/work/parent --issue 1122')" -eq 1 ]
}

@test "launch: a same-repository child reads no permission and still fetches the parent's clone" {
  make_stub orca
  run dispatch launch 1122 11
  [ "$output" = "launched 11" ]
  [ "$(calls '^gh api repos/[^/]*/[^/]*$')" -eq 0 ]
  [ "$(calls '^git fetch origin main')" -eq 1 ]
}

@test "launch: a child in another repository takes a slot and is deferred when none is free" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch 1122 genetta-inc/flatmate#1615 genetta-inc/flatmate#1616
  [ "$output" = "$(printf 'launched genetta-inc/flatmate#1615\ndeferred genetta-inc/flatmate#1616')" ]
  [ "$(calls '^orca worktree create ')" -eq 1 ]
  [ "$(calls '^gh api repos/genetta-inc/flatmate$')" -eq 1 ]
}

@test "launch: a record with an empty worktree in another repository is overwritten without a second slot" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  put_record 1615 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1615 worktree=
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" EPIC_DISPATCH_MAX_PARALLEL=1 run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$output" = "launched genetta-inc/flatmate#1615" ]
  [ "$(rec_get genetta-inc/flatmate#1615 worktree)" = /work/issue-1615 ]
}

@test "launch: an Orca worktree of the child's repository for the same issue is skipped" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  set_list list_json "$(wt_entry 1615 in-progress 'repo-a::/work/parent' repo-b)"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$output" = "skipped genetta-inc/flatmate#1615" ]
  [ "$(calls '^orca worktree create ')" -eq 0 ]
}

@test "launch: a child in another repository gets the epic repository in the command, the first input and the note" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch --note 範囲を守る 1122 genetta-inc/flatmate#1615
  [ "$output" = "launched genetta-inc/flatmate#1615" ]
  case "$(cat "$STUB_CFG/tcmd_1615")" in "EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 "*) ;; *) false ;; esac
  case "$(cat "$STUB_CFG/sent_term-1615")" in "/develop #1615 （エピック #1122 の子。エピックのリポジトリ oratta/claude-harness。"*) ;; *) false ;; esac
  grep -qF -- "gh issue comment 1615 -R genetta-inc/flatmate --body" "$STUB_LOG"
  case "$(cat "$STUB_CFG/comment_1615")" in "親エピックからの注意書き: oratta/claude-harness#1122"*) ;; *) false ;; esac
}

@test "launch: a failing note for a child in another repository prints a repost command with -R" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  echo 1 > "$STUB_CFG/comment_exit_1615"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch --note メモ 1122 genetta-inc/flatmate#1615
  [ "$output" = "launched genetta-inc/flatmate#1615" ]
  grep -qF "gh issue comment 1615 -R genetta-inc/flatmate --body" "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: a same-repository child keeps the old command, first input and note" {
  make_stub orca
  run dispatch launch --note 範囲を守る 1122 11
  [ "$output" = "launched 11" ]
  case "$(cat "$STUB_CFG/tcmd_11")" in "EPIC_DISPATCH_PARENT_EPIC=1122 "*) ;; *) false ;; esac
  case "$(cat "$STUB_CFG/sent_term-11")" in "/develop #11 （エピック #1122 の子。親ワークツリー"*) ;; *) false ;; esac
  grep -qF -- "gh issue comment 11 --body" "$STUB_LOG"
  case "$(cat "$STUB_CFG/comment_11")" in "親エピックからの注意書き: #1122"*) ;; *) false ;; esac
}

@test "launch: two repositories whose names differ only in / and - each use their own clone and Orca repository" {
  make_stub orca
  c1="$(xclone abc1 git@github.com:a/b-c.git)"; c2="$(xclone abc2 git@github.com:a-b/c.git)"
  set_repos "repo-1=$c1" "repo-2=$c2"
  EPIC_DISPATCH_CLONES="a/b-c=$c1;a-b/c=$c2" run dispatch launch 1122 a/b-c#1615 a-b/c#1616
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; false; }
  [ "$output" = "$(printf 'launched a/b-c#1615\nlaunched a-b/c#1616')" ]
  grep -qF -- "orca worktree create --repo id:repo-1 --name issue-1615 " "$STUB_LOG"
  grep -qF -- "orca worktree create --repo id:repo-2 --name issue-1616 " "$STUB_LOG"
  grep -qF -- "git -C $c2 fetch origin main" "$STUB_LOG"
  grep -qF -- "gh api repos/a-b/c" "$STUB_LOG"
}

@test "launch: a same-repository child after a child in another repository gets the epic number alone in the command" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; false; }
  case "$(cat "$STUB_CFG/tcmd_1615")" in "EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 "*) ;; *) false ;; esac
  case "$(cat "$STUB_CFG/tcmd_11")" in "EPIC_DISPATCH_PARENT_EPIC=1122 "*) ;; *) cat "$STUB_CFG/tcmd_11"; false ;; esac
}

@test "launch: a record for another repository never makes launch print other-repo" {
  make_stub orca
  c="$(xclone flat)"; set_repos "repo-b=$c"
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  case "$output" in *other-repo*) false ;; *) true ;; esac
}

@test "reply: a child in another repository gets the epic repository in the header" {
  make_stub orca
  set_current 1122
  put_record 1615 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1615
  set_terms 1615 term-x-1615
  run dispatch reply --as parent 1122 genetta-inc/flatmate#1615 続けてよい
  [ "$output" = "sent genetta-inc/flatmate#1615" ]
  [ "$(cat "$STUB_CFG/sent_term-x-1615")" = "親エピック #1122（oratta/claude-harness）の判断（主の承認ではない）: 続けてよい" ]
  run dispatch reply --as owner 1122 genetta-inc/flatmate#1615 'A で'
  [ "$(cat "$STUB_CFG/sent_term-x-1615")" = "主の返事（親エピック #1122（oratta/claude-harness）経由）: A で" ]
}

@test "reply --relaunch: a child in another repository is started with the epic repository" {
  make_stub orca
  set_current 1122
  put_record 1615 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1615
  run dispatch reply --relaunch --as parent 1122 genetta-inc/flatmate#1615 続けてよい
  [ "$output" = "relaunched genetta-inc/flatmate#1615" ]
  case "$(cat "$STUB_CFG/tcmd_1615")" in "EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 "*) ;; *) false ;; esac
  case "$(cat "$STUB_CFG/sent_term-1615")" in "/develop #1615 （エピック #1122 の子。エピックのリポジトリ oratta/claude-harness。"*) ;; *) false ;; esac
}

@test "reply: a same-repository child keeps the old header" {
  reply_ready term-a-11
  run dispatch reply --as parent 400 11 続けてよい
  [ "$(cat "$STUB_CFG/sent_term-a-11")" = "親エピック #400 の判断（主の承認ではない）: 続けてよい" ]
}

# ---- reap: エピックと別のリポジトリの子（cross-repo-children） ----

# 別のリポジトリの子 1615 の完了済みの記録（base は develop）。PR の無い子にするときは $1 に prless
xreap_ready() {
  make_stub orca
  put_record 1615 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1615 status=done base=develop
  if [ "${1-}" = prless ]; then
    : > "$STUB_CFG/pr_out"
    gh_seq 1615 closed
  else
    echo aaa111 > "$STUB_CFG/pr_out"
  fi
}

@test "reap: a child in another repository asks gh -R for its merged PR and drops the branch in the child's clone" {
  xreap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo /clone/flat/.git > "$STUB_CFG/commondir_out"
  run dispatch reap genetta-inc/flatmate#1615
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "reaped genetta-inc/flatmate#1615" ]
  grep -qF -- 'gh pr list -R genetta-inc/flatmate --head oratta/issue-1615 --state merged --json headRefOid' "$STUB_LOG"
  p="$BATS_TEST_TMPDIR/work/issue-1615"
  grep -qF -- "git -C $p rev-parse --path-format=absolute --git-common-dir" "$STUB_LOG"
  grep -qF -- 'git -C /clone/flat/.git branch -D oratta/issue-1615' "$STUB_LOG"
  [ "$(calls '^git branch -D')" -eq 0 ]
  rm_line="$(first_line "^orca worktree rm --worktree path:$p\$")"
  cd_line="$(first_line 'rev-parse --path-format=absolute --git-common-dir')"
  [ -n "$rm_line" ] && [ -n "$cd_line" ] && [ "$cd_line" -lt "$rm_line" ]
}

@test "reap: a PR-less child in another repository reads the base of its own clone with git -C and the recorded base" {
  xreap_ready prless
  run dispatch reap genetta-inc/flatmate#1615
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "reaped genetta-inc/flatmate#1615" ]
  p="$BATS_TEST_TMPDIR/work/issue-1615"
  grep -qF -- 'gh pr list -R genetta-inc/flatmate --head oratta/issue-1615 --state all --json number' "$STUB_LOG"
  grep -qF -- 'gh pr list -R genetta-inc/flatmate --state merged --search aaa111' "$STUB_LOG"
  grep -qF -- "git -C $p ls-remote origin refs/heads/develop" "$STUB_LOG"
  grep -qF -- "git -C $p cat-file -e" "$STUB_LOG"
  [ "$(calls '^git ls-remote')" -eq 0 ]
  [ "$(calls '^git cat-file')" -eq 0 ]
}

@test "reap: a missing base tip is fetched in the child's worktree, not in the parent's clone" {
  xreap_ready prless
  echo 1 > "$STUB_CFG/catfile_exit_1"
  run dispatch reap genetta-inc/flatmate#1615
  [ "$output" = "reaped genetta-inc/flatmate#1615" ]
  p="$BATS_TEST_TMPDIR/work/issue-1615"
  grep -qF -- "git -C $p fetch origin develop" "$STUB_LOG"
  [ "$(calls '^git fetch')" -eq 0 ]
}

@test "reap: children of both repositories mixed keep their own base, -R and tip" {
  reap_prless_ready
  put_record 1615 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1615 status=done base=develop
  gh_seq 1615 closed
  run dispatch reap 11 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; false; }
  [ "$output" = "$(printf 'reaped 11\nreaped genetta-inc/flatmate#1615')" ]
  grep -qF -- 'git ls-remote origin refs/heads/main' "$STUB_LOG"
  grep -qF -- 'ls-remote origin refs/heads/develop' "$STUB_LOG"
  [ "$(calls 'ls-remote')" -eq 2 ]
  grep -qF -- 'gh pr list --head oratta/issue-11 --state merged' "$STUB_LOG"
  grep -qF -- 'gh pr list -R genetta-inc/flatmate --head oratta/issue-1615 --state merged' "$STUB_LOG"
}

@test "reap: two children of the other repository with different bases read each base once" {
  xreap_ready prless
  put_record 1616 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1616 status=done base=develop
  put_record 1617 repo=genetta-inc/flatmate child=genetta-inc/flatmate#1617 status=done base=staging
  gh_seq 1616 closed; gh_seq 1617 closed
  run dispatch reap genetta-inc/flatmate#1615 genetta-inc/flatmate#1616 genetta-inc/flatmate#1617
  [ "$status" -eq 0 ]
  [ "$(calls 'ls-remote origin refs/heads/develop')" -eq 1 ]
  [ "$(calls 'ls-remote origin refs/heads/staging')" -eq 1 ]
}

@test "reap: two repositories whose names differ only in / and - read the same base once each" {
  make_stub orca
  put_record 1615 repo=a/b-c child=a/b-c#1615 status=done base=main
  put_record 1616 repo=a-b/c child=a-b/c#1616 status=done base=main
  : > "$STUB_CFG/pr_out"
  gh_seq 1615 closed; gh_seq 1616 closed
  run dispatch reap a/b-c#1615 a-b/c#1616
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; false; }
  [ "$(calls 'ls-remote origin refs/heads/main')" -eq 2 ]
  grep -qF -- "git -C $BATS_TEST_TMPDIR/work/issue-1616 ls-remote origin refs/heads/main" "$STUB_LOG"
}

@test "reap: an unreadable git common directory keeps the child of another repository as git-failed" {
  xreap_ready
  echo 1 > "$STUB_CFG/commondir_exit"
  run dispatch reap genetta-inc/flatmate#1615
  [ "$output" = "kept genetta-inc/flatmate#1615 git-failed" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

# spec: dev-workflow-epic-state（起動部品は epic-launch-<名前>.sh の 1 本ずつで、同じサブコマンドと出力の契約を持つ）
# Orca の起動部品を直接呼ぶ（stderr は $BATS_TEST_TMPDIR/stderr）
part() { PATH="$STUB_BIN:/usr/bin:/bin" bash "$PLUGIN_DIR/scripts/epic-launch-orca.sh" "$@" 2>"$BATS_TEST_TMPDIR/stderr"; }

@test "launcher orca: an unknown subcommand and a wrong number of arguments exit 2 with the usage" {
  make_stub orca
  run part nosuch
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
  run part create /work/parent '' 5 main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  run part available extra
  [ "$status" -eq 2 ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "launcher orca: create prints only the path and the branch, and omits --repo for an empty repo_id" {
  make_stub orca
  printf '%s\n' '{"result":{"worktree":{"path":"/work/issue-5","branch":"refs/heads/oratta/issue-5"}}}' > "$STUB_CFG/create_json_5"
  run part create /work/parent '' 5 main /work/parent
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
  [ "$(printf '%s' "$output" | jq -r '.path')" = /work/issue-5 ]
  [ "$(printf '%s' "$output" | jq -r '.branch')" = oratta/issue-5 ]
  grep -qF 'refs/heads/oratta/issue-5' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree create')" -eq 1 ]
  [ "$(calls '--repo')" -eq 0 ]
  grep -qF -- '--base-branch origin/main --parent-worktree path:/work/parent --json' "$STUB_LOG"
}

@test "launcher orca: create with a repo_id passes --repo, and a missing path exits 2" {
  make_stub orca
  echo '{"ok":true}' > "$STUB_CFG/create_json_5"
  run part create /src/other repo-b 5 develop /work/parent
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  grep -qF -- 'orca worktree create --repo id:repo-b --name issue-5' "$STUB_LOG"
  touch "$STUB_CFG/create_fail_6"
  run part create /src/other repo-b 6 develop /work/parent
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "launcher orca: list reads the Orca marks as the record's words and drops archived worktrees" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[
    {"repoId":"repo-a","linkedIssue":5,"path":"/work/issue-5","branch":"refs/heads/oratta/issue-5","parentWorktreeId":"p1","workspaceStatus":"completed","comment":"epic-stopped"},
    {"repoId":"repo-a","linkedIssue":6,"path":"/work/issue-6","isArchived":true}]}}' > "$STUB_CFG/list_json"
  run part list
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
  [ "$(printf '%s' "$output" | jq -r '.issue')" = 5 ]
  [ "$(printf '%s' "$output" | jq -r '.status')" = done ]
  [ "$(printf '%s' "$output" | jq -r '.stop')" = stopped ]
  [ "$(printf '%s' "$output" | jq -r '.branch')" = oratta/issue-5 ]
  [ "$(printf '%s' "$output" | jq -r '.parent_id')" = p1 ]
  [ ! -s "$BATS_TEST_TMPDIR/stderr" ]
  echo '{"result":{}}' > "$STUB_CFG/list_json"
  run part list
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -qF 'orca worktree list --json is not readable' "$BATS_TEST_TMPDIR/stderr"
}

@test "launcher orca: repos prints each clone with no trailing slash" {
  make_stub orca
  echo '{"result":{"repos":[{"id":"r1","path":"/src/a/"},{"id":"r2","path":"/src/b"}]}}' > "$STUB_CFG/repo_list_json"
  run part repos
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | jq -r '.path' | tr '\n' ' ')" = "/src/a /src/b " ]
  echo 1 > "$STUB_CFG/repo_list_exit"
  run part repos
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "launcher orca: deliver reads the terminal list once and relaunches when there is no terminal" {
  make_stub orca
  run part deliver /work/issue-5 0 返事 cld 指示
  [ "$status" -eq 0 ]
  [ "$output" = "relaunched term-5" ]
  [ "$(calls '^orca terminal list')" -eq 1 ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 1 ]
  [ "$(calls '^orca terminal wait')" -eq 1 ]
  [ "$(calls '^orca terminal send')" -eq 1 ]
  [ "$(cat "$STUB_CFG/sent_term-5")" = 指示 ]
}

@test "launcher orca: deliver with only a shell terminal fails as ambiguous-terminal without relaunch, and relaunches with relaunch 1" {
  make_stub orca
  echo '{"ok":true,"result":{"terminals":[{"handle":"sh-5","title":"Terminal 1"}]}}' > "$STUB_CFG/tlist_json_5"
  run part deliver /work/issue-5 0 返事 cld 指示
  [ "$status" -eq 1 ]
  [ "$output" = "failed ambiguous-terminal" ]
  [ "$(calls '^orca terminal list')" -eq 1 ]
  [ "$(calls '^orca terminal send')" -eq 0 ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
  [ "$(calls '^orca terminal create')" -eq 0 ]
  : > "$STUB_LOG"
  run part deliver /work/issue-5 1 返事 cld 指示
  [ "$status" -eq 0 ]
  [ "$output" = "relaunched term-5" ]
  [ "$(calls '^orca terminal list')" -eq 1 ]
  [ "$(grep -oE '^orca terminal (close|create|wait|send)' "$STUB_LOG" | tr '\n' ' ')" \
    = "orca terminal close orca terminal create orca terminal wait orca terminal send " ]
}

@test "launcher orca: mirror does nothing without orca" {
  run part mirror current done /tmp/rec.json
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -s "$BATS_TEST_TMPDIR/stderr" ]
  [ ! -s "$STUB_LOG" ]
}

@test "launcher orca: close retries once after an incomplete close and names the child in stderr" {
  make_stub orca
  echo 1 > "$STUB_CFG/close_exit_1"
  run part close /work/issue-5 o/r#5
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -qF 'terminal close was incomplete for #o/r#5; ' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca terminal close')" -eq 2 ]
  [ "$(calls '^orca terminal list')" -eq 1 ]
  echo 1 > "$STUB_CFG/close_exit"
  rm -f "$STUB_CFG/closecount"
  run part close /work/issue-5 5
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "launcher orca: here exits 0 without jq when orca worktree current --json succeeds" {
  make_stub orca
  local d="$BATS_TEST_TMPDIR/nojq"
  mkdir -p "$d"
  ln -sf "$(command -v bash)" "$d/bash"
  ln -sf "$(command -v cat)" "$d/cat"
  run env PATH="$STUB_BIN:$d" bash "$PLUGIN_DIR/scripts/epic-launch-orca.sh" here
  [ "$status" -eq 0 ]
  [ "$output" = '{"repo_id":"","worktree_id":""}' ]
  echo 1 > "$STUB_CFG/current_exit"
  run part here
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "launcher orca: remove tells a terminal sweep failure from other failures" {
  make_stub orca
  run part remove /work/issue-5
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  echo 1 > "$STUB_CFG/rm_exit"
  echo 'error: terminal sweep failed' > "$STUB_CFG/rm_err"
  run part remove /work/issue-5
  [ "$status" -eq 1 ]
  [ "$output" = rm-failed-terminal-sweep ]
  echo 'error: dirty' > "$STUB_CFG/rm_err"
  run part remove /work/issue-5
  [ "$output" = rm-failed ]
  [ "$(calls '--force')" -eq 0 ]
}

# orca が exit 0 で空・空白だけの stdout を返したら、空の一覧にせず読めないものとして exit 1 にする
@test "launcher orca: list and repos treat an empty or blank stdout as unreadable, and a real empty array as an empty list" {
  make_stub orca
  : > "$STUB_CFG/list_json"
  run part list
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -qF 'orca worktree list --json is not readable' "$BATS_TEST_TMPDIR/stderr"
  printf ' \n\n' > "$STUB_CFG/list_json"
  run part list
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  echo '{"result":{"worktrees":[]}}' > "$STUB_CFG/list_json"
  run part list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  : > "$STUB_CFG/repo_list_json"
  run part repos
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  printf ' \n' > "$STUB_CFG/repo_list_json"
  run part repos
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  echo '{"result":{"repos":[]}}' > "$STUB_CFG/repo_list_json"
  run part repos
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "launcher orca: launch and adopt after an empty worktree list make no record and no worktree" {
  make_stub orca
  : > "$STUB_CFG/list_json"
  run dispatch launch 1122 11
  [ "$status" -eq 1 ]
  grep -qF 'orca worktree list --json is not readable' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree create')" -eq 0 ]
  [ ! -e "$(rec_of 1122 11)" ]
  set_current 1122
  run dispatch adopt 1122 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -qF 'orca worktree list --json is not readable' "$BATS_TEST_TMPDIR/stderr"
  [ ! -e "$(rec_of 1122 11)" ]
}

# rm の通常の stdout は、部品の stdout に混ぜず、渡された FD（EPIC_LAUNCH_STDOUT_FD）へ中継する。
# FD が渡されない呼び出しでは stderr へ回す
# 部品に FD の番号（EPIC_LAUNCH_STDOUT_FD）を渡して呼ぶ（<FD の番号> <サブコマンド> <引数...>）
partfd() { local fd="$1"; shift; EPIC_LAUNCH_STDOUT_FD="$fd" part "$@"; }

@test "launcher orca: remove relays the rm stdout to the given FD and keeps its own stdout to the control line" {
  make_stub orca
  echo 'Removed worktree /work/issue-5' > "$STUB_CFG/rm_out"
  partfd 7 remove /work/issue-5 7>"$BATS_TEST_TMPDIR/relay" >"$BATS_TEST_TMPDIR/ctl"
  [ -z "$(cat "$BATS_TEST_TMPDIR/ctl")" ]
  [ "$(cat "$BATS_TEST_TMPDIR/relay")" = 'Removed worktree /work/issue-5' ]
  echo 1 > "$STUB_CFG/rm_exit"
  echo 'error: dirty' > "$STUB_CFG/rm_err"
  : > "$BATS_TEST_TMPDIR/relay"
  run partfd 7 remove /work/issue-5 7>"$BATS_TEST_TMPDIR/relay"
  [ "$status" -eq 1 ]
  [ "$output" = rm-failed ]
  [ "$(cat "$BATS_TEST_TMPDIR/relay")" = 'Removed worktree /work/issue-5' ]
  grep -qF 'error: dirty' "$BATS_TEST_TMPDIR/stderr"
}

@test "launcher orca: remove without a usable FD sends the rm stdout to stderr, not stdout" {
  make_stub orca
  echo 'Removed worktree /work/issue-5' > "$STUB_CFG/rm_out"
  run part remove /work/issue-5
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -qF 'Removed worktree /work/issue-5' "$BATS_TEST_TMPDIR/stderr"
  run partfd 9 remove /work/issue-5 9>&-
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(calls '^orca worktree rm')" -eq 2 ]
  grep -qF 'Removed worktree /work/issue-5' "$BATS_TEST_TMPDIR/stderr"
}

# 切り出す前（d07eda2f）の reap と同じ: rm の stdout は reap の stdout に出て、rm の stderr は stderr に出る
@test "reap: the stdout of orca worktree rm stays in the stdout of reap, as before the split" {
  reap_ready
  echo 'Removed worktree' > "$STUB_CFG/rm_out"
  echo 'rm note' > "$STUB_CFG/rm_err"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'Removed worktree' ]
  [ "${lines[1]}" = 'reaped 11' ]
  [ "${#lines[@]}" -eq 2 ]
  grep -qF 'rm note' "$BATS_TEST_TMPDIR/stderr"
}

@test "reap: a failing worktree rm keeps its stdout in the stdout of reap before the kept line" {
  reap_ready
  echo 'Removed worktree' > "$STUB_CFG/rm_out"
  echo 'error: dirty' > "$STUB_CFG/rm_err"
  echo 1 > "$STUB_CFG/rm_exit"
  run dispatch reap 11
  [ "${lines[0]}" = 'Removed worktree' ]
  [ "${lines[1]}" = 'kept 11 rm-failed' ]
  [ "${#lines[@]}" -eq 2 ]
  grep -qF 'error: dirty' "$BATS_TEST_TMPDIR/stderr"
}

# ---- tmux の部品（epic-launcher-tmux） ----
# spec: dev-workflow-epic-state（起動部品は記録の launcher ごとに選ぶ）

# tmux の中で、tmux のスタブがあり orca が無い環境にする。子のワークツリー <パス> の会話ログの置き場を決める
# （スタブは -l で打った文をそのログに user の行として書く）。launch の子のワークツリーは /stub/common/.claude/worktrees/issue-<N>
tmux_env() {
  make_stub tmux
  export TMUX=/tmp/tmux-stub,1,0
  export CLAUDE_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
  mkdir -p "$CLAUDE_PROJECTS_DIR"
  export EPIC_DISPATCH_SUBMIT_WAIT=1 EPIC_DISPATCH_READY_TIMEOUT_MS=2000
}

# 子のワークツリー <パス> の会話ログの置き場を tmux のスタブに教える
tmux_log_for() {
  local d="$CLAUDE_PROJECTS_DIR/$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$d"
  printf '%s' "$d/s.jsonl" > "$STUB_CFG/tmux_log_file"
}

# 子 <N> のワークツリーの tmux のペインを 1 つ置く（<N> <ペイン ID> <コマンド>）
tmux_pane() {
  printf '%s\t%s\t%s\n' "$2" "$BATS_TEST_TMPDIR/work/issue-$1" "$3" >> "$STUB_CFG/panes"
}

@test "tmux route: inside tmux without Orca the route is tmux, and Orca managed wins over tmux" {
  tmux_env
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = tmux ]
  make_stub orca
  run dispatch route 11 12
  [ "$output" = orca ]
  run dispatch route 11
  [ "$output" = orca ]
}

@test "tmux route: outside tmux and Orca is subagent, and no children is subagent" {
  tmux_env
  TMUX="" run dispatch route 11 12
  [ "$output" = subagent ]
  run dispatch route
  [ "$output" = subagent ]
}

@test "tmux route: EPIC_DISPATCH_LAUNCHER pins the part and an unusable one is subagent, a bad value exits 1" {
  tmux_env
  make_stub orca
  EPIC_DISPATCH_LAUNCHER=tmux run dispatch route 11 12
  [ "$output" = tmux ]
  TMUX="" EPIC_DISPATCH_LAUNCHER=tmux run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = subagent ]
  grep -q 'tmux is not available' "$BATS_TEST_TMPDIR/stderr"
  rm -f "$STUB_BIN/orca"
  EPIC_DISPATCH_LAUNCHER=orca run dispatch route 11 12
  [ "$output" = subagent ]
  grep -q 'orca is not on PATH' "$BATS_TEST_TMPDIR/stderr"
  EPIC_DISPATCH_LAUNCHER=bogus run dispatch route 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -q 'EPIC_DISPATCH_LAUNCHER must be orca or tmux' "$BATS_TEST_TMPDIR/stderr"
}

@test "tmux route: a pinned part must also pass here, a failing one is subagent with no switch to the other part" {
  tmux_env
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  EPIC_DISPATCH_LAUNCHER=orca run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = subagent ]
  [ "$(calls '^orca worktree current')" -eq 1 ]
  [ "$(calls '^tmux ')" -eq 0 ]
  echo 0 > "$STUB_CFG/current_exit"
  EPIC_DISPATCH_LAUNCHER=orca run dispatch route 11 12
  [ "$output" = orca ]
  TMUX="" EPIC_DISPATCH_LAUNCHER=tmux run dispatch route 11 12
  [ "$output" = subagent ]
}

@test "tmux launch: records launcher tmux, never calls orca, and starts the session in a new window" {
  tmux_env
  tmux_log_for /stub/common/.claude/worktrees/issue-11
  gh_seq 11 open
  run dispatch launch 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
  [ "$output" = "launched 11" ]
  [ "$(jq -r .launcher "$(rec_of 400 11)")" = tmux ]
  [ "$(jq -r .worktree "$(rec_of 400 11)")" = /stub/common/.claude/worktrees/issue-11 ]
  [ "$(calls '^orca ')" -eq 0 ]
  [ "$(calls '^tmux new-window ')" -eq 1 ]
  [ "$(calls '^tmux send-keys .* -l ')" -eq 2 ]
}

@test "tmux launch: EPIC_DISPATCH_LAUNCHER=tmux works under Orca management too and Orca is not asked" {
  tmux_env
  make_stub orca
  tmux_log_for /stub/common/.claude/worktrees/issue-11
  EPIC_DISPATCH_LAUNCHER=tmux run dispatch launch 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
  [ "$output" = "launched 11" ]
  [ "$(jq -r .launcher "$(rec_of 400 11)")" = tmux ]
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "tmux launch: a child in another repository proceeds with a clone and an empty repo_id" {
  tmux_env
  c="$(xclone flat)"
  tmux_log_for /stub/common/.claude/worktrees/issue-1615
  EPIC_DISPATCH_CLONES="genetta-inc/flatmate=$c" run dispatch launch 1122 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
  [ "$output" = "launched genetta-inc/flatmate#1615" ]
  [ "$(rec_get genetta-inc/flatmate#1615 launcher)" = tmux ]
  grep -qF -- "git -C $c rev-parse --path-format=absolute --git-common-dir" "$STUB_LOG"
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "tmux launch: here with an empty repo_id does not stop a same-repo child" {
  tmux_env
  tmux_log_for /stub/common/.claude/worktrees/issue-11
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  case "$(cat "$BATS_TEST_TMPDIR/stderr")" in *"has no repoId"*) false ;; *) true ;; esac
}

@test "tmux launch: a pinned part that is unusable fails with exit 1 and does not fall back to another part" {
  tmux_env
  make_stub orca
  TMUX="" EPIC_DISPATCH_LAUNCHER=tmux run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -q 'tmux is not available' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree create')" -eq 0 ]
  [ ! -e "$(rec_of 400 11)" ]
}

@test "tmux wait --resolve: when every target child's part is unusable the stdout is empty, the reason is on stderr, the exit is 1 and nothing is polled or judged" {
  tmux_env
  make_judge
  set_current 400
  gh_seq 11 closed
  put_record 11 status=waiting stop=stopped launcher=tmux
  TMUX="" run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -q 'tmux is not available' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^judge ')" -eq 0 ]
  [ "$(calls '^gh api')" -eq 0 ]
}

@test "tmux wait --resolve: a mixed epic goes on for the child whose part is usable" {
  tmux_env
  make_stub orca
  make_judge
  set_current 400
  gh_seq 11 open closed
  gh_seq 12 open closed
  put_record 11 status=waiting stop=stopped launcher=tmux
  put_record 12 status=waiting stop=stopped launcher=orca
  set_terms 12 term-a-12
  judge_says judge_out 通す 範囲の内側 推奨どおり進めてよい
  TMUX="" run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11 12
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
  [ "$(calls '^judge 400 12$')" -eq 1 ]
  [ "$(cat "$STUB_CFG/sent_term-a-12")" = "親エピック #400 の判断（主の承認ではない）: 推奨どおり進めてよい" ]
}

@test "tmux wait: without --resolve the unusable part does not gate the watch" {
  tmux_env
  set_current 400
  gh_seq 11 closed
  put_record 11 status=waiting stop=stopped launcher=tmux
  TMUX="" run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
}

@test "tmux reply: a tmux record sends through tmux and never calls orca, even with an Orca-pinned environment" {
  tmux_env
  put_record 11 status=waiting launcher=tmux
  w="$BATS_TEST_TMPDIR/work/issue-11"
  tmux_log_for "$w"
  tmux_pane 11 %7 node
  EPIC_DISPATCH_LAUNCHER=orca run dispatch reply --as owner 400 11 'A で進めて'
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
  [ "$output" = "sent 11" ]
  [ "$(calls '^orca ')" -eq 0 ]
  [ "$(calls '^tmux send-keys -t %7 -l ')" -eq 1 ]
}

@test "tmux reply: an Orca record is sent through Orca even when inside tmux" {
  tmux_env
  reply_ready term-a-11
  run dispatch reply --as owner 400 11 'A で進めて'
  [ "$output" = "sent 11" ]
  [ "$(calls '^tmux ')" -eq 0 ]
  [ "$(calls '^orca terminal send --terminal term-a-11 ')" -eq 1 ]
}

@test "tmux reply: a tmux record works when the Orca part is unusable" {
  tmux_env
  put_record 11 status=waiting launcher=tmux
  tmux_log_for "$BATS_TEST_TMPDIR/work/issue-11"
  tmux_pane 11 %7 node
  EPIC_DISPATCH_LAUNCHER=orca run dispatch reply --as owner 400 11 'B'
  [ "$status" -eq 0 ]
  [ "$output" = "sent 11" ]
}

@test "tmux reap: a done tmux child is closed and removed through tmux, the record is deleted, orca is not called" {
  tmux_env
  put_record 11 status=done launcher=tmux
  echo aaa111 > "$STUB_CFG/pr_out"
  tmux_pane 11 %7 node
  EPIC_DISPATCH_LAUNCHER=orca run dispatch reap 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; cat "$STUB_LOG"; false; }
  [ "$output" = "reaped 11" ]
  [ "$(calls '^orca ')" -eq 0 ]
  [ "$(calls '^tmux kill-pane -t %7')" -eq 1 ]
  [ "$(calls 'worktree remove ')" -eq 1 ]
  [ "$(calls 'worktree remove .*--force')" -eq 0 ]
  [ ! -e "$(rec_of 1122 11)" ]
}

@test "tmux reap: a mixed epic keeps the child whose part is unusable as launcher-unavailable and reaps the other" {
  tmux_env
  put_record 11 status=done launcher=tmux
  put_record 12 status=done launcher=orca
  echo aaa111 > "$STUB_CFG/pr_out"
  gh_seq 12 closed
  run dispatch reap 11 12
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "${lines[0]}" = "reaped 11" ]
  [ "${lines[1]}" = "kept 12 launcher-unavailable" ]
  [ "${#lines[@]}" -eq 2 ]
  [ -e "$(rec_of 1122 12)" ]
}

@test "tmux reap: when every child's part is unusable the stdout is empty, the reason is on stderr and the exit is 1" {
  tmux_env
  put_record 11 status=done launcher=orca
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -q 'orca is not on PATH' "$BATS_TEST_TMPDIR/stderr"
}

@test "tmux reap: a child without a record is gone when Orca is usable, and exit 1 with the reason when it is not" {
  tmux_env
  make_stub orca
  run dispatch reap 77
  [ "$status" -eq 0 ]
  [ "$output" = "gone 77" ]
  rm -f "$STUB_BIN/orca"
  run dispatch reap 77
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -q 'orca is not on PATH' "$BATS_TEST_TMPDIR/stderr"
}

@test "tmux reap: an Orca environment pinned to an unusable part still reaps a tmux record" {
  tmux_env
  put_record 11 status=done launcher=tmux
  echo aaa111 > "$STUB_CFG/pr_out"
  tmux_pane 11 %7 node
  EPIC_DISPATCH_LAUNCHER=orca run dispatch reap 11
  [ "$output" = "reaped 11" ]
}

@test "tmux mark: a tmux record is marked stopped without orca or tmux" {
  put_record 11 launcher=tmux; in_child 11
  run dispatch mark stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 stopped" ]
  [ "$(rec_get 11 stop)" = stopped ]
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "tmux wait: --watch-stopped sees a stopped tmux record with Orca missing and ends with stopped" {
  gh_seq 11 open
  put_record 11 launcher=tmux stop=stopped status=waiting
  run dispatch wait --interval 0 --timeout 60 --watch-stopped 11
  [ "$status" -eq 0 ]
  [ "$output" = "stopped 11" ]
  [ "$(rec_get 11 stop)" = stopped-seen ]
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "tmux record: a launcher that is neither orca nor tmux is an unreadable record" {
  tmux_env
  put_record 11 status=done launcher=zellij
  run dispatch reap 11
  [ "$output" != "reaped 11" ]
  [ -e "$(rec_of 1122 11)" ]
  [ "$(calls 'worktree remove ')" -eq 0 ]
}
