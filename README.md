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

loop-dev-agent の配備済み憲法（各リポの `docs/agent-loop.md`）は、`plugins/loops/templates/agent-loop-template.md` の更新後に `/loops:dev-agent-install` で再生成が必要（Step 3 の委譲先は dev-workflow の `develop` スキル）。

---

### dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。`develop` スキルは、コード・スキル・コマンド・規範文書を変える作業に入口（issue 番号/URL/自然文・会話・cron・エピックの子）を問わず発火する。本体はオーケストレータ専任で、作業者 W・仕様レビュアー R1・ゲート実行者 G を `model` 明示で spawn し、記録先（issue、無ければ Draft PR）の確定 → 仕様化判断の記録 → 仕様レビュー → TDD 実装 → pr-review-gate の 1 ループを回す。

```bash
/plugin install dev-workflow@oratta-claude-harness
```

**機能:**
- `/develop [issue番号|URL|自然文]`（`/work-issue` はエイリアス）— develop スキルを interactive モードで起動する。issue が無ければ issue を切らず Draft PR を記録先にする（issue を切るのは追跡・キュー・議論が要るときだけ）
- 本体は Edit でコードを書かず、レビューを代行しない。別コンテキストを要する工程（仕様レビュー・PR レビュー）はすべて本体が起こす
- エピック（独立してマージできる PR が 2 本以上・複数 capability・順序依存）は子 issue ごとに 1 ループを `isolation: "worktree"` で並列に回す
- `loops` プラグインの loop-dev-agent の無人サイクルでは、憲法のメインが develop の本体を務める（`--unmanned`）
- `longrun:plan` は呼ばない（issue 化前の壁打ちとは切り分ける）

詳細は `plugins/dev-workflow/skills/develop/SKILL.md` を参照。

---

### product-handover

プロダクトをエージェントに引き渡すときにだけ必要になる固有部品を配るプラグイン。法務ドラフト・サポート窓口・教訓ログの雛形3種だけを持ち、オーケストレーターもスキルも持たない。

```bash
/plugin install product-handover@oratta-claude-harness
```

**機能:**
- `templates/legal/` — 利用規約・プライバシーポリシー・返金ポリシーのドラフト雛形（いずれも法務レビュー前である旨を明記した状態で配る）
- `templates/support-desk.md` — サポート窓口メールの設定雛形（`support-<slug>@<domain>` の命名規則、catch-all を使わない理由、一次対応の範囲）
- `templates/autonomy-lessons-skeleton.md` — 教訓ログの様式
- 引き渡しの順番（インフラ → dev-workflow の導入 → auto-merge の配線 → product-handover → SNS）は README に書くだけで、他プラグインの起動はしない
- リポ側と住人側の分担: 住人（workspace・cron・チャンネル）は flatmate の `new-resident` が担い、本プラグインはプロダクトのリポ側だけを扱う

詳細は `plugins/product-handover/README.md` を参照。このプラグインは 2026-08-29 に旧名のプラグインを作り直したもので、入れ替え手順は `plugins/product-handover/CHANGELOG.md` にある。

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
