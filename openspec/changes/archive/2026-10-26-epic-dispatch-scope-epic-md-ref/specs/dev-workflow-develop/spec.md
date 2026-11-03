## MODIFIED Requirements

### Requirement: epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` を持たなければならない（MUST）。どのサブコマンドも LLM を呼んではならない（MUST NOT）。

`route <child>...` は stdout にちょうど 1 行を出して exit 0 で終わらなければならない（MUST）。判定は次の順で、最初に当たったものを出す: (1) エピックの子のセッション（環境変数 `EPIC_DISPATCH_PARENT_EPIC` があるか、今のワークツリーを `worktree` に持つ状態の記録がある）なら `nested`、(2) 引数の子が 0 件なら `subagent`、(3) 環境変数 `EPIC_DISPATCH_LAUNCHER` が `orca` か `tmux` ならその値（部品が使えるかを確かめ、使えなければ stderr に理由を出して `subagent`）、(4) Orca の部品の `here` が exit 0（`orca` が PATH にあり、今いるディレクトリが Orca 管理のワークツリー）なら `orca`、(5) 環境変数 `TMUX` が空でなく `tmux` コマンドが PATH にあれば `tmux`、(6) それ以外は `subagent`。`EPIC_DISPATCH_LAUNCHER` が `orca`・`tmux`・空のどれでもなければ stderr に使い方を出して exit 1 で終わる。子の番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。`launch` と `adopt` は、同じ順の (3)〜(5) で使う起動部品を決め、決められなければ exit 1 で終わる。

`launch [--note <text>] [--base <branch>] <epic> <child>...` は、起動部品が Orca のとき、次の順で呼び出さなければならない（MUST。tmux の部品のときの呼び出しは capability `dev-workflow-epic-state` の要件「tmux の部品は…」が決める。部品の選び方は要件「記録の launcher ごとに起動部品を選ぶ」）: `orca worktree current --json`（今の repo の `repoId` を得る）→ `git rev-parse --show-toplevel` → `git fetch origin <base>` → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` → 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --json` → 子の端末を用意する（`orca terminal list --worktree path:<子> --json` で端末を数え、0 個のときだけ `orca terminal create --worktree path:<子> --command <cmd> --json` で作る。ちょうど 1 つのときは作らずにその端末を使う。詳細は要件「launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ」）→ `orca terminal wait --terminal <handle> --for tui-idle --timeout-ms <ready> --json` → `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json`。worktree create に `--agent` と `--prompt` を渡してはならない（MUST NOT。`--agent` で起動すると子セッションのモデルを指定できず Claude Code の既定モデルで動くため。`--prompt` は Orca 1.4.209 では指示が子の入力欄に届かず、送信と併用すると指示が 2 回届くおそれがあるため）。`<子>` は worktree create の JSON 出力の `result.worktree.path` とする（MUST）。`<cmd>` は `<claude-cmd> --model <model>` で（`--dangerously-skip-permissions` などの許可に関わる引数は付けてはならない（MUST NOT）。付けるのは `<claude-cmd>` 側に任せる）、`<claude-cmd>` の既定は `cld` で環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で変えられ、クォートせずそのまま置く（MUST。`--command` の文字列は Orca が開いたログインシェルに打ち込まれるのでシェル関数も解決され、`cld-account b` のような引数付きも書けるため）。`<model>` はシェルに打ち込まれても 1 語のまま渡るよう単一引用符で囲む（MUST。`opus[1m]` のような値がグロブとして解釈されないため）。`<model>` の既定は `opus` で、環境変数 `EPIC_DISPATCH_MODEL` で変えられる（MUST）。`<handle>` は、端末を作ったときは terminal create の JSON 出力の `result.terminal.handle`、使い回したときはその端末のハンドルとする（MUST）。`<ready>` の既定は 60000（ミリ秒）で環境変数 `EPIC_DISPATCH_READY_TIMEOUT_MS` で、`<submit>` の既定は 30（秒）で環境変数 `EPIC_DISPATCH_SUBMIT_WAIT` で変えられる（SHALL）。`<親>` は `git rev-parse --show-toplevel` で求めた親ワークツリーの絶対パスで、親の指定は create と set の両方で `path:` を使わなければならない（MUST。`worktree:<id>` は set で `selector_not_found` になるため）。`<base>` の既定は `main` で、環境変数 `EPIC_DISPATCH_BASE` で既定を変えられ、`--base` が環境変数より優先する（MUST）。`<prompt>` は `/develop #<N>` で始まり、エピック番号を含み、`--note` があればその文を含む（SHALL）。子を `launched <N>` とするのは、worktree create が exit 0 で終わり、子のワークツリーのパスが取れ、端末を用意でき（terminal create が exit 0 で終わりハンドルが取れた、または使い回した端末が Claude Code になった）、`terminal wait` が exit 0 で終わり、`terminal send` が exit 0 で終わってその JSON 出力のどこかの `stages` 配列に `turn_started` が含まれるときだけでなければならない（MUST）。どれか 1 つでも満たさなければ `failed <N>` とし（MUST）、子のワークツリーのパスが取れていて、端末を作る経路でハンドルが取れていなければ（terminal create の失敗を含む）、端末を手で起動し直すための `orca terminal create --worktree path:<子> --command <cmd> --json` を stderr に出すに続けて、最初の指示を送るための `orca terminal send --terminal <作り直した端末のハンドル> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出す（SHALL。ワークツリーは残るので、再実行ではその子は `skipped <N>` になり端末が作られないため）。端末を用意できたあと（`terminal wait` か `terminal send` の段）で失敗し、ハンドルが取れていれば、指示を手で送り直すための `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出し、あわせて「送る前に `orca terminal read --terminal <handle>` で入力欄とターンの状態を確かめる」旨の案内を出す（SHALL。送信が非 0 やターン未観測で終わっても指示が届いていることがあり、確かめずに送ると 2 回届くため）。`terminal send` の JSON 出力に送り直し用の ID（キー `retryRequestId` または `retryRequest` の文字列値）があれば、送り直しのコマンドに `--retry-request <id>` を付ける（SHALL）。ワークツリーは残すので、再実行ではその子は `skipped <N>` になり、指示を送り直さない（SHALL）。一覧に、同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出さなければならない（MUST。再開時や取り違えで同じ子を二重に起動しないため）。`orca` が PATH に無いときは何も呼ばずに exit 1 で終わり、`orca worktree current`・`git fetch`・`orca worktree set`・`orca worktree list` のどれかが失敗したとき（`jq` が無くて一覧を読めないときを含む）は子を 1 件も作らずに exit 1 で終わらなければならない（MUST）。stdout には子ごとに `launched <N>`・`skipped <N>`・`failed <N>` のどれか 1 行だけを出し、`orca` 自身の出力は stderr に流す（SHALL）。1 件の失敗で残りの子の起動を止めず、`failed` が 0 件なら exit 0、1 件でもあれば exit 1 で終わる（MUST）。

