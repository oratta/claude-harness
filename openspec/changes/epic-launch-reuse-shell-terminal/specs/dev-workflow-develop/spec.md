## MODIFIED Requirements

### Requirement: epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` を持たなければならない（MUST）。どのサブコマンドも LLM を呼んではならない（MUST NOT）。

`route <child>...` は、引数の子が 1 件以上あり、`orca` コマンドが PATH にあり、かつ `orca worktree current` が exit 0 で終わる（今いるディレクトリが Orca 管理のワークツリー）ときだけ stdout に `orca` の 1 行を出し、それ以外は `subagent` の 1 行を出して exit 0 で終わらなければならない（MUST）。子の番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。

`launch [--note <text>] [--base <branch>] <epic> <child>...` は、次の順で呼び出さなければならない（MUST）: `orca worktree current --json`（今の repo の `repoId` を得る）→ `git rev-parse --show-toplevel` → `git fetch origin <base>` → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` → 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --json` → 子の端末を用意する（`orca terminal list --worktree path:<子> --json` で端末を数え、0 個のときだけ `orca terminal create --worktree path:<子> --command <cmd> --json` で作る。ちょうど 1 つのときは作らずにその端末を使う。詳細は要件「launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ」）→ `orca terminal wait --terminal <handle> --for tui-idle --timeout-ms <ready> --json` → `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json`。worktree create に `--agent` と `--prompt` を渡してはならない（MUST NOT。`--agent` で起動すると子セッションのモデルを指定できず Claude Code の既定モデルで動くため。`--prompt` は Orca 1.4.209 では指示が子の入力欄に届かず、送信と併用すると指示が 2 回届くおそれがあるため）。`<子>` は worktree create の JSON 出力の `result.worktree.path` とする（MUST）。`<cmd>` は `<claude-cmd> --model <model>` で（`--dangerously-skip-permissions` などの許可に関わる引数は付けてはならない（MUST NOT）。付けるのは `<claude-cmd>` 側に任せる）、`<claude-cmd>` の既定は `cld` で環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で変えられ、クォートせずそのまま置く（MUST。`--command` の文字列は Orca が開いたログインシェルに打ち込まれるのでシェル関数も解決され、`cld-account b` のような引数付きも書けるため）。`<model>` はシェルに打ち込まれても 1 語のまま渡るよう単一引用符で囲む（MUST。`opus[1m]` のような値がグロブとして解釈されないため）。`<model>` の既定は `opus` で、環境変数 `EPIC_DISPATCH_MODEL` で変えられる（MUST）。`<handle>` は、端末を作ったときは terminal create の JSON 出力の `result.terminal.handle`、使い回したときはその端末のハンドルとする（MUST）。`<ready>` の既定は 60000（ミリ秒）で環境変数 `EPIC_DISPATCH_READY_TIMEOUT_MS` で、`<submit>` の既定は 30（秒）で環境変数 `EPIC_DISPATCH_SUBMIT_WAIT` で変えられる（SHALL）。`<親>` は `git rev-parse --show-toplevel` で求めた親ワークツリーの絶対パスで、親の指定は create と set の両方で `path:` を使わなければならない（MUST。`worktree:<id>` は set で `selector_not_found` になるため）。`<base>` の既定は `main` で、環境変数 `EPIC_DISPATCH_BASE` で既定を変えられ、`--base` が環境変数より優先する（MUST）。`<prompt>` は `/develop #<N>` で始まり、エピック番号を含み、`--note` があればその文を含む（SHALL）。子を `launched <N>` とするのは、worktree create が exit 0 で終わり、子のワークツリーのパスが取れ、端末を用意でき（terminal create が exit 0 で終わりハンドルが取れた、または使い回した端末が Claude Code になった）、`terminal wait` が exit 0 で終わり、`terminal send` が exit 0 で終わってその JSON 出力のどこかの `stages` 配列に `turn_started` が含まれるときだけでなければならない（MUST）。どれか 1 つでも満たさなければ `failed <N>` とし（MUST）、子のワークツリーのパスが取れていて、端末を作る経路でハンドルが取れていなければ（terminal create の失敗を含む）、端末を手で起動し直すための `orca terminal create --worktree path:<子> --command <cmd> --json` を stderr に出すに続けて、最初の指示を送るための `orca terminal send --terminal <作り直した端末のハンドル> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出す（SHALL。ワークツリーは残るので、再実行ではその子は `skipped <N>` になり端末が作られないため）。ハンドルが取れていれば、指示を手で送り直すための `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出し、あわせて「送る前に `orca terminal read --terminal <handle>` で入力欄とターンの状態を確かめる」旨の案内を出す（SHALL。送信が非 0 やターン未観測で終わっても指示が届いていることがあり、確かめずに送ると 2 回届くため）。`terminal send` の JSON 出力に送り直し用の ID（キー `retryRequestId` または `retryRequest` の文字列値）があれば、送り直しのコマンドに `--retry-request <id>` を付ける（SHALL）。ワークツリーは残すので、再実行ではその子は `skipped <N>` になり、指示を送り直さない（SHALL）。一覧に、同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出さなければならない（MUST。再開時や取り違えで同じ子を二重に起動しないため）。`orca` が PATH に無いときは何も呼ばずに exit 1 で終わり、`orca worktree current`・`git fetch`・`orca worktree set`・`orca worktree list` のどれかが失敗したとき（`jq` が無くて一覧を読めないときを含む）は子を 1 件も作らずに exit 1 で終わらなければならない（MUST）。stdout には子ごとに `launched <N>`・`skipped <N>`・`failed <N>` のどれか 1 行だけを出し、`orca` 自身の出力は stderr に流す（SHALL）。1 件の失敗で残りの子の起動を止めず、`failed` が 0 件なら exit 0、1 件でもあれば exit 1 で終わる（MUST）。

