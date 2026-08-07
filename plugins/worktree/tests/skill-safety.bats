#!/usr/bin/env bats
#
# Tests for change-4 (worktree-command-dedup) — SKILL.md safety preservation.
# spec: worktree-command-wrapper (S9, S10).
#
# The SKILL.md is the single source of truth. These tests guard that the
# safety-critical wording (squash detection A/B/C, "prefer the real tree diff",
# SQUASHED handling, and the AskUserQuestion separate-turn absolute prohibition)
# is preserved verbatim and not lost by this change.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- S9: squash detection A/B/C stays in SKILL.md verbatim ---

@test "skill: wt-clean SKILL.md keeps kensho A tree-diff verification" {
  grep -q '検証A' "$WT_CLEAN_SKILL"
  grep -q 'TREE_DIFF' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps kensho B git cherry verification" {
  grep -q '検証B' "$WT_CLEAN_SKILL"
  grep -q 'git cherry' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps kensho C gh pr MERGED verification" {
  grep -q '検証C' "$WT_CLEAN_SKILL"
  grep -q 'gh pr list' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md prefers the real tree diff when verdicts differ" {
  grep -q '実ツリー差分（検証A）を優先' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps SQUASHED not-red rule" {
  grep -q 'SQUASHED' "$WT_CLEAN_SKILL"
  # squash 済み（SQUASHED 非空）は AHEAD_COUNT>0 でも 🔴 にしない
  grep -q 'AHEAD_COUNT > 0.*でも 🔴 にしない' "$WT_CLEAN_SKILL"
}

# --- S10: AskUserQuestion separate-turn absolute prohibition stays in SKILL.md ---

@test "skill: wt-clean SKILL.md keeps AskUserQuestion same-turn parallel prohibition" {
  grep -q '同一ターンの並列ツール呼び出しに含めてはならない' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps 'execute in a separate turn after answer'" {
  # 規範自体は SKILL.md に残っているが、文面が「回答を**受け取った後の別ターン**で」に
  # 書き換わって固定文字列 grep が空振りしていた。装飾（** **）と読点の有無に依存しない
  # 正規表現に変更する。守りたいのは「回答を受け取ってから別ターンで実行する」の明記。
  grep -Eq '回答を\*{0,2}受け取った後の、?\*{0,2}別(の)?(アシスタント)?ターン' "$WT_CLEAN_SKILL"
}

# --- issue #87: unattended mode must not enter the Pass 2 interactive branch ---

@test "skill: unattended mode never calls AskUserQuestion" {
  # 無人モードは cron から人間の目が入らずに走る。Pass 2 の対話分岐に入らないことが
  # 「進行中セッションの worktree を無人で消す経路を作らない」ための前提になる。
  grep -q '`--unattended` 実行中に \*\*`AskUserQuestion` を呼んではならない\*\*' "$WT_CLEAN_SKILL"
}

@test "skill: unattended mode does not run the Pass 2 destructive branches" {
  grep -q 'Pass 2 の破壊分岐（dirty 破棄・🔴 破棄削除・🔴 マージ）を\*\*実行してはならない\*\*' "$WT_CLEAN_SKILL"
}

@test "skill: unattended mode is a route around the prohibitions, not a relaxation" {
  # 禁則を緩めるのではなく、禁則対象の分岐に入らないルートを足す設計であること。
  grep -q '`--unattended` はこの区分を緩めない' "$WT_CLEAN_SKILL"
  grep -q '到達しないルート' "$WT_CLEAN_SKILL"
}

@test "skill: unattended mode still honours the active-session guard (#77)" {
  # #87 は #77 をブロッカーとして待っていた。無人モードでガードが緩むと意味がない。
  grep -q '禁則 3（稼働シグナル）のガードを\*\*無人だからといって緩めてはならない\*\*' "$WT_CLEAN_SKILL"
}

@test "skill: Pass 2 section routes unattended runs away from AskUserQuestion" {
  awk '/^#### Step B Pass 2/,/^### Step C/' "$WT_CLEAN_SKILL" \
    | grep -q '`--unattended` ならここで打ち切る'
}

# --- wt-setup SKILL.md keeps Step 1-6 (the source of truth for setup) ---

@test "skill: wt-setup SKILL.md keeps the setup script invocation" {
  grep -q 'wt-setup.sh' "$WT_SETUP_SKILL"
}

@test "skill: wt-setup SKILL.md keeps the Draft PR bootstrap" {
  grep -q 'gh pr create' "$WT_SETUP_SKILL"
}
