#!/usr/bin/env bats
#
# develop スキル（本体＝オーケストレータ）の構造検証（issue #203）
#
# SKILL.md は実行コードではないため、規定（いつ使うか・本体の禁止事項・入口 0・
# 1 ループ・モデル・実行モード・前提・エピック）の記述が存在することを文書アサーションで検証する。
# 節ごとに切り出してから grep し、他節の既存文で偽合格しないようにする。
#
# spec: dev-workflow-develop, dev-workflow-execution-strategy (REMOVED), dev-workflow-escalation-tripwires

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL_DIR="${PLUGIN_DIR}/skills/develop"
  SKILL="${SKILL_DIR}/SKILL.md"
  TRIPWIRES="${PLUGIN_DIR}/templates/escalation-tripwires.md"
}

# 「## <見出し>」から次の「## 」までを切り出す
section() { awk -v h="## $1" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$SKILL"; }
frontmatter() { awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$SKILL"; }

# --- 存在・frontmatter ---

@test "skill: develop SKILL.md exists and the old issue-only skill dir is gone" {
  [ -f "$SKILL" ]
  [ ! -e "${PLUGIN_DIR}/skills/github-""issue" ]
}

@test "frontmatter: name is develop and version is at least 2.0.0" {
  frontmatter | grep -q '^name: develop$'
  v="$(frontmatter | awk -F': ' '/^version:/{print $2; exit}')"
  [ -n "$v" ]
  printf '2.0.0\n%s\n' "$v" | sort -V -C
}

@test "frontmatter: description carries the old issue trigger words" {
  d="$(frontmatter | awk '/^description:/{print; exit}')"
  echo "$d" | grep -q 'issue 番号'
  echo "$d" | grep -q 'URL'
  echo "$d" | grep -q 'この issue 対応して'
}

@test "frontmatter: description says the skill is mandatory for code/skill/command/normative changes" {
  d="$(frontmatter | awk '/^description:/{print; exit}')"
  echo "$d" | grep -q '規範文書'
  echo "$d" | grep -q '必ず'
}

# --- いつ使うか ---

@test "when-to-use: entry-agnostic with the read-only exception" {
  section 'いつ使うか' | grep -q '入口を問わず'
  section 'いつ使うか' | grep -q '規範文書'
  section 'いつ使うか' | grep -q '読むだけ'
  section 'いつ使うか' | grep -q '回答だけ'
  section 'いつ使うか' | grep -q '生成物'
}

# --- 本体の役割 ---

@test "orchestrator: main never edits code nor performs reviews itself" {
  section '本体の役割' | grep -q 'Edit でコードを書かない'
  section '本体の役割' | grep -qE 'レビュー.*代行しない'
  section '本体の役割' | grep -q '`model`'
  section '本体の役割' | grep -qE 'W / R1 / G|W・R1・G'
}

@test "orchestrator: decides the next role from return summaries and record-target comments/labels" {
  section '本体の役割' | grep -q 'return'
  section '本体の役割' | grep -qE '記録先.*(コメント|ラベル)'
}

# --- 入口 0 ---

@test "entry-0: issue if present, otherwise Draft PR before the spec decision" {
  section '入口 0' | grep -q 'issue があれば'
  section '入口 0' | grep -q 'git commit --allow-empty'
  section '入口 0' | grep -q 'gh pr create --draft'
  section '入口 0' | grep -qE '仕様化判断.*(前|先)'
}

@test "entry-0: acceptance criteria go to the PR body and no issue reference in the PR body" {
  section '入口 0' | grep -qE '受け入れ条件.*PR 本文'
  section '入口 0' | grep -q 'Closes'
  section '入口 0' | grep -qE '(Closes|Refs).*(書かない|書いてはならない)'
}

@test "entry-0: issues are opened only for epics, unmanned queues, or recorded discussions" {
  section '入口 0' | grep -q 'エピック'
  section '入口 0' | grep -q '無人キュー'
  section '入口 0' | grep -q '議論'
}

@test "entry-0: decision and review result live in record-target comments; the spec declaration always goes to a PR comment" {
  # 記録先のコメントに置くのは仕様化判断と仕様レビュー結果
  section '入口 0' | grep -qF '仕様化判断: する|しない'
  section '入口 0' | grep -qF '仕様レビュー: APPROVE|REQUEST_CHANGES'
  section '入口 0' | grep -F '仕様化判断: する|しない' | grep -q '記録先のコメント'
  # 仕様宣言は記録先ではなく PR コメント（issue #212。pr-review-gate 手順 3-b / 5 と worker.md が正）:
  # 節内で仕様宣言に触れる行はすべて 'PR コメント' を含む（冒頭文の「…仕様宣言を置く「記録先」」の再発もここで落ちる）
  section '入口 0' | grep -q '仕様宣言'
  [ -z "$(section '入口 0' | grep '仕様宣言' | grep -v 'PR コメント')" ]
}

# --- worktree ---

@test "worktree: main prepares it (isolation worktree) and W never creates one" {
  grep -qF 'isolation: "worktree"' "$SKILL"
  grep -qE 'W は.*worktree を(切らない|作らない)' "$SKILL"
}

# --- 1 ループ ---

@test "loop: stages 0-4 run in W -> R1 -> W -> G order" {
  loop="$(section '1 ループ')"
  s0="$(echo "$loop" | grep -n '(0)' | head -1 | cut -d: -f1)"
  s1="$(echo "$loop" | grep -n '(1)' | head -1 | cut -d: -f1)"
  s2="$(echo "$loop" | grep -n '(2)' | head -1 | cut -d: -f1)"
  s3="$(echo "$loop" | grep -n '(3)' | head -1 | cut -d: -f1)"
  s4="$(echo "$loop" | grep -n '(4)' | head -1 | cut -d: -f1)"
  [ -n "$s0" ] && [ -n "$s1" ] && [ -n "$s2" ] && [ -n "$s3" ] && [ -n "$s4" ]
  [ "$s0" -lt "$s1" ] && [ "$s1" -lt "$s2" ] && [ "$s2" -lt "$s3" ] && [ "$s3" -lt "$s4" ]
  echo "$loop" | sed -n "${s1},${s2}p" | grep -q 'W'
  echo "$loop" | sed -n "${s2},${s3}p" | grep -q 'R1'
  echo "$loop" | sed -n "${s3},${s4}p" | grep -q 'W'
  echo "$loop" | sed -n "${s4},\$p" | grep -q 'G'
}

@test "loop: W does spec decision, split judgement and /opsx:ff, then R1 reviews before apply" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -q '仕様化判断'
  echo "$loop" | grep -q '/opsx:ff'
  ff="$(echo "$loop" | grep -n '/opsx:ff' | head -1 | cut -d: -f1)"
  rev="$(echo "$loop" | grep -n '仕様レビュー' | head -1 | cut -d: -f1)"
  apply="$(echo "$loop" | grep -n 'apply' | head -1 | cut -d: -f1)"
  [ "$ff" -lt "$rev" ] && [ "$rev" -lt "$apply" ]
  echo "$loop" | grep -qE '仕様化しない.*\(3\)'
}

@test "loop: R1 and G both have a two-round cap and needs-approval afterwards" {
  loop="$(section '1 ループ')"
  [ "$(echo "$loop" | grep -cE '2 ?周')" -ge 2 ]
  echo "$loop" | grep -q 'needs-approval'
}

@test "loop: G failed raises only the cause side (never W to fable) then resumes W and G" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -qE 'failed.*原因分類'
  echo "$loop" | grep -qF '実装品質起因のときだけ'
  echo "$loop" | grep -qF '一方だけ'
  echo "$loop" | grep -qF 'dev-workflow:decider'
  echo "$loop" | grep -qF 'W を fable にはしない'
  echo "$loop" | grep -qE 'W を再開'
  echo "$loop" | grep -qE 'G を再開'
}

