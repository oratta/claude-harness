# Proposal

## Why

エピックの親の見張りに、止まりの扱いの穴が 3 系統残っている（issue #1828。元は #1541・#1759・#1789）。親の `dismiss` が主への問いや読めない止まりまで落としうること、子が説明だけを返したターンで未回答のリスク許容の止まりが `resumed` に書き換わり親の返事が拒まれること、`owner-away` の出力行数・掛け直し・テストの文面とのずれである。

## What Changes

- `epic-dispatch.sh pending-owner` が `status != done` の子だけを対象にする（`told` と揃える）
- `references/epic-stop.md` 手順 8 の `dismiss` の条件を、今回の停止の記録・止まった理由・主への問い・読めない止まりのどれも無いときに絞る。`epic-multirepo.md` の列挙に `dismiss` を足す
- `stop-judge.sh` は `判断: 問いではない` のとき未回答の停止の記録を確かめ、あれば形の崩れ（exit 1）にする。親はその止まりを `dismiss` しない
- `owner-away` の出力行数を 1〜5 行（resolve あり）・1〜4 行（なし）に直し、`owner-away` で起こされた親は同じ出力のほかの行を処理し終えてから `wait` を掛け直すと書く
- `owner-away` に閾値後の `--resolve` と排他取得失敗のテストを足す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: wait の判断と出力行数、Orca 経路の dismiss の条件、再起動した親の pending-owner、別リポジトリの読み替え、未回答の停止の記録（新規 2 要件）、owner-away 後の掛け直し（新規）
- `dev-workflow-epic-state`: owner-away は一度だけ返す要件に、閾値後の `--resolve` と排他取得失敗の場面を足す

## Impact

`plugins/dev-workflow/scripts/epic-dispatch.sh`・`stop-judge.sh`、`skills/develop/references/epic-stop.md`・`epic-multirepo.md`、`tests/epic-dispatch.bats`・`stop-judge.bats`・`develop-skill.bats`。
