## ADDED Requirements

### Requirement: epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` に加えて `mark` と `reap` を持たなければならない（MUST）。どちらも LLM を呼んではならない（MUST NOT）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち、サブコマンドを `route`・`launch`・`wait` とする規定、`wait` が stdout にちょうど 1 行を出す規定、`wait` の子が 0 件なら使い方を出す規定に優先する。

**`mark <done|waiting> <issue>`** は、今いるワークスペースに印を付ける。`done` は Orca のボードの列 `completed`、`waiting` は `in-review` に対応させる（MUST）。次の順で動かなければならない（MUST）。

- 1 つ目の引数が `done` / `waiting` のどちらでもない、`<issue>` が数字でない、引数の数が 2 でないときは、stderr に使い方を出して exit 1 で終わる
- `orca` が PATH に無いか、`orca worktree current --json` が非 0 で終わるときは、stdout に `skipped <issue> no-workspace` の 1 行を出して exit 0 で終わる。ほかの `orca` のコマンドを呼んではならない（MUST NOT）。印の代わりになるもの（ファイルなど）を作ってはならない（MUST NOT）
- `orca worktree current --json` の `.result.worktree.linkedIssue` が `<issue>` と一致しないとき（null を含む）は、`orca worktree set` を呼ばず、stdout に `skipped <issue> not-linked` の 1 行を出して exit 0 で終わる
- 一致するときは `orca worktree set --worktree current --workspace-status <completed|in-review>` を 1 回呼び、exit 0 なら stdout に `marked <issue> <done|waiting>` の 1 行を出して exit 0、非 0 なら `failed <issue>` の 1 行を出して exit 1 で終わる。`orca` 自身の出力は stderr に流す（SHALL）

**`wait [--interval <sec>] [--timeout <sec>] [--watch-done <N>]... [<child>...]`** は、`--watch-done` が 1 つも無いときは今までどおりに動き、`orca` を呼んではならない（MUST NOT）。`--watch-done` が 1 つ以上あるときは次のとおり動かなければならない（MUST）。

- 位置引数の子が 0 件でも受け付ける。`--watch-done` の値が数字でなければ stderr に使い方を出して exit 1 で終わる
- ポーリングを始める前に `orca worktree current --json` で今の repo の `repoId` を得る。`orca` か `jq` が PATH に無い、このコマンドが非 0 で終わる、`repoId` が取れないときは、stderr に理由を出し、stdout に何も出さず exit 1 で終わる
- ポーリングごとに、位置引数の子の `gh` の確認（今までどおり）のあと、`orca worktree list --json` を 1 回だけ呼ぶ。`--watch-done` の子 `<N>` は、一覧に `repoId` が同じ・`linkedIssue` が `<N>`・`isArchived` が true でない・`workspaceStatus` が `completed` のワークツリーがあれば「印が付いた」とする。子の数によらず、ポーリング 1 回あたりの `gh` の呼び出しは位置引数の子の数と同じでなければならない（MUST）
- 閉じた子か印が付いた子が 1 件以上あれば、閉じた子がいるとき `closed <N>...`、印が付いた子がいるとき `done <N>...` を、この順で出して exit 0 で終わる（1 行か 2 行）
- 一覧の取得が非 0 で終わるか、`.result.worktrees` が配列でないポーリングは、閉じた子も印が付いた子も無ければ「失敗したポーリング」に数える。失敗したポーリングが 3 回続いたとき、`gh` で失敗した子がいれば `error gh <N>...`、いなければ `error workspaces` の 1 行を出して exit 1 で終わる
- 上限時間に達したら `timeout` に続けて閉じていない位置引数の子の番号を出して exit 2 で終わる。位置引数が 0 件なら `timeout` だけの 1 行とする

**`reap <child>...`** は、印が付いた子のワークスペースを片付ける。子が 0 件か番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。`orca` か `jq` が PATH に無い、`orca worktree current --json` が非 0 で終わるか `repoId`・`id` が取れない、`orca worktree list --json` が非 0 で終わるか `.result.worktrees` が配列でないときは、何も消さず、stdout に何も出さず exit 1 で終わらなければならない（MUST）。一覧は 1 回だけ取る（SHALL）。子ごとに次の順で確かめ、外れた時点でその子についてはそれ以上何も呼ばず、対応する 1 行を出して次の子へ進まなければならない（MUST）。同じ呼び出しの中で 2 回目以降に現れた番号は何もせず行も出さない（SHALL）。

