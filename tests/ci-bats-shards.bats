#!/usr/bin/env bats
#
# CI の bats を複数のジョブに分けて走らせる構成（issue #990）。
#
#   1. scripts/test.sh の分割指定（TEST_SHARD=k/N）
#   2. .github/workflows/ci.yml の matrix と、結果をまとめる `bats suites` ジョブの構造
#   3. scripts/test-auto-merge-workflow.sh の「ci.yml の全ジョブは必須チェックか、
#      必須チェックのジョブが needs で待つジョブ」の検査
#
# scripts/test.sh を回すケースの多くは、何もせず exit 0 する `bats` の代役を PATH の先頭に
# 置く。test.sh は実行前に対象スイートを表示するので、それと代役が受け取った引数を見れば
# 「どのスイートが選ばれたか」を、内側で本物の bats を走らせずに確かめられる。
#
# このスイート自身が CI では TEST_SHARD 付きで実行されるので、内側の test.sh には
# TEST_SHARD / TEST_EXCLUDE を必ず明示して渡す（外側の値を引き継がせない）。
#
# 守備範囲（仕様: openspec/specs/ci-bats-shards/spec.md）:
#   ci.yml を読む検査は、`shard: [1, 2, 3, 4]` の 1 行リスト・
#   `TEST_SHARD: ${{ matrix.shard }}/4` の数字の分母・1 行の `needs:`・インデント 4 の
#   `if: always()` の形だけを読む。それ以外の書き方は「読めない」として失敗に倒す
#   （読めないまま通すと、確かめないまま CI が緑になる）。

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CI_YML="$ROOT/.github/workflows/ci.yml"
  REPO="${BATS_TEST_TMPDIR}/repo"
  ERR="${BATS_TEST_TMPDIR}/stderr.txt"

  # 何もせず exit 0 する bats の代役。受け取った引数を 1 行 1 個で残す。
  STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
  STUB_ARGS="${BATS_TEST_TMPDIR}/stub-args.txt"
  export STUB_ARGS
  mkdir -p "$STUB_BIN"
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$@" >"$STUB_ARGS"' 'exit 0' >"$STUB_BIN/bats"
  chmod +x "$STUB_BIN/bats"
}

# ── 使い捨てリポジトリ ────────────────────────────────────────

# t/s1.bats 〜 t/s<n>.bats を追跡下に持つ使い捨てリポジトリを作る
make_repo() { # <n>
  local i
  mkdir -p "$REPO/scripts" "$REPO/t"
  cp "$ROOT/scripts/test.sh" "$REPO/scripts/test.sh"
  i=1
  while [ "$i" -le "$1" ]; do
    # 行頭に @test を書かない（bats 1.10 の前処理が外側のテストとして数える）
    printf '%s "s%s passes" {\n  true\n}\n' '@test' "$i" >"$REPO/t/s$i.bats"
    i=$((i + 1))
  done
  ( cd "$REPO" && git init -q && git config user.email t@example.com \
      && git config user.name t && git add -A )
}

# bats の代役を使って test.sh を回す。標準エラーは $ERR に分ける。
#   <root> <TEST_SHARD の値（空なら未設定）> <TEST_EXCLUDE の値（空なら未設定）> [フィルタ...]
shard_run() {
  local root=$1 shard=$2 exclude=$3
  shift 3
  rm -f "$STUB_ARGS"
  if [ -n "$shard" ]; then
    env -u TEST_SHARD -u TEST_EXCLUDE PATH="$STUB_BIN:$PATH" \
      TEST_SHARD="$shard" ${exclude:+TEST_EXCLUDE="$exclude"} \
      sh "$root/scripts/test.sh" "$@" 2>"$ERR"
  else
    env -u TEST_SHARD -u TEST_EXCLUDE PATH="$STUB_BIN:$PATH" \
      ${exclude:+TEST_EXCLUDE="$exclude"} \
      sh "$root/scripts/test.sh" "$@" 2>"$ERR"
  fi
}

