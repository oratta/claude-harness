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
  printf '変更点の一覧\\|照合表\\|ハンク被覆\n' > "$REPO/other/escaped.txt"
  printf 'before `marker` after\n' > "$REPO/other/backtick.txt"
  git -C "$REPO" add .
  git -C "$REPO" commit -qm initial
  SHA="$(git -C "$REPO" rev-parse HEAD)"
}

write_reversible_table() {
  {
    printf '修正前 SHA: %s\n' "$SHA"
    printf "検索コマンド: git grep -n -E '変更点の一覧|before' <rev> -- .\n"
    printf '| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |\n'
    printf '| --- | ---: | :--- | --- |\n'
    printf '| other/escaped.txt | 1 | `変更点の一覧\\\\\\|照合表\\\\\\|ハンク被覆` | 一致 |\n'
    printf '| other/backtick.txt | 1 | ``before \\`marker\\` after`` | 一致 |\n'
  } > "$REPO/reversible.md"
}

write_table() {
  local handling_a="${1:-一致}" handling_b="${2:-直した}"
  {
    printf '修正前 SHA: %s\n' "$SHA"
    printf '検索コマンド: git grep -n needle <rev> -- .\n'
    printf '| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |\n'
    printf '|---|---:|---|---|\n'
    printf '| changed/a.txt | 1 | `needle one` | %s |\n' "$handling_a"
    printf '| other/b.txt | 1 | `needle two` | %s |\n' "$handling_b"
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
  [[ "$output" == *'missing: other/b.txt:1'* ]] || return 1
}

@test "review hit set (#355): extra table row exits one with file:line" {
  write_table
  printf '| ghost.txt | 9 | `needle ghost` | 一致 |\n' >> "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'extra: ghost.txt:9'* ]] || return 1
}

@test "review hit set (#355): narrowed or excluded tracked paths are rejected" {
  write_table
  sed -i.bak 's/-- \.$/-- changed/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1

  write_table
  sed -i.bak 's/<rev> -- \./<rev> -- . :(exclude)other/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
}

@test "review hit set (#355): escaped pipes and significant body whitespace are reversible" {
  write_table
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 0 ]
}

@test "review hit set (#355): spaced alignment separator cells are ignored" {
  write_table
  sed -i.bak 's/|---|---:|---|---|/| --- | ---: | :--- | --- |/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 0 ]
}

@test "review hit set (#355): repository backslash-pipe hit and backtick body round trip" {
  write_reversible_table
  run python3 "$CHECKER" --repo "$REPO" "$REPO/reversible.md"
  [ "$status" -eq 0 ]
}

@test "review hit set (#355): repo must be the repository root" {
  write_table
  run python3 "$CHECKER" --repo "$REPO/changed" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*repository*root* ]] || return 1
}

@test "review hit set (#355): grep options that reduce hit scope or count are rejected" {
  write_table
  sed -i.bak 's/git grep -n needle/git grep -n --max-count=1 needle/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1

  write_table
  sed -i.bak 's/git grep -n needle/git grep -n --max-depth=0 needle/' "$REPO/table.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/table.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
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
  [[ "$output" == *'contract:'* ]] || return 1
}

# ===== 順 3 の 2 段目（--head）と書き換えた「該当しない」行の補助表（issue #377） =====

# 修正前: r/x.txt に「直した」1 行と「該当しない」1 行、r/m.txt に同じ本文の行が 2 行（扱いが混在する組）
setup_head_repo() {
  mkdir -p "$REPO/r"
  printf 'needle fix\nneedle keep typo\n' > "$REPO/r/x.txt"
  printf 'needle same\nneedle same\n' > "$REPO/r/m.txt"
  git -C "$REPO" add .
  git -C "$REPO" commit -qm pre
  PRE="$(git -C "$REPO" rev-parse HEAD)"
}

# 修正後の内容を書いて commit し、HEAD を控える
commit_head() {
  printf "$1" > "$REPO/r/x.txt"
  printf "$2" > "$REPO/r/m.txt"
  git -C "$REPO" add .
  git -C "$REPO" commit -qm head
  HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
}

# 主表（順 3 の扱い）。第 1 引数は r/x.txt:2 の扱い。2 つ目以降の引数は補助表の行（そのまま出力）
write_row3_table() {
  local x2="${1:-該当しない: example}"
  shift || true
  {
    printf '## 一覧（順 3）\n'
    printf '修正前 SHA: %s\n' "$PRE"
    printf '検索コマンド: git grep -n needle <rev> -- .\n'
    printf '| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |\n'
    printf '|---|---:|---|---|\n'
    printf '| changed/a.txt | 1 | `needle one` | 該当しない: fixture |\n'
    printf '| other/b.txt | 1 | `needle two` | 該当しない: fixture |\n'
    printf '| other/c.txt | 1 | `    needle \\| three  ` | 該当しない: fixture |\n'
    printf '| r/m.txt | 1 | `needle same` | 直した |\n'
    printf '| r/m.txt | 2 | `needle same` | 該当しない: example |\n'
    printf '| r/x.txt | 1 | `needle fix` | 直した |\n'
    printf '| r/x.txt | 2 | `needle keep typo` | %s |\n' "$x2"
    if [ "$#" -gt 0 ]; then
      printf '\n### 書き換えた該当しない行\n'
      printf '| ファイル | 行（修正前 SHA） | 修正後の本文 |\n'
      printf '|---|---:|---|\n'
      for row in "$@"; do printf '%s\n' "$row"; done
    fi
  } > "$REPO/row3.md"
}

@test "review hit set (#377): all fixed rows removed and only not-applicable rows remain exits zero" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 0 ]
}

@test "review hit set (#377): a rewritten not-applicable row listed in the rewritten-rows table exits zero" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 2 | `needle keep fixed` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 0 ]
}

@test "review hit set (#377): a rewritten not-applicable row missing from the rewritten-rows table is unmatched" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'unmatched: r/x.txt:2'* ]]
}

@test "review hit set (#377): a fixed row still present at HEAD is unmatched" {
  setup_head_repo
  commit_head 'needle fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'unmatched: r/x.txt:1'* ]]
}

@test "review hit set (#377): rewriting only the not-applicable side of a mixed group reports the fixed row as not removed" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'needle same\nneedle same rewritten\n'
  write_row3_table '該当しない: example' '| r/m.txt | 2 | `needle same rewritten` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  # unmatched: が同時に出うるので、その不在は assert しない
  [[ "$output" == *'not-removed: r/m.txt:1'* ]]
}

@test "review hit set (#377): a rewritten-rows entry pointing at a fixed row is a contract violation" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 1 | `needle fix2` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]
}

@test "review hit set (#377): duplicate rewritten-rows entries are a contract violation" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 2 | `needle keep fixed` |' '| r/x.txt | 2 | `needle keep fixed` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]
}

@test "review hit set (#377): a rewritten-rows entry equal to the main-table body is a contract violation" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 2 | `needle keep typo` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]
}

@test "review hit set (#377): a handling value other than the two row-3 values is a contract violation with --head" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table '一致'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]]
}

@test "review hit set (#377): without --head the rewritten-rows table is ignored and the first stage is unchanged" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 1 | `anything` |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/row3.md"
  [ "$status" -eq 0 ]
}
