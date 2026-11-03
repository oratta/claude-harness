## Why

Codex のロケットモード（リセット権の失効が週次リセットより前に来る状態）では、週次の窓の日程消化率を「窓の始まりから `rocket.earliest_expiry` まで」に対する位置で数えていた（#1302）。この分母は週次のリセット時刻と失効時刻の両方で動くので、画面の数字が何を指すか読みにくい。オーナーの決定（2026-10-28、記録先 oratta/claude-harness#1393）で、分母を常に 7 日にし、起点を失効の 7 日前にする。

## What Changes

- 要件「Codex のロケットモードを描く」の「経過」を変える。日程消化率は `(現在 − (earliest_expiry − 604800)) × 100 ÷ 604800`（整数に切り捨て、0 から 100）にする。失効が近いほど日程消化率だけが前へ進んで見える（意図どおり）
- 現在が起点より前（`earliest_expiry` が現在の 7 日より先）なら 0 に切り詰める。以前は「日程消化率は無い扱い」だったが、日程消化率 0%・バーの日程の線は先頭にする
- シナリオを 2 つ足す（失効が近いほど前へ進む／起点より前は 0%）。既存シナリオ「経過と残り時間が失効に対して描かれる」の期待値を 29% から 73% に直す
- 残り時間・使える量・名前、Claude の行、週次以外の窓は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `statusline-multi-account-usage`: 要件「Codex のロケットモードを描く」の経過の定義とシナリオ

## Impact

- `plugins/statusline/scripts/statusline.sh`、`plugins/statusline/tests/statusline-headroom.bats`（実装は #1394 で済み）
- 変更の記録 `plugins/statusline/changes/1393.md`
