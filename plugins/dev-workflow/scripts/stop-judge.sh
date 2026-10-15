#!/usr/bin/env bash
# 主の返事を待って止まったエピックの子を、親の側で「通す」か「主に上げる」かをモデル 1 回で判断する。
# epic-dispatch.sh wait --resolve が止まった子ごとに呼ぶ（EPIC_DISPATCH_JUDGE で差し替えられる）。
#
#   stop-judge.sh <epic> <child>
#
# 入力として集めるのは次だけ（親や子の会話は渡さない）:
#   エピックの本文、子 issue の本文（どちらも issue の author_association が OWNER / MEMBER / COLLABORATOR の
#   ときだけ。それ以外は exit 1 でモデルを呼ばない）、子 issue の `親エピックからの注意書き:` で始まるコメントのうち
#   author_association が OWNER / MEMBER / COLLABORATOR のもの、子 issue の 1 行目が
#   `子の停止: 主の返事待ち` の最新のコメント（同じ 3 種の投稿者のもの）の本文と URL、エピックのコメント
#   （同じ 3 種の投稿者のもの）のうち `親の判断: 子 #<child> ` で始まる行、skills/develop/references/parent-pass-criteria.md の本文、
#   リポジトリの .claude/casting/project.md・.claude/casting/local.md（あるものだけ）
# モデルの呼び方: 既定は `claude -p --model <EPIC_DISPATCH_JUDGE_MODEL、既定 sonnet> --tools ""
#   --no-session-persistence`（ツールを渡さない）。EPIC_DISPATCH_JUDGE_CMD を設定するとコマンド全体を
#   それに替える（bash -c で実行する）。どちらも入力は標準入力で渡す。
# 出力（stdout）: 1〜3 行目はモデルの出力の空行を除いた最初の 3 行で、`判断: 通す` か `判断: 主に上げる`、
#   `理由: <1 行>`、`返事: <1 行>`（主に上げるときは空でよい）。4 行目に `記録: <停止の記録の URL>` を付ける。
#   exit 0。
# exit 1（stdout は空）: 引数の誤り、gh の失敗、エピックか子の issue の投稿者が上の 3 種でない、
#   停止の記録が無い（ここまではモデルを呼ばない）、
#   モデルのコマンドが非 0、モデルの出力が 1〜3 行目の形で読めない。
#
# 正本は openspec の dev-workflow-develop spec「epic-dispatch.sh の wait は止まった子を判断し、
# 通すものには返事を送って待ちを続ける」。
set -uo pipefail

usage() {
  echo "usage: stop-judge.sh <epic> <child>" >&2
  exit 1
}

[ "$#" -eq 2 ] || usage
epic="$1"; child="$2"
[[ "$epic" =~ ^[0-9]+$ ]] || { echo "not an issue number: $epic" >&2; usage; }
[[ "$child" =~ ^[0-9]+$ ]] || { echo "not an issue number: $child" >&2; usage; }
command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
criteria="$here/../skills/develop/references/parent-pass-criteria.md"
[ -r "$criteria" ] || { echo "criteria file not found: $criteria" >&2; exit 1; }

# issue の本文は、投稿者が OWNER / MEMBER / COLLABORATOR のときだけ判断に渡す（それ以外の投稿者が
# 立てた issue の本文で判断を誘導されないようにする）。それ以外・読めないときは exit 1 で主に上げる
read_trusted_body() { # <issue number> <label>
  local raw assoc
  raw="$(gh api "repos/{owner}/{repo}/issues/$1")" \
    || { echo "could not read $2 #$1" >&2; return 1; }
  assoc="$(printf '%s' "$raw" | jq -r '.author_association // empty' 2>/dev/null)" \
    || { echo "$2 #$1 is not readable" >&2; return 1; }
  case "$assoc" in
    OWNER|MEMBER|COLLABORATOR) ;;
    *) echo "the body of $2 #$1 is by an author who is not an owner, member or collaborator (${assoc:-unknown})" >&2
       return 1 ;;
  esac
  printf '%s' "$raw" | jq -r '.body // ""'
}
epic_body="$(read_trusted_body "$epic" epic)" || exit 1
child_body="$(read_trusted_body "$child" child)" || exit 1
# --paginate はページごとの配列を続けて出すので、jq -s で 1 つにまとめる
child_comments="$(gh api --paginate "repos/{owner}/{repo}/issues/$child/comments")" \
  || { echo "could not read the comments of child #$child" >&2; exit 1; }
child_comments="$(printf '%s' "$child_comments" | jq -s 'add // []' 2>/dev/null)" \
  || { echo "the comments of child #$child are not readable" >&2; exit 1; }
