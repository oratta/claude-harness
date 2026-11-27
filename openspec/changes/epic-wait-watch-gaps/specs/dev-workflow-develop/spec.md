## MODIFIED Requirements

### Requirement: Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る
`plugins/dev-workflow/scripts/epic-dispatch.sh` は `notify-closed [--relaunch] <epic> <child>` を受け付けなければならない（MUST）。`<epic>` か `<child>` が数字でない・引数の数が違う・`--relaunch` 以外のフラグがある・返事の送り方の環境変数が誤っているときは、使い方を出して exit 1 で終わり、`orca` を呼んではならない（MUST）。

`notify-closed` は次の順に確かめ、条件を満たした子にだけ返事を送らなければならない（MUST）。

1. 子 issue（`gh api repos/{owner}/{repo}/issues/<child>`）の `state` が `closed` でなければ `skipped <child> not-closed`、`state_reason` が `completed` でなければ `skipped <child> not-completed` を出す。`gh` が失敗したら `failed <child> issue` を出す
2. 今のワークツリーと同じ repoId・linkedIssue が `<child>`・archive されていない子のワークツリーが 0 件なら `skipped <child> no-worktree`、2 件以上なら `failed <child> ambiguous-worktree`、一覧を読めなければ `failed <child> list` を出す
3. 記録の `status` が `done` なら `skipped <child> already-done` を出す。記録の `stop` の値（空・`stopped`・`stopped-seen`・`resumed`）と、`status` が `running` か `waiting` かでは、送るかを分けてはならない（MUST NOT。止まった印を付けずに主にマージを頼んで見張りを終えた子も、記録先が閉じたら完了報告と mark done を促されるようにするため）
4. 条件を満たしたら、要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の `--as parent` と同じ処理で、`記録先の issue #<child> は completed で閉じた。完了報告を書き、mark done で終える（停止の記録: <URL>）` を子に送る。`<URL>` は子 issue の 1 行目が `子の停止: 主の返事待ち` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` の最新のものの URL で、見つからなければ子 issue の URL とする。`reply` が送る直前に行う止まりの確かめ（記録の `stop` が `stopped` / `stopped-seen` か、受領した組 `stop_turn` が今も有効か、会話ログが止まりの発言より進んでいないか）で止まっていないと決まった子（今までなら `skipped <child> not-stopped` になった子）にも、送るのを止めてはならない（MUST NOT。止まった印を付けずに見張りを終えた子も促すため）。その子には `--relaunch` を当てず、端末が 1 つ以上あれば子のセッションの端末に送るだけにしなければならず（MUST）、端末を閉じたり起動し直したりしてはならない（MUST NOT。ターンの途中の子や主が子のタブで会話中の子の作業と会話を失わせないため）。端末が 0 個なら今までどおり起動し直す。止まっていると決まった子には `--relaunch` の有無のとおりに送る。送信の結果が `failed <child> <段>` なら、それを出して exit 1 で終わる
5. 送れたら（`sent` か `relaunched`）、エピックに `親の判断: 子 #<child> 通した — 記録先が completed で閉じたので、完了報告と mark done を促した <URL>` の 1 行をコメントする（記録に `stop_uuid` があれば `<URL>` の前に `発言 <uuid> ` を足す。空なら足さない）。投稿できたら `notified <child>` を出し、投稿に失敗したら `unrecorded <child>` を出して stderr に投稿し直すコマンド（`gh issue comment <epic> --body <その 1 行>`）を出す。エピックへの記録は送信のあとに投稿しなければならない（MUST。送る前に投稿すると、送れなかったときに送っていない判断が残るため）

`skipped`・`notified`・`unrecorded` はどれも exit 0 で、stdout はちょうど 1 行とする（MUST）。`skipped` のときは子に何も送らず、エピックにも子 issue にも投稿してはならない（MUST NOT）。

この要件は、要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の「`notify-closed` はすでに同じ確認をしており、出力は変わらない」の文と、要件「epic-loop.md は出力語を受けた動作指示を残す」の残すもののうち手順 4 の `skipped <N> not-stopped` の扱いに優先する（`notify-closed` は `skipped <N> not-stopped` を返さなくなる）。要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」の、主が子のタブで打った入力から始まったターンには返事を送らない文は止まりの解決の規定で、`notify-closed` の完了の促しには当てない（端末を閉じず、起動し直さない部分は上の手順 4 のとおり `notify-closed` にも当てる）。

