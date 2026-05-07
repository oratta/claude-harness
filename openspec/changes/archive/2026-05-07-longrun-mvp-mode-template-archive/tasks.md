## 1. OpenSpec Documents

- [x] 1.1 Create `openspec/changes/longrun-mvp-mode-template-archive/proposal.md` with Why / What Changes / Capabilities / Impact
- [x] 1.2 Create `openspec/changes/longrun-mvp-mode-template-archive/specs/longrun-plan-skill/spec.md` (Modified Capability) covering: lightweight template existence + marker + divergence comment + required sections + excluded sections; archive marker branch; synchronized version bump; README MVP-mode documentation
- [x] 1.3 Create `tasks.md` (this file)

## 2. Lightweight Template

- [x] 2.1 Read existing `plugins/longrun/templates/plan-template.md` to identify shared sections
- [x] 2.2 Create `plugins/longrun/templates/plan-template-mvp.md` with `<!-- mvp-mode -->` as the first content line and an immediately following multi-line HTML comment naming the parent template (`plan-template.md`) and listing the shared sections that must be co-edited
- [x] 2.3 Populate the lightweight template with H2 sections: ゴール, 技術要件, スコープ（含むもの / 含まないもの）, 調査結果サマリ（類似サービス）, 調査結果サマリ（実装パターン）, レビュー結果サマリ（plan-reviewer / bestpractice-reviewer）, 受け入れ条件, 動作確認方法
- [x] 2.4 Confirm the template does NOT include `Changes分解` and does NOT include autonomous-execution-only TDD / Build / Verifier required-items language

## 3. Archive Command Branch

- [x] 3.1 Read existing `plugins/longrun/commands/archive.md`
- [x] 3.2 Insert an MVP-mode discriminator section between the existing step "1. ランディレクトリを特定する" and "2. plan.md の Changes 分解セクションから change 一覧を取得" that detects `<!-- mvp-mode -->` near the head of the target `plan.md`
- [x] 3.3 Document the MVP-mode branch flow: skip the OpenSpec-change archival step (existing step 3) and proceed directly to longrun-directory archival (existing step 4), worktree cleanup (step 5), commit (step 6), and report (step 7)
- [x] 3.4 Document that the full-mode flow (marker absent) is unchanged

## 4. Version Bump

- [x] 4.1 Read `plugins/longrun/.claude-plugin/plugin.json` and confirm current version
- [x] 4.2 Bump the `version` field in plugin.json by at least a minor increment
- [x] 4.3 Update the `version:` line in the YAML frontmatter of `plugins/longrun/skills/longrun-plan/SKILL.md` so it equals the new plugin.json version
- [x] 4.4 Confirm the two values match exactly with a grep

## 5. README Update

- [x] 5.1 Read `plugins/longrun/README.md`
- [x] 5.2 Append (or insert in an appropriate location) an MVP-mode section that includes the literal `--mode=mvp` command form, lists the differences from full mode (Build Contract / TDD / Verifier / OpenSpec archival skipped), and describes the use-case as generic short-time human-implemented MVP scenarios

## 6. lr:p Alias (optional)

- [x] 6.1 Inspect the longrun-plugin commands directory for any `lr:p` alias style file; if present and accepting argument forwarding, ensure `--mode=mvp` is documented as a passthrough; otherwise skip with a note in the report

## 7. Validation

- [x] 7.1 Run `openspec validate longrun-mvp-mode-template-archive` and confirm success
- [x] 7.2 Confirm the lightweight template starts with `<!-- mvp-mode -->` followed by the divergence-prevention HTML comment (head 5 lines)
- [x] 7.3 Confirm `plugin.json` and SKILL.md frontmatter versions match via grep
- [x] 7.4 Confirm `archive.md` body contains the literal string `mvp-mode`

## 8. Commit

- [x] 8.1 Stage the new template, edited archive.md, version bumps, README update, and OpenSpec documents
- [x] 8.2 Commit with the prescribed message (`feat(longrun): add MVP mode template, archive support, and version bump ...`)
- [x] 8.3 Report the commit hash
