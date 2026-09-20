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
  # 内側のテストが起動した背景プロセスの PID をここに残す（BATS_* ではないので内側まで届く）
  export RESIDUAL_TEST_PIDS="${BATS_TEST_TMPDIR}/spawned.pids"
  INNER_GRACE=2
}

teardown() {
  # test.sh が回収し損ねても、このテストが立てた背景プロセスをホストに残さない。
  # 対象は記録した PID だけ（コマンド名で kill すると並列で走る別 worktree のテストを巻き込む）
  local p
  [ -s "$RESIDUAL_TEST_PIDS" ] || return 0
  while read -r p; do
    [ -n "$p" ] && kill -9 "$p" 2>/dev/null || true
  done <"$RESIDUAL_TEST_PIDS"
  return 0
}

# test.sh の残留プロセス検査は「自分自身を ps / pgrep で引ける」ことを前提にしている。
# 砂場のようにプロセス一覧を取れない環境では test.sh が検査を諦めて bats をそのまま流すので、
# 検査が働くことを確かめるケースは前提ごと成立しない。そこだけ skip する
# （検査が無効な環境で失敗を求めると、fd 3 を握った残留が消えず内側の bats が終わらない）。
require_process_listing() {
  local pgid
  pgid=$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')
  case "$pgid" in
    ''|*[!0-9]*) skip "プロセス一覧を取得できない環境（ps が自分自身を引けない）" ;;
  esac
  pgrep -g "$pgid" >/dev/null 2>&1 || skip "プロセス一覧を取得できない環境（pgrep が使えない）"
}

# 記録した PID のうち生きているものがあれば 0
tracked_alive() {
  local p
  [ -s "$RESIDUAL_TEST_PIDS" ] || return 1
  while read -r p; do
    [ -n "$p" ] && kill -0 "$p" 2>/dev/null && return 0
  done <"$RESIDUAL_TEST_PIDS"
  return 1
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
  # 外側の bats の実行環境も渡さない。bats は PATH の先頭に自分の libexec を足すので、
  # そのままだと内側の `bats` は外側の内部実行ファイルになる。それは export された
  # bash 関数（bats_readlinkf）を前提にしていて、ubuntu の /bin/sh（dash）を通ると
  # 関数が落ちて起動できない。PATH を bats 起動前に戻し、BATS_* も外してから呼ぶ。
  local v
  PATH=${BATS_SAVED_PATH:-$PATH}
  # STUB_BIN が指定されていれば先頭に足す（ps / pgrep を潰す差し替え用）
  if [ -n "${STUB_BIN:-}" ]; then PATH="$STUB_BIN:$PATH"; fi
  for v in $(compgen -e | grep '^BATS_'); do unset "$v"; done
  cd "$REPO" && git add -A && TEST_RESIDUAL_GRACE="$INNER_GRACE" sh scripts/test.sh
}

# 内側の .bats を stdin から書く。本文では @test を @@TEST と書く。
# 行頭の @test をこのファイルに書くと、bats 1.10（CI）の前処理はヒアドキュメントの中でも
# 外側のテストとして数え、実在しない関数を呼んで "unknown test name" で落ちる。
write_inner_suite() { # <name>
  sed 's/^@@TEST /@test /' >"$REPO/t/$1.bats"
}

# fd 3 を握った背景プロセスが残ると test.sh は非 0 で終わり、残留を表示して回収する
@test "a leftover child holding fd 3 makes test.sh fail, report it and reap it" {
  require_process_listing
  write_inner_suite leak <<'BATS'
@@TEST "leaks a child holding the bats output pipe" {
  sleep 1234 >/dev/null 2>&1 &
  echo $! >>"$RESIDUAL_TEST_PIDS"
}
BATS
  run run_test_sh_isolated
  echo "$output"   # 失敗したときだけ bats が表示する（内側の test.sh の出力）
  [ "$status" -ne 0 ]
  [[ "$output" == *"ok 1 leaks a child"* ]]            # テスト自体は通っている
  [[ "$output" == *"握ったまま残っています"* ]]
  [[ "$output" == *"sleep 1234"* ]]                    # 残留の実物が表示される
  [[ "$output" == *"bats: 失敗あり"* ]]
  # 残留は test.sh が回収済み
  sleep 1
  ! tracked_alive
}

# fd を閉じて teardown で回収する背景プロセスなら test.sh は 0 で終わる
@test "a child with fds closed and reaped in teardown lets test.sh pass" {
  write_inner_suite clean <<'BATS'
teardown() { kill -9 "$(cat "$BATS_TEST_TMPDIR/pid")" 2>/dev/null || true; }
@@TEST "spawns a child with inherited fds closed" {
  ( for f in /dev/fd/*; do f=${f##*/}; [ "$f" -gt 2 ] 2>/dev/null && eval "exec $f>&-" 2>/dev/null; done; exec sleep 1234 ) &
  echo $! >"$BATS_TEST_TMPDIR/pid"
  echo $! >>"$RESIDUAL_TEST_PIDS"
  sleep 1
  kill -0 "$(cat "$BATS_TEST_TMPDIR/pid")"
}
BATS
  run run_test_sh_isolated
  echo "$output"   # 失敗したときだけ bats が表示する（内側の test.sh の出力）
  [ "$status" -eq 0 ]
  [[ "$output" == *"bats: 全スイート pass"* ]]
  [[ "$output" != *"残っています"* ]]
}

