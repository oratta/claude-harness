#!/usr/bin/env bats
#
# statusline:
#   statusline.sh の描画契約（日程分母・バー塗り・色しきい値・snapshot 書き出し）と
#   install.sh の導入契約（コピー / settings.json 配線 / バックアップ / dry-run）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SL="${PLUGIN_DIR}/scripts/statusline.sh"
  INSTALL="${PLUGIN_DIR}/scripts/install.sh"
  WORK="$(mktemp -d)"
  export CLAUDE_CONFIG_DIR="$WORK"
  # ccusage の背景フェッチと為替取得を走らせない
  export STATUSLINE_API_PACE=0
  # 実行環境が既定以外の Claude アカウントのセッション（例: 別アカウント住人）だと
  # このシェルに CLAUDE_SECURESTORAGE_CONFIG_DIR が漏れ込んでいることがあり、
  # 「既定アカウント」を想定したテストが誤って落ちる。ここで明示的に外す。
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR
  NOW="$(date +%s)"
}

teardown() {
  rm -rf "$WORK"
}

# $1=5h消化率 $2=7d消化率 $3=5h残り秒 $4=7d残り秒 → stdin JSON
mk_input() {
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}}' \
    "$WORK" "$1" "$((NOW + $3))" "$2" "$((NOW + $4))"
}

# ANSI エスケープを剥がす
strip_ansi() {
  sed $'s/\033\\[[0-9;]*m//g'
}

@test "render: 7d line shows used%/elapsed% denominator" {  # 7d 行に 消化率/日程消化率 の分母が出る
  # 7d の残り 2 日 = 経過 5/7 ≈ 71%
  mk_input 3 25 14000 172800 | bash "$SL" > "$WORK/out.txt"
  line="$(strip_ansi < "$WORK/out.txt" | grep '7d All')"
  [[ "$line" =~ 25%/71% ]]
}

@test "render: Fable line shows the same elapsed% denominator" {  # Fable 行にも同じ日程分母が出る
  cat > "$WORK/.usage-snapshot" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14000 172800 | bash "$SL" > "$WORK/out.txt"
  line="$(strip_ansi < "$WORK/out.txt" | grep 'Fable')"
  [[ "$line" =~ 7%/71% ]]
}

