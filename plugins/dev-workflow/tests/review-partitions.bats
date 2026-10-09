#!/usr/bin/env bats

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PARTITIONS="${PLUGIN_DIR}/scripts/review-partitions.sh"
}

@test "review partitions: exactly 600 lines stays whole" {
  run sh -c 'printf "300\ta\n300\tb\n" | "$1"' sh "$PARTITIONS"
  [ "$status" -eq 0 ]
  [ "$output" = $'合計: 600 行\n区画: なし' ]
}

@test "review partitions: path order fills sections up to 400 lines" {
  run sh -c 'printf "200\ta\n150\tb\n100\tc\n200\td\n" | "$1"' sh "$PARTITIONS"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'合計: 650 行\n区画: 2\n区画 1/2（350 行）\n- a（200 行）\n- b（150 行）\n区画 2/2（300 行）\n- c（100 行）\n- d（200 行）'* ]] || return 1
}

@test "review partitions: oversized file stands alone" {
  run sh -c 'printf "100\ta\n500\tb\n100\tc\n" | "$1"' sh "$PARTITIONS"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'区画: 3\n区画 1/3（100 行）\n- a（100 行）\n区画 2/3（500 行）\n- b（500 行）\n区画 3/3（100 行）\n- c（100 行）'* ]] || return 1
}

@test "review partitions: zero line file follows oversized file" {
  run sh -c 'printf "100\ta\n500\tb\n0\tz\n100\tc\n" | "$1"' sh "$PARTITIONS"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'区画: 3\n区画 1/3（100 行）\n- a（100 行）\n区画 2/3（500 行）\n- b（500 行）\n- z（0 行）\n区画 3/3（100 行）\n- c（100 行）'* ]] || return 1
}

@test "review partitions: leading zero line file belongs to first section" {
  run sh -c 'printf "0\tz\n500\tb\n101\tc\n" | "$1"' sh "$PARTITIONS"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'区画 1/3（0 行）\n- z（0 行）\n区画 2/3（500 行）'* ]] || return 1
}

@test "review partitions: empty input succeeds" {
  run sh -c '"$1" </dev/null' sh "$PARTITIONS"
  [ "$status" -eq 0 ]
  [ "$output" = $'合計: 0 行\n区画: なし' ]
}

@test "review partitions: malformed count prints no stdout and exits two" {
  run sh -c 'printf "100\ta\nno\tb\n" | "$1" >"$2/out" 2>"$2/err"; code=$?; cat "$2/err"; test ! -s "$2/out"; exit "$code"' sh "$PARTITIONS" "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
  [[ "$output" == *$'no\tb'* ]] || return 1
}

@test "review partitions: missing tab prints no stdout and exits two" {
  run sh -c 'printf "100\ta\ninvalid\n" | "$1" >"$2/out" 2>"$2/err"; code=$?; cat "$2/err"; test ! -s "$2/out"; exit "$code"' sh "$PARTITIONS" "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
  [[ "$output" == *invalid* ]] || return 1
}
