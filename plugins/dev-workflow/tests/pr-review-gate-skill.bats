#!/usr/bin/env bats
#
# pr-review-gate スキルの移植検証（issue #82）
#
# flatmate PR #232 の正本を dev-workflow プラグインへ昇格したもの。
# 手順の骨格（6手順・ラベル体系・fail-closed）が flatmate 版と同一であること、
# flatmate 固有の仕組みへの無条件参照が無いこと（リポ非依存）、
# flatmate issue #240 の収束ルール（2周キャップ・差分限定再レビュー・blocking 限定・
# リスク許容リンクの真正性確認・承認待ち中の並行動作確認）が織り込まれていることを検証する。
#
# spec: dev-workflow-pr-review-gate

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

# --- Requirement: pr-review-gate スキルがプラグインとして全リポに配布される ---

@test "skill: SKILL.md exists" {
  [ -f "$SKILL" ]
}

@test "skill: frontmatter declares name pr-review-gate" {
  head -10 "$SKILL" | grep -q '^name: pr-review-gate$'
}

@test "skill: description contains trigger phrases (create-PR / review / merge / resume-pending)" {
  desc="$(awk '/^description:/{print; exit}' "$SKILL")"
  printf '%s' "$desc" | grep -q 'PR'
  printf '%s' "$desc" | grep -q 'レビュー'
  printf '%s' "$desc" | grep -q 'マージ'
  printf '%s' "$desc" | grep -q '保留'
}

@test "manifest: plugin.json registers ./skills/pr-review-gate" {
  jq -e '.skills | index("./skills/pr-review-gate")' "$MANIFEST" >/dev/null
}

@test "manifest: version bumped above 1.6.2" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$v" != "1.6.2" ]
  highest="$(printf '1.6.2\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

@test "manifest: marketplace entry version matches plugin.json" {
  v="$(jq -r '.version' "$MANIFEST")"
  m="$(jq -r '.plugins[] | select(.name == "dev-workflow") | .version' "$MARKETPLACE")"
  [ "$m" = "$v" ]
}

@test "skill: keeps the 6-step skeleton of the flatmate original" {
  grep -qF '### 1. 前提を揃える' "$SKILL"
  grep -qF '### 2. レビュー' "$SKILL"
  grep -qF '### 3. リスク宣言' "$SKILL"
  grep -qF '### 4. 動作確認' "$SKILL"
  grep -qF '### 5. 合格処理' "$SKILL"
  grep -qF '### 6. 保留処理' "$SKILL"
}

@test "skill: keeps the label vocabulary" {
  grep -qF 'agent-review:passed' "$SKILL"
  grep -qF 'agent-review:pending' "$SKILL"
  grep -qF 'agent-review:failed' "$SKILL"
  grep -qF 'needs-approval' "$SKILL"
}

@test "skill: keeps fail-closed principle with HEAD SHA verification" {
  grep -q 'fail-closed' "$SKILL"
  grep -qF 'HEAD_SHA' "$SKILL"
  # 宣言・証拠コメントの実在を API で実測してから passed を付ける規定
  grep -qF '.head.sha' "$SKILL"
}

# --- Requirement: スキルはリポ非依存で、flatmate 固有の仕組みには条件分岐で対応する ---

@test "portability: no hardcoded flatmate repo URL" {
  ! grep -q 'genetta-inc/flatmate' "$SKILL"
}

@test "portability: no reference to flatmate-only machinery" {
  ! grep -q 'pending-mirror\.sh' "$SKILL"
  ! grep -q 'pending-owner\.md' "$SKILL"
  ! grep -q 'channel-reply-policy' "$SKILL"
  ! grep -q 'agent-loop-steps\.md' "$SKILL"
}

@test "portability: degraded behavior for repos without auto-merge is specified" {
  grep -q '未配備' "$SKILL"
}

@test "portability: direct merge by LLM remains forbidden" {
  # gh pr merge / merge API の直叩き禁止が明文化されている
  grep -q 'gh pr merge' "$SKILL"
  grep -q '禁止' "$SKILL"
}

# --- Requirement: flatmate issue #240 の収束ルールが織り込まれている ---

@test "convergence: two-round cap with high-severity-only third round" {
  grep -q '2周' "$SKILL"
  grep -q '高深刻度' "$SKILL"
}

@test "convergence: re-review is diff-limited, new findings go to follow-up issues" {
  grep -q '差分' "$SKILL"
  grep -q 'follow-up issue' "$SKILL"
}

@test "convergence: mergeable-after fixes are not blocking" {
  grep -qF 'マージ後に issue で直せるものは blocking にしない' "$SKILL"
}

