---
name: agent-owner-setup
description: 任意のプロジェクトを「エージェントオーナープロジェクト（AI自動運営モード）」として立ち上げる。開発エージェント + マーケエージェントが有料プロダクトを自動運営する仕組み（genetta-inc/suimei で実証済み）をテンプレート展開する。「エージェントオーナープロジェクト化」「AI自動運営モードにして」「エージェント運営のセットアップ」「プロダクトを自動運営させたい」「auto-merge ロボットを導入」で起動。
version: 0.1.0
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill, AskUserQuestion
---

# Agent Owner Setup — エージェントオーナープロジェクト化（v0 仮）

任意の Web プロダクトを、開発エージェントとマーケエージェントが自律運営する「エージェントオーナープロジェクト」として立ち上げるオーケストレーター。genetta-inc/suimei での実証結果（Layer 0 マージ自動化・staging スモーク・auto-revert・運営責任設計）をテンプレート化したもの。

**本スキルは v0（仮版）。動く最小構成 + 実証済み資産の同梱を優先する。**

## テンプレ駆動運用の原則

このプラグインは「まずテンプレを作り、うまくいかない点が出たらテンプレ側を直す」運用（オーナー方針 2026-07-13）で育てる。

- 展開先のプロジェクトで問題（バグ・前提の齟齬・命名の食い違い等）が見つかっても、**展開先だけを個別に手直しして終わらせない**。まずここ（`plugins/agent-owner/`）を直す PR を出し、次回以降の展開で同じ問題が再発しないようにする
- v0 は仮版であるため、フェーズの粒度や自動化の範囲は今後変わる前提。判断に迷った箇所は完了報告に明記する

## 全体像

```
Phase 0: ヒアリング
Phase 1: インフラ           → /infra:infra-setup を起動
Phase 2: 開発自律ループ     → /loops:dev-agent-install を起動
Phase 3: Layer 0 マージ自動化 → 本プラグインの templates/ を配線
Phase 4: 運営責任           → 窓口 + 法務ドラフト生成
Phase 5: マーケ運転         → /sns-autopilot:sns-autopilot-setup を起動（SNS運用ありの場合）
Phase 6: 教訓ログとマスタープラン
```

各フェーズの完了後、AskUserQuestion で「次に進む」「見直す」「中断する」を確認してから次に進む（後戻りコストの大きい操作が連続するため）。

## Phase 0: ヒアリング

AskUserQuestion で以下を確定する:

| 項目 | 備考 |
|---|---|
| プロダクト名 | 窓口メールアドレスやドキュメントのタイトルに使う |
| ドメイン | 本番ドメイン。Phase 4 の窓口セットアップで使う |
| GitHub リポジトリ | `owner/repo` 形式。`gh repo view --json owner,name` で自動検出を試みて確認だけにする |
| 課金の有無 | あり/なし。なしなら Phase 4 の返金・引当まわりのドラフトはスキップし、窓口とインシデント対応のみにする |
| SNS 運用の有無 | あり/なしを聞く。ありなら Phase 5 を実行、なしならスキップ |

以降のフェーズはここで確定した値を使う。

## Phase 1: インフラ

Vercel + Supabase + GitHub Actions の基盤を構築する。既存の infra プラグインをそのまま起動する:

```
Skill({ skill: "infra:infra-setup" })
```

**Phase 3 との依存関係**: Phase 3 の staging スモークは `deploy-staging.yml` が生成する `Deploy to Staging` という名前のワークフローの完了イベントを購読する。infra プラグインのテンプレートはこの名前で固定されているため、Phase 1 を先に完了させてから Phase 3 に進むこと（この順序は本フロー内で強制されている）。

Phase 1 がすでに完了しているプロジェクト（infra-setup 済み）であれば、ヒアリングで確認のうえスキップしてよい。

## Phase 2: 開発自律ループ

GitHub Issues をタスクキューにした自律開発ループを導入する。既存の loops プラグインを起動する:

```
Skill({ skill: "loops:loops-dev-agent-install" })
```

これにより憲法ファイル `docs/agent-loop.md`、GitHub ラベル一式、issue テンプレート、`.claude/settings.json` の permission deny、pre-push フックが導入される。Phase 3 はこの `.claude/settings.json` にさらに deny を追記する形になる。

## Phase 3: Layer 0 マージ自動化

「開発の責任」の権限側（誰が何の条件でマージしてよいか）を機械判定に落とし込む。LLM に `gh pr merge` を許す代わりに、GitHub Actions のロボットが決定論的に判定する。

### 3.1 ワークフローの設置

`${CLAUDE_PLUGIN_ROOT}/templates/auto-merge.yml` と `${CLAUDE_PLUGIN_ROOT}/templates/staging-smoke.yml` を対象リポジトリの `.github/workflows/` にコピーする。

```bash
mkdir -p .github/workflows
cp "${CLAUDE_PLUGIN_ROOT}/templates/auto-merge.yml" .github/workflows/auto-merge.yml
cp "${CLAUDE_PLUGIN_ROOT}/templates/staging-smoke.yml" .github/workflows/staging-smoke.yml
```