# fd は閉じていても teardown で回収されなかった背景プロセスは失敗にする
@test "a child with fds closed but not reaped in teardown still fails test.sh" {
  require_process_listing
  write_inner_suite survivor <<'BATS'
@@TEST "leaves a child alive after the test" {
  ( for f in /dev/fd/*; do f=${f##*/}; [ "$f" -gt 2 ] 2>/dev/null && eval "exec $f>&-" 2>/dev/null; done; exec sleep 1234 ) &
  echo $! >>"$RESIDUAL_TEST_PIDS"
}
BATS
  run run_test_sh_isolated
  echo "$output"   # 失敗したときだけ bats が表示する（内側の test.sh の出力）
  [ "$status" -ne 0 ]
  [[ "$output" == *"回収されずに残っています"* ]]
  [[ "$output" == *"sleep 1234"* ]]
  sleep 1
  ! tracked_alive
}

# 残留のコマンドにたまたま bats-core / bats-exec / bats-format が含まれていても、
# bats 本体の実行ファイルでなければ残留として検出する
@test "a leftover whose command merely mentions bats-core is still detected" {
  require_process_listing
  mkdir -p "$BATS_TEST_TMPDIR/bats-core-fixture"
  ln -s "$(command -v sleep)" "$BATS_TEST_TMPDIR/bats-core-fixture/bats-exec-sleep"
  export FIXTURE_SLEEP="$BATS_TEST_TMPDIR/bats-core-fixture/bats-exec-sleep"
  write_inner_suite lookalike <<'BATS'
@@TEST "leaves a bats-looking child alive after the test" {
  ( for f in /dev/fd/*; do f=${f##*/}; [ "$f" -gt 2 ] 2>/dev/null && eval "exec $f>&-" 2>/dev/null; done; exec "$FIXTURE_SLEEP" 1234 ) &
  echo $! >>"$RESIDUAL_TEST_PIDS"
}
BATS
  run run_test_sh_isolated
  echo "$output"   # 失敗したときだけ bats が表示する（内側の test.sh の出力）
  [ "$status" -ne 0 ]
  [[ "$output" == *"回収されずに残っています"* ]]
  [[ "$output" == *"bats-core-fixture/bats-exec-sleep 1234"* ]]
  sleep 1
  ! tracked_alive
}

# TEST_RESIDUAL_GRACE が比較できる非負整数でなければ（小数・負数・文字・シェルの整数を溢れる桁数）、
# 検査を黙って無効にせず非 0 で終える
@test "an uncomparable TEST_RESIDUAL_GRACE is rejected with a non-zero exit" {
  write_inner_suite passing <<'BATS'
@@TEST "passes" {
  true
}
BATS
  local g
  for g in 0.5 -1 abc 9223372036854775808; do
    INNER_GRACE=$g
    run run_test_sh_isolated
    echo "grace=$g: $output"
    [ "$status" -ne 0 ]
    [[ "$output" == *"TEST_RESIDUAL_GRACE"* ]]
    [[ "$output" != *"bats: 全スイート pass"* ]]
  done
}

# 砂場など ps / pgrep がプロセス一覧を取れない環境では、検査を諦めて続行する（issue #320）。
# 検査を続けると「TAP は終わったのに残留が居る」と誤判定し、全件実行をグループごと SIGKILL する。
@test "test.sh drops the residual check and keeps going where the process list is unavailable" {
  STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
  mkdir -p "$STUB_BIN"
  local c
  for c in ps pgrep; do
    cat >"$STUB_BIN/$c" <<'STUB'
#!/bin/sh
echo "$(basename "$0"): Cannot get process list" >&2
exit 1
STUB
    chmod +x "$STUB_BIN/$c"
  done
  export STUB_BIN
  # 検査が生きていれば「回収されずに残っています」で失敗するはずの内容を流す
  write_inner_suite survivor <<'BATS'
@@TEST "leaves a child alive after the test" {
  ( for f in /dev/fd/*; do f=${f##*/}; [ "$f" -gt 2 ] 2>/dev/null && eval "exec $f>&-" 2>/dev/null; done; exec sleep 1234 ) &
  echo $! >>"$RESIDUAL_TEST_PIDS"
}
BATS
  run run_test_sh_isolated
  echo "$output"   # 失敗したときだけ bats が表示する（内側の test.sh の出力）
  [ "$status" -eq 0 ]
  [[ "$output" == *"プロセス一覧を取得できない環境"* ]]
  [[ "$output" == *"ok 1 leaves a child alive"* ]]
  [[ "$output" == *"bats: 全スイート pass"* ]]
  [[ "$output" != *"残っています"* ]]
}
