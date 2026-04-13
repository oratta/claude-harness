## Context

ユーザーはローカルで開発を始め、本番対応時に毎回同じ Vercel + Supabase + GitHub Actions 構成を手動で指示して構築している。既存の `supabase-project-setup` スキル（`~/.claude/skills/` 配下）はSupabaseのみをカバーし、Vercel・CI・環境変数の繋ぎ込みは範囲外。

環境構成:
- **local**: `next dev` でアプリ、リモートの Supabase **dev** を参照（ローカルDBは立てない）
- **PR時**: CI（test/lint/type-check）のみ実行、Vercel自動デプロイは無し
- **staging**: main マージ時に GitHub Actions が Vercel Preview 環境でビルド・デプロイ、Supabase **prod** を参照（Vercel自動URL）
- **prod**: GitHub Actions `workflow_dispatch` で confirm 付き実行、Vercel Production 環境でビルド・デプロイ、カスタムドメインで公開、Supabase **prod** を参照

Vercel の Git 自動連携は `vercel.json` で `"github": { "enabled": false }` にして無効化し、**全デプロイを GitHub Actions で制御**する（OAK Casino 実績パターン）。

Supabase プロジェクト構成:
- **dev**: local 開発専用。マイグレーション試験場、データ破壊しても影響なし
- **prod**: staging / prod の両方が参照する本番DB

dev DB を見るのは local のみ。staging で prod DB と同条件で動作確認してから本番昇格する設計。

## Goals / Non-Goals

**Goals:**
- `/infra-setup` で対話的にVercel + Supabase + GitHub Actionsの全環境を構築できる
- 既存 `supabase-project-setup` の知見を統合する
- CLI/MCPを最大限活用し、ユーザーの手作業を最小化する
- 各フェーズで確認を挟み、安全に進行する

**Non-Goals:**
- Vercel/Supabase以外のインフラ（AWS, GCP等）への対応
- モノレポ構成への対応（単一アプリ前提）
- カスタムドメインのDNS設定自動化（レジストラが多様すぎる。案内のみ）
- DBスキーマやマイグレーションの設計（アプリ固有の話）
- 監視・アラート・ログ基盤の構築

## Decisions

### D1: スキルの配置 — 新規プラグイン `infra` として作成

既存プラグインに入れるより、独立した `plugins/infra/` を作る。インフラセットアップは他のプラグイン（worktree, longrun等）と関心が異なる。

**代替案:** 既存プラグインに追加 → 関心の分離が崩れる。スタンドアロンスキル → marketplace管理のメリットがない。

### D2: フェーズ構成 — 5フェーズ対話型

```
Phase 1: ヒアリング（プロジェクト名、ドメイン、メールプロバイダ等）
Phase 2: Supabase（Org + Dev/Prodプロジェクト + .env.local書き込み）
Phase 3: Vercel（プロジェクト作成、vercel.json Git連携OFF、環境変数、ドメイン）
Phase 4: GitHub Actions（ci / deploy-staging / deploy-production / migrate-production + Secrets投入）
Phase 5: ローカル環境仕上げ（.env.local検証、supabase link、動作確認、完了サマリー）
```

各フェーズ終了時にユーザー確認を挟む。フェーズ単位でスキップも可能にする（既にSupabaseセットアップ済み等）。実装は D8 の Agent オーケストレーション構造に従い、Phase ごとに独立 Agent で実行する。

### D3: Supabaseセットアップ — 既存スキルのロジックを吸収

Gmail+エイリアスによるアカウント分離、Playwright MCPによるブラウザ操作、CLIによるプロジェクト・Organization 作成の流れをそのまま取り込み、`infra-phase-2-supabase.md` Agent に統合する。統合後、既存 `~/.claude/skills/supabase-project-setup/` はユーザー環境から削除案内する（SKILL.md オーケストレータが検出した場合に deprecated 案内）。外部スクリプト依存は最小化する。

### D4: デプロイ制御 — GitHub Actions 主導の2ワークフロー構成（OAK Casino パターン）

Vercel の Git 自動連携を `vercel.json` の `"github": { "enabled": false }` で無効化し、全デプロイを GitHub Actions で制御する。PR時はCIのみ実行し、自動Preview deploy は行わない（個人開発前提、必要時はローカル + staging で確認）。

- **`ci.yml`**: PR時に test/lint/type-check を実行（マージゲート）
- **`deploy-staging.yml`**: `push: branches: [main]` でトリガー。`vercel pull --environment=preview` → `vercel build` → `vercel deploy --prebuilt`（Preview デプロイ、Vercel自動URL）
- **`deploy-production.yml`**: `workflow_dispatch`（`confirm: boolean` 必須）でトリガー。`vercel pull --environment=production` → `vercel build --prod` → `vercel deploy --prebuilt --prod`（Production デプロイ、カスタムドメインに紐付く）
- **`migrate-production.yml`**: `workflow_dispatch`（`confirm: boolean` 必須）でトリガー。prod Supabase へのマイグレーション適用（詳細は D7）

