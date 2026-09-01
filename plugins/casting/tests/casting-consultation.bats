#!/usr/bin/env bats
#
# casting-consultation-protocol: 論点相談・仲裁プロトコルの構造要件
# spec: openspec/changes/casting-consultation-arbitration/specs/casting-consultation-protocol/spec.md
#   Requirement: policy 文書テンプレートの人格ブロック形式 / 観点スペシャリスト subagent の定義 /
#                仲裁 subagent の入力契約 / 相談・仲裁の運用手順と事後報告フォーマット /
#                判例台帳への人格名帰属と実例
# spec: openspec/changes/casting-consultation-arbitration/specs/casting-catalog/spec.md
#   Requirement: 常時ロード層の返信前チェック rule（手順④の相談・仲裁分岐）
#
# 日本語語彙の照合は LC_ALL=C の grep -F のみを使う（awk のマルチバイト比較は禁止）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  POLICY_TMPL="${PLUGIN_DIR}/templates/policy.md"
  SPECIALIST="${PLUGIN_DIR}/agents/casting-specialist.md"
  ARBITER="${PLUGIN_DIR}/agents/casting-arbiter.md"
  PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  SKILL="${PLUGIN_DIR}/skills/casting/SKILL.md"
  RULE="${REPO_ROOT}/rules/perspective-casting.md"
  PRECEDENTS_TMPL="${PLUGIN_DIR}/templates/precedents.md"
  REPO_PRECEDENTS="${REPO_ROOT}/.claude/casting/precedents.md"
}

# --- 受け入れ条件1: policy テンプレートに人格ブロックの形式が定義されている ---

@test "policy template: exists with perspective and catalog_version front matter" {
  [ -f "$POLICY_TMPL" ]
  head -5 "$POLICY_TMPL" | LC_ALL=C grep -q '^perspective:'
  head -5 "$POLICY_TMPL" | LC_ALL=C grep -qx 'catalog_version: 1'
}

@test "policy template: persona block carries name, stance and tone" {
  LC_ALL=C grep -qF -- "## 人格" "$POLICY_TMPL"
  for f in "名前" "スタンス" "口調"; do
    LC_ALL=C grep -qF -- "- ${f}:" "$POLICY_TMPL"
  done
}

@test "policy template: judgment criteria section is the source of truth, persona is a container" {
  LC_ALL=C grep -qF -- "## 判断基準" "$POLICY_TMPL"
  LC_ALL=C grep -qF -- "人格は判断基準の入れ物であって代替ではない" "$POLICY_TMPL"
}

# --- 受け入れ条件2: スペシャリスト・仲裁のサブエージェント定義 ---

@test "specialist: exists with mid-tier model and read-only tools" {
  [ -f "$SPECIALIST" ]
  LC_ALL=C grep -qx 'model: sonnet' "$SPECIALIST"
  LC_ALL=C grep -qx 'tools: Read, Grep, Glob, WebFetch' "$SPECIALIST"
}

@test "specialist: instructed to read the policy, wear the persona and cite precedents" {
  LC_ALL=C grep -qF -- "policies/" "$SPECIALIST"
  LC_ALL=C grep -qF -- "人格ブロック" "$SPECIALIST"
  LC_ALL=C grep -qF -- "過去判例" "$SPECIALIST"
  LC_ALL=C grep -qF -- "人格名" "$SPECIALIST"
}

@test "arbiter: exists with top-tier model" {
  [ -f "$ARBITER" ]
  LC_ALL=C grep -qx 'model: fable' "$ARBITER"
}

@test "arbiter: input is limited to phase declaration plus the claim list, no work context" {
  LC_ALL=C grep -qF -- "フェーズ宣言文と主張リストのみ" "$ARBITER"
  LC_ALL=C grep -qF -- "作業コンテキスト" "$ARBITER"
  LC_ALL=C grep -qF -- "渡された入力以外を読みに行かない" "$ARBITER"
  LC_ALL=C grep -qF -- "ファイルパスが渡されても開かない" "$ARBITER"
}

@test "arbiter: claim list carries main session plus one claim per persona" {
  LC_ALL=C grep -qF -- "主張リスト" "$ARBITER"
  LC_ALL=C grep -qF -- "メインセッションの主張1件" "$ARBITER"
  LC_ALL=C grep -qF -- "人格名付き" "$ARBITER"
}

