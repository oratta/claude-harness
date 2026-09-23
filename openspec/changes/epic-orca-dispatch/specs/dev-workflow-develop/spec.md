## MODIFIED Requirements

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
SKILL.md は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。**回し方**: 本体は子の依存グラフを読み、blocked されていない子の番号を `plugins/dev-workflow/scripts/epic-dispatch.sh route` に渡して経路を決める（MUST）。`route` が `orca` を返したとき（blocked されていない子が 2 件以上あり、`orca` コマンドが PATH にある）は **Orca 経路**、`subagent` を返したときは **サブエージェント方式**で進める（MUST）。経路は `/develop <エピック番号>` の開始時に 1 回決め、そのセッションの間は変えてはならず（MUST NOT）、決めた経路をエピックに 1 行コメントで残す（SHALL）。

Orca 経路では、本体は `epic-dispatch.sh launch` で子ごとに Orca の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。本体は `epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める: `closed` なら閉じた子ごとにエピックへ 1 行コメント（`子 #N マージ → 残り k 件`）し、依存グラフを読み直して解けた子を件数にかかわらず `launch` し、再び `wait` する。`timeout` なら待っている子に `needs-approval` などの停止の兆候が無いかを見て、あればユーザーに報告し、無ければ再び `wait` する。`wait` の `error` と `launch` の `failed` はユーザーに報告する。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子の PR のマージは今までどおり子セッションの中で人の承認で行い、本体が自動でマージしてはならない（MUST NOT）。

サブエージェント方式では、今までどおり blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと。本体が W を `isolation: "worktree"` で spawn して用意し、W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。

どちらの経路でも、スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった新しい問題は新しい子 issue として追加する。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

#### Scenario: エピックの 4 節が存在する
- **WHEN** SKILL.md の「エピックの扱い」節を読む
- **THEN** 条件・作り方・回し方・完了条件の 4 つが揃い、完了条件に「子が全部マージされただけでは閉じない」が書かれている

#### Scenario: 子は並列に worktree 分離で起こす
- **WHEN** エピックの回し方を読む
- **THEN** サブエージェント方式として、blocked されていない子から `isolation: "worktree"` で 1 ループを並列に起こすことが書かれ、どちらの経路でも新しい問題は子の中で直さず新しい子 issue にすることが書かれている

#### Scenario: 回し方に 2 経路の振り分け条件が書かれている
- **WHEN** エピックの回し方を読む
- **THEN** `epic-dispatch.sh route` の出力で経路を決めること、`orca` になる条件（blocked されていない子が 2 件以上かつ `orca` が PATH にある）、それ以外はサブエージェント方式で進むこと、経路を開始時に 1 回決めて途中で変えないことが書かれている

#### Scenario: Orca 経路の本体は wait の出力で次を決める
- **WHEN** Orca 経路の本体の手順を読む
- **THEN** `launch` で子を起動し、`wait` を `run_in_background: true` で起動して待つこと、`closed` でエピックに `子 #N マージ → 残り k 件` をコメントして解けた子を `launch` すること、`timeout` で停止の兆候を確かめて再び待つこと、子の PR を本体が自動でマージしないことが書かれている

### Requirement: 前提環境を明記する
SKILL.md は「前提」節として、Agent ツール（`model` 明示・名前付き spawn・`isolation: "worktree"`）と SendMessage、`gh`（issue / PR コメントとラベル、issue dependencies API）、opsx コマンドまたは openspec CLI（無ければ仕様化経路が発生しない）、Codex CLI（無ければ G が `needs-reviewer` に縮退）、`orca` コマンド（エピックの子を Orca の子ワークツリーで独立セッションとして起動する。無ければエピックはサブエージェント方式で回す）を列挙しなければならない（MUST）。

#### Scenario: 前提節がある
- **WHEN** SKILL.md の「前提」節を読む
- **THEN** Agent / SendMessage / gh / opsx または openspec / Codex CLI / orca とそれぞれ無いときの縮退が書かれている

