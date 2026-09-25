#!/usr/bin/env bash
# risk-carryover-check.sh — 前の HEAD で主が許容したリスクを、新しい HEAD に引き継げるかを git の履歴だけで判定する。
#
# 使い方: risk-carryover-check.sh [--base <ref>] <前 HEAD> <新 HEAD> <根拠ファイル>...
#   --base の既定は origin/main。ローカルの git リポジトリだけを読む（gh を呼ばない）。
# 判定（すべて満たせば引き継げる）:
#   1. 前 HEAD が新 HEAD の祖先
#   2. `git rev-list <新> ^<前> ^<base>` の全件が 2 親の merge commit で、第 2 親が base の祖先、
#      第 1 親が前 HEAD かこの集合の別の commit
#   3. 各 merge commit で `git merge-tree --write-tree <第1親> <第2親>` の tree と実 tree に差があるファイル
#      （衝突解消したファイル）が許可リストに入り、中身の条件を満たす:
#        .claude-plugin/marketplace.json・plugins/<名前>/.claude-plugin/plugin.json
#          → "version" を含む行を除いた本文が第 1 親か第 2 親の版と一致
#        CHANGELOG.md（サブディレクトリを含む）
#          → merge commit の版のすべての行が第 1 親か第 2 親の版に存在する
#   4. 根拠ファイルそれぞれで `git diff <前> <新> -- <ファイル>` が空
# 出力: CARRYOVER=yes|no / MAIN_MERGES=<件数> / RESOLVED_FILES=<カンマ区切り。無ければ none> / 不可の理由ごとに NG: <理由>
# 終了コード: 0 = 引き継げる / 1 = 引き継げない / 2 = 引数不足・SHA が解決できない・根拠ファイルなし・git が古い（引き継げない側）
#
# 許容の真正性とリスクの中身の同一性はここでは見ない（pr-review-gate 手順 3-c で G が確かめる）。
# Bash 3.2（macOS 標準）で動くこと: 空配列の展開は ${arr[@]+"${arr[@]}"} 形を使う。
set -euo pipefail

usage() {
  echo "usage: $0 [--base <ref>] <prev HEAD> <new HEAD> <evidence file>..." >&2
  exit 2
}

base_ref=origin/main
if [ "${1:-}" = "--base" ]; then
  [ $# -ge 2 ] || usage
  base_ref="$2"
  shift 2
fi
[ $# -ge 3 ] || usage
prev_ref="$1"; new_ref="$2"; shift 2
evidence=("$@")

# git merge-tree --write-tree は git 2.38 から
ver="$(git version | sed -n 's/^git version \([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1 \2/p')"
major="${ver%% *}"; minor="${ver#* }"
if [ -z "$ver" ] || [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 38 ]; }; then
  echo "git 2.38 or later is required (merge-tree --write-tree)" >&2
  exit 2
fi

resolve() {
  git rev-parse -q --verify "$1^{commit}" 2>/dev/null || { echo "cannot resolve: $1" >&2; exit 2; }
}
prev="$(resolve "$prev_ref")"
new="$(resolve "$new_ref")"
base="$(resolve "$base_ref")"

ng=()
resolved=()
merges=0

# 許可リストの判定。引数: merge commit 第1親 第2親 ファイル。許せば 0
json_ok() {
  local c="$1" p1="$2" p2="$3" f="$4" mine p
  mine="$(git show "$c:$f" 2>/dev/null | grep -v '"version"')" || return 1
  for p in "$p1" "$p2"; do
    if git cat-file -e "$p:$f" 2>/dev/null && [ "$(git show "$p:$f" | grep -v '"version"' || true)" = "$mine" ]; then
      return 0
    fi
  done
  return 1
}

changelog_ok() {
  local c="$1" p1="$2" p2="$3" f="$4" extra
  git cat-file -e "$c:$f" 2>/dev/null || return 1
  extra="$(git show "$c:$f" | grep -Fxv -f <( { git show "$p1:$f" 2>/dev/null || true; git show "$p2:$f" 2>/dev/null || true; } ) || true)"
  [ -z "$extra" ]
}

allowed() {
  local c="$1" p1="$2" p2="$3" f="$4" mid
  case "$f" in
    .claude-plugin/marketplace.json) json_ok "$c" "$p1" "$p2" "$f" ;;
    plugins/*/.claude-plugin/plugin.json)
      mid="${f#plugins/}"; mid="${mid%/.claude-plugin/plugin.json}"
      case "$mid" in */*) return 1 ;; esac
      json_ok "$c" "$p1" "$p2" "$f" ;;
    CHANGELOG.md|*/CHANGELOG.md) changelog_ok "$c" "$p1" "$p2" "$f" ;;
    *) return 1 ;;
  esac
}

if ! git merge-base --is-ancestor "$prev" "$new"; then
  ng+=("prev HEAD $prev is not an ancestor of new HEAD $new (history rewritten)")
else
  set_list="$(git rev-list "$new" "^$prev" "^$base")"
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    parents="$(git rev-list --parents -n 1 "$c" | cut -d' ' -f2-)"
    nparents="$(printf '%s\n' "$parents" | wc -w | tr -d ' ')"
    if [ "$nparents" -eq 1 ]; then
      ng+=("non-main commit $c (not a merge commit)")
      continue
    elif [ "$nparents" -ne 2 ]; then
      ng+=("merge commit $c has $nparents parents (only 2-parent merges are allowed)")
      continue
    fi
    p1="${parents%% *}"; p2="${parents#* }"
    merges=$((merges + 1))
    if ! git merge-base --is-ancestor "$p2" "$base"; then
      ng+=("non-main merge $c (second parent $p2 is not in $base_ref)")
      continue
    fi
    if [ "$p1" != "$prev" ] && ! printf '%s\n' "$set_list" | grep -qx "$p1"; then
      ng+=("merge commit $c has first parent $p1 outside the PR history")
      continue
    fi
    rc=0
    auto_tree="$(git merge-tree --write-tree "$p1" "$p2" 2>/dev/null | sed -n 1p)" || rc=$?
    if [ "$rc" -gt 1 ] || [ -z "$auto_tree" ]; then
      echo "git merge-tree failed for $c" >&2
      exit 2
    fi
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      resolved+=("$f")
      if ! allowed "$c" "$p1" "$p2" "$f"; then
        ng+=("conflict resolution in $c not allowed: $f")
      fi
    done < <(git diff --name-only "$auto_tree" "$c")
  done < <(printf '%s\n' "$set_list")
fi

for f in "${evidence[@]}"; do
  rc=0
  git diff --quiet "$prev" "$new" -- "$f" || rc=$?
  if [ "$rc" -eq 1 ]; then
    ng+=("evidence file changed between prev and new HEAD: $f")
  elif [ "$rc" -ne 0 ]; then
    echo "git diff failed for $f" >&2
    exit 2
  fi
done

if [ "${#ng[@]}" -eq 0 ]; then echo "CARRYOVER=yes"; else echo "CARRYOVER=no"; fi
echo "MAIN_MERGES=$merges"
if [ "${#resolved[@]}" -eq 0 ]; then
  echo "RESOLVED_FILES=none"
else
  echo "RESOLVED_FILES=$(printf '%s\n' "${resolved[@]}" | sort -u | paste -sd, -)"
fi
for n in ${ng[@]+"${ng[@]}"}; do echo "NG: $n"; done

[ "${#ng[@]}" -eq 0 ] || exit 1
exit 0
