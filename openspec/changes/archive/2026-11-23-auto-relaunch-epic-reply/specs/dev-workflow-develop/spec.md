## MODIFIED Requirements

### Requirement: epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける
`plugins/dev-workflow/scripts/epic-dispatch.sh` は `reply [--relaunch] --as <parent|owner> <epic> <child> <text>` を受け付けなければならない（MUST）。`--as` が無い・値が `parent` / `owner` 以外・`<epic>` か `<child>` が数字でない・`<text>` が空なら、使い方を出して exit 1 で終わり、`orca` を呼んではならない（MUST）。

送る文の頭には、`--as parent` なら `親エピック #<epic> の判断（主の承認ではない）: `、`--as owner` なら `主の返事（親エピック #<epic> 経由）: ` を付けなければならない（MUST）。

`reply` の両送り手は、`--relaunch` が無ければ要件「wait --resolve は通す返事を送る前に起動し直すかを表で決める」と同じ判定を適用しなければならない（MUST）。本体のログの選び方、記録の worktree と stop_uuid の使い方、会話量と経過時間の OR 条件、計測失敗時の扱いを共通にする。以下の表の「起動し直し」は、明示の `--relaunch` またはこの自動判定が真の場合を指す。`--relaunch` があれば自動判定を行わず従来どおり起動し直す。not-stopped の送信抑止は自動判定より優先し、端末を閉じる・作る操作を行わない（MUST）。この自動判定の追加は直接の `reply` に限り、`notify-closed` の送り方は変更しない。

自動判定する `reply` は、`EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）と `EPIC_DISPATCH_RELAUNCH_IDLE_SEC`（既定 3600）を非負整数として検査し、不正なら端末操作前に使い方と変数名を stderr に出して exit 1 で終わらなければならない（MUST）。旧 `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` は読まない。明示の `--relaunch` にはこの追加検査を掛けない。

`reply` は今の Orca の一覧から、今のワークツリーと同じ repoId・linkedIssue が `<child>`・archive されていない子のワークツリーを探し、次のとおりに動かなければならない（MUST）。stdout は 1 行。

| 状態 | 動き | stdout | exit |
|---|---|---|---|
| ワークツリーがちょうど 1 件、端末が 1 つ以上、起動し直しの判定が偽、子のセッションの端末が決まる | 子のセッションの端末（下記）に送り、ターンの開始まで確かめる（`launch` と同じ確かめ方） | `sent <child>` | 0 |
| ワークツリーがちょうど 1 件、端末が 0 か起動し直しの判定が真 | 起動し直しの判定が真なら先にそのワークツリーの端末を全部閉じる。`launch` と同じ起動コマンド（`EPIC_DISPATCH_PARENT_EPIC=<epic>` と待っている間の自動コンパクトの閾値を前置きしたもの）で端末を作り、`/develop #<child> （エピック #<epic> の子。返事を受けて起動し直し）` のうしろに頭を付けた文を続けて送る | `relaunched <child>` | 0 |
| 端末が 1 つ以上で子のセッションの端末が決まらない（起動し直しの判定が偽。シェルの端末だけのときを含む） | 送らず、作らず、閉じない（シェルの端末が子のセッションでないと一覧から言い切れず、起動し直すと二重に動きうるため。stderr に `--relaunch` で起動し直せることを出す） | `failed <child> ambiguous-terminal` | 1 |
| ワークツリーがちょうど 1 件で、子はもう止まっていない（記録の `stop` が `stopped` でも `stopped-seen` でもない。記録の `stop` が `stopped-seen` で `stop_uuid` があり、会話ログを読めて、止まりの発言より新しい発言か入力が進んでいるときを含む） | 送らず、作らず、閉じない（主が子のタブで先に答えて子が再開しているので、古い返事を重ねない。`--relaunch` を付けていても同じ） | `skipped <child> not-stopped` | 0 |
| ワークツリーが 0 件か 2 件以上 | 送らない | `failed <child> no-worktree` / `failed <child> ambiguous-worktree` | 1 |
| 端末の一覧が読めない（`orca` が失敗した、または `result.terminals` が欠落・`null`・配列以外） | 端末を 0 と数えず、送らず、作らず、閉じない（0 と数えて作り直すと、動いている子が二重に起動するため） | `failed <child> terminal-list` | 1 |
| 送信・作成・閉じるのどれかが失敗、またはターンの開始を確かめられない | 送り直しか作り直しのコマンドを stderr に出す（`launch` の案内と同じ形） | `failed <child> <段>` | 1 |

