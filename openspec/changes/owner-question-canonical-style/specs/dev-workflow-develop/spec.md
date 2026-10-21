## RENAMED Requirements

- FROM: `### Requirement: エピックの親が主に出す報告は、主がすることを 1 行目に書く`
- TO: `### Requirement: エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う`

- FROM: `### Requirement: channel モードの主への発言はすべてチャンネルに送り、チャンネルでする操作を 1 行目に書く`
- TO: `### Requirement: channel モードの主への発言はすべてチャンネルに送り、チャンネルでする操作を答え方の行に書く`

## MODIFIED Requirements

### Requirement: Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる
develop の SKILL.md「エピックの扱い」→「回し方」の Orca 経路の手順は、次を規定しなければならない（MUST）。この要件は、要件「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」の親の側のうち、`stopped` で起こされたら記録を読んでユーザーに報告する規定と、止まった子への返事の仕方を #1034 で決めるとする規定に優先する。

- 動いている子を待つ `wait` には、`--watch-stopped` に加えて `--resolve <エピック番号>` を付ける（MUST）。通すと判断された止まりは `wait` の中で返事が送られ、親は起こされない
- `wait` の出力が `closed`・`done`・`stopped`・`unrecorded` の 1〜4 行であることを書く（MUST）。この 1〜4 行は `--resolve` を付けたときだけで、要件「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」の `closed`・`done`・`stopped` の 1〜3 行とする規定に優先する。`--resolve` を付けない `wait` の出力は従来どおり 1〜3 行であることも書く（MUST）
- `unrecorded <N>...` で起こされたら、子には返事が届いているので主に上げず、`wait` が stderr に出した投稿し直しのコマンドでエピックに `親の判断: 子 #N 通した` の 1 行を残す（MUST）。stderr を読めなければ、`親の判断: 子 #N 通した — 理由は記録できなかった <最新の子の停止の記録の URL>` を投稿する（MUST）
- `stopped <N>...` で起こされたら、止まった子ごとに子 issue の最新の `子の停止: 主の返事待ち` のコメントと、2 行目の `停止の記録:` がその URL と一致する最新の `親の判断:` のコメントを読む（MUST）。一致する `親の判断:` が無ければ、判断が無いものとして主に上げる（MUST。前回の止まりへの判断を今回の判断と取り違えないため）
  - `親の判断: 通すが送れなかった` の件（以前の形の `親の判断: 判断できなかった` で、送るはずだった返事があり、送信だけが失敗した件も同じ）は、主に上げずに `epic-dispatch.sh reply --as parent` で送り直してよい（MAY）。送れたらエピックに `親の判断: 子 #N 通した` の 1 行を残す（MUST）
  - それ以外は主に上げる（MUST）。主に上げる説明は本文で書き、質問ツールで聞かない（MUST。子の `--relayed` は親の発言の本文に停止の記録の URL があることで結び付けを見る）。説明は `~/.claude/output-styles/readable.md` の節 3（主に問いを返す文章の書き方の正本）の型で書く（MUST。手順 8 に順を写さない）。説明には、エピックの目的と他の子との関係を含め、子の停止の記録の URL を添える。実機操作は、どの子の・どの画面で・何をするかを書く
- 主の答えを受けたら、`references/reply-after-idle.md` の表でそのまま送るか起動し直すかを決め、`epic-dispatch.sh reply --as owner`（起動し直すなら `--relaunch` も）に主の答えを書き換えずに渡して子に届ける（MUST）。主の答えの末尾には、要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」の発言の場所の添え書き（` [主の発言: セッション <親のセッション ID> / uuid <uuid>]`）を付けて渡す（MUST。主の答えそのものは書き換えず、末尾に足すだけ。場所を引けないときの扱いも同じ要件に従う）。`reply` の出力が `failed` なら主に報告する（MUST）
- 止まった子を動いている子から外さず、2 に戻る（MUST。既存の規定のまま）
- 親が通してよい範囲の基準は `references/parent-pass-criteria.md` を指す（MUST）

