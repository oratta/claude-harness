#!/usr/bin/env bats
#
# statusline-reset-grants: Claude のアカウントの行にリセット権の残数と期限を出す
#
# spec: statusline-multi-account-usage（Claude のアカウントの行にリセット権の残数と期限を表示する）
# 値の出どころは snapshot の accounts.<id>.reset_grants だけ。実ホームには触れない。

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
  # #301 / #277: 呼び出し元の別アカウント設定をテストに持ち込まない。
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR
  export STATUSLINE_API_PACE=0
  export STATUSLINE_CODEX=0
  unset CLAUDE_ACCOUNTS_FILE
  ACCOUNTS="${WORK}/accounts.json"
  SNAP="${WORK}/.usage-snapshot"
  SECURE_B="${WORK}/claude-b"
  NOW="$(date +%s)"
  export NOW
  # #332: byte-identical 系のテストは statusline.sh（new）と origin/main の frozen
  # コピー（old）を「bash <script>」で 2 回呼び、出力を diff する。両方とも自前で
  # `date +%s` を呼んで現在時刻を取るため、2 回の呼び出しの間に実時間が経つと
  # 残り時間の表示（分単位に丸めた値）だけがずれる。old は origin/main の内容その
  # ものなので env var を読ませる改修を入れられない。そのため new/old の内部実装
  # に手を入れる方式（statusline.sh に now を渡す環境変数を足す）ではなく、
  # `date` コマンド自体を bash 関数でシャドウし `export -f` で子プロセスの bash
  # （old/new とも常に `bash <script>` で起動される）に伝播させ、`+%s` の結果を
  # この setup() で 1 回だけ取った $NOW に固定する。`+%s` 以外の呼び出し
  # （$SL の days_ago が ccusage の集計開始日を出す `date -v-30d` など）は実 date
  # にそのまま委譲するので、このシャドウで時刻に依存しない部分の比較対象を
  # 狭めてはいない（diff は全文比較のまま）。再現・検証: 意図的に old/new の
  # 呼び出しの間に 35 秒の遅延を挟むと
  # （14010 の mk_input が渡す resets_at は 14010 mod 60 = 30 秒の位置で分の桁が
  # 繰り上がるため）、シャドウ無しでは "~3h 52m" と "~3h 53m" のように再現し、
  # シャドウ適用後は同じ遅延でも差分が出ないことを確認済み。
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
  # 記録ディレクトリを書き込み不可にしたテストの後始末（権限を戻さないと rm -rf が失敗する）
  chmod -R u+w "$WORK" 2>/dev/null || true
  rm -rf "$WORK"
}

# $1=5h消化率 $2=7d消化率 $3=5h残り秒 $4=7d残り秒 → stdin JSON
mk_input() {
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}}' \
    "$WORK" "$1" "$((NOW + $3))" "$2" "$((NOW + $4))"
}

strip_ansi() { sed $'s/\033\\[[0-9;]*m//g'; }

# $1=reset_grants の JSON（空なら欄なし）。1 スロット（レジストリ不在）の snapshot を書く
write_snap() {
  local rg=""
  [ -n "$1" ] && rg=", \"reset_grants\": $1"
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "default", "fetched_at": $NOW,
  "accounts": { "default": { "label": "default", "securestorage": null, "fetched_at": $NOW,
    "five_hour_pct": 55, "five_hour_resets_epoch": $((NOW + 14000)),
    "weekly_all_pct": 82, "weekly_resets_epoch": $((NOW + 172800))${rg} } } }
JSON
}

iso_after() {  # $1=秒 → 現在 NOW から $1 秒後の ISO 8601（小数秒付き）
  python3 -c "import datetime,sys;print(datetime.datetime.fromtimestamp($NOW+$1,datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.123Z'))"
}

render() { mk_input 55 82 14000 172800 | bash "$SL"; }

