#!/usr/bin/env bats
#
# statusline-multi-account:
#   statusline.sh のアカウント別レートリミット描画（label 列 / active 判定 /
#   6h 鮮度ゲートの active 限定 / 非 active の経過時間と分母）
#
# spec: statusline-multi-account-usage
#       usage-account-registry（active スロットの判定規則）
#
# 既存の statusline.bats は 1 スロット時の退行ガードとして無改変で残す。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SL="${PLUGIN_DIR}/scripts/statusline.sh"
  WORK="$(mktemp -d)"
  export CLAUDE_CONFIG_DIR="$WORK"
  export STATUSLINE_API_PACE=0
  ACCOUNTS="${WORK}/accounts.json"
  SNAP="${WORK}/.usage-snapshot"
  SECURE_B="${WORK}/claude-b"
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

strip_ansi() {
  sed $'s/\033\\[[0-9;]*m//g'
}

write_two_slot_registry() {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
}

# $1=a の fetched_at $2=b の fetched_at $3=b の 7d リセット epoch
write_two_slot_snapshot() {
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "a", "fetched_at": $1,
  "fable_weekly_pct": 94, "fable_active": true,
  "weekly_all_pct": 82, "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
  "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
  "accounts": {
    "a": { "label": "A", "securestorage": null, "fetched_at": $1,
           "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
           "weekly_all_pct": 82, "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
           "fable_weekly_pct": 94, "fable_active": true },
    "b": { "label": "B", "securestorage": "${SECURE_B}", "fetched_at": $2,
           "five_hour_pct": 3, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 1, "weekly_resets_at": "iso", "weekly_resets_epoch": $3,
           "fable_weekly_pct": 0, "fable_active": false }
  } }
JSON
}

# ---------- 複数スロットの描画 ----------

@test "multi: two slots render four rate limit lines with labels" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  [ "$(grep -c '5h' "$WORK/out.txt")" = "2" ]
  [ "$(grep -c '7d All' "$WORK/out.txt")" = "2" ]
  grep -qE '^A +5h' "$WORK/out.txt"
  grep -qE '^A +7d All' "$WORK/out.txt"
  grep -qE '^B +5h' "$WORK/out.txt"
  grep -qE '^B +7d All' "$WORK/out.txt"
}

@test "multi: a null-filled slot renders no line" {
  write_two_slot_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "a", "fetched_at": $NOW,
  "fable_weekly_pct": 94, "fable_active": true, "weekly_all_pct": 82,
  "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
  "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
  "accounts": {
    "a": { "label": "A", "securestorage": null, "fetched_at": $NOW,
           "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
           "weekly_all_pct": 82, "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
           "fable_weekly_pct": 94, "fable_active": true },
    "b": { "label": "B", "securestorage": "${SECURE_B}", "fetched_at": null,
           "five_hour_pct": null, "five_hour_resets_at": null, "five_hour_resets_epoch": null,
           "weekly_all_pct": null, "weekly_resets_at": null, "weekly_resets_epoch": null,
           "fable_weekly_pct": null, "fable_active": null }
  } }
JSON
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  [ "$(grep -c '5h' "$WORK/out.txt")" = "1" ]
  ! grep -qE '^B ' "$WORK/out.txt"
}

@test "multi: a slot with 5h but no 7d renders only the 5h line" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  python3 - "$SNAP" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["accounts"]["b"]["weekly_all_pct"] = None
json.dump(d, open(p, "w"))
PY
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -qE '^B +5h' "$WORK/out.txt"
  ! grep -qE '^B +7d All' "$WORK/out.txt"
}

@test "multi: the active slot uses live stdin values" {
  write_two_slot_registry
  # snapshot の a は 55%、stdin のライブ値は 40%
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 40 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  line="$(grep -E '^A +5h' "$WORK/out.txt")"
  [[ "$line" =~ 40% ]]
}

@test "multi: a non-active slot shows the age of its snapshot values" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  line="$(grep -E '^B +7d All' "$WORK/out.txt")"
  [[ "$line" =~ 2h前 ]]
  # active 側には経過時間を出さない
  ! grep -E '^A ' "$WORK/out.txt" | grep -q '前'
}

# ---------- 6h 鮮度ゲート ----------

@test "gate: a stale active slot still hides the Fable segment" {
  write_two_slot_registry
  write_two_slot_snapshot "$((NOW - 25000))" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  ! grep -E '^A ' "$WORK/out.txt" | grep -q 'Fable'
}

@test "gate: a stale non-active slot keeps its Fable segment" {
  write_two_slot_registry
  # b は 2 日前（6h ゲートより遥かに古い）
  write_two_slot_snapshot "$NOW" "$((NOW - 172800))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -E '^B ' "$WORK/out.txt" | grep -q 'Fable'
  grep -E '^B +7d All' "$WORK/out.txt" | grep -q '2d前'
}

