## 1. 警告フック

- [ ] 1.1 bats テストを先に書く（未設定+harness で 1 行警告・設定済みで無出力・空文字は未設定扱い・他リポジトリと git 外で無出力・常に exit 0・hooks.json 配線） 触る範囲: plugins/worktree/tests/dev-dir-env-check.bats（新規）
- [ ] 1.2 スクリプトを書く 触る範囲: plugins/worktree/scripts/dev-dir-env-check.sh（新規）
- [ ] 1.3 hooks.json の SessionStart に登録する 触る範囲: plugins/worktree/hooks/hooks.json:14-29

## 2. 文書と記録

- [ ] 2.1 README の「ローカル開発」に変数の意味と入れ方を足す（自分の子の分だけ） 触る範囲: README.md:80-92
- [ ] 2.2 変更の記録を書く 触る範囲: plugins/worktree/changes/1234.md（新規）
