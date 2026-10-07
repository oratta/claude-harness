## 1. SKILL.md

- [ ] 1.1 `plugins/worktree/skills/wt-setup/SKILL.md` の frontmatter に、`context: fork` / `background: false` が現行経路（commands ラッパー）で効かないことと、残す理由を YAML コメントで書く。先頭 12 行に収める。触る範囲: plugins/worktree/skills/wt-setup/SKILL.md:1-10（frontmatter）

## 2. 検証と記録

- [ ] 2.1 `bats plugins/worktree/tests/skill-safety.bats` と `scripts/test.sh` が exit 0 になることを確認する。触る範囲: plugins/worktree/tests/skill-safety.bats:131-150（変更なし、確認のみ）
- [ ] 2.2 変更の記録 `plugins/worktree/changes/732.md` を書く（実機確認のコマンドと出力の要点・公式ドキュメントとの食い違い・残す理由）。触る範囲: plugins/worktree/changes/732.md（新規）
- [ ] 2.3 PR 本文に実機確認のコマンドと出力を貼る
