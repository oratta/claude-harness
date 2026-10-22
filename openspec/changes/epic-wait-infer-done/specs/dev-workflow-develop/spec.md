## ADDED Requirements

### Requirement: epic-dispatch.sh wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する

`plugins/dev-workflow/scripts/epic-dispatch.sh` の `wait` は、`--watch-done <N>` で渡された子ごとに、ポーリングごとに次の 5 つをこの順に確かめ、すべて満たした子の完了を推定しなければならない（MUST）。LLM を呼んではならない（MUST NOT）。

1. 親の見張りの照合で子の記録がちょうど 1 件読め、`status` が `running` である（`waiting`・`done` は推定しない）
2. 記録の `stop` が `stopped` でも `stopped-seen` でもない
3. 記録の `worktree` が空でなく、子のトランスクリプト（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/<worktree の英数字以外を - にした名前>/*.jsonl`。`wait --resolve` の起動し直しの判定と同じ求め方で、置き場を求める処理は 1 つの関数を共有する）がちょうど 1 本ある
4. そのトランスクリプトのうち `timestamp` を持つ行（種類を問わない）の最大値を最後の活動とし、今の時刻との差が `EPIC_DISPATCH_DONE_IDLE_SEC`（秒・既定 1800）以上である。`timestamp` を持つ行が無い・読めない・`python3` が無いときは満たさない
5. 子 issue を、位置引数の子と同じ `gh` の呼び出しの形（記録の `repo` で決まる `issue_api`）で 1 回読み、`state` が `closed` で `state_reason` が `completed` である

1〜4 のどれかを満たさない子について `gh` を呼んではならない（MUST NOT）。5 の `gh` が失敗したときは、そのポーリングではその子を推定せず、失敗したポーリングにも数えない（MUST）。すべて満たした子は、要件「wait --watch-done は推定した完了を記録に書き、Orca の印へ写す」（dev-workflow-epic-state）のとおり記録に書き、書けたら stderr に `inferred done <N>: issue closed as completed, no transcript activity since <最後の活動>` を出し、印が付いた子として `done <N>...` の行に入れなければならない（MUST）。stdout の行の形・順・exit code は今の `--watch-done` の規定のまま変えてはならない（MUST NOT。推定の `done` を別の行にしない）。

`--watch-done` が 1 つ以上ある `wait` は、ポーリングを始める前に `EPIC_DISPATCH_DONE_IDLE_SEC` を確かめ、空か数字でなければ stderr に理由と使い方を出して exit 1 で終わり、`gh` を呼んではならない（MUST）。

この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」と要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」の「ポーリング 1 回あたりの `gh` の呼び出しは位置引数の子の数と同じ」の規定に優先し、推定の候補（1〜4 を満たした `--watch-done` の子）1 件ごとに `gh` の呼び出しが 1 回増えることを許す。

`plugins/dev-workflow/scripts/epic-dispatch.sh` の冒頭のコメントの `wait` の説明に、推定の 5 つの条件・`EPIC_DISPATCH_DONE_IDLE_SEC` とその既定・推定の `done` が同じ `done <N>` の行に出ることを書かなければならない（MUST）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、偽の `gh` とテスト用の `CLAUDE_PROJECTS_DIR` で、次を確かめなければならない（MUST）: 5 つを満たすと stdout が `done <N>` で記録の `status` が `done` になり推定の項目が付くこと／最後の活動が閾値より新しい・トランスクリプトが 0 本・2 本以上・`status` が `waiting`・`stop` が `stopped` / `stopped-seen` のときは `gh` を呼ばずに推定しないこと／issue が `open`・`state_reason` が `completed` でないときは推定しないこと／`EPIC_DISPATCH_DONE_IDLE_SEC` で閾値を変えられ、数字でない値は exit 1 で `gh` を呼ばないこと。

この要件の守備範囲で入力として扱うのは、記録の `status`・`stop`・`worktree`、子のトランスクリプトの `timestamp`、子 issue の `state` と `state_reason` である。拾いたい誤りは、主がマージして記録先が閉じたのに子が印を付けず親が待ち続けることと、まだ動いている子・主の確認待ちの印（`waiting`）を付けた子・止まった印の経路にいる子を完了とすることである。次は通ってよく、この要件では止めない: 主が閾値より長く子のタブを離れてから同じタブで追加の作業を頼もうとしたときにワークツリーが片付いていること（`reap` の確認が未コミットの変更とマージに入っていない commit を残す）／時計のずれで最後の活動が未来になり推定されないこと／トランスクリプトが 2 本以上の子が今までどおり待たれること。

#### Scenario: 閉じて動きの止まった子は完了と推定される
- **WHEN** 子 11 の記録が `status` `running`・`stop` 空、トランスクリプトが 1 本で最後の活動が 40 分前、子 issue が `closed`・`completed` の状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** stdout は `done 11`、exit 0 で、記録の `status` は `done`、`done_inferred_at` と `done_inferred_last_activity` があり、stderr に `inferred done 11` で始まる行が出る

#### Scenario: 最後の活動が新しい子は推定しない
- **WHEN** 最後の活動が 10 分前で、ほかは直前の Scenario と同じ状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、exit 2 で、記録の `status` は `running` のまま、`gh` は呼ばれない

#### Scenario: トランスクリプトが 0 本か 2 本以上なら推定しない
- **WHEN** 子 11 のトランスクリプトの置き場に `.jsonl` が無い、または 2 本ある状態で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま、`gh` は呼ばれない

#### Scenario: waiting の子と止まった印の子は推定しない
- **WHEN** 子 11 の記録の `status` が `waiting`、または `stop` が `stopped` か `stopped-seen` で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録は変わらず、`gh` は呼ばれない

#### Scenario: 開いている子・completed 以外で閉じた子は推定しない
- **WHEN** 子 11 の issue が `open`、または `closed` で `state_reason` が `not_planned` で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま

#### Scenario: 閾値を変えられ、誤った値は使い方を出す
- **WHEN** 最後の活動が 10 分前の子 11 で `EPIC_DISPATCH_DONE_IDLE_SEC=300` を付けて `wait --interval 0 --timeout 60 --watch-done 11` を実行し、別に `EPIC_DISPATCH_DONE_IDLE_SEC=abc` を付けて同じコマンドを実行する
- **THEN** 前者は stdout が `done 11` で、後者は exit 1 で stdout は空、stderr に使い方が出て `gh` は呼ばれない

### Requirement: 回し方の手順は推定した done も子の付けた done と同じに片付ける

develop の `SKILL.md`「エピックの扱い」→「回し方」の別セッション方式の手順は、次を書かなければならない（MUST）。

- 手順 2 の `--watch-done` の説明に、`wait` は片付け待ちの子のうち、完了の印の無いまま記録先が `completed` で閉じ、子のトランスクリプトの最後の活動が `EPIC_DISPATCH_DONE_IDLE_SEC`（既定 1800 秒）以上前の子を、LLM なしで完了と推定して `done <N>` を返すこと（`status` が `waiting` の子・止まった印の子・トランスクリプトが 1 本でない子は推定しない）
- 手順 3 に、推定の `done` も子が付けた `done` と同じに `reap` を 1 回呼んで扱い、区別しないこと（片付けの安全確認は `reap` が行う）
- 手順 4 に、`notify-closed` が `skipped <N> not-stopped` を返した子（止まった印を付けずに見張りを終えた子。主に直接マージを頼んだ子など）は、片付け待ちとして `--watch-done` に渡しておけば、子のセッションが止まって閾値を過ぎたあとの `wait` が完了と推定すること。主に子のステータスを変えるよう頼まない（MUST NOT）

`plugins/dev-workflow/tests/epic-dispatch.bats`（または `tests/develop-skill.bats`）は、手順 2〜4 の文面に `EPIC_DISPATCH_DONE_IDLE_SEC` と推定の扱いがあることを確かめなければならない（MUST）。

#### Scenario: 回し方に推定の扱いが書かれている
- **WHEN** SKILL.md の「エピックの扱い」の「回し方」の手順 2〜4 を読む
- **THEN** 手順 2 に `wait` が完了を推定する条件と `EPIC_DISPATCH_DONE_IDLE_SEC` が、手順 3 に推定の `done` も同じに `reap` することが、手順 4 に `skipped <N> not-stopped` の子は `--watch-done` の推定で片付くことが書かれている

### Requirement: エピックの子は主にマージを頼むとき、マージ後の連絡を頼まない

develop の `SKILL.md`「ループの終わり」は、エピックの子（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested`）が PR のマージを主に頼んで（PR がマージされていないので `mark` を呼ばずに）ループを終えるとき、完了報告で「マージしたら教えてください」「ステータスを変えます」のような、マージ後に子のタブへ戻る連絡を主に頼んではならない（MUST NOT）と書き、代わりに「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くことを規定しなければならない（MUST）。親の `wait --watch-done` が完了を推定することを理由として添える（SHALL）。エピックの子でないセッションの完了報告には、この規定を当てない。

#### Scenario: ループの終わりにマージ後の連絡を頼まない規定がある
- **WHEN** SKILL.md の「ループの終わり」を読む
- **THEN** エピックの子が主にマージを頼んで終えるとき、マージ後の連絡を頼まず「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くことと、その理由（親の `wait` が完了を推定する）が書かれている
