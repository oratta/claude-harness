## MODIFIED Requirements

### Requirement: 対象の解決
システムは対象の番号を、最初の位置引数が数字ならその番号、`https://github.com/<owner>/<repo>/pull/<番号>` または `.../issues/<番号>` の URL ならそのリポジトリと番号として SHALL 求める。`gh pr comment`・`gh pr ready`・`gh pr merge` で位置引数が無いときは、hook の `cwd` の現在のブランチをヘッドに持つ PR を対象と SHALL する。それ以外の形（ブランチ名の位置引数、解決できない変数）は積まずに飛ば MUST す。`gh pr reopen` は番号か URL が要り、位置引数が無いときは積まない。

`gh pr create` は位置引数を取らないので、対象は作られた PR をヘッドブランチから SHALL 求める。`-H` / `--head` が無ければ hook の `cwd` の現在のブランチ、あればその値のブランチをヘッドに持つ PR を対象とする。`-H` / `--head` の値が `owner:branch` の形のとき、英数字と `.`・`_`・`/`・`-` 以外の文字を含むとき、解決できないときは積まずに飛ば MUST す。

`gh api` のきっかけの対象は、endpoint の `repos/<owner>/<repo>/` のリポジトリと、その後ろの番号と SHALL する。`<owner>/<repo>` が gh の置き換え記法 `{owner}/{repo}` のときは、gh と同じく、その呼び出しの前置きの `GH_REPO=値` があればそのリポジトリ、無ければ hook の `cwd` のリポジトリとする。endpoint の先頭の `/` は有っても無くてもよい。この形に一致しない endpoint（完全な URL、`?` 以降の問い合わせ文字列が付いたもの、`:owner/:repo` の記法、解決できない変数を含むもの）は積まずに飛ば MUST す。

リポジトリは gh と同じ順で、`-R` / `--repo`、無ければその呼び出しの前置きの `GH_REPO=値`、どちらも無ければ hook の `cwd` のリポジトリと SHALL する（`gh api` には `-R` / `--repo` が無く、リポジトリは上の段落のとおり endpoint から求める）。

`-R` / `--repo` の値、その呼び出しの前置きの `GH_REPO=値`、`gh api` の endpoint に直書きした `repos/<owner>/<repo>/`、位置引数の URL の `https://github.com/<owner>/<repo>/` のどれで指したときも、owner と repo のどちらかが `.` または `..` そのものであるリポジトリは、解決できなかった対象として積まずに飛ば MUST す（API のパスに入れると別の endpoint を指すため。対象の確認の `gh` も呼ばない。同じコマンドの中の代入で値が決まる変数で渡したときも同じ。位置引数の URL がこの定めで飛ばされたとき、同じ呼び出しに `-R` / `--repo` や前置きの `GH_REPO=値` があっても、そのリポジトリの対象としては解決しない）。名前の中に `.` を含むだけの owner / repo（`my.org/my.repo`・`acme/.github`）は、この定めでは飛ばさない。

こうして求めた対象のリポジトリが hook の `cwd`（作業中）のリポジトリと違うとき、システムは PR でも issue でも行を積んではなら MUST NOT ない（対象の確認までは行い、書き込まない。判定は「数字と書式は `timeline` サブコマンドから取る」の終了コード 3）。`cwd` のリポジトリが判別できないとき（git リポジトリでない、など）も同じく積まない。

行を積む対象は github.com の PR / issue だけである。照合はホストを含めて SHALL 行う: `cwd` のリポジトリの origin の URL（`https://github.com/o/r.git`・`git@github.com:o/r.git`・`ssh://git@github.com/o/r.git` の 3 つの形）から読んだホストが github.com で、かつ `owner/repo` が対象のリポジトリと一致するときだけ積む。origin のホストが github.com でないとき、または origin が無い・読めないときは積んではなら MUST NOT ない（終了コード 3）。`gh` の書き込み先は github.com（`gh` の既定）とし、コマンドに `--hostname`、その呼び出しの前置きの `GH_HOST=値`、hook が引き継いだ環境変数 `GH_HOST`、`-R` / `--repo` の `HOST/OWNER/REPO` のいずれかがあり、その値が github.com でないときは、そのきっかけでは積んではなら MUST NOT ない（対象の確認も行わない）。対象の確認・既存コメントの取得・書き込みの問い合わせは、`gh` の既定ホストや環境変数によらず、常に github.com に向け MUST る。

`gh issue comment` などの issue 向けのコマンドや、`gh api` の issue 向けの endpoint（`issues/<番号>/comments`・`issues/<番号>`）に渡された番号が PR だったとき、システムはそれを PR として扱 SHALL う。きっかけの呼び名は、`issue コメント` を `PR コメント`、`issue クローズ` を `PR クローズ`、`issue 再オープン` を `PR 再オープン` に読み替える（状態の確認も PR の側で行う）。