@test "reset grants: count and nearest expiry are shown at the end of the 7d line" {
  g1="$(iso_after $((3*86400 + 21*3600 + 30)))"; g2="$(iso_after $((10*86400)))"
  write_snap "[{\"resets_left\":1,\"ends_at\":\"$g1\",\"paused\":false},{\"resets_left\":1,\"ends_at\":\"$g2\",\"paused\":false}]"
  render | strip_ansi > "$WORK/out.txt"
  line="$(grep '7d All' "$WORK/out.txt")"
  [[ "$line" == *"リセット2回・最短あと3日21h" ]] || { echo "$line"; return 1; }
}

@test "reset grants: yellow within 3 days, red within 24 hours" {
  write_snap "[{\"resets_left\":1,\"ends_at\":\"$(iso_after $((2*86400)))\",\"paused\":false}]"
  render > "$WORK/y.txt"
  grep '7d All' "$WORK/y.txt" | grep -q $'\033\\[33mリセット1回'
  write_snap "[{\"resets_left\":1,\"ends_at\":\"$(iso_after $((12*3600)))\",\"paused\":false}]"
  render > "$WORK/r.txt"
  grep '7d All' "$WORK/r.txt" | grep -q $'\033\\[31mリセット1回'
  write_snap "[{\"resets_left\":1,\"ends_at\":\"$(iso_after $((5*86400)))\",\"paused\":false}]"
  render > "$WORK/d.txt"
  ! grep '7d All' "$WORK/d.txt" | grep -q $'\033\\[3[13]mリセット' || return 1
}

@test "reset grants: hours-and-minutes form under a day" {
  write_snap "[{\"resets_left\":3,\"ends_at\":\"$(iso_after $((5*3600 + 600)))\",\"paused\":false}]"
  render | strip_ansi | grep '7d All' | grep -q 'リセット3回・最短あと5h10m' 
}

@test "reset grants: paused true and zero-left grants are not counted" {
  write_snap "[{\"resets_left\":5,\"ends_at\":\"$(iso_after 3600)\",\"paused\":true},{\"resets_left\":0,\"ends_at\":\"$(iso_after 7200)\",\"paused\":false},{\"resets_left\":1,\"ends_at\":\"$(iso_after $((4*86400)))\",\"paused\":false}]"
  render | strip_ansi | grep '7d All' | grep -q 'リセット1回・最短あと4日'
}

@test "reset grants: paused is excluded only for boolean true" {
  local p
  for p in '' ',"paused":null' ',"paused":"true"' ',"paused":false'; do
    write_snap "[{\"resets_left\":1,\"ends_at\":null${p}}]"
    render | strip_ansi | grep '7d All' | grep -q 'リセット1回・期限不明' || { echo "case: $p"; return 1; }
  done
  write_snap '[{"resets_left":1,"ends_at":null,"paused":true}]'
  ! render | strip_ansi | grep -q 'リセット' || return 1
}

@test "reset grants: a non-empty array with no countable grant shows no segment" {
  write_snap ''
  render > "$WORK/base.txt"
  local rg
  for rg in '[{"resets_left":0,"ends_at":null,"paused":false}]' \
            '[{"resets_left":2,"ends_at":null,"paused":true}]' \
            '[{"resets_left":0,"ends_at":null},{"resets_left":3,"ends_at":null,"paused":true}]'; do
    write_snap "$rg"
    render > "$WORK/o.txt"
    cmp -s "$WORK/base.txt" "$WORK/o.txt" || { echo "case: $rg"; cat "$WORK/o.txt"; return 1; }
  done
}

