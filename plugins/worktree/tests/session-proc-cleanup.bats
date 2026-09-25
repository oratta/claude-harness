#!/usr/bin/env bats
#
# Tests for change session-devserver-cleanup (issue #470).
# spec: session-devserver-cleanup.
#
#   SessionStart -> scripts/session-proc-mark.sh   (目印を CLAUDE_ENV_FILE に追記し、掃除を切り離して起動)
#   SessionEnd   -> scripts/session-proc-end.sh    (目印を計算し、後始末を切り離して起動)
#   本体         -> scripts/session-proc-reaper.sh (--session-end <mark> / --sweep)
#
# 判定の分岐は SESSION_REAPER_PS_FIXTURE_DIR の固定 ps 出力で確かめる。固定出力を
# 使うとき reaper は信号を送らず DRY 行をログに書くだけなので、固定出力に書いた PID が
# 手元で別のプロセスに当たっても止めない。
#
# 実プロセスのテストは、このテストが起動したプロセス（偽の持ち主・python3）だけを
# 対象にする。目印の値は偽の持ち主の PID と開始時刻なので、他のセッションや他の
# プロジェクトのプロセスは目印が一致せず対象に入らない。掃除（--sweep）は実プロセスでは
# 走らせない（手元の他の目印付きプロセスを巻き込むため）。

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

M="100.FriSep251011182026"
OTHER="999.ThuSep241000002026"

setup() {
  wt_setup_paths
  REAPER="${PLUGIN_DIR}/scripts/session-proc-reaper.sh"
  MARK_SH="${PLUGIN_DIR}/scripts/session-proc-mark.sh"
  END_SH="${PLUGIN_DIR}/scripts/session-proc-end.sh"
  LOGDIR="${BATS_TEST_TMPDIR}/logs"
  LOG="${LOGDIR}/session-devserver-cleanup.log"
  FIX="${BATS_TEST_TMPDIR}/fixture"
  export REAPER MARK_SH END_SH LOGDIR LOG FIX
  export SESSION_REAPER_LOG_DIR="$LOGDIR"
  unset CLAUDE_SESSION_PROC_MARK SESSION_REAPER_PS_FIXTURE_DIR SESSION_REAPER_HOOK_PID
}

teardown() {
  # 切り離した後始末・掃除（setsid 済みで bats のプロセスグループの外）を、このテストの
  # 目印・ログディレクトリで絞って回収する。
  if [ -n "${REAL_MARK:-}" ]; then
    pkill -KILL -f "session-proc-reaper.sh --session-end ${REAL_MARK}" 2>/dev/null || true
  fi
  wt_kill_tracked_pids
}

# 固定の ps 出力を作る（pid ppid command+env / pid comm / pid lstart）。
make_fixture() {
  mkdir -p "$FIX"
  cat >"$FIX/ps-env.txt" <<EOF
  100     1 /Users/x/.local/bin/claude HOME=/Users/x PATH=/bin
  200   100 node server.js CLAUDE_SESSION_PROC_MARK=${M} PATH=/bin
  201   200 /bin/sh -c esbuild --service
  202   201 esbuild --service CLAUDE_SESSION_PROC_MARK=${M} PATH=/bin
  203   201 /bin/sleep 30
  210   200 node empty.js CLAUDE_SESSION_PROC_MARK= PATH=/bin
  211   210 /bin/sh
  220   100 node other.js CLAUDE_SESSION_PROC_MARK=${OTHER} PATH=/bin
  221   220 /bin/sleep 30
  230     1 /bin/sleep 30
  240     1 python3 -m http.server 4021 HOME=/Users/x PATH=/bin
  250   200 /bin/sh -c FOO=1 cmd
  251   250 /bin/sleep 1
  300   200 bash session-proc-reaper.sh CLAUDE_SESSION_PROC_MARK=${M} PATH=/bin
  301   300 /bin/sh
  690   100 /bin/sh -c hook
  700   690 bash session-proc-end.sh PATH=/bin
  810     1 node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js PATH=/bin
  820   810 /bin/sh -c hook
  900     1 bash lonely.sh PATH=/bin
EOF
  cat >"$FIX/ps-comm.txt" <<'EOF'
  100 /Users/x/.local/bin/claude
  200 node
  201 /bin/sh
  202 esbuild
  203 /bin/sleep
  210 node
  211 /bin/sh
  220 node
  221 /bin/sleep
  230 /bin/sleep
  240 /opt/homebrew/bin/python3
  250 /bin/sh
  251 /bin/sleep
  300 bash
  301 /bin/sh
  690 /bin/sh
  700 bash
  810 node
  820 /bin/sh
  900 bash
EOF
  cat >"$FIX/lstart.txt" <<'EOF'
  100 Fri Sep 25 10:11:18 2026
  810 Wed Sep 23 09:00:00 2026
EOF
}

