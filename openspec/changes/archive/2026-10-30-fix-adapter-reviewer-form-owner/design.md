## Context

文言を実装の現物に合わせるだけで、動作は変わらない。

## Decisions

設計の選択は無い。持ち主は現物（`stages/triage.md:198`、`stages/review-run.md:28,42`）で一意に決まる。

## Overlap with open PRs

- #1473 は同じ spec の 547 行付近を触る。本変更は 527・539・543 行のみで行が離れる
- #1436（#580）は同じ bats の grep 行を `${SUMMARY}` に変える。本変更はテスト名の行（240 行）と冒頭コメント（8 行）だけを変え、grep の行は変えない
- #1436（#580）が form の段落を `stages/triage-summary.md` へ移すときは、spec の持ち主（本変更で `stages/triage.md` にする部分）も直す必要がある。#1436 の範囲には手を出さず、#1436 へのコメントは本体が行う
- 他の「gate-runner.md」への言及は form の持ち主の話でないので触らない
