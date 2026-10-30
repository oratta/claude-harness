#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  export LC_ALL=C.UTF-8
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
  [[ "$output" == *'unmatched: r/x.txt:2'* ]] || return 1
}

@test "review hit set (#377): a fixed row still present at HEAD is unmatched" {
  setup_head_repo
  commit_head 'needle fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'unmatched: r/x.txt:1'* ]] || return 1
}

@test "review hit set (#377): rewriting only the not-applicable side of a mixed group reports the fixed row as not removed" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'needle same\nneedle same rewritten\n'
  write_row3_table '該当しない: example' '| r/m.txt | 2 | `needle same rewritten` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  # unmatched: が同時に出うるので、その不在は assert しない
  [[ "$output" == *'not-removed: r/m.txt:1'* ]] || return 1
}

@test "review hit set (#377): a rewritten-rows entry pointing at a fixed row is a contract violation" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 1 | `needle fix2` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
}

@test "review hit set (#377): duplicate rewritten-rows entries are a contract violation" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 2 | `needle keep fixed` |' '| r/x.txt | 2 | `needle keep fixed` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
}

@test "review hit set (#377): a rewritten-rows entry equal to the main-table body is a contract violation" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 2 | `needle keep typo` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
}

@test "review hit set (#377): a handling value other than the two row-3 values is a contract violation with --head" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table '一致'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
}

@test "review hit set (#377): without --head the rewritten-rows table is ignored and the first stage is unchanged" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' '| r/x.txt | 1 | `anything` |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/row3.md"
  [ "$status" -eq 0 ]
}

# ===== 順 3 違反の蓄積（issue #406） =====

@test "review hit set (#406): the rewritten-rows table can report two violations at once" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' \
    '| r/x.txt | 1 | `needle fix2` |' \
    '| r/m.txt | 2 | `needle same` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract: rewritten row must point at one not-applicable row: r/x.txt:1'* ]] || return 1
  [[ "$output" == *'contract: rewritten row body is unchanged: r/m.txt:2'* ]] || return 1
}

@test "review hit set (#406): a main-table handling violation and a rewritten-rows violation are both reported" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table '一致' \
    '| r/m.txt | 2 | `needle same different` |' \
    '| r/m.txt | 2 | `needle same different` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract: row-3 handling must be 直した or 該当しない: <理由>: r/x.txt:2'* ]] || return 1
  [[ "$output" == *'contract: rewritten row is duplicated: r/m.txt:2'* ]] || return 1
}

@test "review hit set (#406): a contract violation suppresses the second-stage unmatched/not-removed diff" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table '該当しない: example' \
    '| r/m.txt | 2 | `needle same different` |' \
    '| r/m.txt | 2 | `needle same different` |'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract: rewritten row is duplicated: r/m.txt:2'* ]] || return 1
  [[ "$output" != *'unmatched:'* ]] || return 1
  [[ "$output" != *'not-removed:'* ]] || return 1
}

