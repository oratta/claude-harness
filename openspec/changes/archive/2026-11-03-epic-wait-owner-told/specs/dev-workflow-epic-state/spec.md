## MODIFIED Requirements

### Requirement: 会話ログによる skipped の理由は次の語に限る

会話ログによって送らないときの `skipped` の理由は次の語に限る（MUST）。`no-transcript`（本体のログなし）・`cache-unknown`（選んだログの最後のキャッシュの書き込みが 1 時間の枠でないか読めない）・`cache-future`（その時刻が今より未来）・`expired`（止まりから `EPIC_DISPATCH_OWNER_WAIT_SEC` 秒（既定 43200）以上、または基点を読めない）・`answered`（親が通した判断がある、または主が答えた）・`no-question`・`out-of-window`（最後のリクエストからの経過が送る範囲にない）・`too-large`（会話量が起動し直しの閾値以上）・`pending`（前の声かけに返事が来ていない）。

#### Scenario: 送らなかった理由が記録から読める
- **WHEN** 起動部品が `skipped dialog` を返す、止まりから 43200 秒を過ぎている、画面は送れるが親が通した判断が既にある、をそれぞれ用意する
- **THEN** 記録の `keepalive` はそれぞれ `skipped dialog`、`skipped expired`、`skipped answered` で終わる

## ADDED Requirements

### Requirement: 記録は主に伝えた止まりを told_uuid に持つ

子の記録は、親が `told` で書く任意の文字列の項目 `told_uuid`（主に伝えた止まりの uuid）と `told_at`（書いた UTC の時刻 `YYYY-MM-DDTHH:MM:SSZ`）を持ってよい（MAY）。`told` 以外のサブコマンドはこの 2 つを書いてはならない（MUST NOT）。記録の `schema` は `1` のままとし、要件「子 1 ファイルの記録は決まった項目を持つ」の「読めない記録」の判定にこの 2 つの有無や形を加えてはならない（MUST NOT）。`told_uuid` が無い・文字列でない記録は、伝え済みでないとして読まなければならない（MUST）。

#### Scenario: told の項目が無い記録も読める
- **WHEN** `told_uuid` と `told_at` の無い以前の記録を `wait` と `pending-owner` が読む
- **THEN** 読めない記録にならず、伝え済みでない止まりとして扱う

#### Scenario: told_uuid が文字列でない記録は伝え済みでない
- **WHEN** 子 11 の記録が `stop` `stopped-seen`・`stop_uuid` `d1`・`told_uuid` が数の `1` で、`wait --interval 1 --timeout 2 --watch-stopped 11` を実行する
- **THEN** 読めない記録にならず、上限 2 秒で stdout は `timeout 11` の 1 行で exit 2
