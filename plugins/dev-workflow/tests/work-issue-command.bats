#!/usr/bin/env bats
# work-issue command 定義の構造検証（issue #36: issueify フォールバック）
# command md は実行コードではないため、仕様（5分岐・fail-soft・承認ゲート）の
# 記述が存在することを検証する。挙動の担保はドッグフーディングで行う。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CMD="$PLUGIN_DIR/commands/work-issue.md"
  MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
}

@test "command: work-issue.md exists" {
  [ -f "$CMD" ]
}

@test "fallback: mentions issueify" {
  grep -q "issueify" "$CMD"
}

@test "branch 2: nonexistent issue number triggers typo check first" {
  grep -q "typo" "$CMD"
}

@test "branch 4: unmatched natural-language request falls back to issueify" {
  grep -q "マッチしな" "$CMD"
}

@test "branch 5: no-arg listing offers creating a new issue" {
  grep -q "新しいタスクを説明して issue 化" "$CMD"
}

@test "fallback: resolves loops-issueify via path-discovery" {
  grep -q "loops-issueify" "$CMD"
  grep -q "plugins/loops/skills/loops-issueify" "$CMD"
}

@test "fallback: fail-soft degrades to minimal gh issue create" {
  grep -qE "fail-soft|フォールバック" "$CMD"
  grep -q "gh issue create" "$CMD"
}

@test "fallback: multi-issue split selects one issue to work on" {
  grep -qE "着手する1件|着手1件" "$CMD"
}

@test "fallback: approval gate before filing" {
  grep -q "承認" "$CMD"
}

@test "regression: existing number/URL/natural-language branches remain" {
  grep -q "数字のみ" "$CMD"
  grep -q "GitHub issue URL" "$CMD"
  grep -q "gh issue list" "$CMD"
}

@test "manifest: plugin version is at least 1.4.0" {
  # issue #36 時点で 1.4.0 に上げた。以降のバージョンアップで壊れないよう下限チェックにする
  printf '1.4.0\n%s\n' "$(jq -r .version "$MANIFEST")" | sort -V -C
}
