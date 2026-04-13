## ADDED Requirements

### Requirement: スキルはフェーズベースの対話型セットアップを提供する
スキル `/infra-setup` は、5つのフェーズを順に進行し、各フェーズ終了時にユーザー確認を挟む対話型のインフラセットアップを提供 SHALL する。フェーズは Phase 1: ヒアリング → Phase 2: Supabase → Phase 3: Vercel → Phase 4: GitHub Actions → Phase 5: ローカル環境仕上げ の順で進行 SHALL する。

#### Scenario: 全フェーズを順に実行
- **WHEN** ユーザーが `/infra-setup` を実行する
- **THEN** Phase 1 のヒアリングから開始し、各フェーズ完了後にユーザー確認を求めてから次のフェーズに進む

#### Scenario: 特定フェーズのスキップ
- **WHEN** ユーザーが既にSupabaseセットアップ済みと回答する
- **THEN** Phase 2 をスキップし、既存のSupabase情報をヒアリングしてPhase 3 に進む

### Requirement: Phase 1 でプロジェクト情報をヒアリングする
Phase 1 はプロジェクト名、ドメイン、メールアドレス、リージョンなど、後続フェーズに必要な情報を収集 SHALL する。

#### Scenario: 必須項目のヒアリング
- **WHEN** Phase 1 が開始される
- **THEN** プロジェクト名（kebab-case）、カスタムドメイン、メールアドレス、Supabaseリージョン（デフォルト: ap-northeast-1）をユーザーに確認する

#### Scenario: メールプロバイダと +エイリアス対応確認
- **WHEN** メールアドレスが Gmail 以外である
- **THEN** そのプロバイダが +エイリアス（`user+tag@example.com`）をサポートするかユーザーに確認する。サポートされない場合は「メインアカウントを直接使用するか、プロジェクト専用の別メールアドレスを用意するか」をユーザーに選択させ、選択内容を state に保存する

#### Scenario: GitHub リポジトリの確認
- **WHEN** ヒアリングを行う
- **THEN** 現在のディレクトリのGitリモート設定を確認し、GitHub リポジトリが紐付いているか検出する。未設定の場合はリポジトリ作成を案内する。

### Requirement: Phase 2 で Supabase 環境をセットアップする
Phase 2 は Gmail+エイリアスで専用Supabaseアカウントを作成し、CLIで Dev/Prod プロジェクトを構築 SHALL する。

#### Scenario: 新規Supabaseアカウント作成
- **WHEN** Phase 2 が開始される
- **THEN** `{gmail_user}+{project_name}-supa@gmail.com` のエイリアスを生成し、Playwright MCPでSupabaseアカウントを作成し、メール確認をユーザーに依頼する

#### Scenario: Access Token 取得
- **WHEN** アカウント作成とメール確認が完了する
- **THEN** Playwright MCPでダッシュボードからAccess Tokenを生成・取得し、`.env.local` の `SUPABASE_ACCESS_TOKEN` として保存する

#### Scenario: Organization の作成または取得
- **WHEN** Access Token が取得できる
- **THEN** `supabase orgs list` で既存 Organization を確認し、プロジェクト専用 Org が無ければ `supabase orgs create {project}-org` で作成する。取得した `ORG_ID` を state に保存する

#### Scenario: Dev/Prod プロジェクト作成
- **WHEN** Organization が確定する
- **THEN** Supabase CLI で `{project}-dev` と `{project}-prod` の2プロジェクトを `--org-id {ORG_ID}` 指定で作成し、`PROJECT_REF` と API Keys（URL / ANON_KEY）を取得する

#### Scenario: DB パスワードの生成と保存
- **WHEN** プロジェクト作成時
- **THEN** Dev/Prod それぞれの DB パスワードを生成（または CLI 出力を取得）し、`.env.local` に `SUPABASE_DB_PASSWORD_DEV` / `SUPABASE_DB_PASSWORD_PROD` として保存する。`.env.local` が `.gitignore` に含まれることを検証する