develop の手順書（`skills/develop` 配下）に `orca` のサブコマンドを書いてはならない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、`wait` の出力と、子 issue の `子の停止:` と `親の判断:` のコメント、主の答え（親のセッションの会話）、`reply` の出力である。拾いたい誤りは、通せなかった止まりを主に上げずに待ち続けること、主に上げる説明が子の会話を前提にして主が読めないこと、主の答えを子に届けないこと、時間がたった子に表を見ずに送ることの 4 つである。次は通ってよく、この要件では止めない: 説明の文の良し悪し（順序と含めるものが書かれていればよい）／主が子のタブで先に答えていて、親の届けた答えが 2 度目になること（子は受け取って続ける）。説明が主に読めない書き方を見つけるたびに手順を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 親の手順に resolve と主に上げる説明の順が書かれている
- **WHEN** SKILL.md の Orca 経路の手順を読む
- **THEN** `wait` に `--watch-stopped` と `--resolve <エピック番号>` を付けること、`--resolve` を付けたときの出力が `unrecorded` を含む 1〜4 行で、付けないときは従来どおり 1〜3 行であること、`unrecorded` で起こされたらエピックに 1 行を残して主に上げないこと、`stopped` で起こされたら `子の停止:` と、`停止の記録:` がその URL と一致する `親の判断:` を読み、一致するものが無ければ主に上げること、主に上げる説明を `~/.claude/output-styles/readable.md` の節 3 の型で書き（旧い 5 段の順を写していない）、エピックの目的と他の子との関係と記録の URL を含めること、実機操作はどの子の・どの画面で・何をするかを書くこと、主に上げる説明を本文で書き質問ツールで聞かないこと、主の答えを `reply-after-idle.md` の表で決めてから、書き換えずに末尾に発言の場所の添え書きを付けて `reply --as owner` で届けること、`parent-pass-criteria.md` を指すことが書かれている

### Requirement: エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う
develop の SKILL.md「エピックの扱い」→「回し方」の Orca 経路は、親が主に出す発言について、次を規定しなければならない（MUST）。対象は、Orca 経路で親がターンを終えるときに主に出す発言すべてで、次を含む。手順 2 で `wait` を背景で起動して待ちに入るときの通知、手順 3・4・8 を処理して手順 2 に戻るたびの発言、手順 4 の見送りの報告、手順 5 の `timeout` の報告、手順 6 の `error`・`failed` の報告、手順 7 と完了条件で待ちを終えるときの報告、**マージ待ちの子** の `reply` の `failed` の報告、手順 8 の止まった子の報告。

- 1 行目と最後の行は、`~/.claude/output-styles/readable.md` の節 3 が定める書き分けに従う（MUST）。判断・確認・操作を求める発言は 1 行目を質問にし、最後の行を答え方にする。主の操作も判断も要らない発言は 1 行目を `主がすること: なし` にする（手順 2 で待ちに入るときは普通こちら）。SKILL.md は書き分けを写さず、正本を参照する（MUST）
- 同じターンで主に問いを出したあとに手順 2 で待ちに入るときは、待ちに入る通知を `主がすること: なし` で始めない（MUST）。通知の 1 行目に問いの質問を、最後の行に答え方を繰り返す（直前の問いを `なし` で上書きしない）
- 規定は Orca 経路の導入部に 1 か所で書き、各手順は参照する（MUST。手順ごとに書式を複写しない）
- 親経由のリスク許容の依頼（手順 8 で、止まった子の停止の記録の URL を添えて主の答えを求めるもの）の答え方の行には、打つ場所が親のタブであることと、報告の直後に別の発言を挟まないことを書く（MUST）
- 手順 8 の中でも返事の場所が親のタブでない発言は、答え方の行にその場所を書く（MUST）。`owner-reply-check.sh --locate` で主の発言を引けなかったときの「リスク許容なら子のタブで打ってほしい」の連絡は、答え方の行に子のタブを出す。`reply` の出力が `failed <N> <段>` のときの報告は、主の操作が要れば問いの形にし、要らなければ 1 行目を `主がすること: なし` にする
- 子の完了報告の 1 行目（`主がこのセッションで次にすること:`）は変えない（MUST。要件「エピックの子の完了報告は、主がこのセッションで次にすることを 1 行目に書く」に従う）
- `主がすること: <どこで> <何を>` の形を使わない（MUST NOT）

