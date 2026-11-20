#!/usr/bin/env bash
# PR トークンの計測を 1 コマンドで呼ぶ薄いラッパー。codex-records.sh で記録先の `Codex 消費:` コメントを集め、
# 全番号の取得に成功したときだけ pr-token-budget.sh を --codex-records 付きで呼ぶ。
#
#   pr-token-measure.sh --repo <owner>/<repo> [--cap <tokens>] [--codex-home <dir>]... <記録先番号>...
#
# --codex-home は渡されたものに加えて ${CODEX_HOME:-$HOME/.codex} を渡す。--cap は渡されたときだけ渡す。
# stdout と exit code は pr-token-budget.sh のものをそのまま返す（0 = 上限以内 / 2 = 上限超過 / 1 = 計測できない）。
# codex-records.sh が exit 0 以外のときは pr-token-budget.sh を呼ばず、stdout を空にして stderr に理由を出し exit 1。
# 引数エラー（--repo が無い・番号が 0 件・数字でない番号）も何も呼ばず exit 1。一時ディレクトリは終わるときに消す。
# LLM を呼ばず、GitHub に書き込まない。exit 2 のあとの扱いは skills/develop/references/pr-token-budget.md が正本。
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"
repo=""
cap=""
homes=()
nums=()
bad=""
usage='usage: pr-token-measure.sh --repo <owner>/<repo> [--cap <tokens>] [--codex-home <dir>]... <番号>...'
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      if [ -z "${2-}" ]; then bad="--repo needs <owner>/<repo>"; shift; else repo="$2"; shift 2; fi ;;
    --cap)
      if [ -z "${2-}" ]; then bad="--cap needs a number"; shift; else cap="$2"; shift 2; fi ;;
    --codex-home)
      if [ -z "${2-}" ]; then bad="--codex-home needs a directory"; shift; else homes+=("$2"); shift 2; fi ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then nums+=("$1"); else bad="unknown arg: $1"; fi
      shift ;;
  esac
done

tmp=""
# 中断でも一時ディレクトリを残さない
trap '[ -n "$tmp" ] && rm -rf "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { echo "pr-token-measure: $1" >&2; exit 1; }

[ -z "$bad" ] || { echo "$usage" >&2; fail "$bad"; }
[ -n "$repo" ] && [ ${#nums[@]} -gt 0 ] || { echo "$usage" >&2; fail "missing arguments"; }

tmp="$(mktemp -d)" || fail "cannot create a temporary directory"
"${here}/codex-records.sh" --repo "$repo" --out "${tmp}/codex-records.txt" "${nums[@]}" \
  || fail "Codex 消費コメントを取得できなかった"

args=("${nums[@]}" --codex-records "${tmp}/codex-records.txt")
for h in ${homes[@]+"${homes[@]}"}; do args+=(--codex-home "$h"); done
args+=(--codex-home "${CODEX_HOME:-$HOME/.codex}")
[ -z "$cap" ] || args+=(--cap "$cap")
"${here}/pr-token-budget.sh" "${args[@]}"
exit $?
