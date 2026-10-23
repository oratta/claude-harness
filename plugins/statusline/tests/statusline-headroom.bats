#!/usr/bin/env bats
#
# statusline-headroom: .headroom.json（dev-workflow の headroom.py が書く schema 1）を読み、
# リセット権で使える量が増えたアカウントの行をロケットモードで描く。
#
# spec: statusline-multi-account-usage
#   「`.headroom.json` の値を使えるアカウントを決める」「ロケットモードのための列を空ける」
#   「Claude のロケットモードを描く」「Codex のロケットモードを描く」「リセット権の区画を 🚀 と数で描く」
#   「Codex の行の名前は Codex とアカウント名にする」
# 実ホームには触れない。今の描き方に戻るケースは origin/main の statusline.sh と比べる。

setup() {
  export LC_ALL=C.UTF-8
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SL="${PLUGIN_DIR}/scripts/statusline.sh"
  WORK="$(mktemp -d)"
  export HOME="$WORK/home" FLATMATE_RATE_SHARE_CONF="$WORK/no-share-conf"
  unset FLATMATE_RATE_SHARE_DIR
  mkdir -p "$HOME"
  export CLAUDE_CONFIG_DIR="$WORK"
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR
  export STATUSLINE_API_PACE=0
  export STATUSLINE_CODEX=0
  unset CLAUDE_ACCOUNTS_FILE
  ACCOUNTS="${WORK}/accounts.json"
  SNAP="${WORK}/.usage-snapshot"
  HR="${WORK}/.headroom.json"
  SECURE_B="${WORK}/claude-b"
  NOW="$(date +%s)"
  export NOW
  # 新旧 2 回の呼び出しで現在時刻をそろえる（理由は statusline-reset-grants.bats の setup を参照）
  date() {
    if [ "$1" = "+%s" ]; then
      printf '%s\n' "$NOW"
    else
      command date "$@"
    fi
  }
  export -f date
  # 7d の日程消化率が 59% になる残り秒（604800 × 0.41）
  W59=247968
}

teardown() {
  chmod -R u+w "$WORK" 2>/dev/null || true
  rm -rf "$WORK"
}

# ---------- 準備 ----------

# $1=5h消化率 $2=7d消化率 $3=5h残り秒 $4=7d残り秒 → stdin JSON
mk_input() {
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}}' \
    "$WORK" "$1" "$((NOW + $3))" "$2" "$((NOW + $4))"
}

strip_ansi() { sed $'s/\033\\[[0-9;]*m//g'; }

# $1=accounts の要素を並べた JSON（カンマ区切り） $2=computed_at（既定 NOW）
write_hr() {
  printf '{"schema":1,"computed_at":%s,"settings":{"cap_7d_pct":90,"normal_rate_pct_per_day":null},"best":null,"best_by_provider":{"claude":null,"codex":null},"accounts":[%s]}\n' \
    "${2:-$NOW}" "$1" > "$HR"
}

# $1=provider $2=account $3=status $4=weekly_reset_at $5=rocket $6=tickets $7=capacity_pct → 要素の JSON
el() {
  printf '{"provider":"%s","account":"%s","label":null,"status":"%s","observed_at":%s,"five_hour_pct":10,"used_pct":20,"elapsed_pct":59,"weekly_reset_at":%s,"rocket":%s,"tickets":%s,"capacity_pct":%s,"left_pct":null,"deadline_at":null,"deadline_reason":null,"forecast":null,"surplus_pct":null,"margin":null}' \
    "$1" "$2" "$3" "$NOW" "$4" "$5" "$6" "$7"
}

# $1=count $2=earliest_expiry → {count, earliest_expiry}
rk() { printf '{"count":%s,"earliest_expiry":%s}' "$1" "$2"; }

write_two_slot_registry() {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
}

# 2 スロットの snapshot（a が active。b の 7d は 1%・リセットは NOW+172800）。$1=b の reset_grants（空なら欄なし）
write_two_slot_snapshot() {
  local rg=""
  [ -n "$1" ] && rg=", \"reset_grants\": $1"
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "a", "fetched_at": $NOW,
  "accounts": {
    "a": { "label": "A", "securestorage": null, "fetched_at": $NOW,
           "five_hour_pct": 55, "five_hour_resets_epoch": $((NOW + 14000)),
           "weekly_all_pct": 20, "weekly_resets_epoch": $((NOW + W59)) },
    "b": { "label": "B", "securestorage": "${SECURE_B}", "fetched_at": $((NOW - 7200)),
           "five_hour_pct": 3, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 1, "weekly_resets_epoch": $((NOW + 172800))${rg} } } }
