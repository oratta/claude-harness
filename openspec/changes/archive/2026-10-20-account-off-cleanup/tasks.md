## 1. 実装

- [x] 1.1 `select-account.sh` のオフのスロットの明示選択の stderr 文面を、`accounts.sh on <id>` の案内に変える（id・オフであること・`enabled`・登録簿のパスは残し、1 行のまま）。触る範囲: plugins/dev-workflow/scripts/select-account.sh:46-52
- [x] 1.2 `accounts.sh off b` のあとの `select-account.sh b` の stderr に `accounts.sh on b` が含まれることを確かめるテストを足す（既存テストは変えない）。触る範囲: plugins/dev-workflow/tests/account-selector.bats:447-461 の直後
- [x] 1.3 既定スロット a がオフ・スロット b がオンで使用量が欠測のとき、exit 0 で stderr が `selected=a reason=default-due-to-missing-usage margins=a:off,b:missing` になるテストを足す（#987）。触る範囲: plugins/dev-workflow/tests/account-selector.bats（`enabled:` の既存テスト群の末尾付近）

## 2. 検証

- [x] 2.1 `bats plugins/dev-workflow/tests/account-selector.bats` が通る
- [x] 2.2 `openspec validate --all --strict` が exit 0

## 3. 変更の記録

- [x] 3.1 plugin-editing ルールで必須の変更記録 `plugins/dev-workflow/changes/1005.md`（新規）を書く。触る範囲: plugins/dev-workflow/changes/1005.md（新規）
