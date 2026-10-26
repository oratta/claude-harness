## MODIFIED Requirements

### Requirement: エピックの並列起動は 1 段で止める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子セッションを起動する端末のコマンドの先頭に `EPIC_DISPATCH_PARENT_EPIC=<epic>` を置かなければならない（MUST。`<epic>` は `launch` に渡したエピック番号）。そのうしろに `<cmd>` を置き、`<cmd>` と `--model` のあいだに `--settings '{"idleCompaction":false}'` を置く（MUST。子のセッションのアイドル時のコンパクトを切る。`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を付けないことを含め、要件「子のセッションはアイドル時のコンパクトを切って起動する」が定める）。コマンド全体は `EPIC_DISPATCH_PARENT_EPIC=<epic> <cmd> --settings '{"idleCompaction":false}' --model <model>` の形になり、端末を作れなかった子について stderr に出す `orca terminal create --command ...` の作り直しのコマンドにも同じ前置きが入る（SHALL）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の出力の規定、`<cmd>` の形の規定、および Scenario「EPIC_DISPATCH_MODEL…」「EPIC_DISPATCH_CLAUDE_CMD…」の `--command` の値に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

環境変数 `EPIC_DISPATCH_PARENT_EPIC` が空でない環境では:

- `route <child>...` は、子の番号の検査（数字でなければ使い方を出して exit 1）のあと、子の件数・`orca` の有無・`orca worktree current` の結果によらず stdout に `nested` の 1 行を出して exit 0 で終わらなければならない（MUST）。`orca` を呼んではならない（MUST NOT）
- `launch` は、引数の検査（既存の使い方の誤り）のあと、`orca` と `git` を 1 つも呼ばず、stderr に親エピックの番号と展開しない旨を出して exit 1 で終わらなければならない（MUST。子ワークツリーを作らない）。stdout には何も出さない（SHALL）
- `wait` の振る舞いは変えない（SHALL）

develop の `references/epic.md`「エピックの扱い」は次を規定しなければならない（MUST）。

- **エピックの子を外す**: 本体は依存グラフから求めた blocked されていない子のうち、sub-issue を持つ子（`gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` が 1 以上。`null` や空は 0 とみなす）をエピックとして外し、`route`・`launch`・サブエージェント方式のどれにも渡してはならない（MUST NOT）。経路が `nested` でないと確定したら（`route` が `nested` 以外を返したとき。`route` を呼ばない unmanned と、`回し方:` のコメントから経路を引き継いだ再開を含む）、外した子ごとにエピックへ `後で別に起動するエピック: #N` と 1 行コメントする（MUST）。再開時に `回し方:` のコメントから経路を引き継いだ場合も、`launch` に渡す前に同じ確認で外す（MUST）
- **`nested` を受けたセッション**: `route` が `nested` を返したら、そのセッションはエピックを展開してはならない（MUST NOT。Orca 経路もサブエージェント方式も使わない）。親エピック（`EPIC_DISPATCH_PARENT_EPIC` の番号）と自分の issue に `後で別に起動するエピック: #<自分の issue>` とコメントし、ユーザーに後で `/develop #<自分の issue>` を別に起動して回すと伝えて止まる（MUST）。自分の issue を閉じてはならない（MUST NOT）。`launch` が stderr に展開しない旨を出して exit 1 で終わったときも同じに扱い、「親ワークツリーで開き直す」とは報告しない（MUST NOT）
- **親の待ち受け**: Orca 経路の本体は、`timeout` と `closed` で起こされたときの確認で、エピックに `後で別に起動するエピック: #N` の行がある子を動いている子から外す（MUST）
- **親の完了報告**: 動いている子が無くなったときの本体の報告（エピックへのコメントとユーザーへの報告）に、エピックに記録した `後で別に起動するエピック:` の番号をすべて載せる（MUST）。子エピックが閉じるまで親エピックの完了条件は満たされないので、親エピックを閉じてはならない（MUST NOT）

