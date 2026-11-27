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
2. 候補の `isMainWorktree` が true、または `parentWorktreeId` が今のワークツリーの `id` と一致しなければ `kept <N> not-child`（この確認は要件「Orca の印を正本にした既存要件を状態の記録の項目で読み替える」により行わない）
3. 候補の `workspaceStatus` が `completed` でなければ `kept <N> not-done`
4. `git -C <子のパス> status --porcelain` が非 0 なら `kept <N> git-failed`、出力が空でなければ `kept <N> dirty`
5. `<子のパス>/LLM` が存在すれば `kept <N> llm-logs`
6. 候補の `branch` が `refs/heads/` で始まらなければ `kept <N> no-branch`
7. マージ済み PR の先端（`headRefOid`）と `git -C <子のパス> rev-parse HEAD` の出力（以下 HEAD）が一致するかを、次の 2 段で確かめる。最終判定はどちらも「`headRefOid` が HEAD と完全一致する行がある」ことで、一致の条件は変えない
   1. `gh pr list --head <ブランチ> --state merged --json headRefOid --jq '.[].headRefOid'` が非 0 なら `kept <N> pr-lookup-failed`。出力のどれかの行が HEAD と一致すれば 7 を通る
   2. 1 で一致する行が無い（出力が空、または一致しない）ときに限り、ブランチ名を問わずに探す。`gh pr list --state merged --search <HEAD> --json headRefOid --jq '.[].headRefOid'` が非 0 なら `kept <N> pr-lookup-failed`、出力のどれかの行が HEAD と一致すれば 7 を通る（squash マージでは子の HEAD が main の祖先にならず、子のブランチと別名のブランチの PR で入ることがあるため）。一致する行が無ければ、1 と 2 の出力がどちらも空なら `kept <N> no-merged-pr`、どちらかに出力があったなら `kept <N> head-mismatch`

1〜7 をすべて通った子に限り、`orca terminal close --worktree path:<子のパス> --all`、`orca worktree rm --worktree path:<子のパス>` をこの順に呼ばなければならない（MUST。rm は子ごとに 1 回、close は成功すれば 1 回）。`orca worktree rm` に `--force` を付けてはならない（MUST NOT）。close が非 0 で終わったとき（Orca が `terminal_close_incomplete` を返す場合。子のセッションが印を付けた直後でターンをまだ終えておらず、端末を閉じきれないことがある）は、次の順で 1 回だけ閉じ直さなければならない（MUST）。(a) 原因の手がかりとして `orca terminal list --worktree path:<子のパス> --json` を 1 回呼び、その出力を stderr に流す（読めなくても先へ進む）。(b) `EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT` 秒（既定 10。数字でなければ既定）待つ。(c) `orca terminal close` を同じ引数でもう 1 回呼ぶ。閉じ直しで exit 0 になれば、そのまま rm へ進む。閉じ直しも非 0 なら、rm を呼ばずに `kept <N> close-failed` を出し、stderr に主がする操作（どの画面で何をするか。Orca で子のワークスペース `<子のパス>` を開き、動いているターンの終了を待つか端末を手で閉じてから、親で `epic-dispatch.sh reap <N>` をやり直す）を 1〜2 行で出す（MUST）。閉じ直しは 1 回までで、3 回目は呼ばない（MUST NOT）。rm が非 0 なら `kept <N> rm-failed` を出す（MUST）。ただし rm が非 0 で、その stderr に `terminal sweep failed` を含むとき（Orca が端末の片付けを確かめられずに削除を止めたとき）は、理由を `rm-failed-terminal-sweep` にして `kept <N> rm-failed-terminal-sweep` を出す（MUST）。どちらの rm の失敗でも `--force` を付けた再試行をしてはならず、rm は子ごとに 1 回しか呼ばない（MUST NOT。`--force` は端末の片付けの確認だけでなく git の未コミット変更の保護も外すため。Orca を再起動してから `reap` をやり直せば通る見込みで、やり直しは親の判断に残す）。rm の stderr は従来どおり親の stderr にも流す（SHALL）。rm が exit 0 のあと、`git rev-parse --verify --quiet refs/heads/<ブランチ>` が exit 0 で、その出力が 7 で一致した HEAD と同じときだけ、`git worktree list --porcelain` にその子のパスが無くなるまで待ち（`EPIC_DISPATCH_REAP_DETACH_TIMEOUT` 秒を上限、既定 30。確認の回数（上限秒数 ÷ 間隔 + 1 回）か経過秒数のどちらか早い方で止める。`EPIC_DISPATCH_REAP_DETACH_INTERVAL` 秒間隔、既定 1。`git worktree list` が非 0 のときは残っているものとして待つ）、無くなったら、同じ一覧に `branch refs/heads/<ブランチ>` の行（別の worktree がそのブランチを checkout している）が無いことを確かめ（あれば `git update-ref -d` を呼ばず、stderr に理由を 1 行出して `reaped <N> branch-kept`。`git update-ref -d` は `git branch -D` と違い使用中のブランチも消せるため）、ブランチの先端を読み直して HEAD と同じときだけ `git update-ref -d refs/heads/<ブランチ> <HEAD>`（期待 OID つき。読み直しから削除までの間に別プロセスが ref を進めていれば Git が不一致で失敗する）を呼ぶ（MUST。違えば呼ばずに `reaped <N> branch-kept`）。上限を超えても残っているときは `git update-ref -d` を呼ばずに `reaped <N> branch-kept` を出す（MUST）。ブランチが無いか、`git update-ref -d` が exit 0 なら `reaped <N>`、先端が違うか `git update-ref -d` が非 0（期待 OID の不一致を含む）なら `reaped <N> branch-kept` を出す（MUST）。1〜7 のどれかで外れた子、close か rm が失敗した子について、`git update-ref -d` を呼んではならない（MUST NOT）。stdout には子ごとに 1 行だけを出し、`orca`・`git`・`gh` 自身の出力は stderr に流す（SHALL）。子ごとの行を出し終えたら、`kept` があっても exit 0 で終わる（MUST）。

