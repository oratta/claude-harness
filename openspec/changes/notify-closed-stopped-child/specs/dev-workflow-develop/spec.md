## ADDED Requirements

### Requirement: Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る
`plugins/dev-workflow/scripts/epic-dispatch.sh` は `notify-closed [--relaunch] <epic> <child>` を受け付けなければならない（MUST）。`<epic>` か `<child>` が数字でない・引数の数が違う・`--relaunch` 以外のフラグがある・返事の送り方の環境変数が誤っているときは、使い方を出して exit 1 で終わり、`orca` を呼んではならない（MUST）。

`notify-closed` は次の順に確かめ、条件を満たした子にだけ返事を送らなければならない（MUST）。

1. 子 issue（`gh api repos/{owner}/{repo}/issues/<child>`）の `state` が `closed` でなければ `skipped <child> not-closed`、`state_reason` が `completed` でなければ `skipped <child> not-completed` を出す。`gh` が失敗したら `failed <child> issue` を出す
2. 今のワークツリーと同じ repoId・linkedIssue が `<child>`・archive されていない子のワークツリーが 0 件なら `skipped <child> no-worktree`、2 件以上なら `failed <child> ambiguous-worktree`、一覧を読めなければ `failed <child> list` を出す
3. そのワークツリーの `workspaceStatus` が `completed` なら `skipped <child> already-done`、コメント欄が `epic-stopped` でも `epic-stopped-seen` でもなければ `skipped <child> not-stopped` を出す
4. 条件を満たしたら、要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の `--as parent` と同じ処理（`--relaunch` があれば起動し直す）で、`記録先の issue #<child> は completed で閉じた。完了報告を書き、mark done で終える（停止の記録: <URL>）` を子に送る。`<URL>` は子 issue の 1 行目が `子の停止: 主の返事待ち` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` の最新のものの URL で、見つからなければ子 issue の URL とする。送信の結果が `failed <child> <段>` なら、それを出して exit 1 で終わる
5. 送れたら（`sent` か `relaunched`）、エピックに `親の判断: 子 #<child> 通した — 記録先が completed で閉じたので、完了報告と mark done を促した <URL>` の 1 行をコメントする。投稿できたら `notified <child>` を出し、投稿に失敗したら `unrecorded <child>` を出して stderr に投稿し直すコマンド（`gh issue comment <epic> --body <その 1 行>`）を出す。エピックへの記録は送信のあとに投稿しなければならない（MUST。送る前に投稿すると、送れなかったときに送っていない判断が残るため）

`skipped`・`notified`・`unrecorded` はどれも exit 0 で、stdout はちょうど 1 行とする（MUST）。`skipped` のときは子に何も送らず、エピックにも子 issue にも投稿してはならない（MUST NOT）。

develop の `SKILL.md`「エピックの扱い」→「回し方」の Orca 経路の手順 4 は、`closed <N>...` で起こされて `state_reason` が `completed` の子ごとに、`references/reply-after-idle.md` の表で起動し直すかを決めてから `scripts/epic-dispatch.sh notify-closed`（起動し直すなら `--relaunch`）を呼ぶと書かなければならない（MUST）。出力の扱いとして、`notified` と `skipped` は何もしない、`unrecorded` は stderr に出た投稿し直しのコマンドでエピックに 1 行を残す、`failed` は主に報告する（主に出す発言の 1 行目は既存の `主がすること:` の規定に従う）と書く（MUST）。`state_reason` が `completed` でない子には `notify-closed` を呼ばない（SHALL。作業されていない件に完了を促さない）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、偽の `orca` と `gh` で、上の振る舞い（止まった印のまま completed で閉じた子には返事が送られ、エピックに `親の判断: 子 #<child> 通した` で始まる 1 行が残ること、止まっていない子・既に完了の印の子・completed でない子・閉じていない子には何も送らずどこにも投稿しないこと、送れたがエピックへの投稿に失敗すると `unrecorded` を出すこと、送信の失敗で `failed` を出しエピックに投稿しないこと、引数の誤りで `orca` を呼ばないこと）と、手順 4 の文面が `notify-closed` を呼ぶことを確かめなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、`gh` の出力（子 issue の状態・閉じた理由・コメント）と `orca` の出力（ワークツリーの一覧・端末）である。拾いたい誤りは、止まった印のまま completed で閉じた子に何も届かずワークツリーが残り続けること、止まっていない子や作業されていない件に完了を促すこと、送れなかった返事をエピックに通したと残すことの 3 つである。次は通ってよく、この要件では止めない: 親が同じ `closed` を 2 回処理して同じ促しが 2 回届くこと（子は完了報告を 1 回書いて印を付けるだけ）／主が PR をマージせずに issue を completed で閉じた子に促しが届くこと（`reap` の既存の確認が片付けを止める）／判定のあとに子が自分で再開していて、促しが進んでいる子に届くこと。

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

#### Scenario: 手順 4 は completed の子に notify-closed を呼ぶ
- **WHEN** develop の `SKILL.md`「回し方」の Orca 経路の手順 4 を読む
- **THEN** `state_reason` が `completed` の子ごとに `scripts/epic-dispatch.sh notify-closed` を呼ぶことと、`unrecorded`・`failed` の扱いが書かれている
