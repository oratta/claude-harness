#!/usr/bin/env bats
#
# dev-workflow-fable-usage-probe:
#   usage-probe.sh（snapshot 契約 / 5 分キャッシュ / fail-open）と
#   session-tripwires.sh の残量モード自動導出注入
#
# spec: dev-workflow-escalation-tripwires（usage-probe と snapshot 契約 / 自動導出注入）
#       dev-workflow-execution-strategy（残量モードの自動導出）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PROBE="${PLUGIN_DIR}/scripts/usage-probe.sh"
  SESSION="${PLUGIN_DIR}/scripts/session-tripwires.sh"
  WORK="$(mktemp -d)"
  SNAP="${WORK}/.usage-snapshot"
  RESP="${WORK}/resp.json"
  # 固定 now と週次リセット（now の 2 日後 = 週経過 ≈ 71.4%）
  NOW=1000000000
  RESETS_EPOCH=$((NOW + 2 * 86400))
}

teardown() {
  rm -rf "$WORK"
}

# 実 API 形状（weekly かつ Fable scope のエントリを含む）の応答を書く
write_good_resp() {
  cat > "$RESP" <<JSON
{
  "seven_day": { "utilization": 55.0, "resets_at": "2026-07-24T21:59:59.700395+00:00" },
  "limits": [
    { "kind": "weekly_all", "group": "weekly", "percent": 55, "is_active": false, "scope": null },
    { "kind": "weekly_scoped", "group": "weekly", "percent": 73, "is_active": true,
      "scope": { "model": { "display_name": "Fable" } },
      "resets_at": "2026-07-24T21:59:59.700681+00:00" }
  ]
}
JSON
}

# Fable scope を含まない応答（有効フェッチだが Fable データ無し）
write_nofable_resp() {
  cat > "$RESP" <<JSON
{
  "seven_day": { "utilization": 20.0, "resets_at": "2026-07-24T21:59:59+00:00" },
  "limits": [
    { "kind": "weekly_all", "group": "weekly", "percent": 20, "is_active": true, "scope": null }
  ]
}
JSON
}

# 指定 pct / resets_epoch の snapshot を直接書く（導出テスト用）
write_snapshot() {
  local pct="$1" resets="$2"
  cat > "$SNAP" <<JSON
{ "schema": 1, "fetched_at": ${NOW}, "fable_weekly_pct": ${pct}, "fable_active": true,
  "weekly_all_pct": 55, "weekly_resets_at": "iso", "weekly_resets_epoch": ${resets} }
JSON
}

# ---------- usage-probe.sh: snapshot 契約 ----------

@test "probe: is executable" {
  [ -x "$PROBE" ]
}

@test "probe: writes snapshot with fable_weekly_pct and fable_active" {
  write_good_resp
  run env USAGE_SNAPSHOT="$SNAP" USAGE_PROBE_RESPONSE_FILE="$RESP" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ -f "$SNAP" ]
  python3 -c "import json;json.load(open('$SNAP'))"
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "73" ]
  [ "$(jq -r '.fable_active' "$SNAP")" = "true" ]
}

@test "probe: valid fetch without Fable scope writes null pct" {
  write_nofable_resp
  run env USAGE_SNAPSHOT="$SNAP" USAGE_PROBE_RESPONSE_FILE="$RESP" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ -f "$SNAP" ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "null" ]
  [ "$(jq -r '.fable_active' "$SNAP")" = "false" ]
}

@test "probe: 5-min cache keeps fresh snapshot (no refetch)" {
  write_snapshot 11 "$RESETS_EPOCH"   # 既存 snapshot: pct=11
  write_good_resp                     # 新応答: pct=73
  run env USAGE_SNAPSHOT="$SNAP" USAGE_PROBE_RESPONSE_FILE="$RESP" USAGE_PROBE_TTL=300 USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  # キャッシュヒットのため上書きされず 11 のまま
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "11" ]
}

