# Git Commit Policy

コミットは自律実行してよい。作業の節目ごとに細かく commit する（終わるまでコミットしないのはアンチパターン）。
メッセージは「何を/なぜ」を既存履歴の形式で。

## プロジェクトタイプ判定

worktree セットアップ済み / `gh pr list` で過去 PR あり / PR テンプレ・CONTRIBUTING あり → **PR 運用**。
どれも無ければ**ローカル main 運用**。迷ったら一度だけ聞いて CLAUDE.md か `.claude/rules/` に記録し、以降は聞かない。

- **PR 運用**: 作業完了＋archive（`/opsx:archive` / `/wt-clean` 完了 = テスト・lint 済みのシグナル）後、
  feature branch への push と `gh pr create` まで自律実行 OK。マージ（`gh pr merge` / main 更新）は明示承認。
- **ローカル main 運用**: PR は作らない。feature → main のマージと `git push origin main` は明示承認。

## PR を作成したら pr-review-gate を必ず通す

PR 運用のリポでは、PR を作成し**変更が出揃った時点**で dev-workflow プラグインの
**pr-review-gate** スキルを読み込んでゲート（別コンテキストのレビュー・リスク宣言・
動作確認の証拠添付・`agent-review:passed`）を通す。ゲート通過後に commit を積んだら、
宣言・証拠・`agent-review:passed` を取り直す（手順の正本はスキル側）。
auto-merge 配備リポ（`.github/workflows/auto-merge.yml` があるリポ）では、
**ゲート通過 → auto-merge の機械マージが唯一のマージ経路**。これは上の
「マージは明示承認」の例外ではなく、その承認をゲート＋ロボット判定が担う形
（LLM が `gh pr merge` 等で直接マージすることは引き続き禁止）。機械マージから
人間マージに切り替わる条件（聖域パス・保留ラベル等）の正本は各リポの auto-merge workflow 側。

## 明示承認なしに実行しない（両運用共通）

main/master への直接 push・`--force` 系・`reset --hard`・`rebase -i`・push 済み `--amend`・
`checkout -- <path>` / `restore <path>`・`clean -f`・`branch -D`・`--no-verify` / `--no-gpg-sign`。迷ったら安全側。

過去作業のスキル化は `/e2s:distill`（experience-to-skill プラグイン）。