この要件の守備範囲で入力として扱うのは、develop の本体が SKILL.md の手順どおりに渡す番号と、`orca worktree current --json`・`orca worktree list --json` の出力（2026-10-08、Orca 1.4.222 で確かめた `id`・`repoId`・`path`・`branch`・`linkedIssue`・`isArchived`・`isMainWorktree`・`workspaceStatus`・`parentWorktreeId`）に加え、7 の 2 段目で判定する `gh pr list --state merged --search <HEAD>` の出力（`headRefOid` の行。検索が返す PR の絞り込みは信用せず、完全一致だけで判定する）と、`orca terminal close` の終了コード（非 0 なら失敗として閉じ直す。失敗の種類は区別しない）と、閉じ直しの前に呼ぶ診断用の `orca terminal list --worktree path:<子のパス> --json` の出力（stderr に流すだけで、中身は読まず判定に使わない。非 0 でも先へ進む）と、`orca worktree rm` の stderr（`terminal sweep failed` を含むかだけを見る。文言が変わると `rm-failed` に戻り、消す側には倒れない）と、`orca worktree rm` が exit 0 のあとに `git worktree list --porcelain` が返す出力と終了コード（`worktree <パス>` の行だけを見て、対象の子のパスと完全一致する行があるかだけで判定する。非 0 のときは残っているものとして扱う）である。拾いたい誤りは、対象のワークツリーが git に残っている間にそのブランチを消そうとして失敗すること（残っている間は消さずに待つ。上限を超えたら消さずに `branch-kept`）、印が付いていない子・親の `launch` が作っていないワークツリー・push していないコミットや未コミットの変更や `LLM/` を持つワークツリーを消すことである。次は通してよく、この要件では止めない: 一覧に対象以外のパスだけがある（対象のパスは無い。パスの前方一致・部分一致は残っている扱いにしない）ときは待たずにブランチ削除へ進む／Orca の出力の形が変わったときの検知（読めなければ `gone` か `kept` になり、消す側には倒れない）／フォークの同名ブランチのマージ済み PR（HEAD の一致で落ちる）／オーナーがボードで手で `completed` に動かした子（子が付けた印と同じに扱う）／確認から削除までの間に子が積んだコミット（`--force` を付けない rm と、ブランチの先端の比較で残る）。`mark` は `<issue>` の PR がマージ済みかを検査しない（手順書の条件に頼る。誤って付いた印は `reap` の `no-merged-pr`・`head-mismatch` で止まる）。`.gitignore` の対象のうち `LLM/` 以外は守らない（`git status --porcelain` に出ないので、ワークツリーと一緒に消える）。すり抜ける入力が見つかるたびに確認を足すことは、この要件の完了条件としない。

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
- **WHEN** 上の Scenario から 1 点だけを変えたスタブ環境（`workspaceStatus` が `in-review`／ワークツリーの HEAD が PR の `headRefOid` と違う／`git status --porcelain` に出力がある／`<子>/LLM` がある）それぞれで `epic-dispatch.sh reap 11` を実行する
- **THEN** どの場合も `orca terminal close`・`orca worktree rm`・`git update-ref -d` は 1 回も呼ばれず、stdout は順に `kept 11 not-done`・`kept 11 head-mismatch`・`kept 11 dirty`・`kept 11 llm-logs` の 1 行で exit 0

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
- **THEN** 前者は `git update-ref -d refs/heads/oratta/issue-11 <HEAD>` が 1 回呼ばれて stdout は `reaped 11`、後者は `git update-ref -d` が呼ばれず stdout は `reaped 11 branch-kept`、どちらも exit 0