この要件の守備範囲で入力として扱うのは、`launch` が子の端末のコマンドに前置きした `EPIC_DISPATCH_PARENT_EPIC`（子セッションの Claude Code とその Bash・サブエージェントに引き継がれる）、本体が依存グラフから求めた子の番号ごとの `sub_issues_summary.total`、エピックのコメントの `後で別に起動するエピック:` で始まる行である。拾いたい誤りは、並列起動された子のセッションが自分の issue をエピックとして孫のワークツリーとセッションを作ることである。次は通してよく、この要件では止めない: `EPIC_DISPATCH_PARENT_EPIC` の値は空でなければ数字かどうかを検査しない／人が手で `EPIC_DISPATCH_PARENT_EPIC` を付けて起動したセッションも `nested` になる／sub-issue を持たず本文で子を列挙しているだけのエピックは事前確認を通り、Orca 経路で起動された子なら子のセッションの `route` で止まり、サブエージェント方式で起こされた子（変数が無い）は止まらない／`回し方:` のコメントからサブエージェント方式を引き継いだ子エピックのセッションはスクリプトでは止まらない／この変更の前に起動された子セッションには変数が無く従来どおり展開しうる／`EPIC_DISPATCH_CLAUDE_CMD` が前置きの代入を受け付けない形（`exec` で始まる文字列など）のときは値が渡らない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`EPIC_DISPATCH_PARENT_EPIC` の前置き、`route` の `nested`、`launch` の拒否、`references/epic.md` の上の記述を確かめなければならない（MUST）。

#### Scenario: launch は子の端末のコマンドに親エピックの番号を前置きする
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` の無い環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=420 cld --settings '{"idleCompaction":false}' --model 'opus'` である

#### Scenario: 端末の作り直しのコマンドにも前置きが入る
- **WHEN** `orca terminal create` が失敗する環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** stderr の作り直しのコマンドは `--command 'EPIC_DISPATCH_PARENT_EPIC=420 ` を含む（値全体が単一引用符で囲まれる）

#### Scenario: 並列起動された子のセッションでは route が nested を返す
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` で、`orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `nested` の 1 行で exit 0、`orca` は呼ばれない

#### Scenario: 並列起動された子のセッションでは launch が子ワークツリーを作らない
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `epic-dispatch.sh launch 460 11 12` を実行する
- **THEN** exit 1、stdout は空、`orca` と `git` は 1 回も呼ばれず、stderr に `420` を含む理由が出る

#### Scenario: 並列起動された子のセッションでも引数の誤りは使い方を出す
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `epic-dispatch.sh route '#11'` を実行する
- **THEN** stderr に使い方が出て exit 1

#### Scenario: epic.md に子エピックの扱いと完了報告が書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** sub-issue を持つ子を外して `後で別に起動するエピック: #N` とコメントすること、`route` の `nested` を受けたら展開せず親エピックと自分の issue にコメントして止まること、`nested` と同じく `launch` の拒否でも止まり「親ワークツリーで開き直す」と報告しないこと、`timeout` と `closed` の確認でその行がある子を待つ対象から外すこと、完了報告に `後で別に起動するエピック:` の番号を載せることが書かれている

### Requirement: launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子ごとに `orca worktree create` が終わったあと、`orca terminal list --worktree path:<子> --json` で端末を数えなければならない（MUST。Orca は worktree create で空のシェルの端末を 1 つ作り、`orca terminal create` で 2 つ目を作ると子の端末が 2 つになって、`reply` が `ambiguous-terminal` で止まるため）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の launch の呼び出し順のうち、端末を用意する段の中身を定める（その要件の本文はこの変更で端末を用意する段を条件付きに直してある）。それ以外の規定（起動コマンドの形・環境変数・`terminal wait`・`terminal send`）は変えない。`launched`/`failed` の判定は、この要件では定めない（MODIFIED 側の本文に従う）。

