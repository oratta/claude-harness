## 1. シナリオ bats

- [x] 1.1 `plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats` を新規に作る。`OWNER_REPLY_PROJECTS_DIR` を一時ディレクトリに向け、親の会話ログ 1 本（停止の記録より前の主の発言・親の報告（URL を含む）・親の発言・ツールの結果・本物の主の「許容」）を組む。触る範囲: plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats（新規）。fixture の書き方は plugins/dev-workflow/tests/owner-reply-check.bats:1-30 と 290-345 に合わせる
- [x] 1.2 偽 1（親の発言・ツールの結果の 2 行）が `REASON=not-owner`、偽 2 が `REASON=not-after`、いずれも exit 1・`MATCHES=0`、本物が exit 0・`MATCH:` に「許容」・`MATCHES=1` になるテストを書く。触る範囲: 同上
- [x] 1.3 偽 1 の 2 行を親の報告と本物のあいだに置き、さらに本物のあとにも置いたログで、本物が exit 0・`MATCHES=1`、偽 1・偽 2 が表どおり落ちるテストを書く。bats の `SCRIPT` は環境変数 `OWNER_REPLY_SCRIPT` で差し替えられるようにする。触る範囲: 同上

## 2. 検査

- [x] 2.1 新しい bats を `git add` してから `scripts/test.sh owner-reply-relayed-scenario` が exit 0。`owner-reply-check.sh` を一時ディレクトリに写し、写しの方で偽を通す側に壊して `OWNER_REPLY_SCRIPT` で当て、落ちることを確かめる（作業ツリーは変えない・git restore は使わない）。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:209-255（読むだけ）
- [x] 2.2 `scripts/lint.sh` と `scripts/test.sh owner-reply` が exit 0
- [x] 2.3 変更の記録 `plugins/dev-workflow/changes/1090.md`（なぜ・何を・確認）を書く。触る範囲: plugins/dev-workflow/changes/1090.md（新規）