#### Scenario: ブランチが残っていなければ git update-ref -d を呼ばない
- **WHEN** `orca worktree rm` のあと `git rev-parse --verify --quiet refs/heads/oratta/issue-11` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git update-ref -d` は呼ばれず、stdout は `reaped 11` で exit 0

#### Scenario: 端末を閉じられなければ 1 回だけ閉じ直し、それでも閉じられなければワークツリーを消さない
- **WHEN** `orca terminal close` が常に非 0 で終わり、待ち時間を 0 秒にしたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` はちょうど 2 回呼ばれ、`orca worktree rm` と `git update-ref -d` は呼ばれず、stdout は `kept 11 close-failed` の 1 行で exit 0。stderr には主がする操作（`issue-11` のワークスペースを Orca で開いて端末を閉じ、`epic-dispatch.sh reap 11` をやり直す）が出る

#### Scenario: 1 回目の閉じが不完全でも、閉じ直しで成功すれば片付ける
- **WHEN** `orca terminal close` が 1 回目は非 0、2 回目は exit 0 で終わるスタブ環境（ほかは全部の確認を通る子）で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` はちょうど 2 回呼ばれ、`orca worktree rm` が 1 回呼ばれ、stdout は `reaped 11` の 1 行で exit 0

#### Scenario: 端末の片付けの失敗で止まった rm は別の理由で返し、強制しない
- **WHEN** 条件をすべて満たす子 11 について、`orca worktree rm` が非 0 で終わり stderr に `terminal sweep failed` を含むスタブ環境、および非 0 で終わるが stderr にそれを含まないスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** 前者は stdout が `kept 11 rm-failed-terminal-sweep`、後者は `kept 11 rm-failed`、どちらも exit 0。`orca worktree rm` はどちらも 1 回だけ呼ばれ、どの `orca` の呼び出しにも `--force` が無く、`git update-ref -d` は呼ばれない。rm の stderr は親の stderr にも出る

#### Scenario: 複数の子は 1 件ずつ判定する
- **WHEN** 子 11 は条件をすべて満たし、子 12 は `workspaceStatus` が `in-review` のスタブ環境で `epic-dispatch.sh reap 11 12` を実行する
- **THEN** stdout は `reaped 11` と `kept 12 not-done` の 2 行で、`orca worktree rm` は子 11 のパスに 1 回だけ呼ばれ、exit 0

#### Scenario: 一覧を取れなければ何も消さない
- **WHEN** `orca worktree list` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` も `orca worktree rm` も呼ばれず、stdout は空で exit 1