1. 一覧のうち、`repoId` が今のワークツリーと同じ・`linkedIssue` が `<N>`・`isArchived` が true でないワークツリーを子の候補とする。0 件なら `gone <N>`、2 件以上なら `kept <N> ambiguous`
2. 候補の `isMainWorktree` が true、または `parentWorktreeId` が今のワークツリーの `id` と一致しなければ `kept <N> not-child`
3. 候補の `workspaceStatus` が `completed` でなければ `kept <N> not-done`
4. `git -C <子のパス> status --porcelain` が非 0 なら `kept <N> git-failed`、出力が空でなければ `kept <N> dirty`
5. `<子のパス>/LLM` が存在すれば `kept <N> llm-logs`
6. 候補の `branch` が `refs/heads/` で始まらなければ `kept <N> no-branch`
7. `gh pr list --head <ブランチ> --state merged --json headRefOid --jq '.[].headRefOid'` が非 0 なら `kept <N> pr-lookup-failed`、出力が空なら `kept <N> no-merged-pr`、出力のどの行も `git -C <子のパス> rev-parse HEAD` の出力と一致しなければ `kept <N> head-mismatch`

1〜7 をすべて通った子に限り、`orca terminal close --worktree path:<子のパス> --all`、`orca worktree rm --worktree path:<子のパス>` をこの順に 1 回ずつ呼ばなければならない（MUST）。`orca worktree rm` に `--force` を付けてはならない（MUST NOT）。close が非 0 なら rm を呼ばずに `kept <N> close-failed`、rm が非 0 なら `kept <N> rm-failed` を出す（MUST）。rm が exit 0 のあと、`git rev-parse --verify --quiet refs/heads/<ブランチ>` が exit 0 で、その出力が 7 で一致した HEAD と同じときだけ `git branch -D <ブランチ>` を呼ぶ（MUST）。ブランチが無いか、`git branch -D` が exit 0 なら `reaped <N>`、先端が違うか `git branch -D` が非 0 なら `reaped <N> branch-kept` を出す（MUST）。1〜7 のどれかで外れた子、close か rm が失敗した子について、`git branch -D` を呼んではならない（MUST NOT）。stdout には子ごとに 1 行だけを出し、`orca`・`git`・`gh` 自身の出力は stderr に流す（SHALL）。子ごとの行を出し終えたら、`kept` があっても exit 0 で終わる（MUST）。

この要件の守備範囲で入力として扱うのは、develop の本体が SKILL.md の手順どおりに渡す番号と、`orca worktree current --json`・`orca worktree list --json` の出力（2026-10-08、Orca 1.4.222 で確かめた `id`・`repoId`・`path`・`branch`・`linkedIssue`・`isArchived`・`isMainWorktree`・`workspaceStatus`・`parentWorktreeId`）である。拾いたい誤りは、印が付いていない子・親の `launch` が作っていないワークツリー・push していないコミットや未コミットの変更や `LLM/` を持つワークツリーを消すことである。次は通してよく、この要件では止めない: Orca の出力の形が変わったときの検知（読めなければ `gone` か `kept` になり、消す側には倒れない）／フォークの同名ブランチのマージ済み PR（HEAD の一致で落ちる）／オーナーがボードで手で `completed` に動かした子（子が付けた印と同じに扱う）／確認から削除までの間に子が積んだコミット（`--force` を付けない rm と、ブランチの先端の比較で残る）。すり抜ける入力が見つかるたびに確認を足すことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、下の Scenario を確かめなければならない（MUST）。

#### Scenario: 自分の issue のワークスペースに完了の印を付ける
- **WHEN** `orca worktree current --json` の `linkedIssue` が 11 のスタブ環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** `orca worktree set --worktree current --workspace-status completed` が 1 回呼ばれ、stdout は `marked 11 done` の 1 行で exit 0

#### Scenario: 確認待ちの印は in-review になる
- **WHEN** `linkedIssue` が 11 のスタブ環境で `epic-dispatch.sh mark waiting 11` を実行する
- **THEN** `orca worktree set` は `--workspace-status in-review` で呼ばれ、stdout は `marked 11 waiting` で exit 0

#### Scenario: 別の issue のワークスペースには印を付けない
- **WHEN** `linkedIssue` が 400（エピックの番号）のスタブ環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** `orca worktree set` は呼ばれず、stdout は `skipped 11 not-linked` で exit 0

#### Scenario: Orca 管理外と orca が無い環境では何もしない
- **WHEN** `orca worktree current` が exit 1 を返すスタブ環境、および `orca` が PATH に無い環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** どちらも `orca worktree set` は呼ばれず、stdout は `skipped 11 no-workspace` で exit 0