子のセッションの端末は、端末の一覧（`result.terminals`）のうち `agentIdentity` が `claude` の端末、それが 1 つも無ければ `title` に `Claude Code` を含む端末（Claude Code はタイトルを書き換えるので `agentIdentity` を先に見る）が、ちょうど 1 つのときのその端末としなければならない（MUST）。今の Orca では `launch` の `orca worktree create` が空のシェルの端末（タイトル `Terminal 1`）を作り、そのあと Claude Code の端末を足すので、端末の数では決めない。`launch` を直して端末を 1 つにする件（#1055）のあとの、Claude Code の端末だけがある形でも同じ決め方で送る。

`not-stopped` の行は端末についての行（端末が 1 つ以上・0 か `--relaunch`・決まらない・一覧が読めない）より先に当てる（端末の一覧を読む前に決まる）。「止まっていない」かどうかは、`reply` が送る直前に、今の子の記録（ワークツリーが 1 件に決まったあと）から決めなければならない（MUST）。会話ログを読めない（ログが無い・読み取りに失敗した）`stopped-seen` の子は、会話ログだけで再開したのかを区別できないので、今までどおり送る。`notify-closed` はすでに同じ確認をしており、出力は変わらない。

develop の手順書には `orca` のコマンドを書かず、端末の有無の確かめ方は `reply` が持つ（MUST。既存要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca` のスタブで上の表の各行と、頭の付け方、引数の誤りで `orca` を呼ばないことを確かめなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、自動判定に使う状態の記録・本体ログ・閾値の環境変数に加え、引数と、`orca` の一覧・端末の一覧・送信の出力である。拾いたい誤りは、親の判断を主の返事として届けること（頭の取り違え）、どの端末が子のセッションか分からないまま送ること、端末が無い子に送ったつもりで何も届かないこと、`--relaunch` で古いセッションを残したまま新しいセッションを起動して同じ子が二重に動くことの 4 つに、主が子のタブで先に答えて再開した子に古い返事を重ねて送ること、を足した 5 つである。次は通ってよく、この要件では止めない: 返事の文の中身（親が主の答えを書き換えることは手順で防ぎ、この要件では見ない）／送った端末で子のセッションがちょうど終わっていて、シェルに文字が打ち込まれること（端末の一覧から区別できない。子が閉じた件は `wait` の `closed` で分かる）／子が `mark resumed` を呼ばず会話ログも読めないまま再開していること（読めない子は送る。次の `wait` のポーリングが記録を `resumed` に直す）。端末やワークツリーの取り違えをすり抜ける形が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 端末が 1 つなら送り手を付けて送る
- **WHEN** 自動判定の両条件を真と確認できず、子 11 のワークツリーに Claude Code の端末が 1 つある状態で `reply --as owner 400 11 'A で進めて'` を実行する
- **THEN** その端末に `主の返事（親エピック #400 経由）: A で進めて` が送られ、stdout は `sent 11` で exit 0

#### Scenario: 端末が無ければ起動し直して返事を付ける
- **WHEN** 子 11 のワークツリーに端末が無い状態で `reply --as parent 400 11 '推奨どおり'` を実行する
- **THEN** `EPIC_DISPATCH_PARENT_EPIC=400` と閾値を前置きした起動コマンドで端末が作られ、`/develop #11` で始まり `親エピック #400 の判断（主の承認ではない）: 推奨どおり` を含む文が送られ、stdout は `relaunched 11`

#### Scenario: relaunch は先に端末を閉じる
- **WHEN** 子 11 のワークツリーに端末が 1 つある状態で `reply --relaunch --as owner 400 11 'B で'` を実行する
- **THEN** 端末を閉じる呼び出しが端末を作る呼び出しより先にあり、stdout は `relaunched 11`

#### Scenario: Orca のシェルの端末と Claude Code の端末があれば Claude Code の端末に送る
- **WHEN** 自動判定の両条件を真と確認できず、子 11 のワークツリーに、タイトル `Terminal 1` のシェルの端末と `agentIdentity` が `claude` の端末がある状態で `reply --as parent 400 11 '推奨どおり'` を実行する
- **THEN** `agentIdentity` が `claude` の端末にだけ送られ、stdout は `sent 11` で exit 0

#### Scenario: 子のセッションの端末が決まらなければ送らない
- **WHEN** 自動判定の両条件を真と確認できず、子 11 のワークツリーに Claude Code の端末が 2 つある、またはシェルの端末だけがある状態で `reply --as owner 400 11 'A'` を実行する
- **THEN** 送信・作成・閉じるの呼び出しは無く、stdout は `failed 11 ambiguous-terminal` で exit 1

#### Scenario: as が無ければ orca を呼ばない
- **WHEN** `reply 400 11 'A'` を実行する
- **THEN** stderr に使い方が出て exit 1、`orca` は呼ばれない

#### Scenario: 再開済みの子には送らず not-stopped を返す
- **WHEN** 子 11 の記録の `stop` が `resumed` で、Claude Code の端末が 1 つある状態で `reply --as owner 400 11 'A'` を実行する
- **THEN** stdout は `skipped 11 not-stopped` で exit 0、`orca` の送信も端末の作成も呼ばれない