#### Scenario: rm のあとしばらくワークツリーが git に残っても、外れたらブランチを消す
- **WHEN** `orca worktree rm` が exit 0 で、その後 `git worktree list --porcelain` に子のパスが 2 回目の確認まで残り、先端が HEAD と同じブランチが残るスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git update-ref -d refs/heads/oratta/issue-11 <HEAD>` が 1 回呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: 上限を超えても残るなら branch-kept
- **WHEN** `git worktree list --porcelain` が常に子のパスを返し、上限を短くしたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git update-ref -d` は呼ばれず、stdout は `reaped 11 branch-kept` で exit 0

#### Scenario: 別の worktree が checkout しているブランチは消さない
- **WHEN** `orca worktree rm` が exit 0 で、`git worktree list --porcelain` に子のパスは無いが、別のパスの worktree が `branch refs/heads/oratta/issue-11` を持ち、先端が HEAD と同じブランチが残るスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git update-ref -d` は呼ばれず、ブランチは残り、stdout は `reaped 11 branch-kept` で exit 0。別の worktree が `branch refs/heads/oratta/issue-110`（前方一致の別ブランチ）を持つだけなら、`git update-ref -d refs/heads/oratta/issue-11 <HEAD>` が 1 回呼ばれて stdout は `reaped 11`

#### Scenario: 先端が HEAD と違うブランチは待たずに消さない
- **WHEN** ブランチの先端が HEAD と違い、`git worktree list --porcelain` に子のパスが残るスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git worktree list` を繰り返し呼んで待つことはなく、`git update-ref -d` は呼ばれず、stdout は `reaped 11 branch-kept` で exit 0

