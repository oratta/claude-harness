## Why

エピックの親が子に送った主のリスク許容を子のゲートが受け取る経路（#1059）の「偽の文では通らない、本物の文では通る」は、これまで実機の Orca を主の手で動かして確かめていた（#1090）。親・子・主の入力が絡む仕組みを変えるたびに同じ手作業が要る。判定の実体である `owner-reply-check.sh --relayed` の合否は、会話ログを差し替えれば GitHub も Orca も使わずに機械で固定できる。

## What Changes

- 新しい bats `plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats` を足す。親の会話ログ 1 本に、偽の文 2 件と本物の文 1 件を同居させ、`--relayed` を 3 回当てて合否を固定する。`scripts/test.sh owner-reply-relayed-scenario` の 1 コマンドで主の入力なしに合否が出る。
- 仕様 `dev-workflow-owner-reply-check` に、この回帰の範囲（固定するもの・固定しないもの）を要件として足す。
- 実機 Orca による確認（PR #1066 の 2 段の手順）は残す。コードの変更は無い。

## Capabilities

### Modified Capabilities
- `dev-workflow-owner-reply-check`: 親経由の返事の合否を、偽 2 件・本物 1 件の混在ログで固定するテストの要件を足す

## Impact

- 足すのはテストと仕様のみ。`owner-reply-check.sh` は変えない。
