#!/usr/bin/env bats
#
# issue #284 / openspec change bats-assertion-guard。
# issue #283 / openspec change bats-negation-guard。
#
# bats はテスト本体を bash の set -e（errexit）下で実行する。このファイルは性質の
# 異なる2つの穴を扱う。
#
# 1. `[[ ]]` / `(( ))`（#284）: bash 4.1 でこれらの非ゼロ終了が errexit の対象に
#    含まれるよう変わったため、bash 4.1 未満（macOS 標準の /bin/bash 3.2.57 など）
#    ではテスト本文の途中に置いた単独文の `[[ ... ]]` が偽でもローカル実行時は
#    素通りする（CI の ubuntu-latest は bash 5 系のためこの穴は発生しない）。
# 2. `! cmd`（否定形。#283）: `!` で反転したコマンドの非ゼロ終了は errexit の対象外
#    という POSIX/bash の仕様で、バージョンに関わらず常に成立する（CI の bash 5 系
#    でも再現する）。`! [[ ... ]]` のような否定形の `[[ ]]` もここに含まれる。
#
# cost-ledger は #273 で `|| return 1` を全アサーションに付けて対処済み。ここでは
# 残りのファイルにガード漏れが無いことを機械的に検査する常設テストと、それぞれの穴が
# 実在したことを示す実演テストを行う。

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- 1. 常設の静的スコープ検査（bash バージョン非依存） ---
#
# 対象: git 追跡下の *.bats（_longruns/ と #273 で対応済みの plugins/cost-ledger/
# を除く）のうち、行頭（空白のみ）から `[[ ` で始まり行末（末尾コメント可）が
# `]]` で終わる行。`if`/`while` の条件式・`&&`/`||` 連結・複数行にまたがる `[[ ]]`・
# 否定形 `! [[ ]]`（issue #283 の範囲）は対象定義に一致しないため自然に除外される。

@test "no unguarded standalone [[ ]] assertion remains in tracked bats files" {
  cd "$ROOT"
  run bash -c 'git ls-files "*.bats" ":(exclude)_longruns/" ":(exclude)plugins/cost-ledger/" \
    | xargs grep -nE "^[[:space:]]*\[\[ .*\]\][[:space:]]*(#.*)?\$"'
  echo "$output"
  [ -z "$output" ] || return 1
}

# --- 2. 実行時の実演（bash バージョン依存） ---

# 子プロセスの bats を外側の bats 実行環境から隔離する（BATS_* を外し PATH を戻す）。
# tests/test-sh-residual-guard.bats の run_test_sh_isolated と同じ理由: bats は PATH
# の先頭に自分の libexec を足すので、そのままだと内側の `bats` が外側の内部実行ファイル
# になってしまう。BATS_SAVED_PATH は現状どこも設定していないため今は $PATH と同値だが、
# 将来 test.sh 側で設定されても壊れないよう同じ書き方を踏襲する。
run_bats_isolated() { # <bats に渡す引数...>
  local v
  PATH=${BATS_SAVED_PATH:-$PATH}
  for v in $(compgen -e | grep '^BATS_'); do unset "$v"; done
  bats "$@"
}

# ガード付き（`[[ ... ]] || return 1`）の fixture を書き出す。この行は `]]` の直後に
# ` || return 1` が続くため、上のスコープ検査 grep の対象パターンに一致しない。
#
# ヒアドキュメントで直書きすると、ソース上に行頭 `@test` の行がもう1つ出現する。
# bats 1.10（CI）のテスト数の事前カウントは `^@test` の素朴な行頭一致で、ヒアドキュメント
# の中身かどうかを区別しない（bats 1.13 は区別する）ため、このファイル自身の @test 数
# を実数（3）より多く（4）数えてしまい、テスト名の対応がずれて後続テストが
# `bats: unknown test name` で丸ごと巻き添えになる（実演: #284 の CI 失敗）。
# write_guardless_fixture と同じく echo で組み立て、ソース上に行頭 `@test` を出現させない。
write_guarded_fixture() { # <path>
  {
    echo '@test "guarded assertion mid-body fails when false" {'
    echo '  echo before'
    echo '  [[ "actual" == "expected-mismatch" ]] || return 1'
    echo '  echo after'
    echo '}'
  } >"$1"
}

# ガード無しの fixture を書き出す。tests/bats-assertion-guard.bats 自身も
# `git ls-files '*.bats'` の対象に入りスコープ検査の対象でもあるため、ガード無しの
# `[[ ... ]]` をソース上に単独行としてそのまま書くと、この検査が恒久的に red になる
# （design.md「採用3」）。printf で組み立てて、ソース上に行頭 `[[ ` の行を出現させない。
write_guardless_fixture() { # <path>
  {
    echo '@test "guardless assertion mid-body only fails on set -e-aware bash" {'
    echo '  echo before'
    printf '  %s "actual" == "expected-mismatch" %s\n' '[[' ']]'
    echo '  echo after'
    echo '}'
  } >"$1"
}

@test "a guarded [[ ]] mid-body fails on any bash version" {
  local fixture="$BATS_TEST_TMPDIR/guarded.bats"
  write_guarded_fixture "$fixture"
  run run_bats_isolated "$fixture"
  echo "$output"
  [ "$status" -ne 0 ] || return 1
  [[ "$output" == *"not ok"* ]] || return 1
}

@test "a guardless [[ ]] mid-body slips through only on bash < 4.1" {
  local maj="${BASH_VERSINFO[0]}" min="${BASH_VERSINFO[1]}"
  if [ "$maj" -gt 4 ] || { [ "$maj" -eq 4 ] && [ "$min" -ge 1 ]; }; then
    skip "bash ${maj}.${min} は 4.1 以降のため [[ ]] の非ゼロ終了が errexit の対象になり、素通りは再現しない"
  fi
  local fixture="$BATS_TEST_TMPDIR/guardless.bats"
  write_guardless_fixture "$fixture"
  run run_bats_isolated "$fixture"
  echo "$output"
  [ "$status" -eq 0 ] || return 1
  [[ "$output" != *"not ok"* ]] || return 1
}
