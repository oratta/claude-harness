#!/usr/bin/env bats
#
# casting-delegation: 委任＝「許可ツール × 任された観点」の定義正本・委任宣言の書式・
# /casting:policy-interview・返信前チェック手順③のツール側確認（issue #207）
# spec: openspec/specs/casting-delegation/spec.md
#   Requirement: 委任の定義正本 / 委任宣言の書式と置き場 /
#                /casting:policy-interview による policy 文書の対話生成 /
#                全文未把握の外部規約を前提として書ける /
#                返信前チェック手順③でツール側も確認する
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  DELEGATION="${PLUGIN_DIR}/catalog/delegation.md"
  TEMPLATE="${PLUGIN_DIR}/templates/delegation.md"
  POLICY_TEMPLATE="${PLUGIN_DIR}/templates/policy.md"
  INTERVIEW="${PLUGIN_DIR}/commands/policy-interview.md"
  SKILL="${PLUGIN_DIR}/skills/casting/SKILL.md"
  INJECTION="${PLUGIN_DIR}/catalog/injection.md"
  RULE="${REPO_ROOT}/rules/perspective-casting.md"
  PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
}

has() { LC_ALL=C grep -qF -- "$2" "$1"; }

# --- Scenario: 定義正本に 2 プリミティブと正本の所在が書かれている ---

@test "delegation doc: exists and names the two primitives" {
  [ -f "$DELEGATION" ]
  has "$DELEGATION" "許可ツール"
  has "$DELEGATION" "任された観点"
}

@test "delegation doc: points to permission and casting table as the sources of truth" {
  has "$DELEGATION" "permission"
  has "$DELEGATION" "配役表"
}

@test "delegation doc: roles are combinations, and defines what an issue is" {
  has "$DELEGATION" "組み合わせ"
  has "$DELEGATION" "論点"
  has "$DELEGATION" "別の観点を入れると結論が変わる"
}

@test "delegation doc: declares that the summary loses to the sources of truth" {
  has "$DELEGATION" "正本が勝つ"
}

# --- Scenario: 雛形が 2 表を 1 ファイルに持つ ---

@test "delegation template: carries catalog_version 1 front matter" {
  head -3 "$TEMPLATE" | grep -qx 'catalog_version: 1'
}

@test "delegation template: one heading with both tables" {
  LC_ALL=C grep -qE '^## 委任' "$TEMPLATE"
  has "$TEMPLATE" "### 許可ツール"
  has "$TEMPLATE" "### 任された観点"
  has "$TEMPLATE" "| ツール/パターン | 許可 | 出どころ |"
  has "$TEMPLATE" "| 観点 | 担い手 | 根拠 |"
}

# --- Scenario: SKILL.md が ## 委任 節と 5 列上書き表を区別している ---

@test "skill: session declaration distinguishes the delegation summary from the 5-column override" {
  has "$SKILL" "## 委任"
  has "$SKILL" "上書きではない"
}

# --- Scenario: コマンド定義が存在し手順を持つ ---

@test "policy-interview: command file has the right name" {
  [ -f "$INTERVIEW" ]
  head -5 "$INTERVIEW" | grep -q '^name: casting:policy-interview$'
}

@test "policy-interview: procedure covers slug resolution, one question at a time, template, update, follow-up" {
  has "$INTERVIEW" "slug"
  has "$INTERVIEW" "1 問ずつ"
  has "$INTERVIEW" "templates/policy.md"
  has "$INTERVIEW" "既存"
  has "$INTERVIEW" "project.md"
  has "$INTERVIEW" "delegation.md"
}

@test "policy-interview: forbids multi-choice question UI" {
  has "$INTERVIEW" "AskUserQuestion"
  has "$INTERVIEW" "使わない"
}

# --- Scenario: 対応表に無い観点は生成しない ---

@test "policy-interview: stops without generating when the perspective has no slug" {
  has "$INTERVIEW" "対応表に無い"
  has "$INTERVIEW" "生成せず"
}

@test "plugin.json: registers the policy-interview command" {
  has "$PLUGIN_JSON" "./commands/policy-interview.md"
}

@test "injection map: points to policy-interview as the entry for policies" {
  has "$INJECTION" "/casting:policy-interview"
}

# --- Scenario: 雛形に把握度 3 語の説明がある ---

@test "policy template: has the external-rules section with the three grasp levels" {
  has "$POLICY_TEMPLATE" "前提とする外部規約"
  has "$POLICY_TEMPLATE" "| 規約 | 参照先 | 主の把握度 | スペシャリストへの指示 |"
  has "$POLICY_TEMPLATE" "全文把握"
  has "$POLICY_TEMPLATE" "概要のみ"
  has "$POLICY_TEMPLATE" "名前のみ"
}

# --- Scenario: rule に許可ツールの確認と正本ポインタがある ---

@test "rule: step 3 checks the tool side too and points to delegation.md" {
  has "$RULE" "許可ツール"
  has "$RULE" "plugins/casting/catalog/delegation.md"
  [ "$(wc -l < "$RULE" | tr -d ' ')" -le 30 ]
}
