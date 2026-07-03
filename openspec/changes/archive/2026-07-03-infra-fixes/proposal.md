# Proposal: infra-fixes — infra プラグインの機能バグ修正と整合性回復

## Why

`plugins/infra/` の 5 Phase Agent と GitHub Actions テンプレートの間に、実装済みの新設計（`.env.production.local` 分離方式）へ一部だけ追随していない箇所、GitHub Secrets の投入名とテンプレ参照名の不一致、文書間の矛盾記述が残っている。前者2件は実際にセットアップを実行すると「Phase 5 が正しい `.env.local` を誤検出して壊す」「deploy-staging.yml が未設定の Secrets を参照して実行時エラーになる」という機能バグに直結する。後者はドキュメントの信頼性を損ない、次にこのプラグインを触る際の判断を誤らせる。

## What Changes

- Phase 5（`agents/infra-phase-5-finalize.md`）の `.env.local` 検証ロジックと関連記述を、Phase 2/Phase 3 が既に実装済みの `.env.production.local` 別ファイル方式に合わせて書き換える（旧・コメントアウト保存前提の検証を削除）
- `agents/infra-phase-4-github-actions.md` の Step 7 `gh secret set` 投入リストに、テンプレートが実際に参照している secrets（`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` / `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY`）を追加する。`PROD_SUPABASE_SERVICE_ROLE_KEY` はテンプレで実使用（`deploy-staging.yml.template` のビルド時置換とランタイム注入の両方）されているため、Phase 2 に service_role key 取得手順を追加する形で解消する（参照除去ではなく取得追加を採用）
- 全 GitHub Actions テンプレートの action バージョンを、`gh api /repos/<owner>/<repo>/tags` で実在確認済みの最新メジャータグへ bump する（`actions/checkout@v4→v7`、`actions/setup-node@v4→v6`、`actions/upload-artifact@v4→v7`、`actions/github-script@v7→v9`、`supabase/setup-cli@v1→v2`）。付録 A finding 4 は upload-artifact/github-script を「現行のまま」としていたが、実地確認の結果これらも旧世代であることが判明したため、finding 4 と同じ「Actions バージョンの鮮度」軸としてスコープに含める
- Vercel Token 取得の CLI 化を検証した結果（Vercel CLI 48.12.0 には `tokens`/`token` サブコマンドが存在しない）を反映し、Playwright MCP / 手動フォールバック方式を現状維持のまま、調査結果を SKILL.md と Phase 4 Agent に注記として残す
- Preview deploy 方針の記述矛盾を実装（`deploy-preview.yml.template`: Draft 中 skip、Ready for review で実発火）を正として解消する。矛盾していたのは `skills/infra-setup/SKILL.md:40`（「PR時は CI のみで自動 preview deploy は行わない」）と `agents/infra-phase-5-finalize.md:179`（「自動 Preview deploy は行われません」）で、README.md の記述は既に実装と整合していたため変更しない
- `agents/infra-phase-1-hearing.md` の Phase 2 手順参照（「Step 10 / Step 10.5」）を実体の Step 番号（Step 11 / Step 11.5）に修正する
- `agents/infra-phase-3-vercel.md` の `vercel link` 用法説明（Step 3 の「`--project` は新規作成に使えない」と、トラブルシューティング節の「`--yes --project {name}` を使う」という矛盾）を、正しい用法に一本化する
- `skills/infra-setup/SKILL.md` のアーキテクチャ図（Phase 4 の説明行）に欠落している `deploy-preview` を追加する
- `skills/infra-setup/SKILL.md` の frontmatter `version`（`0.1.0`）を `plugin.json` の実バージョンに同期し、個人 Dropbox パスのハードコード参照を除去する
- infra plugin.json の version を bump する（marketplace.json 側の同期は change-7 が担当）

## Capabilities

### New Capabilities

- `infra-env-file-scheme`: Phase 5 の `.env.local` / `.env.production.local` 検証ロジックと関連記述が、Phase 2/3 で実装済みの分離ファイル方式と一貫していることを規定する
- `infra-secrets-consistency`: GitHub Actions テンプレートが参照する `secrets.*` 名の集合と、Phase 4 が `gh secret set` で投入する集合が過不足なく一致することを規定する（`SERVICE_ROLE_KEY` の取得元を含む）
- `infra-actions-freshness`: GitHub Actions の action バージョンピンが実在確認済みの最新メジャータグであることと、Vercel Token CLI 化検証の結果が文書に反映されていることを規定する
- `infra-doc-integrity`: Preview deploy 方針・Step 番号参照・`vercel link` 用法・アーキ図・version drift・個人パスなど、infra プラグイン内の文書間整合性を規定する

## Impact

- `plugins/infra/agents/infra-phase-5-finalize.md`
- `plugins/infra/agents/infra-phase-4-github-actions.md`
- `plugins/infra/agents/infra-phase-2-supabase.md`
- `plugins/infra/agents/infra-phase-1-hearing.md`
- `plugins/infra/agents/infra-phase-3-vercel.md`
- `plugins/infra/templates/workflows/*.yml.template`（5ファイル全て、action バージョンピン）
- `plugins/infra/skills/infra-setup/SKILL.md`
- `plugins/infra/README.md`（変更なし想定。既に実装と整合しているため確認のみ）
- `plugins/infra/.claude-plugin/plugin.json`（version bump）
- 依存: なし（独立）