#### Scenario: Supabase 環境変数の .env.local への書き込み
- **WHEN** API Keys が取得できる
- **THEN** `.env.local` に以下のキーを書き込む:
  - `NEXT_PUBLIC_SUPABASE_URL`（dev プロジェクトの URL）
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`（dev プロジェクトの ANON_KEY）
  - `SUPABASE_DEV_REF` / `SUPABASE_PROD_REF`（両プロジェクトの ref）

#### Scenario: Supabase MCP設定
- **WHEN** プロジェクト作成が完了する
- **THEN** `.mcp.json` に `@supabase/mcp-server-supabase` の設定を追加する

#### Scenario: Playwright MCP が利用不可
- **WHEN** Playwright MCPが使用できない
- **THEN** 手動でのアカウント作成・Token取得手順をユーザーに案内し、情報を入力してもらって続行する

### Requirement: Phase 3 で Vercel 環境をセットアップする
Phase 3 は Vercel CLI でプロジェクトを作成し、環境変数・ドメイン・Git連携無効化を実施 SHALL する。

#### Scenario: Vercel CLI 認証チェック
- **WHEN** Phase 3 が開始される
- **THEN** `vercel whoami` で認証状態を確認し、未認証の場合は `vercel login` を案内する

#### Scenario: Vercel プロジェクト作成とリンク
- **WHEN** 認証が確認できる
- **THEN** `vercel link` でプロジェクトを作成し、GitHubリポジトリと連携する

#### Scenario: Vercel Git 自動連携を無効化
- **WHEN** プロジェクトがリンクされる
- **THEN** プロジェクトルートに `vercel.json` を生成し、`"github": { "enabled": false }` を設定する（既存 `vercel.json` がある場合はマージする）。これにより Vercel 側の Git push 自動デプロイが停止し、全デプロイを GitHub Actions が制御する状態になる

#### Scenario: 環境変数の設定
- **WHEN** Vercel.json の Git 連携無効化が完了する
- **THEN** Vercel環境変数の **Preview** および **Production** の両方に prod Supabase の `NEXT_PUBLIC_SUPABASE_URL` と `NEXT_PUBLIC_SUPABASE_ANON_KEY` を設定する。`vercel env add` コマンドを使用する。dev Supabase の値は Vercel には設定しない（local の `.env.local` のみで使用）

#### Scenario: カスタムドメインの設定（prodのみ）
- **WHEN** ユーザーがカスタムドメインを指定している
- **THEN** `vercel domains add` でドメインを追加し、**Production deployment にのみ**紐付ける。staging（Preview deployment）には紐付けず Vercel 自動URLで運用する。DNS設定手順をユーザーに案内する

### Requirement: Phase 4 で GitHub Actions を設定する
Phase 4 は CI（test/lint/type-check）、staging 自動デプロイ、production 手動デプロイ、production 手動マイグレーションの4ワークフローファイルを生成 SHALL し、必要な GitHub Secrets を自動投入 SHALL する。

#### Scenario: CI ワークフロー生成
- **WHEN** Phase 4 が開始される
- **THEN** `.github/workflows/ci.yml` を生成する。`pull_request` イベントで test / lint / type-check を実行する内容とする

#### Scenario: staging デプロイワークフロー生成
- **WHEN** CI ワークフロー生成が完了する
- **THEN** `.github/workflows/deploy-staging.yml` を生成する。`push: branches: [main]` トリガーで以下を実行する内容とする:
  - `vercel pull --yes --environment=preview --token=${VERCEL_TOKEN}`
  - `vercel build --token=${VERCEL_TOKEN}`
  - `vercel deploy --prebuilt --token=${VERCEL_TOKEN}` （`--prod` フラグなし、Preview deployment として作成）
  - `concurrency: { group: staging-deploy, cancel-in-progress: true }` を設定

#### Scenario: production デプロイワークフロー生成
- **WHEN** staging ワークフロー生成が完了する
- **THEN** `.github/workflows/deploy-production.yml` を生成する。`workflow_dispatch` トリガー（`inputs.confirm: boolean` 必須）で以下を実行する内容とする:
  - `confirm` が `true` でない場合は早期 `exit 1`
  - `vercel pull --yes --environment=production --token=${VERCEL_TOKEN}`
  - `vercel build --prod --token=${VERCEL_TOKEN}`
  - `vercel deploy --prebuilt --prod --token=${VERCEL_TOKEN}`（Production deployment、カスタムドメインに自動紐付け）
  - `concurrency: { group: production-deploy, cancel-in-progress: false }` を設定
  - `environment: { name: Production }` を設定し、GitHub UI からの approval gate を有効化可能にする

#### Scenario: production マイグレーションワークフロー生成
- **WHEN** production デプロイワークフロー生成が完了する
- **THEN** `.github/workflows/migrate-production.yml` を生成する。`workflow_dispatch` トリガー（`inputs.confirm: boolean` 必須）で以下を実行する内容とする:
  - `confirm` が `true` でない場合は早期 `exit 1`
  - Supabase CLI セットアップ
  - `supabase link --project-ref ${{ secrets.SUPABASE_PROD_REF }}` 実行
  - `supabase db push --linked` 実行
  - `environment: { name: Production }` を設定（approval gate 対応）
  - デプロイワークフローとは独立して実行可能であり、互換性のあるスキーマ変更先行→デプロイ、の運用に対応できる

#### Scenario: GitHub Secrets の自動設定
- **WHEN** ワークフローファイルを生成する
- **THEN** 必要な GitHub Secrets を取得・設定する:
  - `VERCEL_TOKEN`: Playwright MCPで Vercel ダッシュボード（https://vercel.com/account/tokens）から新規生成、取得した値を `gh secret set VERCEL_TOKEN` で投入
  - `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID`: `.vercel/project.json` から `jq -r .orgId` / `jq -r .projectId` で抽出し、`gh secret set` で投入
  - `SUPABASE_ACCESS_TOKEN`: `.env.local` から読み込み、`gh secret set` で投入（`supabase link` 実行に必要）
  - `SUPABASE_PROD_REF`: Phase 2 で保存した prod プロジェクト ref を `gh secret set` で投入（`migrate-production.yml` が使用）
  - `SUPABASE_DB_PASSWORD_PROD`: Phase 2 で保存した prod DB パスワードを `gh secret set` で投入（`supabase db push` が使用）
  - Playwright MCP 利用不可時は手動取得手順を案内し、ユーザーに値を入力してもらう

### Requirement: Phase 5 でローカル開発環境を仕上げる
Phase 5 は `.env.local` の最終検証、`supabase link`、`next dev` 動作確認案内、完了サマリー表示を実施 SHALL する。local はリモートの dev Supabase を参照 SHALL し、ローカルDB（`supabase start`）は起動 MUST NOT する。

#### Scenario: ローカル環境設定
- **WHEN** Phase 5 が開始される
- **THEN** Phase 2 で書き込み済みの `.env.local` 内容を確認し、`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` がリモート**dev**プロジェクトの値になっていることを検証する。`npx supabase link --project-ref {DEV_REF}` を実行する（マイグレーション管理用）。`supabase start` は実行しない

#### Scenario: `next dev` 動作確認の案内
- **WHEN** `supabase link` が完了する
- **THEN** `npm run dev` （または `next dev`）でローカルサーバーを起動し、Supabase dev プロジェクトへの接続が成立することを確認する手順をユーザーに案内する

#### Scenario: セットアップ完了サマリー
- **WHEN** 全フェーズが完了する
- **THEN** 以下を含むサマリーを表示する:
  - 環境一覧（local / staging / prod）と各環境のURL（local: localhost、staging: `*-git-main-*.vercel.app`、prod: カスタムドメイン）
  - Supabase接続先（local: dev、staging+prod: prod）
  - prod 昇格手順（GitHub Actions UI → `Deploy to Production` → `confirm: true` で `Run workflow`）
  - 警告: 「**staging は prod DB を直接参照**するため、staging で破壊的操作（DB drop、destructive migration等）を行うと本番に直接影響する」
  - 警告: 「**local は dev DB を直接参照**するため、`supabase db reset` / `db push` 等は dev に即反映される。複数人開発・並行worktreeでは `supabase start` ローカルDBへの切替を検討」
  - PR時は CI のみ実行され Preview deploy は走らない旨

### Requirement: スキルは Agent オーケストレーション構造で実装される
本スキルは SKILL.md をオーケストレータとし、各 Phase を独立した Agent ファイルとして実装 SHALL する。longrun プラグインのパターンに従う。

#### Scenario: プラグイン構造
- **WHEN** スキルを作成する
- **THEN** 以下のファイル構造で作成する:
  - `plugins/infra/.claude-plugin/plugin.json`（プラグイン定義、skill と agents を登録）
  - `plugins/infra/skills/infra-setup/SKILL.md`（オーケストレータ）
  - `plugins/infra/agents/infra-phase-1-hearing.md`
  - `plugins/infra/agents/infra-phase-2-supabase.md`
  - `plugins/infra/agents/infra-phase-3-vercel.md`
  - `plugins/infra/agents/infra-phase-4-github-actions.md`
  - `plugins/infra/agents/infra-phase-5-finalize.md`
- **AND** `.claude-plugin/marketplace.json` の `plugins` 配列に `infra` プラグインを追加する

#### Scenario: オーケストレータの責務
- **WHEN** `/infra-setup` が実行される
- **THEN** SKILL.md は以下を実行する:
  - 前提条件チェック（CLI有無、認証状態、Playwright MCP 利用可否）
  - state ファイル `/tmp/infra-setup-state.md` の初期化
  - Phase 1〜5 を順に Agent 呼び出し（`subagent_type: infra-phase-N-*`）
  - 各 Phase 完了後にユーザー確認を挟む
  - 全体完了時に state ファイルを削除

#### Scenario: state ファイルによる Phase 間の情報受け渡し
- **WHEN** 各 Phase の Agent が実行される
- **THEN** Agent は `/tmp/infra-setup-state.md` を Read で読み込み、自 Phase のセクション（例: `## Phase 2 (Supabase)`）に結果を Edit で追記する。他 Phase のセクションは変更しない
- **AND** 中断時は state ファイルを残し、次回 `/infra-setup` 実行時に「続きから再開するか」をユーザーに確認する

