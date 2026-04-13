## 1. プラグイン構造の作成

- [ ] 1.1 `plugins/infra/.claude-plugin/plugin.json` を作成（skill + 5 agents を登録）
- [ ] 1.2 `plugins/infra/skills/infra-setup/` ディレクトリ作成
- [ ] 1.3 `plugins/infra/agents/` ディレクトリ作成
- [ ] 1.4 `.claude-plugin/marketplace.json` に `infra` プラグインを追加

## 2. SKILL.md（オーケストレータ）

- [ ] 2.1 `plugins/infra/skills/infra-setup/SKILL.md` を作成
- [ ] 2.2 スキルの目的・発火条件・全体フロー図を記述
- [ ] 2.3 前提条件チェック実行ロジック（CLI存在、認証、Playwright MCP利用可否）を記述
- [ ] 2.4 state ファイル `/tmp/infra-setup-state.md` の初期化ロジックを記述
- [ ] 2.5 Phase 1〜5 を順に Agent 呼び出しするフローを記述（`subagent_type: infra-phase-N-*`）
- [ ] 2.6 各 Phase 完了後のユーザー確認ステップを記述
- [ ] 2.7 中断時の state ファイル保持と再開ロジックを記述
- [ ] 2.8 全体完了時の state ファイル削除ロジックを記述

## 3. Agent: Phase 1 — ヒアリング

- [ ] 3.1 `plugins/infra/agents/infra-phase-1-hearing.md` を作成
- [ ] 3.2 ヒアリング項目の質問テンプレ（プロジェクト名、ドメイン、メール、リージョン）を記述
- [ ] 3.3 メールプロバイダ判定と +エイリアス対応確認ロジックを記述
- [ ] 3.4 GitHub リポジトリ検出ロジック（`git remote -v` 解析）を記述
- [ ] 3.5 state ファイルへの書き込み（`## Phase 1 (Hearing)` セクション）を記述

## 4. Agent: Phase 2 — Supabase セットアップ

- [ ] 4.1 `plugins/infra/agents/infra-phase-2-supabase.md` を作成
- [ ] 4.2 state ファイル読み込みロジックを記述
- [ ] 4.3 メール+エイリアス生成（`{user}+{project}-supa@gmail.com` 等）のロジックを記述
- [ ] 4.4 Playwright MCP による Supabase アカウント作成手順を記述
- [ ] 4.5 メール確認完了をユーザーに依頼するステップを記述
- [ ] 4.6 Playwright MCP で Access Token 取得する手順を記述
- [ ] 4.7 Playwright MCP 利用不可時の手動Token取得フォールバック手順を記述
- [ ] 4.8 `supabase orgs list` / `supabase orgs create` による Organization 取得・作成手順を記述
- [ ] 4.9 Dev/Prod プロジェクト作成手順（`--org-id` 指定、DB パスワード生成）を記述
- [ ] 4.10 API Keys 取得と `.env.local` 書き込み手順を記述（書き込むキー名を明示）
- [ ] 4.11 `.env.local` が `.gitignore` に含まれているかの検証を記述
- [ ] 4.12 `.mcp.json` への Supabase MCP 追加手順を記述
- [ ] 4.13 state ファイルへの書き込み（`## Phase 2 (Supabase)` セクション）を記述

## 5. Agent: Phase 3 — Vercel セットアップ

- [ ] 5.1 `plugins/infra/agents/infra-phase-3-vercel.md` を作成
- [ ] 5.2 state ファイル読み込みロジックを記述
- [ ] 5.3 `vercel link` によるプロジェクト作成・GitHub 連携手順を記述
- [ ] 5.4 `vercel.json` への `"github": { "enabled": false }` 設定（既存ファイルとマージ）手順を記述
- [ ] 5.5 `vercel env add` による Preview / Production 両方への prod Supabase 設定手順を記述
- [ ] 5.6 `vercel domains add` によるカスタムドメイン追加（Production のみ紐付け）手順を記述
- [ ] 5.7 DNS 設定案内を記述
- [ ] 5.8 state ファイルへの書き込み（`## Phase 3 (Vercel)` セクション、Org ID / Project ID 含む）を記述

## 6. Agent: Phase 4 — GitHub Actions

- [ ] 6.1 `plugins/infra/agents/infra-phase-4-github-actions.md` を作成
- [ ] 6.2 state ファイル読み込みロジックを記述
- [ ] 6.3 `.github/workflows/ci.yml` テンプレート（`pull_request` トリガー、test/lint/type-check）を記述
- [ ] 6.4 `.github/workflows/deploy-staging.yml` テンプレート（`push: branches: [main]`、Preview env build、`--prod`なしdeploy、concurrency設定）を記述
- [ ] 6.5 `.github/workflows/deploy-production.yml` テンプレート（`workflow_dispatch`+`confirm`、Production env build、`--prod`deploy、`environment: Production`、concurrency設定）を記述
- [ ] 6.6 `.github/workflows/migrate-production.yml` テンプレート（`workflow_dispatch`+`confirm`、`supabase link`→`supabase db push`、`environment: Production`）を記述
- [ ] 6.7 Playwright MCP による `VERCEL_TOKEN` 取得手順を記述（ダッシュボードURL含む）
- [ ] 6.8 Playwright MCP 利用不可時の VERCEL_TOKEN 手動取得フォールバック手順を記述
- [ ] 6.9 `jq` による `.vercel/project.json` からの ORG_ID / PROJECT_ID 抽出手順を記述
- [ ] 6.10 `gh secret set` による GitHub Secrets 自動投入手順（VERCEL_TOKEN / VERCEL_ORG_ID / VERCEL_PROJECT_ID / SUPABASE_ACCESS_TOKEN / SUPABASE_PROD_REF / SUPABASE_DB_PASSWORD_PROD）を記述
- [ ] 6.11 state ファイルへの書き込み（`## Phase 4 (GitHub Actions)` セクション）を記述

## 7. Agent: Phase 5 — ローカル仕上げ

- [ ] 7.1 `plugins/infra/agents/infra-phase-5-finalize.md` を作成
- [ ] 7.2 state ファイル読み込みロジックを記述
- [ ] 7.3 `.env.local` の最終内容検証（dev プロジェクトの URL / ANON_KEY が設定されているか）を記述
- [ ] 7.4 `npx supabase link --project-ref {DEV_REF}` 実行手順（マイグレーション管理用）を記述
- [ ] 7.5 `next dev` 動作確認の案内（`supabase start` は実行しない旨を明示）を記述
- [ ] 7.6 セットアップ完了サマリー表示ロジック（4環境 × URL × DB接続先、prod昇格手順、警告メッセージ×2、PR Preview なしの旨）を記述
- [ ] 7.7 state ファイル削除ロジックを記述

## 8. 既存スキルの廃止処理

- [ ] 8.1 SKILL.md（オーケストレータ）に「既存 `~/.claude/skills/supabase-project-setup/` 検出時の deprecated 案内」ロジックを追加
- [ ] 8.2 proposal.md または `plugins/infra/README.md` に、既存スキル手動削除手順を明記

## 9. 統合・検証

- [ ] 9.1 SKILL.md と全 Agent ファイルの通しレビュー（state受け渡しキー名の一貫性、Phase間依存の整合性）
- [ ] 9.2 既存 `supabase-project-setup` スキルとの差分確認・統合漏れチェック
- [ ] 9.3 `marketplace.json` への `infra` プラグイン追加とバージョン確認
- [ ] 9.4 OpenSpec change の verify（`openspec-verify-change`）実行
