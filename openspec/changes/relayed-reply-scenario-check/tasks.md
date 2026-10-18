## 1. シナリオ bats

- [ ] 1.1 `plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats` を新規に作る。`OWNER_REPLY_PROJECTS_DIR` を一時ディレクトリに向け、親の会話ログ 1 本（停止の記録より前の主の発言・親の報告（URL を含む）・親の発言・ツールの結果・本物の主の「許容」）を組む。触る範囲: plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats（新規）。fixture の書き方は plugins/dev-workflow/tests/owner-reply-check.bats:1-30 と 290-345 に合わせる
- [ ] 1.2 偽 1（親の発言・ツールの結果の 2 行）が `REASON=not-owner`、偽 2 が `REASON=not-after`、いずれも exit 1・`MATCHES=0`、本物が exit 0・`MATCH:` に「許容」・`MATCHES=1` になるテストを書く。触る範囲: 同上
- [ ] 1.3 偽の行が混在していても本物が通り、本物が混在していても偽が落ちることを確かめるテストを書く。触る範囲: 同上

## 2. 検査

- [ ] 2.1 `scripts/test.sh owner-reply-relayed-scenario` が exit 0。偽を通す側に `owner-reply-check.sh` を一時的に壊す変更（コミットしない）で落ちることを確かめる。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:209-255（読むだけ・戻す）
- [ ] 2.2 `scripts/lint.sh` と `scripts/test.sh owner-reply` が exit 0
- [ ] 2.3 変更の記録 `plugins/dev-workflow/changes/1090.md`（なぜ・何を・確認）を書く。触る範囲: plugins/dev-workflow/changes/1090.md（新規）