develop の `references/epic-loop.md` の「通常進行の手順」の Orca 経路の手順 4 は、`closed <N>...` で起こされて `state_reason` が `completed` の子ごとに、`references/reply-after-idle.md` の表で起動し直すかを決めてから `scripts/epic-dispatch.sh notify-closed`（起動し直すなら `--relaunch`）を呼ぶと書かなければならない（MUST）。`notify-closed` は、依存が解けた子の `launch` より先に呼ぶと書く（MUST。`launch` が `failed` を返すと親は手順 6 で止まり、再開の手順 7 は `notify-closed` を呼ばないので、後ろに置くと閉じた子に送られないまま残る）。出力の扱いとして、`notified` と `skipped` は何もしない（止まった印の無い子も `notify-closed` が促すので、`skipped <N> not-stopped` の子を別に扱う文は書かない）、`unrecorded` は stderr に出た投稿し直しのコマンドでエピックに 1 行を残す、`failed` は主に報告する（主に出す発言の 1 行目と最後の行は、要件「エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う」に従う）と書く（MUST）。`state_reason` が `completed` でない子には `notify-closed` を呼ばない（SHALL。作業されていない件に完了を促さない）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、偽の `orca` と `gh` で、上の振る舞い（completed で閉じた子には、記録の `stop` が `stopped-seen`・空・`resumed` のどれでも、`status` が `running`・`waiting` のどちらでも返事が送られ、エピックに `親の判断: 子 #<child> 通した` で始まる 1 行が残ること、受領した組や会話ログの進みでは送るのを止めないこと、止まっていないと決まった子には `--relaunch` を付けても `orca terminal close` と `orca terminal create` を呼ばずに今の端末に送ること、止まっている子には `--relaunch` で起動し直すこと、既に完了の印の子・completed でない子・閉じていない子には何も送らずどこにも投稿しないこと、送れたがエピックへの投稿に失敗すると `unrecorded` を出すこと、送信の失敗で `failed` を出しエピックに投稿しないこと、引数の誤りで `orca` を呼ばないこと）と、手順 4 の文面が `notify-closed` を呼ぶこと、手順 4 の中で `notify-closed` が `launch` より先に現れることを確かめなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、`gh` の出力（子 issue の状態・閉じた理由・コメント）と `orca` の出力（ワークツリーの一覧・端末）である。拾いたい誤りは、完了の印の無いまま completed で閉じた子（止まった印の有無によらない）に何も届かずワークツリーが残り続けること、作業されていない件に完了を促すこと、送れなかった返事をエピックに通したと残すことの 3 つである。次は通ってよく、この要件では止めない: 親が同じ `closed` を 2 回処理して同じ促しが 2 回届くこと（子は完了報告を 1 回書いて印を付けるだけ）／主が PR をマージせずに issue を completed で閉じた子に促しが届くこと（`reap` の既存の確認が片付けを止める）／判定のあとに子が自分で再開していて、促しが進んでいる子に届くこと／記録先が閉じたあとも子のターンが動いていて（`stop` が空のまま作業中）、または主が子のタブで会話していて、促しがその子のセッションに届くこと（端末を閉じず起動し直さないので作業と会話は残り、子は完了報告を書いて終えるか、作業の続きを報告する）／作業中の子のセッションに送った促しのターンの開始を確かめられず `failed <child> send` になり、親が主に報告すること。この 3 つの誤りを起こす入力の組み合わせが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 止まった印のまま completed で閉じた子には返事を送り、エピックに 1 行を残す
- **WHEN** 子 11 の issue が `closed`・`completed` で、子 11 の記録の `stop` が `stopped-seen`、`status` が `waiting` で、`notify-closed 400 11` を実行する
- **THEN** 子 11 の端末に `親エピック #400 の判断（主の承認ではない）: 記録先の issue #11 は completed で閉じた。完了報告を書き、mark done で終える` で始まる文が送られ、エピック 400 に `親の判断: 子 #11 通した` で始まるコメントが投稿され、stdout は `notified 11` で exit 0 で終わる

