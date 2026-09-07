# Plugin Editing Rules

プラグインのコマンド・スキル・エージェント編集は、**marketplace dir の外に置いた開発用 clone**（とその worktree）で行う。次の 2 か所は編集しない:

- `~/.claude/plugins/marketplaces/...`（marketplace dir）— Claude Code が自動更新するインストール成果物。ここで feature ブランチを checkout すると、自動更新や `scripts/sync.sh` の pull がそのブランチ上で走り、`~/.claude/plugins/cache/` にもマージ前の内容が入る
- `~/.claude/commands/` や `~/.claude/skills/` へのローカルコピー — marketplace 版より優先されて更新が反映されなくなる事故が過去に繰り返し発生

`~/.claude/rules/*.md` は marketplace dir 配下のファイルを指す symlink（`scripts/sync.sh` が張る）。ルールを直すときも symlink の実体ではなく開発用 clone 側の `rules/*.md` を編集し、マージしてから `scripts/sync.sh` で追随させる。

- 変更時は plugin.json のバージョンを上げる。反映のためではなく（`~/.claude/plugins/cache/` は marketplace dir の HEAD に追随するのでバージョン据え置きでも中身は入る）、**リリース管理の規約として**。テスト S131（`tests/marketplace-sync.bats`）が merge-base からの bump を要求する
- `known_marketplaces.json` でリポジトリ URL を確認して commit & push
- マージ前の動作確認は `claude --plugin-dir <worktree のパス>` でそのセッションだけ読み込ませる。マージ後の反映は `/plugin update`（または新規セッション起動時の自動更新）→ `/reload-plugins`
- 状態がおかしくなったら手動削除せず `/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins`