## ADDED Requirements

### Requirement: epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` を持たなければならない（MUST）。どのサブコマンドも LLM を呼んではならない（MUST NOT）。

`route <child>...` は、引数の子が 2 件以上あり、かつ `orca` コマンドが PATH にあるときだけ stdout に `orca` の 1 行を出し、それ以外は `subagent` の 1 行を出して exit 0 で終わらなければならない（MUST）。子の番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。

`launch [--note <text>] <epic> <child>...` は、次の順で呼び出さなければならない（MUST）: `git fetch origin main` → `orca worktree set --worktree path:<親> --issue <epic>` → 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/main --parent-worktree path:<親> --agent claude --prompt <prompt> --json`。`<親>` は `git rev-parse --show-toplevel` で求めた親ワークツリーの絶対パスで、親の指定は create と set の両方で `path:` を使わなければならない（MUST。`worktree:<id>` は set で `selector_not_found` になるため）。`<prompt>` は `/develop #<N>` で始まり、エピック番号を含み、`--note` があればその文を含む（SHALL）。`orca` が PATH に無いときは何も呼ばずに exit 1 で終わり、`git fetch` または `orca worktree set` が失敗したときは子を 1 件も作らずに exit 1 で終わらなければならない（MUST）。stdout には子ごとに `launched <N>` または `failed <N>` の 1 行だけを出し、`orca` 自身の出力は stderr に流す（SHALL）。1 件の失敗で残りの子の起動を止めず、全部起動できれば exit 0、1 件でも失敗すれば exit 1 で終わる（MUST）。

`wait [--interval <sec>] [--timeout <sec>] <child>...` は、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` で state を確かめるポーリングを繰り返し、stdout にちょうど 1 行を出して終わらなければならない（MUST）。1 件以上の子が `closed` なら `closed <N>...`（閉じていた子の番号）で exit 0、上限時間に達したら `timeout <N>...`（まだ開いている子の番号）で exit 2、`gh` の失敗が 3 ポーリング連続したら `error gh <N>...` で exit 1 で終わる（MUST）。閉じた子がいるポーリングでは、ほかの子の `gh` の失敗より `closed` を優先する（SHALL）。間隔と上限は秒で、既定は間隔 300・上限 21600、環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する（MUST）。ポーリングのあとで経過時間と間隔の和が上限を超えるなら、眠らずに `timeout` で終わる（MUST。`--timeout 0` は 1 回だけ確かめて終わる）。子が 0 件、番号が数字でない、間隔・上限が非負整数でないときは stderr に使い方を出して exit 1 で終わる（SHALL）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、呼び出しの引数と順序、stdout の 1 行と exit code を確かめなければならない（MUST）。テストの途中に素の `[[ ]]` を置いてはならない（MUST NOT。bash 3.2 では偽でも素通りする）。

#### Scenario: orca が無い環境ではサブエージェント方式になる
- **WHEN** `orca` が PATH に無い環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: 並列にできる子が 1 件ならサブエージェント方式になる
- **WHEN** `orca` が PATH にある環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: 並列にできる子が 2 件以上で orca があれば Orca 経路になる
- **WHEN** `orca` が PATH にある環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: launch は fetch してから path: で親を渡して子を作る
- **WHEN** スタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 呼び出しの記録は `git fetch origin main`、`orca worktree set --worktree path:<親> --issue 400`、子 11 と子 12 の `orca worktree create`（それぞれ `--name issue-<N> --issue <N> --base-branch origin/main --parent-worktree path:<親> --agent claude --prompt "/develop #<N> ..."`）の順で、stdout は `launched 11` と `launched 12`、exit 0

#### Scenario: fetch に失敗したら子を作らない
- **WHEN** `git fetch` が失敗するスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `orca worktree create` は 1 回も呼ばれず、exit 1

#### Scenario: orca が無い環境では launch は何も呼ばない
- **WHEN** `orca` が PATH に無い環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `git fetch` も `gh` も呼ばれず、exit 1

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
