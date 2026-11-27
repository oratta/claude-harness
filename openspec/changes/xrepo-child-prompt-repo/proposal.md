# Proposal

## Why

エピックと子が別のリポジトリにあるとき（`xrepo=1`）、`epic-dispatch.sh launch` が子に送る最初の入力は `/develop #892 （エピック #1810 の子。エピックのリポジトリ oratta/claude-harness。…）` の形になる。子の番号にリポジトリが付いておらず、文中に出るリポジトリ名はエピックの側だけなので、子はエピックの側のリポジトリの #892 を読みに行く（#1825。2026-11-26、genetta-inc/flatmate#892 の子が oratta/claude-harness#892 を読みに行き、親が画面で訂正した）。今の要件は、`owner-reply-check.sh` の判定の都合でこの番号だけの形を MUST にしている。

## What Changes

- `xrepo=1` の launch の最初の入力を `/develop <子の owner>/<repo>#<N> （エピック #<E> の子。エピックのリポジトリ <エピックの owner>/<repo>。親ワークツリー … から Orca で起動）` にする（子の番号にだけリポジトリを付け、エピックの側は今の句のまま）
- `xrepo=1` の起動し直しの指示（`reply --relaunch`・端末 0 個の起動し直し・`notify-closed --relaunch`・`wait --resolve`）も同じ形にする
- `owner-reply-check.sh` の `DISPATCH_ARGS` が、子の番号にリポジトリを付けた形も起動の指示として主の発言から外すようにする
- 子のターン状態のフック（`plugins/dev-workflow/scripts/epic-child-state.sh`）は変えない。今の起動形の判定が `/develop <repo>#<N>` と `エピックのリポジトリ` の句を既に受けるので、新しい形が `startup` になることをテストで確かめるだけにする（このファイルは聖域パスで、触ると PR が人間マージになる）
- `xrepo=0` の入力は 1 文字も変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-epic-state`: 要件「別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す」の最初の入力と起動し直しの指示の形を変える（子の番号にリポジトリを付ける）
- `dev-workflow-owner-reply-check`: 要件「主の発言として数える行と数えない行」の条件 9 に、子の番号にリポジトリを付けた起動の指示を足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（launch と deliver_reply の `prompt=`）
- `plugins/dev-workflow/scripts/owner-reply-check.sh`（`DISPATCH_ARGS` と冒頭の説明）
- `plugins/dev-workflow/tests/epic-dispatch.bats`・`owner-reply-check.bats`・`epic-child-state.bats`（`epic-child-state.bats` はテストを足すだけ）
- `plugins/dev-workflow/changes/1831.md`（#1831 の 3 つの change の変更の記録）
- 聖域パス（`.github/workflows/auto-merge.yml` の SACRED）のファイルには触らない