この要件の守備範囲で入力として扱うのは、SKILL.md の Orca 経路の文面である。拾いたい誤りは 2 つある。主が親の発言から、答えが要るかどうかと、どこで何を打つかを読み取れないこと。親経由のリスク許容の返事の場所と条件が、発言から読めないこと。次は通ってよく、この要件では止めない: 2 行目以降の説明の文の良し悪し／答え方の中身の正しさ。穴が見つかるたびに決まりを足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: Orca 経路が正本の書き分けを参照する
- **WHEN** SKILL.md の「回し方」の Orca 経路の導入部を読む
- **THEN** 親が主に出す発言の 1 行目と最後の行を `~/.claude/output-styles/readable.md` の節 3 の書き分けに従わせると書かれ、`主がすること: なし` の場合が書かれ、`主がすること: <どの画面・入力欄で>` の形が無い

#### Scenario: 待ちに入る通知が直前の問いを上書きしない
- **WHEN** SKILL.md の Orca 経路の導入部と手順 2 を読む
- **THEN** 同じターンで主に問いを出したときは、待ちに入る通知を `主がすること: なし` で始めず、問いの質問と答え方を繰り返すと書かれている

#### Scenario: 親経由のリスク許容の答え方に場所と条件が入る
- **WHEN** SKILL.md の手順 8 を読む
- **THEN** 親経由のリスク許容の依頼の答え方の行に、親のタブで打つことと、報告の直後に別の発言を挟まないことを書くと書かれ、主の発言を引けなかったときの連絡の答え方の行には子のタブを出すと書かれている

### Requirement: channel モードのリスク許容はチャンネルの返事を確かめられるときだけチャンネルで受ける

channel の本体は、モードを決めた時点でセッションの環境に `OWNER_REPLY_CHANNEL_SENDERS` があるか（空でないか）を確かめ、値を出さずに、develop 開始コメントに `チャンネルの返事の確認: 可` か `チャンネルの返事の確認: 不可（OWNER_REPLY_CHANNEL_SENDERS が無い）` を残さなければならない（MUST）。channel の本体は、G の起動指示に、`実行モード: channel` の行と、開始コメントと同じ値の `チャンネルの返事の確認: 可` / `チャンネルの返事の確認: 不可` の行を書かなければならない（MUST。G の依頼文の書き分けは `dev-workflow-pr-review-gate` の要件「保留処理の依頼文は新しいセッションでの再開を案内する」が正本）。

可のセッションでは、リスク許容のチャンネルの返事を pr-review-gate 手順 5 の「会話で受領」として扱い、`owner-reply-check.sh` で確かめてから保留の解除の G に渡す（MUST。書式と確かめ方は pr-review-gate 手順 5 が正本）。不可のセッションでは、リスク許容の依頼に限り「PR #<N> にコメントで `許容する` と書く」と案内し、PR のフル URL を添える（MUST）。確かめられなかったときの受け直しの案内はチャンネルに送り、「ゲートと同じ PC での `/develop <記録先> 許容する`」の代わりに PR のコメントを案内する（MUST）。リスク許容以外の返事（動作確認の結果・切り出しの確認・方針の選び直し）はチャンネルの返事で進める（MAY）。

