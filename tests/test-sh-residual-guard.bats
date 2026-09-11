#!/usr/bin/env bats
#
# scripts/test.sh の残留プロセス検査（issue #215）。
#
# bats は TAP 出力パイプを fd 3 に複製して子に渡す。テストが起動した背景プロセスが
# それを握ったまま生き残ると bats は EOF 待ちで終了せず、全件実行の exit code が取れない。
# test.sh はこれを「TAP を出す bats-exec-suite が終わったのに bats 本体が終わらない」
# 形で検知し、残留を表示して非 0 で終える。ここではそれを使い捨てリポで確かめる。
#
# 各ケースは使い捨ての git リポに test.sh と 1 本の .bats を置いて test.sh を丸ごと回す
# （test.sh は git ls-files で発見するので git add まで行う）。

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO/scripts" "$REPO/t"
  cp "$ROOT/scripts/test.sh" "$REPO/scripts/test.sh"
  ( cd "$REPO" && git init -q && git config user.email t@example.com && git config user.name t )
}

teardown() {
  # test.sh が回収し損ねても、このテストが立てた sleep をホストに残さない
  pkill -f "sleep 1234" 2>/dev/null || true
}

# 外側（この bats）の出力パイプを内側の test.sh に渡さない。渡すと内側で漏れた
# 背景プロセスがこのスイートまで止める（検査対象そのものの症状）。
run_test_sh_isolated() {
  local f
  for f in /dev/fd/*; do
    f=${f##*/}
    [ "$f" -gt 2 ] 2>/dev/null || continue
    eval "exec $f>&-" 2>/dev/null || true
  done
  cd "$REPO" && git add -A && TEST_RESIDUAL_GRACE=2 sh scripts/test.sh
}

@test "fd 3 を握った背景プロセスが残ると test.sh は非 0 で終わり、残留を表示して回収する" {
  cat >"$REPO/t/leak.bats" <<'BATS'
@test "leaks a child holding the bats output pipe" {
  sleep 1234 >/dev/null 2>&1 &
}
BATS
  run run_test_sh_isolated
  [ "$status" -ne 0 ]
  [[ "$output" == *"ok 1 leaks a child"* ]]            # テスト自体は通っている
  [[ "$output" == *"握ったまま残っています"* ]]
  [[ "$output" == *"sleep 1234"* ]]                    # 残留の実物が表示される
  [[ "$output" == *"bats: 失敗あり"* ]]
  # 残留は test.sh が回収済み
  sleep 1
  run pgrep -f "sleep 1234"
  [ "$status" -ne 0 ]
}

@test "fd を閉じて teardown で回収する背景プロセスなら test.sh は 0 で終わる" {
  cat >"$REPO/t/clean.bats" <<'BATS'
teardown() { kill -9 "$(cat "$BATS_TEST_TMPDIR/pid")" 2>/dev/null || true; }
@test "spawns a child with inherited fds closed" {
  ( for f in /dev/fd/*; do f=${f##*/}; [ "$f" -gt 2 ] 2>/dev/null && eval "exec $f>&-" 2>/dev/null; done; exec sleep 1234 ) &
  echo $! >"$BATS_TEST_TMPDIR/pid"
  sleep 1
  kill -0 "$(cat "$BATS_TEST_TMPDIR/pid")"
}
BATS
  run run_test_sh_isolated
  [ "$status" -eq 0 ]
  [[ "$output" == *"bats: 全スイート pass"* ]]
  [[ "$output" != *"残っています"* ]]
}

@test "fd は閉じていても teardown で回収されなかった背景プロセスは失敗にする" {
  cat >"$REPO/t/survivor.bats" <<'BATS'
@test "leaves a child alive after the test" {
  ( for f in /dev/fd/*; do f=${f##*/}; [ "$f" -gt 2 ] 2>/dev/null && eval "exec $f>&-" 2>/dev/null; done; exec sleep 1234 ) &
}
BATS
  run run_test_sh_isolated
  [ "$status" -ne 0 ]
  [[ "$output" == *"回収されずに残っています"* ]]
  [[ "$output" == *"sleep 1234"* ]]
  sleep 1
  run pgrep -f "sleep 1234"
  [ "$status" -ne 0 ]
}
