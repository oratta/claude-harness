## MODIFIED Requirements

### Requirement: Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る
`plugins/dev-workflow/scripts/epic-dispatch.sh` は `notify-closed [--relaunch] <epic> <child>` を受け付けなければならない（MUST）。`<epic>` か `<child>` が数字でない・引数の数が違う・`--relaunch` 以外のフラグがある・返事の送り方の環境変数が誤っているときは、使い方を出して exit 1 で終わり、`orca` を呼んではならない（MUST）。

`notify-closed` は次の順に確かめ、条件を満たした子にだけ返事を送らなければならない（MUST）。

1. 子 issue（`gh api repos/{owner}/{repo}/issues/<child>`）の `state` が `closed` でなければ `skipped <child> not-closed`、`state_reason` が `completed` でなければ `skipped <child> not-completed` を出す。`gh` が失敗したら `failed <child> issue` を出す
2. 今のワークツリーと同じ repoId・linkedIssue が `<child>`・archive されていない子のワークツリーが 0 件なら `skipped <child> no-worktree`、2 件以上なら `failed <child> ambiguous-worktree`、一覧を読めなければ `failed <child> list` を出す
3. そのワークツリーの `workspaceStatus` が `completed` なら `skipped <child> already-done`、コメント欄が `epic-stopped` でも `epic-stopped-seen` でもなければ `skipped <child> not-stopped` を出す
4. 条件を満たしたら、要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の `--as parent` と同じ処理（`--relaunch` があれば起動し直す）で、`記録先の issue #<child> は completed で閉じた。完了報告を書き、mark done で終える（停止の記録: <URL>）` を子に送る。`<URL>` は子 issue の 1 行目が `子の停止: 主の返事待ち` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` の最新のものの URL で、見つからなければ子 issue の URL とする。送信の結果が `failed <child> <段>` なら、それを出して exit 1 で終わる
5. 送れたら（`sent` か `relaunched`）、エピックに `親の判断: 子 #<child> 通した — 記録先が completed で閉じたので、完了報告と mark done を促した <URL>` の 1 行をコメントする（記録に `stop_uuid` があれば `<URL>` の前に `発言 <uuid> ` を足す。空なら足さない）。投稿できたら `notified <child>` を出し、投稿に失敗したら `unrecorded <child>` を出して stderr に投稿し直すコマンド（`gh issue comment <epic> --body <その 1 行>`）を出す。エピックへの記録は送信のあとに投稿しなければならない（MUST。送る前に投稿すると、送れなかったときに送っていない判断が残るため）

`skipped`・`notified`・`unrecorded` はどれも exit 0 で、stdout はちょうど 1 行とする（MUST）。`skipped` のときは子に何も送らず、エピックにも子 issue にも投稿してはならない（MUST NOT）。

develop の `references/epic-loop.md` の「通常進行の手順」の Orca 経路の手順 4 は、`closed <N>...` で起こされて `state_reason` が `completed` の子ごとに、`references/reply-after-idle.md` の表で起動し直すかを決めてから `scripts/epic-dispatch.sh notify-closed`（起動し直すなら `--relaunch`）を呼ぶと書かなければならない（MUST）。`notify-closed` は、依存が解けた子の `launch` より先に呼ぶと書く（MUST。`launch` が `failed` を返すと親は手順 6 で止まり、再開の手順 7 は `notify-closed` を呼ばないので、後ろに置くと閉じた子に送られないまま残る）。出力の扱いとして、`notified` と `skipped` は何もしない、`unrecorded` は stderr に出た投稿し直しのコマンドでエピックに 1 行を残す、`failed` は主に報告する（主に出す発言の 1 行目と最後の行は、要件「エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う」に従う）と書く（MUST）。`state_reason` が `completed` でない子には `notify-closed` を呼ばない（SHALL。作業されていない件に完了を促さない）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、偽の `orca` と `gh` で、上の振る舞い（止まった印のまま completed で閉じた子には返事が送られ、エピックに `親の判断: 子 #<child> 通した` で始まる 1 行が残ること、止まっていない子・既に完了の印の子・completed でない子・閉じていない子には何も送らずどこにも投稿しないこと、送れたがエピックへの投稿に失敗すると `unrecorded` を出すこと、送信の失敗で `failed` を出しエピックに投稿しないこと、引数の誤りで `orca` を呼ばないこと）と、手順 4 の文面が `notify-closed` を呼ぶこと、手順 4 の中で `notify-closed` が `launch` より先に現れることを確かめなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、`gh` の出力（子 issue の状態・閉じた理由・コメント）と `orca` の出力（ワークツリーの一覧・端末）である。拾いたい誤りは、止まった印のまま completed で閉じた子に何も届かずワークツリーが残り続けること、止まっていない子や作業されていない件に完了を促すこと、送れなかった返事をエピックに通したと残すことの 3 つである。次は通ってよく、この要件では止めない: 親が同じ `closed` を 2 回処理して同じ促しが 2 回届くこと（子は完了報告を 1 回書いて印を付けるだけ）／主が PR をマージせずに issue を completed で閉じた子に促しが届くこと（`reap` の既存の確認が片付けを止める）／判定のあとに子が自分で再開していて、促しが進んでいる子に届くこと。この 3 つの誤りを起こす入力の組み合わせが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 止まった印のまま completed で閉じた子には返事を送り、エピックに 1 行を残す
- **WHEN** 子 11 の issue が `closed`・`completed` で、子 11 のワークツリーのコメント欄が `epic-stopped-seen`、`workspaceStatus` が `in-review` で、`notify-closed 400 11` を実行する
- **THEN** 子 11 の端末に `親エピック #400 の判断（主の承認ではない）: 記録先の issue #11 は completed で閉じた。完了報告を書き、mark done で終える` で始まる文が送られ、エピック 400 に `親の判断: 子 #11 通した` で始まるコメントが投稿され、stdout は `notified 11` で exit 0 で終わる

