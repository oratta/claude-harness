# commit と PR の運用判定

`rules/git-commit-policy.md`（常時注入される要点）から詳細を移した先。最初の commit を打つ前に、このリポジトリが PR 運用かローカル main 運用かを決めるために読む。運用の判定と自律実行の線引きの要点はルール側にも残してある。承認なしに実行してはいけない破壊的操作の一覧は `rules/destructive-git-guard.md` が正本なので、ここには再掲しない。

## プロジェクトタイプ判定

worktree セットアップ済み / `gh pr list` で過去 PR あり / PR テンプレ・CONTRIBUTING あり → **PR 運用**。どれも無ければ **ローカル main 運用**。迷ったら一度だけ聞いて `CLAUDE.md` か `.claude/rules/` に記録し、以降は聞かない。

| 運用 | どこまで自律実行してよいか | 明示承認が要るもの |
|---|---|---|
| PR 運用 | 作業完了＋archive（`/opsx:archive` / `/wt-clean` 完了 = テスト・lint 済みのシグナル）後、feature branch への push と `gh pr create` まで | マージ（`gh pr merge` / main 更新） |
| ローカル main 運用 | feature branch での commit まで。PR は作らない | feature → main のマージと `git push origin main` |

## PR を作成したら pr-review-gate を必ず通す

PR 運用のリポでは、PR を作成し**変更が出揃った時点**で `dev-workflow:pr-review-gate` スキルを読み込んでゲート（別コンテキストのレビュー・リスク宣言・動作確認の証拠添付・`agent-review:passed`）を通す。ゲート通過後に commit を積んだら、宣言・証拠・`agent-review:passed` を取り直す（手順の正本はスキル側）。

auto-merge 配備リポ（`.github/workflows/auto-merge.yml` があるリポ）では、**ゲート通過 → auto-merge の機械マージが唯一のマージ経路**。これは「マージは明示承認」の例外ではなく、その承認をゲート＋ロボット判定が担う形（LLM が `gh pr merge` 等で直接マージすることは引き続き禁止）。機械マージから人間マージに切り替わる条件（聖域パス・保留ラベル等）の正本は各リポの auto-merge workflow 側。

## その他

過去作業のスキル化は `/e2s:distill`（experience-to-skill プラグイン）。