# reaper を source して関数を呼ぶ（main は走らない）。
reaper_fn() {
  bash -c '. "$REAPER"; "$@"' _ "$@"
}

wait_for_log() { # <pattern> <seconds>
  local i=0
  while [ "$i" -lt "$(( $2 * 5 ))" ]; do
    grep -q -- "$1" "$LOG" 2>/dev/null && return 0
    sleep 0.2
    i=$((i + 1))
  done
  return 1
}

# ---------------------------------------------------------------------------
# 1.1 止める対象の判定（固定 ps 出力）
# ---------------------------------------------------------------------------

@test "select: marked roots, unreadable descendants only, cut at readable-unmarked, self excluded" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_select_targets "$M" "300"
  echo "$output"
  [ "$status" -eq 0 ]
  pids=$(printf '%s\n' "$output" | awk '{print $1}' | sort -n | tr '\n' ' ')
  # 200: 目印あり / 201: 読めない子孫 / 202: 目印あり（読めない 201 の子）/ 203: 読めない子孫
  [ "$pids" = "200 201 202 203 " ]
}

@test "select: kind column distinguishes marked roots from unreadable descendants" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_select_targets "$M" "300"
  printf '%s\n' "$output" | grep -Eq '^200 mark 100 node$'
  printf '%s\n' "$output" | grep -Eq '^201 desc 200 /bin/sh$'
  printf '%s\n' "$output" | grep -Eq '^202 mark 201 esbuild$'
}

@test "select: empty mark cuts the subtree (node with empty mark and its /bin/sh stay)" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_select_targets "$M" ""
  run grep -Eq '^(210|211) ' <<<"$output"
  [ "$status" -ne 0 ]
}

@test "select: NAME= word in argv makes a platform binary readable, which cuts the search" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_select_targets "$M" ""
  run grep -Eq '^(250|251) ' <<<"$output"
  [ "$status" -ne 0 ]
}

@test "select: other mark, unmarked, and unreadable non-descendants are not selected" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_select_targets "$M" ""
  run grep -Eq '^(100|220|221|230|240) ' <<<"$output"
  [ "$status" -ne 0 ]
}

@test "select: without exclusion the self process is selected (exclusion is what keeps it out)" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_select_targets "$M" ""
  printf '%s\n' "$output" | grep -Eq '^300 mark '
  printf '%s\n' "$output" | grep -Eq '^301 desc '
  run reaper_fn srp_select_targets "$M" "300"
  run grep -Eq '^(300|301) ' <<<"$output"
  [ "$status" -ne 0 ]
}

@test "readable: defined as having at least one NAME= word" {
  run reaper_fn srp_env_readable "/bin/sh -c esbuild --service"
  [ "$status" -ne 0 ]
  run reaper_fn srp_env_readable "node server.js PATH=/bin"
  [ "$status" -eq 0 ]
  run reaper_fn srp_env_readable "/bin/sh -c FOO=1 cmd"
  [ "$status" -eq 0 ]
  run reaper_fn srp_env_readable "tool 1=2 a.b=c"
  [ "$status" -ne 0 ]
}