JSON
}

# 1 スロット（登録簿なし）の snapshot。$1=reset_grants（空なら欄なし）
write_one_slot_snapshot() {
  local rg=""
  [ -n "$1" ] && rg=", \"reset_grants\": $1"
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "default", "fetched_at": $NOW,
  "accounts": { "default": { "label": "default", "securestorage": null, "fetched_at": $NOW,
    "five_hour_pct": 55, "five_hour_resets_epoch": $((NOW + 14000)),
    "weekly_all_pct": 20, "weekly_resets_epoch": $((NOW + W59))${rg} } } }
JSON
}

# Codex の行を出す。$1=週次の消化率 $2=週次のリセットまでの秒。CODEX_WEEK に週次のリセット時刻を入れる
codex_env() {
  export STATUSLINE_CODEX=1 CODEX_HOME="$WORK/codex-home" STATUSLINE_CODEX_BIN="$WORK/codex-stub"
  mkdir -p "$CODEX_HOME"
  printf '#!/bin/sh\nexit 0\n' > "$STATUSLINE_CODEX_BIN"; chmod 700 "$STATUSLINE_CODEX_BIN"
  echo '{"tokens":{"account_id":"test"}}' > "$CODEX_HOME/auth.json"
  local key
  key="$(python3 -c "
import importlib.util
sp=importlib.util.spec_from_file_location('c','${PLUGIN_DIR}/scripts/statusline-codex.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);print(m.identity())")"
  CODEX_WEEK=$((NOW + $2))
  cat > "$WORK/.statusline-codex" <<JSON
{"identity":"$key","windows":[{"pct":10,"minutes":300,"reset":$((NOW + 3600))},{"pct":$1,"minutes":10080,"reset":$CODEX_WEEK}],
 "fetched_at":$NOW,"next_attempt":$((NOW + 100)),
 "resets":{"availableCount":2,"credits":[{"status":"available","expiresAt":$((NOW + 86400))}]}}
JSON
}

# origin/main の statusline.sh を $WORK/old/ に取り出す（取り出せなければ skip）
old_sl() {
  mkdir -p "$WORK/old"
  git -C "$REPO_ROOT" show origin/main:plugins/statusline/scripts/statusline.sh > "$WORK/old/statusline.sh" 2>/dev/null \
    || skip "origin/main is not available"
  cp "${PLUGIN_DIR}/scripts/statusline-codex.py" "$WORK/old/"
  OLD="$WORK/old/statusline.sh"
}

# $1=7d消化率 $2=7d残り秒 → 新しい statusline の出力
render() { mk_input 55 "${1:-20}" 14000 "${2:-$W59}" | bash "$SL"; }
render_old() { mk_input 55 "${1:-20}" 14000 "${2:-$W59}" | bash "$OLD"; }

# ANSI 付きの行から、最初のバーの 16 セルの背景色の番号を空白区切りで出す
bgs() { python3 -c 'import re,sys;print(" ".join(re.findall(r"\x1b\[48;5;(\d+)m▂", sys.stdin.read())[:16]))'; }

# ANSI を除いた出力（1 行目は cwd なので除く）の、バーを持つ各行の最初のバーの開始位置（表示幅）
bar_cols() {
  python3 -c '
import sys, unicodedata
for line in sys.stdin.read().splitlines()[1:]:
    if "▂" not in line:
        continue
    pre = line[:line.index("▂")]
    print(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in pre))'
}

squeeze() { tr -s ' '; }

# ---------- 今の描き方に戻る（受け入れ条件 3） ----------

@test "fallback: no .headroom.json is byte-identical to origin/main (one slot and two slots)" {
  old_sl
  write_one_slot_snapshot ''
  render > "$WORK/n.txt"; render_old > "$WORK/o.txt"
  cmp -s "$WORK/n.txt" "$WORK/o.txt"
  write_two_slot_registry; write_two_slot_snapshot ''
  render > "$WORK/n.txt"; render_old > "$WORK/o.txt"
  cmp -s "$WORK/n.txt" "$WORK/o.txt"
}