@test "convergence: risk-acceptance link authenticity check with gh api author probe" {
  grep -q '真正性' "$SKILL"
  grep -qF '.user.login' "$SKILL"
}

@test "convergence: verification runs in parallel while awaiting risk acceptance" {
  grep -q '並行' "$SKILL"
}

# --- Requirement: レビュー実行者を変更内容から事前判定する（light / full） ---

@test "triage: review weight section exists at the head of step 2" {
  grep -qF 'レビュー重量の判定' "$SKILL"
  # 手順2（レビュー）の中にあること — 手順3 より前に現れる
  triage="$(grep -n 'レビュー重量の判定' "$SKILL" | head -1 | cut -d: -f1)"
  step2="$(grep -n '^### 2\. レビュー' "$SKILL" | head -1 | cut -d: -f1)"
  step3="$(grep -n '^### 3\. リスク宣言' "$SKILL" | head -1 | cut -d: -f1)"
  [ "$triage" -gt "$step2" ]
  [ "$triage" -lt "$step3" ]
}

@test "triage: decision inputs are mechanical (file list + changed line count)" {
  grep -qF 'gh pr diff' "$SKILL"
  grep -qF -- '--name-only' "$SKILL"
  grep -q '行数' "$SKILL"
}

@test "triage: light condition (a) excludes agent-behavior-defining files" {
  # 「md だけ」では light にならない — エージェントの行動を定義する md は full 側
  grep -qF 'エージェントの行動を定義するファイル' "$SKILL"
  grep -qF 'CLAUDE.md' "$SKILL"
  grep -qF '.github/workflows/' "$SKILL"
}

@test "triage: light condition (b) caps at 30 changed lines and requires behavior-neutral" {
  grep -qF '30 行' "$SKILL"
  grep -q '挙動を変えない' "$SKILL"
}

@test "triage: full is the default and ties break toward full (fail-closed)" {
  grep -q '既定.*full\|full.*既定' "$SKILL"
  grep -qF '迷ったら full' "$SKILL"
  grep -qF '「判断がつかない」は light の理由にならない' "$SKILL"
}

@test "triage: light swaps only the reviewer, exempts no gate step" {
  # 免除されない工程が名指しで列挙されている
  grep -q 'light.*変わるのは.*実行者\|レビュー実行者だけ' "$SKILL"
  grep -q '免除' "$SKILL"
}

@test "triage: decision and reason are recorded as a PR comment" {
  grep -qF 'レビュー重量: light' "$SKILL"
}

@test "triage: pre-triage and availability fallback are distinguished, fallback kept" {
  # 既存のフォールバック記述（Codex が使えないときの迂回路）が残っている（回帰ガード）
  grep -q 'フォールバック' "$SKILL"
  grep -q 'サブスク切れ' "$SKILL"
  grep -q 'タイムアウト' "$SKILL"
  # 事前判定と障害時フォールバックの役割が書き分けられている
  grep -q '事前判定' "$SKILL"
}

@test "manifest: version bumped above 1.7.0" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$v" != "1.7.0" ]
  highest="$(printf '1.7.0\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