**なぜ `vercel promote` を使わないか:**
staging と prod は Vercel の異なる環境（Preview / Production）で別々にビルドする。staging で動作確認してから prod へ手動昇格する流れだが、promote は同一バンドルを昇格する仕組みのため Vercel 環境枠の使い分けと両立しない。今回は環境分離・確認運用を優先して再ビルド方式を採る。

**2回ビルドのリスク:** 理論的には依存解決や Runner 環境の時刻差で `staging OK → production ビルド失敗` があり得るが、`npm ci` + lockfile + Node バージョン固定 で実用上ほぼ発生しない。OAK Casino プロジェクトで本番運用実績あり。

**confirm gate と environment 承認:** `deploy-production.yml` の `inputs.confirm` boolean に加え、GitHub `Production` environment を作って approval gate を有効化する（任意だが推奨）。

**代替案:** 
- `vercel promote` → 環境枠分離と両立しないため却下
- Vercelプロジェクト2つ（staging用とprod用）→ 環境変数管理コスト2倍、却下

### D5: CI構成 — GitHub Actions 一本化

GitHub Actions で CI（test/lint/type-check）とデプロイ（staging/production）をすべて担当する。Vercel 側の Git 連携は `vercel.json` で無効化してあるため、Vercel は CLI 経由のビルド・ホスティングのみを担う。役割を明確に分離する。

### D6: 環境変数の管理 — Vercel Environment Variables + .env.local

| 環境 | URL | Supabase | Vercel環境 | ビルド起動元 |
|------|-----|----------|-----------|-------------|
| local | localhost | **dev（リモート）** | — | `next dev`（ローカル） |
| staging | Vercel自動URL（`*-git-main-*.vercel.app`） | **prod** | **Preview** | GitHub Actions（main push時） |
| prod | **カスタムドメイン** | prod | **Production** | GitHub Actions（workflow_dispatch） |

**Vercel 環境変数の設定値:**
- **Vercel Preview env vars**: prod Supabase の URL / ANON_KEY（staging が使う）
- **Vercel Production env vars**: prod Supabase の URL / ANON_KEY（prod が使う、Preview と同じ値）

実質「Vercel側のenv vars 2セットとも prod Supabase を指す」状態。dev DB は local の `.env.local` でのみ使用する。

**注意点:**
- カスタムドメインは prod のみ（Vercel Production deployment）に紐付ける。staging（Preview deployment）には紐付けない。
- PR Preview の自動デプロイは行わない。PR時は CI（test/lint/type-check）のみ。動作確認は local + main マージ後の staging で実施。
- local は `supabase start` を使わず dev プロジェクトをリモート参照する。**個人開発前提**。複数人開発・並行worktreeでデータ破壊リスクがある点は Risks に記載。

### D7: マイグレーション運用 — デプロイから分離した独立ワークフロー

DB マイグレーションはデプロイと分離し、独立した GitHub Actions ワークフロー `migrate-production.yml` で実行する。

| 環境 | 適用方法 | 実行者 | トリガー |
|------|----------|--------|----------|
| dev | local から `supabase db push --linked` | 開発者（個人） | 手動 |
| prod | `migrate-production.yml`（`workflow_dispatch` + `confirm: boolean`） | 開発者（GitHub UI） | 手動（approval gate対応） |

**なぜデプロイと分離するか:**
- スキーマ変更なしの軽微修正でマイグレーションが走らない運用を明確化できる
- 互換性のあるスキーマ変更を先行適用→後日コードデプロイ、という運用が自然に取れる
- マイグレーション失敗時の影響範囲がデプロイと切り離され、ロールバックしやすい
- 「いつ誰がマイグレーションを当てたか」が GitHub Actions 履歴に残る

**`migrate-production.yml` の構成（概要）:**
```yaml
on:
  workflow_dispatch:
    inputs:
      confirm: { description: '本番マイグレーションを実行しますか？', required: true, type: boolean, default: false }
jobs:
  migrate:
    environment: { name: Production }
    steps:
      - confirm validation
      - checkout
      - setup supabase CLI
      - supabase link --project-ref ${{ secrets.SUPABASE_PROD_REF }}
      - supabase db push --linked
```

**dev 側の運用:**
local から `supabase link --project-ref {DEV_REF}` → `supabase db push --linked` を手動実行。dev は壊しても影響なしの試験場として扱う。

