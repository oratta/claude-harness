## Why

`reply` は `--relaunch` の付け忘れにより、会話が大きい子や長く止まった子を同じセッションで再開してしまう。#1742 は `wait --resolve` の既存判定を直接の返事にも適用し、完了を促すだけの再開を省ける範囲を明らかにする。

## What Changes

- `reply --as parent` / `--as owner` は `--relaunch` なしでも既存の `decide_relaunch` で送り方を決める。会話量 150000 以上、または最後の assistant から 3600 秒以上なら起動し直す。
- 明示の `--relaunch`、再開済みの子への送信抑止、ログを決められない場合の送り方、記録の launcher の選択を維持する。
- 本体による手動判断だけを前提にした時間分類の説明を、`reply` の自動判定に合わせる。
- 親だけの片付けは既に done の子、または既存の完了推定ができる子には足りるが、止まりの印のある子には足りないと記録する。後者の既存 `notify-closed` を残し、適用範囲を手順書に書く。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: reply の起動し直しの自動判定、時間分類の担い手、既存の完了・片付け経路の使い分け。

## Impact

`plugins/dev-workflow/scripts/epic-dispatch.sh`、同 `tests/epic-dispatch.bats`、develop の `references/reply-after-idle.md` と `references/epic-loop.md`、変更記録 `plugins/dev-workflow/changes/1742.md`。launcher の部品・状態スキーマ・完了推定・reap の安全条件は変更しない。記録先は #1742（親 #1732）、PR 本文には `Closes #1742` を書く。

分割判定: 単一 change。issue の 3 つの受け入れ条件は同じ子への返事と終了処理の機能領域に閉じ、独立した設計判断は「完了の強制経路を新設せず既存経路を使い分ける」の 1 件。1 PR で完結する。
