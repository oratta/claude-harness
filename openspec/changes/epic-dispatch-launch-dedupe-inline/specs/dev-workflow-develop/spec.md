## ADDED Requirements

### Requirement: launch は同じ呼び出し内で渡された重複した子番号も skipped にする
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、引数に渡された子番号を先頭から処理する際、同じ呼び出しの中で既に `launched`・`skipped`・`failed` のいずれかとして処理済みの番号が再び現れたら、`orca worktree create` を呼ばずに `skipped <N>` を出さなければならない（MUST）。これは要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち「一覧に同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出す」規定（`spec.md:462`）を書き換えず、同じ `skipped <N>` の出力形のまま、判定基準に「同じ呼び出し内で既に処理済みの番号」を追加するものである。

この要件の守備範囲で入力として扱うのは、`launch` の引数に渡された子番号の並びである。拾いたい誤りは、同じ呼び出しの中で同じ子番号を 2 回以上渡したときに `orca worktree create` が複数回呼ばれ、同じ子のセッションが二重に起動することである。次は通してよく、この要件では止めない: 3 回以上同じ番号が渡された場合も 2 回目以降すべてが `skipped` になればよく、その回数を区別した出力は要求しない／`route` が重複した番号をそのまま通す既存の引数検査（`spec.md:466`）は変えない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、同じ呼び出し内で子番号を重複させたとき 2 回目以降が `orca worktree create` を呼ばずに `skipped` になることを確かめなければならない（MUST）。

#### Scenario: 同じ呼び出し内で重複した子番号は 2 回目以降 skipped になる
- **WHEN** 一覧に既存ワークツリーが無い環境で `epic-dispatch.sh launch 420 11 11` を実行する
- **THEN** `orca worktree create` は子 11 について 1 回だけ呼ばれ、stdout は `launched 11` と `skipped 11` を含む

#### Scenario: 一覧チェックによる skipped と同じ呼び出し内の重複による skipped は同じ形で出る
- **WHEN** 一覧に子 12 の既存ワークツリーがあり、かつ引数に子 11 を 2 回渡した状態で `epic-dispatch.sh launch 420 11 12 11` を実行する
- **THEN** stdout は `launched 11`・`skipped 12`・`skipped 11` の3行で、`orca worktree create` は子 11 について 1 回だけ、子 12 については 0 回呼ばれる
