## 1. 実装（PR #1287 に済み）

- [x] 1.1 `deliver_reply` に、送る直前の `stop` の確認を足し、止まっていなければ `skipped <child> not-stopped` を出して 2 を返す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh（deliver_reply）
- [x] 1.2 `cmd_reply` が戻り値 2 を exit 0 にし、`cmd_notify_closed` と `resolve_stopped` が `skipped <N> not-stopped` を受けて送らず投稿しない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh（cmd_reply・cmd_notify_closed・resolve_stopped）
- [x] 1.3 記録が `stopped-seen` のままでも会話ログが止まりの発言より進んでいれば送らない（`record_log_json`・`log_moved`）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh（deliver_reply）
- [x] 1.4 手順 8 に `skipped <N> not-stopped` の扱いを足す。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md（手順 8）

## 2. テスト

- [x] 2.1 `reply` の再開済み・`stopped-seen`・会話ログが進んだ `stopped-seen`・会話ログが止まりのままの `stopped-seen`、`wait --resolve` の再開済みを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（reply・wait --resolve の節）

## 3. 記録

- [x] 3.1 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1109.md
