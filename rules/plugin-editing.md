# Plugin Editing Rules

プラグインのコマンド・スキル・エージェント編集は、**marketplace dir の外に置いた開発用 clone**（とその worktree）で行う。次の 2 か所は編集しない:

- `~/.claude/plugins/marketplaces/...`（marketplace dir）— Claude Code が自動更新するインストール成果物。ここで feature ブランチを checkout すると、自動更新や `scripts/sync.sh` の pull がそのブランチ上で走り、`~/.claude/plugins/cache/` にもマージ前の内容が入る
- `~/.claude/commands/` や `~/.claude/skills/` へのローカルコピー — marketplace 版より優先されて更新が反映されなくなる事故が過去に繰り返し発生

`~/.claude/rules/*.md` は marketplace dir 配下のファイルを指す symlink（`scripts/sync.sh` が張る）。ルールを直すときも symlink の実体ではなく開発用 clone 側の `rules/*.md` を編集し、マージしてから **marketplace dir 側の** `scripts/sync.sh`（`~/.claude/plugins/marketplaces/oratta-claude-harness/scripts/sync.sh`）で追随させる。開発用 clone や worktree の `scripts/sync.sh` は実行しない — sync.sh は自分自身の位置からリポジトリを決めるので、symlink が既にある PC では「harness 外を指す symlink」として rc=1 で失敗し、まだ無い PC ではマージ前の feature ブランチの rules が全セッションのグローバルルールとして張られる。

- 変更時は plugin.json のバージョンを上げる。反映のためではなく（`~/.claude/plugins/cache/` は marketplace dir の HEAD に追随するのでバージョン据え置きでも中身は入る）、**リリース管理の規約として**。claude-harness のテスト S131（同リポジトリの `tests/marketplace-sync.bats`）が merge-base からの bump を要求する
- `known_marketplaces.json` でリポジトリ URL を確認して commit & push
- マージ前の動作確認は `claude --plugin-dir <worktree のパス>/plugins/<プラグイン名>` でそのセッションだけ読み込ませる（`--plugin-dir` はプラグイン 1 個のディレクトリを取る。リポジトリのルートを渡しても警告なしに何も読み込まれない。複数見るなら繰り返し指定する）。マージ後の反映は `/plugin marketplace update oratta-claude-harness`（または新規セッション起動時の自動更新）→ `/reload-plugins`。`/plugin update` というスラッシュコマンドは存在しない
- 状態がおかしくなったら手動削除せず `/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins`

## 開発用 clone の場所（他プロジェクトで作業中に harness を直したくなったとき）

**別のプロジェクトで作業していて harness の修正が必要になったら、その作業リポジトリの中で直さない。** 作業中のリポジトリに harness のファイルを作ったり書き換えたりすると、そのリポジトリの git 履歴に混ざり、harness 側には永久に届かない。marketplace dir（`~/.claude/plugins/marketplaces/...`）で直すのも同じく禁止 — Claude Code が自動更新するインストール成果物なので、feature ブランチを checkout すると自動更新の pull がそのブランチ上で走り、`~/.claude/plugins/cache/` にマージ前の内容が入る。

開発用 clone の場所は環境変数 **`CLAUDE_HARNESS_DEV_DIR`** で解決する。PC ごとに置き場所が違うので、パスをこのリポジトリの文書やスクリプトに固定で書かない（`LLM_LOG_DIR` と同じ扱い）。

```bash
# 開発用 clone の場所を確認する
echo "${CLAUDE_HARNESS_DEV_DIR:?未設定}"
```

未設定なら **主に置き場所を聞く**。デフォルトパスを勝手に決めない。`find ~ -name claude-harness` のような探索で当てにいくのも禁止（marketplace dir や過去の残骸を拾う）。

解決できたら、そこから worktree を切って直す。作業中のプロジェクトのセッションから直接 harness を編集しにいかず、worktree を作ってそこで別セッションを立てるか、その worktree を作業ディレクトリに指定したサブエージェントに任せる。

```bash
# 開発用 clone は marketplace dir と違って自動更新されないので、origin/main は古いままになり得る
git -C "$CLAUDE_HARNESS_DEV_DIR" fetch origin
git -C "$CLAUDE_HARNESS_DEV_DIR" worktree add <worktree のパス> -b <ブランチ名> origin/main
```

`/wt-setup` は worktree を作るスキルではないので、worktree の作成に使わない（作成後に worktree の中で走らせるもので、カレントが worktree でなければ止まるが、**作業中のプロジェクトの worktree にいると判定が通り、そちらのリポジトリに Draft PR が作られる**）。harness の worktree で立てたセッションの中でなら、`/wt-setup --with-pr` で Draft PR まで用意できる。

元のプロジェクトの作業に戻る前に、harness 側は commit して push する（PR 運用のリポジトリなので Draft PR まで作る）。作業ツリーに置きっぱなしにしない。