- 端末がちょうど 1 つなら、`orca terminal create` を呼ばず、その端末のハンドルに `orca terminal send --terminal <handle> --text <cmd> --enter --json` で起動コマンド `<cmd>`（従来 `--command` に渡していた文字列と同じ）を打ち込む（MUST）。続けて `orca terminal list --worktree path:<子> --json` を引き直し、その端末が Claude Code（`agentIdentity` が `claude`、無ければタイトルに `Claude Code` を含む）になるのを待つ（MUST。シェルは起動コマンドを打つ前から idle で、すぐ `terminal wait` を呼ぶと最初の指示がシェルに入るため）。待つ上限は `EPIC_DISPATCH_READY_TIMEOUT_MS` を秒にした値（最低 1 回）とする。Claude Code になったら、その端末のハンドルで `terminal wait --for tui-idle` と指示の `terminal send` へ進む（MUST）
- 端末が 0 個なら、従来どおり `orca terminal create` で作る（MUST。worktree create が端末を作らない版の後方互換）
- 一覧を読めない・端末が 2 個以上（起動コマンドを打ち込んだあとの引き直しで 2 個以上になった場合を含み、その場合は指示を送らない）・起動コマンドを打ち込めない・待っても Claude Code にならない、のいずれかなら、その子を `failed <N>` とし、`orca terminal create` を呼ばない（MUST。端末を増やすと二重起動の原因になるため）。stderr に理由と、確認または続きを手で行うコマンド（`orca terminal list --worktree path:<子> --json`、`orca terminal read --terminal <handle>`、打ち込めなかった起動コマンド）を出す（SHALL）

#### Scenario: worktree create が作ったシェルの端末で子のセッションが起動し、端末は 1 つのまま
- **WHEN** 子 11 のワークツリーに空のシェルの端末（`term-11`、`agentIdentity` なし）が 1 つあり、起動コマンドが届いたあとは同じ端末が `agentIdentity: claude` になるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` は呼ばれず、`orca terminal send --terminal term-11` が 2 回（1 回目は `EPIC_DISPATCH_PARENT_EPIC=400 cld --settings '{"idleCompaction":false}' --model 'opus'` を含む `--enter --json`、2 回目は `/develop #11` を含む指示）、`orca terminal wait --terminal term-11 --for tui-idle` が 1 回呼ばれ、stdout は `launched 11`、exit 0

#### Scenario: 端末が 0 個なら従来どおり terminal create で作る
- **WHEN** 子 11 のワークツリーの端末が 0 個のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create --worktree path:<子 11> --command ... --json` が呼ばれ、stdout は `launched 11`、exit 0

#### Scenario: シェルの端末が Claude Code にならなければ端末を作らずに failed
- **WHEN** 起動コマンドを打ち込んだあとも端末が Claude Code にならないスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` も `orca terminal wait` も呼ばれず、stderr に `did not become Claude Code` を含む行が出て、stdout は `failed 11`、exit 1