@test "skill: frontmatter version bumped above 1.0.0" {
  v="$(awk -F': ' '/^version:/{print $2; exit}' "$SKILL")"
  [ -n "$v" ]
  [ "$v" != "1.0.0" ]
  highest="$(printf '1.0.0\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

# --- Requirement: 実装とドキュメント文字列の整合を合格の必須条件にする（issue #166） ---

@test "doc-consistency: step 4 is split into 4-1 behavior check and 4-2 doc-string check" {
  grep -qF '#### 4-1' "$SKILL"
  grep -qF '#### 4-2' "$SKILL"
  grep -qF 'ドキュメント文字列の整合確認' "$SKILL"
}

@test "doc-consistency: 4-2 is stated as a required condition for passing" {
  # 合格（手順5）の必須条件であることが明記されている
  grep -q '4-2.*必須\|必須.*4-2\|ドキュメント文字列の整合確認（必須）' "$SKILL"
}

@test "doc-consistency: the four kinds of doc strings are named" {
  grep -qF 'JSDoc' "$SKILL"
  grep -qF 'usage' "$SKILL"
  grep -qF 'README' "$SKILL"
  grep -qF 'エラーメッセージ' "$SKILL"
}

@test "doc-consistency: concrete git grep commands are given, not hand-waving" {
  grep -qF 'git grep -n' "$SKILL"
  # フラグ名・関数名・既定値を説明する語、の3系統の例が揃っている
  [ "$(grep -c 'git grep -n' "$SKILL")" -ge 3 ]
  grep -qF 'gh pr diff' "$SKILL"
}

@test "doc-consistency: zero hits must be recorded, blanks are forbidden" {
  grep -qF '0 件' "$SKILL"
  grep -qF '確認していないものを空欄にしない' "$SKILL"
}

@test "doc-consistency: evidence comment has its own heading and HEAD SHA line" {
  grep -qF '## ドキュメント文字列の整合確認' "$SKILL"
  # 証拠コメントのテンプレに 対象 HEAD 行がある（既存の宣言・動作確認と同形式）
  [ "$(grep -c '^対象 HEAD: ' "$SKILL")" -ge 3 ]
}

@test "doc-consistency: step 5 measures three headings, not two" {
  grep -qF 'ドキュメント文字列の整合確認の3つの見出しがすべて' "$SKILL"
  grep -qF '1つでも欠けていれば' "$SKILL"
  # 旧文言（2見出し前提）が残っていない
  ! grep -qF '動作確認の見出しが両方' "$SKILL"
}

@test "doc-consistency: deferring the mismatch to a follow-up issue is forbidden" {
  grep -q '先送り' "$SKILL"
  # 「やらないこと」節に整合確認スキップの禁止が入っている
  awk '/^\*\*やらないこと\*\*/,0' "$SKILL" | grep -qF 'ドキュメント文字列の整合確認'
}

@test "doc-consistency: existing mandatory steps are not removed (regression guard)" {
  # 既存の必須ステップが1つも消えていない
  grep -qF 'stale な `agent-review:passed` を必ず外す' "$SKILL"
  grep -qF '実装したコンテキストで自己レビューしない' "$SKILL"
  grep -qF '## リスク宣言' "$SKILL"
  grep -qF '## 動作確認' "$SKILL"
  grep -qF '真正性確認' "$SKILL"
  grep -qF 'agent-review:passed' "$SKILL"
}

@test "manifest: version bumped above 1.10.1" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$v" != "1.10.1" ]
  highest="$(printf '1.10.1\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

@test "skill: frontmatter version bumped above 1.2.0" {
  v="$(awk -F': ' '/^version:/{print $2; exit}' "$SKILL")"
  [ -n "$v" ]
  [ "$v" != "1.2.0" ]
  highest="$(printf '1.2.0\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

# --- Requirement: ゲートの必須条件を説明する文字列を全箇所そろって更新する（PR #174 レビュー指摘） ---

@test "gate-description: every user-facing description enumerates all required conditions" {
  # ゲートの合格必須条件（この列挙が正本）。条件を1つ足したら、下の5か所すべての
  # 説明文を同じ PR の中で更新しないとこのテストが落ちる。
  # 「実装は締めたが説明文だけ旧条件のまま取り残される」再発を機械的に止めるためのガード。
  required_conditions="リスク宣言
動作確認
ドキュメント文字列の整合確認
agent-review:passed"

  DEV_README="${PLUGIN_DIR}/README.md"
  AUTOMERGE_README="${PLUGIN_DIR}/templates/auto-merge/README.md"

  # 説明文の在り処（利用者・エージェントがゲートの合格条件を読む場所）。
  # 抽出パターンはすべて ASCII アンカーにする（macOS awk のマルチバイト比較を避けるため）。
  extract_skill_description() { grep '^description: ' "$SKILL"; }
  extract_plugin_description() { jq -r '.description' "$MANIFEST"; }
  extract_marketplace_description() {
    jq -r '.plugins[] | select(.name == "dev-workflow") | .description' "$MARKETPLACE"
  }
  extract_dev_readme_section() {
    awk '/^### pr-review-gate$/ { f = 1; next } /^### / { if (f) exit } f' "$DEV_README"
  }
  extract_automerge_readme_section() {
    awk '/^pr-review-gate/ { f = 1 } f && NF == 0 { exit } f' "$AUTOMERGE_README"
  }

  failures=""
  for location in skill_description plugin_description marketplace_description \
                  dev_readme_section automerge_readme_section; do
    body="$("extract_${location}")"
    [ -n "$body" ] || { failures="${failures}${location}: 説明文を抽出できなかった"$'\n'; continue; }
    while IFS= read -r condition; do
      printf '%s' "$body" | grep -qF "$condition" \
        || failures="${failures}${location}: 「${condition}」が抜けている"$'\n'
    done <<< "$required_conditions"
  done

  [ -z "$failures" ] || { printf '%s' "$failures" >&2; false; }
}