#### Scenario: 一覧に対象以外のパスだけがあるときは待たずにブランチを消す
- **WHEN** `git worktree list --porcelain` が `/work/issue-110`（子 11 のパスの前方一致）と別のワークツリーのパスだけを返し、先端が HEAD と同じブランチが残るスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git update-ref -d refs/heads/oratta/issue-11 <HEAD>` が 1 回呼ばれ、stdout は `reaped 11` で exit 0

### Requirement: epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける
この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の確認 7（マージ済み PR の先端と HEAD の一致）で一致する行が無かったときの扱いに優先しなければならない（MUST）。7 の 1 段・2 段の出力の取り方、一致したときの扱い、1〜6 の確認、片付け（`orca terminal close` → `--force` なしの `orca worktree rm` → ローカルブランチの削除）の手順は変えない。

`reap` は、7 の 1 段と 2 段のどちらでも HEAD と一致する行が無く、HEAD（`git -C <子のパス> rev-parse HEAD` の出力）が空でない子について、従来の理由を出す前に次の順で確かめなければならない（MUST）。以下で「従来の理由」は、7 の 1 段と 2 段の出力がどちらも空なら `no-merged-pr`、どちらかに出力があれば `head-mismatch` を指す。外れた時点でその子についてはそれ以上何も呼ばず、対応する 1 行を出して次の子へ進まなければならない（MUST）。HEAD が空の子は従来どおり従来の理由を出す（MUST）。

1. `gh pr list --head <ブランチ> --state all --json number --jq '.[].number'` が非 0 なら `kept <N> pr-lookup-failed`。出力が空でなければ（状態を問わずそのブランチの PR がある）`kept <N> <従来の理由>`
2. `gh api repos/{owner}/{repo}/issues/<N> --jq .state` が非 0 なら `kept <N> issue-lookup-failed`。出力が `closed` でなければ `kept <N> <従来の理由>`
3. リモートの今の base の先端（以下 base の先端）を `git ls-remote origin refs/heads/<base>` で取る。`<base>` は環境変数 `EPIC_DISPATCH_BASE` の値で、未設定か空なら `main`。`git ls-remote` が非 0 か、出力の 1 列目に 40 桁の 16 進の commit ID が無ければ `kept <N> base-lookup-failed`
4. `git cat-file -e <base の先端>^{commit}` が非 0 なら（base の先端の commit が手元に無い）、`git fetch origin <base>` を呼んでから `git cat-file -e` をもう 1 回呼ぶ。それでも非 0 なら（fetch が非 0 だったときを含む）`kept <N> base-lookup-failed`
5. `git -C <子のパス> merge-base --is-ancestor <HEAD> <base の先端>` を呼ぶ。exit 0 なら通る。exit 1 なら `kept <N> unmerged-commits`、それ以外の終了コードなら `kept <N> git-failed`

祖先の判定の相手に手元の追跡参照（`refs/remotes/origin/<base>`）を使ってはならない（MUST NOT。リモートの base が force push で巻き戻されたあと、古い追跡参照と子の HEAD が同じなら判定が通り、今の base に無い commit を持つブランチを消してしまうため）。`git ls-remote` は 1 回の `reap` の呼び出しで最大 1 回だけ呼び、その結果（失敗を含む）を後の子に使い回さなければならない（MUST）。`git fetch` も 1 回の `reap` の呼び出しで最大 1 回とし、2 件目以降の子で base の先端の commit が手元に無ければ fetch を呼ばずに `kept <N> base-lookup-failed` とする（MUST）

1〜5 をすべて通った子は、7 を通った子と同じ手順で片付けなければならない（MUST）。ローカルブランチの削除の条件（先端が HEAD と同じとき・`git worktree list` から外れるのを待つこと・消す直前に先端を読み直すこと）と、出す行（`reaped <N>` / `reaped <N> branch-kept` / `kept <N> close-failed` / `kept <N> rm-failed` / `kept <N> rm-failed-terminal-sweep`）も同じとする（MUST）。

`reap` は issue の `state_reason` を見てはならない（MUST NOT。消してよいかは main に入っていない commit が無いことで決まり、閉じ方の理由で変わらないため）。`git fetch` は 4 の場合のほかに呼んではならない（MUST NOT）。7 で HEAD と一致する行があった子について、1〜5 のどれも呼んではならない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の入力に加え、`gh pr list --head <ブランチ> --state all` の出力の有無と終了コード、`gh api repos/{owner}/{repo}/issues/<N> --jq .state` の出力と終了コード、`git ls-remote origin refs/heads/<base>` の出力と終了コード、`git cat-file -e`・`git fetch origin <base>`・`git merge-base --is-ancestor` の終了コードである。拾いたい誤りは、PR を作らず issue を閉じた子のワークツリーが `no-merged-pr`・`head-mismatch` で残り続けること、および今のリモートの base に入っていない commit（base の巻き戻しで消えた commit を含む）・マージされていない PR・開いている issue を持つ子を消すことである。次は通してよく、この要件では止めない: `.gitignore` の対象のうち `LLM/` 以外（既存の要件と同じく守らない）／`--base` で main 以外から起動したのに `EPIC_DISPATCH_BASE` を設定していない親の子（`unmerged-commits` か `git-failed` で残る）／`git ls-remote` で base の先端を取ってから子のワークツリーを消すまでの間に、リモートの base が巻き戻されること／fetch と ls-remote の間に base がさらに進み、先端の commit が手元に無いままの子（`base-lookup-failed` で残り、次の `reap` で通る）。すり抜ける入力が見つかるたびに確認を足して塞ぎ切ることは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、下の Scenario を確かめなければならない（MUST）。

#### Scenario: PR が無く issue を閉じ、HEAD がリモートの今の main に含まれる子は片付ける
- **WHEN** 要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の 1〜6 を満たす子 11 について、`gh pr list` の出力が `--state merged`・`--search <HEAD>`・`--state all` のどれでも空、`gh api repos/{owner}/{repo}/issues/11 --jq .state` の出力が `closed`、`git ls-remote origin refs/heads/main` の出力が base の先端 `ccc333…`（40 桁）の 1 行、`git cat-file -e` が exit 0、`git -C <子> merge-base --is-ancestor <HEAD> <base の先端>` が exit 0 のスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close --worktree path:<子> --all` と `orca worktree rm --worktree path:<子>` がこの順に 1 回ずつ呼ばれ、どの `orca` の呼び出しにも `--force` が無く、`git merge-base --is-ancestor` は `refs/remotes/origin/main` ではなく base の先端の commit ID に対して呼ばれ、`git fetch` は呼ばれず、stdout は `reaped 11` の 1 行で exit 0

