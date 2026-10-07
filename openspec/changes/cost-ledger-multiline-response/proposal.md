## Why

Claude Code は 1 回の API 応答を、中身のブロック（考えた内容・本文・ツール呼び出し）ごとに別の行として会話ログに書き、どの行も同じ `requestId` を持つ。`facts_from_lines` は既出の `requestId` の行を読み飛ばすので、残るのは 1 行目だけで、ツール呼び出しが入る 2 行目以降の `gh issue view/comment/edit <番号>` と投稿（`gh pr comment` など）の印が捨てられる。過去 30 日の実ログで `gh issue view/comment/edit <番号>` を実行した行 7,623 本のうち 5,546 本（72.8%）が 2 行目以降にあった。issue へのコストの割り当てと区間の切れ目が、実際に実行したコマンドと食い違う。台帳には拾えなかった形のまま書かれるので、会話ログが消えると取り戻せない。#303・#689・#690 が積む行と合計はこの割り当てを前提にしている。

## What Changes

- 同じ `requestId` の 2 行目以降に、触った issue 番号か投稿の印があれば、それを持つ**補足の事実**を 1 行ぶん足す。補足の事実はトークンが全部 0（トークンと金額は 1 回分のまま）で、`request_id` は `<元の requestId>#<その行の uuid>`、`continuation: true` を持つ。issue も印も無い後続行は足さない
- 補足の事実は既存の事実と同じ形の 1 行なので、台帳・区間分割・各集計は読み方を変えずに使える。メッセージ数は補足の事実を数えない
- 台帳の既存の行は書き換えない（append-only のまま）。既に台帳へ書いた行の取りこぼしは、会話ログが残っている範囲に限り、`ledger-sync --rescan` が補足の行を**追記**して直す。hook の通常の動きでは全履歴を読み直さない
- 会話ログが無い・消えた期間の既存の行は直せない（その事実は台帳にも無い）

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `cost-ledger-attribution`: 同じ応答の 2 行目以降から issue と投稿の印を拾う要件を足す
- `cost-ledger-persistence`: 台帳の行の定義に補足の事実を加え、`ledger-sync --rescan` で既存の取りこぼしを追記で補う要件を足す

## Impact

- `plugins/cost-ledger/scripts/cost_ledger.py`（`facts_from_lines`・`build_fact` の近く・`summarise`・`price_intervals`・`cmd_report`・`cmd_intervals`・`_ledger_sync_locked`・`cmd_ledger_sync`・`build_parser`）
- `plugins/cost-ledger/tests/`（`multiline.bats` を新規）
- `plugins/cost-ledger/README.md`・`plugins/cost-ledger/changes/695.md`
- エピック #272 の制約: LLM のトークンは使わない・`gh` の呼び出しは増やさない（`facts_from_lines` は `gh` を呼ばない）。全履歴 1 パスの所要時間と hook 1 回の所要時間を変更の前後で実測して PR に書く
- 範囲の境目: #689（issue のクローズ時の合計。`cmd_issue`・`split_intervals`・`price_intervals`・`gate_report.py` を触る）、#699（`facts.bats` の絶対パス検査）、#701（`_drift_lines`）とは触る関数が重なりうる。`price_intervals` は本 change が `messages` の数え方（補足の事実を数えない 1 行）だけを変え、#689 は金額の合計の定義を変える