@test "render: stale usage-snapshot (>6h) hides the Fable segment" {  # usage-snapshot が 6h より古いと Fable 行を出さない
  cat > "$WORK/.usage-snapshot" <<JSON
{"schema":1,"fetched_at":$((NOW - 25000)),"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14000 172800 | bash "$SL" > "$WORK/out.txt"
  ! grep -q 'Fable' "$WORK/out.txt"
}

@test "render: 5h line has no denominator" {  # 5h 行には分母を出さない
  mk_input 3 25 14000 172800 | bash "$SL" > "$WORK/out.txt"
  line="$(strip_ansi < "$WORK/out.txt" | grep '5h')"
  [[ "$line" =~ 3% ]]
  [[ "$line" != */* ]]
}

@test "render: pace ahead of schedule turns the 7d bar red" {  # 日程より使いすぎていると警告色になる
  # 日程 71% に対して消化 90% → 比 126% → 203（赤）
  mk_input 3 90 14000 172800 | bash "$SL" > "$WORK/out.txt"
  line="$(grep '7d All' "$WORK/out.txt")"
  [[ "$line" =~ 38\;5\;203m[[:space:]]*90% ]]
}

@test "render: pace behind schedule keeps the 7d bar green" {  # 日程より余裕があると通常色になる
  # 日程 71% に対して消化 25% → 比 35% → 78（緑）
  mk_input 3 25 14000 172800 | bash "$SL" > "$WORK/out.txt"
  line="$(grep '7d All' "$WORK/out.txt")"
  [[ "$line" =~ 38\;5\;78m[[:space:]]*25% ]]
}

@test "snapshot: writes rate limits to .rate-limit-snapshot" {  # レートリミットを rate-limit-snapshot に書き出す
  mk_input 3 25 14000 172800 | bash "$SL" > /dev/null
  [ -f "$WORK/.rate-limit-snapshot" ]
  run jq -r '.five_hour_pct' "$WORK/.rate-limit-snapshot"
  [ "$output" = "3" ]
}

@test "snapshot: skips write when CLAUDE_SECURESTORAGE_CONFIG_DIR is set (other account)" {  # 別アカウントのセッションでは書かない
  mk_input 3 25 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$WORK/other-account" bash "$SL" > /dev/null
  [ ! -f "$WORK/.rate-limit-snapshot" ]
}

@test "snapshot: does not clobber an existing snapshot from another account session" {  # 既定アカウントが既に書いた内容を別アカウントのセッションで上書きしない
  mk_input 3 25 14000 172800 | bash "$SL" > /dev/null
  before="$(cat "$WORK/.rate-limit-snapshot")"
  mk_input 99 99 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$WORK/other-account" bash "$SL" > /dev/null
  [ "$(cat "$WORK/.rate-limit-snapshot")" = "$before" ]
}

@test "render: fail-open draws lines 1-2 without rate limit fields" {  # レートリミット情報が無くても 1〜2 行目は描画する（fail-open）
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91}}' "$WORK" \
    | bash "$SL" > "$WORK/out.txt"
  grep -q 'Opus 5' "$WORK/out.txt"
  grep -q 'Context 91%' "$WORK/out.txt"
  ! grep -q '7d All' "$WORK/out.txt"
}

# $1=cost.total_cost_usd → cost を含む stdin JSON（レートリミットなし）
mk_cost_input() {
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"cost":{"total_cost_usd":%s}}' \
    "$WORK" "$1"
}

@test "session cost: converts cost.total_cost_usd with the cached fx rate" {  # セッションコストを為替キャッシュで円換算して 2 行目に出す
  echo 150 > "$WORK/.statusline-fxrate-JPY"
  mk_cost_input 12.34 | bash "$SL" > "$WORK/out.txt"
  line="$(strip_ansi < "$WORK/out.txt" | grep 'Context')"
  [[ "$line" == *"Context 91%  │  Session ¥1,851"* ]]
}

@test "session cost: sits next to the 30-day API pace" {  # 30 日コストの隣に並ぶ
  echo 150 > "$WORK/.statusline-fxrate-JPY"
  echo 'API ¥180,000/mo' > "$WORK/.statusline-api-pace"
  # キャッシュを新しく見せて背景更新を走らせない
  touch "$WORK/.statusline-api-pace"
  mk_cost_input 1 | STATUSLINE_API_PACE=1 bash "$SL" > "$WORK/out.txt"
  line="$(strip_ansi < "$WORK/out.txt" | grep 'Context')"
  [[ "$line" == *"API ¥180,000/mo  │  Session ¥150"* ]]
}

@test "session cost: falls back to USD when no fx rate is cached" {  # 為替キャッシュが無ければ USD で出す（描画中に取りに行かない）
  mk_cost_input 0.5 | bash "$SL" > "$WORK/out.txt"
  strip_ansi < "$WORK/out.txt" | grep -q 'Session \$0.50'
}

@test "session cost: falls back to USD when the fx cache is not a positive number" {  # 為替キャッシュが壊れていたら ¥0 ではなく USD で出す
  for bad in garbage '   ' 0; do
    echo "$bad" > "$WORK/.statusline-fxrate-JPY"
    mk_cost_input 1.23 | bash "$SL" > "$WORK/out.txt"
    strip_ansi < "$WORK/out.txt" | grep -q 'Session \$1.23'
  done
}

@test "session cost: amounts do not depend on the locale's decimal separator" {  # 小数点がカンマのロケールでも金額が狂わない
  locale -a 2>/dev/null | grep -qi '^de_DE\.utf-\?8$' || skip "de_DE.UTF-8 ロケールが無い"
  mk_cost_input 1.23 | LC_ALL=de_DE.UTF-8 bash "$SL" > "$WORK/out.txt"
  strip_ansi < "$WORK/out.txt" | grep -q 'Session \$1.23'
  echo 150 > "$WORK/.statusline-fxrate-JPY"
  mk_cost_input 12.34 | LC_ALL=de_DE.UTF-8 bash "$SL" > "$WORK/out.txt"
  # 3 桁区切りの記号はロケールに従う（de_DE なら "."）。見るのは金額が 1851 のままであること
  strip_ansi < "$WORK/out.txt" | grep -q 'Session ¥1[.,]851'
}

@test "session cost: STATUSLINE_CURRENCY=USD shows dollars" {  # 通貨が USD ならドルで出す
  echo 150 > "$WORK/.statusline-fxrate-JPY"
  mk_cost_input 3.456 | STATUSLINE_CURRENCY=USD bash "$SL" > "$WORK/out.txt"
  strip_ansi < "$WORK/out.txt" | grep -q 'Session \$3.46'
}

@test "session cost: hidden when the cost field is absent or disabled" {  # cost が無い／STATUSLINE_SESSION_COST=0 なら出さない
  mk_input 3 25 14000 172800 | bash "$SL" > "$WORK/out.txt"
  ! grep -q 'Session' "$WORK/out.txt"
  mk_cost_input 1 | STATUSLINE_SESSION_COST=0 bash "$SL" > "$WORK/out.txt"
  ! grep -q 'Session' "$WORK/out.txt"
}

@test "config: STATUSLINE_BAR_WIDTH changes the bar cell count" {  # STATUSLINE_BAR_WIDTH でバーのセル数が変わる
  out="$(mk_input 3 25 14000 172800 | STATUSLINE_BAR_WIDTH=4 bash "$SL" | grep '7d All')"
  # 4 セル分の glyph しか出ない
  count="$(printf '%s' "$out" | grep -o '▂' | wc -l | tr -d ' ')"
  [ "$count" -eq 4 ]
}

# ---- install.sh ----

@test "install: --dry-run writes nothing" {  # dry-run は何も書き込まない
  echo '{}' > "$WORK/settings.json"
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dry-run" ]]
  [ ! -f "$WORK/statusline.sh" ]
  run jq -r '.statusLine // "none"' "$WORK/settings.json"
  [ "$output" = "none" ]
}

@test "install: copies the script and wires settings.json" {  # 導入するとスクリプトをコピーし settings.json を配線する
  echo '{"model":"opus"}' > "$WORK/settings.json"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -x "$WORK/statusline.sh" ]
  run jq -r '.statusLine.command' "$WORK/settings.json"
  [ "$output" = "bash $WORK/statusline.sh" ]
  # 既存キーを壊さない
  run jq -r '.model' "$WORK/settings.json"
  [ "$output" = "opus" ]
}

@test "install: backs up settings.json before replacing an existing statusLine" {  # 既存の statusLine を置き換える前にバックアップを取る
  jq -n '{statusLine: {type: "command", command: "bash /other/line.sh"}}' > "$WORK/settings.json"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ replace ]]
  ls "$WORK"/settings.json.bak-* > /dev/null
  run jq -r '.statusLine.command' "$WORK/settings.json"
  [ "$output" = "bash $WORK/statusline.sh" ]
}

@test "install: creates settings.json when absent" {  # settings.json が無くても新規作成して配線する
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  run jq -r '.statusLine.type' "$WORK/settings.json"
  [ "$output" = "command" ]
}

@test "install: aborts without writing when settings.json is invalid JSON" {  # settings.json が壊れていたら書き込まずに落ちる
  echo 'not json {' > "$WORK/settings.json"
  run bash "$INSTALL"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "壊れている" ]]
  [ ! -f "$WORK/statusline.sh" ]
}

@test "install: second run reports up-to-date" {  # 二度目の実行は up-to-date になる
  echo '{}' > "$WORK/settings.json"
  bash "$INSTALL" > /dev/null
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "script     : $WORK/statusline.sh (up-to-date)" ]]
  [[ "$output" =~ "statusLine : up-to-date" ]]
}
