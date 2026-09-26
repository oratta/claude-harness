#!/usr/bin/env bash
# ゲート合格後の PR の CI を見張る。待つだけの wait と、一手を取り出して PR ごとの状態を保存する
# next に分ける。分類と一手の判断は同じディレクトリの pr-state.sh に任せ、一手の実行（gh run rerun・
# 直し・マージの依頼）は呼び出し側の手順（references/ci-watch.md）が持つ。
#
#   ci-watch.sh wait <owner/repo> <PR番号> [--until-merged]
#       最初に 1 間隔待ってから gh pr view を繰り返し、決着したら 1 行 JSON を出して exit 0。
#       決着するまで標準出力には何も出さない（本体が run_in_background で起動し、完了通知で読む）。
#         {"result":"merged","obs":null}   PR がマージされた
#         {"result":"closed","obs":null}   PR が閉じられた
#         {"result":"settled","obs":<observe>}  observe の state が wait 以外（--until-merged では ready を決着にしない）
#         {"result":"timeout","obs":<最後の observe か null>}  上限時間を超えた
#         {"result":"error","obs":null}    gh pr view が 5 回続けて失敗した
#       annotations は決着した回だけ取る。状態ファイルは読み書きしない
#   ci-watch.sh next <owner/repo> <PR番号> [--unrelated <チェック名>]... [--after-fix]
#       PR を取り直して pr-state.sh annotations → observe → decide に通し、decide の出力
#       {act, next, obs} を 1 行で出し、状態ファイルを .next で置き換える。--after-fix は、fix を受けた
#       実装者が関係ない失敗と判断して返したときだけ使い、前回の状態の state を wait に置き換えてから
#       decide に渡す（同じ状態・同じ HEAD の none がやり直しより先に効くのを避ける）。
#       gh・pr-state.sh の失敗と読めない状態ファイルでは、状態を書き換えずに非 0
#
# 環境変数:
#   DEV_WORKFLOW_CI_WATCH_INTERVAL  wait の間隔（秒、既定 30）。正の整数でなければ既定
#   DEV_WORKFLOW_CI_WATCH_TIMEOUT   wait の上限時間（秒、既定 3600）。正の整数でなければ既定
#   DEV_WORKFLOW_PR_STATE_DIR       状態ディレクトリ（既定 ${XDG_STATE_HOME:-$HOME/.local/state}/dev-workflow/pr-state）
#
# 状態ファイル: <状態ディレクトリ>/<owner>__<repo>__<PR番号>.json（pr-state.sh decide の状態）。
# 引数が足りないときは標準出力に何も出さず非 0。
# 仕様の正本: openspec の dev-workflow-ci-watch。
set -uo pipefail

PR_STATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pr-state.sh"
FAIL_LIMIT=5

die() { echo "ci-watch.sh: $*" >&2; exit 1; }

posint() {
  case "${1-}" in
    ''|*[!0-9]*|0*) printf '%s' "$2" ;;
    *) printf '%s' "$1" ;;
  esac
}

emit() {
  jq -cn --arg r "$1" --argjson o "$2" '{result: $r, obs: $o}'
}

# gh pr view の JSON $1 を annotations に通してから observe する（$2 以降は observe への追加引数）
observe_with_hints() {
  local view="$1" hints rc
  shift
  hints="$(mktemp "${TMPDIR:-/tmp}/ci-watch.XXXXXX")" || return 1
  if printf '%s' "$view" | "$PR_STATE" annotations "$REPO" > "$hints"; then
    printf '%s' "$view" | "$PR_STATE" observe --hints "$hints" "$@"
    rc=$?
  else
    rc=1
  fi
  rm -f "$hints"
  return "$rc"
}