#### Scenario: 止まっていない子が閉じたときは返事を送らない
- **WHEN** 子 11 の issue が `closed`・`completed` で、子 11 の記録の `stop` が空、`status` が `done`（子が完了の印を付けて終えた）で、`notify-closed 400 11` を実行する
- **THEN** stdout は `skipped 11 already-done` で exit 0 で終わり、`orca terminal send` も `orca terminal create` も呼ばれず、`gh issue comment` も呼ばれない（`stop` が空の子に送らないのは `status` が `done` のときだけで、`done` でなければ次の Scenario のとおり送る。`stop` が `stopped-seen` で `done` の子は Scenario「既に完了の印を付けた子には返事を送らない」）

#### Scenario: 止まった印の無い子が閉じたときも返事を送る
- **WHEN** 子 11 の issue が `closed`・`completed` で、子 11 の記録の `stop` が空か `resumed`、`status` が `running` か `waiting` で、`notify-closed 400 11` を実行する
- **THEN** 子 11 の端末に `親エピック #400 の判断（主の承認ではない）: 記録先の issue #11 は completed で閉じた。完了報告を書き、mark done で終える` で始まる文が送られ、エピック 400 に `親の判断: 子 #11 通した` で始まるコメントが投稿され、stdout は `notified 11` で exit 0 で終わる

#### Scenario: 受領した組や会話ログの進みでは促しを止めない
- **WHEN** 子 11 の issue が `closed`・`completed` で、記録の `stop` が `stopped-seen`、`stop_turn` が今の `turn_input` と合わず、会話ログに止まりの発言より新しい入力がある状態で `notify-closed 400 11` を実行する
- **THEN** 子 11 の端末に促しが送られ、stdout は `notified 11` で exit 0 で終わる

#### Scenario: 止まっていない子には --relaunch を当てず今の端末に送る
- **WHEN** 子 11 の issue が `closed`・`completed` で、子 11 のワークツリーに子のセッションの端末が 1 つあり、記録の `stop` が空・`resumed` のどれか、または `stopped-seen` で `stop_turn` が今の `turn_input` と合わないか会話ログが止まりの発言より進んでいる状態で、`notify-closed --relaunch 400 11` を実行する
- **THEN** 子のセッションの端末に促しが送られ、`orca terminal close` と `orca terminal create` は呼ばれず、stdout は `notified 11` で exit 0 で終わる

#### Scenario: 止まっている子には --relaunch で起動し直す
- **WHEN** 子 11 の issue が `closed`・`completed` で、記録の `stop` が `stopped-seen`、`stop_turn` が今の `turn_input` と合い、会話ログが止まりの発言より進んでいない状態で、`notify-closed --relaunch 400 11` を実行する
- **THEN** 子 11 のワークツリーの端末が閉じられて作り直され、`/develop #11 （エピック #400 の子。返事を受けて起動し直し）` で始まる文が送られ、stdout は `notified 11` で exit 0 で終わる

#### Scenario: completed でない理由で閉じた子には返事を送らない
- **WHEN** 子 11 の issue が `closed`・`not_planned` で、子 11 の記録の `stop` が `stopped` で、`notify-closed 400 11` を実行する
- **THEN** stdout は `skipped 11 not-completed` で exit 0 で終わり、子の端末には何も送られず、`gh issue comment` は呼ばれない

#### Scenario: 既に完了の印を付けた子には返事を送らない
- **WHEN** 子 11 の issue が `closed`・`completed` で、記録の `status` が `done`、`stop` が `stopped-seen` で、`notify-closed 400 11` を実行する
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
2. 記録の `stop` が `stopped` でない（`stopped-seen` は推定の対象に含める。親が受けた止まりのまま記録先が completed で閉じ、`notify-closed` の促しが届かなかった子も片付けるため。`stopped` は親がまだ受けていない止まりで、`--watch-stopped` の `stopped` として先に親に渡す）
3. 記録の `worktree` が空でなく、子のトランスクリプト（`${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}/<worktree の英数字以外を - にした名前>/*.jsonl`。置き場のディレクトリは `wait --resolve` の起動し直しの判定と同じ求め方で、置き場を求める処理は 1 つの関数を共有する（既定の置き場の変更は起動し直しの判定にも掛かる）。起動し直しの判定が使う本体のログの選び方はその判定の側に残し、ここでは置き場の全部の `.jsonl` を読む）が 1 本以上ある
4. 置き場の全部の `.jsonl` と、そのセッションのサブエージェントのトランスクリプト（`<置き場>/<セッション>/subagents/*.jsonl`）を通して、`timestamp` を持つ行（種類を問わない）の最大値を最後の活動とし、今の時刻との差が `EPIC_DISPATCH_DONE_IDLE_SEC`（秒・既定 1800）以上である。`timestamp` を持つ行が 1 つも無い・読めない・`python3` が無いときは満たさない
5. 子 issue を、位置引数の子と同じ `gh` の呼び出しの形（記録の `repo` で決まる `issue_api`）で 1 回読み、`state` が `closed` で `state_reason` が `completed` である
6. 5 と同じ 1 回の `gh` で読んだ `closed_at` と今の時刻との差が `EPIC_DISPATCH_DONE_IDLE_SEC` 以上である。`closed_at` が無いときは満たさない（記録先が閉じた直後に、閉じる前から長く動いている背景のコマンドだけを走らせている子を完了としないため）