@test "ps: live listing is limited to the current user's processes (-U uid) with -E" {
  grep -Eq 'ps -U "\$\(id -u\)" -ww -E -o pid=,ppid=,command=' "$REAPER"
  grep -Eq 'ps -U "\$\(id -u\)" -o pid=,comm=' "$REAPER"
}

# ---------------------------------------------------------------------------
# 1.2 持ち主の Claude Code の見つけ方と start_token
# ---------------------------------------------------------------------------

@test "owner: walks parents to the native claude binary" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_find_owner 700
  [ "$status" -eq 0 ]
  [ "$output" = "100" ]
}

@test "owner: accepts node running @anthropic-ai/claude-code" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_find_owner 820
  [ "$status" -eq 0 ]
  [ "$output" = "810" ]
}

@test "owner: returns failure when no claude ancestor exists" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_find_owner 900
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "mark: value is <pid>.<lstart without non-alphanumerics>" {
  make_fixture
  export SESSION_REAPER_PS_FIXTURE_DIR="$FIX"
  run reaper_fn srp_mark_for 100
  [ "$status" -eq 0 ]
  [ "$output" = "$M" ]
}

@test "start_token: identical under LC_TIME=ja_JP.UTF-8 and LC_ALL=C (live ps)" {
  wt_require_process_listing
  local ja c
  ja=$(LANG=ja_JP.UTF-8 LC_TIME=ja_JP.UTF-8 bash -c '. "$REAPER"; srp_start_token '"$$")
  c=$(LC_ALL=C bash -c '. "$REAPER"; srp_start_token '"$$")
  echo "ja=$ja c=$c"
  [ -n "$c" ]
  [ "$ja" = "$c" ]
  # 英語の曜日で始まる（LC_ALL=C の書式）
  printf '%s' "$c" | grep -Eq '^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[A-Z][a-z]{2}[0-9]+$'
}

@test "start_token: identical under TZ=Asia/Tokyo and TZ=UTC for the same process (live ps)" {
  wt_require_process_listing
  local jst utc
  jst=$(TZ=Asia/Tokyo bash -c '. "$REAPER"; srp_start_token '"$$")
  utc=$(TZ=UTC bash -c '. "$REAPER"; srp_start_token '"$$")
  echo "jst=$jst utc=$utc"
  [ -n "$utc" ]
  [ "$jst" = "$utc" ]
}

@test "start_token: empty for a pid that does not exist" {
  wt_require_process_listing
  run reaper_fn srp_start_token 999999
  [ -z "$output" ]
}

@test "reaper: sourcing does not run main" {
  run bash -c '. "$REAPER"; echo sourced-ok'
  [ "$status" -eq 0 ]
  [ "$output" = "sourced-ok" ]
  [ ! -e "$LOG" ]
}

# ---------------------------------------------------------------------------
# 1.3 目印付け（session-proc-mark.sh）
# ---------------------------------------------------------------------------

fresh_stamp() {
  mkdir -p "$LOGDIR"
  touch "$LOGDIR/session-devserver-cleanup.sweep-stamp"
}

@test "mark.sh: appends one export line to CLAUDE_ENV_FILE and keeps existing content" {
  make_fixture
  fresh_stamp
  local envf="${BATS_TEST_TMPDIR}/env"
  printf 'export FOO=1\n' >"$envf"
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_HOOK_PID=700 \
    CLAUDE_ENV_FILE="$envf" "$MARK_SH" </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(sed -n 1p "$envf")" = "export FOO=1" ]
  [ "$(sed -n 2p "$envf")" = "export CLAUDE_SESSION_PROC_MARK=${M}" ]
  [ "$(wc -l <"$envf" | tr -d ' ')" = "2" ]
}

@test "mark.sh: exported line reaches child processes of a shell that sources the file" {
  make_fixture
  fresh_stamp
  local envf="${BATS_TEST_TMPDIR}/env"
  : >"$envf"
  env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_HOOK_PID=700 \
    CLAUDE_ENV_FILE="$envf" "$MARK_SH" </dev/null
  run bash -c ". '$envf'; sh -c 'printf %s \"\$CLAUDE_SESSION_PROC_MARK\"'"
  [ "$output" = "$M" ]
}

