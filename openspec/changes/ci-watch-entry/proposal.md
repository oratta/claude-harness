## Why

CI の見張りはゲート合格後にしか始まらない。オーナーがゲート未通過の PR について「CI が通ったらマージして」と頼んでも、CI の失敗からやり直し・修正へ進む入口がない。

## What Changes

- dev-workflow に `/ci-watch <PR>` の入口を追加し、PR の URL または番号を受け取る。
- 入口から既存の共有手順 `references/ci-watch.md` と `scripts/ci-watch.sh` を呼び、待ち方、`--unrelated` の判断、失敗時の一手、PR への開始・終了記録を共用する。
- 条件付きの「マージして」をどう扱うかを入口に明記し、既存の PR ゲートとマージ権限の規則に接続する。
- ゲート未通過の PR で CI を意図的に落とす実機確認を行い、やり直しまたは修正へ進んだ証拠を PR に残す。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-ci-watch`: ゲート未通過 PR から同じ見張りを開始する入口と、その後のマージ依頼の扱いを追加する。

## Impact

- `plugins/dev-workflow/commands/` の新しい入口、必要な `skills/` の手順、共有 `references/ci-watch.md` との接続
- `plugins/dev-workflow/scripts/ci-watch.sh` と `pr-state.sh` は既存の契約を再利用する
- GitHub CLI の認証、PR・checks の読取権限、Actions の再実行と PR コメントに必要な権限、メインセッションの背景タスク完了通知が前提