#### Scenario: 止まっていない子が閉じたときは返事を送らない
- **WHEN** 子 11 の issue が `closed`・`completed` で、子 11 のワークツリーのコメント欄が空か `epic-resumed` で、`notify-closed 400 11` を実行する
- **THEN** stdout は `skipped 11 not-stopped` で exit 0 で終わり、`orca terminal send` も `orca terminal create` も呼ばれず、`gh issue comment` も呼ばれない

#### Scenario: completed でない理由で閉じた子には返事を送らない
- **WHEN** 子 11 の issue が `closed`・`not_planned` で、ワークツリーのコメント欄が `epic-stopped` で、`notify-closed 400 11` を実行する
- **THEN** stdout は `skipped 11 not-completed` で exit 0 で終わり、子の端末には何も送られず、`gh issue comment` は呼ばれない

#### Scenario: 既に完了の印を付けた子には返事を送らない
- **WHEN** 子 11 の issue が `closed`・`completed` で、ワークツリーの `workspaceStatus` が `completed`、コメント欄が `epic-stopped-seen` で、`notify-closed 400 11` を実行する
- **THEN** stdout は `skipped 11 already-done` で exit 0 で終わり、子の端末には何も送られない

#### Scenario: 送れたがエピックに残せなければ unrecorded を出す
- **WHEN** 条件を満たした子 11 への送信は成功し、エピック 400 へのコメントの投稿が失敗する
- **THEN** stdout は `unrecorded 11` で exit 0 で終わり、stderr に `gh issue comment 400` で始まり `親の判断: 子 #11 通した` を含む投稿し直しのコマンドが出る

#### Scenario: 送れなければエピックに残さず failed を出す
- **WHEN** 条件を満たした子 11 の端末への送信が失敗する
- **THEN** stdout は `failed 11 send` で exit 1 で終わり、`gh issue comment` は呼ばれない

#### Scenario: 引数の誤りでは orca を呼ばない
- **WHEN** `notify-closed 400 abc` か `notify-closed 400` を実行する
- **THEN** stderr に使い方が出て exit 1 で終わり、`orca` は呼ばれない

#### Scenario: 止まりの uuid があればエピックの行に足す
- **WHEN** 子 11 の記録の `stop_uuid` が `a-1` で、`notify-closed 400 11` が返事を送れた
- **THEN** エピックの行は `親の判断: 子 #11 通した — 記録先が completed で閉じたので、完了報告と mark done を促した 発言 a-1 <URL>` である

#### Scenario: 手順 4 は completed の子に notify-closed を呼ぶ
- **WHEN** develop の `references/epic-loop.md` の「通常進行の手順」の Orca 経路の手順 4 を読む
- **THEN** `state_reason` が `completed` の子ごとに `scripts/epic-dispatch.sh notify-closed` を呼ぶことと、`unrecorded`・`failed` の扱いが書かれている
- **AND** `notify-closed` は、依存が解けた子を `launch` するより前に書かれている

### Requirement: epic-dispatch.sh wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する

`plugins/dev-workflow/scripts/epic-dispatch.sh` の `wait` は、`--watch-done <N>` で渡された子ごとに、ポーリングごとに次の 6 つをこの順に確かめ、すべて満たした子の完了を推定しなければならない（MUST）。LLM を呼んではならない（MUST NOT）。