@test "mark.sh: CLAUDE_ENV_FILE unset -> no output, exit 0" {
  make_fixture
  fresh_stamp
  run env -u CLAUDE_ENV_FILE SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_HOOK_PID=700 \
    "$MARK_SH" </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "mark.sh: owner not found -> env file untouched, logged, exit 0" {
  make_fixture
  fresh_stamp
  local envf="${BATS_TEST_TMPDIR}/env"
  printf 'export FOO=1\n' >"$envf"
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_HOOK_PID=900 \
    CLAUDE_ENV_FILE="$envf" "$MARK_SH" </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "$envf")" = "export FOO=1" ]
  grep -q 'no-owner .*trigger=session-start' "$LOG"
}

@test "mark.sh: unwritable CLAUDE_ENV_FILE -> no output, exit 0" {
  make_fixture
  fresh_stamp
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_HOOK_PID=700 \
    CLAUDE_ENV_FILE="${BATS_TEST_TMPDIR}/no/such/dir/env" "$MARK_SH" </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# 1.6 掃除の間隔（スタンプファイルはログと同じディレクトリ）
# ---------------------------------------------------------------------------

@test "sweep interval: no stamp -> stamp is created next to the log and the sweep runs" {
  make_fixture
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_HOOK_PID=700 \
    SESSION_REAPER_SWEEP_INTERVAL_SECS=600 "$MARK_SH" </dev/null
  [ "$status" -eq 0 ]
  [ -f "$LOGDIR/session-devserver-cleanup.sweep-stamp" ]
  wait_for_log 'trigger=sweep' 10
}

@test "sweep interval: fresh stamp -> the sweep does not run" {
  make_fixture
  fresh_stamp
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_HOOK_PID=700 \
    SESSION_REAPER_SWEEP_INTERVAL_SECS=600 "$MARK_SH" </dev/null
  [ "$status" -eq 0 ]
  sleep 1
  run grep -q 'trigger=sweep' "$LOG"
  [ "$status" -ne 0 ]
}

@test "sweep interval: stamp older than the interval -> the sweep runs" {
  make_fixture
  fresh_stamp
  touch -t 202001010000 "$LOGDIR/session-devserver-cleanup.sweep-stamp"
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_HOOK_PID=700 \
    SESSION_REAPER_SWEEP_INTERVAL_SECS=600 "$MARK_SH" </dev/null
  [ "$status" -eq 0 ]
  wait_for_log 'trigger=sweep' 10
}

@test "sweep: targets only marks whose owner is gone (live owner's processes are kept)" {
  make_fixture
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" "$REAPER" --sweep
  [ "$status" -eq 0 ]
  cat "$LOG"
  # OTHER の持ち主 999 は存在しない -> 220（目印あり）と 221（読めない子孫）
  grep -Eq "DRY pid=220 comm=node mark=${OTHER} trigger=sweep" "$LOG"
  grep -Eq "DRY pid=221 comm=sleep mark=${OTHER} trigger=sweep" "$LOG"
  # M の持ち主 100 は同じ開始時刻で生きている -> 対象外
  run grep -Eq "mark=${M}" "$LOG"
  [ "$status" -ne 0 ]
}

@test "sweep: owner pid reused with a different start time counts as gone" {
  make_fixture
  printf '  100 Sat Sep 26 08:00:00 2026\n' >"$FIX/lstart.txt"
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" "$REAPER" --sweep
  [ "$status" -eq 0 ]
  grep -Eq "DRY pid=200 comm=node mark=${M} trigger=sweep" "$LOG"
}

@test "sweep: nothing to stop still leaves one 'none' line" {
  mkdir -p "$FIX"
  printf '  100     1 /Users/x/.local/bin/claude HOME=/x\n' >"$FIX/ps-env.txt"
  printf '  100 claude\n' >"$FIX/ps-comm.txt"
  printf '  100 Fri Sep 25 10:11:18 2026\n' >"$FIX/lstart.txt"
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" "$REAPER" --sweep
  [ "$status" -eq 0 ]
  grep -Eq ' none .*trigger=sweep' "$LOG"
}

@test "session-end (fixture): owner alive after the wait -> nothing stopped, 'none' logged" {
  make_fixture
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" SESSION_REAPER_OWNER_WAIT_SECS=0 \
    "$REAPER" --session-end "$M"
  [ "$status" -eq 0 ]
  grep -Eq " none mark=${M} trigger=session-end reason=owner-alive" "$LOG"
  run grep -q 'DRY' "$LOG"
  [ "$status" -ne 0 ]
}

@test "session-end: malformed mark is refused without stopping anything" {
  make_fixture
  run env SESSION_REAPER_PS_FIXTURE_DIR="$FIX" "$REAPER" --session-end "bad mark"
  [ "$status" -ne 0 ]
  run grep -q 'DRY' "$LOG"
  [ "$status" -ne 0 ]
}

@test "log: rotates to one .1 generation above 1MB" {
  mkdir -p "$LOGDIR"
  head -c 1100000 /dev/zero | tr '\0' 'x' >"$LOG"
  run reaper_fn srp_log "none mark=- trigger=sweep"
  [ -f "$LOG.1" ]
  [ "$(wc -l <"$LOG" | tr -d ' ')" = "1" ]
}

@test "log: directory falls back to ~/.claude/logs when CLAUDE_PLUGIN_DATA is unset" {
  run env -u SESSION_REAPER_LOG_DIR -u CLAUDE_PLUGIN_DATA HOME=/nonexistent-home \
    bash -c '. "$REAPER"; srp_log_dir'
  [ "$output" = "/nonexistent-home/.claude/logs" ]
  run env -u SESSION_REAPER_LOG_DIR CLAUDE_PLUGIN_DATA=/pd bash -c '. "$REAPER"; srp_log_dir'
  [ "$output" = "/pd" ]
}

# ---------------------------------------------------------------------------
# 1.4 / 1.5 実プロセス（このテストが起動したものだけが対象）
# ---------------------------------------------------------------------------

# 偽の持ち主を起動する。macOS の ps -o comm= は argv[0] を返すので、exec -a で comm を claude にする
# （/bin/sleep を claude の名前で複製すると署名の検査で即 KILL される）。Linux の comm は argv[0] ではなく
# 実行したファイル名なので、/bin/sleep を claude という名前で複製して起動する。
start_fake_owner() {
  if [ "$(uname -s)" = Darwin ]; then
    ( wt_close_inherited_fds && exec -a "${BATS_TEST_TMPDIR}/bin/claude" /bin/sleep 300 ) &
  else
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    cp /bin/sleep "${BATS_TEST_TMPDIR}/bin/claude"
    ( wt_close_inherited_fds && exec "${BATS_TEST_TMPDIR}/bin/claude" 300 ) &
  fi
  OWNER_PID=$!
  wt_track_pid "$OWNER_PID"
  sleep 0.3
  REAL_MARK="${OWNER_PID}.$(bash -c '. "$REAPER"; srp_start_token '"$OWNER_PID")"
  export OWNER_PID REAL_MARK
}

# python3 を目印の値 $1 で起動し PID を $2 の名前の変数に入れる。$3 が ignore なら TERM を無視する。
start_py() { # <mark-value> <varname> [ignore]
  local code='import time; time.sleep(300)'
  [ "${3:-}" = ignore ] && code='import signal, time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(300)'
  ( wt_close_inherited_fds && CLAUDE_SESSION_PROC_MARK="$1" exec python3 -c "$code" ) &
  local pid=$!
  wt_track_pid "$pid"
  eval "$2=$pid"
}

# python3 の環境変数が ps -E で読めるまで待つ。読めない環境なら skip。
require_env_visible() { # <pid>
  local i=0
  while [ "$i" -lt 25 ]; do
    if ps -ww -E -o command= -p "$1" 2>/dev/null | grep -q 'CLAUDE_SESSION_PROC_MARK='; then
      return 0
    fi
    sleep 0.2
    i=$((i + 1))
  done
  skip "environment of python3 is not readable via ps -E"
}

alive() { kill -0 "$1" 2>/dev/null; }

@test "real: owner still alive -> session-end stops nothing" {
  wt_require_process_listing
  command -v python3 >/dev/null 2>&1 || skip "python3 unavailable"
  start_fake_owner
  start_py "$REAL_MARK" P1
  require_env_visible "$P1"
  run env SESSION_REAPER_OWNER_WAIT_SECS=1 "$REAPER" --session-end "$REAL_MARK"
  [ "$status" -eq 0 ]
  alive "$P1"
  grep -Eq " none mark=${REAL_MARK} trigger=session-end reason=owner-alive" "$LOG"
}

@test "real: after owner exits, marked python3 stops, empty-mark python3 stays, TERM-ignoring one is KILLed, all logged" {
  wt_require_process_listing
  command -v python3 >/dev/null 2>&1 || skip "python3 unavailable"
  start_fake_owner
  start_py "$REAL_MARK" P1
  start_py "" P2
  start_py "$REAL_MARK" P3 ignore
  require_env_visible "$P1"
  require_env_visible "$P2"
  require_env_visible "$P3"
  sleep 0.5   # TERM を無視する設定が効くまで待つ
  kill -KILL "$OWNER_PID"
  sleep 0.2
  run env SESSION_REAPER_OWNER_WAIT_SECS=5 SESSION_REAPER_TERM_GRACE_SECS=1 \
    "$REAPER" --session-end "$REAL_MARK"
  [ "$status" -eq 0 ]
  cat "$LOG"
  sleep 0.3
  run alive "$P1"; [ "$status" -ne 0 ]
  run alive "$P3"; [ "$status" -ne 0 ]
  alive "$P2"
  grep -Eq " TERM pid=${P1} comm=[^ ]+ mark=${REAL_MARK} trigger=session-end" "$LOG"
  grep -Eq " KILL pid=${P3} comm=[^ ]+ mark=${REAL_MARK} trigger=session-end" "$LOG"
  run grep -Eq "pid=${P2} " "$LOG"
  [ "$status" -ne 0 ]
}

@test "real: an unreadable child (/bin/sleep) of a marked python3 is stopped, not orphaned by its parent's TERM" {
  wt_require_process_listing
  command -v python3 >/dev/null 2>&1 || skip "python3 unavailable"
  start_fake_owner
  ( wt_close_inherited_fds && CLAUDE_SESSION_PROC_MARK="$REAL_MARK" \
      exec python3 -c 'import subprocess, time; subprocess.Popen(["/bin/sleep", "300"]); time.sleep(300)' ) &
  P1=$!
  wt_track_pid "$P1"
  require_env_visible "$P1"
  local i=0 C1=""
  while [ -z "$C1" ] && [ "$i" -lt 25 ]; do
    C1=$(pgrep -P "$P1" sleep | head -1)
    sleep 0.2
    i=$((i + 1))
  done
  [ -n "$C1" ]
  wt_track_pid "$C1"
  kill -KILL "$OWNER_PID"
  sleep 0.2
  run env SESSION_REAPER_OWNER_WAIT_SECS=5 SESSION_REAPER_TERM_GRACE_SECS=1 \
    "$REAPER" --session-end "$REAL_MARK"
  [ "$status" -eq 0 ]
  cat "$LOG"
  sleep 0.3
  run alive "$P1"; [ "$status" -ne 0 ]
  run alive "$C1"; [ "$status" -ne 0 ]
  grep -Eq " TERM pid=${C1} comm=sleep mark=${REAL_MARK} trigger=session-end" "$LOG"
}

@test "real: session-end hook returns within 1.5s and the detached reaper survives killing the hook's process group" {
  wt_require_process_listing
  command -v python3 >/dev/null 2>&1 || skip "python3 unavailable"
  command -v perl >/dev/null 2>&1 || skip "perl unavailable"
  start_fake_owner
  start_py "$REAL_MARK" P1
  require_env_visible "$P1"

  # フックを新しいプロセスグループの中で起動し、戻ったらグループごと KILL する。
  local grp="${BATS_TEST_TMPDIR}/grp" t0 t1
  t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  ( wt_close_inherited_fds && SESSION_REAPER_HOOK_PID="$OWNER_PID" SESSION_REAPER_OWNER_WAIT_SECS=20 \
      SESSION_REAPER_TERM_GRACE_SECS=1 GRP="$grp" \
      exec perl -e 'setpgrp(0,0); open(my $f,">",$ENV{GRP}) or die; print $f $$; close $f;
                    system(@ARGV); exit($? >> 8)' -- "$END_SH" </dev/null )
  t1=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  perl -e 'exit(($ARGV[1] - $ARGV[0]) < 1.5 ? 0 : 1)' "$t0" "$t1"
  kill -KILL "-$(cat "$grp")" 2>/dev/null || true

  # 後始末は持ち主の終了を待って生きている
  sleep 0.5
  pgrep -f "session-proc-reaper.sh --session-end ${REAL_MARK}" >/dev/null
  alive "$P1"

  # 持ち主が終わると後始末が止める
  kill -KILL "$OWNER_PID"
  wait_for_log "TERM pid=${P1} " 15
  local i=0
  while alive "$P1" && [ "$i" -lt 25 ]; do sleep 0.2; i=$((i + 1)); done
  run alive "$P1"; [ "$status" -ne 0 ]
  grep -Eq " TERM pid=${P1} comm=[^ ]+ mark=${REAL_MARK} trigger=session-end" "$LOG"
}

@test "real: the detached reaper does not carry CLAUDE_SESSION_PROC_MARK" {
  wt_require_process_listing
  start_fake_owner
  ( wt_close_inherited_fds && CLAUDE_SESSION_PROC_MARK="$REAL_MARK" SESSION_REAPER_HOOK_PID="$OWNER_PID" \
      SESSION_REAPER_OWNER_WAIT_SECS=20 exec "$END_SH" </dev/null )
  local rp="" i=0
  while [ -z "$rp" ] && [ "$i" -lt 25 ]; do
    rp=$(pgrep -f "session-proc-reaper.sh --session-end ${REAL_MARK}" | head -1)
    sleep 0.2; i=$((i + 1))
  done
  [ -n "$rp" ]
  # Linux の ps -E では環境変数が読めず、読めないまま「持っていない」と通ってしまうので /proc を読む
  if [ -r "/proc/$rp/environ" ]; then
    run bash -c "tr '\\0' '\\n' </proc/$rp/environ | grep -q '^CLAUDE_SESSION_PROC_MARK='"
  else
    run bash -c "ps -ww -E -o command= -p $rp | grep -q 'CLAUDE_SESSION_PROC_MARK='"
  fi
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# 1.7 配線
# ---------------------------------------------------------------------------

@test "hooks.json: SessionStart runs session-proc-mark.sh and SessionEnd runs session-proc-end.sh" {
  run python3 -c "
import json
d = json.load(open('${HOOKS_JSON}'))['hooks']
start = [h['command'] for g in d['SessionStart'] for h in g['hooks']]
end = [h['command'] for g in d['SessionEnd'] for h in g['hooks']]
assert any(c == '\${CLAUDE_PLUGIN_ROOT}/scripts/session-proc-mark.sh' for c in start), start
assert any(c == '\${CLAUDE_PLUGIN_ROOT}/scripts/session-proc-end.sh' for c in end), end
assert all(g.get('matcher') == 'startup|resume|clear' for g in d['SessionStart']), d['SessionStart']
"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "scripts: exist, are executable and pass bash -n" {
  for f in "$REAPER" "$MARK_SH" "$END_SH"; do
    [ -x "$f" ]
    bash -n "$f"
  done
}