#### Scenario: 印を付けられなければ failed
- **WHEN** `orca worktree set` が非 0 で終わるスタブ環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** stdout は `failed 11` で exit 1

#### Scenario: mark の引数の誤りは使い方を出す
- **WHEN** `epic-dispatch.sh mark completed 11`、`epic-dispatch.sh mark done`、`epic-dispatch.sh mark done '#11'` を実行する
- **THEN** どれも `orca` を呼ばず、stderr に使い方が出て exit 1

#### Scenario: issue が open のままでも印が付いた子を検知して終わる
- **WHEN** 子 11 の `gh` が常に `open` を返し、一覧の子 11 のワークツリーが 2 回目のポーリングから `workspaceStatus: completed` になるスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11 11` を実行する
- **THEN** stdout は `done 11` の 1 行で exit 0、`gh` の呼び出しは 2 回

#### Scenario: 閉じた子と印が付いた子が同じポーリングにいれば 2 行を出す
- **WHEN** 子 12 の `gh` が `closed` を返し、一覧の子 11 のワークツリーが `completed` のスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11 --watch-done 12 12` を実行する
- **THEN** stdout は `closed 12`、`done 11` の順の 2 行で exit 0

#### Scenario: 位置引数が無くても印だけを待てる
- **WHEN** 一覧の子 11 のワークツリーが `in-review` のままのスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** `gh` は呼ばれず、stdout は `timeout` の 1 行で exit 2

#### Scenario: --watch-done が無ければ orca を呼ばない
- **WHEN** 子 11 の `gh` が `closed` を返すスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11` を実行する
- **THEN** stdout は `closed 11` の 1 行で exit 0、`orca` は 1 回も呼ばれない

#### Scenario: 別の repo や archive されたワークツリーの印は数えない
- **WHEN** 一覧に、`repoId` が違う `linkedIssue` 11 の `completed` のワークツリーと、`isArchived` が true の `linkedIssue` 11 の `completed` のワークツリーだけがあるスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout` で exit 2

#### Scenario: 一覧を取れないポーリングが 3 回続いたら error で終わる
- **WHEN** `orca worktree list` が常に非 0 で終わるスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 3 回のポーリングのあと stdout は `error workspaces` の 1 行で exit 1

#### Scenario: 条件をすべて満たす子は端末を閉じてからワークツリーを消す
- **WHEN** 一覧の子 11 のワークツリーが、同じ `repoId`・`parentWorktreeId` が今のワークツリーの `id`・`isMainWorktree` が false・`workspaceStatus` が `completed`・`branch` が `refs/heads/oratta/issue-11` で、`git status --porcelain` が空、`LLM/` が無く、マージ済み PR の `headRefOid` がワークツリーの HEAD と同じスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close --worktree path:<子> --all` と `orca worktree rm --worktree path:<子>` がこの順に 1 回ずつ呼ばれ、どの `orca` の呼び出しにも `--force` が無く、stdout は `reaped 11` の 1 行で exit 0

#### Scenario: 条件を外れた子は消さずに理由を出す
- **WHEN** 上の Scenario から 1 点だけを変えたスタブ環境（`workspaceStatus` が `in-review`／ワークツリーの HEAD が PR の `headRefOid` と違う／`git status --porcelain` に出力がある／`<子>/LLM` がある／`parentWorktreeId` が別のワークツリー）それぞれで `epic-dispatch.sh reap 11` を実行する
- **THEN** どの場合も `orca terminal close`・`orca worktree rm`・`git branch -D` は 1 回も呼ばれず、stdout は順に `kept 11 not-done`・`kept 11 head-mismatch`・`kept 11 dirty`・`kept 11 llm-logs`・`kept 11 not-child` の 1 行で exit 0

#### Scenario: マージ済みの PR が無い子と、PR を調べられない子は消さない
- **WHEN** `gh pr list` の出力が空のスタブ環境、および `gh pr list` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca worktree rm` は呼ばれず、stdout は順に `kept 11 no-merged-pr`・`kept 11 pr-lookup-failed` で exit 0

#### Scenario: ワークツリーが既に無い子は gone
- **WHEN** 一覧に `linkedIssue` が 11 のワークツリーが無いスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git` も `gh` も呼ばれず、stdout は `gone 11` で exit 0

#### Scenario: 残ったブランチは先端が PR の最終コミットと同じときだけ消す
- **WHEN** `orca worktree rm` のあともローカルブランチ `oratta/issue-11` が残り、その先端が PR の `headRefOid` と同じスタブ環境、および先端が違うスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** 前者は `git branch -D oratta/issue-11` が 1 回呼ばれて stdout は `reaped 11`、後者は `git branch -D` が呼ばれず stdout は `reaped 11 branch-kept`、どちらも exit 0

#### Scenario: ブランチが残っていなければ git branch -D を呼ばない
- **WHEN** `orca worktree rm` のあと `git rev-parse --verify --quiet refs/heads/oratta/issue-11` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git branch -D` は呼ばれず、stdout は `reaped 11` で exit 0

