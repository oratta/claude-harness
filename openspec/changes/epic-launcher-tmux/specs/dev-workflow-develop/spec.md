## RENAMED Requirements

- FROM: `### Requirement: 着手できる子が 1 件でも Orca 経路で回す`
- TO: `### Requirement: 着手できる子が 1 件でも別セッション方式で回す`

## MODIFIED Requirements

### Requirement: epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` を持たなければならない（MUST）。どのサブコマンドも LLM を呼んではならない（MUST NOT）。

`route <child>...` は stdout にちょうど 1 行を出して exit 0 で終わらなければならない（MUST）。判定は次の順で、最初に当たったものを出す: (1) エピックの子のセッション（環境変数 `EPIC_DISPATCH_PARENT_EPIC` があるか、今のワークツリーを `worktree` に持つ状態の記録がある）なら `nested`、(2) 引数の子が 0 件なら `subagent`、(3) 環境変数 `EPIC_DISPATCH_LAUNCHER` が `orca` か `tmux` ならその値（部品が使えるかを確かめ、使えなければ stderr に理由を出して `subagent`）、(4) Orca の部品の `here` が exit 0（`orca` が PATH にあり、今いるディレクトリが Orca 管理のワークツリー）なら `orca`、(5) 環境変数 `TMUX` が空でなく `tmux` コマンドが PATH にあれば `tmux`、(6) それ以外は `subagent`。`EPIC_DISPATCH_LAUNCHER` が `orca`・`tmux`・空のどれでもなければ stderr に使い方を出して exit 1 で終わる。子の番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。`launch` と `adopt` は、同じ順の (3)〜(5) で使う起動部品を決め、決められなければ exit 1 で終わる。

