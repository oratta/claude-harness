# Git Commit Policy

コミットは自律実行してよい。作業の節目ごとに細かく commit する（終わるまでコミットしないのはアンチパターン）。メッセージは「何を/なぜ」を既存履歴の形式で。

worktree セットアップ済み / `gh pr list` で過去 PR あり / PR テンプレ・CONTRIBUTING あり → **PR 運用**。どれも無ければ**ローカル main 運用**。PR 運用は作業完了＋archive（`/opsx:archive` / `/wt-clean` 完了 = テスト・lint 済みのシグナル）後、feature branch への push と `gh pr create` まで自律実行してよい。マージは明示承認。ローカル main 運用は PR を作らず、feature → main のマージと `git push origin main` は明示承認。`gh pr merge` などの直接マージは、どちらの運用でも明示承認なしに実行しない。承認が要る破壊的操作の一覧は `destructive-git-guard.md`。迷ったら安全側。

PR を作ったら `dev-workflow:pr-review-gate` スキルのゲートを必ず通す。ゲートを通っていない PR を主の承認なしにマージしない。ゲート通過後に commit を積んだら取り直す。

既存 issue の受け入れ条件を足す前（足してよいかを主に聞くならその前）に、`gh issue view <番号> -R <owner/repo> --json comments` の `develop 開始` のコメントと、`gh pr list -R <owner/repo> --state open --search "<番号> in:body" --json url,body` の PR のうち本文に `Closes` / `Fixes` / `Refs #<番号>` があるものを確かめる（issue の本文だけでは分からない）。どちらかがあれば作業中で、新しい issue に切り出す。同じ issue に足すなら、作業中であること（PR があればその URL）を書いて主に聞く。G がレビュー指摘の振り分けで足す場合は `dev-workflow:pr-review-gate` に従う。

運用の判定の詳細（迷ったときの記録先・auto-merge 配備リポでのマージ経路）は `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/commit-and-pr-operations.md`。