`wait [--interval <sec>] [--timeout <sec>] <child>...` は、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` で state を確かめるポーリングを繰り返し、stdout にちょうど 1 行を出して終わらなければならない（MUST）。子ごとの結果は、出力が `closed` なら閉じている、`open` なら開いている、`gh` が非 0 で終わったか出力がそれ以外（空文字を含む）なら失敗とする（MUST）。1 件以上の子が閉じていれば `closed <N>...`（閉じていた子の番号）で exit 0、上限時間に達したら `timeout <N>...`（閉じていない子の番号）で exit 2、失敗したポーリングが 3 回続いたら `error gh <N>...`（3 回目で失敗した子の番号）で exit 1 で終わる（MUST）。失敗したポーリングとは、1 件以上の子が失敗し、かつ閉じた子が 1 件も無いポーリングを言い、一部の子だけが失敗してほかの子が `open` の場合も含む（MUST）。失敗の無いポーリングがあれば数え直す（SHALL）。閉じた子がいるポーリングでは、ほかの子の失敗より `closed` を優先する（SHALL）。間隔と上限は秒で、既定は間隔 300・上限 21600、環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する（MUST）。ポーリングのあとで経過時間が上限に達しているか、経過時間と間隔の和が上限を超えるなら、眠らずに `timeout` で終わる（MUST。`--timeout 0` は間隔によらず 1 回だけ確かめて終わる）。子が 0 件、番号が数字でない、間隔・上限が非負整数でないときは stderr に使い方を出して exit 1 で終わる（SHALL）。

この要件の守備範囲で入力として扱うのは、本体（LLM）が依存グラフから求めた子の番号と、SKILL.md の手順どおりに付けるフラグである。人が手で打つことは想定しない。引数の検査で拾う誤りは、番号の取り違えで引数が空になること、`#12` のように番号に記号が付くこと、フラグ値の打ち間違いである。数字でさえあれば、存在しない issue 番号・重複した番号・blocked されている子の番号は通してよく（`route` は依存を検証しない。存在しない番号は `wait` の失敗したポーリングとして数えられ `error` で表に出る）、非常に大きい `--timeout` も通してよい。検査をすり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。`EPIC_DISPATCH_READY_TIMEOUT_MS` と `EPIC_DISPATCH_SUBMIT_WAIT` は非負の整数でなければ stderr に使い方を出し、子を 1 件も作らずに exit 1 で終わる（SHALL。`--interval` と同じ扱いで、上限は設けない）。`EPIC_DISPATCH_MODEL` か `EPIC_DISPATCH_CLAUDE_CMD` が設定されていて空文字のときも stderr に使い方を出し、子を 1 件も作らずに exit 1 で終わる（SHALL。空でない値はそのまま使い、モデル名やコマンドとしての正しさは検査しない）。worktree create の JSON 出力の `result.worktree.path` と terminal create の JSON 出力の `result.terminal.handle` は 2026-09-25 の実機での出力の形のとおりと信じ、`terminal send` の JSON 出力の `stages` 配列と `turn_started` の語は、2026-09-24 の実機での出力の形のとおりと信じ、読めないときは `failed` として表に出すだけで、形の変化そのものの検知は範囲外とする。`orca worktree list --json` の出力は確かめた形（`.result.worktrees[]` の `repoId`・`linkedIssue`・`isArchived`）のとおりと信じ、形が変わったときの検知は範囲外とする。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、呼び出しの引数と順序、stdout の 1 行と exit code を確かめなければならない（MUST）。テストの途中に素の `[[ ]]` を置いてはならない（MUST NOT。bash 3.2 では偽でも素通りする）。