# 1 スロット・Codex なしと 2 スロットのそれぞれで、置いた .headroom.json が origin/main と同じ出力になる
assert_fallback_both() {
  local body="$1" ca="${2:-$NOW}"
  rm -f "$ACCOUNTS"
  write_one_slot_snapshot '[{"resets_left":1,"ends_at":null,"paused":false}]'
  write_hr "${body//@ID@/default}" "$ca"
  render > "$WORK/n.txt"; render_old > "$WORK/o.txt"
  cmp -s "$WORK/n.txt" "$WORK/o.txt" || { echo "one slot differs: $body"; diff "$WORK/n.txt" "$WORK/o.txt"; return 1; }
  write_two_slot_registry; write_two_slot_snapshot '[{"resets_left":1,"ends_at":null,"paused":false}]'
  write_hr "${body//@ID@/a}" "$ca"
  render > "$WORK/n.txt"; render_old > "$WORK/o.txt"
  cmp -s "$WORK/n.txt" "$WORK/o.txt" || { echo "two slots differ: $body"; diff "$WORK/n.txt" "$WORK/o.txt"; return 1; }
}

@test "fallback: status stale, missing and off are not used" {
  old_sl
  local s
  for s in stale missing off; do
    assert_fallback_both "$(el claude @ID@ "$s" $((NOW + W59)) "$(rk 1 $((NOW + 86400)))" "$(rk 3 $((NOW + 86400)))" 200)"
  done
}

@test "fallback: a file computed 21600 seconds ago is not used" {
  old_sl
  assert_fallback_both "$(el claude @ID@ ok $((NOW + W59)) "$(rk 1 $((NOW + 86400)))" "$(rk 3 $((NOW + 86400)))" 200)" $((NOW - 21600))
}

@test "fallback: unreadable shapes are not used" {
  old_sl
  local e
  e="$(el claude default ok $((NOW + W59)) "$(rk 1 $((NOW + 86400)))" "$(rk 3 $((NOW + 86400)))" 200)"
  write_one_slot_snapshot ''
  render_old > "$WORK/o.txt"
  printf 'not json {' > "$HR"
  render > "$WORK/n.txt"; cmp -s "$WORK/n.txt" "$WORK/o.txt" || { echo broken; return 1; }
  printf '{"schema":2,"computed_at":%s,"accounts":[%s]}' "$NOW" "$e" > "$HR"
  render > "$WORK/n.txt"; cmp -s "$WORK/n.txt" "$WORK/o.txt" || { echo schema2; return 1; }
  printf '{"schema":1,"computed_at":%s,"accounts":{"default":%s}}' "$NOW" "$e" > "$HR"
  render > "$WORK/n.txt"; cmp -s "$WORK/n.txt" "$WORK/o.txt" || { echo object-accounts; return 1; }
}

@test "fallback: a rocket expiry in the past is not used" {
  old_sl
  assert_fallback_both "$(el claude @ID@ ok $((NOW + W59)) "$(rk 1 $((NOW - 60)))" "$(rk 3 $((NOW + 86400)))" 200)"
}

@test "fallback: a Codex weekly reset two hours apart is not used (Codex row unchanged)" {
  old_sl
  codex_env 42 540000
  write_one_slot_snapshot ''
  write_hr "$(el codex current ok $((CODEX_WEEK + 7200)) "$(rk 1 $((NOW + 158400)))" "$(rk 3 $((NOW + 158400)))" 100)"
  render | grep 'Codex' > "$WORK/n.txt"
  render_old | grep 'Codex' > "$WORK/o.txt"
  [ -s "$WORK/n.txt" ]
  cmp -s "$WORK/n.txt" "$WORK/o.txt" || { diff "$WORK/n.txt" "$WORK/o.txt"; return 1; }
}

@test "fallback: only the usable slot changes; the stale slot keeps its content apart from the column spaces" {
  write_two_slot_registry; write_two_slot_snapshot '[{"resets_left":2,"ends_at":null,"paused":false}]'
  render | strip_ansi | grep 'Claude B' | squeeze > "$WORK/base.txt"
  write_hr "$(el claude a ok $((NOW + W59)) "$(rk 1 $((NOW + 86400)))" "$(rk 3 $((NOW + 86400)))" 200),$(el claude b stale $((NOW + 172800)) "$(rk 1 $((NOW + 86400)))" null 200)"
  render > "$WORK/raw.txt"
  strip_ansi < "$WORK/raw.txt" | grep 'Claude B' | squeeze > "$WORK/b.txt"
  cmp -s "$WORK/base.txt" "$WORK/b.txt" || { diff "$WORK/base.txt" "$WORK/b.txt"; return 1; }
  grep 'リセット2回' "$WORK/b.txt"
  strip_ansi < "$WORK/raw.txt" | grep -E 'Claude A +7d All' | grep -q '🚀'
}

