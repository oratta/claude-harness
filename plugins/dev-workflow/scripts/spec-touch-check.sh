#!/usr/bin/env bash
# spec-touch-check.sh — PR が「規範を持ちうるパス」に触れているのに openspec/ に差分が無いかを報告する。
#
# 使い方: spec-touch-check.sh <owner/repo> <PR番号>
#   環境変数 SPEC_TOUCH_FILES（改行区切りのファイル一覧）があれば gh を呼ばずそれを使う（テスト用）。
#   カレントディレクトリに .spec-touch-paths（1 行 1 prefix、# はコメント）があれば既定の規範パスを置き換える。
# 出力: SPEC_TOUCH=yes|no / OPENSPEC_DIFF=yes|no / 触れた規範パス（1 行 1 件）
# 終了コード: 0 = 正常 / 2 = 規範パスに触れて openspec/ 差分なし（注意喚起） / 1 = 引数不足・取得失敗
#
# 判定材料を出すだけで合否は決めない。合否は pr-review-gate 手順 5 が issue の「仕様化判断:」記録と突き合わせて決める。
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <owner/repo> <PR番号>" >&2
  exit 1
fi
repo="$1"; pr="$2"

# 既定の規範パス。リポ直下の .spec-touch-paths があれば丸ごと置き換える。
default_prefixes=(docs/ .claude/ templates/ scripts/ CLAUDE.md AGENTS.md)
prefixes=()
if [ -f .spec-touch-paths ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"; line="${line## }"; line="${line%% }"
    [ -n "$line" ] && prefixes+=("$line")
  done < .spec-touch-paths
else
  prefixes=("${default_prefixes[@]}")
fi

if [ -n "${SPEC_TOUCH_FILES:-}" ]; then
  files="$SPEC_TOUCH_FILES"
else
  files="$(gh pr diff "$pr" --repo "$repo" --name-only 2>/dev/null)" || { echo "failed to fetch PR files: $repo#$pr" >&2; exit 1; }
fi

touched=()
openspec_diff=no
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in openspec/*) openspec_diff=yes ;; esac
  for p in "${prefixes[@]}"; do
    case "$f" in
      "$p"|"$p"*) touched+=("$f"); break ;;
    esac
  done
done <<< "$files"

if [ "${#touched[@]}" -gt 0 ]; then echo "SPEC_TOUCH=yes"; else echo "SPEC_TOUCH=no"; fi
echo "OPENSPEC_DIFF=$openspec_diff"
for t in "${touched[@]+"${touched[@]}"}"; do echo "$t"; done

if [ "${#touched[@]}" -gt 0 ] && [ "$openspec_diff" = no ]; then exit 2; fi
exit 0
