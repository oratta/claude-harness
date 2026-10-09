#!/usr/bin/env bats
#
# チーム機能（CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS）が有効なら SessionStart で警告する（issue #591）。
# spec: openspec/changes/team-mode-warning（archive 後は openspec/specs/dev-workflow-role-agent-types）

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  SCRIPT="${REPO_ROOT}/plugins/dev-workflow/scripts/team-mode-warning.sh"
  HOOKS="${REPO_ROOT}/plugins/dev-workflow/hooks/hooks.json"
  unset CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
}

@test "value 1 puts the warning in both systemMessage and additionalContext" {
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c '
import json,sys
d=json.load(sys.stdin)
n="CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
assert n in d["systemMessage"]
assert n in d["hookSpecificOutput"]["additionalContext"]
assert d["hookSpecificOutput"]["hookEventName"]=="SessionStart"
'
}

@test "value true also warns" {
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=true run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *systemMessage* ]] || return 1
}

@test "unset prints nothing" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty prints nothing" {
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS= run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "value 0 prints nothing" {
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "false and FALSE print nothing" {
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=false run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=FALSE run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hooks.json registers it under SessionStart with startup-clear-compact matcher" {
  run python3 -c '
import json,sys
h=json.load(open(sys.argv[1]))["hooks"]["SessionStart"]
ok=[e for e in h if e.get("matcher")=="startup|clear|compact"
    and any("team-mode-warning.sh" in x["command"] for x in e["hooks"])]
sys.exit(0 if ok else 1)
' "$HOOKS"
  [ "$status" -eq 0 ]
}
