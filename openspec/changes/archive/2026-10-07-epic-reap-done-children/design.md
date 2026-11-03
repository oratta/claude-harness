## Context

Orca 経路のエピックでは、親セッション（エピックの解決セッション）が `epic-dispatch.sh launch` で子ごとに Orca の子ワークツリーと Claude Code のセッションを作り、`epic-dispatch.sh wait` を背景で走らせて子 issue のクローズを待つ。子のワークツリーを消す手順はどこにも無く、マージ後も Claude のタブごと残る。

エピック #811 で次が決まっている（この設計で覆さない）。

- 片付けの合図は、子が自分で Orca のボードの列を `completed` にすること。子 issue のクローズや Orca の完了通知は使わない
- 子が `completed` にしたことを、そのワークツリーを消す承認として扱う。消すのは安全確認を通った子だけ
- `orca` のコマンドを呼ぶのは 1 本のスクリプトだけ。develop の手順書には `orca` のコマンドを書かない。Orca の有無での切り替えは作らない
- 片付けも判定もシェルで行う。wt-clean は呼ばず、wt-clean・wt-setup は触らない

調べた実物（2026-10-08、Orca 1.4.222）:

- `grep -rnw orca plugins/dev-workflow --include='*.sh'` に出るスクリプトは `plugins/dev-workflow/scripts/epic-dispatch.sh` だけ
- develop の手順書（`plugins/dev-workflow/skills/develop/` 配下）で `orca` のコマンドを書いているのは `SKILL.md` の 1 か所（`orca terminal read`）。ほかの `orca` は、前提の表の行の名前、`route` が返す値、「`orca` が PATH にあり」という条件の説明
- `orca worktree list --json` の `.result.worktrees[]` は `id`（`<repoId>::<パス>`）・`repoId`・`path`・`branch`（`refs/heads/...`）・`linkedIssue`（数値か null）・`isArchived`・`isMainWorktree`・`workspaceStatus`（`in-progress` など）・`parentWorktreeId`（親の `id` と同じ形）を持つ。`orca worktree current --json` の `.result.worktree` も同じ項目を持つ
- `orca worktree rm` は `--force` の有無によらずローカルブランチの削除も試みるが、変更がマージ済みと証明できないブランチは残す（help の記載）。squash マージではブランチが残る
- `orca terminal close --worktree <selector> --all` は、そのワークスペースの端末のプロセスを止め、タブと再開の記録を消す
- `orca worktree set --worktree <selector> --workspace-status <id>` の既定の id は `todo`・`in-progress`・`in-review`・`completed`

## Goals / Non-Goals

**Goals:**

- 子が完了の印を付けたワークツリーを、親が Bash 1 回で、Orca のサイドバーとボード・`git worktree list`・ローカルブランチから消す
- マージ後にオーナーの確認を待っている子のワークツリーを消さない
- push していないコミット・未コミットの変更・`LLM/` の会話ログを失わない
- develop の手順書に環境によらない動作だけを書く

**Non-Goals:**

- サブエージェント方式の子（Claude Code の `isolation: "worktree"`）の片付け
- 手で `/wt-clean` を実行したときに Orca 管理のワークツリーを `orca worktree rm` で消す変更
- `launch --note` の引き継ぎと `route` の `nested` 判定の変更（子 issue #809 の範囲）
- Orca が無い環境で同じ動きをする代わりの実装

## Decisions

### 1. `orca` を呼ぶ 1 本のスクリプトは `epic-dispatch.sh` のままにする

`mark`・`reap`・`wait` の拡張はすべて `epic-dispatch.sh` のサブコマンドとして足す。

退けた案は「Orca のコマンドだけを集めた新しいスクリプトを作り、`epic-dispatch.sh` からそれを呼ぶ」。退けた理由は 3 つある。