@test "reset grants: an expiry with a UTC offset reads as the same instant as Z" {
  local t z
  t=$((NOW + 12*3600 + 600))
  write_snap "[{\"resets_left\":1,\"ends_at\":\"$(iso_after $((12*3600 + 600)))\",\"paused\":false}]"
  render > "$WORK/z.txt"
  grep '7d All' "$WORK/z.txt" | grep -q $'\033\\[31mリセット1回・最短あと12h10m' || { cat "$WORK/z.txt"; return 1; }
  for z in '+00:00' '+09:00' '-05:30'; do
    e="$(python3 -c "import datetime as d;h,m=int('$z'[1:3]),int('$z'[4:6]);o=(1 if '$z'[0]=='+' else -1)*d.timedelta(hours=h,minutes=m);print(d.datetime.fromtimestamp($t,d.timezone(o)).strftime('%Y-%m-%dT%H:%M:%S.123')+'$z')")"
    write_snap "[{\"resets_left\":1,\"ends_at\":\"$e\",\"paused\":false}]"
    render > "$WORK/o.txt"
    cmp -s "$WORK/z.txt" "$WORK/o.txt" || { echo "case: $e"; cat "$WORK/o.txt"; return 1; }
  done
}

@test "reset grants: an unreadable expiry string stays unknown" {
  local e
  for e in 'soon' '2026-13-40T00:00:00Z' '2026-11-02T03:00:00' '2026-11-02T03:00:00+9'; do
    write_snap "[{\"resets_left\":1,\"ends_at\":\"$e\",\"paused\":false}]"
    render | strip_ansi | grep '7d All' | grep -q 'リセット1回・期限不明$' || { echo "case: $e"; return 1; }
  done
}

@test "reset grants: no expiry and a past expiry are told apart" {
  write_snap '[{"resets_left":2,"ends_at":null,"paused":false}]'
  render | strip_ansi | grep '7d All' | grep -q 'リセット2回・期限不明'
  write_snap "[{\"resets_left\":2,\"ends_at\":\"$(iso_after -60)\",\"paused\":false}]"
  render | strip_ansi | grep '7d All' | grep -q 'リセット2回・期限経過（更新待ち）'
}

@test "reset grants: an empty array shows 0 and no expiry" {
  write_snap '[]'
  line="$(render | strip_ansi | grep '7d All')"
  [[ "$line" == *"リセット0回" ]] || { echo "$line"; return 1; }
}

@test "reset grants: no field, a non-array, or only unusable grants leave the output unchanged" {
  write_snap ''
  render > "$WORK/base.txt"
  local rg
  for rg in '"x"' '{"a":1}' 'null' '[{"resets_left":"1","ends_at":null}]' '[{"resets_left":-1}]' '[null,3]' '[{"resets_left":1.5}]'; do
    write_snap "$rg"
    render > "$WORK/o.txt"
    cmp -s "$WORK/base.txt" "$WORK/o.txt" || { echo "case: $rg"; return 1; }
  done
  rm -f "$SNAP"
  render > "$WORK/nosnap.txt"
  ! grep -q 'リセット' "$WORK/nosnap.txt" || return 1
}

@test "reset grants: single slot differs from the no-field output only by the segment" {
  write_snap ''
  render | strip_ansi > "$WORK/base.txt"
  write_snap '[{"resets_left":1,"ends_at":null,"paused":false}]'
  render | strip_ansi > "$WORK/with.txt"
  sed 's/  │  リセット1回・期限不明$//' "$WORK/with.txt" > "$WORK/stripped.txt"
  cmp -s "$WORK/base.txt" "$WORK/stripped.txt"
  ! grep -q 'Claude' "$WORK/with.txt" || return 1
}

@test "reset grants: a non-active slot shows its own segment after the age" {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" } ] }
JSON
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "a", "fetched_at": $NOW,
  "accounts": {
    "a": { "label": "A", "securestorage": null, "fetched_at": $NOW, "five_hour_pct": 55,
           "five_hour_resets_epoch": $((NOW + 14000)), "weekly_all_pct": 82, "weekly_resets_epoch": $((NOW + 172800)) },
    "b": { "label": "B", "securestorage": "${SECURE_B}", "fetched_at": $((NOW - 7200)), "five_hour_pct": 3,
           "five_hour_resets_epoch": $((NOW + 9000)), "weekly_all_pct": 1, "weekly_resets_epoch": $((NOW + 172800)),
           "reset_grants": [{"resets_left":2,"ends_at":null,"paused":false}] } } }