### 3.2 聖域パスの調整

`auto-merge.yml` 内の `SACRED` 変数はプロジェクトに合わせて調整する。聖域の考え方は「**金・DB・法務・自己言及コア**」の4種:

- **金**: 価格ロジック・決済導線（例: `lib/pricing.ts` / `app/checkout/` 相当のパス）
- **DB**: マイグレーション（例: `supabase/migrations/` 相当）
- **法務**: 利用規約等の法務ページ（例: `app/legal/` 相当）
- **自己言及コア**: このマージ条件自体・憲法ファイル・`.claude/` 設定（例: `.github/workflows/` / `docs/agent-loop.md` / `CLAUDE.md` / `.claude/`）

最後の「自己言及コア」が最重要: エージェントが自分のマージ条件を書き換えて main に入れる経路を塞ぐのがこの設計の核心のため、ここは緩めない。`staging-smoke.yml` 内のスモークチェック対象パス（`check "/" ...` の行）もプロジェクトの代表的な導線（トップ・料金・規約ページ等）に書き換える。

### 3.3 permission deny の配線

`${CLAUDE_PLUGIN_ROOT}/templates/settings-permissions-deny.json` の内容を対象リポジトリの `.claude/settings.json` に**マージ**する（Phase 2 で loops プラグインがすでに一部の deny を入れているので、既存エントリを消さず重複を避けて追記する）。

### 3.4 ラベルの作成

```bash
gh label create "agent-review:passed" -c "#0E8A16" -d "レビュー合格。マージ判断待ち" --force
gh label create "human-merge"         -c "#5319E7" -d "聖域パス接触につき人間のマージ判断が必要" --force
gh label create "human-decision"      -c "#5319E7" -d "意思決定論点ありにつき人間の判断待ち" --force
```

（`agent-review:passed` は Phase 2 の loops プラグインがすでに作成している場合があるが、`--force` により冪等）

### 3.5 人間セットアップ3点

以下は人間にしかできない操作。案内して完了を確認する:

1. **`secrets.AUTOMERGE_PAT`**: fine-grained PAT を発行し、`contents: RW` + `pull-requests: RW` の権限で登録する。`GITHUB_TOKEN` でマージすると push イベントが `deploy-staging` を起動しないため、この PAT が必須（`gh secret set AUTOMERGE_PAT --repo {owner}/{repo}`）
2. **`vars.STAGING_DOMAIN`**: staging の固定ドメイン。未設定の間はスモークがスキップされ警告のみになる（`gh variable set STAGING_DOMAIN --repo {owner}/{repo} --body <domain>`）
3. **`secrets.VERCEL_AUTOMATION_BYPASS_SECRET`**: Vercel の Protection Bypass for Automation の secret。Deployment Protection を維持したままスモークを通すためのヘッダーに使う（`gh secret set VERCEL_AUTOMATION_BYPASS_SECRET --repo {owner}/{repo}`）

## Phase 4: 運営責任

### 4.1 サポート窓口

- 命名規則: `support-<slug>@<domain>`（ハイフン区切り。`<slug>` はプロダクト名から機械的に導出）
- **`+` ではなくハイフンを使う理由**: Cloudflare Email Routing は `+` サフィックスを完全一致解決しない（2026-07-13 に実弾で判明）うえ、`+` 入りアドレスは Web フォームの email バリデーションで弾かれることがある。ハイフンなら全メールシステムで安全に扱える
- **catch-all は使わず、個別ルーティングルール方式にする**: catch-all はドメイン宛のランダム送信・スパム攻撃をすべて受信してしまいスパム面が広い。新サービスごとに Cloudflare Email Routing に **個別ルール `support-<slug>@<domain>` → 集約先 Gmail** を1件作成する（ダッシュボードまたは Cloudflare API で作成。API 自動化が可能な場合は導入手順に含める）。ドメインの catch-all は無効のままにしておくことを推奨する
- 集約先 Gmail 側に `to:support-<slug>@<domain>` でこのアドレス宛のフィルタを作成する案内を行う（ラベル付け・優先度設定等）

### 4.2 法務・運営ドラフトの生成

以下 4 種のドラフトを生成する。参照実装は genetta-inc/suimei の `docs/legal-drafts/`（`terms-v2.md` / `legal-notes.md`）と `docs/ops/`（`incident-runbook.md` / `support-desk.md`）。構成・観点の参考にするために内容を取得してよい:

```bash
gh api repos/genetta-inc/suimei/contents/docs/legal-drafts/terms-v2.md --jq .content | base64 -d
gh api repos/genetta-inc/suimei/contents/docs/legal-drafts/legal-notes.md --jq .content | base64 -d
gh api repos/genetta-inc/suimei/contents/docs/ops/incident-runbook.md --jq .content | base64 -d
gh api repos/genetta-inc/suimei/contents/docs/ops/support-desk.md --jq .content | base64 -d
```

参照実装の条文・体制をそのまま流用せず、Phase 0 で確定したプロダクト名・ドメイン・課金有無に合わせて書き直したうえで、対象リポジトリに以下として出力する:

- `docs/legal-drafts/terms.md` — 利用規約ドラフト
- `docs/legal-drafts/tokushoho.md` — 特定商取引法に基づく表記ドラフト（事業者情報は空欄プレースホルダにし、Phase 6 の人間アクション一覧に「事業者情報の穴埋め」として載せる。課金なしプロジェクトでは省略してよい）
- `docs/ops/incident-runbook.md` — インシデント対応手順書ドラフト
- `docs/ops/support-desk.md` — 窓口運用設計ドラフト

いずれも「ドラフトであり法務・専門家レビュー前提」であることを文書冒頭に明記する。

## Phase 5: マーケ運転

Phase 0 で「SNS 運用あり」と回答された場合のみ実行する。

`sns-autopilot` は別マーケットプレイス（marketing-harness）のプラグインであり、コマンド（`commands/sns-autopilot-setup.md`）として提供されている（skill ではないため本スキルから `Skill` ツールで直接起動はできない）。

1. インストール済みか確認する（`/plugin list` 相当の確認、または marketplace 設定ファイルを確認）
2. 未インストールなら `/plugin marketplace add` と `/plugin install sns-autopilot@marketing-harness` の案内を行う
3. ユーザーに `/sns-autopilot:sns-autopilot-setup` を実行するよう案内する（テーマ・ゴール・ペルソナ・運用メディア・頻度のヒアリングとアカウント設計はこのコマンド側の責務）

## Phase 6: 教訓ログとマスタープラン

### 6.1 教訓ログのスケルトン設置

`${CLAUDE_PLUGIN_ROOT}/templates/autonomy-lessons-skeleton.md` を対象リポジトリの `docs/ops/autonomy-lessons.md` にコピーする（既存ファイルがあれば上書きせず、追記や統合の要否をユーザーに確認する）。

```bash
mkdir -p docs/ops
cp "${CLAUDE_PLUGIN_ROOT}/templates/autonomy-lessons-skeleton.md" docs/ops/autonomy-lessons.md
```

### 6.2 運営責任マスタープラン issue の起票

`${CLAUDE_PLUGIN_ROOT}/templates/master-plan-issue.md` を Read し、`{{PROJECT_NAME}}` `{{OWNER}}` `{{REPO}}` 等のプレースホルダを Phase 0 のヒアリング結果で置換したうえで、「確定済みの設計判断」セクションを対象プロジェクトの実情（返金ポリシー・聖域パス・課金有無等）で埋めてから起票する:

```bash
gh issue create --repo {owner}/{repo} \
  --title "運営責任設計マスタープラン（共同/自律の分担表）" \
  --label "human-only" \
  --body-file <置換済みファイル>
```

`human-only` ラベルが存在しない場合は事前に作成する（`gh label create human-only -c "#5319E7" -d "ループは触らない" --force`）。

## 人間アクション一覧（全フェーズ横断）

完了報告の最後に、以下を1つの表にまとめて提示する。すべて人間にしかできない操作:

| フェーズ | アクション |
|---|---|
| Phase 1 | Vercel / Supabase アカウント認証、Vercel Token 発行（infra-setup 側の案内に従う） |
| Phase 3 | `AUTOMERGE_PAT` 発行・登録（fine-grained: contents RW + pull-requests RW） |
| Phase 3 | `vars.STAGING_DOMAIN` 登録 |
| Phase 3 | `VERCEL_AUTOMATION_BYPASS_SECRET` 発行・登録 |
| Phase 3 | 聖域パスに触れる PR（`human-merge` ラベル）のマージボタン（継続的） |
| Phase 4 | Cloudflare Email Routing の個別ルール（`support-<slug>@<domain>` → 集約先 Gmail）作成、Gmail フィルタ作成（API 自動化不可の場合はダッシュボード操作） |
| Phase 4 | 特定商取引法表記の事業者情報穴埋め（課金ありの場合） |
| Phase 4 | Stripe 本番鍵の発行（課金ありの場合） |
| Phase 5 | X アカウント開設・API キー取得（SNS 運用ありの場合） |
| Phase 6 | マスタープラン issue の共同セッション（周1〜3） |

## してはならないこと

- 展開先リポジトリでの `gh pr merge` の代行実行（Layer 0 が導入された後は、マージはロボットか人間の役目）
- `main`/`master` への直接 push（deny 済みだが、本スキル自身もこれを回避しようとしない）
- 展開先だけの場当たり的な修正で終わらせること（「テンプレ駆動運用の原則」参照。テンプレ側の修正 PR を出す）
- Phase 5 の `sns-autopilot-setup` を `Skill` ツールで直接起動しようとすること（コマンドであり skill ではない）

## 自己検証

完了宣言の前に、以下を確認する（原則: `plugins/loops/references/self-verification.md`）:

- `.github/workflows/auto-merge.yml` / `staging-smoke.yml` が YAML として妥当であること
- `.claude/settings.json` が妥当な JSON であり、既存の deny エントリが失われていないこと
- 作成したラベル（`agent-review:passed` / `human-merge` / `human-decision` / `human-only`）が `gh label list` で確認できること
- マスタープラン issue が実際に起票され、URL を報告できること
