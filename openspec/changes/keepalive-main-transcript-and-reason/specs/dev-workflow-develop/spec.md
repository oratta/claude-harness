## MODIFIED Requirements

### Requirement: wait --resolve は通す返事を送る前に起動し直すかを表で決める
`epic-dispatch.sh wait --resolve` の `resolve_stopped` は、判断が `通す` のとき、`reply-after-idle.md` の子の表に従って `deliver_reply` の `relaunch` を決めなければならない（MUST）。子の会話量 `context_tokens` が `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）以上なら、経過時間と `compact_boundary` の有無によらず起動し直す（`relaunched`）。子の最後のリクエスト（トランスクリプトの最後の assistant の行の `timestamp`）から `EPIC_DISPATCH_RELAUNCH_IDLE_SEC`（既定 3600）秒以上の場合も、会話量と `compact_boundary` の有無によらず起動し直す。2 条件は OR とし、どちらも真と確認できなければ今までどおり送る（`sent`）。トランスクリプトは、状態の記録の `worktree` のパスの英数字以外を `-` に置換した名前の `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}` 直下のディレクトリの `*.jsonl` のうち、本体の会話のログ 1 本だけを使う（MUST）。本体のログは、`entrypoint` が `cli` ちょうどで sidechain でない assistant の行を持つファイルを候補にし、全行の `timestamp` の最大値が最も新しい 1 本とする。最大値が最も新しいファイルが 2 本以上あるとき、記録の `stop_uuid` が空でないのに選んだファイルがその uuid の行を持たないとき、`stop_uuid` が空で候補が 2 本以上あるときは、本体のログを決めない（dev-workflow-epic-state の要件「止まった子への声かけは本体の会話ログ 1 本で判定する」と同じ選び方で、選ぶ処理は 1 つの関数を共有する）。`sdk-py` などの別のセッションのログが同じ置き場にあっても、それだけを理由にそのまま送ってはならない（MUST NOT）。本体のログを決められない・ファイルを読めないときはそのまま送る（端末が無いときの起動し直しは既存の送信処理に従う）。会話量は同じトランスクリプトを `plugins/dev-workflow/scripts/subagent-context.sh --file <file>` で測った `context_tokens` を使う（MUST）。exit 0 と 2 の JSON の値を比較し、`over_cap` やサブエージェント用の閾値で代用してはならない（MUST NOT）。会話量を読めなくても時間条件が真なら起動し直し、時刻を読めなくても会話量条件が真なら起動し直す（MUST）。新しい閾値と既存の時間閾値は未設定のときだけ既定を使い、数字だけの非負整数を受け付け、空か数字だけでない値なら、有効な `--resolve` の待ち受けに入る前に変数名と使い方を出して exit 1 で終わる（MUST）。`EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` は読まない（SHALL。設定されていても値を検査しない）。`tests/epic-dispatch.bats` は偽の `orca`・`gh`・トランスクリプトで次の Scenario を確かめなければならない（MUST）。

この要件の入力は、状態の記録の `worktree`、本体のログとして選ばれたトランスクリプトの `timestamp`・`type` と会話量の計測値、上の環境変数である。拾いたい誤りは、大きい会話の子へ 60 分未満だからとそのまま送り続けること、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子を含む）へそのまま送ること、会話量が閾値未満かつ 60 分未満の子を不要に起動し直すことである。次は通してよく、この要件では止めない: 経過時間が 60 分前後で時刻の読み方により扱いが分かれる子／本体のログを決められずそのまま送った子（過去の `cli` のログだけが残る子、最終活動が同時刻の候補がある子を含む）／PC が寝ていて、60 分未満と読め、会話量条件も真と確認できなかった子／計測に必要な情報が欠けて両方の条件を真と確認できなかった子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。送れたあとのエピックの記録と、成功した子を待ち受けの出力から外す契約は維持する（MUST）。以下の `sent` / `relaunched` は送信処理の結果であり、`wait` の stdout にその行を追加する要件ではない。

#### Scenario: 60 分以上・コンパクトなし・150,000 以上なら起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、`compact_boundary` が無く、会話量が 150,000 以上で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届き、エピックに通した記録が残る

#### Scenario: 60 分以上なら会話量によらず起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、`compact_boundary` が無く会話量が 150,000 未満で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 60 分以上ならコンパクトが走っていても起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、そのあとに `compact_boundary` がある状態で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 60 分未満ならそのまま送る
- **WHEN** 最後のリクエストが 60 分未満前で会話量が 149999 の子に、既定値で同じ実行をする
- **THEN** 返事は `sent` で届く

#### Scenario: 事実を読めなければそのまま送る
- **WHEN** トランスクリプトが無い、または記録の `stop_uuid` を持つ `cli` のログが無い（過去の `cli` のログだけがある）、または最終活動が同時刻の `cli` のログが 2 本ある
- **THEN** 返事は `sent` で届く

#### Scenario: 別のセッションのログが混ざっていても本体のログで決める
- **WHEN** 置き場に `entrypoint` が `sdk-py` のログと、最後のリクエストが 60 分以上前で記録の `stop_uuid` を持つ本体のログがある
- **THEN** 返事は `relaunched` で届く

#### Scenario: 閾値の環境変数が数字でなければ起動しない
- **WHEN** `EPIC_DISPATCH_RELAUNCH_IDLE_SEC=1h` で `wait --resolve` を実行する
- **THEN** stderr に変数名と使い方が出て exit 1 である

#### Scenario: 会話量の環境変数は読まない
- **WHEN** `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS=150k` で、最後のリクエストが 60 分以上前の子に `wait --resolve` を実行する
- **THEN** exit 1 にならず、返事は `relaunched` で届く

#### Scenario: 60 分未満でも会話量が閾値ちょうどかそれ以上なら起動し直す
- **WHEN** 最後の assistant が 5 分前で `context_tokens` が 150000 または 150001 の子に、既定値で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届き、端末を起動し直して `/develop #<child>` と返事を送り、送れたあとにエピックに通した記録が残る

