# Git Commit Policy

コミットは自律実行してよい。作業の節目ごとに細かく commit する（終わるまでコミットしないのはアンチパターン）。
メッセージは「何を/なぜ」を既存履歴の形式で。

## プロジェクトタイプ判定

worktree セットアップ済み / `gh pr list` で過去 PR あり / PR テンプレ・CONTRIBUTING あり → **PR 運用**。
どれも無ければ**ローカル main 運用**。迷ったら一度だけ聞いて CLAUDE.md か `.claude/rules/` に記録し、以降は聞かない。

- **PR 運用**: 作業完了＋archive（`/lr:a` / `/wt-clean` 完了 = テスト・lint 済みのシグナル）後、
  feature branch への push と `gh pr create` まで自律実行 OK。マージ（`gh pr merge` / main 更新）は明示承認。
- **ローカル main 運用**: PR は作らない。feature → main のマージと `git push origin main` は明示承認。

## PR を作成したら pr-review-gate を必ず通す

PR 運用のリポでは、`gh pr create` の直後に dev-workflow プラグインの **pr-review-gate** スキルを
読み込んでゲート（別コンテキストのレビュー・リスク宣言・動作確認の証拠添付・`agent-review:passed`）を通す。
auto-merge 配備リポ（`.github/workflows/auto-merge.yml` があるリポ）では、
**ゲート通過 → auto-merge の機械マージが唯一のマージ経路**。ゲートを通さず
`gh pr merge` や手動マージで先回りしない（聖域パスに触れる PR だけは、ゲート通過後も主の手動マージ）。

## 明示承認なしに実行しない（両運用共通）

main/master への直接 push・`--force` 系・`reset --hard`・`rebase -i`・push 済み `--amend`・
`checkout -- <path>` / `restore <path>`・`clean -f`・`branch -D`・`--no-verify` / `--no-gpg-sign`。迷ったら安全側。

過去作業のスキル化は `/e2s:distill`（experience-to-skill プラグイン）。
