## Why

ローカルで開発を始めたWebアプリを本番対応する際、毎回同じVercel + Supabase + GitHub Actionsの構成を手動で指示して構築し直している。この繰り返し作業をスキル化し、対話的にインフラ環境を一括セットアップできるようにする。

## What Changes

- Vercel + Supabase + GitHub Actionsを使ったWebアプリのインフラを対話的にセットアップするスキル `/infra-setup` を新規作成
- 既存の `supabase-project-setup` スキル（`~/.claude/skills/` 配下）の内容を統合・吸収
- 環境構成: local / preview(PR) / staging(mainマージ) / prod(手動promote)
- Supabaseプロジェクト: dev（local+preview用）/ prod（staging+prod用）
- Vercelのビルド + GitHub ActionsのCI（test/lint/type-check）の併用構成
- 本番デプロイは `vercel promote` でstagingビルドをprodに昇格

## Capabilities

### New Capabilities
- `infra-setup-skill`: Vercel + Supabase + GitHub Actionsによるインフラ一括セットアップスキル。ヒアリング → Supabaseセットアップ → Vercelセットアップ → GitHub Actions設定 → ローカル環境仕上げの5フェーズを対話的に実行する。

### Modified Capabilities
<!-- なし -->

## Impact

- oratta-claude-harness marketplace に新プラグインまたは既存プラグインへのスキル追加
- marketplace.json の更新
- 既存 `~/.claude/skills/supabase-project-setup/` は統合後に廃止候補
- 依存ツール: Supabase CLI, Vercel CLI, GitHub CLI, Playwright MCP（ブラウザ操作用）