#### Scenario: main の先端の PR が検索に出ても、PR の無い子は片付ける
- **WHEN** 上の Scenario から、`--search <HEAD>` の出力だけを HEAD と違う `headRefOid` の 1 行に変えたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca worktree rm` が 1 回呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: PR がある子は issue が閉じていても従来の理由で残す
- **WHEN** 最初の Scenario から、`--state all` の出力だけを 1 行（PR の番号）に変えたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `gh api`・`git merge-base`・`orca terminal close`・`orca worktree rm` は 1 回も呼ばれず、stdout は `kept 11 no-merged-pr` で exit 0

#### Scenario: issue が開いている子は従来の理由で残し、状態を読めなければ issue-lookup-failed
- **WHEN** 最初の Scenario から、issue の状態の出力を `open` に変えたスタブ環境、`gh api` が非 0 で終わるスタブ環境、`--state all` の `gh pr list` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** どれも `git merge-base`・`orca worktree rm` は呼ばれず、stdout は順に `kept 11 no-merged-pr`・`kept 11 issue-lookup-failed`・`kept 11 pr-lookup-failed` で exit 0

#### Scenario: main に入っていない commit がある子と、祖先を判定できない子は残す
- **WHEN** 最初の Scenario から、`git merge-base --is-ancestor` の終了コードを 1 に変えたスタブ環境と 128 に変えたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** どちらも `orca terminal close`・`orca worktree rm`・`git update-ref -d` は呼ばれず、stdout は順に `kept 11 unmerged-commits`・`kept 11 git-failed` で exit 0

#### Scenario: リモートの base が巻き戻されていれば、古い追跡参照と同じ HEAD の子も残す
- **WHEN** 最初の Scenario から、手元の `refs/remotes/origin/main` が子の HEAD と同じ（巻き戻し前の先端）で、`git ls-remote` が返す base の先端が巻き戻し後の別の commit、その先端に対する `git merge-base --is-ancestor <HEAD> <base の先端>` が exit 1 のスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close`・`orca worktree rm`・`git update-ref -d` は呼ばれず、stdout は `kept 11 unmerged-commits` で exit 0

#### Scenario: リモートの base を読めない子は残す
- **WHEN** 最初の Scenario から、`git ls-remote` が非 0 で終わるスタブ環境、`git ls-remote` の出力が空のスタブ環境、`git cat-file -e` が常に非 0 で `git fetch` が非 0 で終わるスタブ環境、`git cat-file -e` が常に非 0 で `git fetch` が exit 0 のスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** どれも `git merge-base`・`orca worktree rm` は呼ばれず、stdout は `kept 11 base-lookup-failed` で exit 0

#### Scenario: 先端の commit が手元に無ければ 1 回だけ fetch してから判定する
- **WHEN** 子 11 と子 12 がどちらも最初の Scenario の条件を満たし、`git cat-file -e` が 1 回目だけ非 0 で 2 回目以降は exit 0 のスタブ環境で `epic-dispatch.sh reap 11 12` を実行する
- **THEN** `git ls-remote` と `git fetch origin main` はそれぞれ 1 回だけ呼ばれ、stdout は `reaped 11` と `reaped 12` の 2 行で exit 0

#### Scenario: 起点のブランチは EPIC_DISPATCH_BASE で変わる
- **WHEN** 最初の Scenario の環境で、`EPIC_DISPATCH_BASE=develop` を付けて `epic-dispatch.sh reap 11` を実行する
- **THEN** `git ls-remote` は `origin refs/heads/develop` に対して呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: マージ済み PR で一致した子には PR の無い子の確認を呼ばない
- **WHEN** 要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の Scenario「条件をすべて満たす子は端末を閉じてからワークツリーを消す」の環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `gh pr list --state all`・`gh api`・`git ls-remote`・`git fetch`・`git merge-base` は 1 回も呼ばれず、stdout は `reaped 11` で exit 0