`launch [--note <text>] [--base <branch>] <epic> <child>...` は、次の順で呼び出さなければならない（MUST）: `orca worktree current --json`（今の repo の `repoId` を得る）→ `git rev-parse --show-toplevel` → `git fetch origin <base>` → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` → 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --json` → 子の端末を用意する（`orca terminal list --worktree path:<子> --json` で端末を数え、0 個のときだけ `orca terminal create --worktree path:<子> --command <cmd> --json` で作る。ちょうど 1 つのときは作らずにその端末を使う。詳細は要件「launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ」）→ `orca terminal wait --terminal <handle> --for tui-idle --timeout-ms <ready> --json` → `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json`。worktree create に `--agent` と `--prompt` を渡してはならない（MUST NOT。`--agent` で起動すると子セッションのモデルを指定できず Claude Code の既定モデルで動くため。`--prompt` は Orca 1.4.209 では指示が子の入力欄に届かず、送信と併用すると指示が 2 回届くおそれがあるため）。`<子>` は worktree create の JSON 出力の `result.worktree.path` とする（MUST）。`<cmd>` は `<claude-cmd> --model <model>` で（`--dangerously-skip-permissions` などの許可に関わる引数は付けてはならない（MUST NOT）。付けるのは `<claude-cmd>` 側に任せる）、`<claude-cmd>` の既定は `cld` で環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で変えられ、クォートせずそのまま置く（MUST。`--command` の文字列は Orca が開いたログインシェルに打ち込まれるのでシェル関数も解決され、`cld-account b` のような引数付きも書けるため）。`<model>` はシェルに打ち込まれても 1 語のまま渡るよう単一引用符で囲む（MUST。`opus[1m]` のような値がグロブとして解釈されないため）。`<model>` の既定は `opus` で、環境変数 `EPIC_DISPATCH_MODEL` で変えられる（MUST）。`<handle>` は、端末を作ったときは terminal create の JSON 出力の `result.terminal.handle`、使い回したときはその端末のハンドルとする（MUST）。`<ready>` の既定は 60000（ミリ秒）で環境変数 `EPIC_DISPATCH_READY_TIMEOUT_MS` で、`<submit>` の既定は 30（秒）で環境変数 `EPIC_DISPATCH_SUBMIT_WAIT` で変えられる（SHALL）。`<親>` は `git rev-parse --show-toplevel` で求めた親ワークツリーの絶対パスで、親の指定は create と set の両方で `path:` を使わなければならない（MUST。`worktree:<id>` は set で `selector_not_found` になるため）。`<base>` の既定は `main` で、環境変数 `EPIC_DISPATCH_BASE` で既定を変えられ、`--base` が環境変数より優先する（MUST）。`<prompt>` は `/develop #<N>` で始まり、エピック番号を含み、`--note` があればその文を含む（SHALL）。子を `launched <N>` とするのは、worktree create が exit 0 で終わり、子のワークツリーのパスが取れ、端末を用意でき（terminal create が exit 0 で終わりハンドルが取れた、または使い回した端末が Claude Code になった）、`terminal wait` が exit 0 で終わり、`terminal send` が exit 0 で終わってその JSON 出力のどこかの `stages` 配列に `turn_started` が含まれるときだけでなければならない（MUST）。どれか 1 つでも満たさなければ `failed <N>` とし（MUST）、子のワークツリーのパスが取れていて、端末を作る経路でハンドルが取れていなければ（terminal create の失敗を含む）、端末を手で起動し直すための `orca terminal create --worktree path:<子> --command <cmd> --json` を stderr に出すに続けて、最初の指示を送るための `orca terminal send --terminal <作り直した端末のハンドル> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出す（SHALL。ワークツリーは残るので、再実行ではその子は `skipped <N>` になり端末が作られないため）。端末を用意できたあと（`terminal wait` か `terminal send` の段）で失敗し、ハンドルが取れていれば、指示を手で送り直すための `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出し、あわせて「送る前に `orca terminal read --terminal <handle>` で入力欄とターンの状態を確かめる」旨の案内を出す（SHALL。送信が非 0 やターン未観測で終わっても指示が届いていることがあり、確かめずに送ると 2 回届くため）。`terminal send` の JSON 出力に送り直し用の ID（キー `retryRequestId` または `retryRequest` の文字列値）があれば、送り直しのコマンドに `--retry-request <id>` を付ける（SHALL）。ワークツリーは残すので、再実行ではその子は `skipped <N>` になり、指示を送り直さない（SHALL）。一覧に、同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出さなければならない（MUST。再開時や取り違えで同じ子を二重に起動しないため）。`orca` が PATH に無いときは何も呼ばずに exit 1 で終わり、`orca worktree current`・`git fetch`・`orca worktree set`・`orca worktree list` のどれかが失敗したとき（`jq` が無くて一覧を読めないときを含む）は子を 1 件も作らずに exit 1 で終わらなければならない（MUST）。stdout には子ごとに `launched <N>`・`skipped <N>`・`failed <N>` のどれか 1 行だけを出し、`orca` 自身の出力は stderr に流す（SHALL）。1 件の失敗で残りの子の起動を止めず、`failed` が 0 件なら exit 0、1 件でもあれば exit 1 で終わる（MUST）。

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


### Requirement: 着手できる子が 1 件でも別セッション方式で回す
`plugins/dev-workflow/scripts/epic-dispatch.sh` の `route` は、エピックの子のセッションでなく（`nested` でなく）、子の番号が 1 件以上あるときは、子の件数が何件でも、起動部品が使えれば `orca` か `tmux` を出さなければならない（MUST。順は要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `route` の段落のとおり）。子が 0 件のとき、起動部品が使えないときは `subagent` を出す。`nested` の判定が先に行われること、`orca worktree current` を 1 回の `route` で 1 回だけ呼ぶこと、子の番号が数字でなければ exit 1 で終わることは変えない。develop の SKILL.md「エピックの扱い」の「経路の決め方」は、`orca` になる条件として子の件数の下限（2 件以上など）を書いてはならない（MUST NOT）。着手できる子が 0 件のとき `subagent` になることと、エピックの子のセッションでは件数によらず `nested` になることは、`route` の実際の結果の説明として書いてよい。