この要件の守備範囲は、チャンネルの返事で確かめられないリスク許容を主に頼み、受け直しを重ねることを防ぐことである。拾いたい誤りは、`OWNER_REPLY_CHANNEL_SENDERS` の無い住人にチャンネルで許容を求めること。設定の値が正しいか（主の ID か）は確かめない（`owner-reply-check.sh` が一致しない行を数えないので、合格しない側に倒れる）。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 設定が無い住人

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` の無い channel の本体がリスク許容の保留で止まる
- **THEN** チャンネルに送る依頼の最後の答え方の行は、PR #<N> にコメントで `許容する` と書くことを案内し、PR のフル URL が添えられている

#### Scenario: 設定がある住人

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` のある channel の本体がリスク許容の保留で止まる
- **THEN** チャンネルに送る依頼の最後の答え方の行は、このチャンネルで返すことを案内し、返事を受けたら `owner-reply-check.sh` で確かめてから保留の解除の G に渡す


### Requirement: channel モードの主への発言はすべてチャンネルに送り、チャンネルでする操作を答え方の行に書く

channel の本体は、主へのすべての発言を、要件「channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない」と同じ宛先のチャンネルに送らなければならない（MUST）。質問だけでなく、質問ではない報告（再開で HEAD が動いていた・前任 W の手渡し不可・`epic-dispatch.sh` などのスクリプトの失敗・レビューの周の打ち切り・完了報告・エピックの親の報告）も含む。端末に出すだけで済ませてはならない（MUST NOT。住人の画面は誰も見ていないので、端末に出しただけの報告は誰にも読まれず、主の指示を待ったまま止まる）。

それらの発言の 1 行目と最後の行は、`~/.claude/output-styles/readable.md` の節 3 が定める書き分けに従わなければならない（MUST）。主の操作も判断も要らない発言は 1 行目を `主がすること: なし` にする。判断・確認・操作を求める発言は 1 行目を質問にし、最後の答え方の行に、このチャンネルで何を返すか、または PR #<N> に何を書くかを書く（MUST）。PR に書く形のときは、PR のフル URL を添える（MUST）。答え方の行に、チャンネル以外の画面・タブ・入力欄（`子のタブで`・`入力欄で` など）を書いてはならない（MUST NOT）。

この要件の守備範囲は、チャンネルだけを見ている主が、発言から自分の操作を読み取れないことを防ぐことである。拾いたい誤りは 3 つある。主への報告が端末に出るだけでチャンネルに届かないこと。答え方の行が主の見ていない画面を指すこと。主の操作が要るのに答え方の行が無いこと。2 行目以降の説明の良し悪しと、答え方の中身の正しさは、この要件では止めない。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 保留の依頼

- **WHEN** channel の本体が動作確認の保留で主に依頼する
- **THEN** チャンネルに送る発言の 1 行目は質問で、最後の答え方の行に、このチャンネルで何を返せばよいか（例: 「#1126 確認した」）が書かれている

#### Scenario: 完了報告

- **WHEN** channel の本体が PR の合格とマージ待ちを報告し、主の操作が要らない
- **THEN** 1 行目は `主がすること: なし` で、画面やタブを指していない

#### Scenario: 再開で HEAD が動いていた

- **WHEN** channel の本体が新しいセッションでの再開の手順 3 で、引き継ぎの HEAD と PR の今の HEAD が違うと分かる
- **THEN** 本体は差分の報告と続けるかの問いを、1 行目が質問で、最後の答え方の行がこのチャンネルで返すことを案内する発言としてチャンネルに送り、端末に出すだけで済ませない

### Requirement: Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る
`plugins/dev-workflow/scripts/epic-dispatch.sh` は `notify-closed [--relaunch] <epic> <child>` を受け付けなければならない（MUST）。`<epic>` か `<child>` が数字でない・引数の数が違う・`--relaunch` 以外のフラグがある・返事の送り方の環境変数が誤っているときは、使い方を出して exit 1 で終わり、`orca` を呼んではならない（MUST）。

`notify-closed` は次の順に確かめ、条件を満たした子にだけ返事を送らなければならない（MUST）。

