#!/usr/bin/env bash
# 記録先（issue または Draft PR）の `Codex 消費: <thread_id> <tokens>` コメントを集め、
# pr-token-budget.sh の --codex-records に渡すファイルを作る。
#
#   codex-records.sh --repo <owner>/<repo> --out <file> <記録先番号>...
#
# 番号ごとに `gh api --paginate --slurp repos/<owner>/<repo>/issues/<番号>/comments` で全ページ取得し、
# 1 行目が `^Codex 消費: ` のコメントから接頭辞を除いた `<thread_id> <tokens>` を 1 行ずつ抜き出す。
# exit code: 0 = 全番号の取得と抽出に成功し <file> を書いた（該当なしなら空ファイル）/
#            1 = 引数エラー・gh か jq が無い・どれかの番号の取得か抽出か書き込みに失敗
# exit 1 のときは <file> を残さない（途中までの記録も、前回の計測で作った同名のファイルも消す）。
# 本体は exit 1 なら pr-token-budget.sh を呼ばず、計測できない扱いにする（正本は skills/develop/SKILL.md）。
set -uo pipefail

repo=""
out=""
nums=()
bad=""
usage='usage: codex-records.sh --repo <owner>/<repo> --out <file> <番号>...'
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      if [ -z "${2-}" ]; then bad="--repo needs <owner>/<repo>"; shift; else repo="$2"; shift 2; fi ;;
    --out)
      if [ -z "${2-}" ]; then bad="--out needs a file"; shift; else out="$2"; shift 2; fi ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then nums+=("$1"); else bad="unknown arg: $1"; fi
      shift ;;
  esac
done

tmp=""
fail() {
  echo "codex-records: $1" >&2
  [ -n "$tmp" ] && rm -rf "$tmp"
  [ -n "$out" ] && rm -f "$out"
  exit 1
}

[ -z "$bad" ] || { echo "$usage" >&2; fail "$bad"; }
[ -n "$repo" ] && [ -n "$out" ] && [ ${#nums[@]} -gt 0 ] || { echo "$usage" >&2; fail "missing arguments"; }
command -v gh >/dev/null 2>&1 || fail "gh not found"
command -v jq >/dev/null 2>&1 || fail "jq not found"

tmp="$(mktemp -d)" || fail "cannot create a temporary directory"
: > "${tmp}/records" || fail "cannot write ${tmp}/records"
for n in "${nums[@]}"; do
  gh api --paginate --slurp "repos/${repo}/issues/${n}/comments" > "${tmp}/pages.json" \
    || fail "failed to fetch comments of #${n}"
  jq -r '.[][] | (.body // "") | split("\n")[0] | select(test("^Codex 消費: ")) | sub("^Codex 消費: "; "")' \
    "${tmp}/pages.json" >> "${tmp}/records" \
    || fail "failed to read comments of #${n}"
done
mv -f "${tmp}/records" "$out" || fail "cannot write $out"
rm -rf "$tmp"
exit 0
