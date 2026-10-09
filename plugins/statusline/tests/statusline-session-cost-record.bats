#!/usr/bin/env bats
#
# statusline-session-cost-record:
#   statusline.sh が Claude Code 本体のセッションコスト（stdin の cost.total_cost_usd）を
#   <設定ディレクトリ>/.session-cost/<session_id> に 1 行で書き残す契約。読み手は cost-ledger。
#
# spec: session-cost-record
#
# このリポジトリの bats は途中に置いた [[ ]] が偽でも素通りする環境があるので、
# アサーションには || return 1 を付ける（tests/bats-assertion-guard.bats が検査する）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SL="${PLUGIN_DIR}/scripts/statusline.sh"
  WORK="$(mktemp -d)"
  export HOME="$WORK/home" FLATMATE_RATE_SHARE_CONF="$WORK/no-share-conf"
  unset FLATMATE_RATE_SHARE_DIR
  mkdir -p "$HOME"
  export CLAUDE_CONFIG_DIR="$WORK"
  export STATUSLINE_API_PACE=0
  export STATUSLINE_CODEX=0
  unset CLAUDE_ACCOUNTS_FILE USAGE_SESSIONS_DIR CLAUDE_SECURESTORAGE_CONFIG_DIR STATUSLINE_SESSION_COST
  REC_DIR="$WORK/.session-cost"
  NOW=1000
  export NOW
  # 記録に書かれる時刻を決め打ちにするため、`date +%s` を固定する
  date() {
    if [ "$1" = "+%s" ]; then
      printf '%s\n' "$NOW"
    else
      command date "$@"
    fi
  }
  export -f date
}

teardown() {
  chmod -R u+w "$WORK" 2>/dev/null
  rm -rf "$WORK"
}

# $1=session_id（JSON 文字列の中身。空なら付けない） $2=cost.total_cost_usd の表記（空なら cost を付けない）
mk_input() {
  local sid_field="" cost_field=""
  [ -z "$1" ] || sid_field="\"session_id\":\"$1\","
  [ -z "${2-}" ] || cost_field=",\"cost\":{\"total_cost_usd\":$2}"
  printf '{%s"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91}%s}' \
    "$sid_field" "$WORK" "$cost_field"
}

# $1=時刻 $2=session_id $3=値 → その時刻に描画する
render() {
  NOW="$1"
  export NOW
  mk_input "$2" "${3-}" | bash "$SL"
}

# $1=日数 $2=ファイル → 更新時刻をその日数だけ前にする
age_days() {
  python3 -c 'import os,sys,time; t=time.time()-int(sys.argv[1])*86400; os.utime(sys.argv[2],(t,t))' "$1" "$2"
}

# $1=ファイル → inode と更新時刻（書き換えられていないことの判定に使う）
stamp() {
  python3 -c 'import os,sys; s=os.stat(sys.argv[1]); print(s.st_ino, s.st_mtime_ns)' "$1"
}

@test "session-cost-record: the first render creates the record" {  # 最初の描画で記録ができる
  render 1000 abc-123 0.25 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 1000 0.25 1000 0.25" ] || return 1
}

@test "session-cost-record: a larger value replaces only the last observation" {  # 値が増えたら最後の観測だけを差し替える
  render 1000 abc-123 0.25 >/dev/null
  render 1300 abc-123 1.5 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 1000 0.25 1300 1.5" ] || return 1
}

@test "session-cost-record: an unchanged value does not rewrite the file" {  # 値が同じ描画では書かない
  mkdir -p "$REC_DIR"
  printf '1 1000 0.25 1300 1.5\n' > "$REC_DIR/abc-123"
  before="$(stamp "$REC_DIR/abc-123")"
  render 1400 abc-123 1.5 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 1000 0.25 1300 1.5" ] || return 1
  [ "$(stamp "$REC_DIR/abc-123")" = "$before" ] || return 1
}

@test "session-cost-record: the same number in another notation does not rewrite the file" {  # 表記だけが違う同じ値では書かない
  mkdir -p "$REC_DIR"
  printf '1 1000 0.25 1300 1.5\n' > "$REC_DIR/abc-123"
  before="$(stamp "$REC_DIR/abc-123")"
  render 1400 abc-123 1.50 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 1000 0.25 1300 1.5" ] || return 1
  [ "$(stamp "$REC_DIR/abc-123")" = "$before" ] || return 1
}

@test "session-cost-record: a smaller value restarts the interval" {  # 値が下がったら区間を始め直す
  mkdir -p "$REC_DIR"
  printf '1 1000 0.25 1300 1.5\n' > "$REC_DIR/abc-123"
  render 2000 abc-123 0 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 2000 0 2000 0" ] || return 1
}

@test "session-cost-record: a malformed record is recreated" {  # 壊れた記録は作り直す
  mkdir -p "$REC_DIR"
  printf 'garbage\n' > "$REC_DIR/abc-123"
  render 3000 abc-123 0.4 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 3000 0.4 3000 0.4" ] || return 1
  printf '2 1000 0.25 1300 1.5\n' > "$REC_DIR/abc-123"
  render 3100 abc-123 0.4 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 3100 0.4 3100 0.4" ] || return 1
  printf '1 1000 0.25 1300 1.5 extra\n' > "$REC_DIR/abc-123"
  render 3200 abc-123 0.4 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 3200 0.4 3200 0.4" ] || return 1
}