- いま `orca` を呼んでいるのは `epic-dispatch.sh` だけで、条件「1 本だけ」は既に満たされている。切り出すと `launch` の約 100 行（`orca` の呼び出しと失敗時の案内が交互に並ぶ）を振る舞いを変えずに移すことになり、2 本のスクリプトの間に新しい受け渡しの契約（出力と終了コード）が増える
- issue #805 と、後続の子 issue #809 の「触るファイル」は、どちらも `epic-dispatch.sh` だけを挙げている。#809 は「環境依存の処理を置く 1 本のスクリプトのサブコマンド」として親子関係の取得を足す前提で、それを `epic-dispatch.sh` に足せばそのまま成り立つ
- 別の環境に移るときに差し替える単位は「サブコマンドの名前・引数・stdout の行・終了コードが同じスクリプト」であればよく、ファイルが 1 本か 2 本かは差し替えやすさを変えない。手順書が頼るのはこの契約だけにする

この案を選ぶと、`epic-dispatch.sh` には環境によらない処理（`wait` の `gh` によるポーリング）も同居したままになる。別の環境に移るときは、その部分も新しいスクリプトに書き写すことになる。

### 2. 印を付けるサブコマンドは `mark <done|waiting> <issue>` にし、引数に Orca の語を使わない

手順書に書くのは `done`（用が済んだ）と `waiting`（オーナーの確認待ち）で、Orca の列の id（`completed` / `in-review`）への対応はスクリプトの中に置く。

`<issue>` を必須にし、今いるワークスペースの `linkedIssue` がその番号と一致するときだけ印を付ける。一致しなければ `skipped <issue> not-linked` を出して exit 0 で終わる。理由は、サブエージェント方式のエピックでは親セッション自身が子のループを回すので、番号を確かめないと、最初の子が終わった時点で親のワークスペース（`linkedIssue` はエピックの番号）に完了の印が付いてしまうため。この確認をスクリプトに置くと、手順書は「記録先が issue なら、ループの最後に必ず 1 回呼ぶ」とだけ書けて、セッションが「自分はエピックの子か」を判断しなくて済む（起動し直したセッションはそれを知らない）。

`orca` が PATH に無い、または `orca worktree current` が非 0 で終わる（Orca 管理外）ときは `skipped <issue> no-workspace` を出して exit 0 で終わる。これは issue #805 の「Orca 管理外のワークツリーや、`orca` が無い環境では何もしない」のとおりで、代わりの実装（ファイルに印を書くなど）は持たない。エピック #811 が禁じている「Orca の有無での切り替え」は代わりの実装を持つことを指すと読み、何もしないで終わる分岐は切り替えに数えない（`route` が既に同じ判定で `subagent` を返している）。

### 3. `wait` は `--watch-done <N>` を付けたときだけ完了の印を見る

`wait [--interval <sec>] [--timeout <sec>] [--watch-done <N>]... [<child>...]`。位置引数の子は今までどおり issue の state を `gh` で見る。`--watch-done` の子は、ポーリングごとに 1 回の `orca worktree list --json` で、同じ `repoId`・`linkedIssue` が `<N>`・archive されていない・`workspaceStatus` が `completed` のワークツリーがあるかを見る。`gh` の呼び出しは増えない。

2 つの一覧を分けた理由は 2 つある。閉じた子は、マージの直後から数時間後（オーナーの確認が済んだあと）までのどこかで完了の印が付くので、issue を見る対象から外れたあとも印は見続ける必要がある。逆に、片付けの安全確認に落ちて残した子は、印が付いたままなので、印を見る対象から外さないと `wait` がすぐ終わり続ける。

出力は、閉じた子がいれば `closed <N>...`、印の付いた子がいれば `done <N>...` で、両方あれば `closed` の行が先の 2 行になる。`--watch-done` を付けない呼び出しは今までどおりちょうど 1 行で、`orca` を呼ばない（既存のテストはそのまま通る）。位置引数が 0 件でも `--watch-done` が 1 件以上あれば受け付ける（全部の子が閉じたあと、確認待ちの子だけを待つため）。

