# Claude Harness

Claude Code用スキル・プラグインのマーケットプレイス

## クイックスタート

```bash
# マーケットプレイスを登録
/plugin marketplace add oratta/claude-harness

# プラグインをインストール
/plugin install longrun@oratta-claude-harness
```

## プラグイン一覧

### longrun

Claude Code ロングラン自律実行システム。instruction.mdを対話的に作成し、人間の介入なしに長時間の自律的実装を完遂する。

```bash
/plugin install longrun@oratta-claude-harness
```

**機能:**
- Brain Dump → Gap Analysis → Interview → Synthesis で instruction.md を対話的に作成
- 専門サブエージェント（意思決定・検証・テスト・仕様管理）による品質担保
- 意思決定の分岐点でGitコミット（ロールバックポイント）
- リアルタイム進捗追跡（`_longrun/progress.md`）

**コマンド:**

| コマンド | 説明 |
|----------|------|
| `/instruction [brain-dump]` | instruction.mdを対話的に作成する |
| `/exec [instruction-path]` | ロングラン自律実行を開始する |
| `/status` | 実行中の進捗状況を確認する |
| `/decisions [番号]` | 意思決定の一覧・詳細を確認する |

**含まれるスキル:**
- `instruction-builder` - 指示ファイルの対話的作成
- `longrun-orchestrator` - 自律実行オーケストレーション

**含まれるエージェント:**
- `decision-agent` - 設計上の意思決定（Opus）
- `verification-agent` - ブラウザ動作確認（Opus）
- `test-agent` - テスト作成・実行（Sonnet）
- `spec-agent` - 仕様書メンテナンス（Sonnet）

---

### loops

公式記事「Getting started with loops」（https://claude.com/blog/getting-started-with-loops）が定義する **4 つのループタイプ**を、Claude Code のネイティブプリミティブ（`/goal`・`/loop`・`/schedule`・skill・workflows・auto mode）の**合成レシピ集**として設計・記述するためのプラグイン。**独自のループ実行系（常駐スクリプト・カスタム driver）は持たない**——ハーネスが提供するのはレシピ（設計図）と規約であり、反復・スケジュール・停止判定はネイティブプリミティブに委ねる。

```bash
/plugin install loops@oratta-claude-harness
```

**公式 4 ループタイプ:**

| タイプ | 何を手放すか | 主なプリミティブ |
|--------|--------------|------------------|
| ターンベース | 検証ステップ（skill の自己検証） | skill |
| ゴールベース | 停止条件（定量基準まで反復） | `/goal` |
| タイムベース | トリガー（定期・イベント起動） | `/loop`・`/schedule` |
| プロアクティブ | プロンプト自体（人間不在で回る） | 合成（`/schedule` + `/goal` + workflows + auto mode） |

**機能:**
- `/loops:design` — 選択フレームワークに沿ってループ型を選び、停止基準必須・Bad Loop 検査を通したレシピを設計する
- `/loops:goalify <テキスト|ファイル>` — brain dump から機械検証可能な goal ブリーフと `/goal` 起動コマンドを一発生成する
- レシピ集（ゴール / タイム / プロアクティブ）と State 規約・コストガードレール

詳細は `plugins/loops/`（レシピ・規約・リファレンス）および調査資料 `research/` を参照。定期実行のスケジューラ登録・課金選択はレシピのスコープ外（呼び出し側の責務）。

---

### dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。`github-issue` スキルは、GitHub issue（番号/URL/自然文）に取り組む時に発火し、worktree なら `wt-setup` 未実行を検出して先に実行 → 仕様として残すべき変更なら opsx（openspec）フロー → 単一 change で足りるか複数 change に割れるかを判定 → TDD で実装、という標準手順を毎回同じに通す。

```bash
/plugin install dev-workflow@oratta-claude-harness
```

**機能:**
- `/work-issue [issue番号|URL|自然文]` — github-issue スキルを interactive モードで起動する
- 人間の直接依頼でも `loops` プラグインの loop-dev-agent の無人サイクルからでも同じ判定ロジックを共有する（`--unmanned` で無人モード）
- 複数 change に割れる場合、対話セッション中はその場で順番に実行、無人ループ中はサブ issue に分割して `blocked_by` で順序付けし次サイクルへ委ねる（1サイクル1仕事を維持）
- `longrun:plan` は呼ばない（issue 化前の壁打ちとは切り分ける）

