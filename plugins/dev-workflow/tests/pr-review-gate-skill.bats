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
