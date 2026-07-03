# infra-secrets-consistency Specification

## Purpose
TBD - created by archiving change infra-fixes. Update Purpose after archive.
## Requirements
### Requirement: Phase 4 gh secret set list MUST cover every `secrets.*` name referenced by the templates

`plugins/infra/templates/` 配下の全 `.yml.template` が参照する `secrets.*` 名の集合（`GITHUB_TOKEN` を除く）は、`agents/infra-phase-4-github-actions.md` の Step 7 が `gh secret set` で投入する集合に過不足なく含まれていなければならない（`EDGE_CONFIG_ID` はメンテナンスモード opt-in のオプション項目として明示的に文書化されていれば充足とみなす）。This requirement MUST be satisfied.

#### Scenario: Template-referenced secrets are a subset of the investment list

- **WHEN** `grep -rho 'secrets\.[A-Z_]*' plugins/infra/templates/ | sort -u` を実行し、`GITHUB_TOKEN` を除いた各項目について `agents/infra-phase-4-github-actions.md` を grep する
- **THEN** `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` / `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY` / `PROD_SUPABASE_PROJECT_REF` / `PROD_SUPABASE_DB_URL` / `SUPABASE_ACCESS_TOKEN` / `VERCEL_TOKEN` / `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` の全てについて、対応する `gh secret set <NAME>` の行が Step 7 に存在しなければならない

#### Scenario: EDGE_CONFIG_ID remains explicitly documented as optional

- **WHEN** `agents/infra-phase-4-github-actions.md` の `EDGE_CONFIG_ID` に関する記述を読む
- **THEN** 「メンテナンスモードを使う場合のみ必要」という opt-in の位置づけと、投入する際の `gh secret set EDGE_CONFIG_ID` コマンド例の両方が含まれていなければならない

### Requirement: Phase 2 MUST acquire the prod service_role key when the templates use it

`deploy-staging.yml.template` が `PROD_SUPABASE_SERVICE_ROLE_KEY` をビルド時・ランタイムの両方で実使用している以上、`agents/infra-phase-2-supabase.md` は Prod プロジェクトの `service_role` key を取得し `.env.production.local` に書き込まなければならない（`.env.local` には書き込まない）。This requirement MUST be satisfied.

#### Scenario: Phase 2 extracts the service_role key alongside anon

- **WHEN** `agents/infra-phase-2-supabase.md` の API Keys 取得ステップ本文を読む
- **THEN** `anon` key の抽出手順に加えて `service_role` key を prod プロジェクトから抽出する手順が明記されていなければならない

#### Scenario: service_role key is written only to .env.production.local

- **WHEN** `agents/infra-phase-2-supabase.md` の `.env.production.local` 書き込みステップと `.env.local` 書き込みステップの両方を読む
- **THEN** `service_role` key（`SUPABASE_SERVICE_ROLE_KEY` 等の変数名）への言及は `.env.production.local` 側にのみ存在し、`.env.local` 側には存在してはならない

#### Scenario: State file does not record the raw service_role key value

- **WHEN** `agents/infra-phase-2-supabase.md` の state ファイル書き込みステップ（Phase 2 セクション）を読む
- **THEN** service_role key の実値がその中に書き込まれる記述は存在してはならない（既存の「機密情報は state に書かない」原則が service_role key にも適用されていなければならない）

### Requirement: Phase 4 MUST source PROD_SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY from `.env.production.local`

Phase 4 が新規に投入する `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY` の 3 secrets は、`.env.production.local`（Phase 2 が書き込み済み）から値を取得しなければならない。`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY`（CI 用）は `.env.local` の dev 値から取得しなければならない。This requirement MUST be satisfied.

#### Scenario: Prod secrets read from the production env file

- **WHEN** Phase 4 の Step 6 または Step 7 付近で `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY` を取得するコマンドを読む
- **THEN** 取得元として `.env.production.local` が明示されていなければならない

#### Scenario: CI secrets read from the dev-active local env file

- **WHEN** Phase 4 の Step 6 または Step 7 付近で `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` を取得するコマンドを読む
- **THEN** 取得元として `.env.local` が明示されていなければならない