@test "loop: W is spawned by name, resumed via SendMessage, and never needs grandchildren" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -q '名前付き'
  echo "$loop" | grep -q 'SendMessage'
  echo "$loop" | grep -q '孫'
}

@test "loop: W's second run covers apply(TDD), verify, archive, PR Ready and the spec declaration" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -q 'TDD'
  echo "$loop" | grep -q 'verify'
  echo "$loop" | grep -q 'archive'
  echo "$loop" | grep -q 'Ready'
  echo "$loop" | grep -q '仕様宣言'
}

# (3) を (3a) 実装＋verify / (3b) archive＋PR＋仕様宣言 の 2 回の return に分ける（#262）。
# 本体がコンテキスト量を測れるのは W を再開する直前だけなので、return の区切りの数が計測点の数になる。
@test "loop: stage 3 splits into (3a) implement+verify and (3b) archive+PR+spec declaration" {
  loop="$(section '1 ループ')"
  a="$(echo "$loop" | grep -n '(3a)' | head -1 | cut -d: -f1)"
  b="$(echo "$loop" | grep -n '(3b)' | head -1 | cut -d: -f1)"
  s4="$(echo "$loop" | grep -n '(4)' | head -1 | cut -d: -f1)"
  [ -n "$a" ] || { echo "no (3a) in the loop block"; return 1; }
  [ -n "$b" ] || { echo "no (3b) in the loop block"; return 1; }
  [ -n "$s4" ]
  [ "$a" -lt "$b" ] && [ "$b" -lt "$s4" ]
  sega="$(echo "$loop" | sed -n "${a},$((b - 1))p")"
  echo "$sega" | grep -q 'TDD'
  echo "$sega" | grep -q 'verify'
  echo "$sega" | grep -qF '工程完了: 実装＋verify'
  ! echo "$sega" | grep -q 'archive'
  segb="$(echo "$loop" | sed -n "${b},$((s4 - 1))p")"
  echo "$segb" | grep -q 'archive'
  echo "$segb" | grep -q 'Ready'
  echo "$segb" | grep -q '仕様宣言'
  echo "$segb" | grep -qF '工程完了: archive＋PR＋仕様宣言'
}