1. 子 issue（`gh api repos/{owner}/{repo}/issues/<child>`）の `state` が `closed` でなければ `skipped <child> not-closed`、`state_reason` が `completed` でなければ `skipped <child> not-completed` を出す。`gh` が失敗したら `failed <child> issue` を出す
2. 今のワークツリーと同じ repoId・linkedIssue が `<child>`・archive されていない子のワークツリーが 0 件なら `skipped <child> no-worktree`、2 件以上なら `failed <child> ambiguous-worktree`、一覧を読めなければ `failed <child> list` を出す
3. そのワークツリーの `workspaceStatus` が `completed` なら `skipped <child> already-done`、コメント欄が `epic-stopped` でも `epic-stopped-seen` でもなければ `skipped <child> not-stopped` を出す
4. 条件を満たしたら、要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の `--as parent` と同じ処理（`--relaunch` があれば起動し直す）で、`記録先の issue #<child> は completed で閉じた。完了報告を書き、mark done で終える（停止の記録: <URL>）` を子に送る。`<URL>` は子 issue の 1 行目が `子の停止: 主の返事待ち` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` の最新のものの URL で、見つからなければ子 issue の URL とする。送信の結果が `failed <child> <段>` なら、それを出して exit 1 で終わる
5. 送れたら（`sent` か `relaunched`）、エピックに `親の判断: 子 #<child> 通した — 記録先が completed で閉じたので、完了報告と mark done を促した <URL>` の 1 行をコメントする。投稿できたら `notified <child>` を出し、投稿に失敗したら `unrecorded <child>` を出して stderr に投稿し直すコマンド（`gh issue comment <epic> --body <その 1 行>`）を出す。エピックへの記録は送信のあとに投稿しなければならない（MUST。送る前に投稿すると、送れなかったときに送っていない判断が残るため）

`skipped`・`notified`・`unrecorded` はどれも exit 0 で、stdout はちょうど 1 行とする（MUST）。`skipped` のときは子に何も送らず、エピックにも子 issue にも投稿してはならない（MUST NOT）。

develop の `SKILL.md`「エピックの扱い」→「回し方」の Orca 経路の手順 4 は、`closed <N>...` で起こされて `state_reason` が `completed` の子ごとに、`references/reply-after-idle.md` の表で起動し直すかを決めてから `scripts/epic-dispatch.sh notify-closed`（起動し直すなら `--relaunch`）を呼ぶと書かなければならない（MUST）。`notify-closed` は、依存が解けた子の `launch` より先に呼ぶと書く（MUST。`launch` が `failed` を返すと親は手順 6 で止まり、再開の手順 7 は `notify-closed` を呼ばないので、後ろに置くと閉じた子に送られないまま残る）。出力の扱いとして、`notified` と `skipped` は何もしない、`unrecorded` は stderr に出た投稿し直しのコマンドでエピックに 1 行を残す、`failed` は主に報告する（主に出す発言の 1 行目と最後の行は、要件「エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う」に従う）と書く（MUST）。`state_reason` が `completed` でない子には `notify-closed` を呼ばない（SHALL。作業されていない件に完了を促さない）。

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

#### Scenario: 手順 4 は completed の子に notify-closed を呼ぶ
- **WHEN** develop の `SKILL.md`「回し方」の Orca 経路の手順 4 を読む
- **THEN** `state_reason` が `completed` の子ごとに `scripts/epic-dispatch.sh notify-closed` を呼ぶことと、`unrecorded`・`failed` の扱いが書かれている
- **AND** `notify-closed` は、依存が解けた子を `launch` するより前に書かれている

### Requirement: 別のリポジトリの子を含むエピックの回し方を SKILL.md に書く

develop の SKILL.md「エピックの扱い」は、エピックの子がエピックと別のリポジトリにあるときの挙動を、既存の要件（子エピックの外し方・マージ待ちの子・子の側の手順・コメントの書式）の読み替えとして書かなければならない（MUST）。読み替えは次の表のとおりで、同じリポジトリの子の呼び出しの形・書式・判定は表の外では変えない（MUST）。既存の要件の本文は書き直さず、この要件が読み替えを持つ。