守備範囲: この解決が受け取る入力は、`tool_input.command` の文字列、hook の `cwd`、対象の確認で GitHub が返す応答の 3 つに限る。拾いたい誤りは、コマンドが指したのとは別の PR / issue に行を積むことと、解決のためにコマンドを評価・再実行して副作用を起こすことの 2 つ。次の入力は誤ったまま通ることを許す: コマンド置換や、そのコマンドの外で設定された変数（`$PR`・`export` 済みの `GH_REPO`）で渡された番号やリポジトリは解決できず、行が積まれない（`GH_REPO` の場合は `cwd` のリポジトリとして扱われる）／`cd ../other && gh pr comment --body x` のようにコマンドの中で作業ディレクトリを変えた呼び出しは、hook の `cwd` のリポジトリとブランチで解決される／`github.com` 以外のホストの URL は対象にならない／`www.github.com` のような github.com の別名の origin は github.com と見なさず、積まない／前のコマンドでの `export GH_HOST=...`・`gh` の設定の既定ホストなど、コマンドから読めない形で別のホストを指した場合は、github.com の同じ番号の対象に積むことがある（書き込みは常に github.com に向く）／番号を省いたときと `gh pr create` で、同じヘッドブランチの PR が複数あれば、GitHub が返す一覧の先頭が対象になる／ブランチ名や `owner:branch` の位置引数は対象にならない／`gh pr create` の出力（作られた PR の URL）は読まないので、`git checkout` や `cd` で `cwd` のブランチと違うブランチから `--head` 無しで作った PR は対象にならないか、`cwd` のブランチの PR として解決される／`gh api` の endpoint を完全な URL や `:owner/:repo` で書いたものは対象にならない／owner / repo が `.`・`..` の対象を飛ばす定めが見るのは、名前が `.` か `..` そのものかどうかだけで、`a/...`・`a/b..` のように `.` を連ねた名前は、`-R` / `--repo`・前置きの `GH_REPO`・`gh api` の endpoint・位置引数の URL のどれで指しても対象として取り出され、許可の一覧（`cost-ledger-write-allowlist`）にその名前があれば対象の確認の `gh` まで進む。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

対象のリポジトリが作業中のリポジトリと違えば積まない、という守りが守るのは「作業中のリポジトリのコストを、別のリポジトリの PR / issue へ書き出すこと」である（fork の clone から upstream の PR にコメントしても行は付かず、別のディレクトリから `-R` で自分のリポジトリの PR を指したときも行は付かない）。守らないのは「手元の別のリポジトリにある同名のブランチのコストが、作業中のリポジトリの PR の累計に合算されること」で、これは PR の累計をブランチ名だけで引く `/cost <PR番号>` と共通の既存の性質である。

#### Scenario: 番号を渡す
- **WHEN** `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `cwd` のリポジトリの #300 が対象になる

#### Scenario: URL を渡す
- **WHEN** `gh issue comment https://github.com/acme/other/issues/12 --body x` の hook JSON を流す
- **THEN** 対象の確認は acme/other の #12 に対して行われる（`cwd` のリポジトリが acme/other でなければ、行は積まれない）

#### Scenario: 番号を省く
- **WHEN** `cwd` のブランチをヘッドに持つ PR #300 がある状態で `gh pr ready` の hook JSON を流す
- **THEN** #300 が対象になる

#### Scenario: `gh pr create` は `cwd` のブランチの PR が対象
- **WHEN** `cwd` のブランチをヘッドに持つ、作られたばかりの PR #300 がある状態で `gh pr create --draft --title x --body y` の hook JSON を流す
- **THEN** #300 に行が 1 行積まれ、きっかけの欄は `PR 作成`

#### Scenario: `gh pr create --head` はそのブランチの PR が対象
- **WHEN** `gh pr create --draft --head feat/x --base main --title x --body y` の hook JSON を流す
- **THEN** 対象の確認は、ヘッドブランチが `feat/x` の PR の問い合わせ（`pulls?head=<owner>:feat/x&state=all`）で行われ、`cwd` のブランチでは問い合わせない

#### Scenario: `gh pr create --head owner:branch` は飛ばす
- **WHEN** `gh pr create --head someone:feat/x --title x --body y` の hook JSON を流す
- **THEN** `gh` は 1 回も呼ばれない

#### Scenario: `gh api` の endpoint のリポジトリと番号
- **WHEN** `cwd` が acme/repo-a のリポジトリで、`gh api repos/acme/repo-a/issues/300/comments -f body=x` と `gh api repos/{owner}/{repo}/issues/300/comments -f body=x` の hook JSON をそれぞれ流す
- **THEN** どちらも acme/repo-a の #300 が対象になる

