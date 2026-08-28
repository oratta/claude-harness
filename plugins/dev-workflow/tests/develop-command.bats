#!/usr/bin/env bats
#
# /develop コマンド定義と /work-issue エイリアスの構造検証（issue #203）
# 旧 work-issue-command.bats（#36: 5 分岐・issueify フォールバック）と
# issue-draft-sections.bats（#47: fail-soft ドラフトの承認判断 2 節）を統合したもの。
# command md は実行コードではないため、仕様の記述が存在することを検証する。
#
# spec: dev-workflow-issue-entry, dev-workflow-develop

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CMD="$PLUGIN_DIR/commands/develop.md"
  ALIAS="$PLUGIN_DIR/commands/work-issue.md"
  MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
}

frontmatter() { awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$1"; }

@test "command: develop.md and work-issue.md both exist" {
  [ -f "$CMD" ]
  [ -f "$ALIAS" ]
}

@test "command: allowed-tools includes Agent and SendMessage and excludes Edit" {
  tools="$(frontmatter "$CMD" | awk -F': ' '/^allowed-tools:/{print $2; exit}')"
  echo "$tools" | grep -qw 'Agent'
  echo "$tools" | grep -qw 'SendMessage'
  ! echo "$tools" | grep -qw 'Edit'
  ! echo "$tools" | grep -qw 'Write'
}

@test "command: resolves skills/develop/SKILL.md via path-discovery and runs it inline (no Skill tool)" {
  grep -q 'skills/develop' "$CMD"
  grep -q 'CLAUDE_PLUGIN_ROOT' "$CMD"
  grep -q 'plugins/dev-workflow/skills/develop' "$CMD"
  grep -q 'interactive' "$CMD"
  grep -qE 'Skill tool は使わない|Skill ツールは使わない' "$CMD"
}

# --- 5 分岐 ---

@test "branch 1/3: existing number/URL/natural-language branches remain" {
  grep -q '数字のみ' "$CMD"
  grep -q 'GitHub issue URL' "$CMD"
  grep -q 'gh issue list' "$CMD"
}

@test "branch 2: nonexistent issue number triggers typo check first, then entry-0 unless issueify is chosen" {
  grep -q 'typo' "$CMD"
  b2="$(grep -n '数字のみだが issue が存在しない' "$CMD" | head -1)"
  [ -n "$b2" ]
  echo "$b2" | grep -q '入口 0'
}

@test "branch 4: unmatched natural-language request defaults to entry-0 (Draft PR), issueify only when tracking is needed" {
  b4="$(grep -n 'マッチしな' "$CMD" | head -1)"
  [ -n "$b4" ]
  echo "$b4" | grep -q '入口 0'
  echo "$b4" | grep -q 'Draft PR'
  echo "$b4" | grep -q '追跡・キュー・議論'
}

@test "branch 5: no-arg listing offers both start-without-issue and issue-ify options" {
  grep -q '新しいタスクを説明して着手する' "$CMD"
  grep -q '新しいタスクを説明して issue 化する' "$CMD"
}

# --- issueify フォールバック ---

@test "fallback: mentions issueify and resolves loops-issueify via path-discovery" {
  grep -q 'issueify' "$CMD"
  grep -q 'loops-issueify' "$CMD"
  grep -q 'plugins/loops/skills/loops-issueify' "$CMD"
}

@test "fallback: fail-soft degrades to minimal gh issue create" {
  grep -qE 'fail-soft|フォールバック' "$CMD"
  grep -q 'gh issue create' "$CMD"
}

@test "fail-soft: minimal draft includes what-changes, cost-of-inaction and measurable acceptance sections" {
  grep -q 'これで何が変わるか' "$CMD"
  grep -q 'やらないとどうなるか' "$CMD"
  grep -q '測定可能な受け入れ条件' "$CMD"
}

@test "fallback: approval gate before filing" {
  grep -q '承認' "$CMD"
}

@test "fallback: multi-issue split selects one issue to work on" {
  grep -qE '着手する1件|着手1件' "$CMD"
}

# --- エイリアス ---

@test "alias: work-issue.md points at develop.md, passes ARGUMENTS, and carries no branch body" {
  grep -q 'エイリアス' "$ALIAS"
  grep -q 'commands/develop.md' "$ALIAS"
  grep -qF '$ARGUMENTS' "$ALIAS"
  ! grep -q '数字のみ' "$ALIAS"
  ! grep -q 'typo' "$ALIAS"
  ! grep -q 'loops-issueify' "$ALIAS"
  ! grep -q 'gh issue create' "$ALIAS"
}

# --- manifest ---

@test "manifest: plugin version is at least 2.0.0" {
  printf '2.0.0\n%s\n' "$(jq -r .version "$MANIFEST")" | sort -V -C
}

@test "manifest: registers develop skill and both commands, not github-issue" {
  jq -e '.skills | index("./skills/develop")' "$MANIFEST" >/dev/null
  jq -e '.skills | index("./skills/github-issue") == null' "$MANIFEST" >/dev/null
  jq -e '.commands | index("./commands/develop.md")' "$MANIFEST" >/dev/null
  jq -e '.commands | index("./commands/work-issue.md")' "$MANIFEST" >/dev/null
}
