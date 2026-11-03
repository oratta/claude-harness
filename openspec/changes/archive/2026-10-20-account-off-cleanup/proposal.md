## Why

`accounts.sh off b` のあとに `select-account.sh b` を実行した利用者が、stderr で「登録簿を手で書き換えろ」と案内される。README と仕様の `accounts.sh` が入ってからの正しい戻し方は `accounts.sh on <id>` で、実際に目にする文面と食い違う（#1005）。あわせて #976 のレビューで残った、仕様の列挙漏れ（#1005、#988）とテスト不足（#987）を同じ PR で片付ける。

## What Changes

- `select-account.sh` のオフのスロットを明示選択したときの stderr 文面を、手編集の案内から `accounts.sh on <id>` の案内に変える（#1005）
- `usage-account-registry` の要件「登録済みスロットを明示選択できる」の戻し方を `accounts.sh on <id>` に合わせる（#1005）
- `usage-account-registry` の要件「スロットを enabled でオフにできる」の、判定が扱う入力に `accounts.sh on|off` の出力を足し、レジストリを読む箇所に `accounts.sh list` を足す（5 か所 → 6 か所）（#1005）
- `dev-workflow-escalation-tripwires` の usage-probe の実行条件に、オフのスロットの扱いを 1 行足す（#988）
- `account-selector.bats` に、既定スロット a がオフ・スロット b がオンで使用量が欠測のときのテストを足す（#987。仕様の変更は無く、既存の要件と scenario の回帰を守るだけ）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `usage-account-registry`: 明示選択の戻し方の文面、`enabled` 判定の入力と読み手の列挙
- `dev-workflow-escalation-tripwires`: usage-probe の実行条件にオフのスロットを足す

## Impact

- `plugins/dev-workflow/scripts/select-account.sh`（stderr 文面のみ。選択の振る舞いは変えない）
- `plugins/dev-workflow/tests/account-selector.bats`
- `openspec/specs/usage-account-registry/spec.md`、`openspec/specs/dev-workflow-escalation-tripwires/spec.md`（archive 時に反映）
- Codex 側（#978）には触れない
