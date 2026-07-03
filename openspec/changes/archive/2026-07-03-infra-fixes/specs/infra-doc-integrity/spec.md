# infra-doc-integrity Delta Specification

## ADDED Requirements

### Requirement: Preview deploy policy descriptions MUST match the implemented Draft-skip / Ready-for-review-fire behavior

`skills/infra-setup/SKILL.md` と `agents/infra-phase-5-finalize.md` の Preview deploy に関する記述は、`templates/workflows/deploy-preview.yml.template` の実装（Draft 中は job レベルで skip、`ready_for_review` で実際に Preview deploy が発火する）と一致しなければならない。「自動 Preview deploy は行われない」という趣旨の記述をこれらのファイルに残してはならない。`README.md` は既に実装と整合しているため変更対象外とする。This requirement MUST be satisfied.

#### Scenario: SKILL.md no longer claims no automatic preview deploy

- **WHEN** `grep -n "自動 preview deploy は行わない\|自動 Preview deploy は行われません" plugins/infra/skills/infra-setup/SKILL.md plugins/infra/agents/infra-phase-5-finalize.md` を実行する
- **THEN** 一致件数は 0 件でなければならない

#### Scenario: Updated wording states Ready-for-review triggers real deploy

- **WHEN** `skills/infra-setup/SKILL.md` の「ポイント」文と `agents/infra-phase-5-finalize.md` の「PR Preview について」節を読む
- **THEN** 両方に「Draft 中は skip」「Ready for review で Preview deploy が実行される」という趣旨の記述が含まれていなければならない

#### Scenario: README.md remains unchanged

- **WHEN** 本 change 適用前後で `plugins/infra/README.md` を diff する
- **THEN** Preview deploy 方針に関する行に差分がない（既に実装と整合しているため）

### Requirement: Phase 1's cross-reference to Phase 2 step numbers MUST match the actual step numbers

`agents/infra-phase-1-hearing.md` が `agents/infra-phase-2-supabase.md` の手順を参照する際の Step 番号は、参照先の実際の見出し番号と一致しなければならない。This requirement MUST be satisfied.

#### Scenario: Step number references corrected

- **WHEN** `agents/infra-phase-1-hearing.md` 内の「Phase 2 の手順（`infra-phase-2-supabase.md` の Step ...）」という参照文を読む
- **THEN** `.env.local` 書き込みへの参照は「Step 11」、`.env.production.local` 書き込みへの参照は「Step 11.5」でなければならない（旧「Step 10」「Step 10.5」という表記が残っていてはならない）

#### Scenario: No stale step-number grep hits

- **WHEN** `grep -n "Step 10\.5\|の Step 10）" plugins/infra/agents/infra-phase-1-hearing.md` を実行する
- **THEN** 一致件数は 0 件でなければならない

### Requirement: `vercel link` usage guidance MUST disambiguate new-project vs. re-link cases

`agents/infra-phase-3-vercel.md` の Step 3（新規プロジェクト作成時の対話フロー案内）とトラブルシューティング節（`--yes --project {name}` の案内）は、それぞれ「新規作成」と「既存プロジェクトへの再リンク」という異なるケースを指すことが本文から明確に読み取れなければならない。This requirement MUST be satisfied.

#### Scenario: Troubleshooting section scoped to re-link case

- **WHEN** `agents/infra-phase-3-vercel.md` のトラブルシューティング節にある `vercel link` の記述を読む
- **THEN** 「既存プロジェクトへの再リンク時のみ」等、新規作成フロー（Step 3）とは異なるケースであることを明示する文言が含まれていなければならない

#### Scenario: No unqualified contradictory statement remains

- **WHEN** Step 3 本文とトラブルシューティング節の `vercel link` 関連記述を並べて読む
- **THEN** 「`--project` は新規作成に使えない」という Step 3 の説明と、トラブルシューティング節の `--project` 使用例が、適用ケースの違いなしに並存していてはならない

### Requirement: Architecture diagram in SKILL.md MUST list all five generated workflows

`skills/infra-setup/SKILL.md` のアーキテクチャ図における Phase 4 の説明行は、Phase 4 が実際に生成する 5 本のワークフロー（ci / deploy-preview / deploy-staging / deploy-production / migrate-production）を漏れなく反映しなければならない。This requirement MUST be satisfied.

#### Scenario: deploy-preview appears in the Phase 4 line

- **WHEN** `skills/infra-setup/SKILL.md` のアーキテクチャ図内 `infra-phase-4-github-actions` の説明行を読む
- **THEN** `deploy-preview` という語がその行に含まれていなければならない

### Requirement: SKILL.md version frontmatter and personal path references MUST be removed/synced

`skills/infra-setup/SKILL.md` の frontmatter `version` は `plugins/infra/.claude-plugin/plugin.json` の値と一致しなければならず、個人環境固有のディレクトリパス（`/Users/oratta/Dropbox/...`）への参照を含んではならない。This requirement MUST be satisfied.

#### Scenario: SKILL.md version matches plugin.json

- **WHEN** `skills/infra-setup/SKILL.md` の frontmatter `version` と `plugins/infra/.claude-plugin/plugin.json` の `version` を比較する
- **THEN** 両者は同一の値でなければならない

#### Scenario: No personal Dropbox path remains

- **WHEN** `grep -rn "/Users/oratta" plugins/infra/` を実行する
- **THEN** 一致件数は 0 件でなければならない

### Requirement: infra plugin.json version MUST be bumped for this change

`plugins/infra/.claude-plugin/plugin.json` の `version` は、本 change 適用前の値より大きくなければならない（`~/.claude/rules/plugin-editing.md` 準拠。marketplace.json への同期は change-7 が担当するため本 capability の対象外）。This requirement MUST be satisfied.

#### Scenario: plugin.json version is bumped

- **WHEN** 本 change 適用前後で `plugins/infra/.claude-plugin/plugin.json` の `version` フィールドを比較する
- **THEN** 適用後の値が適用前の値より大きい（semver 上位）