1〜4 のどれかを満たさない子について `gh` を呼んではならない（MUST NOT）。5・6 の `gh`（1 回）が失敗したときは、そのポーリングではその子を推定せず、失敗したポーリングにも数えない（MUST）。すべて満たした子は、要件「wait --watch-done は推定した完了を記録に書き、Orca の印へ写す」（dev-workflow-epic-state）のとおり記録に書き、書けたら stderr に `inferred done <N>: issue closed as completed, no transcript activity since <最後の活動>` を出し、印が付いた子として `done <N>...` の行に入れなければならない（MUST）。stdout の行の形・順・exit code は今の `--watch-done` の規定のまま変えてはならない（MUST NOT。推定の `done` を別の行にしない）。

`--watch-done` が 1 つ以上ある `wait` は、ポーリングを始める前に `EPIC_DISPATCH_DONE_IDLE_SEC` を確かめ、空か数字でなければ stderr に理由と使い方を出して exit 1 で終わり、`gh` を呼んではならない（MUST）。

この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」と要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」の「ポーリング 1 回あたりの `gh` の呼び出しは位置引数の子の数と同じ」の規定に優先し、推定の候補（1〜4 を満たした `--watch-done` の子）1 件ごとに `gh` の呼び出しが 1 回増えることを許す。

`plugins/dev-workflow/scripts/epic-dispatch.sh` の冒頭のコメントの `wait` の説明に、推定の 6 つの条件・`EPIC_DISPATCH_DONE_IDLE_SEC` とその既定・推定の `done` が同じ `done <N>` の行に出ることを書かなければならない（MUST）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、偽の `gh` とテスト用の `CLAUDE_PROJECTS_DIR` で、次を確かめなければならない（MUST）: 6 つを満たすと stdout が `done <N>` で記録の `status` が `done` になり推定の項目が付くこと／最後の活動が閾値より新しい・トランスクリプトが 0 本・2 本のうち片方だけ新しい・`status` が `waiting`・`stop` が `stopped` のときは `gh` を呼ばずに推定しないこと／`stop` が `stopped-seen` でほかの条件を満たせば推定し、記録の `stop` は `stopped-seen` のまま残ること／2 本とも古ければ推定すること／issue が `open`・`state_reason` が `completed` でない・閉じてから閾値より短い・`closed_at` が無いときは推定しないこと／サブエージェントのトランスクリプトにだけ閾値より新しい行があるときは推定しないこと／排他の中の確かめ直しで外れたとき（推定の `gh` の間に子が `waiting` を付けた）は推定せず Orca の印へ写さないこと／`EPIC_DISPATCH_DONE_IDLE_SEC` で閾値を変えられ、数字でない値は exit 1 で `gh` を呼ばないこと／同じ子を位置引数と `--watch-done` の両方に渡したとき、閉じたポーリングで `closed <N>` と `done <N>` の 2 行がこの順に出ること。