#### Scenario: `gh api` で別のリポジトリを指す
- **WHEN** `cwd` が acme/repo-a のリポジトリで、`gh api repos/acme/other/issues/300/comments -f body=x` の hook JSON を流す
- **THEN** 対象の確認は acme/other の #300 に対して行われ、コメントの作成も書き換えも行われない

#### Scenario: 形の合わない endpoint は飛ばす
- **WHEN** `gh api https://api.github.com/repos/acme/repo-a/issues/300/comments -f body=x` や `gh api "repos/acme/repo-a/issues/$(echo 300)/comments" -f body=x` の hook JSON を流す
- **THEN** `gh` は 1 回も呼ばれない

#### Scenario: -R で別のリポジトリを指す
- **WHEN** `cwd` が acme/repo-a のリポジトリで、`gh pr comment 300 -R acme/other --body x` の hook JSON を流す
- **THEN** 対象の確認は acme/other の #300 に対して行われ、コメントの作成も書き換えも行われない

#### Scenario: owner / repo が `.` か `..` の対象は飛ばす
- **WHEN** `gh pr comment 1 -R a/.. --body x`、`GH_REPO=a/.. gh pr comment 1 --body x`、`gh api -X POST repos/a/../issues/1/comments -f body=x` の hook JSON をそれぞれ流す
- **THEN** どれも `gh` は 1 回も呼ばれない

#### Scenario: 位置引数の URL の owner / repo が `.` か `..` の対象は飛ばす
- **WHEN** 許可の一覧に `a/..` と `../b` が載っている状態で、`gh pr comment https://github.com/a/../pull/1 --body x` と `gh issue close https://github.com/../b/issues/2` の hook JSON をそれぞれ流す
- **THEN** どちらも `gh` は 1 回も呼ばれない

#### Scenario: 位置引数の URL が飛ばされたとき、併記した `-R` のリポジトリには落ちない
- **WHEN** 許可の一覧に `a/..` と `acme/other` が載っている状態で、`gh pr comment https://github.com/a/../pull/1 -R acme/other --body x` の hook JSON を流す
- **THEN** `gh` は 1 回も呼ばれない

#### Scenario: 名前の中に `.` を含むだけの owner / repo は飛ばさない
- **WHEN** `gh pr comment 1 -R my.org/my.repo --body x` と `gh api -X POST repos/acme/.github/issues/2/comments -f body=x` の hook JSON をそれぞれ流す
- **THEN** 対象の確認は my.org/my.repo の #1 と acme/.github の #2 に対して行われる

#### Scenario: -R で作業中のリポジトリ自身を指す
- **WHEN** `cwd` が acme/repo-a のリポジトリで、`gh pr comment 300 -R acme/repo-a --body x` の hook JSON を流す
- **THEN** acme/repo-a の #300 に行が 1 行積まれる

#### Scenario: 別ホストの同名のリポジトリ
- **WHEN** `cwd` のリポジトリの origin が `https://unrelated.example/acme/repo-a.git` で、`gh pr comment 300 -R acme/repo-a --body x` の hook JSON を流す
- **THEN** github.com の acme/repo-a の #300 にコメントの作成も書き換えも行われない（`timeline` の終了コード 3）

#### Scenario: github.com 以外への書き込み
- **WHEN** `GH_HOST=ghe.example gh pr comment 300 --body x`、`gh api --hostname ghe.example -X POST repos/acme/repo-a/issues/300/labels -f 'labels[]=agent-review:passed'`、または `gh api --hostname ghe.example repos/acme/repo-a/issues/300/comments -f body=x` の hook JSON を流す
- **THEN** 対象の確認もコメントの作成も書き換えも行われない

#### Scenario: 解決できない番号は飛ばす
- **WHEN** `gh pr comment "$(gh pr view --json number -q .number)" --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: issue 向けの endpoint に渡された番号が PR
- **WHEN** PR である #300 に `gh api repos/o/r/issues/300/comments -f body=x`、`gh api -X PATCH repos/o/r/issues/300 -f state=closed`、`gh api -X PATCH repos/o/r/issues/300 -f state=open` を順に流す（GitHub の応答は各コマンドが成功した状態を返す）
- **THEN** きっかけの欄は順に `PR コメント`・`PR クローズ`・`PR 再オープン`

#### Scenario: `gh issue reopen` に渡された番号が PR
- **WHEN** PR である #300（`state` は open）に `gh issue reopen 300` の hook JSON を流す
- **THEN** #300 に行が 1 行積まれ、きっかけの欄は `PR 再オープン`
