#!/usr/bin/env bats
#
# issueify スキル（loops-issueify の dev-workflow への移設。issue #205）の構造検証
#
# spec: dev-workflow-issueify, dev-workflow-issue-entry（issueify フォールバックの解決先）
#
# SKILL.md は実行コードではないため、規定の記述が存在することを grep で検証する。
# テスト名は ASCII のみ。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/issueify/SKILL.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  CMD="${PLUGIN_DIR}/commands/develop.md"
}

frontmatter() { awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$SKILL"; }

# --- Requirement: issueify スキルは dev-workflow に属し 4 つの入力モードを持つ ---

@test "skill: issueify SKILL.md exists and is registered in plugin.json skills[]" {
  [ -f "$SKILL" ]
  jq -e '.skills | index("./skills/issueify")' "$MANIFEST" >/dev/null
}

@test "frontmatter: name is issueify and description carries the trigger phrases" {
  frontmatter | grep -q '^name: issueify$'
  desc="$(frontmatter | sed -n 's/^description:[[:space:]]*//p')"
  [ -n "$desc" ]
  echo "$desc" | grep -q 'issueにして'
  echo "$desc" | grep -q 'issue化'
  echo "$desc" | grep -q 'バックログ'
}

@test "skill: four input modes are defined" {
  grep -q 'インラインテキスト' "$SKILL"
  grep -q 'ファイルパス' "$SKILL"
  grep -q '引数なし' "$SKILL"
  grep -qF -- '--existing' "$SKILL"
  grep -q 'TODO' "$SKILL"
  grep -q 'FIXME' "$SKILL"
}

# --- Requirement: 原子化・測定可能な受け入れ条件・不足だけヒアリング・承認ゲート ---

@test "skill: atomization and the six draft sections" {
  grep -q '原子化' "$SKILL"
  grep -q 'これで何が変わるか' "$SKILL"
  grep -q 'やらないとどうなるか' "$SKILL"
  grep -q '概要' "$SKILL"
  grep -q '触るファイル' "$SKILL"
  grep -q '受け入れ条件' "$SKILL"
  grep -q '備考' "$SKILL"
}

@test "skill: acceptance criteria are limited to the four machine-checkable kinds" {
  grep -q 'exit 0' "$SKILL"
  grep -q 'curl' "$SKILL"
  grep -q 'ブラウザ' "$SKILL"
  grep -q '成果物' "$SKILL"
  grep -qE '機械検証に変換できない.*(書かない|書いてはならない)' "$SKILL"
}

@test "skill: hearing is limited to gaps and approval precedes filing" {
  grep -q 'AskUserQuestion' "$SKILL"
  grep -qE '導出できた項目は質問しない' "$SKILL"
  grep -q '承認を得てから' "$SKILL"
  grep -q 'gh issue create' "$SKILL"
  grep -qE '承認なしに.*(起票|編集)しない' "$SKILL"
}

@test "skill: uses the repo issue template when present, else the six sections" {
  grep -qE 'issue テンプレート' "$SKILL"
}

# --- Requirement: ラベル提案と issue 依存関係の張り方 ---

@test "skill: five label proposals are defined" {
  for l in agent-ready needs-approval human-only 'size:large' agent-proposed; do
    grep -qF -- "$l" "$SKILL" || { echo "missing label ${l}"; return 1; }
  done
}

@test "skill: native issue dependencies command is documented" {
  grep -q 'dependencies/blocked_by' "$SKILL"
  grep -q 'issue_id' "$SKILL"
  grep -q '移行済み' "$SKILL"
}

# --- Requirement: 解散プラグインへの依存を持たない ---

@test "skill: no references to retired loops plugin parts" {
  ! grep -q 'loops' "$SKILL"
  ! grep -q 'goalify' "$SKILL"
  ! grep -q 'agent-loop-template' "$SKILL"
  ! grep -q 'recipes/' "$SKILL"
}

@test "skill: translation discipline points at the shared pr-body-format" {
  grep -qF 'plugins/dev-workflow/references/pr-body-format.md' "$SKILL"
  grep -q 'docs/agent-loop.md' "$SKILL"
}

# --- Requirement (dev-workflow-issue-entry): フォールバックは同プラグイン内の issueify を Read ---

@test "develop.md resolves issueify inside dev-workflow and never via loops" {
  grep -q 'skills/issueify/SKILL.md' "$CMD"
  grep -q 'CLAUDE_PLUGIN_ROOT' "$CMD"
  ! grep -q 'plugins/loops' "$CMD"
  ! grep -q 'loops-issueify' "$CMD"
}
