## ADDED Requirements

### Requirement: エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、子のセッションを閉じて同じワークツリーで `/develop #<N>` だけを打ち直しても、親が `launch --note` で渡した注意書きと「エピックの子である」ことが失われないようにしなければならない（MUST）。この要件は、要件「エピックの並列起動は 1 段で止める」のうち `route` が `nested` を返す条件と `launch` の拒否の条件、および要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の判定と `launch` の呼び出し順に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

**注意書きのコメント**: `launch --note <text>` は、`orca worktree create` が exit 0 で終わった子ごとに 1 回、端末を作る前に、`gh issue comment <N> --body <本文>` で子 issue にコメントしなければならない（MUST）。本文の 1 行目は `親エピックからの注意書き: #<epic>`、2 行目は空行、3 行目以降は `<text>` そのものとする（MUST）。`--note` が無いとき、`skipped <N>` の子、worktree create が非 0 で終わった子には投稿してはならない（MUST NOT）。投稿が非 0 で終わっても、その子の stdout の 1 行と `launch` の exit code を変えてはならず（MUST NOT）、stderr に `note not posted to #<N>` を含む行と、同じ本文を単一引用符で囲んだ `gh issue comment <N> --body '<本文>'` を出す（SHALL）。最初の指示の文面に `<text>` を含める既存の規定は変えない（SHALL）。

**エピックの子の判定**: 次のどちらかが成り立つとき、そのセッションを「エピックの子」とし、親エピックの番号を次のとおりとする（MUST）。

1. 環境変数 `EPIC_DISPATCH_PARENT_EPIC` が空でない。親エピックの番号はその値。このとき `orca` を呼んではならない（MUST NOT）
2. 1 が成り立たず、`orca` と `jq` が PATH にあり、`orca worktree current --json` が exit 0 で終わり、その `.result.worktree.parentWorktreeId` が空でも `null` でもなく、`orca worktree list --json` の `.result.worktrees[]` のうち `id` がその値と一致するワークツリーの `linkedIssue` が `null` でない。親エピックの番号はその `linkedIssue`。親ワークツリーの `isArchived` は判定に使わない（SHALL）

`orca worktree list --json` は、`parentWorktreeId` が空でも `null` でもないときだけ呼ぶ（MUST）。`jq` が無い、`orca worktree list --json` が非 0 で終わる、出力の `.result.worktrees` が配列でないときは、2 は成り立たないとして扱う（MUST）。

**`route`**: 子の番号の検査のあと、子の件数によらず最初にエピックの子の判定を行い、エピックの子なら stdout に `nested` の 1 行、stderr に `parent epic: #<親エピックの番号>` の 1 行を出して exit 0 で終わらなければならない（MUST）。エピックの子でなければ、子が 2 件以上で `orca worktree current --json` が exit 0 なら `orca`、それ以外は `subagent` を出す（MUST）。`orca worktree current` は 1 回の `route` で 1 回だけ呼ぶ（SHALL）。2 の判定の途中で一覧を読めなかったときは stderr に `could not read the parent worktree` を出す（SHALL）。

**`launch`**: 引数の検査のあと、1 が成り立てば今までどおり `orca` も `git` も呼ばずに stderr に理由を出して exit 1 で終わる（MUST）。1 が成り立たなければ、`orca worktree current --json` の直後、`git rev-parse --show-toplevel` より前に 2 を判定し、成り立てば `git`・`orca worktree set`・`orca worktree create` を 1 つも呼ばず、stdout には何も出さず、stderr に親エピックの番号と `child epics are not expanded here` を含む理由を出して exit 1 で終わらなければならない（MUST）。1 による拒否の stderr も `child epics are not expanded here` を含む（SHALL）。親ワークツリーを持たないワークツリーでは、呼び出しの順序を変えてはならない（MUST NOT）。

**develop の SKILL.md「エピックの扱い」** は次を規定しなければならない（MUST）。`orca` のコマンドは書かない（MUST NOT。要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」）。