#### Scenario: 端末を閉じられなければワークツリーを消さない
- **WHEN** `orca terminal close` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca worktree rm` と `git branch -D` は呼ばれず、stdout は `kept 11 close-failed` で exit 0

#### Scenario: 複数の子は 1 件ずつ判定する
- **WHEN** 子 11 は条件をすべて満たし、子 12 は `workspaceStatus` が `in-review` のスタブ環境で `epic-dispatch.sh reap 11 12` を実行する
- **THEN** stdout は `reaped 11` と `kept 12 not-done` の 2 行で、`orca worktree rm` は子 11 のパスに 1 回だけ呼ばれ、exit 0

#### Scenario: 一覧を取れなければ何も消さない
- **WHEN** `orca worktree list` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` も `orca worktree rm` も呼ばれず、stdout は空で exit 1

### Requirement: wait のテストはポーリングごとの stderr の空化を固定する
`plugins/dev-workflow/tests/epic-dispatch.bats` の「`gh` の stderr はエラー行の直前に出る」テストは、`error` で終わったときに本体の stderr に出るのが最後（3 回目）のポーリングの `gh` の stderr だけであることを確かめなければならない（MUST）。`gh` のスタブは失敗のたびに `gh: mock failure for issue <N> (poll <回数>)` を stderr に出すので、stderr に `(poll 3)` が含まれることと、`mock failure` を含む行がちょうど 1 行であることを確かめる（MUST）。

#### Scenario: 3 回目のポーリングの stderr だけが出る
- **WHEN** `gh` が常に失敗するスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11` を実行する
- **THEN** stderr は `(poll 3)` を含み、`mock failure` を含む行はちょうど 1 行である

#### Scenario: 空にする処理を消すとテストが落ちる
- **WHEN** `epic-dispatch.sh` の `wait` から、ポーリングごとに stderr の置き場を空にする処理を消して同じテストを実行する
- **THEN** `mock failure` を含む行が 3 行になり、テストは失敗する

### Requirement: develop のループの終わりは片付けを聞かず、ワークスペースに印を付ける
develop の SKILL.md は「ループの終わり」の節を持ち、次を規定しなければならない（MUST）。

- 本体は、完了報告でも途中でも、worktree の片付けを提案も質問もしてはならない（MUST NOT）。片付けは、Orca 経路のエピックの子なら親セッションが行い、それ以外はオーナーが別のセッションで `/wt-clean` を使う
- 記録先が issue で PR がマージ済みのとき、本体はそのループの最後のツール呼び出しとして `scripts/epic-dispatch.sh mark <done|waiting> <記録先の issue 番号>` を 1 回呼ぶ（MUST）。オーナーに頼むことが残っていなければ `done`、完了報告にマージ後の依頼（動作確認など）を書いたなら `waiting` とし、オーナーが済んだと返事をしたら `done` で呼び直す（MUST）
- PR がマージされていないとき（保留・マージ待ち・unmanned）と、記録先が Draft PR のときは呼ばない（MUST NOT）
- 出力が `marked` / `skipped` なら何もせず、`failed` なら完了報告に 1 行書く。どの出力でも止まらない（SHALL）
- 印を最後に置く理由（印が付くと親セッションがそのワークスペースの端末を閉じること）を書く（SHALL）

この規定は SKILL.md に置き、`launch --note` で子に渡す指示に頼ってはならない（MUST NOT。起動し直したセッションにも効かせるため）。

#### Scenario: SKILL.md にループの終わりの節がある
- **WHEN** SKILL.md の「ループの終わり」の節を読む
- **THEN** worktree の片付けを提案も質問もしないこと、片付けは親セッションか別セッションの `/wt-clean` が担うこと、記録先が issue で PR がマージ済みのときに最後のツール呼び出しとして `epic-dispatch.sh mark` を呼ぶこと、`done` と `waiting` の使い分け、オーナーの返事のあとに `done` で呼び直すこと、マージされていないときと記録先が Draft PR のときは呼ばないことが書かれている

#### Scenario: 片付けの記述を grep で確かめられる
- **WHEN** `grep -rn "worktree" plugins/dev-workflow/skills/develop/SKILL.md` を実行する
- **THEN** 「worktree の片付けを提案も質問もしない」に当たる行が出る

### Requirement: Orca 経路の本体は印が付いた子のワークスペースを片付ける
develop の SKILL.md「エピックの扱い」の Orca 経路は、次を規定しなければならない（MUST）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」の Orca 経路の規定に加わる。

- 本体は `epic-dispatch.sh wait` に、`launch` に渡したことのある子（閉じた子を含む）を `--watch-done <N>` で渡す（MUST）。エピックに `子 #N のワークツリーを残した` で始まる行がある子は渡さない（MUST NOT）
- `done <N>...` で起こされたら、本体は `epic-dispatch.sh reap <N>...` を Bash で 1 回呼ぶ（MUST）。wt-clean を呼んではならない（MUST NOT）。子ごとの確認をオーナーに取ってはならない（MUST NOT。子が印を付けたことを承認として扱う）
- `reaped <N>` と `gone <N>` は何もしない。`reaped <N> branch-kept` はエピックに `子 #N のローカルブランチを残した` と 1 行コメントする。`kept <N> <理由>`（理由が `not-done` 以外）はエピックに `子 #N のワークツリーを残した（<理由>）` と 1 行コメントし、オーナーの判断に残す（MUST）。本体が手で消し直してはならない（MUST NOT）。`kept <N> not-done` は待ちを続ける
- `closed` と `done` の 2 行で起こされたら、両方を処理する（MUST）
- 開いている子が無くなったら `reap` を 1 回呼び、`kept <N> not-done` の子だけを `--watch-done` に渡して（位置引数の子なしで）待ちを続ける。エピックの完了条件の確認と報告を、この待ちを理由に遅らせない（SHALL）。この待ちが `timeout` で終わったら、残っている子の番号をユーザーに報告して待ちをやめる（SHALL）
- `回し方: Orca` を引き継いで再開したら、`launch` の前に子（閉じた子を含む）で `reap` を 1 回呼ぶ（SHALL）
- `wait` の `error workspaces` は `error gh ...` と同じく、ユーザーに報告して止まる（MUST）