#### Scenario: orca が無い環境ではサブエージェント方式になる
- **WHEN** `orca` が PATH に無い環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: orca はあるが Orca 管理外のワークツリーならサブエージェント方式になる
- **WHEN** `orca` が PATH にあり `orca worktree current` が exit 1 を返す環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: 並列にできる子が 2 件でも Orca 管理下なら Orca 経路になる
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: launch は fetch してから path: で親を渡して子を作る
- **WHEN** 一覧に子のワークツリーが無く、子のワークツリーの端末が 0 個のスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 呼び出しの記録は `orca worktree current --json`、`git rev-parse --show-toplevel`、`git fetch origin main`、`orca worktree set --worktree path:<親> --issue 400`、`orca worktree list --json`、子ごとに `orca worktree create`（`--name issue-<N> --issue <N> --base-branch origin/main --parent-worktree path:<親> --json`。`--agent` も `--prompt` も含まない）、`orca terminal list --worktree path:<子> --json`、`orca terminal create --worktree path:<子> --command "cld --model 'opus'" --json`、`orca terminal wait --terminal <handle> --for tui-idle`、`orca terminal send --terminal <handle> --text "/develop #<N> ..." --enter --wait-submit 30 --json` を子 11・子 12 の順に繰り返し、stdout は `launched 11` と `launched 12`、exit 0

#### Scenario: 子セッションのモデルを環境変数で変えられる
- **WHEN** `EPIC_DISPATCH_MODEL='opus[1m]'` のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `cld --model 'opus[1m]'`、stdout は `launched 11`、exit 0

#### Scenario: モデルの環境変数が空なら子を作らない
- **WHEN** `EPIC_DISPATCH_MODEL=` （空文字）のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca worktree create` は呼ばれず、exit 1

#### Scenario: 起動コマンドを環境変数でそのまま差し替えられる
- **WHEN** `EPIC_DISPATCH_CLAUDE_CMD='cld-account b'` のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `cld-account b --model 'opus'`、stdout は `launched 11`、exit 0

#### Scenario: 起動コマンドの環境変数が空なら子を作らない
- **WHEN** `EPIC_DISPATCH_CLAUDE_CMD=` （空文字）のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca worktree create` は呼ばれず、exit 1

