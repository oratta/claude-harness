#!/usr/bin/env bash
# risk-carryover-check.sh — 前の HEAD で主が許容したリスクを、新しい HEAD に引き継げるかを git の履歴だけで判定する。
#
# 使い方: risk-carryover-check.sh [--base <ref>] <前 HEAD> <新 HEAD> <根拠ファイル>...
#   --base の既定は origin/main。ローカルの git リポジトリだけを読む（gh を呼ばない）。
# 判定:
#   1. 前 HEAD が新 HEAD の祖先
#   2. `git rev-list <新> ^<前> ^<base>` のうち merge commit はすべて 2 親で、第 2 親が base の祖先、
#      第 1 親が前 HEAD かこの集合の別の commit。merge commit でない commit は PR 自身の commit として
#      PR_COMMITS= で数え、NG にしない（#1238）
#   3. 各 merge commit で `git merge-tree --write-tree <第1親> <第2親>` の tree と実 tree に差があるファイル
#      （衝突解消したファイル。`git diff --no-renames` で列挙し、rename は削除と追加に分けて数える）が
#      許可リストに入り、中身の条件を満たす:
#        .claude-plugin/marketplace.json・plugins/<名前>/.claude-plugin/plugin.json
#          → "version" を含む行を除いた本文が第 1 親か第 2 親の版と一致
#        CHANGELOG.md（サブディレクトリを含む）
#          → merge commit の版のすべての行が第 1 親か第 2 親の版に存在する
#   4. 根拠ファイルそれぞれで（パスはリポジトリのルート相対で、GIT_LITERAL_PATHSPECS=1 により glob ではなく字句どおりに扱う）、`git diff <前> <新> -- <ファイル>` が空か、
#      空でなくても「PR 自身の差分」が前後で同じで、PR 自身の commit がそのファイルに触れていない（#1238・#1303）。
#      PR 自身の差分 = その HEAD と base の merge-base からその HEAD までのそのファイルの差分
#        （前は <merge-base(前, base)>..<前>、新は <merge-base(新, base)>..<新>）。
#      比べ方 = `git diff -U0` の mode の行（old mode・new mode・new file mode・deleted file mode）と、最初の `@@` より
#        後ろにある `-`・`+`・`\` で始まる行だけを、出てくる順のまま文字列で比べる（ハンクの見出しの行番号・
#        ほかの頭の行・文脈の行は比べない。main が別の場所を変えても同じになる）。
#      同じで、2 の merge commit でない commit のどれもそのファイルに触れていなければ EVIDENCE_MAIN_ONLY=<ファイル>、
#      違うか、merge commit でない commit のどれかが触れていれば（commit ごとに `git diff --quiet --no-renames <親> <commit> -- <ファイル>`
#      が終了コード 1。mode だけの変更を含む。0 と 1 以外は git の失敗として終了コード 2）EVIDENCE_PR_CHANGED=<ファイル>。比べ方は行の位置を見ないので、PR 自身の commit が
#      自分の行を別の位置へ動かしただけでも main 由来と取り違えないよう、触れたら同じでも EVIDENCE_PR_CHANGED にする（#1303）。
#      前後の diff が空でない根拠ファイルについて、前後の HEAD の diff か各 HEAD の PR 自身の差分のどちらかで
#      バイナリとして扱われるとき（numstat が `-`）と、merge-base が 1 つに決まらないときは NG。
# 1・2 のどれかが外れたとき、4 でバイナリか merge-base の NG が出たときは NG: 行を出す。3 だけが外れたファイル
# （許可リストの条件を満たさない衝突解消 = 許可リストに無いファイル・許可リストのファイルで中身の条件を満たさないもの・
# 衝突していないファイルへの手入れ）は NG にせず RESOLVED_OUTSIDE_ALLOWLIST=<ファイル> の行で出す（#694）。
# 出力: CARRYOVER=yes|if-rereviewed|if-judged|no / MAIN_MERGES=<件数> / PR_COMMITS=<merge commit でない commit の件数>
#       / RESOLVED_FILES=<カンマ区切り。無ければ none> / RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>（該当ファイルごとに 1 行）
#       / EVIDENCE_MAIN_ONLY=<ファイル>・EVIDENCE_PR_CHANGED=<ファイル>（該当ファイルごとに 1 行）
#       / EVIDENCE_DIFF_LINES=<EVIDENCE_PR_CHANGED のファイルの `git diff --numstat <前> <新>` の追加と削除の合計。無ければ 0>
#       / 不可の理由ごとに NG: <理由>
# 終了コード（優先順 1 → 4 → 3 → 0）: 0 = 無条件で引き継げる
#   / 3 = 新しい HEAD で PR 全体を見たレビューを経ていれば引き継げる（NG も EVIDENCE_PR_CHANGED も無く、
#     許可リストの条件を満たさない衝突解消だけがある）
#   / 4 = 根拠ファイルの PR 自身の差分が前後で違うか、PR 自身の commit が根拠ファイルに触れた（NG は無い）。リスクの中身が同じかを git の履歴だけでは
#     決められないという意味で、スクリプトは引き継げるかを決めない（pr-review-gate 手順 3-c が扱う）
#   / 1 = 引き継げない（NG あり）
#   / 2 = 引数不足・SHA が解決できない・根拠ファイルなし・根拠ファイルが前後どちらの HEAD にも無い・git が古い・git diff が失敗した（引き継げない側）
#
# 許容の真正性・リスクの中身の同一性・終了コード 3 のときのレビューの確認はここでは見ない
# （pr-review-gate 手順 3-c で G が確かめる）。
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