@test "loop: main measures between (3a) and (3b) and defers the cap handling to decision-criteria.md" {
  loop="$(section '1 ループ')"
  s3="$(echo "$loop" | grep -n '(3)' | head -1 | cut -d: -f1)"
  s4="$(echo "$loop" | grep -n '(4)' | head -1 | cut -d: -f1)"
  seg="$(echo "$loop" | sed -n "${s3},$((s4 - 1))p")"
  a="$(echo "$seg" | grep -n '(3a)' | head -1 | cut -d: -f1)"
  b="$(echo "$seg" | grep -n '(3b)' | head -1 | cut -d: -f1)"
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]
  # (3a) の return と (3b) の指示のあいだに計測がある
  echo "$seg" | sed -n "${a},$((b - 1))p" | grep -q 'subagent-context.sh'
  # 閾値・環境変数名は再掲せず正本を指す（正本は decision-criteria.md「コンテキスト上限」）
  echo "$seg" | grep -q 'decision-criteria.md'
  echo "$seg" | grep -q 'コンテキスト上限'
  ! echo "$seg" | grep -q 'DEV_WORKFLOW_CONTEXT_CAP'
  ! echo "$seg" | grep -qE '150000|150K|220000'
  # (3a)/(3b) より細かく切らないこと
  echo "$seg" | grep -q 'これより細かく'
}

# 旧世代の W（古いキャッシュの worker.md を読んだ W）が (3) を通しで終えて返してきたとき、
# 本体が (3b) を再指示して PR Ready と仕様宣言を二重に走らせないための工程ルーティング。
@test "loop: main routes stage 3 by what it instructed, not by matching the stage name string" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -qF '工程名の文字列照合では決めない'
  echo "$loop" | grep -qF '(3b) を指示せず'
}

# --- モデル ---

@test "model: W defaults to sonnet and is capped at opus; R1 opus, G sonnet; fable only via the decider type" {
  m="$(section 'モデル')"
  echo "$m" | grep -qE '^\| W（実行役） \| `sonnet` \|'
  echo "$m" | grep -qE 'W.*`opus`'
  echo "$m" | grep -qE '^\| R1（読んで判断する役） \| `opus` \|'
  echo "$m" | grep -qE '^\| G \| `sonnet` \|'
  ! echo "$m" | grep -qE 'マージ条件・聖域・層間契約'
  echo "$m" | grep -q '事前分類'
  echo "$m" | grep -q 'マージ条件'
  echo "$m" | grep -q '聖域'
  echo "$m" | grep -q '層間契約'
  # W を fable にする行は無く、fable は決める役の種別だけ
  echo "$m" | grep -qF 'W の上限は `opus`'
  echo "$m" | grep -qF 'dev-workflow:decider'
  echo "$m" | grep -qF 'agent-model-guard.sh'
}

@test "model: reserve only for automatic runs, exhausted caps every path at opus" {
  m="$(section 'モデル')"
  echo "$m" | grep -qE 'reserve.*自動実行'
  echo "$m" | grep -qE 'exhausted.*全経路'
  echo "$m" | grep -q 'FABLE_BUDGET_MODE'
  echo "$m" | grep -q 'references/decision-criteria.md'
}

