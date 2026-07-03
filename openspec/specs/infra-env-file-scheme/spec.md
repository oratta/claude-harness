# infra-env-file-scheme Specification

## Purpose
TBD - created by archiving change infra-fixes. Update Purpose after archive.
## Requirements
### Requirement: Phase 5 MUST validate prod values against `.env.production.local`, not commented-out `.env.local` entries

`agents/infra-phase-5-finalize.md` の Step 2（`.env.local` 最終検証）は、prod 用の Supabase 値が `.env.local` にコメントアウトで保存されているという前提を持ってはならない。Phase 2/3 が実装済みの方式（prod 値は `.env.production.local` に active な値として分離保存し、`.env.local` は dev 値のみを active に保持する）に基づき、Phase 5 は (a) `.env.local` の `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` が dev プロジェクトの値であること、(b) `.env.production.local` が存在し同名キーが prod プロジェクトの値で active に書かれていること、の 2 点を検証しなければならない。This requirement MUST be satisfied by `infra-phase-5-finalize.md`.

#### Scenario: No commented-out prod value expectation remains

- **WHEN** `plugins/infra/agents/infra-phase-5-finalize.md` を grep で `コメントアウト` を検索する
- **THEN** prod 値の保存形式に関する文脈での一致は 0 件でなければならない（`supabase start` に関する既存の警告文など無関係な文脈での一致は対象外）

#### Scenario: Step 2 checks both env files

- **WHEN** Step 2（`.env.local` 最終検証）のセクション本文を読む
- **THEN** `.env.production.local` というファイル名が明示的に検証対象として言及されていなければならない

#### Scenario: Goal description matches the two-file scheme

- **WHEN** ファイル冒頭の「あなたのゴール」1項目目を読む
- **THEN** 「prod 側はコメントアウト状態」という記述は存在せず、`.env.production.local` の検証を指す記述に置き換わっていなければならない

### Requirement: Phase 5 completion summary and cautions MUST reflect the two-file scheme

Phase 5 の「重要な注意事項」節および完了サマリー（Step 6/Step 7 の state 書き込み）は、prod 値が `.env.local` にコメントアウト保存されているという前提を含んではならない。This requirement MUST be satisfied.

#### Scenario: Cautions section updated

- **WHEN** 「重要な注意事項」節を読む
- **THEN** 「`.env.local` の prod系がコメントアウトで保存されている前提を崩さない」という記述は存在せず、`.env.production.local` に prod 値が分離保存されている前提の記述に置き換わっていなければならない

### Requirement: Acceptance grep for legacy comment-based prod storage MUST return zero matches

`plan.md` 受け入れ条件 6 を満たすため、`agents/infra-phase-5-finalize.md` 全体に「コメントアウトで prod 値を保存」する旧方式を示唆する記述が残っていてはならない。This requirement MUST be satisfied.

#### Scenario: Repository-wide acceptance check

- **WHEN** `grep -n "コメントアウト" plugins/infra/agents/infra-phase-5-finalize.md` を実行する
- **THEN** prod 値の保存方式に関する一致が 0 件であること（`.env.production.local` 方式に統一されていること）

