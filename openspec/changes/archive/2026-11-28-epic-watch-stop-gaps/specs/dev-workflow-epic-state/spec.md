## MODIFIED Requirements

### Requirement: owner-away は一度だけ返し、子にも既存の停止にも触れない

`owner-away` を返す前に、排他つきで同じターンのまま記録の `owner_away_told` に今回のターンの `generation` と `session_id` を書かなければならない（MUST）。書けなければ返さず、そのポーリングを失敗したポーリングに数える。書く直前に入力が更新されていれば書かず返さない。同じターンで 2 回返してはならない（MUST NOT）。この知らせは子に何も送らず、端末を閉じず、起動し直さず、`stop`・`stop_uuid` を変えず、`--resolve` の判断・声かけ・長い待ちの判定に渡してはならない（MUST NOT）。

#### Scenario: 同じターンでは一度だけ知らせる
- **WHEN** `owner-away 11` を返したあと、同じ記録にもう一度同じコマンドを実行する
- **THEN** 2 回目は `owner-away` を返さない

#### Scenario: 知らせは子の記録と端末に触れない
- **WHEN** `owner-away 11` を返した直後の記録を読む
- **THEN** `stop`・`stop_uuid` は変わらず、`owner_away_told` は今回のターンの `generation` と `session_id` を持つ。送信・`orca terminal close`・`--relaunch` は呼ばれていない

#### Scenario: 閾値を過ぎたあとに resolve を付けても知らせるだけで何も呼ばない
- **WHEN** 子 11 の記録が `owner-away` の閾値を過ぎた状態で `wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11` を実行する
- **THEN** stdout は `owner-away 11`、exit 0 で、判断・子への送信・`orca terminal close`・`orca terminal create` は 0 回で、`owner_away_told` は今回のターンになる

#### Scenario: 記録に書けなければ知らせず、書けるまで owner_away_told は空のまま
- **WHEN** 閾値を過ぎた子 11 の記録の排他（`<記録>.lock` のディレクトリ）が取れない状態で `EPIC_STATE_LOCK_TIMEOUT=0` の `wait --interval 0 --timeout 0 --watch-stopped 11` を実行する
- **THEN** stdout は `timeout 11` で `owner-away` は出ず、`owner_away_told` は空（null）のままである
