#!/usr/bin/env bats
# 会話で頼まれた変更も必ず通す起動条件を、一覧に載る description に残す。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

check_description() {
  local description
  description=$(awk 'NR == 1 { if ($0 != "---") exit; next }
    /^---[ \t]*$/ { exit }
    /^description:/ { print }' "$REPO_ROOT/plugins/dev-workflow/commands/$1.md")
  [[ "$description" == *"必ず通す"* ]]
  [[ "$description" == *"会話"* ]]
}

@test "develop description requires the workflow for conversational requests" {
  check_description develop
}

@test "work-issue alias description requires the workflow for conversational requests" {
  check_description work-issue
}
