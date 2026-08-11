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

Claude Code 向け自律実行ハーネス。plan.md から Workflow スクリプトを生成し、TDD 実装（Build）と 4 軸定量評価（Verify）を Build Contract レビュー付きで自律的に回す。

```bash
/plugin install longrun@oratta-claude-harness
```

**機能:**
- brain dump を分析し、発散リスクの高い論点を質問で埋めて plan.md を対話的に作成
- Build Contract パターンの実装前レビューと、独立コンテキストのサブエージェントによる TDD 実装
- 静的検証（テスト・lint・型・ビルド）とブラウザ動作検証による定量評価
- 完了後は OpenSpec change + ランディレクトリとしてアーカイブし、フィードバックを自動分類して反映

**コマンド:**

| コマンド | 説明 |
|----------|------|
| `/longrun:plan [brain-dump]` | 自律実行用の plan.md を対話的に作成する |
| `/longrun:mvp` | 短時間・人間実装向けの軽量 MVP plan.md を作成する |
| `/longrun:exec [plan-path]` | plan.md から Workflow スクリプトを生成・起動し、自律実行する |
| `/longrun:archive` | 完了した自律実行をアーカイブする（OpenSpec change + ランディレクトリ） |
| `/longrun:feedback` | 完了後のフィードバックを自動分類し、即実行または backlog に記録する |

**含まれるスキル:**
- `longrun-plan` - 自律実行用 plan.md の対話的作成
- `longrun-mvp-plan` - 軽量 MVP plan.md の対話的作成
- `longrun-feedback` - 完了後フィードバックの自動分類（Tier 1/2 即実行・Tier 3 backlog）

**含まれるエージェント:**
- `longrun-builder` - 独立コンテキストでの TDD 実装
- `longrun-reviewer` - Build Contract パターンの実装前レビュー
- `longrun-verifier` - 静的検証（テスト・lint・型チェック・ビルド）
- `longrun-browser-verifier` - ブラウザ動作検証
- `longrun-mvp-plan-reviewer` / `longrun-mvp-bestpractice-reviewer` / `longrun-mvp-research` - MVP プランのレビューとリサーチ

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

詳細は `plugins/loops/`（レシピ・規約・リファレンス）を参照。定期実行のスケジューラ登録・課金選択はレシピのスコープ外（呼び出し側の責務）。

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

### その他のプラグイン

いずれも `/plugin install <プラグイン名>@oratta-claude-harness` でインストールする。

| プラグイン | 説明 |
|-----------|------|
| `telegram` | Telegram messaging bridge。公式プラグインの fork で、主のリアクション（👍👀等）をセッションに配送する |
| `discord` | Discord messaging bridge。公式プラグインの fork で、`fetch_messages` がリアクションを返す |
| `lr` | longrun の短縮コマンド集（`/lr:p` `/lr:m` `/lr:e` `/lr:a` `/lr:f`） |
| `worktree` | Git worktree のセットアップ（`/wt-setup`。`--with-pr` で Draft PR まで作成）とクリーンアップ（`/wt-clean`） |
| `weekly-report` | 週次プロジェクト実績レポートを自動生成し、Obsidian 週次ノートに挿入する。cron 非対話実行に対応 |
| `daily-report` | 音声トランスクリプト・Obsidian ノート・LLM セッションログを横断集約し、日次日記を生成する |
| `infra` | Vercel + Supabase + GitHub Actions で local/staging/prod の環境を一括セットアップする（`/infra-setup`） |
| `experience-to-skill` | セッションの jsonl ログを素材に、自然言語の依頼で SKILL.md を蒸留する（`/e2s:distill`） |
| `skill-pack` | プロジェクトごとに skillOverrides / enabledPlugins を対話的に編集し、必要なスキルだけを ON にする |
| `capability-registry` | 外部サービスを操作する前に CLI とトークンの在処を教える発見層。`fmtoken.sh` を同梱 |
| `statusline` | 使用量ステータスライン。クォータ消化率と窓の日程消化率を1本のバーに重ね、`25%/29%` の形で「今のペースでリセットまで持つか」を示す（`/statusline:setup`） |

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
