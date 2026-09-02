#!/usr/bin/env bash
# spec-touch-check.sh — PR が「規範を持ちうるパス」に触れているのに openspec/ に差分が無いかを報告する。
#
# 使い方: spec-touch-check.sh <owner/repo> <PR番号>
#   環境変数 SPEC_TOUCH_FILES（改行区切りのファイル一覧）があれば gh を呼ばずそれを使う（テスト用）。
#   カレントディレクトリに .spec-touch-paths（1 行 1 エントリ、# はコメント）があれば既定の規範パスを置き換える。
#   エントリは末尾 `/` ならディレクトリ prefix、それ以外はファイルパスの完全一致（CLAUDE.md.bak 等を拾わない）。
# 出力: SPEC_TOUCH=yes|no / OPENSPEC_DIFF=yes|no / 触れた規範パス（1 行 1 件）
# 終了コード: 0 = 正常 / 2 = 規範パスに触れて openspec/ 差分なし（注意喚起） / 1 = 引数不足・取得失敗・設定エラー
#
# 判定材料を出すだけで合否は決めない。合否は pr-review-gate 手順 5 が issue の「仕様化判断:」記録と突き合わせて決める。
# Bash 3.2（macOS 標準）で動くこと: 空配列の展開は ${arr[@]+"${arr[@]}"} 形を使う。
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <owner/repo> <PR番号>" >&2
  exit 1
fi
repo="$1"; pr="$2"

# 既定の規範パス。リポ直下の .spec-touch-paths があれば丸ごと置き換える。
prefixes=()
if [ -f .spec-touch-paths ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -n "$line" ] && prefixes+=("$line")
  done < .spec-touch-paths
  if [ "${#prefixes[@]}" -eq 0 ]; then
    echo ".spec-touch-paths has no entries (empty or comments only)" >&2
    exit 1
  fi
else
  prefixes=(docs/ .claude/ templates/ scripts/ CLAUDE.md AGENTS.md)
fi

if [ -n "${SPEC_TOUCH_FILES:-}" ]; then
  files="$SPEC_TOUCH_FILES"
else
  files="$(gh pr diff "$pr" --repo "$repo" --name-only 2>/dev/null)" || { echo "failed to fetch PR files: $repo#$pr" >&2; exit 1; }
fi

touched=()
openspec_diff=no
seen=0
# here-string は一時ファイルを要するので使わない（作れない環境で fail-open になる）。プロセス置換で流す。
while IFS= read -r f; do
  [ -z "$f" ] && continue
  seen=$((seen + 1))
  case "$f" in openspec/*) openspec_diff=yes ;; esac
  for p in ${prefixes[@]+"${prefixes[@]}"}; do
    case "$p" in
      */) case "$f" in "$p"*) touched+=("$f"); break ;; esac ;;
      *)  [ "$f" = "$p" ] && { touched+=("$f"); break; } ;;
    esac
  done
done < <(printf '%s\n' "$files")

if [ "$seen" -eq 0 ]; then
  echo "no changed files were read (input setup failed?)" >&2
  exit 1
fi

if [ "${#touched[@]}" -gt 0 ]; then echo "SPEC_TOUCH=yes"; else echo "SPEC_TOUCH=no"; fi
echo "OPENSPEC_DIFF=$openspec_diff"
for t in ${touched[@]+"${touched[@]}"}; do echo "$t"; done

if [ "${#touched[@]}" -gt 0 ] && [ "$openspec_diff" = no ]; then exit 2; fi
exit 0
