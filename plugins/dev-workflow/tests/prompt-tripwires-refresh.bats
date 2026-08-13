#!/usr/bin/env bats
#
# dev-workflow-tripwire-prompt-refresh: UserPromptSubmit hook による
# 「プラグインのバージョンが変わったときだけ」のトリップワイヤー再注入
#
# spec: dev-workflow-escalation-tripwires（issue #34 縮小版）
#
# 偽プラグインルート（$FAKE）を組んで検証する。usage-probe.sh は意図的にコピーしない
# ので、session-tripwires.sh はネットワークに出ず conserve 既定で決定論的に走る。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/prompt-tripwires-refresh.sh"

  FAKE="$(mktemp -d)"
  mkdir -p "$FAKE/scripts" "$FAKE/templates" "$FAKE/.claude-plugin"
  cp "$PLUGIN_DIR/scripts/session-tripwires.sh" "$FAKE/scripts/"
  cp "$SCRIPT" "$FAKE/scripts/"
  cp "$PLUGIN_DIR/templates/escalation-tripwires.md" "$FAKE/templates/"
  STATE_DIR="$FAKE/state"
  set_version "1.0.0"
}

teardown() {
  rm -rf "$FAKE"
}

set_version() {
  printf '{\n  "name": "dev-workflow",\n  "version": "%s"\n}\n' "$1" > "$FAKE/.claude-plugin/plugin.json"
}

# $1 = stdin に流す hook 入力（JSON）
run_hook() {
  printf '%s' "$1" | env \
    CLAUDE_PLUGIN_ROOT="$FAKE" \
    TRIPWIRE_STATE_DIR="$STATE_DIR" \
    USAGE_SNAPSHOT="$FAKE/absent-snapshot" \
    "$FAKE/scripts/prompt-tripwires-refresh.sh"
}

@test "hooks.json: has UserPromptSubmit entry calling prompt-tripwires-refresh.sh" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
entries = d["hooks"]["UserPromptSubmit"]
cmd = entries[0]["hooks"][0]["command"]
assert entries[0]["hooks"][0]["type"] == "command"
assert "${CLAUDE_PLUGIN_ROOT}" in cmd, cmd
assert "prompt-tripwires-refresh.sh" in cmd, cmd
# 既存の SessionStart 注入は残っていること
assert d["hooks"]["SessionStart"][0]["matcher"] == "startup|clear|compact"
PY
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

# (a) 状態ファイルが無い初回は注入せず、現在バージョンを記録するだけ
@test "(a) first prompt of a session records version without injecting" {
  run run_hook '{"session_id":"sess-a","hook_event_name":"UserPromptSubmit"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -f "${STATE_DIR}/sess-a" ]
  [ "$(cat "${STATE_DIR}/sess-a")" = "1.0.0" ]
}

# (b) 同一バージョンの2回目以降は無出力（毎プロンプト注入しない）
@test "(b) same version stays silent on later prompts" {
  run_hook '{"session_id":"sess-b"}'
  run run_hook '{"session_id":"sess-b"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run run_hook '{"session_id":"sess-b"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "${STATE_DIR}/sess-b")" = "1.0.0" ]
}

# (c) バージョンが変わると additionalContext を出力し、状態を更新する
@test "(c) version change emits additionalContext and updates state" {
  run_hook '{"session_id":"sess-c"}'
  set_version "1.1.0"
  run run_hook '{"session_id":"sess-c"}'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
h = d["hookSpecificOutput"]
assert h["hookEventName"] == "UserPromptSubmit", h
ctx = h["additionalContext"]
for kw in ("昇格トリップワイヤー", "規模超過", "失敗ループ", "仕様の発明",
           "FABLE_BUDGET_MODE", "1.0.0", "1.1.0"):
    assert kw in ctx, kw
PY
  [ "$(cat "${STATE_DIR}/sess-c")" = "1.1.0" ]
  # 更新後は同一バージョンなので再び無出力に戻る
  run run_hook '{"session_id":"sess-c"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# (d) 壊れた JSON を渡されても exit 0・無出力（プロンプト送信をブロックしない）
@test "(d) malformed stdin JSON still exits 0 with no output" {
  run run_hook '{"session_id": "sess-d"'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run run_hook 'not json at all'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run run_hook ''
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# (e) セッション ID が異なれば状態は独立する
@test "(e) state is isolated per session id" {
  run_hook '{"session_id":"sess-e1"}'
  set_version "2.0.0"
  # 新しいセッションは初回なので注入しない（SessionStart が新版を注入済み）
  run run_hook '{"session_id":"sess-e2"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "${STATE_DIR}/sess-e2")" = "2.0.0" ]
  # 既存セッションは自分の記録（1.0.0）との差で注入される
  run run_hook '{"session_id":"sess-e1"}'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$(cat "${STATE_DIR}/sess-e1")" = "2.0.0" ]
}

# (f) 30 日より古い状態ファイルは書き込み経路で掃除される
@test "(f) stale state files older than 30 days are pruned" {
  run_hook '{"session_id":"sess-f"}'
  touch -t 202001010000 "${STATE_DIR}/stale-session"
  [ -f "${STATE_DIR}/stale-session" ]
  set_version "1.2.0"
  run_hook '{"session_id":"sess-f"}'
  [ ! -f "${STATE_DIR}/stale-session" ]
  [ -f "${STATE_DIR}/sess-f" ]
}

# (g) セッション ID が取れなければ何もしない
@test "(g) no session id means no state and no output" {
  run run_hook '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -d "$STATE_DIR" ]
}