@test "model: the escalation tripwire survives as a one-side-only ladder" {
  m="$(section 'モデル')"
  echo "$m" | grep -q '2 連続'
  echo "$m" | grep -qF 'どちらか一方だけ'
  echo "$m" | grep -qF '両方同時に上げない'
  echo "$m" | grep -qF 'dev-workflow:decider'
}

@test "model: shared budget mode sets the floor and abundant no longer lifts W" {
  m="$(section 'モデル')"
  echo "$m" | grep -q 'SHARED_BUDGET_MODE'
  echo "$m" | grep -qE 'throttled.*`sonnet`'
  echo "$m" | grep -qE 'depleted.*`sonnet`'
  echo "$m" | grep -q 'どの役割の既定も上げない'
}

@test "model: G defaults to sonnet and every pre-classification lifts W only to opus" {
  m="$(section 'モデル')"
  echo "$m" | grep -qE '^\| G \| `sonnet` \|'
  echo "$m" | grep -qE '^\| R1（読んで判断する役） \| `opus` \|'
  echo "$m" | grep -q '聖域パス'
  echo "$m" | grep -qE 'マージ権限・層間契約・課金/法務'
}

@test "loop: W and G are measured with subagent-context.sh before every SendMessage resume" {
  loop="$(section '1 ループ（W → R1 → W → G）')"
  echo "$loop" | grep -q 'subagent-context.sh'
  echo "$loop" | grep -q '手渡し'
  # 閾値と環境変数名の正本は decision-criteria.md「コンテキスト上限」1 箇所（#261）。
  # ここでは再掲ではなく、その正本を指していることを固定する
  echo "$loop" | grep -q 'decision-criteria.md'
  echo "$loop" | grep -q 'コンテキスト上限'
  ! echo "$loop" | grep -q 'DEV_WORKFLOW_CONTEXT_CAP'
  echo "$loop" | grep -q 'G の再開も同じ'
}

@test "model: no execution-strategy branches nor deterministic signal commands anywhere under develop" {
  ! grep -rq 'delegate+verify' "$SKILL_DIR"
  ! grep -rq 'workflow 型' "$SKILL_DIR"
  ! grep -rqE '4 ?象限' "$SKILL_DIR"
  ! grep -rq '決定論的シグナル' "$SKILL_DIR"
  ! grep -rq 'self-contained' "$SKILL_DIR"
  ! grep -rqF '| length' "$SKILL_DIR"
  ! grep -rqF "startswith(\"size:\")" "$SKILL_DIR"
}

# --- 実行モード ---

@test "mode table: unmanned main is the orchestrator, runs (0)-(3), W adds Draft PR + pending, G left to Step 1" {
  t="$(section '実行モード')"
  echo "$t" | grep -q 'interactive'
  echo "$t" | grep -q 'unmanned'
  echo "$t" | grep -q '憲法のメイン'
  echo "$t" | grep -qE 'W / R1.*spawn|W と R1.*spawn'
  echo "$t" | grep -qE '\(0\).*\(3\)'
  echo "$t" | grep -q 'Draft PR'
  echo "$t" | grep -q 'agent-review:pending'
  echo "$t" | grep -qE 'G.*Step 1'
}

@test "mode table: spec decision record and spec review are not exempt in unmanned" {
  t="$(section '実行モード')"
  echo "$t" | grep -qE '(仕様化判断|判定の記録).*免除しない'
  echo "$t" | grep -qE '仕様レビュー.*免除しない|免除しない.*仕様レビュー'
  echo "$t" | grep -q 'blocked_by'
}

# --- 前提 ---

@test "prerequisites: Agent / SendMessage / gh / opsx-or-openspec / Codex with their degraded paths" {
  p="$(section '前提')"
  echo "$p" | grep -q 'Agent'
  echo "$p" | grep -q '`model`'
  echo "$p" | grep -q '名前付き'
  echo "$p" | grep -qF 'isolation: "worktree"'
  echo "$p" | grep -q 'SendMessage'
  echo "$p" | grep -q '`gh`'
  echo "$p" | grep -q 'dependencies'
  echo "$p" | grep -q 'opsx'
  echo "$p" | grep -q 'openspec'
  echo "$p" | grep -q 'Codex'
  echo "$p" | grep -q 'needs-reviewer'
}

# --- エピック ---