1. 親の見張りの照合で子の記録がちょうど 1 件読め、`status` が `running` である（`waiting`・`done` は推定しない）
2. 記録の `stop` が `stopped` でも `stopped-seen` でもない
3. 記録の `worktree` が空でなく、子のトランスクリプト（`${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}/<worktree の英数字以外を - にした名前>/*.jsonl`。置き場のディレクトリは `wait --resolve` の起動し直しの判定と同じ求め方で、置き場を求める処理は 1 つの関数を共有する（既定の置き場の変更は起動し直しの判定にも掛かる）。起動し直しの判定が使う本体のログの選び方はその判定の側に残し、ここでは置き場の全部の `.jsonl` を読む）が 1 本以上ある
4. 置き場の全部の `.jsonl` と、そのセッションのサブエージェントのトランスクリプト（`<置き場>/<セッション>/subagents/*.jsonl`）を通して、`timestamp` を持つ行（種類を問わない）の最大値を最後の活動とし、今の時刻との差が `EPIC_DISPATCH_DONE_IDLE_SEC`（秒・既定 1800）以上である。`timestamp` を持つ行が 1 つも無い・読めない・`python3` が無いときは満たさない
5. 子 issue を、位置引数の子と同じ `gh` の呼び出しの形（記録の `repo` で決まる `issue_api`）で 1 回読み、`state` が `closed` で `state_reason` が `completed` である
6. 5 と同じ 1 回の `gh` で読んだ `closed_at` と今の時刻との差が `EPIC_DISPATCH_DONE_IDLE_SEC` 以上である。`closed_at` が無いときは満たさない（記録先が閉じた直後に、閉じる前から長く動いている背景のコマンドだけを走らせている子を完了としないため）

1〜4 のどれかを満たさない子について `gh` を呼んではならない（MUST NOT）。5・6 の `gh`（1 回）が失敗したときは、そのポーリングではその子を推定せず、失敗したポーリングにも数えない（MUST）。すべて満たした子は、要件「wait --watch-done は推定した完了を記録に書き、Orca の印へ写す」（dev-workflow-epic-state）のとおり記録に書き、書けたら stderr に `inferred done <N>: issue closed as completed, no transcript activity since <最後の活動>` を出し、印が付いた子として `done <N>...` の行に入れなければならない（MUST）。stdout の行の形・順・exit code は今の `--watch-done` の規定のまま変えてはならない（MUST NOT。推定の `done` を別の行にしない）。

`--watch-done` が 1 つ以上ある `wait` は、ポーリングを始める前に `EPIC_DISPATCH_DONE_IDLE_SEC` を確かめ、空か数字でなければ stderr に理由と使い方を出して exit 1 で終わり、`gh` を呼んではならない（MUST）。

この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」と要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」の「ポーリング 1 回あたりの `gh` の呼び出しは位置引数の子の数と同じ」の規定に優先し、推定の候補（1〜4 を満たした `--watch-done` の子）1 件ごとに `gh` の呼び出しが 1 回増えることを許す。

`plugins/dev-workflow/scripts/epic-dispatch.sh` の冒頭のコメントの `wait` の説明に、推定の 6 つの条件・`EPIC_DISPATCH_DONE_IDLE_SEC` とその既定・推定の `done` が同じ `done <N>` の行に出ることを書かなければならない（MUST）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、偽の `gh` とテスト用の `CLAUDE_PROJECTS_DIR` で、次を確かめなければならない（MUST）: 6 つを満たすと stdout が `done <N>` で記録の `status` が `done` になり推定の項目が付くこと／最後の活動が閾値より新しい・トランスクリプトが 0 本・2 本のうち片方だけ新しい・`status` が `waiting`・`stop` が `stopped` / `stopped-seen` のときは `gh` を呼ばずに推定しないこと／2 本とも古ければ推定すること／issue が `open`・`state_reason` が `completed` でない・閉じてから閾値より短い・`closed_at` が無いときは推定しないこと／サブエージェントのトランスクリプトにだけ閾値より新しい行があるときは推定しないこと／排他の中の確かめ直しで外れたとき（推定の `gh` の間に子が `waiting` を付けた）は推定せず Orca の印へ写さないこと／`EPIC_DISPATCH_DONE_IDLE_SEC` で閾値を変えられ、数字でない値は exit 1 で `gh` を呼ばないこと／同じ子を位置引数と `--watch-done` の両方に渡したとき、閉じたポーリングで `closed <N>` と `done <N>` の 2 行がこの順に出ること。