- `launch` が `--note` を子 issue に `親エピックからの注意書き:` で始まるコメントとして残すこと。子のセッションの本体（起動し直したセッションを含む）は、記録先にこの行で始まるコメントがあればすべて従い、W・R1・G に渡す関連コメントに必ず含めること
- `launch` の stderr に `note not posted to #<N>` があれば、本体がその子 issue に stderr に出た本文を投稿すること
- 子であることは、`launch` が端末に付けた環境変数と、子のワークツリーの親子関係のどちらからでも判定されるので、起動し直したセッションでも `route` が `nested` を返すこと
- `nested` を受けたセッションは、親エピックの番号を `route` の stderr の `parent epic: #<N>` から読むこと
- `launch` の拒否は stderr の `child epics are not expanded here` で見分け、`nested` と同じに扱うこと

この要件の守備範囲で入力として扱うのは、`launch` に渡された `--note` の文、`orca worktree current --json` の `.result.worktree.parentWorktreeId`、`orca worktree list --json` の `.result.worktrees[]` の `id` と `linkedIssue` である。2 つの JSON は 2026-10-08 の実機（Orca 1.4.222）で確かめた形のとおりと信じ、形が変わったときの検知は範囲外とする。拾いたい誤りは、起動し直した子のセッションが注意書きを知らずに範囲外に手を出すこと、自分を子だと知らずに孫のワークツリーやサブエージェントを作ることである。次は通してよく、この要件では止めない: `launch` 以外で、`linkedIssue` の付いたワークツリーを親にして作ったワークツリーで回すエピックは `nested` になる／一覧の一時的な失敗と `route` の 1 回が重なると子のセッションが `nested` にならない（そのとき `launch` は一覧を読めずに子を作らない）／この変更の前に `launch` された子の issue には注意書きのコメントが無い／注意書きの本文の長さや内容は検査しない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`gh issue comment` の呼び出しの回数と本文、親子関係による `nested` と `launch` の拒否、上の SKILL.md の記述を確かめなければならない（MUST）。

#### Scenario: --note があれば子ごとに 1 回注意書きをコメントする
- **WHEN** 一覧に子のワークツリーが無いスタブ環境で `epic-dispatch.sh launch --note "後続の範囲に手を出さない" 400 11 12` を実行する
- **THEN** `gh issue comment` は子 11 と子 12 にそれぞれ 1 回呼ばれ、どちらの本文も 1 行目が `親エピックからの注意書き: #400` で `後続の範囲に手を出さない` を含み、各子の `gh issue comment` は `orca terminal create` より前に呼ばれ、stdout は `launched 11` と `launched 12`、exit 0

#### Scenario: --note が無ければコメントしない
- **WHEN** 一覧に子のワークツリーが無いスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `gh issue comment` は 1 回も呼ばれない

#### Scenario: skipped の子と worktree create に失敗した子にはコメントしない
- **WHEN** 一覧に子 11 のワークツリーがあり、子 12 の `orca worktree create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch --note "x" 400 11 12 13` を実行する
- **THEN** `gh issue comment` は子 13 にだけ 1 回呼ばれ、stdout は `skipped 11`・`failed 12`・`launched 13`、exit 1

#### Scenario: 端末を作れなかった子にもコメントは残る
- **WHEN** 子 11 の `orca terminal create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch --note "x" 400 11` を実行する
- **THEN** `gh issue comment` は子 11 に 1 回呼ばれ、stdout は `failed 11`、exit 1

#### Scenario: コメントに失敗しても起動の結果は変えない
- **WHEN** `gh issue comment` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch --note "x" 400 11` を実行する
- **THEN** stdout は `launched 11`、exit 0、stderr に `note not posted to #11` と `gh issue comment 11 --body` を含む行が出る

#### Scenario: 環境変数が無くても、親ワークツリーに issue があれば nested
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` が無く、`orca worktree current --json` の `parentWorktreeId` が `repo-a::/work/parent`、一覧の `id` が `repo-a::/work/parent` のワークツリーの `linkedIssue` が 420 のスタブ環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `nested` の 1 行、stderr に `parent epic: #420`、exit 0

#### Scenario: 子が 1 件でも親ワークツリーに issue があれば nested
- **WHEN** 上と同じスタブ環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `nested` の 1 行で exit 0