| 既存の書き方 | 別のリポジトリの子での読み替え |
|---|---|
| 子の依存を `gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by` で読む | 子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/dependencies/blocked_by`）で読む。前提の issue のリポジトリは応答の `repository_url` から取り、前提の state もそのリポジトリで読む。前提が別リポジトリにあっても閉じていれば解けている。前提の issue を `gh` が読めないときは、解けていないものとして待つ（この change で新しく決めた扱い。今の SKILL.md にこの記述は無い） |
| 子エピックの判定 `gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` | 子のリポジトリで読む（`repos/<子の owner>/<子の repo>/issues/<N>`）。別リポジトリというだけでは外さず、sub-issue を持つ子だけを外す |
| エピックの子の一覧 | エピックのリポジトリの sub-issue（`gh api repos/{owner}/{repo}/issues/<E>/sub_issues`。各要素の `repository_url` から子のリポジトリを取る）と、エピック本文の子の表（`<owner>/<repo>#<N>` か `#<N>`）を合わせて組み立てる。同じ子は小文字にそろえた `<owner>/<repo>#<N>` で 1 件に数える |
| エピックへのコメント `後で別に起動するエピック: #N` | 別のリポジトリの子は `後で別に起動するエピック: <owner>/<repo>#N` |
| エピックへのコメント `子 #N マージ → 残り k 件`・`子 #N 見送り（<state_reason>）→ 残り k 件`・`子 #N のワークツリーを残した`・`親の判断: 子 #N 通した — ...` | 別のリポジトリの子は `子 <owner>/<repo>#N` の同じ形（`親の判断: 子 <owner>/<repo>#N 通した — ...`）。完了報告も同じ呼び方 |
| 子の側が親エピックに残すコメント `gh issue comment <E> --body '後で別に起動するエピック: #<自分>'` | エピックが別のリポジトリにあるときは `gh issue comment <E> -R <エピックのリポジトリ> --body '後で別に起動するエピック: <自分の owner>/<自分の repo>#<自分>'`。`<E>` とエピックのリポジトリは `route` の stderr の `parent epic: <owner>/<repo>#<E>` から取る |
| マージ待ちの子の前提の `auto-merge.yml` の取得（`repos/<owner>/<repo>/contents/...`）、`親のマージ判断:` のコメント、`parent-merge-approved` のラベル、PR 本文の `Closes #N` の確認 | すべて子のリポジトリの PR に対して行う（`contents` は `repos/<子の owner>/<子の repo>/...`、コメントは `gh pr comment <PR> -R <子の repo>`、ラベルは `gh api repos/<子の repo>/issues/<PR番号>/labels`）。印が数えられるのは `gh` の認証アカウントが子のリポジトリの OWNER・MEMBER・COLLABORATOR のときだけで、そうでなければ決める役を起こさず手順 8 の形で主に上げる |
| 親から届く返事の頭 `親エピック #<E> の判断（主の承認ではない）: ` / `主の返事（親エピック #<E> 経由）: ` を受ける子の側の手順（`references/ci-watch.md` の 1 箇所を含む） | 番号のあとに `（<owner>/<repo>）` が付く形（要件「別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す」）でも同じ手順で受ける。先頭の `親エピック #` / `主の返事（親エピック #` で判定する |
| 手順 4 の `gh api repos/{owner}/{repo}/issues/<N> --jq .state_reason` | 別のリポジトリの子は `gh api repos/<子の owner>/<子の repo>/issues/<N> --jq .state_reason`（親のリポジトリの同じ番号を読んで `completed` と `not_planned` を取り違えない） |
| 手順 8 とマージ待ちの子の、子 issue の `子の停止: 主の返事待ち` と `親の判断:` のコメントの読み先（`author_association` を含む） | 別のリポジトリの子は子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/comments`）から読む |
| 手順 3 (b) の起点ブランチ | その子の記録の `base`（別のリポジトリの子は子のリポジトリの既定ブランチか `--base` の値）。親のリポジトリの `main` ではない |
| `後で別に起動するエピック:` の行で子を外す照合（手順 2・`timeout` と `closed` の確認） | 別のリポジトリの子は `<owner>/<repo>#N` の形の行で照合する（同じリポジトリの子は `#N`） |
| 子を `route`・`launch`・`wait`（位置引数と `--watch-done`）・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt` に渡す | 別のリポジトリの子は `<owner>/<repo>#N` の形で渡す（同じリポジトリの子は番号だけ） |
| SKILL.md:487 の注意書き `親エピックからの注意書き: #<エピック番号>`、手順 1 の「起点は `origin/main`」 | 別のリポジトリの子は注意書きが `親エピックからの注意書き: <エピックの owner>/<repo>#<E>`（子のリポジトリの issue に残る）。起点は `--base` / `EPIC_DISPATCH_BASE`、無ければ子のリポジトリの既定ブランチ |
| `stop-judge.sh <epic> <child>` の `<child>` は番号 | 番号か `<owner>/<repo>#<N>`。後者は子の本文・コメントを `repos/<o>/<r>/issues/<N>` から読み、エピックのコメントの過去の判断を `親の判断: 子 <o>/<r>#<N> ` で始まる行から探す。同じリポジトリの子は今までどおり。入力文の見出しも同じ呼び方にする |

