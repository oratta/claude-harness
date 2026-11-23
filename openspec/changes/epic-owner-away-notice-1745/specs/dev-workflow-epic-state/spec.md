## ADDED Requirements

### Requirement: 主が打った返事待ちは時間がたったら親が主に知らせる

`wait --watch-stopped` は、閉じていない位置引数の子の記録が、`status` が `done` でなく、有効な `turn_input` の `sender` が `owner`、同じ世代・セッションの有効な `turn_state` の値が `主の返事待ち`、`turn_state.recorded_at` から `EPIC_DISPATCH_OWNER_AWAY_SEC`（既定 3600 秒）以上たち、`owner_away_told` が今回のターンと違うときに、その子を `owner-away <N>...` の行で返さなければならない（MUST）。出力は `closed` / `done` / `stopped` と同じく該当する語の行を並べて exit 0 で終わる。`EPIC_DISPATCH_OWNER_AWAY_SEC` が非負整数でなければ、何も呼ばずに使い方を出して exit 1 で終わる（MUST）。

#### Scenario: 既定の時間を過ぎた主の返事待ちを知らせる
- **WHEN** 子 11 の `turn_input.sender` が `owner`、`turn_state` が有効な `主の返事待ち` で `recorded_at` が 3600 秒以上前の状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-stopped 11` を実行する
- **THEN** stdout は `owner-away 11`、exit 0 で、子への送信・`orca terminal close`・`--relaunch` は呼ばれず、記録の `stop` は変わらない

#### Scenario: 時間より前は知らせない
- **WHEN** 同じ記録の `recorded_at` が 3600 秒に満たない状態で同じコマンドを実行する
- **THEN** stdout は `timeout 11`、exit 2 である

#### Scenario: 環境変数で時間を変えられる
- **WHEN** `EPIC_DISPATCH_OWNER_AWAY_SEC=60` で `recorded_at` が 120 秒前の記録に同じコマンドを実行する
- **THEN** stdout は `owner-away 11` である。同じ記録で `EPIC_DISPATCH_OWNER_AWAY_SEC=7200` なら `timeout 11` である

#### Scenario: 主が新しく入力したら知らせない
- **WHEN** 主が新しく入力して `turn_input` の世代が `turn_state` と違う記録に同じコマンドを実行する
- **THEN** `owner-away` は返らない

### Requirement: owner-away は一度だけ返し、子にも既存の停止にも触れない

`owner-away` を返す前に、排他つきで同じターンのまま記録の `owner_away_told` に今回のターンの `generation` と `session_id` を書かなければならない（MUST）。書けなければ返さず、そのポーリングを失敗したポーリングに数える。書く直前に入力が更新されていれば書かず返さない。同じターンで 2 回返してはならない（MUST NOT）。この知らせは子に何も送らず、端末を閉じず、起動し直さず、`stop`・`stop_uuid` を変えず、`--resolve` の判断・声かけ・長い待ちの判定に渡してはならない（MUST NOT）。

#### Scenario: 同じターンでは一度だけ知らせる
- **WHEN** `owner-away 11` を返したあと、同じ記録にもう一度同じコマンドを実行する
- **THEN** 2 回目は `owner-away` を返さない

#### Scenario: 知らせは子の記録と端末に触れない
- **WHEN** `owner-away 11` を返した直後の記録を読む
- **THEN** `stop`・`stop_uuid` は変わらず、`owner_away_told` は今回のターンの `generation` と `session_id` を持つ。送信・`orca terminal close`・`--relaunch` は呼ばれていない

### Requirement: owner-away の守備範囲を限る

上の 2 つの要件（主が打った返事待ちの知らせ・owner-away の一度きりの記録）は、入力として扱うものを、子の記録の `turn_input` / `turn_state` / `owner_away_told` と `EPIC_DISPATCH_OWNER_AWAY_SEC` の値に限らなければならない（MUST）。拾いたい誤りは、主が話している最中の子への送信と端末の終了、同じ問いの繰り返しの知らせ、主が答えたあとの知らせである。次は通してよく、止めない: 親や起動時の入力のターン（既存の停止の経路で扱う）・状態記録の無い古い子（知らせない）・別の経路で解決済みの問いへの余分な 1 回の知らせ。穴が見つかるたびに塞ぎ切ることは完了条件にしない。

#### Scenario: 親が送った入力のターンと古い子は知らせの対象にしない
- **WHEN** `turn_input.sender` が `parent` の返事待ち、または `turn_input` / `turn_state` の無い記録に `wait --watch-stopped` を実行する
- **THEN** `owner-away` は返らない（前者は既存の `stopped` の経路、後者は何も返さない）