@test "arbiter: tools frontmatter grants Read only, nothing else" {
  LC_ALL=C grep -qx 'tools: Read' "$ARBITER"
  [ "$(LC_ALL=C grep -c '^tools:' "$ARBITER" | tr -d ' ')" -eq 1 ]
}

@test "arbiter: opening referenced paths is a contract violation that aborts the verdict" {
  LC_ALL=C grep -qF -- "入力契約違反" "$ARBITER"
  LC_ALL=C grep -qF -- "裁定を拒否" "$ARBITER"
}

@test "arbiter: verdict is attributed by persona name with rationale" {
  LC_ALL=C grep -qF -- "人格名" "$ARBITER"
  LC_ALL=C grep -qF -- "根拠" "$ARBITER"
}

@test "plugin.json: registers both agents and bumps version to at least 0.3.0" {
  LC_ALL=C grep -qF -- '"./agents/casting-specialist.md"' "$PLUGIN_JSON"
  LC_ALL=C grep -qF -- '"./agents/casting-arbiter.md"' "$PLUGIN_JSON"
  LC_ALL=C grep -qF -- '"version": "0.4.1"' "$PLUGIN_JSON"
}

# --- 受け入れ条件3: 事後報告フォーマットの定義と実例1件 ---

@test "skill: consultation section defines the trigger and the report format" {
  LC_ALL=C grep -qF -- "論点相談・仲裁" "$SKILL"
  # 発火点＝主へのエスカレーション文面を書き始めた瞬間の宛先チェック
  LC_ALL=C grep -qF -- "書き始めた瞬間" "$SKILL"
  # 事後報告フォーマットの5要素
  for f in "論点" "主張" "裁定" "根拠" "判例リンク"; do
    LC_ALL=C grep -qF -- "$f" "$SKILL"
  done
}

@test "skill: defines the no-reconsultation terminal condition" {
  LC_ALL=C grep -qF -- "同一論点の相談は1回" "$SKILL"
  LC_ALL=C grep -qF -- "再相談" "$SKILL"
}

@test "skill: caller convention forbids passing work context to the arbiter" {
  LC_ALL=C grep -qF -- "作業コンテキスト" "$SKILL"
  LC_ALL=C grep -qF -- "フェーズ宣言文と主張リスト" "$SKILL"
}

@test "skill: arbiter input must not contain file paths or URLs" {
  LC_ALL=C grep -qF -- "参照可能な文字列を一切含めない" "$SKILL"
}

@test "skill: consultation fans out to every agent-held perspective" {
  LC_ALL=C grep -qF -- "担い手がエージェントの観点すべて" "$SKILL"
  LC_ALL=C grep -qF -- "並行" "$SKILL"
}

@test "skill: a single dissent, including between specialists, triggers arbitration" {
  LC_ALL=C grep -qF -- "誰か1人でも" "$SKILL"
  LC_ALL=C grep -qF -- "スペシャリスト同士" "$SKILL"
}

@test "skill: out-of-scope or missing policy escalates to the owner" {
  LC_ALL=C grep -qF -- "判断基準の範囲外" "$SKILL"
  LC_ALL=C grep -qF -- "policy 不在" "$SKILL"
  LC_ALL=C grep -qF -- "読み取り不能" "$SKILL"
  LC_ALL=C grep -qF -- "主へ上げる" "$SKILL"
}

@test "specialist: missing or unreadable policy is reported, not improvised" {
  LC_ALL=C grep -qF -- "policy 不在" "$SPECIALIST"
  LC_ALL=C grep -qF -- "読み取り不能" "$SPECIALIST"
}

@test "rule: step 4 escalates out-of-scope replies to the owner" {
  LC_ALL=C grep -qF -- "範囲外" "$RULE"
  LC_ALL=C grep -qF -- "policy 不在" "$RULE"
}

@test "precedents template: route vocabulary includes consultation" {
  LC_ALL=C grep -qF -- "相談の上自走した" "$PRECEDENTS_TMPL"
}

