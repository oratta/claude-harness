## 1. 置き換え

- [x] 1.1 `git grep -nE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' -- plugins/cost-ledger openspec/specs/cost-ledger-*` で `owner/repo` 形の名前を洗い出し、このリポジトリ自身・`acme/...`・`example/...` 以外の、リポジトリ名として使われているものを一覧にする
- [x] 1.2 `plugins/cost-ledger/tests/gate-report.bats` の該当箇所を、同じ旧名に同じ新名を対応させる 1 本の対応表で置き換える（期待値の構造は変えない）
- [x] 1.3 `openspec/specs/cost-ledger-gate-report/spec.md` と `openspec/specs/cost-ledger-cost-command/spec.md` の例の名前を、1.2 と同じ対応表で置き換える（規範の文は変えない）

## 2. 確認と記録

- [x] 2.1 `plugins/cost-ledger/changes/800.md` に変更記録を書く
- [x] 2.2 `scripts/test.sh cost-ledger public-names` と `openspec validate --specs --strict` が exit 0
