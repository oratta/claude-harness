## 1. SKILL.md

- [x] 1.1 `plugins/worktree/skills/wt-setup/SKILL.md` の frontmatter に、`context: fork` / `background: false` が現行経路で効かないことと本文参照の旨を短い YAML コメントで書く。先頭 12 行に収める。触る範囲: plugins/worktree/skills/wt-setup/SKILL.md:1-10（frontmatter）
- [x] 1.2 同 SKILL.md の本文に節「frontmatter の fork 指定について」を足し、実機観測（版 2.1.292、`claude -p --plugin-dir`、`/wt-setup` と Skill ツール経由が同名 commands ラッパーに解決されたこと、確かめ方）と、設定を残す理由を書く。触る範囲: plugins/worktree/skills/wt-setup/SKILL.md:12-30（「自動実行との関係」節の前後）

## 2. 検証と記録

- [x] 2.1 `bats plugins/worktree/tests/skill-safety.bats` と `scripts/test.sh` が exit 0 になることを確認する。触る範囲: plugins/worktree/tests/skill-safety.bats:131-150（変更なし、確認のみ）
- [x] 2.2 変更の記録 `plugins/worktree/changes/732.md` を書く（実機確認のコマンドと出力の要点・公式ドキュメントとの食い違い・残す理由）。触る範囲: plugins/worktree/changes/732.md（新規）
- [x] 2.3 PR 本文に実機確認のコマンドと出力を貼る