サブエージェント方式（unmanned・channel・Orca 管理外で選ばれる）では、別のリポジトリの子を W に渡してはならない（MUST。W は親のリポジトリに worktree を作るので、別のリポジトリの issue を親のリポジトリの PR として実装してしまう）。本体はエピックに `子 <owner>/<repo>#N は別のリポジトリなので Orca 経路でだけ起動する` と 1 行コメントし、その子と、その子を前提にする子を起こさずに、主に報告する（1 行目と最後の行は、`~/.claude/output-styles/readable.md` の節 3 の書き分けに従う）。

SKILL.md の手順 1 には、`--base` と `EPIC_DISPATCH_BASE` が 1 回の `launch` の全部の子に掛かること、リポジトリごとに既定ブランチが違う子を混ぜるときは `--base` を付けないか `launch` をリポジトリごとに分けることを書かなければならない（MUST）。手順 6 の `failed` の報告には、`failed <child> no-clone`（`EPIC_DISPATCH_CLONES` の設定か clone を主に頼む）・`ambiguous-clone`（候補のパス）・`not-in-orca`（`orca repo add` を主に頼む）・`no-push`・`permission-lookup-failed`・`base-lookup-failed`（stderr の `gh` の認証アカウントと子のリポジトリを添える）を足し、どれも主に報告して止まると書かなければならない（MUST。サブエージェント方式に自動で振り替えない）。

この要件の守備範囲で入力として扱うのは、SKILL.md の手順書の文面と `stop-judge.sh` の引数である。拾いたい誤りは、別のリポジトリの子の依存や子エピックの判定を親のリポジトリに対して読み、解けていない子を起動したり、子エピックを展開したりすることである。次は通してよく、この要件では止めない: 前提の issue を `gh` が読めないとき（読めない前提は解けていないとして待つ。この change で決めた扱い）／エピック本文の子の表の書式の揺れ。表を手で直した結果の細かい食い違いを見つけるたびに検査を足すことは、この要件の完了条件としない。

#### Scenario: 依存と子エピックの判定を子のリポジトリで読むと書いてある
- **WHEN** SKILL.md の「回し方」の経路の決め方と「エピックである子を外す」を読む
- **THEN** 別のリポジトリの子の `blocked_by` と `sub_issues_summary.total` を子のリポジトリで読むこと、前提の issue のリポジトリを `repository_url` から取ることが書いてある

#### Scenario: 子の一覧の組み立てが書いてある
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** sub-issue の `repository_url` とエピック本文の子の表から子の一覧を組み立て、同じ子を 1 件に数えることが書いてある