@test "review hit set (#406): missing header or mismatched columns still stop immediately as a structural error" {
  cat > "$REPO/no-header.md" <<EOF
修正前 SHA: $SHA
検索コマンド: git grep -n needle <rev> -- .
| foo | bar |
|---|---|
| changed/a.txt | needle one |
EOF
  run python3 "$CHECKER" --repo "$REPO" "$REPO/no-header.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*'header'* ]] || return 1

  cat > "$REPO/bad-columns.md" <<EOF
修正前 SHA: $SHA
検索コマンド: git grep -n needle <rev> -- .
| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |
|---|---:|---|---|
| changed/a.txt | 1 | \`needle one\` |
EOF
  run python3 "$CHECKER" --repo "$REPO" "$REPO/bad-columns.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*'columns'* ]] || return 1
}

# ===== 補助表の見出し表記ゆれ・主表の重複・エラー文言（issue #407, #408, #409） =====

# 補助表を、指定した見出し行つきで主表の後ろに足した表を作る（見出しが正しければ exit 0 になる内容）
write_row3_table_with_heading() {
  write_row3_table
  {
    printf '\n%s\n' "$1"
    printf '| ファイル | 行（修正前 SHA） | 修正後の本文 |\n'
    printf '|---|---:|---|\n'
    printf '| r/x.txt | 2 | `needle keep fixed` |\n'
  } >> "$REPO/row3.md"
}

@test "review hit set (#407): a rewritten-rows table under a quoted heading is a contract error naming the correct heading" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table_with_heading '### 書き換えた「該当しない」行'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
  [[ "$output" == *'### 書き換えた該当しない行'* ]] || return 1
  [[ "$output" != *'unmatched:'* ]] || return 1
}

@test "review hit set (#407): a rewritten-rows table under a wrong heading level is a contract error naming the correct heading" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table_with_heading '## 書き換えた該当しない行'
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
  [[ "$output" == *'### 書き換えた該当しない行'* ]] || return 1
}

@test "review hit set (#407): with no rewritten-rows table at all the result is still the unmatched report" {
  setup_head_repo
  commit_head 'done fix\nneedle keep fixed\n' 'done same\nneedle same\n'
  write_row3_table
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'unmatched: r/x.txt:2'* ]] || return 1
  [[ "$output" != *'contract:'* ]] || return 1
}

@test "review hit set (#408): a duplicated (file, line) in the main table is a contract error with --head" {
  setup_head_repo
  commit_head 'done fix\nneedle keep typo\n' 'done same\nneedle same\n'
  write_row3_table
  printf '| r/x.txt | 2 | `needle keep typo` | 該当しない: example |\n' >> "$REPO/row3.md"
  run python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$REPO/row3.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract: main table row is duplicated: r/x.txt:2'* ]] || return 1
}

@test "review hit set (#409): contract error wording without --head is the pre-#377 wording" {
  cat > "$REPO/bad-columns.md" <<EOF
修正前 SHA: $SHA
検索コマンド: git grep -n needle <rev> -- .
| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |
|---|---:|---|---|
| changed/a.txt | 1 | \`needle one\` |
EOF
  run python3 "$CHECKER" --repo "$REPO" "$REPO/bad-columns.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'every hit row must have four columns'* ]] || return 1

  cat > "$REPO/bad-row.md" <<EOF
修正前 SHA: $SHA
検索コマンド: git grep -n needle <rev> -- .
| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |
|---|---:|---|---|
| changed/a.txt | x | \`needle one\` | 一致 |
EOF
  run python3 "$CHECKER" --repo "$REPO" "$REPO/bad-row.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'hit rows require path, numeric line, and body'* ]] || return 1
}

# ===== 件数の多い語の全ヒット要約（issue #1457） =====

# 語 bulk が N 行ヒットするファイルを足して commit し、固定 SHA を BULK_SHA に控える。
# 第 2 引数以降は commit する前に実行するコマンド（追加のファイルを置く）
commit_bulk() {
  local count="$1"
  shift
  seq 1 "$count" | sed 's/^/bulk /' > "$REPO/bulk.txt"
  if [ "$#" -gt 0 ]; then "$@"; fi
  git -C "$REPO" add .
  git -C "$REPO" commit -qm bulk
  BULK_SHA="$(git -C "$REPO" rev-parse HEAD)"
}

# 指示ブロックと同じパイプで行数とハッシュを求める。引数は語の指定（既定は bulk）
measure() {
  [ "$#" -gt 0 ] || set -- bulk
  COUNT="$(git -C "$REPO" grep -n "$@" "$BULK_SHA" -- . | wc -l | tr -d ' ')"
  DIGEST="$(git -C "$REPO" grep -n "$@" "$BULK_SHA" -- . | git -C "$REPO" hash-object --stdin)"
}

# 要約の表を書く。第 1 引数は `全ヒット要約:` の値、残りは 4 列の表の行（無ければ表を省く）。
# 検索コマンドは SEARCH で差し替えられる
write_summary() {
  local summary="$1"
  shift
  {
    printf '修正前 SHA: %s\n' "$BULK_SHA"
    printf '検索コマンド: %s\n' "${SEARCH:-git grep -n bulk <rev> -- .}"
    printf '全ヒット要約: %s\n' "$summary"
    if [ "$#" -gt 0 ]; then
      printf '| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |\n'
      printf '|---|---:|---|---|\n'
      for row in "$@"; do printf '%s\n' "$row"; done
    fi
  } > "$REPO/summary.md"
}

@test "hit summary (#1457): a 2,100-hit word with a matching summary exits zero without a four-column table" {
  commit_bulk 2100
  measure
  [ "$COUNT" -eq 2100 ]
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hit summary (#1457): a mismatch row under the summary exits zero" {
  commit_bulk 60
  measure
  write_summary "$COUNT 行 $DIGEST" '| bulk.txt | 3 | `bulk 3` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]
}

@test "hit summary (#1457): shell pipeline values match the checker with a read-only .git and a quoted search" {
  commit_bulk 60
  export SEARCH="git grep -n -E 'bulk|needle' <rev> -- ."
  measure -E 'bulk|needle'
  write_summary "$COUNT 行 $DIGEST"
  chmod -R a-w "$REPO/.git"
  COUNT_AGAIN="$(git -C "$REPO" grep -n -E 'bulk|needle' "$BULK_SHA" -- . | wc -l | tr -d ' ')"
  DIGEST_AGAIN="$(git -C "$REPO" grep -n -E 'bulk|needle' "$BULK_SHA" -- . | git -C "$REPO" hash-object --stdin)"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  chmod -R u+w "$REPO/.git"
  [ "$status" -eq 0 ]
  [ "$COUNT_AGAIN" = "$COUNT" ]
  [ "$DIGEST_AGAIN" = "$DIGEST" ]
}

add_narrowed_hits() {
  seq 1 60 | sed 's/^/bulk /' > "$REPO/changed/many.txt"
}

@test "hit summary (#1457): a narrowed search is rejected even when count and digest match the narrowed output" {
  commit_bulk 60 add_narrowed_hits
  COUNT="$(git -C "$REPO" grep -n bulk "$BULK_SHA" -- changed | wc -l | tr -d ' ')"
  DIGEST="$(git -C "$REPO" grep -n bulk "$BULK_SHA" -- changed | git -C "$REPO" hash-object --stdin)"
  [ "$COUNT" -eq 60 ]
  export SEARCH='git grep -n bulk <rev> -- changed'
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*'must end with'* ]] || return 1

  measure --max-count=30 bulk
  [ "$COUNT" -eq 60 ]
  export SEARCH='git grep -n --max-count=30 bulk <rev> -- .'
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*'search option is not allowed'* ]] || return 1
}

@test "hit summary (#1457): --repo pointing at a subdirectory is rejected on the summary path" {
  commit_bulk 60 add_narrowed_hits
  COUNT="$(git -C "$REPO/changed" grep -n bulk "$BULK_SHA" -- . | wc -l | tr -d ' ')"
  DIGEST="$(git -C "$REPO/changed" grep -n bulk "$BULK_SHA" -- . | git -C "$REPO" hash-object --stdin)"
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO/changed" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*'repository root'* ]] || return 1
}

@test "hit summary (#1457): a different count is reported as summary: with both values" {
  commit_bulk 60
  measure
  write_summary "59 行 $DIGEST"
  run --separate-stderr python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'summary: hit count differs: table 59, actual 60'* ]] || return 1
  [ -z "$stderr" ]
}

@test "hit summary (#1457): a different digest is reported as summary:, and an uppercase copy does not pass" {
  commit_bulk 60
  measure
  write_summary "$COUNT 行 0000000000000000000000000000000000000000"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'summary: digest differs'* ]] || return 1
  [[ "$output" != *'hit count differs'* ]] || return 1

  write_summary "$COUNT 行 $(printf '%s' "$DIGEST" | tr 'a-f' 'A-F')"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'summary: digest differs'* ]] || return 1
}

@test "hit summary (#1457): exactly 10 hits is rejected and 11 hits is accepted" {
  commit_bulk 10
  measure
  [ "$COUNT" -eq 10 ]
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*'more than 10'* ]] || return 1

  rm "$REPO/summary.md"
  commit_bulk 11
  measure
  [ "$COUNT" -eq 11 ]
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]
}

@test "hit summary (#1457): a four-column row outside the hits is reported as extra:" {
  commit_bulk 60
  measure
  write_summary "$COUNT 行 $DIGEST" '| ghost.txt | 9 | `bulk ghost` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'extra: ghost.txt:9'* ]] || return 1
  [[ "$output" != *'summary:'* ]] || return 1

  write_summary "$COUNT 行 $DIGEST" '| bulk.txt | 3 | `bulk 4` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'extra: bulk.txt:3'* ]] || return 1
}

@test "hit summary (#1457): a row under the summary whose handling is not a mismatch is a contract violation on stderr" {
  commit_bulk 60
  measure
  for handling in 一致 直した '該当しない: x' '食い違い:' 保留; do
    write_summary "$COUNT 行 $DIGEST" "| bulk.txt | 3 | \`bulk 3\` | $handling |"
    run --separate-stderr python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
    [ "$status" -eq 1 ] || { echo "accepted: $handling"; return 1; }
    [[ "$stderr" == *'contract:'*'食い違い'* ]] || { echo "no contract: $handling"; return 1; }
    [ -z "$output" ] || { echo "stdout: $handling"; return 1; }
  done
}

@test "hit summary (#1457): rows under another header or after a blank line do not skip the row checks" {
  commit_bulk 60
  measure
  for header in '| ファイル | 行 | 本文 | 扱い |' '| ファイル | 行(修正前 SHA) | ヒットした行の本文 | 扱い |'; do
    {
      printf '修正前 SHA: %s\n' "$BULK_SHA"
      printf '検索コマンド: git grep -n bulk <rev> -- .\n'
      printf '全ヒット要約: %s 行 %s\n' "$COUNT" "$DIGEST"
      printf '%s\n' "$header" '|---|---:|---|---|' '| ghost.txt | 9 | `bulk ghost` | 一致 |'
    } > "$REPO/summary.md"
    run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
    [ "$status" -eq 1 ] || { echo "accepted: $header"; return 1; }
    [[ "$output" == *'contract:'* ]] || { echo "no contract: $header"; return 1; }
  done

  write_summary "$COUNT 行 $DIGEST" '| bulk.txt | 3 | `bulk 3` | 食い違い: F-1 |'
  printf '\n%s\n' '| ghost.txt | 9 | `bulk ghost` | 一致 |' >> "$REPO/summary.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'* ]] || return 1
}

@test "hit summary (#1457): a malformed or repeated summary line is a contract violation" {
  commit_bulk 60
  measure
  for value in "$DIGEST" "$COUNT $DIGEST" "x 行 $DIGEST" "$COUNT 行 xyz" "$COUNT 行" "-1 行 $DIGEST"; do
    write_summary "$value"
    run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
    [ "$status" -eq 1 ] || { echo "accepted: $value"; return 1; }
    [[ "$output" == *'contract:'*'全ヒット要約'* ]] || { echo "no contract: $value"; return 1; }
  done

  write_summary "$COUNT 行 $DIGEST"
  printf '全ヒット要約: %s 行 %s\n' "$COUNT" "$DIGEST" >> "$REPO/summary.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*'全ヒット要約'* ]] || return 1
}

# 要約の下に引数の行をそのまま置く（write_summary と違い、見出しも区切り行も足さない）
write_summary_lines() {
  {
    printf '修正前 SHA: %s\n' "$BULK_SHA"
    printf '検索コマンド: git grep -n bulk <rev> -- .\n'
    printf '全ヒット要約: %s 行 %s\n' "$COUNT" "$DIGEST"
    printf '%s\n' "$@"
  } > "$REPO/summary.md"
}

HIT_HEADER='| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |'
HIT_RULE='|---|---:|---|---|'
GOOD_ROW='| bulk.txt | 3 | `bulk 3` | 食い違い: F-1 |'
GHOST_ROW='| ghost.txt | 9 | `x` | 一致 |'

expect_one_table_violation() {
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ] || return 1
  [[ "$output" == *'contract:'*'must stay in one four-column table'* ]] || return 1
}

@test "hit summary (#1457): a row after a blank line under a table without a separator row is a contract violation" {
  commit_bulk 60
  measure
  write_summary_lines "$HIT_HEADER" "$GOOD_ROW" '' "$GHOST_ROW"
  expect_one_table_violation
}

@test "hit summary (#1457): a row after a non-table line under a table without a separator row is a contract violation" {
  commit_bulk 60
  measure
  write_summary_lines "$HIT_HEADER" "$GOOD_ROW" 'memo' "$GHOST_ROW"
  expect_one_table_violation
}

@test "hit summary (#1457): a row above the header is a contract violation" {
  commit_bulk 60
  measure
  write_summary_lines "$GHOST_ROW" "$HIT_HEADER" "$GOOD_ROW"
  expect_one_table_violation
}

@test "hit summary (#1457): a blank line between the header and the rows is rejected on purpose, stricter than a full table" {
  commit_bulk 60
  measure
  write_summary_lines "$HIT_HEADER" '' "$GOOD_ROW"
  expect_one_table_violation
}

@test "hit summary (#1457): one row without a separator row, a table with one, and no table all exit zero" {
  commit_bulk 60
  measure
  write_summary_lines "$HIT_HEADER" "$GOOD_ROW"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]

  write_summary_lines "$HIT_HEADER" "$HIT_RULE" "$GOOD_ROW"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]

  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]
}

@test "hit summary (#1457): a 64-digit hex value passes the format check and is compared as a digest" {
  commit_bulk 60
  measure
  write_summary "$COUNT 行 $(printf 'a%.0s' $(seq 1 64))"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'summary: digest differs'* ]] || return 1
  [[ "$output" != *'contract:'* ]] || return 1
}

@test "hit summary (#1457): a summary with --head is a contract violation" {
  commit_bulk 60
  measure
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" --head "$BULK_SHA" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'contract:'*'--head'* ]] || return 1
}

add_binary_hit() {
  printf 'bulk\0binary\n' > "$REPO/blob.dat"
}

@test "hit summary (#1457): a binary hit counts in the summary with and without a mismatch row" {
  commit_bulk 60 add_binary_hit
  measure
  [ "$COUNT" -eq 61 ]
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]

  write_summary "$COUNT 行 $DIGEST" '| bulk.txt | 3 | `bulk 3` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]

  write_summary "$((COUNT - 1)) 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'summary: hit count differs: table 60, actual 61'* ]] || return 1
}

add_carriage_returns() {
  printf 'bulk crlf\r\nbulk mid\rdle\n' > "$REPO/crlf.txt"
}

@test "hit summary (#1457): CRLF and mid-line carriage returns count like the shell and a row can point at a CRLF hit" {
  commit_bulk 60 add_carriage_returns
  measure
  [ "$COUNT" -eq 62 ]
  write_summary "$COUNT 行 $DIGEST"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]

  write_summary "$COUNT 行 $DIGEST" '| crlf.txt | 1 | `bulk crlf` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]
}

add_colon_path_hit() {
  printf 'bulk colon\n' > "$REPO/we:ird.txt"
}

@test "hit summary (#1457): a hit in a path with a colon neither stops another row nor hides its own" {
  commit_bulk 60 add_colon_path_hit
  measure
  write_summary "$COUNT 行 $DIGEST" '| bulk.txt | 3 | `bulk 3` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]

  write_summary "$COUNT 行 $DIGEST" '| we:ird.txt | 1 | `bulk colon` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]

  write_summary "$COUNT 行 $DIGEST" '| we:ird.txt | 1 | `bulk wrong` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *'extra: we:ird.txt:1'* ]] || return 1
}

add_latin1_hit() {
  printf 'bulk caf\351\n' > "$REPO/latin1.txt"
}

@test "hit summary (#1457): a hit that cannot be decoded does not stop a mismatch row on another hit" {
  commit_bulk 60 add_latin1_hit
  measure
  write_summary "$COUNT 行 $DIGEST" '| bulk.txt | 3 | `bulk 3` | 食い違い: F-1 |'
  run python3 "$CHECKER" --repo "$REPO" "$REPO/summary.md"
  [ "$status" -eq 0 ]
}

@test "hit summary (#1457): a table with more than 10 hits written in full is still accepted" {
  commit_bulk 11
  {
    printf '修正前 SHA: %s\n' "$BULK_SHA"
    printf '検索コマンド: git grep -n bulk <rev> -- .\n'
    printf '| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |\n'
    printf '|---|---:|---|---|\n'
    for number in $(seq 1 11); do
      printf '| bulk.txt | %s | `bulk %s` | 一致 |\n' "$number" "$number"
    done
  } > "$REPO/full.md"
  run python3 "$CHECKER" --repo "$REPO" "$REPO/full.md"
  [ "$status" -eq 0 ]
}