@test "jq: the file is read by one jq call when present and none when absent" {
  codex_env 42 540000
  write_two_slot_registry; write_two_slot_snapshot ''
  cat > "$WORK/jq" <<SH
#!/usr/bin/env bash
for a in "\$@"; do
  case "\$a" in *.headroom.json) echo x >> "$WORK/jq-hr-calls" ;; esac
done
exec "$(command -v jq)" "\$@"
SH
  chmod +x "$WORK/jq"
  : > "$WORK/jq-hr-calls"
  mk_input 55 20 14000 "$W59" | PATH="$WORK:$PATH" bash "$SL" > /dev/null
  [ "$(wc -l < "$WORK/jq-hr-calls" | tr -d ' ')" -eq 0 ]
  write_hr "$(el claude a ok $((NOW + W59)) "$(rk 1 $((NOW + 86400)))" null 200),$(el codex current ok "$CODEX_WEEK" null null 100)"
  mk_input 55 20 14000 "$W59" | PATH="$WORK:$PATH" bash "$SL" > /dev/null
  [ "$(wc -l < "$WORK/jq-hr-calls" | tr -d ' ')" -eq 1 ]
}

# ---------- Claude のロケットモード（受け入れ条件 1） ----------

@test "claude rocket: one reset grant makes 200%" {
  write_one_slot_snapshot ''
  write_hr "$(el claude default ok $((NOW + W59)) "$(rk 1 $((NOW + 172800)))" null 200)"
  render > "$WORK/raw.txt"
  line="$(strip_ansi < "$WORK/raw.txt" | grep '7d All')"
  [[ "$line" == "7d All 🚀  ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂  20/200%   10%/59%"* ]] || { echo "$line"; return 1; }
  [ "$(grep '7d All' "$WORK/raw.txt" | bgs)" = "78 238 238 238 238 238 238 238 24 24 24 24 24 24 24 24" ]
}

@test "claude rocket: two reset grants make 🚀2 and 300%" {
  write_one_slot_snapshot ''
  write_hr "$(el claude default ok $((NOW + W59)) "$(rk 2 $((NOW + 172800)))" null 300)"
  render > "$WORK/raw.txt"
  line="$(strip_ansi < "$WORK/raw.txt" | grep '7d All')"
  [[ "$line" == "7d All 🚀2 ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂  20/300%    7%/59%"* ]] || { echo "$line"; return 1; }
  [ "$(grep '7d All' "$WORK/raw.txt" | bgs)" = "78 238 238 238 238 24 24 24 24 24 24 24 24 24 24 24" ]
}

@test "claude rocket: the 7d name gets the orange ground, the 5h name does not" {
  write_two_slot_registry; write_two_slot_snapshot ''
  write_hr "$(el claude a ok $((NOW + W59)) "$(rk 1 $((NOW + 172800)))" null 200)"
  render > "$WORK/raw.txt"
  grep '7d All' "$WORK/raw.txt" | grep -q $'\033\\[1;38;5;16;48;5;214mClaude A\033\\[0m'
  ! grep -E '5h' "$WORK/raw.txt" | grep -q $'48;5;214mClaude A' || return 1
  ! grep -q $'48;5;214mClaude B' "$WORK/raw.txt" || return 1
}

@test "claude rocket: the colour follows the share of the usable amount" {
  write_one_slot_snapshot ''
  write_hr "$(el claude default ok $((NOW + 423360)) "$(rk 1 $((NOW + 172800)))" null 200)"
  render 80 423360 > "$WORK/raw.txt"
  line="$(grep '7d All' "$WORK/raw.txt")"
  strip_ansi <<< "$line" | grep -q '80/200%   40%/30%' || { strip_ansi <<< "$line"; return 1; }
  grep -q $'\033\\[38;5;203m   40%' <<< "$line"
}

