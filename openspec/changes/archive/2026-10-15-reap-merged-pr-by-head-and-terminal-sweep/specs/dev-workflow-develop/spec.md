## MODIFIED Requirements

### Requirement: epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` に加えて `mark` と `reap` を持たなければならない（MUST）。どちらも LLM を呼んではならない（MUST NOT）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち、次の 5 点に優先する。サブコマンドを `route`・`launch`・`wait` とする規定／`wait` が stdout にちょうど 1 行を出す規定／`wait` の子が 0 件なら使い方を出す規定／「失敗したポーリング」の定義（`--watch-done` が 1 つ以上あるときは、一覧の取得の失敗も失敗したポーリングに数える）／`wait` の終わり方の列挙（`closed`・`timeout`・`error gh` に、`done` と `error workspaces` が加わる）。

`mark` と `reap` は、環境変数 `EPIC_DISPATCH_PARENT_EPIC` の有無によらず同じに動かなければならない（MUST。並列起動された子のセッションは `EPIC_DISPATCH_PARENT_EPIC` を持ったまま自分のループを終えて `mark` を呼び、`reap` を呼ぶのは親セッションなので、どちらもこの変数の影響を受けない）。

この要件で `<ブランチ>` は、一覧の `branch` から先頭の `refs/heads/` を外した名前を言う。

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
7. マージ済み PR の先端（`headRefOid`）と `git -C <子のパス> rev-parse HEAD` の出力（以下 HEAD）が一致するかを、次の 2 段で確かめる。最終判定はどちらも「`headRefOid` が HEAD と完全一致する行がある」ことで、一致の条件は変えない
   1. `gh pr list --head <ブランチ> --state merged --json headRefOid --jq '.[].headRefOid'` が非 0 なら `kept <N> pr-lookup-failed`。出力のどれかの行が HEAD と一致すれば 7 を通る
   2. 1 で一致する行が無い（出力が空、または一致しない）ときに限り、ブランチ名を問わずに探す。`gh pr list --state merged --search <HEAD> --json headRefOid --jq '.[].headRefOid'` が非 0 なら `kept <N> pr-lookup-failed`、出力のどれかの行が HEAD と一致すれば 7 を通る（squash マージでは子の HEAD が main の祖先にならず、子のブランチと別名のブランチの PR で入ることがあるため）。一致する行が無ければ、1 と 2 の出力がどちらも空なら `kept <N> no-merged-pr`、どちらかに出力があったなら `kept <N> head-mismatch`

1〜7 をすべて通った子に限り、`orca terminal close --worktree path:<子のパス> --all`、`orca worktree rm --worktree path:<子のパス>` をこの順に 1 回ずつ呼ばなければならない（MUST）。`orca worktree rm` に `--force` を付けてはならない（MUST NOT）。close が非 0 なら rm を呼ばずに `kept <N> close-failed`、rm が非 0 なら `kept <N> rm-failed` を出す（MUST）。ただし rm が非 0 で、その stderr に `terminal sweep failed` を含むとき（Orca が端末の片付けを確かめられずに削除を止めたとき）は、理由を `rm-failed-terminal-sweep` にして `kept <N> rm-failed-terminal-sweep` を出す（MUST）。どちらの rm の失敗でも `--force` を付けた再試行をしてはならず、rm は子ごとに 1 回しか呼ばない（MUST NOT。`--force` は端末の片付けの確認だけでなく git の未コミット変更の保護も外すため。Orca を再起動してから `reap` をやり直せば通る見込みで、やり直しは親の判断に残す）。rm の stderr は従来どおり親の stderr にも流す（SHALL）。rm が exit 0 のあと、`git rev-parse --verify --quiet refs/heads/<ブランチ>` が exit 0 で、その出力が 7 で一致した HEAD と同じときだけ `git branch -D <ブランチ>` を呼ぶ（MUST）。ブランチが無いか、`git branch -D` が exit 0 なら `reaped <N>`、先端が違うか `git branch -D` が非 0 なら `reaped <N> branch-kept` を出す（MUST）。1〜7 のどれかで外れた子、close か rm が失敗した子について、`git branch -D` を呼んではならない（MUST NOT）。stdout には子ごとに 1 行だけを出し、`orca`・`git`・`gh` 自身の出力は stderr に流す（SHALL）。子ごとの行を出し終えたら、`kept` があっても exit 0 で終わる（MUST）。