#### Scenario: 端末が 2 個以上・一覧が読めないときは端末を作らずに failed
- **WHEN** 子 11 のワークツリーの端末が 2 個ある、または `orca terminal list` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` は呼ばれず、stdout は `failed 11`、exit 1

この要件の守備範囲で入力として扱うのは、`orca terminal list --worktree path:<子> --json` の出力である。出どころは、launch が直前に worktree create で作った子のワークツリーに対する Orca 自身の出力で、人が手で打つ入力ではない。拾いたい誤りは、端末の数を取り違えて端末を増やすこと（一覧が読めないのを 0 個として作る、2 個以上なのに作る）と、シェルが idle のうちに最初の指示を送ってしまうことである。通してよい入力は、`result.terminals` が配列で、要素の `handle` が空でない文字列のもの（`agentIdentity` や `title` が無い要素を含む。使い回す端末の識別には起動後の `agentIdentity`・タイトルだけを使う）、および `Terminal 1` 以外のタイトルの端末である。一覧の形が変わったときの検知は範囲外とし、読めなければ `failed` として表に出すだけにする。入力の穴を塞ぎ切ることをこの要件の完了条件としない。

### Requirement: wait --resolve は通す返事を送る前に起動し直すかを表で決める
`epic-dispatch.sh wait --resolve` の `resolve_stopped` は、判断が `通す` のとき、`reply-after-idle.md` の子の表に従って `deliver_reply` の `relaunch` を決めなければならない（MUST）。子の最後のリクエスト（トランスクリプトの最後の assistant の行の `timestamp`）から 60 分以上なら、その間の `compact_boundary` の有無と会話量によらず起動し直し（`relaunched`）、60 分未満なら今までどおり送る（`sent`）。`compact_boundary` と `subagent-context.sh` は見ない（SHALL）。トランスクリプトは、子のワークツリーのパスの英数字以外を `-` に置換した名前（Claude Code のプロジェクト名の付け方）の `${CLAUDE_PROJECTS_DIR:-~/.claude/projects}` 直下のディレクトリの `*.jsonl` で、ちょうど 1 本のときだけ使う。0 本または 2 本以上、時刻を読めない、のいずれかのときは送る（MUST）。60 分は環境変数 `EPIC_DISPATCH_RELAUNCH_IDLE_SEC`（既定 3600）で変えられ、設定された値が空か数字だけでなければ、`wait` は使い方を出して exit 1 で終わる（MUST）。`EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` は読まない（SHALL。設定されていても値を検査しない）。`tests/epic-dispatch.bats` は偽の `orca`・`gh`・トランスクリプトで次の Scenario を確かめなければならない（MUST）。

この要件の入力は、子のワークツリーの `path`（`orca worktree list --json`）、そのトランスクリプトの `timestamp`・`type`、上の環境変数である。拾いたい誤りは、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子を含む）へそのまま送って、子が手順を外れて進むことと、キャッシュが生きている 60 分未満の子を起動し直して費用を無駄にすることである。次は通してよく、この要件では止めない: 経過時間が 60 分前後で扱いが分かれる子／トランスクリプトが複数あり、そのまま送った子／PC が寝ていて、60 分未満と読めた子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

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
- **WHEN** 最後のリクエストが 60 分未満前で同じ実行をする
- **THEN** 返事は `sent` で届く

#### Scenario: 事実を読めなければそのまま送る
- **WHEN** トランスクリプトが無い、または 2 本ある
- **THEN** 返事は `sent` で届く

#### Scenario: 閾値の環境変数が数字でなければ起動しない
- **WHEN** `EPIC_DISPATCH_RELAUNCH_IDLE_SEC=1h` で `wait --resolve` を実行する
- **THEN** stderr に変数名と使い方が出て exit 1 である

#### Scenario: 会話量の環境変数は読まない
- **WHEN** `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS=150k` で、最後のリクエストが 60 分以上前の子に `wait --resolve` を実行する
- **THEN** exit 1 にならず、返事は `relaunched` で届く

## ADDED Requirements

### Requirement: 子のセッションはアイドル時のコンパクトを切って起動する
`plugins/dev-workflow/scripts/epic-dispatch.sh` が作る子の起動コマンド（`launch` と、端末が無い子・`--relaunch` の子を起動し直す `reply`）は、子のアイドル時のコンパクト（待っている間の自動コンパクト）を切る `--settings '{"idleCompaction":false}'` を含み、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を含んではならない（MUST。置く場所は要件「エピックの並列起動は 1 段で止める」）。通常の自動コンパクトを止める指定（`DISABLE_AUTO_COMPACT` など）を付けてはならない（MUST NOT）。環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` は読まない（SHALL。設定されていても値を検査せず、起動コマンドを変えない）。

#### Scenario: launch は子の起動コマンドでアイドル時のコンパクトを切る
- **WHEN** `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=400 cld --settings '{"idleCompaction":false}' --model 'opus'` で、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を含まない