一覧の取得に失敗したポーリングは、`gh` の失敗と同じく「失敗したポーリング」に数える。3 回続いたとき、`gh` で失敗した子がいれば今までどおり `error gh <N>...`、いなければ `error workspaces` を出して exit 1 で終わる。黙って上限時間まで待ち続けないようにするため。

### 4. `reap <child>...` は安い確認から順に行い、1 つでも外れたら何も消さない

issue #805 の仮名 `reap <エピック番号> <子>...` からエピック番号を外した。親の `launch` が作ったワークツリーかどうかは、子の `parentWorktreeId` が今いるワークツリーの `id` と一致することで確かめられ、エピック番号を足しても確かめられることが増えないため。

子ごとの確認の順と、外れたときの出力は次のとおり。確認はローカルで済むものを先に、`gh` を呼ぶものを最後に置く。

| 順 | 確かめること | 外れたときの出力 |
|---|---|---|
| 1 | 一覧に、同じ `repoId`・`linkedIssue` が `<N>`・archive されていないワークツリーがある | 0 件なら `gone <N>`、2 件以上なら `kept <N> ambiguous` |
| 2 | `isMainWorktree` が true でなく、`parentWorktreeId` が今いるワークツリーの `id` と一致する | `kept <N> not-child` |
| 3 | `workspaceStatus` が `completed` | `kept <N> not-done` |
| 4 | `git -C <子> status --porcelain` が exit 0 で、出力が空 | 非 0 なら `kept <N> git-failed`、出力があれば `kept <N> dirty` |
| 5 | `<子>/LLM` が存在しない | `kept <N> llm-logs` |
| 6 | 一覧の `branch` が `refs/heads/` で始まる（ブランチ上にいる） | `kept <N> no-branch` |
| 7 | `gh pr list --head <ブランチ> --state merged --json headRefOid --jq '.[].headRefOid'` が exit 0 で、出力のどれかの行が `git -C <子> rev-parse HEAD` と一致する | `gh` が非 0 なら `kept <N> pr-lookup-failed`、出力が空なら `kept <N> no-merged-pr`、一致が無ければ `kept <N> head-mismatch` |

`LLM/` を `git status` と別に見るのは、`.gitignore` に入っていると `git status` に出ないため。

全部通った子だけ、`orca terminal close --worktree path:<子> --all` → `orca worktree rm --worktree path:<子>` の順に呼ぶ（`--force` は付けない）。close が非 0 なら rm を呼ばずに `kept <N> close-failed`、rm が非 0 なら `kept <N> rm-failed` を出す。

そのあと、ローカルブランチが残っていれば（`git rev-parse --verify --quiet refs/heads/<ブランチ>` が exit 0）、その先端が順 7 で一致した HEAD と同じときだけ `git branch -D <ブランチ>` を呼び、`reaped <N>` を出す。先端が違うか、`git branch -D` が非 0 なら、ブランチを残して `reaped <N> branch-kept` を出す。確認のあとから削除までの間に子がコミットを積んだ場合、`orca worktree rm` は `--force` が無いので未コミットの変更を理由に止まり、コミット済みの分はこのブランチの先端の比較で残る。

終了コードは、子ごとの行を出し終えれば `kept` があっても 0。`orca`・`jq` が無い、`orca worktree current --json` か `orca worktree list --json` が失敗したときは、何も消さず、stdout に何も出さずに exit 1。

### 5. 手順書に書かない「`orca` のコマンド」の範囲と測り方

`orca worktree ...`・`orca terminal ...` のように `orca` を実行する書き方を手順書から無くす。測り方は `grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` が 0 行。

最初は `orca (worktree|terminal)` に限っていたが、`orca [a-z]+` に広げた。2026-10-08 に実物で `grep -rnoE 'orca [a-z]+' plugins/dev-workflow/skills/develop` を流すと、出るのは `SKILL.md:309` の `orca terminal` の 1 件だけだった。前提の表や「`orca` が PATH にあり」の `orca` は直後が日本語か記号なので当たらない。広げても今の手順書で誤検知は出ず、`orca repo` のような別系統のサブコマンドを書き足したときも拾える。