# ---------- Codex のロケットモード（受け入れ条件 1） ----------

@test "codex rocket: elapsed and time left are measured against the expiry" {
  codex_env 42 540000
  write_one_slot_snapshot ''
  write_hr "$(el codex current ok "$CODEX_WEEK" "$(rk 3 $((NOW + 158400)))" null 100)"
  render > "$WORK/raw.txt"
  line="$(strip_ansi < "$WORK/raw.txt" | grep 'Codex')"
  [[ "$line" == *"7d All 🚀  ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂            42%/29%  ~1d 20h (~6d 6h)"* ]] || { echo "$line"; return 1; }
  [[ "$line" != *"🚀3"* ]] || return 1
  grep 'Codex' "$WORK/raw.txt" | grep -q $'\033\\[1;38;5;16;48;5;214mCodex A\033\\[0m'
}

@test "codex rocket: within 24 hours the time left is red and the weekly reset is dim" {
  codex_env 42 540000
  write_one_slot_snapshot ''
  write_hr "$(el codex current ok "$CODEX_WEEK" "$(rk 1 $((NOW + 32400)))" null 100)"
  render > "$WORK/raw.txt"
  grep 'Codex' "$WORK/raw.txt" | grep -q $'\033\\[38;5;203m~9h 0m\033\\[0m \033\\[2m(~6d 6h)'
}

# ---------- 右端の区画（受け入れ条件 1・2） ----------

@test "tickets: a rocket-mode Claude shows 🚀×N in orange, red within 24 hours" {
  write_one_slot_snapshot '[{"resets_left":1,"ends_at":null,"paused":false}]'
  write_hr "$(el claude default ok $((NOW + W59)) "$(rk 1 $((NOW + 140400)))" "$(rk 3 $((NOW + 140400)))" 200)"
  render > "$WORK/raw.txt"
  grep '7d All' "$WORK/raw.txt" | grep -q $'\033\\[38;5;214m🚀×3 ~1d 15h\033\\[0m$'
  ! grep -q 'リセット' "$WORK/raw.txt" || return 1
  write_hr "$(el claude default ok $((NOW + W59)) "$(rk 1 $((NOW + 64800)))" "$(rk 3 $((NOW + 64800)))" 200)"
  render | grep '7d All' | grep -q $'\033\\[38;5;203m🚀×3 ~18h 0m'
}

@test "tickets: grants that outlive the weekly reset show a dim 🚀×N and no rocket" {
  old_sl
  write_one_slot_snapshot ''
  render_old > "$WORK/old.txt"
  write_one_slot_snapshot '[{"resets_left":1,"ends_at":null,"paused":false}]'
  write_hr "$(el claude default ok $((NOW + W59)) null "$(rk 1 $((NOW + 874800)))" 100)"
  render > "$WORK/raw.txt"
  grep '7d All' "$WORK/raw.txt" | grep -q $'\033\\[2m🚀×1 ~10d 3h\033\\[0m$'
  ! strip_ansi < "$WORK/raw.txt" | sed 's/🚀×//' | grep -q '🚀' || return 1
  ! grep -q 'リセット' "$WORK/raw.txt" || return 1
  # バーのセルと割合の数字は .headroom.json が無いときと同じ
  [ "$(grep '7d All' "$WORK/raw.txt" | bgs)" = "$(grep '7d All' "$WORK/old.txt" | bgs)" ]
  a="$(strip_ansi < "$WORK/raw.txt" | grep '7d All' | sed 's/  │  🚀×1 ~10d 3h$//' | squeeze)"
  b="$(strip_ansi < "$WORK/old.txt" | grep '7d All' | squeeze)"
  [ "$a" = "$b" ] || { echo "$a"; echo "$b"; return 1; }
}

@test "tickets: a rocket-mode Codex shows only the count" {
  codex_env 42 540000
  write_one_slot_snapshot ''
  write_hr "$(el codex current ok "$CODEX_WEEK" "$(rk 3 $((NOW + 158400)))" "$(rk 3 $((NOW + 158400)))" 100)"
  render > "$WORK/raw.txt"
  line="$(strip_ansi < "$WORK/raw.txt" | grep 'Codex')"
  [[ "$line" == *"  │  🚀×3" ]] || { echo "$line"; return 1; }
  grep 'Codex' "$WORK/raw.txt" | grep -q $'\033\\[38;5;214m🚀×3\033\\[0m$'
  ! grep -q 'リセット' "$WORK/raw.txt" || return 1
}