この要件の守備範囲で入力として扱うのは、記録の `status`・`stop`・`worktree`、子のトランスクリプト（サブエージェントのものを含む）の `timestamp`、子 issue の `state` と `state_reason` と `closed_at` である。拾いたい誤りは、主がマージして記録先が閉じたのに子が印を付けず親が待ち続けることと、まだ動いている子・主の確認待ちの印（`waiting`）を付けた子・親がまだ受けていない止まり（`stopped`）の子を完了とすることである。次は通ってよく、この要件では止めない: 主が閾値より長く子のタブを離れてから同じタブで追加の作業を頼もうとしたときにワークツリーが片付いていること（`reap` の確認が未コミットの変更とマージに入っていない commit を残す）／時計のずれで最後の活動が未来になり推定されないこと／記録先が閉じたあと、子が 1 回のツール呼び出しを閾値より長く動かしている（その間トランスクリプトに行が増えない）ときに推定されること（`reap` の確認は変えないので、失うのは後片付けの途中だけ）／マージ後の依頼（動作確認など）を完了報告に書いてマージを主に頼んだ子も、PR が未マージのうちは `waiting` を付けられないので推定され、主の返事の前にタブが閉じること（依頼は完了報告と記録先に残る）。親が受けた止まり（`stopped-seen`）のまま主の返事を待っている子が、記録先が completed で閉じて閾値を過ぎたあとに推定されること（閉じた記録先の件に主の返事は要らず、`reap` の確認は変えない）も通してよい。推定した完了の子は記録の `stop` が `stopped-seen` のまま残るが、片付けの前に親が起動し直されても、再開の手順 7 は開いている子だけを `pending-owner` に渡すので、その子が主に出し直されることは今は起きない（手順 7 が閉じた子も渡すように変わったら、この要件の守備範囲を見直す）。この要件は、ここに挙げていない穴が見つかるたびに塞ぎ切ることを完了条件にしない。

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
- **WHEN** 子 11 の記録の `status` が `waiting`、または `stop` が `stopped`（止まった印。受けた印の `stopped-seen` は次の Scenario）で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録は変わらず、`gh` は呼ばれない

