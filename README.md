# Claude Harness

Claude Code用スキル・プラグインのマーケットプレイス

## クイックスタート

```bash
# マーケットプレイスを登録
/plugin marketplace add oratta/claude-harness

# プラグインをインストール
/plugin install dev-workflow@oratta-claude-harness
```

## プラグイン一覧

### dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。`develop` スキルは、コード・スキル・コマンド・規範文書を変える作業に入口（issue 番号/URL/自然文・会話・cron・エピックの子）を問わず発火する。本体はオーケストレータ専任で、作業者 W・仕様レビュアー R1・ゲート実行者 G を `model` 明示で spawn し、記録先（issue、無ければ Draft PR）の確定 → 仕様化判断の記録 → 仕様レビュー → TDD 実装 → pr-review-gate の 1 ループを回す。

```bash
/plugin install dev-workflow@oratta-claude-harness
```

**機能:**
- `/develop [issue番号|URL|自然文]`（`/work-issue` はエイリアス）— develop スキルを interactive モードで起動する。issue が無ければ issue を切らず Draft PR を記録先にする（issue を切るのは追跡・キュー・議論が要るときだけ）
- 本体は Edit でコードを書かず、レビューを代行しない。別コンテキストを要する工程（仕様レビュー・PR レビュー）はすべて本体が起こす
- エピック（独立してマージできる PR が 2 本以上・複数 capability・順序依存）は子 issue ごとに 1 ループを `isolation: "worktree"` で並列に回す
- loop-dev-agent の無人サイクル（憲法は各リポの `docs/agent-loop.md`。flatmate が保守）では、憲法のメインが develop の本体を務める（`--unmanned`）
- 上流の壁打ち（`/opsx:explore`）は呼ばない（issue 化前の壁打ちとは切り分ける）
- `references/`（プラグイン直下）に他プラグインと共有する契約を置く: 自己検証の共通原則・PR / issue 本文の型・Workflow 実行のロール別ティア・Workflow 実行の型。`issueify` スキルはタスクメモを受け入れ条件付き issue に変換する

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
/plugin add ./plugins/dev-workflow
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

---

### 解散済みプラグイン

ループレシピ集・自律実行ハーネス・その短縮コマンド集の 3 プラグインは 2026-08 に解散した（[#205](https://github.com/oratta/claude-harness/issues/205)）。手順書としての層をやめ、中に埋まっていた契約（自己検証の共通原則・PR / issue 本文の型・issueify・ロール別モデルティア）だけを `dev-workflow` に移した。install 済みの環境での `/plugin uninstall` 手順と新旧パスの対応表は `plugins/dev-workflow/CHANGELOG.md` にある。
