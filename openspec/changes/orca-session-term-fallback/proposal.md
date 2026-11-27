# Proposal

## Why

エピックの子の PR を主がマージしたあと、親の `notify-closed` が `failed <N> ambiguous-terminal` で終わり、子のセッションとワークツリーが片付かないまま残る（#1598。2026-11-07 の genetta-inc/flatmate エピック #1995、2026-11-18 の同 #698 で観測）。子のワークツリーの端末は 1 つで、そこで子の Claude Code が動いていた。ただし Orca の端末一覧では `agentIdentity` が null、`title` が子の付けたセッション名で、`Claude Code` を含まなかった。今の決め方はこの 2 つしか見ないので、端末を選べない。`reply --as owner` も同じ理由で落ち、主の答えが子に届かなかった。

## What Changes

- Orca の部品が子のセッションの端末を決めるとき、`agentIdentity` でも題名でも決まらず、ワークツリーの端末がちょうど 1 つなら、その端末の画面を 1 回読む。下端に Claude Code の入力枠があれば、その端末を子のセッションとして選ぶ
- 画面を読めない・下端に入力枠が無いときは、今までどおり `ambiguous-terminal` で送らない。端末が 2 つ以上のときは画面を読まない
- 当てる先は `deliver`（`reply`・`notify-closed`・`wait --resolve`）と `keepalive`。`launch` の起動を待つ判定（`shell_start`）は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の子のセッションの端末の決め方に、1 端末の画面で確かめる段を足す

## Impact

- `plugins/dev-workflow/scripts/epic-launch-orca.sh`（端末の決め方・`cmd_deliver`・`cmd_keepalive`）
- `plugins/dev-workflow/tests/epic-dispatch.bats`
- 起動部品の契約（`deliver` / `keepalive` の stdout の語）は変えない。tmux の部品は変えない