@test "tickets: null or zero tickets show no segment" {
  local t
  for t in null "$(rk 0 null)"; do
    write_one_slot_snapshot '[{"resets_left":1,"ends_at":null,"paused":false}]'
    write_hr "$(el claude default ok $((NOW + W59)) "$(rk 1 $((NOW + 140400)))" "$t" 200)"
    render | strip_ansi > "$WORK/out.txt"
    ! grep -q '│' "$WORK/out.txt" || { echo "case $t"; cat "$WORK/out.txt"; return 1; }
    grep '7d All' "$WORK/out.txt" | grep -q '🚀'
  done
}

# ---------- 列を空ける ----------

@test "columns: open even without reset grants, with spaces in place of 🚀 and the usable amount" {
  write_two_slot_registry; write_two_slot_snapshot ''
  write_hr "$(el claude a ok $((NOW + W59)) null null 100)"
  render | strip_ansi > "$WORK/out.txt"
  ! grep -q '🚀' "$WORK/out.txt" || return 1
  ! grep -q '/100%' "$WORK/out.txt" || return 1
  local s
  for s in A B; do
    grep -E "Claude $s" "$WORK/out.txt" | grep -qE '  5h {9}▂' || { cat "$WORK/out.txt"; return 1; }
    grep -E "Claude $s" "$WORK/out.txt" | grep -qE '  7d All {5}▂' || { cat "$WORK/out.txt"; return 1; }
  done
  grep -E 'Claude A' "$WORK/out.txt" | grep -qE '▂ {9}   20%/59%'
  grep -E 'Claude B' "$WORK/out.txt" | grep -qE '▂ {9}    1%/'
}

@test "columns: bars start at the same column with a rocket Claude and a plain Codex" {
  codex_env 42 540000
  write_two_slot_registry; write_two_slot_snapshot ''
  write_hr "$(el claude a ok $((NOW + W59)) "$(rk 1 $((NOW + 172800)))" null 200),$(el codex current ok "$CODEX_WEEK" null null 100)"
  render | strip_ansi > "$WORK/out.txt"
  grep -q '🚀' "$WORK/out.txt"
  [ "$(bar_cols < "$WORK/out.txt" | wc -l | tr -d ' ')" -eq 5 ]
  [ "$(bar_cols < "$WORK/out.txt" | sort -u | wc -l | tr -d ' ')" -eq 1 ] || { bar_cols < "$WORK/out.txt"; cat "$WORK/out.txt"; return 1; }
}

# ---------- 1 スロットで Codex の行が出るときの名前の列（受け入れ条件 4） ----------

@test "one slot with Codex: Claude rows carry the name column without the active mark" {
  codex_env 42 540000
  printf '{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null}]}' > "$ACCOUNTS"
  write_two_slot_snapshot ''
  render | strip_ansi > "$WORK/out.txt"
  grep -q '^  Claude A  5h' "$WORK/out.txt" || { cat "$WORK/out.txt"; return 1; }
  grep -q '^  Claude A  7d All' "$WORK/out.txt"
  ! grep -q '▸' "$WORK/out.txt" || return 1
  [ "$(bar_cols < "$WORK/out.txt" | sort -u | wc -l | tr -d ' ')" -eq 1 ] || { cat "$WORK/out.txt"; return 1; }
}

@test "one slot with Codex: without a registry the name is Claude" {
  codex_env 42 540000
  write_one_slot_snapshot ''
  render | strip_ansi > "$WORK/out.txt"
  grep -q '^  Claude   5h' "$WORK/out.txt" || { cat "$WORK/out.txt"; return 1; }
  grep -q '^  Claude   7d All' "$WORK/out.txt"
  [ "$(bar_cols < "$WORK/out.txt" | sort -u | wc -l | tr -d ' ')" -eq 1 ] || { cat "$WORK/out.txt"; return 1; }
}

@test "one slot without Codex: the output is byte-identical to origin/main" {
  old_sl
  printf '{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null}]}' > "$ACCOUNTS"
  write_two_slot_snapshot ''
  render > "$WORK/n.txt"; render_old > "$WORK/o.txt"
  cmp -s "$WORK/n.txt" "$WORK/o.txt"
}