#### Scenario: Orca 経路に片付けの手順が書かれている
- **WHEN** SKILL.md の「エピックの扱い」の「回し方」を読む
- **THEN** `wait` に `--watch-done` を付けること、`done` で起こされたら `reap` を 1 回呼ぶこと、`kept` の子はエピックに `子 #N のワークツリーを残した（<理由>）` とコメントしてオーナーの判断に残し手で消し直さないこと、`not-done` は待ちを続けること、開いている子が無くなったあとは確認待ちの子だけを待ち `timeout` で待ちをやめること、再開時に `reap` を 1 回呼ぶことが書かれている

### Requirement: develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする
`plugins/dev-workflow/skills/develop/` 配下のファイルは、`orca` を実行する書き方（`orca worktree ...`・`orca terminal ...`）を含んではならない（MUST NOT）。手順書には環境によらない動作（「このワークスペースに印を付ける」「印が付いた子のワークスペースを片付ける」）と、それを行う `epic-dispatch.sh` のサブコマンドだけを書く（MUST）。前提の表の `orca` の行、`route` が返す値 `orca`、その条件の説明（`orca` が PATH にある）は、`orca` を実行する書き方ではないので残してよい。指示が届かなかった子の確認は、`launch` が stderr に出した確認のコマンドを指す書き方にする（SHALL）。

`plugins/dev-workflow/` 配下のシェルスクリプト（`*.sh`）のうち、`orca` の語を含むのは `scripts/epic-dispatch.sh` だけでなければならない（MUST）。`epic-dispatch.sh` の中では `orca` のコマンドをそのまま呼び、Orca の機能を自前で作り直してはならない（MUST NOT）。Orca が無い環境のための代わりの実装を持ってはならない（MUST NOT。`route` の `subagent` と `mark` の `skipped` のように、何もしないで終わる分岐は代わりの実装に数えない）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、この 2 つの検索の結果を確かめなければならない（MUST）。

#### Scenario: 手順書に orca を実行する書き方が無い
- **WHEN** `grep -rnE 'orca (worktree|terminal)' plugins/dev-workflow/skills/develop` を実行する
- **THEN** 出力は 0 行である

#### Scenario: orca を呼ぶスクリプトは 1 本だけ
- **WHEN** `grep -rlw orca plugins/dev-workflow --include='*.sh'` を実行する
- **THEN** 出力は `plugins/dev-workflow/scripts/epic-dispatch.sh` の 1 行だけである
