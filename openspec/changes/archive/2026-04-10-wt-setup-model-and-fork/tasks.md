## 1. Frontmatter設定追加

- [x] 1.1 SKILL.md frontmatterに `model: sonnet` を追加
- [x] 1.2 SKILL.md frontmatterに `context: fork` を追加

## 2. コマンドファイル修正

- [x] 2.1 commands/wt-setup.md の description から実装詳細（`.claude/ symlink`、`envコピー`）を除去

## 3. 検証

- [ ] 3.1 fork環境でwt-setup.shが正常に実行されることを確認（git追跡済みworktreeで実行）
- [ ] 3.2 fork環境でAskUserQuestionが動作するか確認（.worktreeinclude未存在のケースで検証）
- [ ] 3.3 fork環境の結果が親コンテキストに正しく返されることを確認