この要件の守備範囲で入力として扱うのは、記録の `status`・`stop`・`worktree`、子のトランスクリプト（サブエージェントのものを含む）の `timestamp`、子 issue の `state` と `state_reason` と `closed_at` である。拾いたい誤りは、主がマージして記録先が閉じたのに子が印を付けず親が待ち続けることと、まだ動いている子・主の確認待ちの印（`waiting`）を付けた子・止まった印の経路にいる子を完了とすることである。次は通ってよく、この要件では止めない: 主が閾値より長く子のタブを離れてから同じタブで追加の作業を頼もうとしたときにワークツリーが片付いていること（`reap` の確認が未コミットの変更とマージに入っていない commit を残す）／時計のずれで最後の活動が未来になり推定されないこと／記録先が閉じたあと、子が 1 回のツール呼び出しを閾値より長く動かしている（その間トランスクリプトに行が増えない）ときに推定されること（`reap` の確認は変えないので、失うのは後片付けの途中だけ）／マージ後の依頼（動作確認など）を完了報告に書いてマージを主に頼んだ子も、PR が未マージのうちは `waiting` を付けられないので推定され、主の返事の前にタブが閉じること（依頼は完了報告と記録先に残る）。この要件は、ここに挙げていない穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: 閉じて動きの止まった子は完了と推定される
- **WHEN** 子 11 の記録が `status` `running`・`stop` 空、トランスクリプトが 1 本で最後の活動が 40 分前、子 issue が `closed`・`completed` の状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** stdout は `done 11`、exit 0 で、記録の `status` は `done`、`done_inferred_at` と `done_inferred_last_activity` があり、stderr に `inferred done 11` で始まる行が出る

#### Scenario: 最後の活動が新しい子は推定しない
- **WHEN** 最後の活動が 10 分前で、ほかは直前の Scenario と同じ状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、exit 2 で、記録の `status` は `running` のまま、`gh` は呼ばれない

#### Scenario: トランスクリプトが 0 本なら推定しない
- **WHEN** 子 11 のトランスクリプトの置き場に `.jsonl` が無い状態で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま、`gh` は呼ばれない

#### Scenario: トランスクリプトが 2 本なら全部を通した最後の活動で決める
- **WHEN** 子 11 のトランスクリプトの置き場に `.jsonl` が 2 本あり、片方の最後の活動が 40 分前でもう片方が 10 分前の状態で `wait --interval 0 --timeout 0 --watch-done 11` を実行し、別に 2 本とも最後の活動が 40 分前より古い状態で `wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 前者は stdout が `timeout`、記録の `status` は `running` のまま、`gh` は呼ばれない。後者は stdout が `done 11` で、`done_inferred_last_activity` は 2 本を通した最大の `timestamp` である

#### Scenario: 閉じてから閾値より短い子は推定しない
- **WHEN** 子 11 の issue が `completed` で閉じてから 60 秒、または `closed_at` が無い状態で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま

#### Scenario: サブエージェントのトランスクリプトの新しい行も活動に数える
- **WHEN** 子 11 の本体のトランスクリプトの最後の活動は 40 分前で、`<置き場>/<セッション>/subagents/` の `.jsonl` に 10 分前の行がある状態で `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま、`gh` は呼ばれない

#### Scenario: 同じ子が位置引数と --watch-done の両方にあれば closed と done の 2 行を出す
- **WHEN** 子 11 を位置引数と `--watch-done` の両方に渡し、推定される条件のまま `wait --interval 0 --timeout 60 --watch-done 11 11` を実行する
- **THEN** stdout は `closed 11` と `done 11` の 2 行をこの順に出して exit 0 で、記録の `status` は `done` である

#### Scenario: waiting の子と止まった印の子は推定しない
- **WHEN** 子 11 の記録の `status` が `waiting`、または `stop` が `stopped` か `stopped-seen` で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録は変わらず、`gh` は呼ばれない

#### Scenario: 開いている子・completed 以外で閉じた子は推定しない
- **WHEN** 子 11 の issue が `open`、または `closed` で `state_reason` が `not_planned` で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま

#### Scenario: 閾値を変えられ、誤った値は使い方を出す
- **WHEN** 最後の活動が 10 分前の子 11 で `EPIC_DISPATCH_DONE_IDLE_SEC=300` を付けて `wait --interval 0 --timeout 60 --watch-done 11` を実行し、別に `EPIC_DISPATCH_DONE_IDLE_SEC=abc` を付けて同じコマンドを実行する
- **THEN** 前者は stdout が `done 11` で、後者は exit 1 で stdout は空、stderr に使い方が出て `gh` は呼ばれない

