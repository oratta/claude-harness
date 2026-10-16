## ADDED Requirements

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
- **THEN** どちらも `orca terminal close`・`orca worktree rm`・`git branch -D` は呼ばれず、stdout は順に `kept 11 unmerged-commits`・`kept 11 git-failed` で exit 0

#### Scenario: リモートの base が巻き戻されていれば、古い追跡参照と同じ HEAD の子も残す
- **WHEN** 最初の Scenario から、手元の `refs/remotes/origin/main` が子の HEAD と同じ（巻き戻し前の先端）で、`git ls-remote` が返す base の先端が巻き戻し後の別の commit、その先端に対する `git merge-base --is-ancestor <HEAD> <base の先端>` が exit 1 のスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close`・`orca worktree rm`・`git branch -D` は呼ばれず、stdout は `kept 11 unmerged-commits` で exit 0

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

### Requirement: develop のループの終わりは、PR を伴わない子を親が片付ける条件を書く
develop の SKILL.md の節「ループの終わり」の、PR を伴わない記録先 issue を閉じて `mark` を呼ぶ項は、親の `epic-dispatch.sh reap` がその子を片付ける条件（そのブランチに PR が無い・issue が閉じている・HEAD がリモートの今の main に含まれる）と、main に入っていない commit を積んだまま閉じると `kept <N> unmerged-commits` で残ることを書かなければならない（MUST）。`mark` を呼ぶ手順は変えない（SHALL）。

#### Scenario: ループの終わりに PR の無い子の片付けの条件が書かれている
- **WHEN** SKILL.md の節「ループの終わり」を読む
- **THEN** PR を伴わない記録先 issue の項に、親の `reap` が片付ける条件と `unmerged-commits` の語が書かれている
