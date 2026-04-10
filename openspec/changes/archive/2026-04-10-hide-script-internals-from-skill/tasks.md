## 1. SKILL.md frontmatter修正

- [x] 1.1 descriptionを「Git worktreeの開発環境セットアップ。worktree作成後に実行する。」に変更し、symlink・.claude関連の文言を除去する

## 2. SKILL.md本文からスクリプト内部実装の除去

- [x] 2.1 Step 1の説明文から「.claude/の判定とsymlink作成」等の実装詳細を削除し、「セットアップスクリプトを実行し、出力を確認する」のみにする
- [x] 2.2 エラーハンドリングセクションからsymlink関連の記述（「symlink先が既に存在する場合: -sfn で上書き」）を削除し、「スクリプトがエラー終了した場合は出力をユーザーに報告する」に置換する

## 3. 検証

- [x] 3.1 SKILL.md全文に `symlink`、`ln -s`、`-sfn`、`git ls-files` の文字列が存在しないことを確認する
- [x] 3.2 git追跡済みプロジェクトのworktreeでスクリプトを実行し、symlinkスキップが正しく動作することを確認する