`orca` の語そのものは残る。既存の要件「前提環境を明記する」が前提の表に `orca` の行を求め、「エピックの条件・作り方・回し方・完了条件を規定する」が `route` の返す値 `orca` と、その条件（`orca` が PATH にある）を書くことを求めているため。これらは `orca` を実行する手順ではない。

いま 1 か所ある `orca terminal read`（指示が届かなかった子の確認）は「stderr に出た確認のコマンド」に言い換える。コマンドそのものは `launch` が stderr に出しているので、手順書に写す必要が無い。

### 6. ループの終わりの規定は SKILL.md の新しい節に置く（#459 と同じ箇所）

`plugins/dev-workflow/skills/develop/SKILL.md` の「1 ループ」の節のうしろに「ループの終わり」の節を足す。本体が読むファイルで、起動し直したセッションも `/develop` で必ず読むため。子への指示（`launch --note`）には書かない。

書くことは 2 つ。ワークツリーの片付けを提案も質問もしないこと（#459）と、最後のツール呼び出しとして `mark` を 1 回呼ぶこと。呼ぶ条件は、記録先が issue で、PR がマージ済みのとき。オーナーに頼むことが残っていなければ `done`、完了報告にマージ後の依頼（動作確認など）を書いたなら `waiting` で、オーナーが済んだと返事をしたら `done` で呼び直す。PR がマージされていない（保留・マージ待ち・unmanned）ときと、記録先が Draft PR のときは呼ばない。

PR がマージされていない子に `waiting` を付けない理由は 3 つある。issue #805 は `in-review` を「マージ後にオーナーにしてほしいことを報告に書いたとき」の列と決めていて、マージ前の止まり方（保留・マージ待ち）をこの列に入れると、オーナーがボードを見たときに「マージの判断待ち」と「マージ後の確認待ち」を見分けられなくなる。片付けの側では、`reap` が見るのは `completed` だけで、マージされていない子は印の有無によらず消えない（印があっても `no-merged-pr` で残る）ので、印を付けても動きが変わらない。あとでそのセッションが再開されて PR がマージされれば、そのループの終わりで `mark` が呼ばれる。

`mark` を最後に置くのは、印が付くと最短で次のポーリング（既定 300 秒以内）に親が端末を閉じるので、完了報告を書き終えてから印を付けるため。`reap` の側に「印が付いてから一定時間は消さない」という猶予は足さない。時間で見分ける案は issue #805 の経緯で退けられていて（備考）、完了報告は印の前に書き終える手順にしてあり、会話ログはワークツリーを消しても残るため。

#459 の質問の出どころは、develop の手順書・`commands/develop.md`・pr-review-gate の手順・worktree プラグインの hooks を `片付け`・`クリーン`・`wt-clean`・`clean` で検索しても該当する指示が無いので、手順書が聞かせているのではなく、セッションが自分から聞いていると判断した。実装の工程で、検索の結果（コマンドと該当ファイル:行）を #459 にコメントする。

### 7. 親の側の動き（SKILL.md「エピックの扱い」の Orca 経路）

