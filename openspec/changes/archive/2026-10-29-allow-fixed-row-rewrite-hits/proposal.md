# Proposal

## Why

順 3 の 2 段目は、修正後にも検索語を含む「直した」行を記録する方法がなく、正しく直した行も unmatched にする（issue #549）。修正後の本文を既存の補助表で明示できるようにし、未記載の直し忘れを引き続き検出する。

## What Changes

- 補助表 `### 書き換えた該当しない行` の見出しと列を保ち、参照先を「該当しない」行から「直した」行にも広げる。
- 2 段目では補助表に載った「直した」行の修正後本文を 1 行につき 1 件だけ許す。未記載の「直した」行には許容を足さない。
- 混在組の削除必要数は「直した」の件数＋補助表に載った「該当しない」の件数のままとし、補助表に載った「直した」を二重計上しない。
- triage と worker の記述、既存の契約違反テストを新しい契約に揃え、成功・直し忘れ・件数超過・混在組の回帰テストを追加する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 順 3 の補助表、HEAD の件数照合、W の一覧記録契約を拡張する。

## Impact

対象は `plugins/dev-workflow/scripts/review-hit-set.py`、`plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`、`plugins/dev-workflow/skills/develop/references/roles/worker/implement.md`、`plugins/dev-workflow/tests/review-hit-set.bats` と同 capability の仕様。変更記録は `plugins/dev-workflow/changes/549.md` に残す。依存追加・version 更新は行わない。

仕様化判断は issue #549 に記録済み。単一 capability の一つの契約拡張で、受け入れ条件は成功と直し忘れの検出の 2 点に閉じるため、単一 change とする。実装変更を伴うため文言合わせの通し方は使わず、R1 レビューを受ける。
