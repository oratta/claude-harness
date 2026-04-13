# Infra Setup Plugin

Web アプリのインフラ（Vercel + Supabase + GitHub Actions）を対話的に一括セットアップする Claude Code プラグイン。

## 概要

ローカル開発した Web アプリを本番対応する際、毎回同じような構成作業（Supabase プロジェクト作成、Vercel セットアップ、GitHub Actions ワークフロー生成、環境変数配線）を手動でやるのを避けるためのスキル。5フェーズを Agent 分離で順に実行する。

## 使い方

```
/infra-setup
```

または、自然言語で起動:

- 「このプロジェクトのインフラを作って」
- 「Vercel と Supabase でデプロイ環境をセットアップして」
- 「本番環境を用意したい」

## 構築される環境

| 環境 | URL | Supabase DB |
|---|---|---|
| local | localhost | dev（リモート） |
| staging | Vercel 自動 URL | prod（リモート） |
| prod | カスタムドメイン | prod（リモート） |

- Vercel の Git 自動連携は `vercel.json` で OFF
- 全デプロイは GitHub Actions で制御（ci / deploy-staging / deploy-production / migrate-production の4本）
- PR 時は CI のみ、自動 Preview deploy はしない（個人開発前提）

## 依存ツール

- Supabase CLI（`npx supabase` でも可）
- Vercel CLI（`npm i -g vercel`）
- GitHub CLI（`gh`）
- `jq`
- Playwright MCP（推奨、無ければ手動フォールバック）

## 既存 `supabase-project-setup` スキルからの移行

このプラグインは `~/.claude/skills/supabase-project-setup/` を統合吸収しています。
既存スキルがある場合、`/infra-setup` 実行時に検出して削除案内します。手動で削除したい場合:

```bash
rm -rf ~/.claude/skills/supabase-project-setup/
```

削除しても機能は失われません（`infra-setup` の Phase 2 で同等以上の処理を行います）。

## 構成ファイル

```
plugins/infra/
├── .claude-plugin/plugin.json        ← プラグイン定義
├── README.md                          ← このファイル
├── skills/
│   └── infra-setup/
│       └── SKILL.md                  ← オーケストレータ
└── agents/
    ├── infra-phase-1-hearing.md      ← Phase 1: ヒアリング
    ├── infra-phase-2-supabase.md     ← Phase 2: Supabase
    ├── infra-phase-3-vercel.md       ← Phase 3: Vercel
    ├── infra-phase-4-github-actions.md ← Phase 4: GitHub Actions
    └── infra-phase-5-finalize.md     ← Phase 5: ローカル仕上げ
```

## state ファイル

Phase 間の情報受け渡しに `/tmp/infra-setup-state.md` を使用。中断時はこのファイルを残したまま終了するので、次回実行で再開可能。完了時に自動削除される。

**セキュリティ上の注意**:
- state ファイルには `project_ref` / `org_id` / メールアドレスなど **semi-sensitive** な情報が含まれる
- Access Token / DB パスワード / API Keys の**実値は含まれない**（これらは `.env.local` / `.env.production.local` / ユーザーのパスワードマネージャーで管理）
- 共有 PC で作業する場合、セットアップ完了前（state ファイル残存中）に他ユーザーに操作される可能性に注意
- macOS のデフォルト `/tmp` は `drwxrwxrwt` だが、オーナー読み取りのみで実運用は問題になりにくい

## 書き込まれるファイル

- `.env.local` — dev 用 Supabase 認証情報 + Access Token + DB passwords（`.gitignore` 対象）
- `.env.production.local` — prod 用 `NEXT_PUBLIC_SUPABASE_URL` / `ANON_KEY`（Phase 3 が参照、`.gitignore` 対象）
- `.mcp.json` — Supabase MCP サーバー設定（`.gitignore` 対象）
- `.gitignore` — 上記 3ファイルを追記（既に含まれていればスキップ）
- `vercel.json` — `github.enabled: false` を追加（既存キーは保持）
- `.vercel/project.json` — `vercel link` が作成
- `.github/workflows/ci.yml` / `deploy-staging.yml` / `deploy-production.yml` / `migrate-production.yml`

## ライセンス・著者

著者: Oratta
