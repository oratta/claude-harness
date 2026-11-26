#!/usr/bin/env bash
# マージ待ちの前提の確認と入力収集だけを行う。モデル・委任の判定・書き込みは親に残す。
# 0: 入力文、3: 主に上げる理由 1 行、1: 読めない入力（stdout 空）。
set -euo pipefail
usage() {
  echo 'usage: parent-merge-inputs.sh <epic> <child|owner/repo#N> <PR URL> --last-message <file> [--delegation-place <line>]' >&2
  exit 1
}
[ "$#" -ge 3 ] || usage
epic=$1; child=$2; pr_url=$3; shift 3
[[ "$epic" =~ ^[0-9]+$ ]] || usage
child_repo='{owner}/{repo}'
if [[ "$child" =~ ^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)$ ]]; then
  child_repo=${BASH_REMATCH[1]}; child_num=${BASH_REMATCH[2]}
elif [[ "$child" =~ ^[0-9]+$ ]]; then
  child_num=$child
else
  usage
fi
[[ "$pr_url" =~ ^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/pull/([0-9]+)/?$ ]] || usage
pr_repo=${BASH_REMATCH[1]}; pr_num=${BASH_REMATCH[2]}
last_message=''; delegation_place=''
while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || usage
  case "$1" in
    --last-message) last_message=$2 ;;
    --delegation-place) delegation_place=$2 ;;
    *) usage ;;
  esac
  shift 2
done
[ -f "$last_message" ] && [ -r "$last_message" ] || usage
statement=$(cat "$last_message")
# stop-judge.sh と同じ信頼の境界。本文を読む前に投稿者を確認する。
read_trusted_body() {
  local raw
  raw=$(gh api "repos/$1/issues/$2") || return 1
  printf '%s' "$raw" | jq -er 'select(.author_association == "OWNER" or .author_association == "MEMBER" or .author_association == "COLLABORATOR") | .body // ""'
}
comments() {
  gh api --paginate "repos/$1/issues/$2/comments" | jq -s 'add // []'
}
escalate() { printf '主に上げる: %s\n' "$1"; exit 3; }
epic_body=$(read_trusted_body '{owner}/{repo}' "$epic") || exit 1
child_body=$(read_trusted_body "$child_repo" "$child_num") || exit 1
pr=$(gh pr view "$pr_url" --json body,labels,headRefOid,state,baseRefName,statusCheckRollup) || exit 1
head=$(printf '%s' "$pr" | jq -er '.headRefOid | select(test("^[0-9a-f]{40}$"))') || exit 1
base=$(printf '%s' "$pr" | jq -er '.baseRefName | select(length > 0)') || exit 1
workflow=$(gh api "repos/$pr_repo/contents/.github/workflows/auto-merge.yml?ref=$base" --jq .content | base64 -d) || exit 1
[[ "$workflow" == *parent-merge-approved* ]] || escalate 'base ブランチの auto-merge.yml に parent-merge-approved が無い'
printf '%s' "$pr" | jq -e '.state == "OPEN" and ([.labels[].name | select(. == "human-merge" or . == "needs-human-merge" or . == "human-only" or . == "needs-approval")] | sort == ["human-merge"])' >/dev/null \
  || escalate 'PR が open でないか、見送りラベルが human-merge だけではない'
first=$(printf '%s' "$pr" | jq -r '[.body | scan("(?:Closes|Fixes|Refs) #([0-9]+)")] | .[0][0] // ""') || exit 1
[ "$first" = "$child_num" ] || escalate 'PR 本文の最初の Closes・Fixes・Refs の番号が子 issue と違う'
pr_comments=$(comments "$pr_repo" "$pr_num") || exit 1
trusted='select(.author_association == "OWNER" or .author_association == "MEMBER" or .author_association == "COLLABORATOR")'
approved=$(printf '%s' "$pr_comments" | jq --arg head "$head" '[.[] | '"$trusted"' | (.body // "" | split("\n") | map(rtrimstr("\r"))) | select(.[0] == "親のマージ判断: 可" and index("親が見た HEAD: " + $head))] | length') || exit 1
[ "$approved" = 0 ] || escalate '今の HEAD の親のマージ判断: 可 がある。docs/auto-merge.md「親の判断の印を付けたのにマージされないとき」を調べる'
child_comments=$(comments "$child_repo" "$child_num") || exit 1
epic_comments=$(comments '{owner}/{repo}' "$epic") || exit 1
notes=$(printf '%s' "$child_comments" | jq -r '.[] | '"$trusted"' | select((.body // "") | startswith("親エピックからの注意書き:")) | .body') || exit 1
pr_notes=$(printf '%s' "$pr_comments" | jq -r '.[] | '"$trusted"' | .body, "---"') || exit 1
bot_notes=$(printf '%s' "$pr_comments" | jq -r '.[] | select((.body // "") | startswith("🔒 **auto-merge 対象外（聖域パス接触）**")) | .body, "---"') || exit 1
delegation=$(printf '%s' "$epic_comments" | jq -r '[.[] | '"$trusted"' | select((.body // "") | split("\n")[0] | rtrimstr("\r") == "主の委任: 論点なしの止まり")] | sort_by(.created_at) | last // empty | .body, .html_url') || exit 1
files=$(gh api --paginate "repos/$pr_repo/pulls/$pr_num/files" | jq -s '(add // []) | if length == 0 then empty else . end') || exit 1
diff=$(gh pr diff "$pr_url") || exit 1
pr_body=$(printf '%s' "$pr" | jq -r '.body, "ラベル:", (.labels[].name)') || exit 1
ci=$(printf '%s' "$pr" | jq 'if (.statusCheckRollup | length) == 0 then empty else .statusCheckRollup end') || exit 1
paths=$(printf '%s\n' "$workflow" | sed -n '/# >>> sacred-paths/,/# <<< merge-condition-paths/p')
casting=''
top=$(git rev-parse --show-toplevel) || exit 1
for file in "$top/.claude/casting/project.md" "$top/.claude/casting/local.md"; do
  if [ -f "$file" ]; then
    content=$(cat "$file") || exit 1
    casting="$casting$(printf '\n### %s\n\n%s\n' "${file#"$top"/}" "$content")"
  fi
done
# 収集の途中では stdout に出さない。後半の gh が失敗しても部分入力を渡さない。
section() {
  if [ -n "$2" ]; then printf '\n## %s\n\n%s\n' "$1" "$2"
  else printf '\n## %s（なし）\n' "$1"; fi
}
printf 'HEAD: %s\n' "$head"
section 'エピックの本文' "$epic_body"
section '子 issue の本文' "$child_body"
section '親エピックからの注意書き' "$notes"
section '子の最後の発言' "$statement"
section 'PR の本文とラベル' "$pr_body"
section '変更ファイルの一覧' "$files"
section '差分' "$diff"
section 'PR のコメント' "$pr_notes"
section 'CI の結果' "$ci"
section 'auto-merge.yml の聖域とマージ条件の行' "$paths"
section 'human-merge を付けた投稿' "$bot_notes"
section '配役表' "$casting"
[ -n "$delegation_place" ] || delegation=''
section '委任の記録の候補' "$delegation"
section '委任の確認の場所' "$delegation_place"