@test "probe: expired cache refetches and overwrites" {
  write_snapshot 11 "$RESETS_EPOCH"
  write_good_resp
  run env USAGE_SNAPSHOT="$SNAP" USAGE_PROBE_RESPONSE_FILE="$RESP" USAGE_PROBE_TTL=0 USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "73" ]
}

@test "probe: fail-open when fetch fails and no prior snapshot" {
  run env USAGE_SNAPSHOT="$SNAP" USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -f "$SNAP" ]
}

@test "probe: fail-open preserves existing snapshot on fetch failure" {
  write_snapshot 42 "$RESETS_EPOCH"
  run env USAGE_SNAPSHOT="$SNAP" USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" USAGE_PROBE_TTL=0 USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "42" ]
}

@test "probe: fail-open on invalid JSON response preserves snapshot" {
  write_snapshot 42 "$RESETS_EPOCH"
  printf 'not json <<<' > "$RESP"
  run env USAGE_SNAPSHOT="$SNAP" USAGE_PROBE_RESPONSE_FILE="$RESP" USAGE_PROBE_TTL=0 USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "42" ]
}

# ---------- session-tripwires.sh: 残量モード自動導出 ----------

# additionalContext を取り出すヘルパ（run の $output から）
ctx() { python3 -c "import json,sys;print(json.loads(sys.argv[1])['additionalContext'])" "$1"; }

@test "session: derives abundant when usage under weekly pace" {
  write_snapshot 30 "$RESETS_EPOCH"   # pct=30 <= 週経過≈71 → abundant
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="$SNAP" \
      USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" \
      USAGE_PROBE_NOW="$NOW" "$SESSION"
  [ "$status" -eq 0 ]
  c="$(ctx "$output")"
  echo "$c" | grep -q "abundant"
  echo "$c" | grep -q "昇格トリップワイヤー"
  # Fable 残量% = 100 - 30 = 70
  echo "$c" | grep -q "70"
}

@test "session: derives conserve when usage outpaces the week" {
  write_snapshot 85 "$RESETS_EPOCH"   # 85 > 週経過≈71 かつ <=90 → conserve
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="$SNAP" \
      USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" \
      USAGE_PROBE_NOW="$NOW" "$SESSION"
  [ "$status" -eq 0 ]
  echo "$(ctx "$output")" | grep -q "conserve"
}

@test "session: derives exhausted above 90 percent" {
  write_snapshot 95 "$RESETS_EPOCH"
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="$SNAP" \
      USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" \
      USAGE_PROBE_NOW="$NOW" "$SESSION"
  [ "$status" -eq 0 ]
  echo "$(ctx "$output")" | grep -q "exhausted"
}

@test "session: explicit FABLE_BUDGET_MODE overrides derivation" {
  write_snapshot 30 "$RESETS_EPOCH"   # 導出なら abundant
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="$SNAP" \
      USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" \
      USAGE_PROBE_NOW="$NOW" FABLE_BUDGET_MODE=reserve "$SESSION"
  [ "$status" -eq 0 ]
  c="$(ctx "$output")"
  echo "$c" | grep -q "reserve"
  # 明示なので abundant は現在モードとして提示されない
  ! echo "$c" | grep -qE "現在.*abundant|abundant（導出）"
}

@test "session: no snapshot defaults to conserve but still injects tripwires" {
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="${WORK}/absent" \
      USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" \
      USAGE_PROBE_NOW="$NOW" "$SESSION"
  [ "$status" -eq 0 ]
  c="$(ctx "$output")"
  echo "$c" | grep -q "conserve"
  echo "$c" | grep -q "昇格トリップワイヤー"
  echo "$c" | grep -q "規模超過"
}

@test "session: output is valid JSON in all derivation paths" {
  write_snapshot 30 "$RESETS_EPOCH"
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="$SNAP" \
      USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" \
      USAGE_PROBE_NOW="$NOW" "$SESSION"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys;json.loads(sys.argv[1])" "$output"
}