経路は `/develop <エピック番号>` の最初の開始時に 1 回決めて途中で変えず、再開時は `回し方:` で始まる最新のコメントから引き継ぎ、すでに `回し方: サブエージェント` と記録したエピックを途中で 別セッション方式に切り替える規則は置かない（SHALL。進行中のサブエージェント方式の子と 起動部品の子ワークツリーの子が混在する状態を扱う規則が無く、別セッション方式の手順の規定は別の変更が扱うため）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」の `route` が `orca` を返す条件の規定、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `route` の判定の規定、要件「エピックの子への注意書きと…引き継ぐ」の `route` の段落のうち、子の件数の条件に関わる部分に優先する。

この要件の守備範囲で入力として扱うのは、本体が依存グラフから求めた子の番号の並びと、`orca` の有無・`orca worktree current` の終了コードである。この要件で新しく拾う誤りは無く、引数の検査（数字でない番号を exit 1 で止めること）は既存の要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」が受け持つ。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。次は通してよく、この要件では止めない: 存在しない・重複した・blocked されている子の番号は `route` では検証しない（既存の規定どおり）／この変更より前に `回し方: サブエージェント` と記録した進行中のエピックは、そのエピックが終わるまでサブエージェント方式のまま進む。

#### Scenario: Orca 管理のワークツリーで子が 1 件なら orca を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: 子が 2 件でも今までどおり orca を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: 子が 1 件でも orca が無い・Orca 管理外ならサブエージェント方式になる
- **WHEN** `orca` が PATH に無い環境と、`orca` が PATH にあり `orca worktree current` が exit 1 を返す環境のそれぞれで `epic-dispatch.sh route 11` を実行する
- **THEN** どちらも stdout は `subagent` の 1 行で exit 0

#### Scenario: 子が 0 件なら Orca 管理下でも subagent を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route` を子なしで実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: nested の判定は子が 1 件でも先に行われる
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `orca` が PATH にあり Orca 管理のワークツリーにいるとき、`epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `nested` の 1 行で exit 0、`orca` は呼ばれない

#### Scenario: SKILL.md の経路の決め方に orca になる条件としての件数の下限が書かれていない
- **WHEN** `skills/develop/SKILL.md` の「エピックの扱い」の「経路の決め方」を読む
- **THEN** `orca` になる条件が「`orca` が PATH にあり、本体が Orca 管理のワークツリーにいる」だけで書かれ、`orca` になる条件として blocked されていない子の件数の下限（2 件以上など）が無く（着手できる子が 0 件のとき `subagent` になる旨の文はあってよい）、経路は最初の開始時に 1 回だけ決めて途中で変えないこと、再開時は `回し方:` のコメントから引き継ぐことは残っている


#### Scenario: Orca 管理外でも tmux の中なら tmux を返す
- **WHEN** `orca` が PATH に無く、環境変数 `TMUX` が空でなく、`tmux` が PATH にある環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `tmux` の 1 行で exit 0

#### Scenario: Orca 管理下かつ tmux の中なら orca が先
- **WHEN** Orca 管理のワークツリーにいて、環境変数 `TMUX` も空でない環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `orca` の 1 行である

#### Scenario: 環境変数で部品を固定できる
- **WHEN** Orca 管理のワークツリーにいて `TMUX` も空でない環境で、`EPIC_DISPATCH_LAUNCHER=tmux` を付けて `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `tmux` の 1 行である。`EPIC_DISPATCH_LAUNCHER=orca` で Orca 管理外なら `subagent`、`EPIC_DISPATCH_LAUNCHER=zellij` なら stderr に使い方が出て exit 1 である

#### Scenario: tmux の外ならサブエージェント方式になる
- **WHEN** `orca` が PATH に無く、環境変数 `TMUX` が空の環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `subagent` の 1 行である


### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
SKILL.md は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。

**回し方（経路の決め方）**: interactive の本体は子の依存グラフを読み、blocked されていない子の番号を `plugins/dev-workflow/scripts/epic-dispatch.sh route` に渡して経路を決める（MUST）。`route` が `orca` か `tmux` を返したとき（Orca 管理のワークツリーにいる、または tmux の中にいる）は、その起動部品で子を別のセッションとして起こす **別セッション方式**、`subagent` を返したときは **サブエージェント方式**で進める（MUST）。別セッション方式とサブエージェント方式は二本立てではなく、子を起こす手段を起動部品として差し替える一本の手順で書く（MUST。共通の手順に、部品ごとに違う点だけを部品ごとの欄に書く）。経路は `/develop <エピック番号>` の最初の開始時に 1 回決め、途中で変えてはならず（MUST NOT）、決めた経路をエピックに `回し方:` で始まる 1 行コメントで残す（MUST）。別セッションで同じエピックを再開したときは、`回し方:` で始まる最新のコメントを読んで経路を引き継ぎ、`route` をやり直してはならない（MUST NOT）。unmanned（`--unmanned`）では `route` を呼ばず、サブエージェント方式で進める（MUST。背景で待って起こされる動きが 1 サイクル 1 仕事と合わないため）。channel でも `route` を呼ばず、サブエージェント方式で進め、エピックに `回し方: サブエージェント（channel モード）` を残す（MUST）。channel で再開したエピックの最新の `回し方:` が別セッション方式（Orca・tmux）なら、`launch` もサブエージェント方式も使わず、その旨をチャンネルで主に報告して止まる（MUST。channel は別セッション方式を引き継がない）。channel の本体は、develop の手順のために別の Claude Code セッション（Orca・tmux など）を起こしてはならない（MUST NOT。別に起こしたセッションには印 `DEV_WORKFLOW_UNATTENDED` が届かず、その画面を誰も見ていないので、子が主の返事待ちで止まっても誰も気づかない）。develop の外で住人が別のセッションを起こすときの印の渡し方は、この要件の範囲に入れない（#1123）。

**回し方（別セッション方式）**: 本体は `epic-dispatch.sh launch` で子ごとに起動部品（Orca か tmux）の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。再開時も、依存が解けた open の子を `launch` に渡し、起動済みの子は `launch` の `skipped` で見分ける（同じ子を二重に起動しない）。本体は `launch` が `launched` / `skipped` を出した子を動いている子とし、`epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める。`closed` なら閉じた子ごとに `state_reason` を読み、`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントして依存グラフを読み直し、解けた子を件数にかかわらず `launch` する。`completed` 以外ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子を起動してはならず（MUST NOT）、ユーザーに報告する。そのあと残りの動いている子で再び `wait` する。`timeout` なら待っている子に `needs-approval` などの停止の兆候が無いかを見て、あればユーザーに報告し、報告したかどうかにかかわらず残りの動いている子で再び `wait` する。子が自分のタブでユーザーに質問して止まっている場合はこの確認では気づけないことを書く（SHALL）。`wait` の `error` と `launch` の `failed` はユーザーに報告して止まる。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子セッションのモデルは `epic-dispatch.sh launch` が起動時に `cld --model` で指定し、既定は `opus` で環境変数 `EPIC_DISPATCH_MODEL` で変えられること（Claude Code の既定モデルは子に効かないこと）、コマンド部分（既定 `cld`）は環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ、Orca に設定したコマンドはハーネスから読めないので（tmux の部品はこの環境変数のコマンドをそのまま打ち込む）Orca 側のコマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変えることを書く（SHALL）。子セッションは `cld` が付ける `--dangerously-skip-permissions` で動き許可の確認画面が出ないこと（`epic-dispatch.sh` が足すのは `--model` だけであること）、マージを止めているのは develop と pr-review-gate の規則と hooks であることを書く（SHALL）。本体は子の PR を `gh pr merge` や merge API で直接マージしてはならない（MUST NOT）。子の PR のマージは、子セッションの中の人の承認か自動マージの処理（`.github/workflows/auto-merge.yml`）が行い、`human-merge` の付いた子の PR は、本体が要件「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」の手順で判断の印を付けたときに限って自動マージの処理がマージすることを書く（SHALL）。

