#!/usr/bin/env bash
# review-issue-candidates.sh — レビューの指摘が指すファイルについて、同じ場所を直す open の issue の候補（番号と題名）を返す。
#
# 使い方: review-issue-candidates.sh --repo <owner>/<name> [--exclude <番号>]... [--epic <番号> [--children-only]] <パス>...
#   パスごとに gh issue list --state open --search '"<ファイル名>" in:title,body' を 1 回だけ引く。
#   <ファイル名> は渡されたパスの最後の要素。同じ文字列のパスは最初の 1 つだけ検索する。issue の本文は取らない・出さない。
#   --exclude  候補から外す番号（いまの PR と記録先 issue）。0 回以上。
#   --epic     実行の最初に repos/<owner>/<name>/issues/<番号>/sub_issues を 1 回取り、各行の 3 列目に child / other を足す。
#   --children-only  --epic と一緒に使う。sub_issues は取らず、検索語に parent-issue:<owner>/<name>#<番号> を足して
#              検索の側で子だけに絞り、3 列目はすべて child にする。
# 出力: パスごとに "== <渡されたパス>" の見出し行、その下に "<番号><TAB><題名>[<TAB>child|other]" を検索が返した順に最大 15 件。
#   候補が 0 件なら "(該当なし)"。外す番号を除いて 15 件を超えるときは最後に "(15 件で打ち切り。ほかにも一致あり)"。
#   出力は全パスの検索が済んでからまとめて出す。
# 終了コード: 0 = 全パスの検索が済んだ（候補 0 件でも 0） / 1 = gh の呼び出しが失敗した（標準出力は空。「候補なし」と扱わない）
#   / 2 = 引数の不備、または gh・jq が無い（検索は 1 回も走らせない）
#
# spec: openspec/specs/dev-workflow-review-issue-candidates（change: review-finding-issue-candidates）
set -euo pipefail

usage() {
  echo "usage: $0 --repo <owner>/<name> [--exclude <n>]... [--epic <n> [--children-only]] <path>..." >&2
}

die2() {
  echo "review-issue-candidates: $1" >&2
  exit 2
}

repo=""
epic=""
epic_given=0
children_only=0
excludes=()
paths=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo|--exclude|--epic)
      [ "$#" -ge 2 ] || { usage; die2 "$1 needs a value"; }
      case "$1" in
        --repo) repo="$2" ;;
        --exclude) excludes+=("$2") ;;
        --epic) epic="$2"; epic_given=1 ;;
      esac
      shift 2
      ;;
    --children-only) children_only=1; shift ;;
    --) shift; paths+=("$@"); break ;;
    -*) usage; die2 "unknown option: $1" ;;
    *) paths+=("$1"); shift ;;
  esac
done

[ "${#paths[@]}" -gt 0 ] || { usage; die2 "no path given"; }
[[ "$repo" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || die2 "--repo must be <owner>/<name>: '${repo}'"
for n in ${excludes[@]+"${excludes[@]}"}; do
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || die2 "--exclude must be a positive integer: '${n}'"
done
if [ "$epic_given" -eq 1 ]; then
  [[ "$epic" =~ ^[1-9][0-9]*$ ]] || die2 "--epic must be a positive integer: '${epic}'"
fi
if [ "$children_only" -eq 1 ] && [ "$epic_given" -eq 0 ]; then
  die2 "--children-only needs --epic"
fi
for p in "${paths[@]}"; do
  name="${p##*/}"
  [ -n "$name" ] || die2 "cannot take a file name from path: '${p}'"
  case "$name" in
    *'"'*) die2 "file name contains a double quote: '${p}'" ;;
  esac
done
command -v gh >/dev/null 2>&1 || die2 "gh not found"
command -v jq >/dev/null 2>&1 || die2 "jq not found"

fail() {
  echo "review-issue-candidates: $1 failed" >&2
  exit 1
}

excl_json="[]"
if [ "${#excludes[@]}" -gt 0 ]; then
  excl_json="$(printf '%s\n' "${excludes[@]}" | jq -sc 'map(tonumber)')"
fi
limit=$((15 + ${#excludes[@]} + 1))

kids_json="[]"
mark="none"
if [ "$epic_given" -eq 1 ]; then
  if [ "$children_only" -eq 1 ]; then
    mark="all"
  else
    mark="mark"
    sub_out="$(gh api --paginate "repos/${repo}/issues/${epic}/sub_issues?per_page=100")" \
      || fail "gh api repos/${repo}/issues/${epic}/sub_issues"
    kids_json="$(printf '%s' "$sub_out" | jq -sc '[.[][] | .number]')" \
      || fail "parsing sub_issues"
  fi
fi

result=""
seen=$'\n'
for p in "${paths[@]}"; do
  case "$seen" in
    *$'\n'"${p}"$'\n'*) continue ;;
  esac
  seen="${seen}${p}"$'\n'
  name="${p##*/}"
  query="\"${name}\" in:title,body"
  if [ "$children_only" -eq 1 ]; then
    query="${query} parent-issue:${repo}#${epic}"
  fi
  list="$(gh issue list --repo "$repo" --state open --search "$query" --limit "$limit" --json number,title)" \
    || fail "gh issue list --search '${query}'"
  body="$(printf '%s' "$list" | jq -r --argjson ex "$excl_json" --argjson kids "$kids_json" --arg mark "$mark" '
    [ .[] | select(.number as $n | ($ex | any(. == $n)) | not) ] as $c
    | ( $c[:15][]
        | "\(.number)\t\(.title | gsub("[\t\r\n]"; " "))"
          + ( if $mark == "all" then "\tchild"
              elif $mark == "mark" then (if (.number as $n | $kids | any(. == $n)) then "\tchild" else "\tother" end)
              else "" end ) ),
      ( if ($c | length) == 0 then "(該当なし)"
        elif ($c | length) > 15 then "(15 件で打ち切り。ほかにも一致あり)"
        else empty end )
  ')" || fail "parsing gh issue list output for '${p}'"
  result="${result}== ${p}"$'\n'"${body}"$'\n'
done

printf '%s' "$result"
