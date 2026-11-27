# Plugin Editing Rules

Claude Code プラグイン（コマンド・スキル・エージェント・ルール）を編集しようと思ったら、またはその動きをメモリで補おうと思ったら、書き始める前に読む。

- インストールされたフォルダ（`~/.claude/plugins/marketplaces/...`）は自動更新されるので直接編集しない。`~/.claude/commands/` `~/.claude/skills/` へのローカルコピーも編集しない
- `~/.claude/rules/*.md` は marketplace のフォルダを指す symlink なので、ルールもその部品を持つリポジトリ側で直す
- 部品は、その部品を持つリポジトリの開発用 clone（marketplace のフォルダの外）で直す
- 状態がおかしくなっても手動で削除しない（`/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins`）
- プラグインの動きへの指摘をメモリにその場しのぎで書くときは、同じターンでその部品を持つリポジトリに直し先の issue を立て、メモリの frontmatter に `patches: <issue の URL>` を書く（閉じたら消す候補になる。書き方は dev-workflow の memory-refresh スキル）