#### Scenario: 閾値の上書きの変数は読まない
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=150000`、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=`、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=120k` のそれぞれの環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** どれも stdout は `launched 11`、exit 0 で、`--command` は `EPIC_DISPATCH_PARENT_EPIC=400 cld --settings '{"idleCompaction":false}' --model 'opus'` である

#### Scenario: 端末が無い子を起動し直すコマンドもアイドル時のコンパクトを切る
- **WHEN** 端末が無い子 11 に `epic-dispatch.sh reply --as owner 400 11 <返事>` を実行する
- **THEN** `orca terminal create` の `--command` は `--settings '{"idleCompaction":false}'` を含み、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を含まない

この要件の守備範囲で入力として扱うのは、`launch`・`reply` を実行したシェルの環境変数（`EPIC_DISPATCH_CLAUDE_CMD`・`EPIC_DISPATCH_MODEL`）だけである。拾いたい誤りは、子の起動コマンドにアイドル時のコンパクトを切る指定が入らず、子がコンパクトされて `SKILL.md` の中身を持たないまま進むことと、通常の自動コンパクトまで止めて子の会話が上限を越えることである。次は通してよく、この要件では止めない: 主の起動コマンド（`cld`）が子のプロセスの環境に入れる `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`（アイドル時のコンパクトを切った子では効かない）／`EPIC_DISPATCH_CLAUDE_CMD` が `--settings` を `claude` に渡さない形で、指定が効かなかった子／Claude Code が v2.1.290 より古く、指定が効かなかった子／この変更より前に起動され、従来の閾値で動いている子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

### Requirement: 時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める
時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、子について次を書かなければならない（MUST）: 子は `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること（そのプロセスだけに効き通常の自動コンパクトは止めない・v2.1.290 以降が要る・`~/.claude/settings.json` に置かない）。分ける条件は、端末が無ければ起動し直す、最後のリクエストから 60 分未満ならそのまま送る、60 分以上ならコンパクトの有無と会話量によらず起動し直す。根拠は、コンパクトされた子は `SKILL.md` の中身を持たずに進むことと、費用の差の小ささ。

#### Scenario: 規則のファイルに子の切り方と分ける条件と根拠が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 子は `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること、`settings.json` に置かないこと、子は端末が無い・60 分以上なら起動し直し 60 分未満ならそのまま送ること、子を起動し直す根拠（コンパクトされた子は `SKILL.md` の中身を持たない）と #1039 の決定を #1323 で覆したこと、判定に使う事実（端末の有無は `epic-dispatch.sh reply` が確かめること・最後のリクエストの時刻はトランスクリプトから読むこと）が書かれている

根拠には、2026-10-23 の子のログで、コンパクトのあとに残ったのが `SKILL.md` のファイル名と `/develop` の入口だけで、再開したあとも読み直さずにゲートの実行まで進んでいたことと、起動し直しとの費用の差（1 回あたり Opus 5.5 で約 $0.5）、1 時間以上たってから返事が来る子の割合（3.2%）を書く（SHALL）。判定に使う事実は、子の端末の有無（`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）と、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻である。送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順（develop の `references/epic.md` の Orca 経路と `epic-dispatch.sh reply`）が書き、このファイルを参照する）。

この分類は、`epic-dispatch.sh wait --resolve` が親の代わりに通す返事を除き、スクリプトではなく本体が規則のファイルを読んで行う。`wait --resolve` が通す返事は、要件「wait --resolve は通す返事を送る前に起動し直すかを表で決める」のとおり `resolve_stopped` が同じ子の表で分類する（例外）。拾いたい誤りは、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子と、この変更より前に起動されてコンパクトされうる子を含む）にそのまま返事を送り、子が手順を外れて進むことと、60 分未満の子を起動し直して、子が積んだ判断と起動し直しの費用を無駄にすることである。次は通してよく、この分類では止めない: 経過時間がちょうど 60 分前後で、時刻の読み方によって扱いが分かれる子／トランスクリプトが複数あってどれが子のセッションか分からず、そのまま送った子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

### Requirement: 親が長く待ったあとは親の表で続けるか起動し直すかを決める
`plugins/dev-workflow/skills/develop/references/reply-after-idle.md` は、親（エピックを回すセッション）について次を書かなければならない（MUST）: 親の閾値は 120,000 で、主の起動コマンド（例: `cld`）が値の未設定のときだけ入れ、`~/.claude/settings.json` の `env` に置かないこと（個人の設定ファイルのパスは書かない）。親の表は、最後のリクエストから 60 分未満ならそのまま続ける、60 分以上でコンパクトが走っていればそのまま続ける、走っていなければ会話量 N が 150,000 以上なら起動し直し未満なら続ける。親を子と分ける理由と、親の状態の復元元。

#### Scenario: 規則のファイルに親の値と表と復元元が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 親は 120,000 で主の起動コマンドが未設定のときだけ入れて `settings.json` に置かないこと、親の表がコンパクトの有無と N が 150,000 以上か未満で分けること、会話量を `subagent-context.sh --file` で測ること、親を子と分ける理由、親の状態の復元（親が通した判断を含む）、hook が `SKILL.md` の読み直しを差し込むこととその費用 1 回約 39k と #1264 で計算し直すこと、1〜2 週間後の再集計が書かれている

親を子と分ける理由は、親の監視の `wait` はコンパクトのあとも動き続けて通知を受けた親はそのまま作業を続けられ、起動し直すと監視が途切れることである（SHALL。書く）。親の状態のうち、回し方（`回し方:`）・終わった子（`子 #N マージ → 残り k 件` / `子 #N 見送り`）・外した子エピック（`後で別に起動するエピック:`）・残したワークツリー（`子 #N のワークツリーを残した`）・親が通した判断（`親の判断: 子 #N 通した`）はエピックのコメントから、残りの子は依存グラフと子 issue の状態から復元できると書く（SHALL）。根拠と限りとして、#1039 の集計コメントの URL と要点（返事の直前の会話の中央値、起動し直しの費用、閾値ごとの費用の増減）、実績の少なさと PC が寝ているとコンパクトが走らないこと、コンパクトのあと develop を呼んでいた会話には SessionStart の hook（`scripts/develop-compact-reread.sh`）が `SKILL.md` の読み直しを差し込むことと、その費用（1 回約 39k トークン）、両方を足した想定は計算し直しておらず #1264 で計算すること（#1217 の計算コメントの URL）を書く（SHALL）。再集計は、1〜2 週間回したあとに親の同じ集計をやり直して #1039 にコメントし、値を見直す。件数・金額は合否に使わず記録する。