#### Scenario: 親が受けた止まりのまま閉じた子は推定する
- **WHEN** 子 11 の記録の `stop` が `stopped-seen` で、ほかは推定される条件のまま `wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** stdout は `done 11`、exit 0 で、記録の `status` は `done`、`stop` は `stopped-seen` のまま

#### Scenario: 開いている子・completed 以外で閉じた子は推定しない
- **WHEN** 子 11 の issue が `open`、または `closed` で `state_reason` が `not_planned` で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま

#### Scenario: 閾値を変えられ、誤った値は使い方を出す
- **WHEN** 最後の活動が 10 分前の子 11 で `EPIC_DISPATCH_DONE_IDLE_SEC=300` を付けて `wait --interval 0 --timeout 60 --watch-done 11` を実行し、別に `EPIC_DISPATCH_DONE_IDLE_SEC=abc` を付けて同じコマンドを実行する
- **THEN** 前者は stdout が `done 11` で、後者は exit 1 で stdout は空、stderr に使い方が出て `gh` は呼ばれない

### Requirement: 回し方の手順は推定した done も子の付けた done と同じに片付ける

develop の `references/epic-loop.md` の「通常進行の手順」の別セッション方式の手順は、次を書かなければならない（MUST）。

- 手順 2 の `--watch-done` の説明に、`wait` は片付け待ちの子のうち、完了の印の無いまま記録先が `completed` で閉じてから `EPIC_DISPATCH_DONE_IDLE_SEC`（既定 1800 秒）以上たち、子のトランスクリプト（サブエージェントのものを含む）の最後の活動もそれ以上前の子を、LLM なしで完了と推定して `done <N>` を返すこと（`status` が `waiting` の子・親がまだ受けていない止まり（`stop` が `stopped`）の子・トランスクリプトが無い子は推定しない。親が受けた止まり（`stopped-seen`）の子は推定の対象に入る）
- 手順 3 に、推定の `done` も子が付けた `done` と同じに `reap` を 1 回呼んで扱い、区別しないこと（片付けの安全確認は `reap` が行う）。同じ子が `closed` と `done` の両方の行に出たら、手順 4 を処理してから手順 3 の `reap` を呼ぶこと
- 手順 4 に、`notify-closed` は止まった印の有無によらず完了の印の無い子に促しを送ること。促しが届かなかった子（`failed` を返した子など）も、片付け待ちとして `--watch-done` に渡しておけば、子のセッションが止まって閾値を過ぎたあとの `wait` が完了と推定すること。主に子のステータスを変えるよう頼まない（MUST NOT）

`plugins/dev-workflow/tests/epic-dispatch.bats`（または `tests/develop-skill.bats`）は、手順 2〜4 の文面に `EPIC_DISPATCH_DONE_IDLE_SEC` と推定の扱いがあることを確かめなければならない（MUST）。

この要件の入力は、`wait` が返す `done <N>` と `closed <N>` の行、`notify-closed` が返す行である。拾いたい誤りは、推定の `done` を子の付けた `done` と区別して片付けを飛ばすこと、促しが届かなかった子について主にステータスを変えるよう頼むことである。次は通してよく、この要件では止めない: 推定の `done` を渡した `reap` が `kept` を返し、本体が確かめて残すこと（安全確認は `reap` が行う）／`status` が `waiting` の子やトランスクリプトの無い子が推定されないこと。推定の条件の細部の食い違いを見つけるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 回し方に推定の扱いが書かれている
- **WHEN** `references/epic-loop.md` の「通常進行の手順」の手順 2〜4 を読む
- **THEN** 手順 2 に `wait` が完了を推定する条件と `EPIC_DISPATCH_DONE_IDLE_SEC` が、手順 3 に推定の `done` も同じに `reap` することと、同じ子が `closed` と `done` の両方に出たら手順 4 を処理してから `reap` を呼ぶことが、手順 4 に `notify-closed` が止まった印の有無によらず促すことと、促しの届かなかった子は `--watch-done` の推定で片付くことが書かれている

### Requirement: 完了を伝えるだけの子を起こす必要は既存の片付け条件で分ける
`references/epic-loop.md` は、PR がマージ済みで実作業が残っていない子でも、親だけの片付けが全件には足りないと理由付きで記さなければならない（MUST）。既に done なら reap、既存の完了推定条件を満たす子なら wait --watch-done → done → reap を使い、「終えて」だけの reply を省く（MUST）。waiting の子と親がまだ受けていない止まり（`stopped`）の子は完了推定の対象外で、親が受けた止まり（`stopped-seen`）の子は対象に入る。completed で閉じた完了の印の無い子（止まった印の有無・waiting によらない）には notify-closed で完了報告と mark done を促す（MUST）。親の mark done の代行や状態記録の直接編集を手順にしてはならない（MUST NOT）。

守備範囲: 入力は親の子状態記録、子のログ、GitHub の閉鎖状態、wait・reap・notify-closed の出力。防ぐ誤りは、片付け可能な子への不要な返事と、推定対象外の子の完了促進の省略・done の強制。done でも既存の安全確認で reap が `kept <N> dirty` を返して子を残すことは許容する。分類の穴を塞ぎ切ることは完了条件にしない。

#### Scenario: done または完了推定可能な子には終了だけの返事を送らない
- **WHEN** マージ済みで残作業のない子が done、または running・stop が stopped でない・ログありで completed の閉鎖と最後の活動から各 EPIC_DISPATCH_DONE_IDLE_SEC 以上経過した場合の手順を読む
- **THEN** reply で子を起こさず、前者は reap、後者は wait --watch-done の done を受けて reap すると分かる

#### Scenario: 停止中の子には既存の完了促進を残す
- **WHEN** PR がマージ済みでも status が waiting、または stop が stopped / stopped-seen の子の場合の手順を読む
- **THEN** waiting と stopped の子は完了推定では done にできず reap は not-done で残す理由が分かり、stopped-seen の子は完了推定の対象に入ること、completed で閉じたこれらの子には notify-closed で完了報告と mark done を促すと分かる

## ADDED Requirements

### Requirement: stop-judge.sh は判断の値に「親が動く」を受け付ける

`plugins/dev-workflow/scripts/stop-judge.sh` は、モデルの出力の 1 行目に、`判断: 通す`・`判断: 主に上げる`・`判断: 問いではない` に加えて `判断: 親が動く` を受け付けなければならない（MUST）。2 行目 `理由:`（空でない）と 3 行目 `返事:`（空でよい）の検査と、4 行目 `記録:` の付け方はほかの値と同じにする（MUST）。`判断: 親が動く` は、止まりの JSON・停止の記録・止まった印の有無によらず出せる（MUST）。この要件は、要件「epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける」と要件「親が通してよい範囲の基準を 1 つのファイルに置く」の、1 行目の値を 3 つに限る規定に優先する。`plugins/dev-workflow/tests/stop-judge.bats` がこれを確かめる（MUST）。

#### Scenario: stop-judge は親が動くの出力を受け付ける
- **WHEN** 子 11 に停止の記録（子 issue の `子の停止: 主の返事待ち` のコメント）があり、モデルのスタブが `判断: 親が動く`・`理由: 親が #12 を起動する`・`返事: ` を出し、`stop-judge.sh 400 11` を止まりの JSON なしで実行する
- **THEN** stdout は 4 行で 1 行目が `判断: 親が動く`、exit 0 である

