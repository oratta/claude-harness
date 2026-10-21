## MODIFIED Requirements

### Requirement: `gh` の呼び出し回数
システムが 1 行積むために呼ぶ `gh` は、対象 1 件あたり 3 回（対象の確認・既存コメントの取得・書き込み）以下で MUST ある。ただし、PR でない issue にきっかけ `issue クローズ` を含む行を積むときは、閉じた PR の問い合わせ 1 回を足した 4 回以下で MUST ある。既存コメントの取得がコメント 100 件ごとに 1 ページ増える分と、issue 向けのコマンドや `gh api` の issue 向けの endpoint（`issues/<番号>/comments`・`issues/<番号>`）に渡された番号が PR だったときの 1 回は、この数に含めない。回数は、その PR / issue に既に積まれている行の数にも、その issue を閉じた PR の数にも比例してはなら MUST NOT ない。きっかけが `gh api`・`gh pr create`・`gh pr reopen` でも、この回数は変わってはなら MUST NOT ない。

許可の一覧（`cost-ledger-write-allowlist`）が空のとき、および hook の `cwd` の origin のリポジトリかコマンドが名指ししたリポジトリが一覧に無いとき、その対象について呼ぶ `gh` は 0 回で MUST ある。一覧の判定のために `gh` を呼んではなら MUST NOT ない。

#### Scenario: PR へのコメント
- **WHEN** `gh pr comment 300 --body x` の hook JSON を流す（コメントは 100 件未満）
- **THEN** `gh` が呼ばれた回数は 3 回

#### Scenario: 対象が 2 件
- **WHEN** `gh issue comment 12 --body x; gh pr comment 300 --body y` の hook JSON を流す
- **THEN** `gh` が呼ばれた回数は 6 回

#### Scenario: issue のクローズ
- **WHEN** `closedByPullRequestsReferences` が PR を 3 件返す issue #12 に、`gh issue close 12` の hook JSON を流す（コメントは 100 件未満）
- **THEN** `gh` が呼ばれた回数は 4 回

#### Scenario: `gh pr create` と PR 向けの `gh api`
- **WHEN** `gh pr create --title x --body y`、`gh pr reopen 300`、`gh api -X PATCH repos/o/r/pulls/300 -f state=closed`、`gh api -X PUT repos/o/r/pulls/300/merge` の hook JSON をそれぞれ流す（コメントは 100 件未満）
- **THEN** `gh` が呼ばれた回数は、どれも 3 回

#### Scenario: `gh api` のコメント投稿
- **WHEN** `gh api repos/o/r/issues/12/comments -f body=x`（#12 は PR でない issue）と `gh api repos/o/r/issues/300/comments -f body=x`（#300 は PR）の hook JSON をそれぞれ流す
- **THEN** `gh` が呼ばれた回数は、#12 では 3 回、#300 では 4 回

#### Scenario: `gh api` での issue のクローズ
- **WHEN** PR でない issue #12 に `gh api -X PATCH repos/o/r/issues/12 -f state=closed` の hook JSON を流す
- **THEN** `gh` が呼ばれた回数は 4 回（閉じた PR の問い合わせを含む）

#### Scenario: 一覧に無いリポジトリ
- **WHEN** 許可の一覧に `cwd` の origin のリポジトリが無い状態で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `gh` が呼ばれた回数は 0 回