@test "epic: four subsections exist (conditions / how to create / how to run / completion)" {
  e="$(section 'エピックの扱い')"
  echo "$e" | grep -q '^### 条件'
  echo "$e" | grep -q '^### 作り方'
  echo "$e" | grep -q '^### 回し方'
  echo "$e" | grep -q '^### 完了条件'
}

@test "epic: conditions name 2+ PRs, multiple capabilities, or ordered children" {
  e="$(section 'エピックの扱い')"
  echo "$e" | grep -qE '2 本以上'
  echo "$e" | grep -q 'capability'
  echo "$e" | grep -q '順序依存'
}

@test "epic: creation binds Closes to children and wires dependencies via blocked_by" {
  e="$(section 'エピックの扱い')"
  echo "$e" | grep -q 'Closes'
  echo "$e" | grep -q 'dependencies/blocked_by'
  echo "$e" | grep -q '/develop <エピック番号>'
}

@test "epic: children run in parallel in isolated worktrees, new problems become new child issues" {
  e="$(section 'エピックの扱い')"
  echo "$e" | grep -q '並列'
  echo "$e" | grep -qF 'isolation: "worktree"'
  echo "$e" | grep -q '新しい子 issue'
  echo "$e" | grep -qE 'スタック'
}

@test "epic: completion needs the epic's own verification, not just all children merged" {
  e="$(section 'エピックの扱い')"
  echo "$e" | grep -q '閉じない'
  echo "$e" | grep -qE '証拠.*エピック'
}

# --- 上流の壁打ち（旧 longrun:plan。#205 で /opsx:explore に） ---

@test "upstream brainstorming (opsx:explore) is explicitly not called from develop" {
  grep -q '^## 上流の壁打ち' "$SKILL"
  grep -q 'opsx:explore' "$SKILL"
  ! grep -q 'longrun' "$SKILL"
  ! grep -qF '/lr:' "$SKILL"
}

# --- 昇格トリップワイヤーのテンプレート（1.6b。hook 出力を検査する tripwire-hook.bats には混ぜない） ---

@test "tripwire template: wire 4 is the context cap handoff and wire 5 is the rate-limit reactive downgrade" {
  grep -qE '^4\. 【コンテキスト上限 → 手渡し】' "$TRIPWIRES"
  grep -qE '^5\. 【rate-limit 実エラー → reactive 降格】' "$TRIPWIRES"
  ! grep -qE '^6\. ' "$TRIPWIRES"
  w4="$(awk '/^4\. /{f=1} /^5\. /{f=0} f' "$TRIPWIRES")"
  echo "$w4" | grep -q 'subagent-context.sh'
  # 閾値の再掲ではなく正本を指す（#261）。あわせて途中計測 hook の経路に触れていること
  echo "$w4" | grep -q 'decision-criteria.md'
  echo "$w4" | grep -q 'context-tripwire.sh'
  ! echo "$w4" | grep -q 'DEV_WORKFLOW_CONTEXT_CAP'
  echo "$w4" | grep -q 'モデルは変えない'
}

@test "tripwire template: wire 1 routes to return-to-main split or native Workflow execution, keeps heading and five wires" {
  grep -q '^## 昇格トリップワイヤー' "$TRIPWIRES"
  w1="$(awk '/^1\. /{f=1} /^2\. /{f=0} f' "$TRIPWIRES")"
  echo "$w1" | grep -q '規模超過'
  echo "$w1" | grep -q '本体に return'
  echo "$w1" | grep -q 'エピック化'
  echo "$w1" | grep -q 'workflow-execution.md'
  ! echo "$w1" | grep -q 'workflow 型へ'
  ! grep -qF '/lr:' "$TRIPWIRES"
  grep -q '失敗ループ' "$TRIPWIRES"
  grep -q '仕様の発明' "$TRIPWIRES"
  w3="$(awk '/^3\. /{f=1} /^4\. /{f=0} f' "$TRIPWIRES")"
  echo "$w3" | grep -q 'opsx:explore'
  [ "$(grep -cE '^[1-4]\. 【' "$TRIPWIRES")" -eq 4 ]
}

@test "tripwire template: unmanned wiring names the flatmate-owned constitution, not a loops template" {
  grep -q 'docs/agent-loop.md' "$TRIPWIRES"
  ! grep -q 'loop-dev-agent-tripwires' "$TRIPWIRES"
  ! grep -q 'loops プラグイン' "$TRIPWIRES"
}
