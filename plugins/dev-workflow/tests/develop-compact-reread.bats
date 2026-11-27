#!/usr/bin/env bats
#
# コンパクト直後に、その会話で develop を呼んでいたときだけ SKILL.md の読み直しを差し込む（issue #1217）。
# 判定できないときは何も出さない（fail-open）。
# SessionStart(compact) の時点の会話記録には compact_boundary も invoked_skills もまだ無く、
# コンパクト前の Skill 呼び出しやコマンドの記録だけがある（#1217 の実機確認）。fixture はその形に合わせる。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  SCRIPT="${REPO_ROOT}/plugins/dev-workflow/scripts/develop-compact-reread.sh"
  HOOKS="${REPO_ROOT}/plugins/dev-workflow/hooks/hooks.json"
  export CLAUDE_PLUGIN_ROOT="${REPO_ROOT}/plugins/dev-workflow"
  TP="${BATS_TEST_TMPDIR}/session.jsonl"
  : > "$TP"
}

# 会話記録に 1 行足す
add() { printf '%s\n' "$1" >> "$TP"; }

skill_call() {
  add '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":"'"$1"'"}}]}}'
}

hook_input() {
  printf '{"session_id":"s1","transcript_path":"%s","hook_event_name":"SessionStart","source":"%s"}' "$TP" "$1"
}

assert_reread() {
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c '
import json,sys
d=json.load(sys.stdin)
h=d["hookSpecificOutput"]
assert h["hookEventName"]=="SessionStart"
c=h["additionalContext"]
assert sys.argv[1]+"/skills/develop/SKILL.md" in c, c
assert "親" in c and "子" in c and "記録先" in c, c
assert "offset" in c and "limit" in c, c
' "$CLAUDE_PLUGIN_ROOT"
}

@test "compact after a Skill call of dev-workflow:develop injects the reread instruction" {
  add '{"type":"user","message":{"role":"user","content":"hello"}}'
  skill_call "dev-workflow:develop"
  run "$SCRIPT" < <(hook_input compact)
  assert_reread
}

@test "compact after the /dev-workflow:develop command injects the reread instruction" {
  add '{"type":"user","message":{"role":"user","content":"<command-message>dev-workflow:develop</command-message>\n<command-name>/dev-workflow:develop</command-name>\n<command-args>#12</command-args>"}}'
  run "$SCRIPT" < <(hook_input compact)
  assert_reread
}

@test "compact after an earlier compaction's invoked_skills record injects the reread instruction" {
  add '{"type":"system","subtype":"compact_boundary"}'
  add '{"type":"attachment","attachment":{"type":"invoked_skills","skills":[{"name":"dev-workflow:develop","path":"plugin:dev-workflow:develop","content":"x"}]}}'
  run "$SCRIPT" < <(hook_input compact)
  assert_reread
}

@test "a develop without the dev-workflow namespace does not count" {
  # プラグインのコマンドは /develop と打っても /dev-workflow:develop と記録される。名前空間の無い名前は別のスキルやコマンド
  skill_call "develop"
  add '{"type":"user","message":{"role":"user","content":"<command-name>/develop</command-name>"}}'
  add '{"type":"attachment","attachment":{"type":"invoked_skills","skills":[{"name":"develop","path":"userSettings:develop","content":"x"}]}}'
  run "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the command in a text block of a list-form user message counts" {
  add '{"type":"user","message":{"role":"user","content":[{"type":"image","source":{}},{"type":"text","text":"<command-name>/dev-workflow:develop</command-name>\n<command-args>#12</command-args>"}]}}'
  run "$SCRIPT" < <(hook_input compact)
  assert_reread
}

@test "valid JSON lines of an unexpected shape do not stop the scan" {
  add '{"type":"attachment","attachment":{"type":"invoked_skills","skills":5,"note":"develop"}}'
  add '{"type":"attachment","attachment":{"type":"invoked_skills","skills":[{"name":["develop"]}]}}'
  add '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":["dev-workflow:develop"]}}]}}'
  add '{"type":"user","message":{"role":"user","content":[{"type":"text","text":["develop"]}]}}'
  add '["develop"]'
  run "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  skill_call "dev-workflow:develop"
  run "$SCRIPT" < <(hook_input compact)
  assert_reread
}

@test "compact in a conversation without develop prints nothing" {
  add '{"type":"user","message":{"role":"user","content":"Use the probe skill"}}'
  skill_call "probe:hello"
  run "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "other skills whose name contains develop do not count" {
  skill_call "dev-workflow:codex-develop"
  add '{"type":"user","message":{"role":"user","content":"<command-name>/dev-workflow:develop-epic</command-name>"}}'
  run "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "develop only mentioned in text or tool results does not count" {
  add '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"run dev-workflow:develop with <command-name>/dev-workflow:develop</command-name>"}]}}'
  add '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t","content":"\"name\":\"Skill\",\"input\":{\"skill\":\"dev-workflow:develop\"} <command-name>/dev-workflow:develop</command-name>"}]}}'
  run "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "startup, clear and resume sources print nothing even with develop" {
  skill_call "dev-workflow:develop"
  for src in startup clear resume ""; do
    run "$SCRIPT" < <(hook_input "$src")
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "missing transcript prints nothing" {
  rm -f "$TP"
  run "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stdin that is not JSON prints nothing" {
  run "$SCRIPT" <<<'not json'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "broken lines in the transcript are skipped" {
  add '{"type":"assistant", broken'
  add 'garbage'
  run "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  skill_call "dev-workflow:develop"
  run "$SCRIPT" < <(hook_input compact)
  assert_reread
}

@test "empty CLAUDE_PLUGIN_ROOT prints nothing" {
  skill_call "dev-workflow:develop"
  CLAUDE_PLUGIN_ROOT= run "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "python3 not on PATH prints nothing" {
  skill_call "dev-workflow:develop"
  local bin="${BATS_TEST_TMPDIR}/nopython-bin"
  mkdir -p "$bin"
  ln -s "$(command -v bash)" "$bin/bash"
  ln -s "$(command -v cat)" "$bin/cat"
  if PATH="$bin" command -v python3 >/dev/null 2>&1; then return 1; fi
  PATH="$bin" run /bin/bash "$SCRIPT" < <(hook_input compact)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hooks.json registers it under SessionStart for compact" {
  run python3 -c '
import json,sys
h=json.load(open(sys.argv[1]))["hooks"]["SessionStart"]
ok=[e for e in h if "compact" in e.get("matcher","").split("|")
    and any("develop-compact-reread.sh" in x["command"] for x in e["hooks"])]
sys.exit(0 if ok else 1)
' "$HOOKS"
  [ "$status" -eq 0 ]
}
