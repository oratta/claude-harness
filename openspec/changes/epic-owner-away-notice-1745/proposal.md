## Why

#1744 で、主が子のタブで打った入力から始まったターン（`turn_input.sender` が `owner`）は、`主の返事待ち` で終わっても親の `wait --watch-stopped` が何もしない形になった。主の会話を割って返事を送ったり端末を閉じたりしないためだが、主が問いを受けたまま席を離れると、問いが誰にも知らされず残る。#1670 の「決めた形」の 4 のとおり、時間で拾って主に知らせる。#1670 の仕様化で編集ファイルが 5 の上限を超えたため #1745 に分けた。

## What Changes

- `wait --watch-stopped` が、主が打った入力から始まり `主の返事待ち` で終わったターンを、終了状態の `recorded_at` から `EPIC_DISPATCH_OWNER_AWAY_SEC`（既定 3600 秒）以上たち、その間に主の新しい入力が無ければ、新しい出力語 `owner-away <N>...`（exit 0）で返す
- 同じターンでは一度だけ返す（子の記録に `owner_away_told` を持つ）
- この知らせは子に何も送らず、`orca terminal close` も `--relaunch` も呼ばず、`stop` 印も変えない。`--resolve` の判断・声かけ・長い待ちの対象にもしない
- 手順書 `references/epic-stop.md` と `references/epic.md` を上の形に合わせて書き換える

## Capabilities

### Modified Capabilities

- `dev-workflow-epic-state`: 主が打ったターンの時間による知らせ（`owner-away`）を足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`・`tests/epic-dispatch.bats`・`skills/develop/references/epic-stop.md`・`skills/develop/references/epic.md`・`changes/1745.md`
- 子側のフック（`epic-child-state.sh`）は変えない。古い記録（`owner_away_told` の無いもの）は未通知として扱う
