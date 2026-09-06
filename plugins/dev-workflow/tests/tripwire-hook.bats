#!/usr/bin/env bats
#
# dev-workflow-tripwire-session-hook: SessionStart hook によるトリップワイヤー常駐注入
#
# spec: dev-workflow-escalation-tripwires（SessionStart hook 要件）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/session-tripwires.sh"
  TEMPLATE="${PLUGIN_DIR}/templates/escalation-tripwires.md"
  TMPDIR_EMPTY="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_EMPTY"
}

@test "hooks.json: exists and parses" {
  [ -f "$HOOKS_JSON" ]
  python3 -c "import json;json.load(open('$HOOKS_JSON'))"
}

@test "hooks.json: has SessionStart entry with matcher and CLAUDE_PLUGIN_ROOT command" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
entries = d["hooks"]["SessionStart"]
e = entries[0]
assert e["matcher"] == "startup|clear|compact", e.get("matcher")
cmd = e["hooks"][0]["command"]
assert e["hooks"][0]["type"] == "command"
assert "${CLAUDE_PLUGIN_ROOT}" in cmd, cmd
assert "session-tripwires.sh" in cmd, cmd
PY
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "script: outputs valid JSON additionalContext containing the tripwire section" {
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" "$SCRIPT"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
ctx = d["additionalContext"]
for kw in ("昇格トリップワイヤー", "規模超過", "失敗ループ", "仕様の発明"):
    assert kw in ctx, kw
PY
}

@test "script: fail-soft when template is missing (exit 0, no output)" {
  run env CLAUDE_PLUGIN_ROOT="$TMPDIR_EMPTY" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "template: intro documents hook-based default and optional manual copy" {
  grep -q 'SessionStart' "$TEMPLATE"
  grep -Eq 'オプション|プラグイン未導入' "$TEMPLATE"
}

# ---- schema 2 snapshot に対する FABLE_BUDGET_MODE 導出の退行ガード ----
# トップレベルの従来キーを active スロットのミラーとして残す唯一の存在理由がこれ。
# spec: dev-workflow-escalation-tripwires（usage-probe と snapshot 契約 / 自動導出注入）

@test "derivation: a schema 2 snapshot derives the same mode as schema 1" {
  work="$(mktemp -d)"
  now=1000000000
  resets=$(( now + 2 * 86400 ))   # 週経過 ≈ 71%
  s1="${work}/snap1.json"
  s2="${work}/snap2.json"
  cat > "$s1" <<JSON
{ "schema": 1, "fetched_at": ${now}, "fable_weekly_pct": 30, "fable_active": true,
  "weekly_all_pct": 55, "weekly_resets_at": "iso", "weekly_resets_epoch": ${resets} }
JSON
  # 同じ active スロットの値を持つ schema 2（非 active スロットは別の値を持つ）
  cat > "$s2" <<JSON
{ "schema": 2, "active": "a", "fetched_at": ${now},
  "fable_weekly_pct": 30, "fable_active": true,
  "weekly_all_pct": 55, "weekly_resets_at": "iso", "weekly_resets_epoch": ${resets},
  "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": ${now},
  "accounts": {
    "a": { "label": "A", "securestorage": null, "fetched_at": ${now},
           "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": ${now},
           "weekly_all_pct": 55, "weekly_resets_at": "iso", "weekly_resets_epoch": ${resets},
           "fable_weekly_pct": 30, "fable_active": true },
    "b": { "label": "B", "securestorage": "/tmp/cb", "fetched_at": ${now},
           "five_hour_pct": 3, "five_hour_resets_at": "iso", "five_hour_resets_epoch": ${now},
           "weekly_all_pct": 1, "weekly_resets_at": "iso", "weekly_resets_epoch": ${resets},
           "fable_weekly_pct": 95, "fable_active": false }
  } }
JSON
  ctx_of() {
    run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="$1" \
        USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${work}/nonexistent.json" \
        USAGE_PROBE_NOW="$now" "$SCRIPT"
    [ "$status" -eq 0 ]
    python3 -c "import json,sys;print(json.loads(sys.argv[1])['additionalContext'])" "$output"
  }
  out1="$(ctx_of "$s1")"
  out2="$(ctx_of "$s2")"
  # 30% <= 週経過 71% → abundant。非 active スロットの 95% に引きずられない
  echo "$out1" | grep -q "abundant"
  echo "$out2" | grep -q "abundant"
  ! echo "$out2" | grep -q "exhausted"
  # Fable 残量% も同じ（100 - 30 = 70）
  echo "$out2" | grep -q "70"
  rm -rf "$work"
}

@test "derivation: shared budget mode comes from weekly_all_pct and is independent of the Fable mode" {
  work="$(mktemp -d)"
  now=1000000000
  resets=$(( now + 2 * 86400 ))   # 週経過 ≈ 71%
  mk() {  # $1=file $2=fable_pct $3=all_pct
    cat > "$1" <<JSON
{ "schema": 1, "fetched_at": ${now}, "fable_weekly_pct": $2, "fable_active": true,
  "weekly_all_pct": $3, "weekly_resets_at": "iso", "weekly_resets_epoch": ${resets} }
JSON
  }
  ctx_of() {
    run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="$1" \
        USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${work}/nonexistent.json" \
        USAGE_PROBE_NOW="$now" "$SCRIPT"
    [ "$status" -eq 0 ]
    python3 -c "import json,sys;print(json.loads(sys.argv[1])['additionalContext'])" "$output"
  }
  # Fable は余っている（abundant）のに全モデル枠は週経過より速い → throttled が下限を決める
  mk "${work}/a.json" 30 80
  out="$(ctx_of "${work}/a.json")"
  echo "$out" | grep -q "FABLE_BUDGET_MODE: abundant"
  echo "$out" | grep -q "SHARED_BUDGET_MODE: throttled"
  echo "$out" | grep -q "全モデル週次: 使用 80%"
  # 全モデル枠 90% 超 → depleted
  mk "${work}/b.json" 30 95
  echo "$(ctx_of "${work}/b.json")" | grep -q "SHARED_BUDGET_MODE: depleted"
  # 週経過以下 → ok
  mk "${work}/c.json" 30 40
  echo "$(ctx_of "${work}/c.json")" | grep -q "SHARED_BUDGET_MODE: ok"
  # 明示 env が勝つ
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="${work}/c.json" SHARED_BUDGET_MODE=depleted \
      USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${work}/nonexistent.json" USAGE_PROBE_NOW="$now" "$SCRIPT"
  echo "$output" | grep -q "depleted（明示 env）"
  # コンテキスト上限の案内が載る
  echo "$out" | grep -q "subagent-context.sh"
  rm -rf "$work"
}

@test "derivation: no snapshot → SHARED_BUDGET_MODE ok (fail-open) while the Fable mode stays conserve" {
  work="$(mktemp -d)"
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="${work}/missing.json" \
      USAGE_PROBE_TTL=100000 USAGE_PROBE_RESPONSE_FILE="${work}/nonexistent.json" "$SCRIPT"
  [ "$status" -eq 0 ]
  out="$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['additionalContext'])" "$output")"
  echo "$out" | grep -q "FABLE_BUDGET_MODE: conserve"
  echo "$out" | grep -q "SHARED_BUDGET_MODE: ok（既定（usage データなし））"
  rm -rf "$work"
}
