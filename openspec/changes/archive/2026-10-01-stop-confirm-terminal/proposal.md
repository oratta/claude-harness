## Why

前任のサブエージェントを動作中に交代させる手順は「停止を指示 → 停止確認を受け取る → 手渡し先を spawn」と定めてあるが、停止確認が返ってこないときの終端が空いている。interactive で他に進められる作業が無いと停滞（fail-closed）し、終端が無い場所では即興が生まれる。二重 spawn 事故の直接原因が即興だった（#253）。

## What Changes

- 停止確認が返らないときの終端を、観測できる 2 条件（停止指示からの経過時間・前任のトランスクリプトの無更新時間）で定義し、値は環境変数で上書きできるようにする。
- 終端に達したときの帰結は、手渡しをせず作業を止めて人間に報告することとし、手渡しの許可条件（`工程完了:` の return か停止確認）を増やさない。
- `scripts/subagent-context.sh` に `--stop-since` を足して本体が終端を測れるようにする。

## Capabilities

### Modified Capabilities

- `dev-workflow-develop`: 停止確認が返らないときの終端の要件を足す。

## Impact

- `plugins/dev-workflow/skills/develop/references/decision-criteria.md`、`plugins/dev-workflow/scripts/subagent-context.sh`、`plugins/dev-workflow/tests/handoff-declaration.bats`、`plugins/dev-workflow/tests/subagent-context.bats`
