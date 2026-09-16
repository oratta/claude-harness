# Plugin Editing Rules

Claude Code プラグイン（コマンド・スキル・エージェント・ルール）を編集しようと思ったら、書き始める前に読む。

- **編集してよいのは marketplace dir の外に置いた開発用 clone とその worktree だけ。** `~/.claude/plugins/marketplaces/...`（自動更新される install 成果物）と `~/.claude/commands/` `~/.claude/skills/` へのローカルコピーは編集しない。`~/.claude/rules/*.md` は marketplace dir を指す symlink なので、ルールも開発用 clone 側の `rules/*.md` を直す
- **別プロジェクトで作業中に harness を直したくなっても、その作業リポジトリの中で直さない。** 開発用 clone の場所は環境変数 `CLAUDE_HARNESS_DEV_DIR` で解決し、パスを文書やスクリプトに固定で書かない。未設定なら主に聞く（`find` 等の探索で当てにいかない）。開発用 clone は自動更新されないので、`git fetch origin` してから origin/main を起点に worktree を切り、別セッションかサブエージェントに任せる
- `/wt-setup` は worktree を作るスキルではない。別プロジェクトの worktree で走らせると、そちらのリポジトリに Draft PR が作られる
- `sync.sh` は marketplace dir 側のもの（`~/.claude/plugins/marketplaces/oratta-claude-harness/scripts/sync.sh`）だけ実行する。開発用 clone や worktree のものは実行しない
- 変更したら `plugin.json` のバージョンを上げ、commit・push して Draft PR まで作る（作業ツリーに置きっぱなしにしない）
- 状態がおかしくなっても手動で削除しない（`/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins`）

詳細（編集禁止の理由、マージ前の `--plugin-dir` での動作確認、マージ後の反映手順、旧運用からの移行）は `~/.claude/plugins/marketplaces/oratta-claude-harness/docs/worktree-recovery.md`。