- `wait` には、`launch` に渡したことのある子（閉じた子を含む）を `--watch-done` で渡す。ただしエピックに `子 #N のワークツリーを残した` の行がある子は渡さない
- `done <N>...` で起こされたら `reap <N>...` を 1 回呼ぶ。`reaped <N>`・`gone <N>` は何もしない。`reaped <N> branch-kept` と、`not-done` 以外の `kept <N> <理由>` は、エピックに 1 行コメントしてオーナーの判断に残し、手で消し直さない。`kept <N> not-done` は待ちを続ける
- 開いている子が無くなったら、`--watch-done` に渡す子と同じ集合（`launch` に渡したことのある子から、`子 #N のワークツリーを残した` の行がある子を除いたもの）で `reap` を 1 回呼び、`kept <N> not-done` の子だけを `--watch-done` に渡して待ちを続ける。エピックの完了条件の確認と報告は、この待ちを理由に遅らせない。この待ちが `timeout` で終わったら、残っている子をユーザーに報告して待ちをやめる（6 時間ごとに親のターンを使い続けないため）
- Orca 経路を引き継いで再開したら、`launch` の前に、`launch` に渡したことのある子（閉じた子を含む）で `reap` を 1 回呼ぶ（待ちをやめたあとに印が付いた子を拾うため）。ここでは `子 #N のワークツリーを残した` の行がある子も除かない。オーナーが残した理由を片付けたあとで再開したとき、もう一度確かめるため（条件を満たさなければ同じ `kept` が出るだけで、何も消さない）
- `--watch-done` 付きの `wait` が stdout に何も出さず exit 1 で終わったら、今のワークツリーを Orca から読めないので、`launch` の exit 1 と同じく「Orca の親ワークツリーで開き直す」とユーザーに報告して止まる
- `mark` と `reap` は `EPIC_DISPATCH_PARENT_EPIC` を見ない。この変数は並列起動された子のセッションが持っていて、子はその状態のまま自分のループの終わりで `mark` を呼ぶため。`reap` は親セッションが呼ぶので、変数の有無で動きを変える理由が無い

### 8. delta spec は ADDED で書き、既存の要件に優先する箇所を明記する

`epic-dispatch.sh` の既存の要件は 1 段落が非常に長く、MODIFIED にすると全文を写すことになって差分が読めない。既存の「エピックの並列起動は 1 段で止める」と同じ形で、新しい要件を ADDED で足し、既存の要件のどの規定に優先するかを書く。優先するのは次の 5 点。「サブコマンドは `route`・`launch`・`wait`」／`wait` の「stdout にちょうど 1 行」／「子が 0 件なら使い方を出す」／「失敗したポーリング」の定義（`--watch-done` があるときは一覧の取得の失敗も数える）／`wait` の終わり方の列挙（`closed`・`timeout`・`error gh` に `done` と `error workspaces` が加わる）。

`reap` の `<ブランチ>` は、一覧の `branch` から先頭の `refs/heads/` を外した名前とする（delta spec にも同じ定義を置いた）。

## Risks / Trade-offs

- **子が印を付けたあとも書き続けていると、完了報告の途中で端末が閉じる** → 手順書で `mark` をループの最後のツール呼び出しに置く。会話ログ（`~/.claude/projects/` の jsonl）はワークツリーを消しても残る（issue #805 備考）。それでも、印のあとに長い文章を書くセッションでは末尾が画面に出ないまま閉じることがある
- **`orca worktree list --json` の項目名が Orca の更新で変わると、印を検知できない・全部 `gone` になる** → 既存の要件と同じく、確かめた形（2026-10-08、Orca 1.4.222）のとおりと信じ、形の変化の検知は範囲外とする。`gone` は何も消さないので、誤って消す側には倒れない
- **`gh pr list --head <ブランチ>` は、フォークの同名ブランチのマージ済み PR も返しうる** → HEAD の一致を求めているので、別の PR の最終コミットがワークツリーの HEAD と一致しないかぎり通らない
- **編集するファイルが 5 個を超える**（スクリプト・テスト・SKILL.md・README 2 つ・変更の記録・spec） → エピック #811 が既存 issue 4 件を同じ PR にまとめると決めているための数で、README 2 つと変更の記録は 1〜数行の直し。実装の工程で規模超過として止めるかどうかは本体が決める
- **確認待ちの子だけを待つ `wait` が `timeout` で終わると、親は待ちをやめる** → そのあとに付いた印は、エピックを再開するまで拾われない。再開時に `reap` を 1 回呼ぶことで拾う