JSON
  render | strip_ansi > "$WORK/out.txt"
  grep -E '^(▸ |  )Claude B +7d All' "$WORK/out.txt" | grep -q '2h前  │  リセット2回・期限不明$'
  ! grep -E '^(▸ |  )Claude A ' "$WORK/out.txt" | grep -q 'リセット' || return 1
}

@test "reset grants: a slot with only the 5h line gets the segment on that line" {
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "default", "fetched_at": $NOW,
  "accounts": { "default": { "label": "default", "securestorage": null, "fetched_at": $NOW,
    "five_hour_pct": 55, "five_hour_resets_epoch": $((NOW + 14000)),
    "reset_grants": [{"resets_left":1,"ends_at":null,"paused":false}] } } }
JSON
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"rate_limits":{"five_hour":{"used_percentage":55,"resets_at":%s}}}' "$WORK" "$((NOW + 14000))" | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep '5h' "$WORK/out.txt" | grep -q 'リセット1回・期限不明$'
}

@test "reset grants: the Codex row output is the same as before the shared formatter" {
  export STATUSLINE_CODEX=1 CODEX_HOME="$WORK/codex-home" STATUSLINE_CODEX_BIN="$WORK/codex-stub"
  mkdir -p "$CODEX_HOME"
  printf '#!/bin/sh\nexit 0\n' > "$STATUSLINE_CODEX_BIN"; chmod 700 "$STATUSLINE_CODEX_BIN"
  echo '{"tokens":{"account_id":"test"}}' > "$CODEX_HOME/auth.json"
  write_snap ''
  # 比べる元は origin/main の statusline.sh（固定の SHA は CI の checkout に無いことがあるので書かない）。
  # マージ後に origin/main がこの版になっても、Codex の行の出力は同じはずなので比較の意味は変わらない
  mkdir -p "$WORK/old"
  git -C "$REPO_ROOT" show origin/main:plugins/statusline/scripts/statusline.sh > "$WORK/old/statusline.sh" 2>/dev/null \
    || skip "origin/main is not available"
  cp "${PLUGIN_DIR}/scripts/statusline-codex.py" "$WORK/old/"
  local key delta cnt exp
  key="$(python3 -c "
import importlib.util,sys
sp=importlib.util.spec_from_file_location('c','${PLUGIN_DIR}/scripts/statusline-codex.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);print(m.identity())")"
  for delta in 120 43200 172800 345600 -60 0; do
    cnt=3; exp=$((NOW + delta)); [ "$delta" = 0 ] && { exp=0; cnt=2; }
    cat > "$WORK/.statusline-codex" <<JSON
{"identity":"$key","windows":[{"pct":10,"minutes":10080,"reset":$((NOW + 172800))}],"fetched_at":$NOW,
 "next_attempt":$((NOW + 100)),
 "resets":{"availableCount":$cnt,"credits":[{"status":"available","expiresAt":$exp}]}}
JSON
    [ "$delta" = 0 ] && sed -i.bak 's/"expiresAt":0/"expiresAt":-1/' "$WORK/.statusline-codex"
    # 比べるのは Codex の行だけ（1 スロットで Codex の行が出ると、Claude の行には名前の列が付くようになった）
    mk_input 55 82 14000 172800 | bash "$SL" | grep 'Codex' > "$WORK/new.txt"
    mk_input 55 82 14000 172800 | bash "$WORK/old/statusline.sh" | grep 'Codex' > "$WORK/oldout.txt"
    grep -q 'リセット' "$WORK/new.txt" || { echo "no codex reset row: $delta"; cat "$WORK/new.txt"; cat "$WORK/.statusline-codex"; return 1; }
    cmp -s "$WORK/new.txt" "$WORK/oldout.txt" || { echo "differs: $delta"; return 1; }
  done
}