@test "session-cost-record: a session_id unusable as a file name writes nothing" {  # ファイル名に使えない session_id では書かない
  render 1000 "../evil" 0.25 >/dev/null
  [ ! -e "$WORK/evil" ] || return 1
  [ -z "$(ls -A "$REC_DIR" 2>/dev/null)" ] || return 1
  render 1000 "a b" 0.25 >/dev/null
  render 1000 "a/b" 0.25 >/dev/null
  render 1000 "" 0.25 >/dev/null
  render 1000 "$(printf 'x%.0s' $(seq 1 129))" 0.25 >/dev/null
  [ -z "$(ls -A "$REC_DIR" 2>/dev/null)" ] || return 1
  # 128 文字ちょうどは書く
  render 1000 "$(printf 'x%.0s' $(seq 1 128))" 0.25 >/dev/null
  [ "$(ls -A "$REC_DIR" | wc -l | tr -d ' ')" = "1" ] || return 1
}

@test "session-cost-record: no usable cost value writes nothing" {  # 本体の値が無い入力では書かない
  render 1000 abc-123 >/dev/null
  render 1000 abc-123 '"abc"' >/dev/null
  render 1000 abc-123 null >/dev/null
  render 1000 abc-123 -1 >/dev/null
  [ -z "$(ls -A "$REC_DIR" 2>/dev/null)" ] || return 1
}

@test "session-cost-record: the record is written even when the display is off" {  # 表示を消していても書く
  export STATUSLINE_SESSION_COST=0
  render 1000 abc-123 0.25 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 1000 0.25 1000 0.25" ] || return 1
}

@test "session-cost-record: output is identical whether or not the record can be written" {  # 記録の有無で表示が変わらない
  NOW=1000
  export NOW
  mk_input abc-123 0.25 | bash "$SL" > "$WORK/out.ok" 2> "$WORK/err.ok"
  rc_ok=$?
  [ -f "$REC_DIR/abc-123" ] || return 1
  rm -rf "$REC_DIR"
  : > "$REC_DIR"   # ディレクトリの位置に通常ファイルを置いて書けなくする
  mk_input abc-123 0.25 | bash "$SL" > "$WORK/out.ng" 2> "$WORK/err.ng"
  rc_ng=$?
  [ "$rc_ok" -eq 0 ] || return 1
  [ "$rc_ng" -eq 0 ] || return 1
  [ ! -s "$WORK/err.ok" ] || return 1
  [ ! -s "$WORK/err.ng" ] || return 1
  [ -s "$WORK/out.ok" ] || return 1
  cmp -s "$WORK/out.ok" "$WORK/out.ng" || return 1
  [ -f "$REC_DIR" ] || return 1
}

@test "session-cost-record: an unwritable record directory does not change output" {  # 書けないディレクトリでも表示とエラーを変えない
  render 1000 abc-123 0.25 > "$WORK/out.ok" 2> "$WORK/err.ok"
  chmod a-w "$REC_DIR"
  render 1300 abc-123 0.5 > "$WORK/out.ng" 2> "$WORK/err.ng"
  rc=$?
  chmod u+w "$REC_DIR"
  [ "$rc" -eq 0 ] || return 1
  [ ! -s "$WORK/err.ng" ] || return 1
  [ -z "$(ls -A "$REC_DIR" | grep -v '^abc-123$')" ] || return 1
}

@test "session-cost-record: no temporary file is left behind" {  # 一時ファイルが残らない
  render 1000 abc-123 0.25 >/dev/null
  render 1300 abc-123 1.5 >/dev/null
  [ "$(ls -A "$REC_DIR")" = "abc-123" ] || return 1
}

@test "session-cost-record: old records are removed when a new record is created" {  # 古い記録を消すのは新しい記録を作るときだけ
  mkdir -p "$REC_DIR"
  printf '1 1 0.1 2 0.2\n' > "$REC_DIR/old-session"
  printf '1 1 0.1 2 0.2\n' > "$REC_DIR/recent-session"
  age_days 401 "$REC_DIR/old-session"
  age_days 399 "$REC_DIR/recent-session"
  render 1000 new-session 0.25 >/dev/null
  [ ! -e "$REC_DIR/old-session" ] || return 1
  [ -f "$REC_DIR/recent-session" ] || return 1
  [ -f "$REC_DIR/new-session" ] || return 1
}

@test "session-cost-record: renders that do not create a record leave old records alone" {  # 値が同じ描画・値が増えた描画では古い記録に触らない
  mkdir -p "$REC_DIR"
  printf '1 1 0.1 2 0.2\n' > "$REC_DIR/old-session"
  printf '1 1000 0.25 1300 1.5\n' > "$REC_DIR/abc-123"
  age_days 401 "$REC_DIR/old-session"
  render 1400 abc-123 1.5 >/dev/null
  [ -f "$REC_DIR/old-session" ] || return 1
  render 1500 abc-123 2.5 >/dev/null
  [ "$(cat "$REC_DIR/abc-123")" = "1 1000 0.25 1500 2.5" ] || return 1
  [ -f "$REC_DIR/old-session" ] || return 1
}