`wait [--interval <sec>] [--timeout <sec>] <child>...` は、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` で state を確かめるポーリングを繰り返し、stdout にちょうど 1 行を出して終わらなければならない（MUST）。子ごとの結果は、出力が `closed` なら閉じている、`open` なら開いている、`gh` が非 0 で終わったか出力がそれ以外（空文字を含む）なら失敗とする（MUST）。1 件以上の子が閉じていれば `closed <N>...`（閉じていた子の番号）で exit 0、上限時間に達したら `timeout <N>...`（閉じていない子の番号）で exit 2、失敗したポーリングが 3 回続いたら `error gh <N>...`（3 回目で失敗した子の番号）で exit 1 で終わる（MUST）。失敗したポーリングとは、1 件以上の子が失敗し、かつ閉じた子が 1 件も無いポーリングを言い、一部の子だけが失敗してほかの子が `open` の場合も含む（MUST）。失敗の無いポーリングがあれば数え直す（SHALL）。閉じた子がいるポーリングでは、ほかの子の失敗より `closed` を優先する（SHALL）。間隔と上限は秒で、既定は間隔 300・上限 21600、環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する（MUST）。ポーリングのあとで経過時間が上限に達しているか、経過時間と間隔の和が上限を超えるなら、眠らずに `timeout` で終わる（MUST。`--timeout 0` は間隔によらず 1 回だけ確かめて終わる）。子が 0 件、番号が数字でない、間隔・上限が非負整数でないときは stderr に使い方を出して exit 1 で終わる（SHALL）。

この要件の守備範囲で入力として扱うのは、本体（LLM）が依存グラフから求めた子の番号と、`references/epic.md` の手順どおりに付けるフラグである。人が手で打つことは想定しない。引数の検査で拾う誤りは、番号の取り違えで引数が空になること、`#12` のように番号に記号が付くこと、フラグ値の打ち間違いである。数字でさえあれば、存在しない issue 番号・重複した番号・blocked されている子の番号は通してよく（`route` は依存を検証しない。存在しない番号は `wait` の失敗したポーリングとして数えられ `error` で表に出る）、非常に大きい `--timeout` も通してよい。検査をすり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。`EPIC_DISPATCH_READY_TIMEOUT_MS` と `EPIC_DISPATCH_SUBMIT_WAIT` は非負の整数でなければ stderr に使い方を出し、子を 1 件も作らずに exit 1 で終わる（SHALL。`--interval` と同じ扱いで、上限は設けない）。`EPIC_DISPATCH_MODEL` か `EPIC_DISPATCH_CLAUDE_CMD` が設定されていて空文字のときも stderr に使い方を出し、子を 1 件も作らずに exit 1 で終わる（SHALL。空でない値はそのまま使い、モデル名やコマンドとしての正しさは検査しない）。worktree create の JSON 出力の `result.worktree.path` と terminal create の JSON 出力の `result.terminal.handle` は 2026-09-25 の実機での出力の形のとおりと信じ、`terminal send` の JSON 出力の `stages` 配列と `turn_started` の語は、2026-09-24 の実機での出力の形のとおりと信じ、読めないときは `failed` として表に出すだけで、形の変化そのものの検知は範囲外とする。`orca worktree list --json` の出力は確かめた形（`.result.worktrees[]` の `repoId`・`linkedIssue`・`isArchived`）のとおりと信じ、形が変わったときの検知は範囲外とする。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、呼び出しの引数と順序、stdout の 1 行と exit code を確かめなければならない（MUST）。テストの途中に素の `[[ ]]` を置いてはならない（MUST NOT。bash 3.2 では偽でも素通りする）。

#### Scenario: orca が無く tmux の中でもない環境ではサブエージェント方式になる
- **WHEN** `orca` が PATH に無く、環境変数 `TMUX` が空の環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: orca はあるが Orca 管理外のワークツリーで tmux の中でもなければサブエージェント方式になる
- **WHEN** `orca` が PATH にあり `orca worktree current` が exit 1 を返し、環境変数 `TMUX` が空の環境で `epic-dispatch.sh route 11 12` を実行する
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

#### Scenario: orca が無く tmux の中でもない環境では launch は何も呼ばない
- **WHEN** `orca` が PATH に無く、環境変数 `TMUX` が空で、`EPIC_DISPATCH_LAUNCHER` が空の環境で `epic-dispatch.sh launch 400 11 12` を実行する
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