# pathspec をルート相対に固定する（git diff -- <pathspec> は cwd 相対、git show <rev>:<path> はルート相対のため）
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repository" >&2; exit 2; }
cd "$top"
# 根拠ファイルのパスは glob ではなく字句どおりの名前として扱う（`ev[1].txt` を `ev1.txt` に当てない。#1303）
export GIT_LITERAL_PATHSPECS=1

resolve() {
  git rev-parse -q --verify "$1^{commit}" 2>/dev/null || { echo "cannot resolve: $1" >&2; exit 2; }
}
prev="$(resolve "$prev_ref")"
new="$(resolve "$new_ref")"
base="$(resolve "$base_ref")"

ng=()
resolved=()
outside=()
main_only=()
pr_changed=()
pr_own_commits=()
merges=0
pr_commits=0
diff_lines=0

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

# 根拠ファイルの PR 自身の差分（-U0 の削除・追加・改行なしの印の行を順序のまま）を出す。引数: HEAD ファイル
# mode の行（old mode・new mode・new file mode・deleted file mode）も比べる対象に含める（mode だけの変更を拾うため）。
# HEAD と base の merge-base が 1 つに決まらないか git diff が失敗すれば 1、merge-base から HEAD までの差分で
# バイナリとして扱われれば（numstat が `-`）3 を返す
pr_own_diff() {
  local h="$1" f="$2" mbs n ns
  mbs="$(git merge-base --all "$h" "$base")" || return 1
  n="$(printf '%s\n' "$mbs" | grep -c . || true)"
  [ "$n" -eq 1 ] || return 1
  ns="$(git diff --numstat --no-renames "$mbs" "$h" -- "$f")" || return 1
  if printf '%s\n' "$ns" | grep -q '^-'; then return 3; fi
  git diff -U0 --no-color --no-ext-diff --no-textconv "$mbs" "$h" -- "$f" \
    | awk '!started && /^(old|new) mode |^(new|deleted) file mode / { print; next } started && /^[-+\\]/ { print; next } /^@@/ { started = 1 }' \
    || return 1
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
      pr_commits=$((pr_commits + 1))
      # 判定 4 で、PR 自身の commit が根拠ファイルに触れたかを git diff --quiet で見るために「親 commit」の組を控える（#1303）
      pr_own_commits+=("$parents $c")
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
        outside+=("$f")
      fi
    # 非 ASCII のパスは core.quotePath により quote された形で出る（許可リストは ASCII のみなので判定は outside のまま。出力の表記だけが quote 形）
    done < <(git diff --no-renames --name-only "$auto_tree" "$c")
  done < <(printf '%s\n' "$set_list")
fi

for f in "${evidence[@]}"; do
  if ! git cat-file -e "$prev:$f" 2>/dev/null && ! git cat-file -e "$new:$f" 2>/dev/null; then
    echo "evidence file not found at either HEAD: $f" >&2
    exit 2
  fi
  rc=0
  git diff --quiet "$prev" "$new" -- "$f" || rc=$?
  if [ "$rc" -eq 0 ]; then
    continue
  elif [ "$rc" -ne 1 ]; then
    echo "git diff failed for $f" >&2
    exit 2
  fi
  numstat="$(git diff --numstat --no-renames "$prev" "$new" -- "$f")"
  if printf '%s\n' "$numstat" | grep -q '^-'; then
    ng+=("binary evidence file changed between prev and new HEAD: $f")
    continue
  fi
  rc=0
  prev_diff="$(pr_own_diff "$prev" "$f")" || rc=$?
  [ "$rc" -ne 0 ] || { new_diff="$(pr_own_diff "$new" "$f")" || rc=$?; }
  if [ "$rc" -eq 3 ]; then
    ng+=("binary evidence file at merge-base or HEAD: $f (the PR's own diff cannot be compared)")
    continue
  elif [ "$rc" -ne 0 ]; then
    ng+=("cannot determine a unique merge-base with $base_ref for prev or new HEAD (or git diff failed); cannot compare the PR's own diff of $f")
    continue
  fi
  # PR 自身の commit がこのファイルに触れたか（パスの一覧を文字列で照合せず、pathspec の解釈を git に任せる。
  # 終了コード 1 = 触れた、0 = 触れていない、それ以外 = git の失敗で引き継げない側。#1303）
  # PR 自身の差分が既に違うときは終了コード 4 が決まっているので回さない
  touched=0
  if [ "$prev_diff" = "$new_diff" ]; then
    for pc in ${pr_own_commits[@]+"${pr_own_commits[@]}"}; do
      rc=0
      git diff --quiet --no-renames "${pc%% *}" "${pc#* }" -- "$f" || rc=$?
      if [ "$rc" -eq 1 ]; then
        touched=1
        break
      elif [ "$rc" -ne 0 ]; then
        echo "git diff failed for $f in ${pc#* }" >&2
        exit 2
      fi
    done
  fi
  if [ "$prev_diff" = "$new_diff" ] && [ "$touched" -eq 0 ]; then
    main_only+=("$f")
  else
    pr_changed+=("$f")
    while IFS=$'\t' read -r a d _; do
      [ -z "$a" ] && continue
      diff_lines=$((diff_lines + a + d))
    done < <(printf '%s\n' "$numstat")
  fi
done

if [ "${#ng[@]}" -ne 0 ]; then echo "CARRYOVER=no"
elif [ "${#pr_changed[@]}" -ne 0 ]; then echo "CARRYOVER=if-judged"
elif [ "${#outside[@]}" -ne 0 ]; then echo "CARRYOVER=if-rereviewed"
else echo "CARRYOVER=yes"; fi
echo "MAIN_MERGES=$merges"
echo "PR_COMMITS=$pr_commits"
if [ "${#resolved[@]}" -eq 0 ]; then
  echo "RESOLVED_FILES=none"
else
  echo "RESOLVED_FILES=$(printf '%s\n' "${resolved[@]}" | sort -u | paste -sd, -)"
fi
if [ "${#outside[@]}" -ne 0 ]; then
  printf '%s\n' "${outside[@]}" | sort -u | sed 's/^/RESOLVED_OUTSIDE_ALLOWLIST=/'
fi
for f in ${main_only[@]+"${main_only[@]}"}; do echo "EVIDENCE_MAIN_ONLY=$f"; done
for f in ${pr_changed[@]+"${pr_changed[@]}"}; do echo "EVIDENCE_PR_CHANGED=$f"; done
echo "EVIDENCE_DIFF_LINES=$diff_lines"
for n in ${ng[@]+"${ng[@]}"}; do echo "NG: $n"; done

[ "${#ng[@]}" -eq 0 ] || exit 1
[ "${#pr_changed[@]}" -eq 0 ] || exit 4
[ "${#outside[@]}" -eq 0 ] || exit 3
exit 0