### Requirement: 前提条件を実行前にチェックする
オーケストレータ（SKILL.md）は Phase 1 に入る前に、必要な CLI・認証・MCP の存在を確認 SHALL する。不足時は適切な案内をして処理を中断 SHALL する。

#### Scenario: CLI の存在チェック
- **WHEN** `/infra-setup` が実行される
- **THEN** Supabase CLI (`npx supabase --version`)、Vercel CLI (`vercel --version`)、GitHub CLI (`gh --version`)、`jq` の存在を確認し、不足があればインストール手順を案内して中断する

#### Scenario: CLI の認証状態チェック
- **WHEN** CLI の存在確認が完了する
- **THEN** `vercel whoami` と `gh auth status` を実行し、未認証の場合は `vercel login` / `gh auth login` を案内して中断する

#### Scenario: Playwright MCP の利用可否チェック
- **WHEN** CLI 認証チェックが完了する
- **THEN** Playwright MCP が利用可能か判定し、state ファイルに `playwright_mcp_available: true/false` を記録する。利用不可の場合でも中断はせず、Phase 2 / Phase 4 でフォールバック手順に切り替える

### Requirement: 既存 `supabase-project-setup` スキルを廃止する
本スキルは `~/.claude/skills/supabase-project-setup/` の機能を統合吸収 SHALL し、ユーザー環境に旧スキルが残存する場合は削除案内を提示 SHALL する。

#### Scenario: 既存スキルの deprecated 案内
- **WHEN** `/infra-setup` 初回実行時に `~/.claude/skills/supabase-project-setup/` が存在する
- **THEN** 「このスキルは `infra-setup` に統合されました。`~/.claude/skills/supabase-project-setup/` は削除して問題ありません」とユーザーに案内し、削除するかをユーザーに確認する
- **AND** 本 change のドキュメント（README または proposal）に、手動削除手順を明記する
