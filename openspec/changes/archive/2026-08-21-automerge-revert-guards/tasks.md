## 1. 退行テスト（先に書いて落とす）

- [x] 1.1 test-auto-merge-workflow.sh（テンプレート・repo 両方）に base/ancestor/再開の検査を追加し、修正前に FAIL することを確認
- [x] 1.2 automerge-templates.bats に同じ不変条件の @test を追加

## 2. 実装

- [x] 2.1 revert-pr.yml（テンプレート・repo 両方）に base 検証・ancestor 検証・再開ロジックを実装
- [x] 2.2 テスト green を確認（bats 全件 + actionlint + bash -n）

## 3. ドキュメント

- [x] 3.1 docs/auto-merge.md（テンプレート・repo 両方）に拒否条件と re-run 再開を追記
- [x] 3.2 配備先への伝播は auto-merge-deployments.md の手順に従う（PR 本文に対象を明記）