この要件の守備範囲で入力として扱うのは、develop の本体が SKILL.md の手順どおりに渡す番号と、`orca worktree current --json`・`orca worktree list --json` の出力（2026-10-08、Orca 1.4.222 で確かめた `id`・`repoId`・`path`・`branch`・`linkedIssue`・`isArchived`・`isMainWorktree`・`workspaceStatus`・`parentWorktreeId`）に加え、7 の 2 段目で判定する `gh pr list --state merged --search <HEAD>` の出力（`headRefOid` の行。検索が返す PR の絞り込みは信用せず、完全一致だけで判定する）と、`orca worktree rm` の stderr（`terminal sweep failed` を含むかだけを見る。文言が変わると `rm-failed` に戻り、消す側には倒れない）である。拾いたい誤りは、印が付いていない子・親の `launch` が作っていないワークツリー・push していないコミットや未コミットの変更や `LLM/` を持つワークツリーを消すことである。次は通してよく、この要件では止めない: Orca の出力の形が変わったときの検知（読めなければ `gone` か `kept` になり、消す側には倒れない）／フォークの同名ブランチのマージ済み PR（HEAD の一致で落ちる）／オーナーがボードで手で `completed` に動かした子（子が付けた印と同じに扱う）／確認から削除までの間に子が積んだコミット（`--force` を付けない rm と、ブランチの先端の比較で残る）。`mark` は `<issue>` の PR がマージ済みかを検査しない（手順書の条件に頼る。誤って付いた印は `reap` の `no-merged-pr`・`head-mismatch` で止まる）。`.gitignore` の対象のうち `LLM/` 以外は守らない（`git status --porcelain` に出ないので、ワークツリーと一緒に消える）。すり抜ける入力が見つかるたびに確認を足すことは、この要件の完了条件としない。

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

#### Scenario: 並列起動された子のセッションでも印を付ける
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=400` を付け、`linkedIssue` が 11 のスタブ環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** `orca worktree set --worktree current --workspace-status completed` が呼ばれ、stdout は `marked 11 done` で exit 0

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

#### Scenario: 別名のブランチで入った子は先端が HEAD と一致すれば片付ける
- **WHEN** `gh pr list --head oratta/issue-11` の出力が空で、`gh pr list --state merged --search <HEAD>` の出力に HEAD と同じ `headRefOid` の行があるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` と `orca worktree rm` が 1 回ずつ呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: ブランチ名を問わない検索でも先端が一致しなければ消さない
- **WHEN** `--head` の出力が空で、`--search <HEAD>` の出力が空のスタブ環境、`--search <HEAD>` の出力が HEAD と違う `headRefOid` だけのスタブ環境、`--search <HEAD>` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca worktree rm` は呼ばれず、stdout は順に `kept 11 no-merged-pr`・`kept 11 head-mismatch`・`kept 11 pr-lookup-failed` で exit 0

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

#### Scenario: 端末の片付けの失敗で止まった rm は別の理由で返し、強制しない
- **WHEN** 条件をすべて満たす子 11 について、`orca worktree rm` が非 0 で終わり stderr に `terminal sweep failed` を含むスタブ環境、および非 0 で終わるが stderr にそれを含まないスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** 前者は stdout が `kept 11 rm-failed-terminal-sweep`、後者は `kept 11 rm-failed`、どちらも exit 0。`orca worktree rm` はどちらも 1 回だけ呼ばれ、どの `orca` の呼び出しにも `--force` が無く、`git branch -D` は呼ばれない。rm の stderr は親の stderr にも出る

#### Scenario: 複数の子は 1 件ずつ判定する
- **WHEN** 子 11 は条件をすべて満たし、子 12 は `workspaceStatus` が `in-review` のスタブ環境で `epic-dispatch.sh reap 11 12` を実行する
- **THEN** stdout は `reaped 11` と `kept 12 not-done` の 2 行で、`orca worktree rm` は子 11 のパスに 1 回だけ呼ばれ、exit 0

#### Scenario: 一覧を取れなければ何も消さない
- **WHEN** `orca worktree list` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` も `orca worktree rm` も呼ばれず、stdout は空で exit 1