この要件の守備範囲で入力として扱うのは、親のセッションのトランスクリプトの最後のリクエストの時刻とそのあとの `compact_boundary` の有無、`plugins/dev-workflow/scripts/subagent-context.sh --file` で測った会話量 N である。拾いたい誤りは、PC が寝ていてコンパクトが走らなかった 150,000 トークン以上の親の会話をそのまま続けて会話全体を書き込み直すことと、コンパクトが走った親や 60 分未満の親を起動し直して監視を途切れさせることである。次は通してよく、この要件では止めない: 経過時間が 60 分前後、N が 150,000 前後で扱いが分かれる場合／主の起動コマンドが値を入れず、既定のまま動く親。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

### Requirement: epic.md の回し方は子の起動コマンドの指定と返事の規則のファイルを指す
develop の `references/epic.md`「エピックの扱い」の「回し方」は、子セッションの起動コマンドに `--settings '{"idleCompaction":false}'` が付いて子のアイドル時のコンパクトが切られることと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で「そのまま送る」か「起動し直す」かを決めることを書かなければならない（MUST）。子の起動コマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が付く、または `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` で変えられるとは書かない（MUST NOT）。`plugins/dev-workflow/tests/epic-dispatch.bats` はこの記述と、上の 3 つの要件の規則のファイルの記述を確かめなければならない（MUST）。

#### Scenario: epic.md の回し方が起動コマンドの指定と規則のファイルを指す
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** 子の起動コマンドに `--settings '{"idleCompaction":false}'` が付くことと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で決めることが書かれていて、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` と `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` は書かれていない

## REMOVED Requirements

### Requirement: 時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める
**Reason**: 子のアイドル時のコンパクトを閾値 120,000 で走らせ、コンパクトされた子にはそのまま返事を送るという #1039 の決定を #1323 で覆した。コンパクトされた子は develop の `SKILL.md` の中身を持たずに進むため。
**Migration**: 子の起動コマンドは要件「子のセッションはアイドル時のコンパクトを切って起動する」、子への返事の分け方は要件「時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める」、親の閾値と表と復元は要件「親が長く待ったあとは親の表で続けるか起動し直すかを決める」、`references/epic.md` の記述は要件「epic.md の回し方は子の起動コマンドの指定と返事の規則のファイルを指す」に移した。`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` は読まれなくなるので、設定している呼び出し元は外す。
