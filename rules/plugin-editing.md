# Plugin Editing Rules

プラグインのコマンド・スキル・エージェント編集は **marketplace 版のみ**（`~/.claude/plugins/marketplaces/...`）。
`~/.claude/commands/` や `~/.claude/skills/` へのローカルコピーは禁止 —
marketplace 版より優先されて更新が反映されなくなる事故が過去に繰り返し発生。

- 変更時は plugin.json のバージョンを上げる（`~/.claude/plugins/cache/` はバージョン単位キャッシュのため、同バージョンのままでは他プロジェクトに反映されない）
- `known_marketplaces.json` でリポジトリ URL を確認して commit & push
- 状態がおかしくなったら手動削除せず `/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins`