@test "repo precedents: the consultation example block itself carries all five report elements" {
  [ -f "$REPO_PRECEDENTS" ]
  # ブロック単位で切り出して検査する（ファイル全体への語句 grep では他ブロックの語句で偽合格する）
  local block
  block="$(awk '/^### 2026-08-19 観点スペシャリスト/{on=1; next} /^### /{on=0} on' "$REPO_PRECEDENTS")"
  printf '%s' "$block" | LC_ALL=C grep -qF -- "相談の上自走した"
  for f in "- 論点:" "- 各人格の主張:" "- 裁定:" "- 根拠:" "- 判例リンク:" ; do
    printf '%s' "$block" | LC_ALL=C grep -qF -- "$f"
  done
  # 発言の人格名帰属（保守番のクレバス）もブロック内で確認する
  printf '%s' "$block" | LC_ALL=C grep -qF -- "保守番のクレバス"
}

@test "repo precedents: the annotation block marks the dogfood trial as pre-protocol" {
  # 既存判例は書き換えず、直後の注記ブロックで「確定版規約の実例ではない」ことを明示する
  LC_ALL=C grep -qF -- "### 2026-08-21 注記" "$REPO_PRECEDENTS"
  LC_ALL=C grep -qF -- "プロトコル確定前の dogfood 試行" "$REPO_PRECEDENTS"
  LC_ALL=C grep -qF -- "確定版規約の実例ではない" "$REPO_PRECEDENTS"
}

# --- 受け入れ条件4: 担い手が主の観点が絡む論点は相談・仲裁に入らず主へ ---

@test "rule: step 4 branches to specialist consultation and arbitration" {
  LC_ALL=C grep -qF -- "観点スペシャリスト" "$RULE"
  LC_ALL=C grep -qF -- "仲裁" "$RULE"
  LC_ALL=C grep -qF -- "事後報告" "$RULE"
}

@test "rule: issues touching an owner-held perspective bypass consultation and go to the owner" {
  LC_ALL=C grep -qF -- "担い手が主の観点が1つでも" "$RULE"
  LC_ALL=C grep -qF -- "相談・仲裁に入らない" "$RULE"
}

@test "rule: step 5 attributes statements and verdicts by persona name" {
  LC_ALL=C grep -qF -- "人格名" "$RULE"
}

@test "rule: stays within 30 lines after the rewrite" {
  [ "$(wc -l < "$RULE" | tr -d ' ')" -le 30 ]
}

@test "skill: owner-held branch is stated ahead of consultation" {
  LC_ALL=C grep -qF -- "担い手が主の観点が1つでも" "$SKILL"
}

# --- 回帰: レビューゲート Blocking 指摘（2026-08-20） ---

@test "skill: the assessment section no longer restates the old self-drive step and routes to consultation" {
  # 判定節（## 論点が来たときの判定 〜 次の ## 見出し）に旧手順④「方針文・判断基準に従って自走する」が
  # 残っていないこと、相談手順への接続があることをブロック単位で検査する（Blocking 1）
  local section
  section="$(awk '/^## 論点が来たときの判定/{on=1; next} /^## /{on=0} on' "$SKILL")"
  [ -n "$section" ]
  ! printf '%s' "$section" | LC_ALL=C grep -qF -- "方針文・判断基準に従って自走する"
  printf '%s' "$section" | LC_ALL=C grep -qF -- "「論点相談・仲裁」の手順に入る"
}

@test "arbiter: the precedent link is declared caller-appended, not part of the verdict output" {
  # 仲裁は作業コンテキストを持たず判例リンクを知り得ない（Blocking 3）
  LC_ALL=C grep -qF -- "判例リンク" "$ARBITER"
  LC_ALL=C grep -qF -- "記録時に呼び出し側が付与する" "$ARBITER"
}

@test "spec: consultation protocol spec ends without a trailing blank line" {
  # EOF の余分な空行（Blocking 4）。tail -1 が空でない＝末尾は本文行
  local spec_file="${REPO_ROOT}/openspec/specs/casting-consultation-protocol/spec.md"
  [ -f "$spec_file" ]
  [ -n "$(tail -1 "$spec_file")" ]
}

@test "plugin.json: description states the claim list, not the retired two-party wording" {
  # 旧仕様「双方の主張」（2者固定）が説明文に残らないこと（Blocking 5）
  ! LC_ALL=C grep -qF -- "双方の主張" "$PLUGIN_JSON"
  LC_ALL=C grep -qF -- "主張リスト" "$PLUGIN_JSON"
}
