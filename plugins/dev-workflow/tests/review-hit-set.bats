#!/usr/bin/env bats

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CHECKER="${PLUGIN_DIR}/scripts/review-hit-set.py"
  REPO="$(mktemp -d "${BATS_TEST_TMPDIR}/repo.XXXXXX")"
  git -C "$REPO" init -q
  git -C "$REPO" config user.name test
  git -C "$REPO" config user.email test@example.com
  mkdir -p "$REPO/changed" "$REPO/other"
  printf 'needle one\n' > "$REPO/changed/a.txt"
  printf 'needle two\n' > "$REPO/other/b.txt"
  printf '    needle | three  \n' > "$REPO/other/c.txt"
  git -C "$REPO" add .
  git -C "$REPO" commit -qm initial
  SHA="$(git -C "$REPO" rev-parse HEAD)"
}

write_table() {
  local handling_a="${1:-一致}" handling_b="${2:-直した}"
  {
    printf '修正前 SHA: %s\n' "$SHA"
    printf '検索コマンド: git grep -n needle <rev> -- .\n'
    printf '| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |\n'
    printf '|---|---:|---|---|\n'
    printf '| changed/a.txt | 1 | needle one | %s |\n' "$handling_a"
    printf '| other/b.txt | 1 | needle two | %s |\n' "$handling_b"
    printf '| other/c.txt | 1 | `    needle \\| three  ` | 一致 |\n'
  } > "$REPO/table.md"
}

@test "review hit set (#355): matching repository-wide table exits zero regardless of handling values" {
  write_table '一致' '食い違い: F-1'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 0 ]
  write_table '直した' '該当しない: intentional'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 0 ]
}

@test "review hit set (#355): missing unchanged-directory hit exits one with file:line" {
  write_table
  sed -i.bak '/other\/b.txt/d' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'missing: other/b.txt:1'* ]]
}

@test "review hit set (#355): extra table row exits one with file:line" {
  write_table
  printf '| ghost.txt | 9 | needle ghost | 一致 |\n' >> "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'extra: ghost.txt:9'* ]]
}

@test "review hit set (#355): narrowed or excluded tracked paths are rejected" {
  write_table
  sed -i.bak 's/-- \.$/-- changed/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]

  write_table
  sed -i.bak 's/<rev> -- \./<rev> -- . :(exclude)other/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]
}

@test "review hit set (#355): escaped pipes and significant body whitespace are reversible" {
  write_table
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 0 ]
}

@test "review hit set (#355): repo must be the repository root" {
  write_table
  run python3 "$CHECKER" --repo "$REPO/changed" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*repository*root* ]]
}

@test "review hit set (#355): grep options that reduce hit scope or count are rejected" {
  write_table
  sed -i.bak 's/git grep -n needle/git grep -n --max-count=1 needle/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]

  write_table
  sed -i.bak 's/git grep -n needle/git grep -n --max-depth=0 needle/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]
}

@test "review hit set (#355): case-axis table is not an input to the grep checker" {
  cat > "$REPO/axis.md" <<EOF
修正前 SHA: $SHA
検索コマンド: 軸=先頭バイト、全域=0x00〜0xFF
| 軸の値 | 扱い |
|---|---|
| 0x00〜0xFF | 該当しない: full domain |
EOF
  run python3 "$CHECKER" --repo "$REPO" "$REPO/axis.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]
}