cmd_wait() {
  local until_merged=0
  REPO="${1-}"
  local pr="${2-}"
  [ -n "$REPO" ] && [ -n "$pr" ] || die "usage: ci-watch.sh wait <owner/repo> <PR番号> [--until-merged]"
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --until-merged) until_merged=1; shift ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  local interval timeout start fails=0 last=null view state obs
  interval="$(posint "${DEV_WORKFLOW_CI_WATCH_INTERVAL-}" 30)"
  timeout="$(posint "${DEV_WORKFLOW_CI_WATCH_TIMEOUT-}" 3600)"
  start="$(date +%s)"
  while :; do
    sleep "$interval"
    if view="$(gh pr view "$pr" --repo "$REPO" --json state,mergeable,statusCheckRollup,headRefOid 2>/dev/null)" \
       && state="$(jq -er '.state // "" | tostring' <<<"$view" 2>/dev/null)"; then
      fails=0
      case "$state" in
        MERGED) emit merged null; return 0 ;;
        CLOSED) emit closed null; return 0 ;;
      esac
      if obs="$(printf '%s' "$view" | "$PR_STATE" observe)"; then
        last="$obs"
        # --until-merged は ready だけを待ち続け、ci-fail・conflict は決着として返す
        if [ "$(jq -r .state <<<"$obs")" != wait ] &&
           { [ "$until_merged" -eq 0 ] || [ "$(jq -r .state <<<"$obs")" != ready ]; }; then
          # 決着した回だけ annotation を取り、通信切れの判定が済んだ観測を出す
          obs="$(observe_with_hints "$view")" || obs="$last"
          emit settled "$obs"
          return 0
        fi
      fi
    else
      fails=$((fails + 1))
      echo "ci-watch.sh: warning: gh pr view failed (${fails}/${FAIL_LIMIT}) for ${REPO}#${pr}" >&2
      if [ "$fails" -ge "$FAIL_LIMIT" ]; then
        emit error null
        return 0
      fi
    fi
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then
      emit timeout "$last"
      return 0
    fi
  done
}

cmd_next() {
  local after_fix=0 unrelated=()
  REPO="${1-}"
  local pr="${2-}"
  [ -n "$REPO" ] && [ -n "$pr" ] || die "usage: ci-watch.sh next <owner/repo> <PR番号> [--unrelated NAME]... [--after-fix]"
  case "$REPO" in */*) ;; *) die "owner/repo expected: $REPO" ;; esac
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --unrelated)
        [ -n "${2-}" ] || die "--unrelated needs a check name"
        unrelated+=(--unrelated "$2"); shift 2 ;;
      --after-fix) after_fix=1; shift ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  local dir file prev='{}' view obs out tmp
  dir="${DEV_WORKFLOW_PR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dev-workflow/pr-state}"
  mkdir -p "$dir" || die "cannot create state directory: $dir"
  file="${dir}/${REPO%%/*}__${REPO#*/}__${pr}.json"
  if [ -e "$file" ]; then
    prev="$(jq -ce 'if type == "object" then . else error("not an object") end' "$file" 2>/dev/null)" \
      || die "cannot read state file: $file"
  fi
  if [ "$after_fix" -eq 1 ]; then
    prev="$(jq -c '.state = "wait"' <<<"$prev")"
  fi
  view="$(gh pr view "$pr" --repo "$REPO" --json mergeable,statusCheckRollup,headRefOid)" \
    || die "gh pr view failed for ${REPO}#${pr}"
  obs="$(observe_with_hints "$view" ${unrelated[@]+"${unrelated[@]}"})" || die "pr-state.sh observe failed"
  out="$(printf '%s' "$obs" | "$PR_STATE" decide "$prev")" || die "pr-state.sh decide failed"
  tmp="$(mktemp "${dir}/.ci-watch.XXXXXX")" || die "cannot create a temporary file in $dir"
  if ! jq -c .next <<<"$out" > "$tmp" || ! mv -f "$tmp" "$file"; then
    rm -f "$tmp"
    die "cannot write state file: $file"
  fi
  printf '%s\n' "$out"
}

case "${1-}" in
  wait) shift; cmd_wait "$@" ;;
  next) shift; cmd_next "$@" ;;
  *) die "usage: ci-watch.sh wait OWNER/REPO PR [--until-merged] | next OWNER/REPO PR [--unrelated NAME]... [--after-fix]" ;;
esac
