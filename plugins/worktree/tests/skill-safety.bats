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

# 旧テストは「検証が割れたら実ツリー差分（検証A）を優先」を要求していた。
# その規則こそが 2026-08-10 の誤判定の一因（検証A にパスフィルタが掛かっており、
# Markdown 中心のリポジトリでは差分が常に空＝常にマージ済みになった）ため、
# 「検査が失敗したらマージ済み側に倒れない」という fail-closed の検証に置き換える。
@test "skill: squash detection takes no path filter on the real tree diff" {
  # 全 tracked ファイル対象であること
  grep -q 'git -C "$MAIN_REPO" diff "$MAIN_BRANCH" "$BRANCH_NAME" --stat 2>/dev/null' "$WT_CLEAN_SKILL"
  # 言語別フィルタが復活していないこと
  ! grep -q "diff \"\$MAIN_BRANCH\" \"\$BRANCH_NAME\" --stat -- " "$WT_CLEAN_SKILL"
  grep -q 'パスフィルタを掛けてはならない' "$WT_CLEAN_SKILL"
}

@test "skill: an OPEN pull request vetoes automatic deletion" {
  grep -q 'PR が OPEN（レビュー中の作業）' "$WT_CLEAN_SKILL"
  grep -q 'PR_OPEN' "$WT_CLEAN_SKILL"
}

@test "skill: unknown PR state fails closed (never treated as merged)" {
  grep -q 'PR 状態を確認できない' "$WT_CLEAN_SKILL"
  grep -q 'PR_STATE' "$WT_CLEAN_SKILL"
}

@test "skill: gh is not piped into grep -c (its exit code must be observable)" {
  # `gh ... | grep -c` はパイプ末尾の grep の終了コードになり gh の失敗を隠す
  ! grep -Eq 'gh pr list[^|]*\| *grep -c' "$WT_CLEAN_SKILL"
}

@test "skill: a merged PR is only trusted when its headRefOid matches the branch tip" {
  grep -q 'headRefOid' "$WT_CLEAN_SKILL"
  grep -q 'PR_MERGED_AT_HEAD' "$WT_CLEAN_SKILL"
}

@test "skill: the tree-diff asymmetry is documented" {
  # 「差分が空」は削除可の十分条件だが、「差分がある」は未マージの証明にならない
  grep -q '非対称' "$WT_CLEAN_SKILL"
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
  # 書き換わって固定文字列 grep が空振りしていた。守りたいのは「回答を受け取ってから
  # 別ターンで実行する」の明記なので、装飾（** **）と読点の有無には依存させない。
  #
  # ただし ERE の回数指定（`\*{0,2}` / `、?`）を多バイト文字の隣に置くと、macOS の
  # BSD grep（/usr/bin/grep。bats は /bin/bash 経由で走るのでこちらに解決される）が
  # 空振りする（#202）。GNU grep では通るため対話シェルと bats で結果が食い違う。
  # 回数指定を使わず、装飾と読点を先に剥がしてから、許容する言い回しを固定文字列の
  # OR（`grep -F -e … -e …`）で照合する。
  tr -d '*' < "$WT_CLEAN_SKILL" | sed 's/、//g' | grep -Fq \
    -e '回答を受け取った後の別ターン' \
    -e '回答を受け取った後の別のターン' \
    -e '回答を受け取った後の別アシスタントターン' \
    -e '回答を受け取った後の別のアシスタントターン'
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
