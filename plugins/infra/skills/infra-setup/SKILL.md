---
name: infra-setup
description: 新規/既存 Web アプリに Vercel + Supabase + GitHub Actions のデプロイ基盤を 5 フェーズで一括構築する。「インフラを構築」「デプロイ環境を作って」「Vercel と Supabase のセットアップ」「本番デプロイ環境を用意して」で起動。
version: 0.5.7
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

# Infra Setup — Vercel + Supabase + GitHub Actions 一括セットアップ

ローカルで開発した Web アプリを本番対応するための定型作業（Supabaseプロジェクト作成、Vercelセットアップ、GitHub Actions ワークフロー生成、環境変数配線）を対話的に完遂するスキル。

## このスキルがメインセッションで動く理由

このSkillはメインセッションでInline実行される。これにより `Agent` ツールで各 Phase のサブエージェント（`infra-phase-1-hearing` ～ `infra-phase-5-finalize`）を呼び出せる。サブエージェントはサブエージェントを生成できないため、orchestrator は必ずメインセッション側で動く。

## アーキテクチャ

```
/infra-setup → infra-setup (Skill, メインセッションで Inline 実行)
  ↓ 前提条件チェック → state 初期化
  ↓ Agent ツール呼び出し
  ├── infra-phase-1-hearing         ← プロジェクト情報ヒアリング
  ├── infra-phase-2-supabase        ← Supabase dev/prod プロジェクト作成
  ├── infra-phase-3-vercel          ← Vercel セットアップ + vercel.json
  ├── infra-phase-4-github-actions  ← CI + deploy-preview + deploy-staging + deploy-production + migrate-production
  └── infra-phase-5-finalize        ← .env.local 仕上げ + 動作確認 + サマリー
  ↓ state ファイル削除
```

各 Phase は独立コンテキストで動き、`/tmp/infra-setup-state.md` を通じて情報を受け渡す。

## 環境構成（完成形）

| 環境 | URL | Supabase | ビルド起動元 |
|---|---|---|---|
| local | localhost | dev（リモート） | `next dev`（ローカル） |
| staging | `*-git-main-*.vercel.app` | **prod** | GitHub Actions（main push） |
| prod | カスタムドメイン | prod | GitHub Actions（`workflow_dispatch`） |

**ポイント:** Vercel の Git 自動連携は `vercel.json` で OFF にし、全デプロイを GitHub Actions で制御する。staging と prod は同じ prod DB を参照するため、staging で本番に近い状態を確認できる。PR は Draft + Ready for review 方式で、Draft 中は CI を skip し、Ready for review で CI が発火する。Preview deploy は opt-in で、PR に `preview` ラベルを貼ったときだけ実行される（Draft 中でも動く）。ラベルが付いている間は push のたびに同じ URL が更新され、剥がすと停止する。

## 前提条件チェック（Phase 0）

Phase 1 に入る前に以下を順次確認する。不足があれば即座にユーザーに案内して中断する。

### 0.1 CLI 存在チェック

```bash
command -v npx && npx supabase --version 2>&1 | head -1
command -v vercel || npm i -g vercel >/dev/null  # 未導入時のみ
vercel --version
command -v gh && gh --version | head -1
command -v jq
```

いずれかが失敗したら以下を案内して中断:
- Supabase CLI: `npm i -g supabase` か `npx supabase` で使える状態にする
- Vercel CLI: `npm i -g vercel`
- GitHub CLI: `brew install gh` or `https://cli.github.com/`
- jq: `brew install jq`

### 0.2 CLI 認証チェック

```bash
vercel whoami
gh auth status
```

未認証の場合、それぞれ `vercel login` / `gh auth login` をユーザーに実行してもらってから再開。

### 0.3 Playwright MCP 利用可否

`mcp__playwright__*` 系のツールが存在するか、もしくは `mcp__claude-in-chrome__*` が存在するかを判定し、state に `playwright_mcp_available: true/false` を記録する。利用不可でも中断はせず、Phase 2 / Phase 4 でフォールバック手順に切り替える。

### 0.4 既存 `supabase-project-setup` スキルの検出

```bash
[ -d ~/.claude/skills/supabase-project-setup ] && echo EXISTS
```

存在する場合は Phase 0 セクションの `existing_supabase_skill: true` として記録。削除案内は Phase 5 Agent が実施するため、ここでは案内を行わない（Phase 5 でまとめて処理することで重複を避ける）。

### 0.5 Node.js バージョン検出

```bash
jq -r '.engines.node // "22"' package.json 2>/dev/null || echo "22"
```

`package.json` の `engines.node` から Node バージョンを抽出。`>=20` のような range 指定の場合は、数字部分だけ取り出す（例: `>=20` → `20`）。取れない場合はデフォルト `22`。state の `node_version_detected` に記録する。Phase 4 でワークフロー生成時に使用する。

## state ファイル管理

