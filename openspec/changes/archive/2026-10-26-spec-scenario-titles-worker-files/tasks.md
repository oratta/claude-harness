## 1. spec の題名

- [x] 1.1 `dev-workflow-develop` の題名 5 件を直す。触る範囲: `openspec/specs/dev-workflow-develop/spec.md:125`、`:354`、`:379`、`:1029`、`:1230`
- [x] 1.2 `dev-workflow-pr-review-gate` の題名 3 件を直す。触る範囲: `openspec/specs/dev-workflow-pr-review-gate/spec.md:755`、`:760`、`:765`
- [x] 1.3 `dev-workflow-spec-review` の題名 2 件を直す。触る範囲: `openspec/specs/dev-workflow-spec-review/spec.md:11`、`:32`

## 2. 検証

- [x] 2.1 `grep -nE "^#### Scenario: .*worker\.md" openspec/specs/*/spec.md` の残りが 0 件
- [x] 2.2 `openspec validate --specs --strict` の failed 件数が変更前（86）より増えない
- [x] 2.3 `openspec validate spec-scenario-titles-worker-files --type change --strict` が終了コード 0
- [x] 2.4 `scripts/test.sh` が通る（手元は bats 未導入。CI の bats suites と shard 1〜4 の pass で確認）