# ---------- リセット時刻が過去のとき ----------

@test "stale window: a past resets_at drops the denominator and the remaining time" {
  write_two_slot_registry
  # b の 7d リセットは 1 日前
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW - 86400))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  line="$(grep -E '^B +7d All' "$WORK/out.txt")"
  [[ "$line" =~ 1% ]]
  # 分母（%/%）も残り時間（~Nd Nh）も出ない
  ! [[ "$line" =~ %/ ]]
  ! [[ "$line" =~ ~ ]]
}

# ---------- active スロットの判定 ----------

@test "active: CLAUDE_SECURESTORAGE_CONFIG_DIR wins over the snapshot" {
  write_two_slot_registry
  # snapshot の active は a、env は b を指す
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 40 82 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$SECURE_B" bash "$SL" \
    | strip_ansi > "$WORK/out.txt"
  # b がライブ値 40% を使い、a が snapshot 値 + 経過時間になる
  [[ "$(grep -E '^B +5h' "$WORK/out.txt")" =~ 40% ]]
  [[ "$(grep -E '^A +5h' "$WORK/out.txt")" =~ 55% ]]
}

@test "active: falls back to the snapshot active when the env is unset" {
  write_two_slot_registry
  write_two_slot_snapshot "$((NOW - 7200))" "$NOW" "$((NOW + 172800))"
  python3 - "$SNAP" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["active"] = "b"
json.dump(d, open(p, "w"))
PY
  mk_input 40 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  [[ "$(grep -E '^B +5h' "$WORK/out.txt")" =~ 40% ]]
  [[ "$(grep -E '^A +5h' "$WORK/out.txt")" =~ 55% ]]
}

@test "active: an env matching no slot leaves every slot on snapshot values" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 40 82 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="${WORK}/unknown" bash "$SL" \
    | strip_ansi > "$WORK/out.txt"
  # ライブ値 40% はどの行にも現れない（誤った帰属をしない）
  ! grep -q '40%' "$WORK/out.txt"
  [[ "$(grep -E '^A +5h' "$WORK/out.txt")" =~ 55% ]]
  [[ "$(grep -E '^B +5h' "$WORK/out.txt")" =~ 3% ]]
}

# ---------- 1 スロット時の退行ガード ----------

# 残り時間の表示は分単位なので、2 回の実行が分の境界を跨ぐと差が出る。
# 残り秒を 60 で割った余りが 30 になるオフセットを使い、約 30 秒の余裕を作って決定論にする。
@test "single: no registry keeps the output byte-identical to the previous version" {
  old="${WORK}/statusline-old.sh"
  git -C "$REPO_ROOT" show origin/main:plugins/statusline/scripts/statusline.sh > "$old" 2>/dev/null \
    || skip "origin/main is not available"
  cat > "$SNAP" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14010 172830 | bash "$SL"  > "$WORK/new.txt"
  mk_input 3 25 14010 172830 | bash "$old" > "$WORK/old.txt"
  diff "$WORK/old.txt" "$WORK/new.txt"
}

@test "single: a schema 2 snapshot without a registry renders like the old one" {
  old="${WORK}/statusline-old.sh"
  git -C "$REPO_ROOT" show origin/main:plugins/statusline/scripts/statusline.sh > "$old" 2>/dev/null \
    || skip "origin/main is not available"
  cat > "$WORK/old-snap.json" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "default", "fetched_at": $NOW,
  "fable_weekly_pct": 7, "fable_active": true,
  "accounts": { "default": { "label": "default", "securestorage": null, "fetched_at": $NOW,
    "five_hour_pct": 3, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
    "weekly_all_pct": 25, "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
    "fable_weekly_pct": 7, "fable_active": true } } }
JSON
  mk_input 3 25 14010 172830 | bash "$SL" > "$WORK/new.txt"
  cp "$WORK/old-snap.json" "$SNAP"
  mk_input 3 25 14010 172830 | bash "$old" > "$WORK/old.txt"
  diff "$WORK/old.txt" "$WORK/new.txt"
}

@test "single: a one-slot registry renders no label column" {
  printf '{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null}]}' > "$ACCOUNTS"
  cat > "$SNAP" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -qE '^5h' "$WORK/out.txt"
  ! grep -qE '^A ' "$WORK/out.txt"
}

@test "single: a schema 1 snapshot still renders the Fable segment" {
  cat > "$SNAP" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -q 'Fable' "$WORK/out.txt"
}

@test "single: no rate_limits and no snapshot renders no rate limit line" {
  write_two_slot_registry
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91}}' "$WORK" \
    | bash "$SL" | strip_ansi > "$WORK/out.txt"
  ! grep -q '5h' "$WORK/out.txt"
  ! grep -q '7d All' "$WORK/out.txt"
}