# test.sh の出力（stdin）から対象スイートの一覧を取り出す。
# 一覧は `▶ bats suites:` の次の行から、`  (` で始まる最初の行の手前まで。
listed_suites() {
  awk '
    /^▶ bats suites:$/ { on = 1; next }
    on && /^  \(/ { exit }
    on { sub(/^  /, ""); print }
  '
}

# ── ci.yml を読む検査（写しにも当てられるよう関数にしてある）────

# jobs: の直下（インデント 2）のジョブ ID を列挙する
job_ids() { # <ci.yml>
  awk '
    /^jobs:[ \t]*$/ { j = 1; next }
    j && /^[^ \t#]/ { j = 0 }
    j && /^  [A-Za-z_][A-Za-z0-9_-]*:[ \t]*$/ {
      id = $0; sub(/^  /, "", id); sub(/:[ \t]*$/, "", id); print id
    }
  ' "$1"
}

# 指定したジョブ ID のブロック（ID の行を除く）を出す
job_block() { # <ci.yml> <job id>
  awk -v want="$2" '
    /^jobs:[ \t]*$/ { j = 1; next }
    j && /^[^ \t#]/ { j = 0 }
    j && /^  [A-Za-z_][A-Za-z0-9_-]*:[ \t]*$/ {
      id = $0; sub(/^  /, "", id); sub(/:[ \t]*$/, "", id); on = (id == want); next
    }
    j && on { print }
  ' "$1"
}

# name: が一致するジョブ ID を列挙する
job_ids_named() { # <ci.yml> <name>
  local id
  for id in $(job_ids "$1"); do
    if job_block "$1" "$id" | grep -qxF "    name: $2"; then echo "$id"; fi
  done
}

# matrix で分けたジョブ（ブロックに `shard: ` の行を持つジョブ）の ID
shard_job_ids() { # <ci.yml>
  local id
  for id in $(job_ids "$1"); do
    if job_block "$1" "$id" | grep -qE '^ +shard:'; then echo "$id"; fi
  done
}

# 組の番号がちょうど 1〜N で、TEST_SHARD の分母が N に等しいことを確かめ、N を出す。
# 読めない形（複数行の matrix・式を経由した分母など）は失敗にする。
check_shard_matrix() { # <ci.yml>
  local line nums n denom_line denom expect
  if [ "$(grep -cE '^ +shard:' "$1")" -ne 1 ]; then
    echo "ci.yml の matrix の shard: の行がちょうど 1 つではない" >&2
    return 1
  fi
  line=$(grep -E '^ +shard: \[[1-9][0-9]*(, *[1-9][0-9]*)*\]$' "$1") || {
    echo "ci.yml の matrix の shard: を読めない（shard: [1, 2, 3, 4] の 1 行の形で書く）" >&2
    return 1
  }
  nums=$(printf '%s\n' "$line" | sed 's/^.*\[//; s/\]$//' | tr ',' '\n' | tr -d ' ')
  n=$(printf '%s\n' "$nums" | wc -l | tr -d ' ')
  expect=$(i=1; while [ "$i" -le "$n" ]; do echo "$i"; i=$((i + 1)); done)
  if [ "$(printf '%s\n' "$nums" | sort -n)" != "$expect" ]; then
    echo "ci.yml の matrix の組の番号がちょうど 1〜$n ではない: $line" >&2
    return 1
  fi
  if [ "$(grep -cE '^ +TEST_SHARD:' "$1")" -ne 1 ]; then
    echo "ci.yml の TEST_SHARD: の行がちょうど 1 つではない" >&2
    return 1
  fi
  denom_line=$(grep -E '^ +TEST_SHARD: \$\{\{ matrix\.shard \}\}/[1-9][0-9]*$' "$1") || {
    echo "ci.yml の TEST_SHARD: を読めない（TEST_SHARD: \${{ matrix.shard }}/4 の形で書く）" >&2
    return 1
  }
  denom=${denom_line##*/}
  if [ "$denom" != "$n" ]; then
    echo "ci.yml の TEST_SHARD の分母（${denom}）が matrix の組の数（${n}）と違う" >&2
    return 1
  fi
  echo "$n"
}

# 結果をまとめるジョブ（name: bats suites）の構造を確かめる
check_result_job() { # <ci.yml>
  local ids id block needs shard_id
  ids=$(job_ids_named "$1" "bats suites")
  if [ "$(printf '%s\n' "$ids" | grep -c .)" -ne 1 ]; then
    echo "name: bats suites のジョブがちょうど 1 つではない: [$ids]" >&2
    return 1
  fi
  id=$ids
  block=$(job_block "$1" "$id")
  needs=$(printf '%s\n' "$block" \
    | sed -n -E 's/^    needs: (\[[^]]+\]|[A-Za-z_][A-Za-z0-9_-]*)$/\1/p' \
    | tr -d '[] ' | tr ',' '\n')
  if [ -z "$needs" ]; then
    echo "ジョブ $id の needs: を読めない（1 行の形で書く）" >&2
    return 1
  fi
  shard_id=$(shard_job_ids "$1")
  if [ -z "$shard_id" ]; then
    echo "matrix で分けたジョブが見つからない" >&2
    return 1
  fi
  for s in $shard_id; do
    printf '%s\n' "$needs" | grep -qxF "$s" || {
      echo "ジョブ $id の needs: に分けたジョブ $s が無い" >&2
      return 1
    }
  done
  # インデント 4 の行そのもの。コメント行（# で始まる）は一致しない。
  printf '%s\n' "$block" | grep -qxF '    if: always()' || {
    echo "ジョブ $id に if: always() が無い" >&2
    return 1
  }
  printf '%s\n' "$block" | grep -qF 'needs.*.result' || {
    echo "ジョブ $id の判定が needs.*.result を参照していない" >&2
    return 1
  }
  # ジョブ ID は英字か _ で始まるので、`needs.*.result` の `*` はこの形に一致しない。
  if printf '%s\n' "$block" | grep -qE 'needs\.[A-Za-z_][A-Za-z0-9_-]*\.result'; then
    echo "ジョブ $id の判定がジョブ ID を列挙している（needs.<ジョブ ID>.result の形）" >&2
    return 1
  fi
  return 0
}

# ── 不変条件の検査（scripts/test-auto-merge-workflow.sh）を当てる写し ──

# このリポジトリのワークフロー・docs・検査スクリプトを写した木を作る
make_tree() {
  TREE="${BATS_TEST_TMPDIR}/tree"
  mkdir -p "$TREE/.github/workflows" "$TREE/docs" "$TREE/scripts"
  cp "$ROOT/.github/workflows/auto-merge.yml" "$ROOT/.github/workflows/revert-pr.yml" \
    "$ROOT/.github/workflows/ci.yml" "$TREE/.github/workflows/"
  cp "$ROOT/docs/auto-merge.md" "$TREE/docs/"
  cp "$ROOT/scripts/test-auto-merge-workflow.sh" "$TREE/scripts/"
  TREE_CI="$TREE/.github/workflows/ci.yml"
}

run_invariants() {
  run env AUTOMERGE_TEST_ROOT="$TREE" sh "$TREE/scripts/test-auto-merge-workflow.sh"
}

# 必須チェックでも、必須チェックの needs でもないジョブを写しの ci.yml の末尾に足す
append_job() { # <job id> <name>
  printf '\n  %s:\n    name: %s\n    runs-on: ubuntu-latest\n    steps:\n      - run: "true"\n' \
    "$1" "$2" >>"$TREE_CI"
}

# 写しの ci.yml を awk のプログラムで書き換える
rewrite_ci() { # <ci.yml> <awk の -v 代入...> <awk program>
  local f=$1
  shift
  awk "$@" "$f" >"$f.new"
  mv -f "$f.new" "$f"
}

# ══ 1. scripts/test.sh の分割指定 ═════════════════════════════

@test "shard: all shards together cover every suite exactly once" {
  make_repo 7
  : >"${BATS_TEST_TMPDIR}/listed.txt"
  : >"${BATS_TEST_TMPDIR}/passed.txt"
  local k
  for k in 1 2 3; do
    run shard_run "$REPO" "$k/3" ""
    [ "$status" -eq 0 ] || { echo "$output"; cat "$ERR"; return 1; }
    printf '%s\n' "$output" | listed_suites >>"${BATS_TEST_TMPDIR}/listed.txt"
    cat "$STUB_ARGS" >>"${BATS_TEST_TMPDIR}/passed.txt"
  done
  git -C "$REPO" ls-files -- '*.bats' ':(exclude)_longruns/' | LC_ALL=C sort \
    >"${BATS_TEST_TMPDIR}/all.txt"
  [ "$(wc -l <"${BATS_TEST_TMPDIR}/all.txt" | tr -d ' ')" -eq 7 ]
  # 表示された一覧に重複が無く、全件と一致する
  [ -z "$(LC_ALL=C sort "${BATS_TEST_TMPDIR}/listed.txt" | uniq -d)" ]
  diff "${BATS_TEST_TMPDIR}/all.txt" <(LC_ALL=C sort "${BATS_TEST_TMPDIR}/listed.txt")
  # bats に実際に渡されたスイートも同じ
  diff "${BATS_TEST_TMPDIR}/all.txt" <(LC_ALL=C sort "${BATS_TEST_TMPDIR}/passed.txt")
}

@test "shard: assignment follows the position in git ls-files, and the shard line follows the skipped line" {
  make_repo 7
  run shard_run "$REPO" "2/3" ""
  [ "$status" -eq 0 ] || { echo "$output"; cat "$ERR"; return 1; }
  [ "$(printf '%s\n' "$output" | listed_suites | tr '\n' ' ')" = "t/s2.bats t/s5.bats " ]
  [ "$(tr '\n' ' ' <"$STUB_ARGS")" = "t/s2.bats t/s5.bats " ]
  # (skipped ...) の行のすぐ次が (shard k/N)、その次が区切り線
  printf '%s\n' "$output" | grep -A2 -xF '  (skipped by TEST_EXCLUDE: 0)' >"${BATS_TEST_TMPDIR}/after.txt"
  [ "$(sed -n 2p "${BATS_TEST_TMPDIR}/after.txt")" = "  (shard 2/3)" ]
  [ "$(sed -n 3p "${BATS_TEST_TMPDIR}/after.txt")" = "----------------------------------------" ]
}

@test "shard: without TEST_SHARD every suite runs and no shard line is printed" {
  make_repo 7
  run shard_run "$REPO" "" ""
  [ "$status" -eq 0 ] || { echo "$output"; cat "$ERR"; return 1; }
  [ "$(printf '%s\n' "$output" | listed_suites | wc -l | tr -d ' ')" -eq 7 ]
  [ "$(wc -l <"$STUB_ARGS" | tr -d ' ')" -eq 7 ]
  ! printf '%s\n' "$output" | grep -qF '(shard' || return 1
}

@test "shard: an empty TEST_SHARD is the same as unset" {
  make_repo 7
  run env -u TEST_EXCLUDE PATH="$STUB_BIN:$PATH" TEST_SHARD= sh "$REPO/scripts/test.sh"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(wc -l <"$STUB_ARGS" | tr -d ' ')" -eq 7 ]
  ! printf '%s\n' "$output" | grep -qF '(shard' || return 1
}

@test "shard: a filter does not change which shard a suite belongs to" {
  make_repo 7
  run shard_run "$REPO" "2/3" "" s5
  [ "$status" -eq 0 ] || { echo "$output"; cat "$ERR"; return 1; }
  [ "$(printf '%s\n' "$output" | listed_suites | tr '\n' ' ')" = "t/s5.bats " ]
  # 一致するスイートが別の組にしか無いときは、対象が空なので失敗する
  run shard_run "$REPO" "1/3" "" s5
  [ "$status" -ne 0 ]
  [ ! -e "$STUB_ARGS" ]
}

@test "shard: an excluded suite is counted only in the shard it belongs to" {
  make_repo 7
  local k want
  for k in 1 2 3; do
    want=0
    [ "$k" -eq 2 ] && want=1
    run shard_run "$REPO" "$k/3" "s2"
    [ "$status" -eq 0 ] || { echo "$output"; cat "$ERR"; return 1; }
    printf '%s\n' "$output" | grep -qxF "  (skipped by TEST_EXCLUDE: $want)" || {
      echo "shard $k/3: expected skipped $want"; echo "$output"; return 1
    }
  done
}

@test "shard: malformed TEST_SHARD values are rejected without running anything" {
  make_repo 7
  local v
  for v in "0/4" "5/4" "2" "a/4" "1/0" "1/4/2" "01/4" "1/04" " 1/4" "1/4 " "/" "1/" "/4" "-1/4"; do
    run shard_run "$REPO" "$v" ""
    [ "$status" -ne 0 ] || { echo "accepted: '$v'"; echo "$output"; return 1; }
    grep -qF -- "'$v'" "$ERR" || { echo "stderr does not show '$v':"; cat "$ERR"; return 1; }
    if printf '%s\n' "$output" | grep -qF '▶ bats suites:'; then echo "listed for '$v'"; return 1; fi
    [ ! -e "$STUB_ARGS" ] || { echo "bats was run for '$v'"; return 1; }
  done
}

@test "shard: a shard with no suites fails instead of passing with nothing run" {
  make_repo 2
  run shard_run "$REPO" "3/3" ""
  [ "$status" -ne 0 ]
  [ ! -e "$STUB_ARGS" ]
  grep -qF '3/3' "$ERR"
}

@test "shard: a shard really runs its suites with the real bats" {
  make_repo 7
  # 外側の bats の出力パイプと実行環境を内側に渡さない
  # （理由は tests/test-sh-residual-guard.bats の run_test_sh_isolated と同じ）
  inner() {
    local f v
    for f in /dev/fd/*; do
      f=${f##*/}
      [ "$f" -gt 2 ] 2>/dev/null || continue
      eval "exec $f>&-" 2>/dev/null || true
    done
    PATH=${BATS_SAVED_PATH:-$PATH}
    for v in $(compgen -e | grep '^BATS_'); do unset "$v"; done
    unset TEST_EXCLUDE
    TEST_SHARD=2/3 sh "$REPO/scripts/test.sh"
  }
  run inner
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"1..2"* ]] || return 1
  [[ "$output" == *"ok 1 s2 passes"* ]] || return 1
  [[ "$output" == *"ok 2 s5 passes"* ]] || return 1
}

# ══ 2. ci.yml の matrix と、結果をまとめるジョブ ══════════════

@test "ci.yml: shard numbers are exactly 1..N and the TEST_SHARD denominator is N" {
  run check_shard_matrix "$CI_YML"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" -ge 2 ]
}

@test "ci.yml: a missing shard number is detected" {
  cp "$CI_YML" "${BATS_TEST_TMPDIR}/ci.yml"
  local n
  n=$(check_shard_matrix "$CI_YML")
  # 最後の組を落とす（分母は N のまま）
  rewrite_ci "${BATS_TEST_TMPDIR}/ci.yml" -v last=", $n]" \
    '/^ +shard: \[/ { i = index($0, last); if (i) $0 = substr($0, 1, i - 1) "]" } { print }'
  ! diff -q "$CI_YML" "${BATS_TEST_TMPDIR}/ci.yml" >/dev/null || return 1
  run check_shard_matrix "${BATS_TEST_TMPDIR}/ci.yml"
  [ "$status" -ne 0 ]
}

@test "ci.yml: a matrix or a denominator in a form the check cannot read fails" {
  # 複数行のリストで書いた matrix
  cp "$CI_YML" "${BATS_TEST_TMPDIR}/multi.yml"
  rewrite_ci "${BATS_TEST_TMPDIR}/multi.yml" \
    '/^ +shard: \[/ { ind = $0; sub(/shard:.*$/, "", ind); print ind "shard:"; print ind "  - 1"; print ind "  - 2"; next } { print }'
  ! diff -q "$CI_YML" "${BATS_TEST_TMPDIR}/multi.yml" >/dev/null || return 1
  run check_shard_matrix "${BATS_TEST_TMPDIR}/multi.yml"
  [ "$status" -ne 0 ]

  # 式を経由した分母
  cp "$CI_YML" "${BATS_TEST_TMPDIR}/expr.yml"
  rewrite_ci "${BATS_TEST_TMPDIR}/expr.yml" \
    '/^ +TEST_SHARD: / { sub(/\/[0-9]+$/, "/${{ env.SHARDS }}") } { print }'
  ! diff -q "$CI_YML" "${BATS_TEST_TMPDIR}/expr.yml" >/dev/null || return 1
  run check_shard_matrix "${BATS_TEST_TMPDIR}/expr.yml"
  [ "$status" -ne 0 ]
}

@test "ci.yml: the shards of the real repository cover every tracked suite exactly once" {
  local n k
  n=$(check_shard_matrix "$CI_YML")
  : >"${BATS_TEST_TMPDIR}/listed.txt"
  k=1
  while [ "$k" -le "$n" ]; do
    run shard_run "$ROOT" "$k/$n" ""
    [ "$status" -eq 0 ] || { echo "shard $k/$n"; echo "$output" | tail -5; cat "$ERR"; return 1; }
    printf '%s\n' "$output" | listed_suites >>"${BATS_TEST_TMPDIR}/listed.txt"
    k=$((k + 1))
  done
  git -C "$ROOT" ls-files -- '*.bats' ':(exclude)_longruns/' | LC_ALL=C sort \
    >"${BATS_TEST_TMPDIR}/all.txt"
  [ "$(wc -l <"${BATS_TEST_TMPDIR}/listed.txt" | tr -d ' ')" -eq "$(wc -l <"${BATS_TEST_TMPDIR}/all.txt" | tr -d ' ')" ]
  [ -z "$(LC_ALL=C sort "${BATS_TEST_TMPDIR}/listed.txt" | uniq -d)" ]
  diff "${BATS_TEST_TMPDIR}/all.txt" <(LC_ALL=C sort "${BATS_TEST_TMPDIR}/listed.txt")
}

@test "ci.yml: shards keep running when one fails, and never use bats' own parallel jobs" {
  local id
  id=$(shard_job_ids "$CI_YML")
  [ "$(printf '%s\n' "$id" | grep -c .)" -eq 1 ]
  job_block "$CI_YML" "$id" | grep -qxE ' +fail-fast: false'
  # 分けたジョブの名前は bats suites と異なる
  job_block "$CI_YML" "$id" | grep -qE '^    name: '
  ! job_block "$CI_YML" "$id" | grep -qxF '    name: bats suites' || return 1
  # コメント以外の行に --jobs / -j が無い
  ! grep -vE '^[ \t]*#' "$CI_YML" | grep -qE -- '(--jobs|bats +-j)' || return 1
  ! grep -vE '^[ \t]*#' "$ROOT/scripts/test.sh" | grep -qE -- '(--jobs|bats +-j)' || return 1
}

@test "ci.yml: the bats suites job waits for the shards and judges every needs result" {
  run check_result_job "$CI_YML"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  # auto-merge.yml の必須チェック名は変えていない
  grep -qxF "          REQUIRED_CHECKS='shellcheck" "$ROOT/.github/workflows/auto-merge.yml"
  grep -qxF "          bats suites'" "$ROOT/.github/workflows/auto-merge.yml"
}

@test "ci.yml: a judgement that names a job id, or a missing if: always(), is detected" {
  local shard_id
  shard_id=$(shard_job_ids "$CI_YML")

  cp "$CI_YML" "${BATS_TEST_TMPDIR}/named.yml"
  rewrite_ci "${BATS_TEST_TMPDIR}/named.yml" -v id="$shard_id" \
    '{ while ((i = index($0, "needs.*.result")) > 0) $0 = substr($0, 1, i - 1) "needs." id ".result" substr($0, i + 14); print }'
  ! diff -q "$CI_YML" "${BATS_TEST_TMPDIR}/named.yml" >/dev/null || return 1
  run check_result_job "${BATS_TEST_TMPDIR}/named.yml"
  [ "$status" -ne 0 ]

  cp "$CI_YML" "${BATS_TEST_TMPDIR}/noalways.yml"
  rewrite_ci "${BATS_TEST_TMPDIR}/noalways.yml" '$0 != "    if: always()" { print }'
  ! diff -q "$CI_YML" "${BATS_TEST_TMPDIR}/noalways.yml" >/dev/null || return 1
  run check_result_job "${BATS_TEST_TMPDIR}/noalways.yml"
  [ "$status" -ne 0 ]
}

@test "ci.yml: the auto-merge invariants run exactly once, in the shellcheck job" {
  [ "$(grep -cE '^ +run: scripts/test-auto-merge-workflow\.sh$' "$CI_YML")" -eq 1 ]
  local id
  id=$(job_ids_named "$CI_YML" "shellcheck")
  [ "$(printf '%s\n' "$id" | grep -c .)" -eq 1 ]
  job_block "$CI_YML" "$id" | grep -qE '^ +run: scripts/test-auto-merge-workflow\.sh$'
  ! job_block "$CI_YML" "$id" | grep -qE '^ +shard:' || return 1
}

# ══ 3. 必須チェックと ci.yml のジョブの対応の検査 ═════════════

@test "invariants: this repository's ci.yml passes (an if: on a required job is allowed)" {
  make_tree
  grep -qxF '    if: always()' "$TREE_CI"
  run_invariants
  [ "$status" -eq 0 ] || { echo "$output" | grep -v '^PASS'; return 1; }
  [[ "$output" == *"PASS  ci.yml の全ジョブが必須チェックか"* ]] || return 1
}

@test "invariants: a job that is neither required nor needed by a required job is detected" {
  make_tree
  append_job extra "extra job"
  run_invariants
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep '^FAIL' | grep -qF 'extra'
}

@test "invariants: a job needed only transitively is detected" {
  make_tree
  local shard_id
  shard_id=$(shard_job_ids "$TREE_CI")
  append_job extra "extra job"
  # 分けたジョブが extra を待つ（bats suites のジョブの needs: には書かない）
  rewrite_ci "$TREE_CI" -v id="$shard_id" \
    '{ print } $0 == "  " id ":" { print "    needs: [extra]" }'
  job_block "$TREE_CI" "$shard_id" | grep -qxF '    needs: [extra]'
  run_invariants
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep '^FAIL' | grep -qF 'extra'
}

@test "invariants: a multi-line needs fails and asks for the one-line form" {
  make_tree
  rewrite_ci "$TREE_CI" \
    '/^    needs: / { print "    needs:"; print "      - " substr($0, 12); next } { print }'
  ! diff -q "$CI_YML" "$TREE_CI" >/dev/null || return 1
  run_invariants
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep '^FAIL' | grep -qF '1 行の形'
}

@test "invariants: a required check name with no matching job is detected" {
  make_tree
  rewrite_ci "$TREE_CI" '$0 == "    name: bats suites" { print "    name: bats all"; next } { print }'
  ! diff -q "$CI_YML" "$TREE_CI" >/dev/null || return 1
  run_invariants
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep '^FAIL' | grep -qF 'bats suites'
}

@test "invariants: a required check name used by two jobs is detected" {
  make_tree
  append_job extra "bats suites"
  run_invariants
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep '^FAIL' | grep -qF 'bats suites'
}

@test "invariants: a job without a name is detected" {
  make_tree
  local shard_id
  shard_id=$(shard_job_ids "$TREE_CI")
  rewrite_ci "$TREE_CI" -v id="$shard_id" '
    /^  [A-Za-z_][A-Za-z0-9_-]*:[ \t]*$/ { on = ($0 == "  " id ":") }
    on && /^    name: / { next }
    { print }'
  ! diff -q "$CI_YML" "$TREE_CI" >/dev/null || return 1
  run_invariants
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep '^FAIL' | grep -qF "$shard_id"
}

# issue #990 の受け入れ条件の確認用（PR #1010 には入れない。マージしない）
@test "deliberate failure for #990 acceptance check (do not merge)" {
  false
}