#### Scenario: 読み先が子のリポジトリだと書いてある
- **WHEN** SKILL.md の手順 3 (b)・手順 4・手順 8・マージ待ちの子・`後で別に起動するエピック:` の照合を読む
- **THEN** 手順 4 は別のリポジトリの子の `state_reason` を `repos/<子の owner>/<子の repo>/issues/<N>` で読むと書いてあり、手順 8 とマージ待ちの子は子 issue のコメントを子のリポジトリから読むと書いてあり、手順 3 (b) は起点を記録の `base` と書いてあり、`後で別に起動するエピック:` の照合は `<owner>/<repo>#N` の形と書いてある

#### Scenario: 各サブコマンドへの渡し方が書いてある
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** 別のリポジトリの子を `route`・`launch`・`wait`・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt` に `<owner>/<repo>#N` で渡すと書いてある

#### Scenario: サブエージェント方式では別のリポジトリの子を起こさない
- **WHEN** SKILL.md の「サブエージェント方式」を読む
- **THEN** 別のリポジトリの子を W に渡さず、エピックに 1 行残して、その子とそれを前提にする子を起こさずに主に報告すると書いてある

#### Scenario: コメントの書式が書いてある
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** 別のリポジトリの子は `子 <owner>/<repo>#N`・`後で別に起動するエピック: <owner>/<repo>#N`・`親の判断: 子 <owner>/<repo>#N 通した` と書くことが書いてあり、同じリポジトリの子は今のままの書式で残っている

#### Scenario: マージ待ちの子を子のリポジトリで扱うと書いてある
- **WHEN** SKILL.md の「マージ待ちの子」を読む
- **THEN** `auto-merge.yml` の取得・`親のマージ判断:` のコメント・`parent-merge-approved` のラベルを子のリポジトリの PR に付けること、認証アカウントが子のリポジトリで権限を持たないときは主に上げることが書いてある

#### Scenario: 子の側が親エピックのリポジトリにコメントする
- **WHEN** SKILL.md の「`nested` を受けたセッション」を読む
- **THEN** エピックが別のリポジトリにあるときは `gh issue comment <E> -R <エピックのリポジトリ>` で `後で別に起動するエピック: <owner>/<repo>#<自分>` を残すと書いてあり、`<E>` とリポジトリを `route` の stderr の `parent epic: <owner>/<repo>#<E>` から取ると書いてある

#### Scenario: 親から届く返事の頭の新しい形を受ける
- **WHEN** SKILL.md の「エピックの子が主の返事を待って止まるとき」と `references/ci-watch.md` の親から届く返事の頭の照合を読む
- **THEN** どちらも `親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）: ` と `主の返事（親エピック #<E>（<owner>/<repo>）経由）: ` を受けると書いてある

#### Scenario: failed の新しい理由の報告が書いてある
- **WHEN** SKILL.md の手順 6 を読む
- **THEN** `no-clone`・`ambiguous-clone`・`not-in-orca`・`no-push`・`permission-lookup-failed`・`base-lookup-failed` を主に報告して止まると書いてある

#### Scenario: stop-judge.sh は owner/repo#番号 の子を受ける
- **WHEN** 子 `genetta-inc/flatmate#1615` を指定して `stop-judge.sh 1122 genetta-inc/flatmate#1615` を実行する（`gh` はスタブ）
- **THEN** 子の本文は `repos/genetta-inc/flatmate/issues/1615` から読まれ、エピックのコメントの過去の判断は `親の判断: 子 genetta-inc/flatmate#1615 ` で始まる行から探される

#### Scenario: 同じリポジトリの子の stop-judge.sh は今と同じ
- **WHEN** 子 `11` を指定して `stop-judge.sh 1122 11` を実行する
- **THEN** 子の本文は今までと同じ `repos/{owner}/{repo}/issues/11` から読まれ、過去の判断は `親の判断: 子 #11 ` で探される