#### Scenario: 親ワークツリーに issue が無ければ今までどおり
- **WHEN** `parentWorktreeId` が `repo-a::/work/parent` で、一覧のそのワークツリーの `linkedIssue` が `null` のスタブ環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: 親も環境変数も無ければ今までどおりで一覧を読まない
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` が無く、`orca worktree current --json` に `parentWorktreeId` が無いスタブ環境で `epic-dispatch.sh route 11 12` と `epic-dispatch.sh route 11` を実行する
- **THEN** stdout はそれぞれ `orca` と `subagent` の 1 行で exit 0、`orca worktree list` は呼ばれず、`orca worktree current` はそれぞれ 1 回呼ばれる

#### Scenario: 一覧を読めなければ子ではないとして扱う
- **WHEN** `parentWorktreeId` があり、`orca worktree list --json` が非 0 で終わるスタブ環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0、stderr に `could not read the parent worktree`

#### Scenario: 環境変数があるときは nested の stderr に環境変数の番号を出す
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `nested` の 1 行、stderr に `parent epic: #420`、`orca` は呼ばれない

#### Scenario: 親ワークツリーに issue があれば launch は子ワークツリーを作らない
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` が無く、親ワークツリーの `linkedIssue` が 420 のスタブ環境で `epic-dispatch.sh launch 460 11 12` を実行する
- **THEN** exit 1、stdout は空、`git`・`orca worktree set`・`orca worktree create` は 1 回も呼ばれず、stderr に `420` と `child epics are not expanded here` が出る

#### Scenario: SKILL.md に注意書きのコメントと起動し直したセッションの扱いが書かれている
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** `親エピックからの注意書き:` のコメントに従い W・R1・G に渡すこと、`note not posted to` のときに本体が投稿すること、起動し直したセッションでも `nested` になること、親エピックの番号を `parent epic: #` から読むこと、`child epics are not expanded here` で `launch` の拒否を見分けることが書かれていて、`grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` は 0 行

### Requirement: 端末を作れなかった子と指示が届かなかった子の案内は、二重起動を避ける確認を先に出す
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` が stderr に出す案内は、次を満たさなければならない（MUST）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の作り直しと送り直しのコマンドの規定に足すもので、既存の規定は変えない。

- 端末を作れなかった子の案内は、作り直しのコマンド（`orca terminal create ...`）より前の行に、そのワークツリーで `claude` がすでに動いている端末が無いことを確かめる `orca terminal list --worktree path:<子> --json` を出す（MUST。案内どおりに作り直して同じワークツリーで Claude Code が 2 つ起動し、`/develop #N` が二重に走るのを避けるため）
- 指示を送り直すための案内のハンドル引数（`orca terminal send --terminal <handle>` と `orca terminal read --terminal <handle>`）は、指示の文と同じく単一引用符で囲む（MUST）

develop の SKILL.md「エピックの扱い」は、端末を作れなかった `failed` の子について、stderr に出た確認のコマンドで既存の端末が無いことを確かめ、stderr の作り直しのコマンドで端末を作り、返ったハンドルに送信のコマンドを送って動き出したのを確かめてから再開する手順を書かなければならない（MUST。作り直さずに再開するとその子は `skipped` になり、`wait` が端末の無い子を最長 6 時間待つため）。`orca` のコマンドは書かない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、`launch` が端末の作成や送信に失敗した子の、子のワークツリーのパスとハンドルである。ハンドルは Orca が払い出す単純な識別子（`term-11` など）で、引用符で囲むのは表示の揃えのためであり、ハンドルに記号が入る場合の検知は範囲外とする。

#### Scenario: 作り直しの案内の前に既存端末の確認を出す
- **WHEN** 子 11 の `orca terminal create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** stderr の `orca terminal list --worktree path:<子 11 のパス> --json` を含む行は、`orca terminal create --worktree` を含む行より前にある

#### Scenario: 送り直しの案内のハンドルは引用符で囲まれる
- **WHEN** 子 11 の `orca terminal send` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stderr の送り直しのコマンドは `--terminal 'term-11'` を含み、確認のコマンドも `orca terminal read --terminal 'term-11'` を含む

#### Scenario: SKILL.md に端末を作れなかった子の再開手順が書かれている
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** 端末を作れなかった `failed` の子について、既存の端末が無いことを確かめ、作り直して送り、動き出したのを確かめてから再開することが書かれている