**代替案:**
- deploy-production.yml に組み込む → デプロイ失敗時にDBだけ更新済みの状態になるリスクで却下
- 完全手動（ローカルから prod に db push）→ 監査ログが残らず属人化するため却下

### D8: スキル構造 — Agent オーケストレーションパターン（longrun 踏襲）

SKILL.md をオーケストレータとし、各 Phase を独立 Agent として実装する。longrun プラグインの実績構造に揃える。

```
plugins/infra/
├── .claude-plugin/plugin.json
├── skills/
│   └── infra-setup/
│       └── SKILL.md                          # オーケストレータ（~200行）
└── agents/
    ├── infra-phase-1-hearing.md              # Phase 1: ヒアリング
    ├── infra-phase-2-supabase.md             # Phase 2: Supabase（Playwright MCP利用）
    ├── infra-phase-3-vercel.md               # Phase 3: Vercel
    ├── infra-phase-4-github-actions.md       # Phase 4: GHAワークフロー生成
    └── infra-phase-5-finalize.md             # Phase 5: .env.local仕上げ+サマリー
```

**SKILL.md（オーケストレータ）の責務:**
- ユーザーへの挨拶と全体フロー説明
- 前提条件チェック（CLI有無、認証状態、Playwright MCP 利用可否）
- state ファイルの初期化
- Phase 1〜5 を順に Agent 呼び出し（`subagent_type: infra-phase-N-*`）
- 各 Phase 完了後にユーザー確認を挟む
- 全体完了時にサマリー表示

**state 受け渡し:**
- 場所: `/tmp/infra-setup-state.md`（プロジェクト外、セッション限り）
- 形式: Markdown（セクション毎に Phase 名、各 Agent が Read/Edit）
- ライフサイクル: 完了時削除、中断時は次回再開可能な状態で残す
- 管理責任: 各 Agent が自 Phase のセクションのみ追記する。オーケストレータは初期化と最終削除のみ

**state ファイル例:**
```markdown
# Infra Setup State

## Phase 1 (Hearing)
- project_name: my-app
- custom_domain: my-app.com
- gmail: user@gmail.com
- region: ap-northeast-1
- repo: owner/my-app

## Phase 2 (Supabase)
- dev_project_ref: abc123
- prod_project_ref: xyz789
- access_token: sbp_****
- dev_db_password: ****
- prod_db_password: ****

## Phase 3 (Vercel)
- vercel_org_id: team_xxx
- vercel_project_id: prj_xxx
- vercel_token: (Phase 4 で取得)
...
```

**なぜ Agent 分割か（Skill 分割との比較）:**
- コンテキスト分離: 各 Phase が fresh context で動作、親（SKILL.md）には結果サマリのみ返る
- token消費: 重い Phase（特に Playwright MCP を使う Phase 2）が親コンテキストを圧迫しない
- モデル切替: Phase 別に haiku/sonnet を選択可能（longrun パターンと同様）
- longrun プラグインとの設計思想の一貫性

**代替案:**
- 単一 SKILL.md に全部詰める → 500行超・毎回フルロード、却下
- Skill 分割（Phase ごとに独立 skill） → コンテキスト分離弱い、モデル切替不可、却下

## Risks / Trade-offs

- **[Playwright MCP依存]** Supabaseアカウント作成にブラウザ操作が必要 → Playwright MCPが利用可能であることを前提条件として明記。利用不可の場合は手動手順を案内するフォールバック。
- **[Gmail+エイリアス前提]** Gmail以外のメールでは+エイリアスが使えない場合がある → ヒアリングでメールプロバイダを確認し、非Gmail時は手動アカウント作成を案内。
- **[Vercel CLI認証]** `vercel login` が必要 → スキル実行前の前提条件チェックで確認。
- **[staging/prod同一DB]** staging検証とprod運用が同じDB → 意図的な設計判断。本番DBで動作確認したいという要件のため。staging で破壊的操作をすると prod に直接影響する点は完了サマリーで警告。
- **[local→dev DB 直接参照]** Docker不要でシンプルだが、個人開発前提。複数人 or 並行worktreeでは local→dev DB 経由の相互破壊リスクあり。**スキル完了時にこの前提を明示**。
- **[2回ビルド]** staging/prod が別ビルドのため理論的にビルド時刻差リスクあり。`npm ci` + lockfile + Node固定で実用上ほぼ問題なし。OAK Casino で実績あり。
- **[PR Preview なし]** PR時は CI のみ、自動Preview deploy なし → 個人開発で十分との判断。複数人開発に拡張する際は `deploy-preview.yml` 追加の余地を残す。