#### Scenario: 止まっている子にはこれまでどおり送る
- **WHEN** 自動判定の両条件を真と確認できず、子 11 の記録の `stop` が `stopped` か `stopped-seen` で、`stopped-seen` なら会話ログが止まりの発言のまま、Claude Code の端末が 1 つある状態で `reply --as owner 400 11 'A'` を実行する
- **THEN** stdout は `sent 11` で exit 0

#### Scenario: 記録が stopped-seen のままでも会話ログが進んでいれば送らない
- **WHEN** 子 11 の記録の `stop` が `stopped-seen`・`stop_uuid` が `d1` で、会話ログに `d1` より後のユーザーの入力がある状態で `reply --as owner 400 11 'A'` を実行する
- **THEN** stdout は `skipped 11 not-stopped` で exit 0、`orca` の送信は呼ばれない

#### Scenario: parent と owner の大きい会話は短時間でも起動し直す
- **WHEN** 止まっている子の本体ログの最後の assistant が 5 分前で会話量が 150000 または 150001 の fixture に、`--relaunch` なしで `reply --as parent` または `reply --as owner` を実行する
- **THEN** 既存端末を閉じてから作り、`/develop #<child>` と送り手を保った返事を送り、stdout は `relaunched <child>`、exit 0

#### Scenario: 閾値未満で短時間ならそのまま送る
- **WHEN** 止まっている子の本体ログの会話量が 149999、最後の assistant が 5 分前の fixture に、両送り手の `reply` を `--relaunch` なしで実行する
- **THEN** stdout は `sent <child>`、exit 0 で、端末を閉じず作らない

#### Scenario: 会話が小さくても時間条件で起動し直す
- **WHEN** 止まっている子の本体ログの会話量が 150000 未満、最後の assistant が 3600 秒以上前の fixture に、両送り手の `reply` を `--relaunch` なしで実行する
- **THEN** compact の有無によらず stdout は `relaunched <child>`、exit 0

#### Scenario: 自動判定も同じログと計測不能時の規則を使う
- **WHEN** 本体ログを一意に決められない、または片方の計測だけができる fixture に `reply` を実行する
- **THEN** wait --resolve と同じく、確認できた条件が真なら起動し直し、両条件とも真と確認できなければ通常の送り方に戻る。通常の送り方でも端末が無ければ起動し直す

#### Scenario: 明示の起動し直しは追加検査を受けない
- **WHEN** 小さい会話で短時間の停止中の子に、上記の自動判定用の環境変数が不正でも `reply --relaunch` を実行する
- **THEN** 従来どおり端末を閉じて作り直し、stdout は `relaunched <child>`、exit 0

#### Scenario: 自動判定の閾値を上書きし不正値を検出する
- **WHEN** `--relaunch` なしの `reply` に FORCE_TOKENS と IDLE_SEC の非負整数の上書き、または空文字・150k・-1 の不正値を与える
- **THEN** 有効な値は wait --resolve と同じ境界で判定し、不正値は変数名と使い方を stderr に出して exit 1、端末操作を行わない

#### Scenario: 大きい会話でも再開済みなら返事を重ねない
- **WHEN** 会話量または時間条件が真でも、送信直前の記録とログが既存の not-stopped 条件に当たる子に `reply` を実行する
- **THEN** stdout は `skipped <child> not-stopped`、exit 0 で、端末への送信・作成・閉じる操作は無い

### Requirement: 時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める
時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、子について次を書かなければならない（MUST）: すべての develop セッションは開始時の worktree-local 設定でアイドル時のコンパクトを切り、子は補助として `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること（そのプロセスだけに効き通常の自動コンパクトは止めない・v2.1.290 以降が要る・ホームの `~/.claude/settings.json` に置かない（worktree の `.claude/settings.local.json` だけを使う））。子の表は上から、端末が無ければ起動し直す、会話量 N が `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）以上なら経過時間と compact の有無によらず起動し直す、最後のリクエストから 60 分未満ならそのまま送る、60 分以上なら compact の有無と会話量によらず起動し直す、と書く。会話量条件が時間条件に優先するよう並べる。根拠は、コンパクトされた子は `SKILL.md` の中身を持たずに進むことと、費用の差の小ささ。