#### Scenario: 端末を作れなければ送らずに failed で端末の作り直しのコマンドを出す
- **WHEN** 子 11 の `orca terminal create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 子 11 には `orca terminal wait` も `orca terminal send` も呼ばれず、stderr には子 11 のワークツリーのパスと `cld --model` を含む `orca terminal create` のコマンドと、`/develop #11` を含む `orca terminal send` のコマンドが出て、stdout は `failed 11` と `launched 12`、exit 1

#### Scenario: ハンドルが取れなければ送らずに failed
- **WHEN** 子 11 の terminal create の JSON 出力に `result.terminal.handle` が無いスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 子 11 には `orca terminal wait` も `orca terminal send` も呼ばれず、stdout は `failed 11` と `launched 12`、exit 1

#### Scenario: 子のワークツリーのパスが取れなければ端末を作らずに failed
- **WHEN** 子 11 の worktree create の JSON 出力に `result.worktree.path` が無いスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** 子 11 には `orca terminal create` が呼ばれず、stdout は `failed 11`、exit 1

#### Scenario: 送信が失敗したら failed で送り直しのコマンドを出す
- **WHEN** 子 11 の `orca terminal send` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** stdout は `failed 11` と `launched 12`、stderr には子 11 のハンドルと `/develop #11` を含む `orca terminal send` のコマンドが出て、exit 1

#### Scenario: 送り直し用の ID があれば送り直しのコマンドに付ける
- **WHEN** 子 11 の `orca terminal send` が非 0 で終わり、JSON 出力に `retryRequestId` の値 `rq-1` があるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stdout は `failed 11`、stderr の送り直しのコマンドに `--retry-request rq-1` が付き、`orca terminal read` で確かめる案内が出て、exit 1

#### Scenario: 時間の環境変数が整数でなければ子を作らない
- **WHEN** `EPIC_DISPATCH_SUBMIT_WAIT=abc` のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca worktree create` は呼ばれず、exit 1

#### Scenario: ターンの開始を確かめられなければ failed
- **WHEN** 子 11 の `orca terminal send` が exit 0 で終わるが、JSON 出力の `stages` に `turn_started` が無い（`input_accepted` だけ）スタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stdout は `failed 11`、exit 1

#### Scenario: 起動完了待ちが失敗したら送らずに failed
- **WHEN** 子 11 の `orca terminal wait` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** 子 11 に `orca terminal send` は呼ばれず、stdout は `failed 11`、exit 1

#### Scenario: 起動完了待ちと送信の観測時間を環境変数で変えられる
- **WHEN** `EPIC_DISPATCH_READY_TIMEOUT_MS=5000`・`EPIC_DISPATCH_SUBMIT_WAIT=7` のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal wait` は `--timeout-ms 5000`、`orca terminal send` は `--wait-submit 7` で呼ばれる

#### Scenario: 起点のブランチを変えられる
- **WHEN** `EPIC_DISPATCH_BASE=develop` のスタブ環境で `epic-dispatch.sh launch --base trunk 400 11` を実行する
- **THEN** `git fetch origin trunk` と `--base-branch origin/trunk` で呼ばれる

#### Scenario: 起動済みの子は作らない
- **WHEN** 一覧に同じ `repoId` で `linkedIssue` が 11 の archive されていないワークツリーがあるスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 子 11 の `orca worktree create` は呼ばれず、stdout は `skipped 11` と `launched 12`、exit 0

#### Scenario: fetch に失敗したら子を作らない
- **WHEN** `git fetch` が失敗するスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `orca worktree create` は 1 回も呼ばれず、exit 1

#### Scenario: orca が無い環境では launch は何も呼ばない
- **WHEN** `orca` が PATH に無い環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `git` も `gh` も呼ばれず、exit 1