### Requirement: 通す基準は親の操作を含む推奨に「親が動く」を出すと定める

`plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md` は、通してよい止まりのうち推奨が**親の操作**を含むものに `判断: 親が動く` を出すと書かなければならない（MUST）。親の操作は、推奨のうちこの子に返事を送ること（`wait` が決める起動し直しを含む）以外で親がすること（別の子の起動、依存の張り替え、別の issue・PR への投稿や操作、ワークツリーの片付け、エピックの本文の更新など）と書く（MUST）。主に聞く理由の 3 つに当たる止まりは、親の操作を含んでも `判断: 主に上げる` とする（MUST）。推奨が子の側の行動だけの止まりは今までどおり `判断: 通す` とする（MUST）。`理由:` に親がする操作を、`返事:` に操作のあとに子に送る返事を書く（SHALL）。

#### Scenario: 基準のファイルに親の操作の扱いがある
- **WHEN** `references/parent-pass-criteria.md` を読む
- **THEN** 親の操作の定義と、推奨が親の操作を含む通してよい止まりに `判断: 親が動く` を出すこと、主に聞く理由に当たるときは `判断: 主に上げる` が先なこと、出力の形の 1 行目の値に `判断: 親が動く` があることが書かれている

### Requirement: wait --resolve は親の操作が要る止まりを通さず stopped で返す

`plugins/dev-workflow/scripts/epic-dispatch.sh` の `wait --resolve` は、判断の 1 行目が `判断: 親が動く` の止まりについて、子に何も送らず、エピックに `親の判断: 子 #<N> 通した` の行を残してはならない（MUST NOT）。代わりに子 issue に、1 行目 `親の判断: 親の操作が要る`、2 行目 `止まりの発言: <uuid か 不明>`、3 行目 `停止の記録: <4 行目の 記録: のうしろ>`、4 行目に理由、5 行目 `送るはずだった返事: <返事。空なら なし>` のコメントを投稿し、`stopped <N>` で返さなければならない（MUST。記録の `stop` は `stopped-seen` のまま）。投稿に失敗したら `判断: 主に上げる` と同じく stderr に投稿し直しのコマンドを出す（MUST）。判断の前後の受領した組の確かめはほかの値と同じに掛ける（MUST）。

#### Scenario: 親の操作を含む止まりは通さず stopped で返る
- **WHEN** 子 11 の止まりで、判断のスタブが `判断: 親が動く`・`理由: 親が #12 を起動する`・`返事: #12 を起動した。マージを待って再開する` を出し、`wait --interval 0 --timeout 60 --resolve 400 --watch-stopped 11` を実行する
- **THEN** stdout は `stopped 11`、exit 0 で、子の端末には何も送られず、エピック 400 に `親の判断: 子 #11 通した` は投稿されず、子 issue 11 に 1 行目 `親の判断: 親の操作が要る` と `送るはずだった返事: #12 を起動した。マージを待って再開する` の行を含むコメントが投稿される

#### Scenario: 子の側の行動だけの止まりは今までどおり通る
- **WHEN** 判断のスタブが `判断: 通す`・`返事: 見張りを続ける` を出し、同じコマンドを実行する
- **THEN** 子の端末に返事が送られ、エピック 400 に `親の判断: 子 #11 通した` で始まる行が投稿され、`stopped 11` は出ない

#### Scenario: 親の操作が要るの投稿に失敗したら投稿し直しのコマンドを出す
- **WHEN** 判断のスタブが `判断: 親が動く` を出し、子 issue へのコメントの投稿が失敗する
- **THEN** stdout は `stopped 11` で、stderr に `親の判断: 親の操作が要る` を含む投稿し直しのコマンドが出る

