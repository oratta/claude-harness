## 1. OpenSpec Documents

- [x] 1.1 Create `openspec/changes/longrun-mvp-mode-skill-branch/proposal.md` with Why / What Changes / Capabilities / Impact
- [x] 1.2 Create `openspec/changes/longrun-mvp-mode-skill-branch/specs/longrun-plan-skill/spec.md` as a Modified Capability delta covering: flag dispatch, Step mapping, Step 4.5 research, Step 7 parallel reviewers, mvp-mode marker, lightweight Validation, Step 8 handoff
- [x] 1.3 Create `tasks.md` (this file)

## 2. SKILL.md Edits — Dispatch Section

- [x] 2.1 Read current `plugins/longrun/skills/longrun-plan/SKILL.md` and capture the boundary between the YAML frontmatter and the first body line (`# Run Plan — plan.md 作成スキル`)
- [x] 2.2 Insert a new `## モード分岐（フルモード / MVP モード）` section immediately after the frontmatter and before the existing introduction line, describing how `--mode=mvp` is detected, how `--mode=full` and no-flag inputs route to the existing Step 1〜8, and how `--mode=mvp` jumps to the MVP-mode section at the end of the file
- [x] 2.3 Verify with `git diff` that nothing inside the existing Step 1 〜 Step 8 section bodies is modified

## 3. SKILL.md Edits — MVP Mode Section

- [x] 3.1 Append a new `## MVP モード（--mode=mvp）` section to the end of SKILL.md, opening with a one-paragraph overview that says: short-time human-implemented MVP use case; Build Contract / TDD / Verifier are skipped; this is a generic capability not tied to any specific project
- [x] 3.2 Add the Step 1〜8 mapping table as a Markdown table with columns: 既存 Step / MVP モード対応 / 内容. Cover rows for Step 1, Step 2, Step 2b, Step 3, Step 4, Step 4.5 (new), Step 5, Step 5a, Step 5b, Step 6, Step 7, Step 8
- [x] 3.3 Add per-step prose for each REPLACE or new step (Step 1, Step 4.5, Step 5, Step 5a, Step 6, Step 7, Step 8) describing the lightweight behavior. For Step 4.5 include the literal `longrun-mvp-research` agent name and a prompt template referencing the `## 類似サービス事例` / `## 実装パターン` / `## Search Audit` output contract
- [x] 3.4 For Step 5 (Synthesis) prose, explicitly require the executor to embed `<!-- mvp-mode -->` as the first content line of the generated plan.md
- [x] 3.5 For Step 6 (Validation) prose, list the seven required sections (ゴール / 技術要件 / スコープ / 受け入れ条件 / 動作確認方法 / 調査結果サマリ / レビュー結果サマリ) as an explicit checklist
- [x] 3.6 For Step 7 (Plan Review) prose, name both `longrun-mvp-plan-reviewer` and `longrun-mvp-bestpractice-reviewer` and state explicitly that both Agent tool invocations MUST be placed in a single assistant message (multiple tool_use entries) to execute in parallel
- [x] 3.7 For Step 8 (Handoff) prose, omit any backlog editing or OpenSpec change-creation instruction; provide a handoff message describing where plan.md is saved and inviting human implementation or `/longrun:exec` delegation

## 4. Validation

- [x] 4.1 Run `openspec validate longrun-mvp-mode-skill-branch` and confirm success
- [x] 4.2 Run `git diff plugins/longrun/skills/longrun-plan/SKILL.md` and confirm no in-place edits inside Step 1 〜 Step 8 bodies (only additions before Step 1 and after Step 8)
- [x] 4.3 Grep the SKILL.md body for the literal strings `longrun-mvp-research`, `longrun-mvp-plan-reviewer`, `longrun-mvp-bestpractice-reviewer`, `<!-- mvp-mode -->`, `--mode=mvp`, `--mode=full` and confirm each appears at least once
- [x] 4.4 Confirm that the existing Step 7 body (full mode) still references `longrun-reviewer` (the original full-mode reviewer agent)

## 5. Commit

- [x] 5.1 `git add` the SKILL.md edits + new OpenSpec documents
- [x] 5.2 Commit with the prescribed message (`feat(longrun): add MVP mode branching to longrun-plan SKILL.md ...`)
- [x] 5.3 Report the commit hash