#### Scenario: 会話量条件は compact の有無によらない
- **WHEN** 最後の assistant が 5 分前で、`compact_boundary` がある子の最新の有効な usage による会話量が 150000 の状態で、既定値で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: compact 後の最新の会話量が小さければそのまま送る
- **WHEN** 150000 以上の usage のあとに `compact_boundary`、そのあとに 5 分前で会話量が 100000 の有効な usage がある状態で、既定値で実行する
- **THEN** 返事は `sent` で届き、compact 前の最大値では起動し直さない

#### Scenario: キャッシュの量も含む最後の有効な usage で決める
- **WHEN** 5 分前の有効な assistant usage が input 10000・cache_creation 40000・cache_read 100000 で、そのあとに usage が全部 0 の API エラーの assistant があり、既定値で実行する
- **THEN** `subagent-context.sh --file` の会話量 150000 を使い、返事は `relaunched` で届く

#### Scenario: 会話量を読めなくても時間条件で起動し直す
- **WHEN** 本体のログとして選べて読めるトランスクリプトに有効な usage が無い、または会話量の計測が失敗したが、最後の assistant が 60 分以上前の状態で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 時刻を読めなくても会話量条件で起動し直す
- **WHEN** 本体のログとして選べて読めるトランスクリプトから時刻を読めないが、会話量が 150000 の状態で既定値で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 両条件とも真と確認できなければそのまま送る
- **WHEN** 時刻と有効な usage の両方が無い、または最後の assistant が 5 分前で会話量だけを計測できない状態で実行する
- **THEN** 返事は `sent` で届く

#### Scenario: 会話量閾値は既定値と独立して上書きできる
- **WHEN** 最後の assistant が 5 分前で会話量 160000 の子に `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS=200000` で実行する
- **THEN** 返事は `sent` で届く

#### Scenario: 会話量閾値を 0 にできる
- **WHEN** 最後の assistant が 5 分前で会話量 100000 の子に `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS=0` で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 会話量閾値の不正値は待つ前に拒否する
- **WHEN** `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS` を空文字・`150k`・`-1` のいずれかにして有効な `wait --resolve` を実行する
- **THEN** 変数名と使い方を stderr に出して exit 1 となり、子の端末を作成・送信・終了しない

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
