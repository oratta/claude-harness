#!/usr/bin/env bats
#
# dev-workflow-tripwire-prompt-refresh: UserPromptSubmit hook による
# 「プラグインが更新されたとき（CLAUDE_PLUGIN_ROOT が変わったとき）だけ」の
# トリップワイヤー再注入
#
# spec: dev-workflow-escalation-tripwires（issue #34 縮小版、issue #447 で比較値を
# plugin.json の version から CLAUDE_PLUGIN_ROOT に変更）
#
# キャッシュと同じ形の偽プラグインルート（${BASE}/dev-workflow/<SHA>）を組んで検証する。
# plugin.json には version を書かない（issue #447 の実際の形）。usage-probe.sh は意図的に
# コピーしないので、session-tripwires.sh はネットワークに出ず conserve 既定で決定論的に走る。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/prompt-tripwires-refresh.sh"

  BASE="$(mktemp -d)"
  STATE_DIR="$BASE/state"
  use_root "aaaaaaaaaaaa"
}

teardown() {
  rm -rf "$BASE"
}

# $1 = キャッシュの版名（commit SHA）。そのディレクトリに偽プラグインを組み、FAKE をそこに切り替える
use_root() {
  FAKE="$BASE/dev-workflow/$1"
  mkdir -p "$FAKE/scripts" "$FAKE/templates" "$FAKE/.claude-plugin"
  cp "$PLUGIN_DIR/scripts/session-tripwires.sh" "$FAKE/scripts/"
  cp "$SCRIPT" "$FAKE/scripts/"
  cp "$PLUGIN_DIR/templates/escalation-tripwires.md" "$FAKE/templates/"
  printf '{\n  "name": "dev-workflow"\n}\n' > "$FAKE/.claude-plugin/plugin.json"
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

# (a) 状態ファイルが無い初回は注入せず、現在の CLAUDE_PLUGIN_ROOT を記録するだけ
@test "(a) first prompt of a session records CLAUDE_PLUGIN_ROOT without injecting" {
  run run_hook '{"session_id":"sess-a","hook_event_name":"UserPromptSubmit"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -f "${STATE_DIR}/sess-a" ]
  [ "$(cat "${STATE_DIR}/sess-a")" = "$FAKE" ]
}

# (b) 同じ CLAUDE_PLUGIN_ROOT の2回目以降は無出力（毎プロンプト注入しない）
@test "(b) same CLAUDE_PLUGIN_ROOT stays silent on later prompts" {
  run_hook '{"session_id":"sess-b"}'
  run run_hook '{"session_id":"sess-b"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run run_hook '{"session_id":"sess-b"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "${STATE_DIR}/sess-b")" = "$FAKE" ]
}

# (c) プラグインの更新で CLAUDE_PLUGIN_ROOT が変わると additionalContext を出力し、状態を更新する
@test "(c) CLAUDE_PLUGIN_ROOT change emits additionalContext and updates state" {
  run_hook '{"session_id":"sess-c"}'
  use_root "bbbbbbbbbbbb"
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
           "FABLE_BUDGET_MODE", "aaaaaaaaaaaa", "bbbbbbbbbbbb"):
    assert kw in ctx, kw
PY
  [ "$(cat "${STATE_DIR}/sess-c")" = "$FAKE" ]
  # 更新後は同じ CLAUDE_PLUGIN_ROOT なので再び無出力に戻る
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
  old="$FAKE"
  use_root "cccccccccccc"
  # 新しいセッションは初回なので注入しない（SessionStart が新版を注入済み）
  run run_hook '{"session_id":"sess-e2"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "${STATE_DIR}/sess-e2")" = "$FAKE" ]
  # 既存セッションは自分の記録（旧ルート）との差で注入される
  [ "$(cat "${STATE_DIR}/sess-e1")" = "$old" ]
  run run_hook '{"session_id":"sess-e1"}'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$(cat "${STATE_DIR}/sess-e1")" = "$FAKE" ]
}

# (f) 30 日より古い状態ファイルは書き込み経路で掃除される
@test "(f) stale state files older than 30 days are pruned" {
  run_hook '{"session_id":"sess-f"}'
  touch -t 202001010000 "${STATE_DIR}/stale-session"
  [ -f "${STATE_DIR}/stale-session" ]
  use_root "dddddddddddd"
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

# (h) 旧方式（plugin.json の version）の記録が残ったセッションは 1 回だけ再注入して移行する
@test "(h) state holding an old-style version number reinjects once then compares by root" {
  mkdir -p "$STATE_DIR"
  printf '2.13.38\n' > "${STATE_DIR}/sess-h"
  run run_hook '{"session_id":"sess-h"}'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$(cat "${STATE_DIR}/sess-h")" = "$FAKE" ]
  run run_hook '{"session_id":"sess-h"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# (i) plugin.json に version があっても無くても動作は同じ（比較に使わない）
@test "(i) a version field in plugin.json neither triggers nor suppresses reinjection" {
  run_hook '{"session_id":"sess-i"}'
  # 同じルートで version だけ書き足しても無出力
  printf '{\n  "name": "dev-workflow",\n  "version": "9.9.9"\n}\n' > "$FAKE/.claude-plugin/plugin.json"
  run run_hook '{"session_id":"sess-i"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # 同じ version のままルートが変われば注入される
  use_root "eeeeeeeeeeee"
  printf '{\n  "name": "dev-workflow",\n  "version": "9.9.9"\n}\n' > "$FAKE/.claude-plugin/plugin.json"
  run run_hook '{"session_id":"sess-i"}'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