- **パス**: `/tmp/infra-setup-state.md`
- **形式**: Markdown（セクション単位で各 Phase が Read/Edit）
- **初期化**: Phase 1 開始前にオーケストレータが作成（テンプレ書き込み）
- **更新**: 各 Agent が自 Phase セクションのみ Edit で追記する
- **削除**: Phase 5 完了時にオーケストレータが削除
- **再開**: 既存 state ファイルが残っていた場合、「前回のセットアップを再開しますか？」を AskUserQuestion で確認

state ファイルの具体的なテンプレート（Phase 0 含む）は「実行フロー Step 3」参照。各 Phase が完了すると該当セクションの `<!-- pending -->` 行は具体的な値に置き換わる。セクション行を見れば Phase が完了しているかが判別できる。

## 実行フロー

**順序は厳守**: 前提条件チェックを先に行う。再開判定は前提が満たされた後で行わないと、state に中途半端な Phase 0 セクションが残って事故の元になる。

### Step 1: 前提条件チェック（Phase 0）

上記 0.1 〜 0.4 を順に実行。失敗時は即座にユーザーに案内して中断（state ファイルには触らない）。成功時は結果を一時変数として保持（まだ state には書かない。Step 3 で初期化時にまとめて書く）。

### Step 2: 再開判定

```
IF /tmp/infra-setup-state.md が既に存在する
  → 内容を Read し、どの Phase まで完了しているか判定
  → AskUserQuestion で以下を選択:
    - 前回の続きから再開（保留中の Phase N から）
    - 最初からやり直す（state削除 → Step 3 へ）
    - 中止（state 保持、終了）
  → 「再開」選択時: 保持されている Phase 0 セクションを Step 1 の結果で上書き（Edit）
ELSE
  → Step 3 に進む
```

### Step 3: state ファイル初期化（新規時のみ）

以下のテンプレートで state ファイルを Write する:

```markdown
# Infra Setup State

## Phase 0 (Prerequisites)
- cli_ok: true
- vercel_auth: ok (user: {whoami})
- gh_auth: ok
- playwright_mcp_available: {true|false}
- existing_supabase_skill: {true|false}
- node_version_detected: {package.json の engines.node から抽出、無ければ "22"}

## Phase 1 (Hearing)
<!-- pending -->

## Phase 2 (Supabase)
<!-- pending -->

## Phase 3 (Vercel)
<!-- pending -->

## Phase 4 (GitHub Actions)
<!-- pending -->

## Phase 5 (Finalize)
<!-- pending -->
```

### Step 4: Phase 1 〜 5 を順次実行

各 Phase は以下のパターンで呼び出す:

```
1. 該当 Phase が未完了なら Agent 呼び出し:
   Agent({
     description: "Phase N: <Phase名>",
     subagent_type: "infra-phase-N-<name>",
     prompt: "state ファイル /tmp/infra-setup-state.md を参照して Phase N を実行してください。完了時は state ファイルの該当セクションを必ず更新してください。"
   })
2. Agent 完了後、state ファイルの該当セクションが更新されているか検証
3. AskUserQuestion で「次に進む」「見直す」「中断」を確認
4. 「次に進む」を選択したら次の Phase へ
```

**Phase 2 スキップの扱い:**
Phase 1 Agent は「Supabase セットアップ済みか？」をヒアリング項目に含め、`supabase_already_setup: true/false` を state に記録する。true の場合、Phase 1 Agent が既存 URL / ANON_KEY / REF を追加ヒアリングし、オーケストレータは Phase 2 を**スキップ**して Phase 3 に進む（Phase 2 Agent は呼び出さない）。

### Step 5: 完了処理（Phase 5 Agent 側で実施）

既存 `supabase-project-setup` スキルの削除案内は **Phase 5 Agent が実施する**（オーケストレータはこれを行わない）。これにより削除ロジックが重複せず、Phase 5 Agent の完了サマリーの一部として自然に組み込まれる。

### Step 6: state ファイル削除

Phase 5 完了後、オーケストレータが以下を実行:

```bash
rm /tmp/infra-setup-state.md
```

Phase 5 Agent が表示した最終サマリーをユーザーに再確認してもらって終了。

## Agent 呼び出しの具体例

```
Agent({
  description: "Phase 1: プロジェクト情報ヒアリング",
  subagent_type: "infra-phase-1-hearing",
  prompt: "新規プロジェクトのインフラセットアップを開始します。state ファイル /tmp/infra-setup-state.md の ## Phase 1 (Hearing) セクションに結果を書き込んでください。\n\n現在のディレクトリ: {$PWD}"
})
```

エージェントは `/tmp/infra-setup-state.md` を自分で Read / Edit して、結果をセクションに追記する。オーケストレータは Agent 完了後に state を再度 Read して次 Phase に進めるか判断する。

## フェーズ間のユーザー確認

各 Phase 完了時、以下のような AskUserQuestion を表示:

```
質問: Phase {N} ({Phase名}) が完了しました。次に進みますか？
選択肢:
- 次に進む (Phase {N+1} を開始)
- 内容を見直す (state の該当セクションを表示 → 再実行判断)
- 中断する (state を保持したまま終了 → 次回再開可能)
```

確認なしで進むと、Supabase プロジェクト作成ミスや Vercel 環境変数設定ミスなど、後戻りコストの大きい操作が連続実行されるため、必ず各 Phase 終わりで止まる。