**回し方（サブエージェント方式）**: 今までどおり blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと。本体が W を `isolation: "worktree"` で spawn して用意し、W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。

どちらの経路でも、スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった新しい問題は新しい子 issue として追加する。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

#### Scenario: エピックの 4 節が存在する
- **WHEN** SKILL.md の「エピックの扱い」節を読む
- **THEN** 条件・作り方・回し方・完了条件の 4 つが揃い、完了条件に「子が全部マージされただけでは閉じない」が書かれている

#### Scenario: 子は並列に worktree 分離で起こす
- **WHEN** エピックの回し方を読む
- **THEN** サブエージェント方式として、blocked されていない子から `isolation: "worktree"` で 1 ループを並列に起こすことが書かれ、どちらの経路でも新しい問題は子の中で直さず新しい子 issue にすることが書かれている

#### Scenario: 回し方に 2 経路の振り分け条件が書かれている
- **WHEN** エピックの回し方を読む
- **THEN** `epic-dispatch.sh route` の出力で経路を決めること、`orca` になる条件（`orca` が PATH にある・本体が Orca 管理のワークツリーにいる）、それ以外はサブエージェント方式で進むこと、経路を最初の開始時に 1 回決めて途中で変えないこと、再開時は `回し方:` のコメントから経路を引き継ぐこと、unmanned はサブエージェント方式のままであることが書かれている

#### Scenario: 別セッション方式の本体は wait の出力で次を決める
- **WHEN** 別セッション方式の本体の手順を読む
- **THEN** `launch` で子を起動し、`wait` を `run_in_background: true` で起動して待つこと、`closed` で `state_reason` を読み `completed` なら `子 #N マージ → 残り k 件` をコメントして解けた子を `launch` し、それ以外なら `見送り` とコメントして後続を起動せず報告すること、`timeout` で停止の兆候を確かめて報告したうえで再び待つこと、子のタブでの質問は検知できないこと、本体が子の PR を直接マージせず、`human-merge` の付いた子の PR は本体が判断の印を付けたときに限って自動マージの処理がマージすることが書かれている

#### Scenario: 別セッション方式に子セッションのモデルの決め方が書かれている
- **WHEN** 別セッション方式の説明を読む
- **THEN** 子セッションのモデルは `epic-dispatch.sh launch` が `cld --model` で指定すること、既定が `opus` であること、`EPIC_DISPATCH_MODEL` で変えられること、Claude Code の既定モデルが何であっても子は指定したモデルで起動すること、コマンド部分を `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ Orca 側のコマンドを変えたら合わせて変えること、`--dangerously-skip-permissions` を付けるのは `cld` であることが書かれている

#### Scenario: Orca がある環境の channel の本体がエピックを回す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる channel の本体が `/develop <エピック番号>` を始める
- **THEN** 本体は `route` を呼ばず、エピックに `回し方: サブエージェント（channel モード）` とコメントしてサブエージェント方式で回し、別の Claude Code セッションを起こさない

#### Scenario: SKILL.md の回し方が起動部品の差し替えとして書かれている
- **WHEN** develop の SKILL.md「エピックの扱い」→「回し方」を読む
- **THEN** 起動・待ち・閉じた子・止まった子・片付け・完了の手順は 1 本で書かれ、Orca の部品・tmux の部品・サブエージェント方式のどれで起こすかによって違う点だけが部品ごとの欄に書かれており、「Orca 経路」と「サブエージェント方式」を別々の手順として二重に書いていない。サブエージェント方式は状態の記録を書かない、と書かれている
