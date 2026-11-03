## 1. 実装（PR #1204 で実施済み）

- [x] 1.1 cmd_reap のブランチ削除を期待 OID つきの `git update-ref -d refs/heads/<ブランチ> <HEAD>` にする。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh
- [x] 1.2 別の worktree が checkout しているブランチは `update-ref -d` を呼ばず `reaped <N> branch-kept` にする（前方一致の別ブランチでは消す）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh
- [x] 1.3 bats のスタブに `update-ref -d`（期待 OID 違いで exit 1）を足し、確認後・削除前に ref が進む回帰テストと使用中ブランチの回帰テストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats
- [x] 1.4 openspec/specs の reap の記述と Scenario を `git update-ref -d` に揃える（change は事後に作成）。触る範囲: openspec/specs/dev-workflow-develop/spec.md、openspec/specs/dev-workflow-epic-state/spec.md
