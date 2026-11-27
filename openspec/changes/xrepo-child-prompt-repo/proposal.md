# Proposal

## Why

エピックと子が別のリポジトリにあるとき（`xrepo=1`）、`epic-dispatch.sh launch` が子に送る最初の入力は `/develop #892 （エピック #1810 の子。エピックのリポジトリ oratta/claude-harness。…）` の形になる。子の番号にリポジトリが付いておらず、文中に出るリポジトリ名はエピックの側だけなので、子はエピックの側のリポジトリの #892 を読みに行く（#1825。2026-11-26、genetta-inc/flatmate#892 の子が oratta/claude-harness#892 を読みに行き、親が画面で訂正した）。今の要件は、`owner-reply-check.sh` の判定の都合でこの番号だけの形を MUST にしている。

## What Changes

- `xrepo=1` の launch の最初の入力を `/develop <子の owner>/<repo>#<N> （エピック <エピックの owner>/<repo>#<E> の子。親ワークツリー … から Orca で起動）` にする
- `xrepo=1` の起動し直しの指示（`reply --relaunch`・端末 0 個の起動し直し・`notify-closed --relaunch`・`wait --resolve`）も同じ形にする
- `エピックのリポジトリ <owner>/<repo>。` の句は付けない
- `owner-reply-check.sh` の `DISPATCH_ARGS` が、リポジトリ付きの形も起動の指示として主の発言から外すようにする
- 子のターン状態のフック（`epic-child-state.sh` の起動形の判定）が `エピック <owner>/<repo>#<E>` の形を受け、エピックの repo をそこから照合するようにする。旧形（`エピックのリポジトリ` の句）も受け続ける
- `xrepo=0` の入力は 1 文字も変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-epic-state`: 要件「別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す」の最初の入力と起動し直しの指示の形を変える。要件「入力の送り手は予約文と起動形と先頭の接頭辞で決める」の起動形に `エピック owner/repo#E` を足す
- `dev-workflow-owner-reply-check`: 要件「主の発言として数える行と数えない行」の条件 9 に、リポジトリ付きの起動の指示を足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（launch と deliver_reply の `prompt=`）
- `plugins/dev-workflow/scripts/owner-reply-check.sh`（`DISPATCH_ARGS` と冒頭の説明）
- `plugins/dev-workflow/scripts/epic-child-state.sh`（`startup()`）
- `plugins/dev-workflow/tests/epic-dispatch.bats`・`owner-reply-check.bats`・`epic-child-state.bats`