## 中断時の挙動

- ユーザーが「中断する」を選択、または Ctrl+C 等で中断した場合:
  - state ファイルは**削除しない**（再開用）
  - オーケストレータは「`/infra-setup` で再開できます」と案内
- 次回 `/infra-setup` 実行時、Step 1 の再開判定で検出される

## エラーハンドリング

各 Phase Agent が失敗・不完全終了した場合:

1. state の該当セクションが更新されていない → 失敗と判定
2. ユーザーに状況を説明し、`AskUserQuestion` で「再実行」「スキップ」「中断」を選択
3. 「再実行」: 同じ Agent をもう一度呼び出す
4. 「スキップ」: state に `skipped: true` を書き、次 Phase へ（推奨しないため警告）
5. 「中断」: state 保持したまま終了

## 技術メモ

- **Gmail +エイリアス**: `user+tag@gmail.com` は `user@gmail.com` に配信される。Supabase は `+` エイリアスを別アドレスとして扱うので、Free tier 2プロジェクト制限を回避できる。
- **Supabase Free tier 制限**: アクティブ 2 プロジェクトまで（アカウント単位）。だから「1プロジェクト = 1アカウント」運用にする。
- **`.env.local` と `.mcp.json` は必ず `.gitignore` に含める**。Phase 2 でこれを検証する。
- **DB パスワード**: `openssl rand -base64 24 | tr -d '/+='` で生成する。Supabase CLI の `--db-password` で指定。
- **Vercel Token**: ダッシュボード手動生成のみ（`vercel login` では取得できない）。Playwright MCP でダッシュボードを自動操作するか、ユーザーに案内する。CLI 化は検証済み: 2026-07-03 時点で Vercel CLI 48.x に `tokens`/`token` サブコマンドは存在せず、CLI 化不可と確認済み。

## トラブルシューティング

### Free tier 制限エラー
```
maximum limits for the number of active free projects
```
→ アカウントあたりアクティブ 2 プロジェクトまで。別エイリアスで新アカウント作成で回避（このスキルが実施する運用の根拠）。

### `+` エイリアスが認識されない
→ RFC 5321 準拠の有効なメールアドレス。Supabase は `+` を別アドレスとして扱う（GitHub Issue #39254 で確認済み）。

### MCP server パッケージ名
→ 正しいパッケージ名: `@supabase/mcp-server-supabase`（`@supabase/mcp-server` ではない）。

### Vercel の Preview / Production 環境変数の挙動
→ Vercel の Preview env vars と Production env vars は独立した設定枠。`vercel pull --environment=preview` / `--environment=production` でどちらを引き抜くか選べる。staging ワークフローは `--environment=preview`、production ワークフローは `--environment=production` を使う。

## CI/CD 構成の 2 軸（省エネ CI 設計）

Phase 1 で「開発形態（solo / solo-agent / team）」と「プロダクトステージ（pre-release / released）」を
ヒアリングし、Phase 4 の生成内容を変える。2026-07 に suimei で Actions free 枠 2,000 分/月を
5 日で使い切った反省が起点。判断基準は「誰が守るか」「壊れたら誰が困るか」。

| ステージ | 生成されるワークフロー | 思想 |
|---|---|---|
| pre-release | deploy-on-merge.yml + migrate-production.yml のみ | 実利用者ゼロ。マージ = 本番反映の最短経路。防衛線はローカル pre-push hook（Tier 0） |
| released | ci.yml（軽量 Tier 1）/ weekly-full.yml（Tier 3）/ deploy-preview / deploy-staging / deploy-production（preflight = Tier 2）/ migrate-production | PR は 5 分以内の軽いチェック、フルテストは週次 + 本番デプロイ直前 |

- solo-agent（エージェント自動マージ）は人間レビューが無い分、PR CI がレビューの代替 = マージゲートとして必須
- 全ワークフローの `runs-on` は `${{ vars.CI_RUNNER || 'ubuntu-latest' }}`。free 枠を使い切ったら
  セルフホストランナー登録 + repo variable `CI_RUNNER=self-hosted` で無課金継続、月初に variable を消して復帰
- **昇格**: pre-release → released は `/infra-setup` を再実行して released を選ぶ。
  Phase 4 が deploy-on-merge.yml の削除を提案し、フルセットに置き換える

## 参考: 関連ドキュメント

- Vercel CLI: https://vercel.com/docs/cli
- Supabase CLI: https://supabase.com/docs/guides/cli
- GitHub Actions: https://docs.github.com/actions

## 自己検証

完了宣言の前に、infra 成果物の evidence を確認する（原則: `plugins/dev-workflow/references/self-verification.md`）。

- 生成した `vercel.json` が妥当な JSON であることを確認する: `jq . vercel.json` が exit 0。
- GitHub Actions ワークフロー（deploy-preview / deploy-production / migrate-production 等）が `.github/workflows/` に生成され、YAML として妥当であることを確認する。
- 環境変数配線（Supabase dev/prod・Vercel）が設定され、preview デプロイが成功することを確認する。