epic_comments="$(gh api --paginate "repos/{owner}/{repo}/issues/$epic/comments")" \
  || { echo "could not read the comments of epic #$epic" >&2; exit 1; }
epic_comments="$(printf '%s' "$epic_comments" | jq -s 'add // []' 2>/dev/null)" \
  || { echo "the comments of epic #$epic are not readable" >&2; exit 1; }

# 投稿者が OWNER / MEMBER / COLLABORATOR のコメントだけを読む（子 issue には誰でもコメントできるので、
# 偽の停止の記録や偽の親の判断で判断を誘導されないようにする）
trusted='select(.author_association == "OWNER" or .author_association == "MEMBER" or .author_association == "COLLABORATOR")'
stop="$(printf '%s' "$child_comments" | jq -c \
  '[.[] | '"$trusted"' | select((.body // "") | split("\n")[0] | rtrimstr("\r") == "子の停止: 主の返事待ち")] | last // empty')"
[ -n "$stop" ] || { echo "no stop record (子の停止: 主の返事待ち) on child #$child" >&2; exit 1; }
stop_url="$(printf '%s' "$stop" | jq -r '.html_url // empty')"
stop_body="$(printf '%s' "$stop" | jq -r '.body // empty')"
[ -n "$stop_url" ] || { echo "the stop record on child #$child has no URL" >&2; exit 1; }

notes="$(printf '%s' "$child_comments" | jq -r \
  '.[] | select((.body // "") | startswith("親エピックからの注意書き:"))
       | '"$trusted"'
       | .body, "---"')"
past="$(printf '%s' "$epic_comments" | jq -r --arg p "親の判断: 子 #$child " \
  '.[] | '"$trusted"' | (.body // "") | split("\n")[] | select(startswith($p))')"

casting=""
top="$(git rev-parse --show-toplevel 2>/dev/null)" || top=""
if [ -n "$top" ]; then
  for f in "$top/.claude/casting/project.md" "$top/.claude/casting/local.md"; do
    [ -r "$f" ] && casting="$casting$(printf '### %s\n\n%s\n\n' "${f#"$top"/}" "$(cat "$f")")"
  done
fi

prompt="$(cat <<EOF
エピック #$epic の子 #$child が、主の返事を待って止まった。下の「親が通してよい範囲の基準」に照らして、親の側で通すか主に上げるかを決め、基準の「出力の形」の 3 行だけを出す。前置き・説明・コードブロックを付けない。

## 親が通してよい範囲の基準

$(cat "$criteria")

## エピック #$epic の本文

$epic_body

## 子 #$child の本文

$child_body

## 子 #$child への親エピックからの注意書き（投稿者が OWNER・MEMBER・COLLABORATOR のもの）

${notes:-（なし）}

## 子 #$child の停止の記録（最新）

URL: $stop_url

$stop_body

## このエピックで子 #$child について親が過去に出した判断

${past:-（なし）}

## 配役表

${casting:-（なし）}
EOF
)"

out=""
if [ -n "${EPIC_DISPATCH_JUDGE_CMD-}" ]; then
  out="$(printf '%s\n' "$prompt" | bash -c "$EPIC_DISPATCH_JUDGE_CMD")" \
    || { echo "the judge command failed" >&2; exit 1; }
else
  model="${EPIC_DISPATCH_JUDGE_MODEL:-sonnet}"
  out="$(printf '%s\n' "$prompt" | claude -p --model "$model" --tools "" --no-session-persistence)" \
    || { echo "the judge model failed" >&2; exit 1; }
fi

# 空行を除いた最初の 3 行を読む（行末の CR は落とす）
l1=""; l2=""; l3=""; i=0
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [ -n "${line//[[:space:]]/}" ] || continue
  i=$((i + 1))
  case "$i" in
    1) l1="$line" ;;
    2) l2="$line" ;;
    3) l3="$line"; break ;;
  esac
done <<EOF_OUT
$out
EOF_OUT

bad() { echo "the judge output is not in the expected form: $1" >&2; exit 1; }
case "$l1" in
  "判断: 通す"|"判断: 主に上げる") ;;
  *) bad "line 1: $l1" ;;
esac
case "$l2" in
  "理由: "?*) ;;
  *) bad "line 2: $l2" ;;
esac
case "$l3" in
  "返事:"|"返事: "*) ;;
  *) bad "line 3: $l3" ;;
esac
[ "$l3" = "返事:" ] && l3="返事: "

printf '%s\n%s\n%s\n記録: %s\n' "$l1" "$l2" "$l3" "$stop_url"
