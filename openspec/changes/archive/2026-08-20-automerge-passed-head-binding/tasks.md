## 1. 実装

- [x] 1.1 テンプレート auto-merge.yml に `passed-head-binding` マーカー対で照合を実装（passed チェック直後・fail-closed・`$HEAD_SHA` 変数の同一性でマージ対象と一致）
- [x] 1.2 テンプレート test-auto-merge-workflow.sh に (1-f) 退行テストを追加
- [x] 1.3 テンプレート docs/auto-merge.md を 5 条件に更新・調べ方に SHA 不一致ケースを追記
- [x] 1.4 pr-review-gate SKILL.md に規約の結合（対象 HEAD: が合格条件そのもの）を明文化
- [x] 1.5 自リポ配備分（.github/workflows / scripts / docs）へ同じ差分を適用

## 2. テスト

- [x] 2.1 automerge-templates.bats にマーカー対と HEAD 束縛の不変条件テストを追加
- [x] 2.2 `bash scripts/test-auto-merge-workflow.sh` 全 PASS（exit 0）
- [x] 2.3 bats automerge-templates.bats 全 PASS（exit 0）

## 3. 整合

- [x] 3.1 plugin.json / marketplace.json を 1.11.0 へ bump
- [x] 3.2 `openspec validate automerge-passed-head-binding --strict` を通す
