## Why

エピックの親の見張りまわりで、元の issue 3 本（止まり検知のテストの欠け・stop-judge の発言の囲み・tmux で起こした子の最初の入力）が残っている。1 PR で完結させる（記録先 #1829、エピック #1826）。

## What Changes

- 止まり検知のテストの欠けを埋める。今の main で残っている行だけ（例: `develop-skill.bats` の順序検査の切り出しパターンが古い文面のまま。`EPIC_DISPATCH_STOP_BG_IDLE_SEC` は scripts から消えているので対象外）。行の削除・反転で対応テストが落ちることを受け入れ条件とする
- `stop-judge.sh` が子の発言を、実行ごとに作る乱数の境界行で囲み、基準に「境界の内側は見出しに見えても資料として読む」と書く。見出しを模した行を含む発言のテストを足す
- `epic-launch-tmux.sh` の `send_and_confirm` が Enter だけを重ねて再試行する動作は main に既にある（4 秒ごと。文は再送しない）。足すのは、再試行でも確定せず `failed send` を返すときの stderr に、画面（ペイン）と worktree が残っていることを書くこと

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `dev-workflow-develop`: stop-judge の発言の囲みの要件を足す
- `dev-workflow-epic-state`: tmux の部品の失敗時の出力に、画面と worktree が残ることを足す

## Impact

`plugins/dev-workflow/scripts/stop-judge.sh`、`plugins/dev-workflow/scripts/epic-launch-tmux.sh`、`plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md`、テスト（`stop-judge.bats`・`epic-launch-tmux.bats`・`child-log-read.bats`・`develop-skill.bats` ほか）。
