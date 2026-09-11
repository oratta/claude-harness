# Git Commit Policy

コミットは自律実行してよい。作業の節目ごとに細かく commit する（終わるまでコミットしないのはアンチパターン）。メッセージは「何を/なぜ」を既存履歴の形式で。

## 明示承認なしに実行しない（PR 運用・ローカル main 運用の共通）

main/master への直接 push・`--force` 系・`reset --hard`・`rebase -i`・push 済み `--amend`・`checkout -- <path>` / `restore <path>`・`clean -f`・`branch -D`・`--no-verify` / `--no-gpg-sign`・`gh pr merge` などの直接マージ。迷ったら安全側。

PR を作ったら `dev-workflow:pr-review-gate` スキルのゲートを必ず通す。ゲートを通っていない PR を主の承認なしにマージしない。

このリポジトリが PR 運用かローカル main 運用かの判定と、どこまで自律実行してよいかの線引きは `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/commit-and-pr-operations.md`。