#### Scenario: 子が閉じたら closed で終わる
- **WHEN** 子 12 が 2 回目のポーリングから `closed` を返すスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11 12` を実行する
- **THEN** stdout は `closed 12` の 1 行で exit 0

#### Scenario: 上限時間に達したら timeout で終わる
- **WHEN** どの子も `open` を返すスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 0 11 12` を実行する
- **THEN** stdout は `timeout 11 12` の 1 行で exit 2

#### Scenario: 間隔は sleep に渡される
- **WHEN** 3 回目のポーリングで子が閉じるスタブ環境で `epic-dispatch.sh wait --interval 7 --timeout 100 11` を実行する
- **THEN** `sleep 7` が 2 回呼ばれ、stdout は `closed 11` で exit 0

#### Scenario: gh が失敗し続けたら error で終わる
- **WHEN** `gh` が常に失敗するスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11` を実行する
- **THEN** 3 回のポーリングのあと stdout は `error gh 11` の 1 行で exit 1

#### Scenario: 一部の子だけが失敗し続けても error で終わる
- **WHEN** 子 11 の `gh` が常に失敗し、子 12 は常に `open` を返すスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11 12` を実行する
- **THEN** 3 回のポーリングのあと stdout は `error gh 11` の 1 行で exit 1

## ADDED Requirements

### Requirement: launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子ごとに `orca worktree create` が終わったあと、`orca terminal list --worktree path:<子> --json` で端末を数えなければならない（MUST。Orca は worktree create で空のシェルの端末を 1 つ作り、`orca terminal create` で 2 つ目を作ると子の端末が 2 つになって、`reply` が `ambiguous-terminal` で止まるため）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の launch の呼び出し順のうち、端末を用意する段の中身を定める（その要件の本文はこの変更で端末を用意する段を条件付きに直してある）。それ以外の規定（起動コマンドの形・環境変数・`terminal wait`・`terminal send`・`launched`/`failed` の判定）は変えない。

- 端末がちょうど 1 つなら、`orca terminal create` を呼ばず、その端末のハンドルに `orca terminal send --terminal <handle> --text <cmd> --enter --json` で起動コマンド `<cmd>`（従来 `--command` に渡していた文字列と同じ）を打ち込む（MUST）。続けて `orca terminal list --worktree path:<子> --json` を引き直し、その端末が Claude Code（`agentIdentity` が `claude`、無ければタイトルに `Claude Code` を含む）になるのを待つ（MUST。シェルは起動コマンドを打つ前から idle で、すぐ `terminal wait` を呼ぶと最初の指示がシェルに入るため）。待つ上限は `EPIC_DISPATCH_READY_TIMEOUT_MS` を秒にした値（最低 1 回）とする。Claude Code になったら、その端末のハンドルで `terminal wait --for tui-idle` と指示の `terminal send` へ進む（MUST）
- 端末が 0 個なら、従来どおり `orca terminal create` で作る（MUST。worktree create が端末を作らない版の後方互換）
- 一覧を読めない・端末が 2 個以上・起動コマンドを打ち込めない・待っても Claude Code にならない、のいずれかなら、その子を `failed <N>` とし、`orca terminal create` を呼ばない（MUST。端末を増やすと二重起動の原因になるため）。stderr に理由と、確認または続きを手で行うコマンド（`orca terminal list --worktree path:<子> --json`、`orca terminal read --terminal <handle>`、打ち込めなかった起動コマンド）を出す（SHALL）

#### Scenario: worktree create が作ったシェルの端末で子のセッションが起動し、端末は 1 つのまま
- **WHEN** 子 11 のワークツリーに空のシェルの端末（`term-11`、`agentIdentity` なし）が 1 つあり、起動コマンドが届いたあとは同じ端末が `agentIdentity: claude` になるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` は呼ばれず、`orca terminal send --terminal term-11` が 2 回（1 回目は `EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'` を含む `--enter --json`、2 回目は `/develop #11` を含む指示）、`orca terminal wait --terminal term-11 --for tui-idle` が 1 回呼ばれ、stdout は `launched 11`、exit 0

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
