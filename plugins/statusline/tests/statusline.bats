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

@test "render: fail-open draws lines 1-2 without rate limit fields" {  # レートリミット情報が無くても 1〜2 行目は描画する（fail-open）
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91}}' "$WORK" \
    | bash "$SL" > "$WORK/out.txt"
  grep -q 'Opus 5' "$WORK/out.txt"
  grep -q 'Context 91%' "$WORK/out.txt"
  ! grep -q '7d All' "$WORK/out.txt"
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