根拠には、2026-10-23 の子のログで、コンパクトのあとに残ったのが `SKILL.md` のファイル名と `/develop` の入口だけで、再開したあとも読み直さずにゲートの実行まで進んでいたことと、起動し直しとの費用の差（1 回あたり Opus 5.5 で約 $0.5）、1 時間以上たってから返事が来る子の割合（3.2%）を書く（SHALL）。判定に使う事実は、子の端末の有無（`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）と、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻、および同じファイルを `plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>` で測った会話量 N である。事実を読めない場合は、上の自動判定の要件と同じく確認できた条件だけで決め、どちらも真と確認できなければそのまま送ると書く（MUST）。送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順（develop の `references/epic-loop.md` の Orca 経路と `epic-dispatch.sh reply`）が書き、このファイルを参照する）。

#### Scenario: 規則のファイルに子の切り方と分ける条件と根拠が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 子は `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること、ホームの `~/.claude/settings.json` に置かず、worktree の `.claude/settings.local.json` だけを使うこと、子は端末が無い・会話量が新閾値以上・60 分以上のいずれかなら起動し直し、会話量が閾値未満か不明で 60 分未満ならそのまま送ること、新閾値の変数名と既定値 150000、子を起動し直す根拠（コンパクトされた子は `SKILL.md` の中身を持たない）と #1039 の決定を #1323 で覆したこと、判定に使う事実（端末の有無は `epic-dispatch.sh reply` が確かめること・最後のリクエストの時刻はトランスクリプトから読むこと・会話量は同じファイルを `subagent-context.sh --file` で測ること）が書かれている

この分類は、直接の `epic-dispatch.sh reply`（`--as parent` / `--as owner`）と `wait --resolve` が通す返事ではスクリプトが同じ子の表で自動判定する（MUST）。本体が指定を忘れても直接の `reply` に判定が掛かると規則のファイルに書く（MUST）。`notify-closed` の分類は本体が規則のファイルを読んで行い、これを直接の `reply` の自動判定と混同しない。拾いたい誤りは、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子と、この変更より前に起動されてコンパクトされうる子を含む）にそのまま返事を送り、子が手順を外れて進むこと、大きい会話の子に時間だけを見て返事を送り続けること、会話量が閾値未満か不明で 60 分未満の子を不要に起動し直して、子が積んだ判断と起動し直しの費用を無駄にすることである。次は通してよく、この分類では止めない: 経過時間がちょうど 60 分前後で、時刻の読み方によって扱いが分かれる子／トランスクリプトが複数あってどれが子のセッションか分からず、そのまま送った子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: 子の会話量の行が短時間の行に優先する
- **WHEN** 子の表を上から読む
- **THEN** 端末が無い行の次で、`EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS` と既定値 150000 が明記された会話量の行により、60 分未満でも閾値以上なら起動し直すと分かる

#### Scenario: 閾値を選んだ根拠と限りが分かる
- **WHEN** 規則のファイルの子の説明を読む
- **THEN** #1046 の再集計の結論に合わせて 150000 を採用したことと、その集計はキャッシュ有効中の新条件の最適値を実証したものではないこと、時間条件は #1323 のまま残ることが書かれている

#### Scenario: 直接の返事も指定なしで自動判定すると分かる
- **WHEN** reply-after-idle.md の子の分類の説明を読む
- **THEN** 両送り手の reply は --relaunch なしでも wait --resolve と同じ判定が掛かること、明示 --relaunch は残ること、notify-closed は従来どおり本体が分類することが分かる

## ADDED Requirements

### Requirement: 完了を伝えるだけの子を起こす必要は既存の片付け条件で分ける
`references/epic-loop.md` は、PR がマージ済みで実作業が残っていない子でも、親だけの片付けが全件には足りないと理由付きで記さなければならない（MUST）。既に done なら reap、既存の完了推定条件を満たす子なら wait --watch-done → done → reap を使い、「終えて」だけの reply を省く（MUST）。停止中または waiting の子は完了推定の対象外で、停止中の completed の子には既存 notify-closed を残す（MUST）。親の mark done の代行や状態記録の直接編集を手順にしてはならない（MUST NOT）。

守備範囲: 入力は親の子状態記録、子のログ、GitHub の閉鎖状態、wait・reap・notify-closed の出力。防ぐ誤りは、片付け可能な子への不要な返事と、推定対象外の子の完了促進の省略・done の強制。done でも既存の安全確認で reap が `kept <N> dirty` を返して子を残すことは許容する。分類の穴を塞ぎ切ることは完了条件にしない。

#### Scenario: done または完了推定可能な子には終了だけの返事を送らない
- **WHEN** マージ済みで残作業のない子が done、または running・止まりの印なし・ログありで completed の閉鎖と最後の活動から各 EPIC_DISPATCH_DONE_IDLE_SEC 以上経過した場合の手順を読む
- **THEN** reply で子を起こさず、前者は reap、後者は wait --watch-done の done を受けて reap すると分かる

#### Scenario: 停止中の子には既存の完了促進を残す
- **WHEN** PR がマージ済みでも status が waiting、または stop が stopped / stopped-seen の子の場合の手順を読む
- **THEN** 完了推定では done にできず reap は not-done で残す理由が分かり、completed で閉じた停止中の子は既存 notify-closed で完了報告と mark done を促すと分かる
