## ADDED Requirements

### Requirement: wait --watch-done は推定した完了を記録に書き、Orca の印へ写す

`wait --watch-done` が dev-workflow-develop の要件「epic-dispatch.sh wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する」の条件を満たした子について記録を書くときは、要件「記録は一時ファイルから置き換え、親と子の書き込みを排他する」の排他の中で、`status` が `running` で `stop` が `stopped` / `stopped-seen` でないことを確かめ直してから、`status` を `done` にし、次の 2 つの項目を足さなければならない（MUST）。

| 項目 | 型 | 中身 |
|---|---|---|
| `done_inferred_at` | 文字列 | 親が推定して書いた時刻。UTC の `YYYY-MM-DDTHH:MM:SSZ` |
| `done_inferred_last_activity` | 文字列 | 推定の根拠にした、子のトランスクリプトの最後の活動の `timestamp`（そのままの文字列） |

この 2 つは親が推定したときだけ書く項目で、子の `mark done` は書かない（MUST NOT）。読み手は知らない項目として無視してよく、記録の `schema` は `1` のままとする（MUST）。要件「子 1 ファイルの記録は決まった項目を持つ」の「読めない記録」の判定に、この 2 つの有無や形を加えてはならない（MUST NOT）。

確かめ直しで外れたとき（その間に子が `mark done`・`mark waiting`・`mark stopped` を付けた）は書かず、そのポーリングではその子を推定しない（MUST）。排他が取れない・書けないときは、`--watch-stopped` の書き換えと同じく、そのポーリングを失敗したポーリングに数える（MUST）。

書けたら、要件「Orca の部品は記録を書いたあとに Orca の印へ写す」に加えて、記録の `launcher` が `orca` のときは Orca の部品の `mirror <記録の worktree> done <記録のパス>` を呼ばなければならない（MUST。子の `mark done` と同じ `--workspace-status completed` の印になる）。写しに失敗しても書き込みを成功として扱う（MUST）。

#### Scenario: 推定した完了は排他つきで書かれ、推定の項目が付く
- **WHEN** 子 11 の記録が `status` `running`・`stop` 空・`extra: 1` を持ち、推定の条件を満たした状態で `wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 記録の `status` は `done`、`done_inferred_at` は UTC の形、`done_inferred_last_activity` はトランスクリプトの最後の `timestamp` で、`extra` と `schema` 1 は残り、`.lock` も一時ファイルも残っていない

#### Scenario: 残ったロックがあると推定は書かずに失敗したポーリングに数える
- **WHEN** 子 11 の記録の `.lock` ディレクトリを先に作り、`EPIC_STATE_LOCK_TIMEOUT=0` で、推定の条件を満たした状態で `wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 記録の `status` は `running` のまま、3 回のポーリングのあと stdout は `error workspaces` で exit 1 である

#### Scenario: Orca の部品の子は completed の印へ写す
- **WHEN** 記録の `launcher` が `orca` の子 11 の完了を推定する
- **THEN** `orca worktree set --worktree path:<子のワークツリー> --workspace-status completed` が 1 回呼ばれる（`epic-dispatch.sh` からは Orca の部品の `mirror` を通す）