詳細は `plugins/dev-workflow/skills/github-issue/SKILL.md` を参照。

---

### agent-owner

任意のプロジェクトを「エージェントオーナープロジェクト（AI自動運営モード）」として立ち上げるセットアップオーケストレーター（v0 仮）。genetta-inc/suimei で実証した「開発エージェント + マーケエージェントが有料プロダクトを自動運営する仕組み」をテンプレート化したもの。

```bash
/plugin install agent-owner@oratta-claude-harness
```

**機能:**
- `agent-owner-setup` スキルが 6 フェーズを対話的に導入: インフラ（`infra` プラグイン起動）→ 開発自律ループ（`loops` プラグイン起動）→ Layer 0 マージ自動化（auto-merge ロボット + staging スモーク + auto-revert）→ 運営責任（窓口セットアップ + 利用規約/特商法/incident-runbook/support-desk ドラフト）→ マーケ運転（`sns-autopilot` プラグイン起動）→ 教訓ログとマスタープラン issue
- `templates/` に実証済み資産を同梱: `auto-merge.yml`（聖域パス保護 + 必須チェック機械判定）、`staging-smoke.yml`（外形スモーク + 誤検知ガード付き auto-revert）、permission deny 設定、教訓ログ様式、運営責任マスタープラン issue 雛形
- **テンプレ駆動運用**: 展開先で問題が出たら展開先だけを直さず、本プラグイン側を修正する PR を出す

詳細は `plugins/agent-owner/skills/agent-owner-setup/SKILL.md` を参照。**v0 は仮版であり、今後の展開結果に応じてフェーズ構成・自動化範囲が変わる前提。**

---

### genetta-mail

genetta.jp ドメイン配下の新サービス向けサポート窓口メール（`support-<slug>@genetta.jp`）を、1コマンド分の作業量でセットアップするプラグイン。設計の正本は genetta-inc/suimei の `docs/ops/genetta-mail-skill-design.md`（個別ルーティングルール方式に改訂済み）。

```bash
/plugin install genetta-mail@oratta-claude-harness
```

**機能:**
- `genetta-mail-setup` スキルが5手順を対話的に進める: ヒアリング → Cloudflare Email Routing の個別ルール作成（`CLOUDFLARE_API_TOKEN` があれば API、なければダッシュボード手順を提示）→ Gmail のラベル・フィルタ作成 → 対象サービス docs への窓口追記 → 到達テスト
- **catch-all は不採用**: ドメイン宛のランダム送信攻撃を全受信してしまいスパムの攻撃面が広すぎるため、サービスごとに個別ルーティングルールを1件作成する方式を採る
- **命名はハイフン区切り**（`support-<slug>@`）: `+` サブアドレス方式は Cloudflare Email Routing が解決せず 550 で不達になることが実弾で判明しているため不採用
- 窓口を「使える状態にする」ところまでがスコープ。問い合わせの分類・自動返信等の CS エージェント本体は扱わない

詳細は `plugins/genetta-mail/skills/genetta-mail-setup/SKILL.md` を参照。

---

## バンドル

複数のプラグインを一括でインストールできます。

```bash
# 全プラグインをインストール
/plugin install bundle:all@oratta-claude-harness
```

---

## ローカル開発

```bash
# リポジトリをクローン
git clone https://github.com/oratta/claude-harness
cd claude-harness

# Claude Codeでローカルプラグインを追加
/plugin add ./plugins/longrun
```

### 新しいプラグインを追加

```bash
# プラグインディレクトリを作成
mkdir -p plugins/new-plugin/{.claude-plugin,skills,commands}

# plugin.json を作成
cat > plugins/new-plugin/.claude-plugin/plugin.json << 'EOF'
{
  "name": "new-plugin",
  "version": "1.0.0",
  "description": "...",
  "skills": [],
  "commands": []
}
EOF

# marketplace.json を更新
# plugins 配列に追加
```

---

## ライセンス

MIT License

## Author

Oratta