### Requirement: 親は親の操作が要る止まりで操作をしてから返事を送る

develop の `references/epic-stop.md` の手順 8 は、子 issue の最新の `親の判断:` のコメントの 1 行目が `親の判断: 親の操作が要る` の止まりについて、親がそのコメントの理由の操作を親の権限で行い（主に聞く理由の 3 つに当たると分かったら主に上げる）、そのあとで送るはずだった返事（`なし` なら操作の結果を伝える 1 行）を `scripts/epic-dispatch.sh reply --as parent` で送り、送れたらエピックに `親の判断: 子 #N 通した — <理由> 発言 <止まりの uuid か 不明>`（停止の記録があれば末尾に URL）の 1 行を残すと書かなければならない（MUST）。操作をせずに返事だけを送ると書いてはならない（MUST NOT）。

#### Scenario: 親の手順は操作をしてから返事を送る
- **WHEN** `references/epic-stop.md` の手順 8 を読む
- **THEN** `親の判断: 親の操作が要る` の止まりは、親が理由の操作を行ってから `reply --as parent` で送るはずだった返事を送り、エピックに通した行を残すことが書かれている

### Requirement: 親は親の操作が要る止まりを dismiss と照らし直しより先に扱う

develop の `references/epic-stop.md` の手順 8 の中では、`親の判断: 親の操作が要る` の件は、今回の止まった理由が `PR トークン上限（`・`PR のマージ待ち（` で始まるものを除いて、`dismiss` の判定（今回の停止の記録が無く主への問いでもない止まり）・主の委任・`parent-pass-criteria.md` への照らし直しより先に扱い、照らし直さないと書く（MUST。判断のモデルが既に通してよい止まりと読み、親の操作だけが残っているため。`dismiss` で戻すと操作が行われない）。`PR トークン上限（`・`PR のマージ待ち（` で始まる止まりは、`親の操作が要る` でもそれぞれの手順を先に当てる（親の権限と主の承認を確かめる手順で、操作の前に要るため）。`epic-stop.md` の「pending-owner の復元」も、最新の `親の判断:` が `親の判断: 親の操作が要る` の子は手順 8 と同じく操作をしてから返事を送り、出し直さないと書く（MUST）。

#### Scenario: 親の操作が要る止まりは dismiss と照らし直しより先に書かれている
- **WHEN** `references/epic-stop.md` の手順 8 と「pending-owner の復元」を読む
- **THEN** `親の判断: 親の操作が要る` の件は `dismiss` の判定・主の委任・基準への照らし直しより前に書かれ、照らし直さないことと、`PR トークン上限（`・`PR のマージ待ち（` の止まりはそれぞれの手順が先なことが書かれている
- **AND** 「pending-owner の復元」に、`親の判断: 親の操作が要る` の子は手順 8 と同じく操作をしてから返事を送ることが書かれている

### Requirement: 親の操作が要る止まりの守備範囲を限る

上の 5 つの要件は、入力として、判断のモデルの出力の 1〜3 行目と子 issue の `親の判断:` のコメントだけを扱わなければならない（MUST）。拾いたい誤りは、推奨が親の操作を含む止まりを通して子に「親がする」と送ったまま親が起こされず操作が行われないこと、子の側の行動だけの止まりで親を起こすことの 2 つである。次は通ってよく、止めない: 判断のモデルが親の操作を含む推奨を `判断: 通す` と読み誤ること（繰り返せば基準の「繰り返していない」で親に上がる）／子の側の行動だけの推奨を `判断: 親が動く` と読み誤り親が起こされること（親が操作の無いことを確かめて返事を送る）。判断のモデルの読み誤りは、上の 2 つに限らずどの形でも塞ぎ切ることを完了条件にしない（返事の文面から親の操作を機械で見つけることも含む。読み誤りを減らす手段は基準のファイルの書き方である）。

#### Scenario: 返事の文面だけでは止めない
- **WHEN** 判断のスタブが `判断: 通す`・`返事: 親が見張りを続けるので、そのまま待つ` を出し、`wait --interval 0 --timeout 60 --resolve 400 --watch-stopped 11` を実行する
- **THEN** 子の端末に返事が送られ、エピック 400 に `親の判断: 子 #11 通した` で始まる行が投稿される（返事に「親が」を含むことだけでは `stopped` にしない）
