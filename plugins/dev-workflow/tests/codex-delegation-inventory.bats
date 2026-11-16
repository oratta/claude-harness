#!/usr/bin/env bats
#
# Codex に委譲している全箇所の一覧表（docs/codex-delegation-inventory.md）と、実際の呼び出し元の突き合わせ（issue #324）
#
#   表に無いファイルが Codex の呼び出しの語を含むと落ちる（新しい呼び出し元を足したら表に 1 行足す）。
#   表にあるファイルが消えた・語を含まなくなったときも落ちる（古い行を残さない）。
#
# 検索から外すもの（記録・テスト・仕様本文）:
#   - 変更の記録: plugins/*/changes/ と CHANGELOG
#   - テスト: tests/ 配下（bats・Python とも。検査の対象であって呼び出し元ではない）
#   - openspec/: 要件の本文。呼び出しの手順ではなく、手順の正本は表の行が指すファイル
#   - archive と _longruns: 過去の記録
#   - 表そのもの

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  DOC_REL="plugins/dev-workflow/docs/codex-delegation-inventory.md"
  DOC="${REPO_ROOT}/${DOC_REL}"
  PATTERN='codex exec|codex-companion|codex-worker\.py|codex-develop\.py|codex-rescue|codex:adversarial-review|codex review'
}

# 検索の対象の一覧（リポジトリ相対パス）
callers() {
  cd "$REPO_ROOT" || return 1
  git ls-files -z | tr '\0' '\n' \
    | grep -vE '(^|/)(changes|tests|archive|_longruns)/|^openspec/|(^|/)CHANGELOG[^/]*$' \
    | grep -vxF "$DOC_REL" \
    | while IFS= read -r f; do
        [ -f "$f" ] && grep -qEI -- "$PATTERN" "$f" && printf '%s\n' "$f"
      done
}

# 表の行（`| `パス` | ... |`）の先頭列のパス
table_paths() {
  grep -E '^\| `[^`]+` \|' "$DOC" | sed -E 's/^\| `([^`]+)` \|.*/\1/'
}

@test "inventory doc exists" {
  [ -f "$DOC" ]
}

@test "every file that names a Codex call is in the table" {
  [ -f "$DOC" ]
  missing=""
  for f in $(callers); do
    table_paths | grep -qxF "$f" || missing="${missing}${f}"$'\n'
  done
  [ -z "$missing" ] || { printf 'not in the table:\n%s' "$missing" >&2; false; }
}

@test "every table row still names a Codex call in an existing file" {
  [ -f "$DOC" ]
  stale=""
  for f in $(table_paths); do
    [ -f "${REPO_ROOT}/${f}" ] && grep -qEI -- "$PATTERN" "${REPO_ROOT}/${f}" || stale="${stale}${f}"$'\n'
  done
  [ -z "$stale" ] || { printf 'stale rows:\n%s' "$stale" >&2; false; }
}

@test "every table row has a known class" {
  [ -f "$DOC" ]
  bad="$(grep -E '^\| `[^`]+` \|' "$DOC" | awk -F'|' '{gsub(/^ +| +$/,"",$4); if ($4!="移行済み" && $4!="残置" && $4!="言及のみ" && $4!="実装") print $0}')"
  [ -z "$bad" ] || { printf 'unknown class:\n%s\n' "$bad" >&2; false; }
}

@test "every table row names a role" {
  [ -f "$DOC" ]
  bad="$(grep -E '^\| `[^`]+` \|' "$DOC" | awk -F'|' '{gsub(/^ +| +$/,"",$3); if ($3=="") print $0}')"
  [ -z "$bad" ] || { printf 'empty role:\n%s\n' "$bad" >&2; false; }
}

@test "the table has no duplicate path" {
  [ -f "$DOC" ]
  [ -z "$(table_paths | sort | uniq -d)" ]
}
