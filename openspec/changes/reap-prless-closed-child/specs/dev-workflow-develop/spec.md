## ADDED Requirements

### Requirement: epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける
この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の確認 7（マージ済み PR の先端と HEAD の一致）で一致する行が無かったときの扱いに優先しなければならない（MUST）。7 の 1 段・2 段の出力の取り方、一致したときの扱い、1〜6 の確認、片付け（`orca terminal close` → `--force` なしの `orca worktree rm` → ローカルブランチの削除）の手順は変えない。

`reap` は、7 の 1 段と 2 段のどちらでも HEAD と一致する行が無く、HEAD（`git -C <子のパス> rev-parse HEAD` の出力）が空でない子について、従来の理由を出す前に次の順で確かめなければならない（MUST）。以下で「従来の理由」は、7 の 1 段と 2 段の出力がどちらも空なら `no-merged-pr`、どちらかに出力があれば `head-mismatch` を指す。外れた時点でその子についてはそれ以上何も呼ばず、対応する 1 行を出して次の子へ進まなければならない（MUST）。HEAD が空の子は従来どおり従来の理由を出す（MUST）。

1. `gh pr list --head <ブランチ> --state all --json number --jq '.[].number'` が非 0 なら `kept <N> pr-lookup-failed`。出力が空でなければ（状態を問わずそのブランチの PR がある）`kept <N> <従来の理由>`
2. `gh api repos/{owner}/{repo}/issues/<N> --jq .state` が非 0 なら `kept <N> issue-lookup-failed`。出力が `closed` でなければ `kept <N> <従来の理由>`
3. `git -C <子のパス> merge-base --is-ancestor <HEAD> refs/remotes/origin/<base>` を呼ぶ。`<base>` は環境変数 `EPIC_DISPATCH_BASE` の値で、未設定か空なら `main`。exit 0 なら通る。exit 1 なら `kept <N> unmerged-commits`、それ以外の終了コードなら `kept <N> git-failed`

1〜3 をすべて通った子は、7 を通った子と同じ手順で片付けなければならない（MUST）。ローカルブランチの削除の条件（先端が HEAD と同じとき・`git worktree list` から外れるのを待つこと・消す直前に先端を読み直すこと）と、出す行（`reaped <N>` / `reaped <N> branch-kept` / `kept <N> close-failed` / `kept <N> rm-failed` / `kept <N> rm-failed-terminal-sweep`）も同じとする（MUST）。

`reap` は issue の `state_reason` を見てはならない（MUST NOT。消してよいかは main に入っていない commit が無いことで決まり、閉じ方の理由で変わらないため）。`reap` の中で `git fetch` を呼んではならない（MUST NOT。古い `origin/<base>` は消さない側に倒れるだけのため）。7 で HEAD と一致する行があった子について、1〜3 のどれも呼んではならない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の入力に加え、`gh pr list --head <ブランチ> --state all` の出力の有無と終了コード、`gh api repos/{owner}/{repo}/issues/<N> --jq .state` の出力と終了コード、`git merge-base --is-ancestor` の終了コードである。拾いたい誤りは、PR を作らず issue を閉じた子のワークツリーが `no-merged-pr`・`head-mismatch` で残り続けること、および main に入っていない commit・マージされていない PR・開いている issue を持つ子を消すことである。次は通してよく、この要件では止めない: `.gitignore` の対象のうち `LLM/` 以外（既存の要件と同じく守らない）／`--base` で main 以外から起動したのに `EPIC_DISPATCH_BASE` を設定していない親の子（`unmerged-commits` か `git-failed` で残る）／子が自分で pull して手元の `origin/<base>` より先に進んでいた子（`unmerged-commits` で残り、親が fetch したあとの `reap` で通る）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、下の Scenario を確かめなければならない（MUST）。

#### Scenario: PR が無く issue を閉じ、HEAD が origin/main に含まれる子は片付ける
- **WHEN** 要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の 1〜6 を満たす子 11 について、`gh pr list` の出力が `--state merged`・`--search <HEAD>`・`--state all` のどれでも空、`gh api repos/{owner}/{repo}/issues/11 --jq .state` の出力が `closed`、`git -C <子> merge-base --is-ancestor <HEAD> refs/remotes/origin/main` が exit 0 のスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close --worktree path:<子> --all` と `orca worktree rm --worktree path:<子>` がこの順に 1 回ずつ呼ばれ、どの `orca` の呼び出しにも `--force` が無く、stdout は `reaped 11` の 1 行で exit 0

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
- **THEN** どちらも `orca terminal close`・`orca worktree rm`・`git branch -D` は呼ばれず、stdout は順に `kept 11 unmerged-commits`・`kept 11 git-failed` で exit 0

#### Scenario: 起点のブランチは EPIC_DISPATCH_BASE で変わる
- **WHEN** 最初の Scenario の環境で、`EPIC_DISPATCH_BASE=develop` を付けて `epic-dispatch.sh reap 11` を実行する
- **THEN** `git merge-base --is-ancestor` は `refs/remotes/origin/develop` に対して呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: マージ済み PR で一致した子には PR の無い子の確認を呼ばない
- **WHEN** 要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の Scenario「条件をすべて満たす子は端末を閉じてからワークツリーを消す」の環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `gh pr list --state all`・`gh api`・`git merge-base` は 1 回も呼ばれず、stdout は `reaped 11` で exit 0

### Requirement: develop のループの終わりは、PR を伴わない子を親が片付ける条件を書く
develop の SKILL.md の節「ループの終わり」の、PR を伴わない記録先 issue を閉じて `mark` を呼ぶ項は、親の `epic-dispatch.sh reap` がその子を片付ける条件（そのブランチに PR が無い・issue が閉じている・HEAD が `origin/main` に含まれる）と、main に入っていない commit を積んだまま閉じると `kept <N> unmerged-commits` で残ることを書かなければならない（MUST）。`mark` を呼ぶ手順は変えない（SHALL）。

#### Scenario: ループの終わりに PR の無い子の片付けの条件が書かれている
- **WHEN** SKILL.md の節「ループの終わり」を読む
- **THEN** PR を伴わない記録先 issue の項に、親の `reap` が片付ける条件と `unmerged-commits` の語が書かれている
