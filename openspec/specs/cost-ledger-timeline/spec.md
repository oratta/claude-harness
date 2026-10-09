# cost-ledger-timeline Specification

## Purpose
TBD - created by archiving change cost-ledger-timeline. Update Purpose after archive.
## Requirements
### Requirement: 行を積むきっかけ
システムは、PostToolUse の hook（`plugins/cost-ledger/scripts/gate-report.sh`）が受け取った `tool_input.command` に次のいずれかが含まれるとき、その対象の PR / issue に行を 1 行積 MUST む。行の「きっかけ」の欄には表の呼び名を SHALL 書く。

| コマンド | きっかけ |
|---|---|
| `gh pr create`（`--dry-run` と `-w` / `--web` を除く） | `PR 作成` |
| `gh pr comment` | `PR コメント` |
| `gh issue comment` | `issue コメント` |
| `gh pr ready`（`--undo` を除く） | `Ready` |
| `gh pr close` | `PR クローズ` |
| `gh pr reopen` | `PR 再オープン` |
| `gh pr merge` | `マージ` |
| `gh issue close` | `issue クローズ` |
| `gh issue reopen` | `issue 再オープン` |
| `gh api` で `repos/<owner>/<repo>/issues/<番号>/comments` への POST | `issue コメント` |
| `gh api` で `repos/<owner>/<repo>/pulls/<番号>` への PATCH のうち、フィールドに `state=closed` があるもの | `PR クローズ` |
| `gh api` で `repos/<owner>/<repo>/pulls/<番号>` への PATCH のうち、フィールドに `state=open` があるもの | `PR 再オープン` |
| `gh api` で `repos/<owner>/<repo>/issues/<番号>` への PATCH のうち、フィールドに `state=closed` があるもの | `issue クローズ` |
| `gh api` で `repos/<owner>/<repo>/issues/<番号>` への PATCH のうち、フィールドに `state=open` があるもの | `issue 再オープン` |
| `gh api` で `repos/<owner>/<repo>/pulls/<番号>/merge` への PUT | `マージ` |
| 合格ラベル `agent-review:passed` の付与（判定は `cost-ledger-gate-report`） | `ゲート通過` |

`gh api` の endpoint・メソッド・フィールドは「`gh api` の呼び出しの読み方」に従って SHALL 読む。issue 向けの endpoint（`issues/<番号>/comments`・`issues/<番号>`）に渡された番号が PR だったときの呼び名の読み替えは「対象の解決」に従う。

`ゲート通過` の対象は PR だけと SHALL する。PR でない issue に合格ラベルを付けても積まない。

これ以外のコマンドで行を積んではなら MUST NOT ない。積まないものには次を含む: `gh pr view`・`gh issue view` などの読み取り／`gh api` の GET／`gh api` の PATCH で `state` のフィールドが無いもの（タイトルや本文の編集、`--input` で本文を渡したもの）／コメントの編集（`repos/<owner>/<repo>/issues/comments/<id>` への PATCH。hook 自身がコストのコメントを書き換えるときの形でもある）／`gh api graphql`。コマンドの読み取りは `cost-ledger-gate-report` の付与の判定と同じ規則（同じコマンドの中の単純な代入と `for` の展開、サブシェルの扱い）に従い、コマンドを評価・再実行してはなら MUST NOT ない。文字列として含むだけ（`echo "gh pr comment 300"` など）のコマンドで積んではなら MUST NOT ない。

1 つのコマンドに同じ対象へのきっかけが複数あるとき、システムは行を 1 行だけ積み、きっかけを実行順に `+` でつな SHALL ぐ。

hook 自身の書き込み（コストのコメントの作成と書き換え）は Bash ツールの呼び出しではないので、PostToolUse を起こさず、行を積むきっかけになら SHALL ない。1 回のきっかけで行われる書き込みは 1 回だけで MUST ある。

守備範囲: この判定が受け取る入力は、PostToolUse が渡す `tool_input.command`（Claude Code のセッションが Bash ツールで実行したコマンド文字列）に限る。拾いたい誤りは、表に無いコマンドで行を積むこと・コマンドを文字列として含むだけの Bash で行を積むこと・1 つのコマンドで同じ対象に行を 2 行以上積むことの 3 つ。次の入力は誤ったまま通ることを許す: `eval`・`bash -c '...'`・シェル関数・エイリアス・スクリプトファイルの中から実行された `gh pr comment` などは見えず、行が積まれない／`gh` を変数で呼んだもの（`$GH pr comment`）と、`gh` と `pr` のあいだにオプションを置いたもの（`gh -R x pr comment`）は行が積まれない／`false && gh pr comment 300 --body x` のように実行されなかったコメントのコマンドでも行が積まれる（数字は正しく、きっかけの名前だけが実際と合わない）／`gh api graphql` の mutation での投稿や状態変更、`--input` で渡した JSON の中の `state` の変更は見えず、行が積まれない／hook の新規作成と同じ形のコマンド（`issues/<番号>/comments` への POST）を Bash で実行したものは、コメントの投稿として行が積まれる／Bash ツール以外（別の端末、GitHub の画面、auto-merge）で行われた投稿や状態変更は、この hook では行が積まれない（このうち PR のマージと issue のクローズは、`cost-ledger-backfill` が次のセッション開始時に後追いで積む）。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 7 種のコマンドで同じコメントに 1 行ずつ増える
- **WHEN** 同じ PR に `gh pr comment`・`gh pr ready`・`gh pr close`・`gh pr merge` を、同じ issue に `gh issue comment`・`gh issue close`・`gh issue reopen` を、それぞれ別の hook 呼び出しとして順に流す（GitHub の応答は各コマンドが成功した状態を返す）
- **THEN** PR と issue のそれぞれで、コメントの新規作成は最初の 1 回だけで、以後は同じコメントが書き換えられ、流すたびに表の行が 1 行ずつ増える

#### Scenario: `gh api` の直叩きと `gh pr create` / `gh pr reopen` で同じコメントに 1 行ずつ増える
- **WHEN** `cwd` のリポジトリが o/r で、`cwd` のブランチをヘッドに持つ PR が #300 の状態で、`gh pr create --title x --body y`、`gh api repos/o/r/issues/300/comments -f body=x`、`gh api -X PATCH repos/o/r/pulls/300 -f state=closed`、`gh pr reopen 300`、`gh api -X PUT repos/o/r/pulls/300/merge` を、それぞれ別の hook 呼び出しとして順に流す（GitHub の応答は各コマンドが成功した状態を返す）
- **THEN** コメントの新規作成は最初の 1 回だけで、以後は同じコメントが書き換えられ、流すたびに表の行が 1 行ずつ増え、きっかけの欄は順に `PR 作成`・`PR コメント`・`PR クローズ`・`PR 再オープン`・`マージ`

#### Scenario: issue への `gh api` の直叩き
- **WHEN** PR でない issue #12 に、`gh api repos/o/r/issues/12/comments -f body=x`、`gh api -X PATCH repos/o/r/issues/12 -f state=closed`、`gh api -X PATCH repos/o/r/issues/12 -f state=open` を順に流す
- **THEN** 流すたびに表の行が 1 行ずつ増え、きっかけの欄は順に `issue コメント`・`issue クローズ`・`issue 再オープン`

#### Scenario: 対象外の gh コマンドでは積まない
- **WHEN** `gh pr view 300` や `gh issue view 12` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: `gh api` の読み取りでは積まない
- **WHEN** `gh api repos/o/r/issues/300/comments`、`gh api repos/o/r/pulls/300 --jq .state`、`gh api -X GET repos/o/r/issues/300/comments -f per_page=100` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: `state` を変えない PATCH では積まない
- **WHEN** `gh api -X PATCH repos/o/r/pulls/300 -f title=x` や `gh api -X PATCH repos/o/r/issues/12 --input body.json` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: hook 自身の書き込みと同じ形の書き換えでは積まない
- **WHEN** `gh api -X PATCH repos/o/r/issues/comments/900 --input -` の hook JSON を流す
- **THEN** `gh` は 1 回も呼ばれず、コメントの作成も書き換えも行われない

#### Scenario: 1 回のきっかけで書き込みは 1 回
- **WHEN** 目印付きのコメントが無い PR #300 に `gh api repos/o/r/issues/300/comments -f body=x` の hook JSON を 1 回流す
- **THEN** コメントの新規作成は 1 回、書き換えは 0 回で、表の行は 1 行

#### Scenario: 文字列として含むだけでは積まない
- **WHEN** `echo "gh pr comment 300 --body x"` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 1 つのコマンドに複数のきっかけ
- **WHEN** `gh pr comment 300 --body x && gh pr ready 300` の hook JSON を流す
- **THEN** #300 に積まれる行は 1 行で、きっかけの欄は `PR コメント+Ready`

### Requirement: 対象の解決
システムは対象の番号を、最初の位置引数が数字ならその番号、`https://github.com/<owner>/<repo>/pull/<番号>` または `.../issues/<番号>` の URL ならそのリポジトリと番号として SHALL 求める。`gh pr comment`・`gh pr ready`・`gh pr merge` で位置引数が無いときは、hook の `cwd` の現在のブランチをヘッドに持つ PR を対象と SHALL する。それ以外の形（ブランチ名の位置引数、解決できない変数）は積まずに飛ば MUST す。`gh pr reopen` は番号か URL が要り、位置引数が無いときは積まない。

`gh pr create` は位置引数を取らないので、対象は作られた PR をヘッドブランチから SHALL 求める。`-H` / `--head` が無ければ hook の `cwd` の現在のブランチ、あればその値のブランチをヘッドに持つ PR を対象とする。`-H` / `--head` の値が `owner:branch` の形のとき、英数字と `.`・`_`・`/`・`-` 以外の文字を含むとき、解決できないときは積まずに飛ば MUST す。

`gh api` のきっかけの対象は、endpoint の `repos/<owner>/<repo>/` のリポジトリと、その後ろの番号と SHALL する。`<owner>/<repo>` が gh の置き換え記法 `{owner}/{repo}` のときは、gh と同じく、その呼び出しの前置きの `GH_REPO=値` があればそのリポジトリ、無ければ hook の `cwd` のリポジトリとする。endpoint の先頭の `/` は有っても無くてもよい。この形に一致しない endpoint（完全な URL、`?` 以降の問い合わせ文字列が付いたもの、`:owner/:repo` の記法、解決できない変数を含むもの）は積まずに飛ば MUST す。

リポジトリは gh と同じ順で、`-R` / `--repo`、無ければその呼び出しの前置きの `GH_REPO=値`、どちらも無ければ hook の `cwd` のリポジトリと SHALL する（`gh api` には `-R` / `--repo` が無く、リポジトリは上の段落のとおり endpoint から求める）。

こうして求めた対象のリポジトリが hook の `cwd`（作業中）のリポジトリと違うとき、システムは PR でも issue でも行を積んではなら MUST NOT ない（対象の確認までは行い、書き込まない。判定は「数字と書式は `timeline` サブコマンドから取る」の終了コード 3）。`cwd` のリポジトリが判別できないとき（git リポジトリでない、など）も同じく積まない。

行を積む対象は github.com の PR / issue だけである。照合はホストを含めて SHALL 行う: `cwd` のリポジトリの origin の URL（`https://github.com/o/r.git`・`git@github.com:o/r.git`・`ssh://git@github.com/o/r.git` の 3 つの形）から読んだホストが github.com で、かつ `owner/repo` が対象のリポジトリと一致するときだけ積む。origin のホストが github.com でないとき、または origin が無い・読めないときは積んではなら MUST NOT ない（終了コード 3）。`gh` の書き込み先は github.com（`gh` の既定）とし、コマンドに `--hostname`、その呼び出しの前置きの `GH_HOST=値`、hook が引き継いだ環境変数 `GH_HOST`、`-R` / `--repo` の `HOST/OWNER/REPO` のいずれかがあり、その値が github.com でないときは、そのきっかけでは積んではなら MUST NOT ない（対象の確認も行わない）。対象の確認・既存コメントの取得・書き込みの問い合わせは、`gh` の既定ホストや環境変数によらず、常に github.com に向け MUST る。

`gh issue comment` などの issue 向けのコマンドや、`gh api` の issue 向けの endpoint（`issues/<番号>/comments`・`issues/<番号>`）に渡された番号が PR だったとき、システムはそれを PR として扱 SHALL う。きっかけの呼び名は、`issue コメント` を `PR コメント`、`issue クローズ` を `PR クローズ`、`issue 再オープン` を `PR 再オープン` に読み替える（状態の確認も PR の側で行う）。

守備範囲: この解決が受け取る入力は、`tool_input.command` の文字列、hook の `cwd`、対象の確認で GitHub が返す応答の 3 つに限る。拾いたい誤りは、コマンドが指したのとは別の PR / issue に行を積むことと、解決のためにコマンドを評価・再実行して副作用を起こすことの 2 つ。次の入力は誤ったまま通ることを許す: コマンド置換や、そのコマンドの外で設定された変数（`$PR`・`export` 済みの `GH_REPO`）で渡された番号やリポジトリは解決できず、行が積まれない（`GH_REPO` の場合は `cwd` のリポジトリとして扱われる）／`cd ../other && gh pr comment --body x` のようにコマンドの中で作業ディレクトリを変えた呼び出しは、hook の `cwd` のリポジトリとブランチで解決される／`github.com` 以外のホストの URL は対象にならない／`www.github.com` のような github.com の別名の origin は github.com と見なさず、積まない／前のコマンドでの `export GH_HOST=...`・`gh` の設定の既定ホストなど、コマンドから読めない形で別のホストを指した場合は、github.com の同じ番号の対象に積むことがある（書き込みは常に github.com に向く）／番号を省いたときと `gh pr create` で、同じヘッドブランチの PR が複数あれば、GitHub が返す一覧の先頭が対象になる／ブランチ名や `owner:branch` の位置引数は対象にならない／`gh pr create` の出力（作られた PR の URL）は読まないので、`git checkout` や `cd` で `cwd` のブランチと違うブランチから `--head` 無しで作った PR は対象にならないか、`cwd` のブランチの PR として解決される／`gh api` の endpoint を完全な URL や `:owner/:repo` で書いたものは対象にならない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

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

### Requirement: 状態の変更は実測してから積む
システムは状態を変えるきっかけについて、積む前に GitHub に問い合わせ、その状態になっていることを確かめ MUST る。`Ready` は `draft` が false、`PR クローズ` と `issue クローズ` は `state` が closed、`マージ` はマージ済み、`PR 再オープン` と `issue 再オープン` は `state` が open、`ゲート通過` はラベルが付いていること。`PR 作成` は `state` が open で、作成時刻（`created_at`）がきっかけの時刻の前後 300 秒以内であること（`gh pr create` が失敗して、同じブランチの前からある PR が見つかった場合に積まないため）。なっていなければ、そのきっかけでは積んではなら MUST NOT ない。コメントのきっかけは、対象が存在することだけを確かめ SHALL る。この確認は、きっかけが `gh` のサブコマンドでも `gh api` でも同じに SHALL 行う。

守備範囲: この確認が受け取る入力は、対象の確認で GitHub が返す応答（`state`・`draft`・`merged`・`merged_at`・`labels`・`created_at`）と、hook が起動した手元の時刻に限る。拾いたい誤りは、失敗したコマンドの節目を積むことの 1 つ。次の入力は誤ったまま通ることを許す: 手元の時計が GitHub の時計より 300 秒を超えてずれていると、`PR 作成` の行が積まれない／既に open の PR への `gh pr reopen`、既に Ready の PR への `gh pr ready` のように、状態が前からそうだった対象でも行が積まれる（数字は正しい）／`created_at` が無い・読めない応答では `PR 作成` を積まない／PR を作ってから 300 秒以内にもう一度 `gh pr create` を実行し、「既にある」で失敗した場合は、`PR 作成` の行がもう 1 行積まれる（数字は正しく、きっかけの名前だけが実際と合わない）／`gh pr create ... && <5 分を超える処理>` のように、同じ Bash 呼び出しの中で PR の作成から hook の起動までが 300 秒を超えた場合は、`PR 作成` の行が積まれない（その分は次の節目の行の増分に含まれる）。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: マージされていない
- **WHEN** `gh pr merge 300 --auto` の hook JSON を流し、問い合わせた PR がマージ済みでない
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: `gh api` のマージが失敗していた
- **WHEN** `gh api -X PUT repos/o/r/pulls/300/merge` の hook JSON を流し、問い合わせた PR がマージ済みでない
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: クローズに失敗していた
- **WHEN** `gh issue close 12` の hook JSON を流すが、問い合わせた issue の `state` が open
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: `gh api` のクローズが失敗していた
- **WHEN** `gh api -X PATCH repos/o/r/pulls/300 -f state=closed` の hook JSON を流すが、問い合わせた PR の `state` が open
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 再オープンに失敗していた
- **WHEN** `gh pr reopen 300` の hook JSON を流すが、問い合わせた PR の `state` が closed
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 前からある PR には `PR 作成` を積まない
- **WHEN** `gh pr create --title x --body y` の hook JSON を流し、`cwd` のブランチをヘッドに持つ PR の `created_at` がきっかけの時刻の 1 時間前
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: PR が作られていない
- **WHEN** `gh pr create --title x --body y` の hook JSON を流し、`cwd` のブランチをヘッドに持つ PR が無い
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 存在しない番号
- **WHEN** `gh pr comment 999 --body x` の hook JSON を流すが、#999 の問い合わせが失敗する
- **THEN** コメントの作成も書き換えも行われない

### Requirement: 1 本のコメントに行を積む
システムは PR / issue 1 件につき、`<!-- cost-ledger:timeline` で始まる行を持つコメントを 1 本だけ SHALL 保つ。そのコメントが既にあれば `gh api -X PATCH` で本文を書き換え、無ければ新規作成 MUST する。1 回の書き換えで足す表の行は、節目の行 1 行と、「`issue クローズ` では、閉じた PR を合わせた合計の行を積む」が定める場合の合計の行 1 行だけと MUST する（合計の行が無い節目では 1 行だけ足す）。新しい行の時刻が既存のどの行よりも遅いときは末尾に足し（足さないのは、時刻・きっかけ・累計がすべて同じ行が既にあるときと、`--backfill` を付けた呼び出しで「`--backfill` を付けた `timeline` は、既にある行を足さず、手元にコストが無ければ積まない」が定める場合だけ）、既存の行を書き換えても削除してもなら MUST NOT ない（時刻が前後したときの扱いは「行は時刻順に並べ、完了順によらず同じ本文にする」）。書き換えに失敗したときに新規作成へ切り替えてはなら MUST NOT ない。既存のコメントの有無が分からなかった（検索が失敗した）ときは、書いてはなら MUST NOT ない。

本文は次の構成と SHALL する。

1. 1 行目: 並びのいちばん最後の行の累計の行で、`headline()` が作る。最後の行が合計の行でないときは、その時刻に `/cost <その番号>` を実行したときの出力の 1 行目と同じ行。最後の行が合計の行（きっかけの欄が `合計（` で始まる行）のときは、金額が合計で、帰属の種別が `区間+閉じた PR` の行
2. 空行をはさんで Markdown の表。見出しは `| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |`。行は時刻の昇順
3. 空行をはさんで最終行: `<!-- cost-ledger:timeline v1 <記録> <記録> ... -->`。記録は表の行 1 行につき 1 つで（合計の行も 1 つ持つ）、表と同じ順に空白で区切る。1 つの記録は `<時刻>:<金額>:<入出力トークン>:<キャッシュトークン>`（時刻は小数 3 桁の epoch 秒、金額は小数 6 桁、トークンは整数。その行の累計の丸める前の値）

古い目印 `<!-- cost-ledger:gate-report -->` を持つコメントは、探しても書き換えても削除してもなら MUST NOT ない。

#### Scenario: 初回
- **WHEN** 目印付きのコメントが無い PR に `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** コメントが 1 本新規作成され、1 行目が `コスト: ` で始まり、表の行が 1 行で、最終行が `<!-- cost-ledger:timeline v1 ` で始まる

#### Scenario: 2 回目以降
- **WHEN** 目印付きのコメント（表の行が 2 行）がある PR に `gh pr ready 300` の hook JSON を流す
- **THEN** そのコメントが PATCH で書き換えられ、新しいコメントは作成されず、表の行は 3 行で、先頭の 2 行は書き換え前と同じ

#### Scenario: 書き換えに失敗する
- **WHEN** PATCH が失敗する環境で、目印付きのコメントがある PR にきっかけの hook JSON を流す
- **THEN** 新しいコメントは作成されない

#### Scenario: 古い形のコメントには触らない
- **WHEN** `<!-- cost-ledger:gate-report -->` を持つコメントだけがある PR にきっかけの hook JSON を流す
- **THEN** 新しいコメントが 1 本作成され、古いコメントへの PATCH は行われない

#### Scenario: 最後の行が合計の行のときの 1 行目
- **WHEN** issue #12 に帰属する区間の合計が $3.00、ブランチ `feat/a` の合計が $3.00（うち $1.00 が区間と重なる）の会話ログで、標準入力を空にして `timeline --issue 12 --trigger "issue クローズ" --closing-pr 300:feat/a` を実行する
- **THEN** 1 行目は `コスト: $5.00` で始まり、`issue #12` を含み、`帰属: 区間+閉じた PR` で終わる

#### Scenario: 合計の行のあとに行が積まれると 1 行目は区間の累計に戻る
- **WHEN** 最後の行が合計の行（合計 $5.00、区間の累計 $3.00）のコメントに、より後の時刻で `timeline --issue 12 --trigger "issue 再オープン"` を実行する（区間の累計は $3.00 のまま）
- **THEN** 1 行目は `cost_ledger.py cost 12` の 1 行目と一致し、合計の行は書き換え前と 1 文字も違わない

### Requirement: 行の書式
システムは表の 1 行を `| <時刻> | <きっかけ> | <金額> | <入出力> | <キャッシュ> |` と SHALL する。この行を作る実装は `cost_ledger.py` の 1 か所（`timeline_row()`）だけと MUST する（合計の行もここで作る）。

- 時刻: きっかけのコマンドを実行した時刻（hook が起動した時刻。`--at`）を、実行したマシンのローカル時刻で `MM/DD HH:MM`
- 累計: きっかけの時刻以前の応答だけを数えた値（「累計はきっかけの時刻で切る」）
- 金額・入出力・キャッシュ: どれも `<累計> (<符号つきの増分>)`。0 以上は `+`、負は `-` を付ける
- 増分の基準: 合計の行でない行の増分は、並びの上でその行より前にある行のうち、合計の行でない、いちばん近い行の累計との差（合計の行を飛ばす）。そのような行が無い行の増分は累計と同じ値。合計の行の増分は、同じ時刻の節目の行の累計との差（「`issue クローズ` では、閉じた PR を合わせた合計の行を積む」）
- 金額: `$` と小数 2 桁、3 桁区切り。増分には `$` を付けない（例: `$39.62 (+23.02)`）
- トークン: 1,000 未満はそのままの整数、1,000,000 未満は整数の `K`、10,000,000 未満は小数 1 桁の `M`、1,000,000,000 未満は整数の `M`、それ以上は小数 1 桁の `B`（例: `900K`・`2.1M`・`81M`・`1.2B`）。四捨五入した結果が次の単位に届くときは、次の単位で書く（999,999 は `1.0M`、9,999,999 は `10M`、999,999,999 は `1.0B`。`1000K`・`10.0M`・`1000M` とは書かない）
- 入出力トークンは入力トークンと出力トークンの和、キャッシュトークンはキャッシュ書き込み（5 分・1 時間）とキャッシュ読み出しの和。単価が引けないモデルの行のトークンも数える

#### Scenario: 2 行目の増分
- **WHEN** 前の累計が $16.60・入出力 900,000・キャッシュ 33,000,000 のコメントに、累計が $39.62・入出力 2,100,000・キャッシュ 81,000,000 の時点で 1 行積む
- **THEN** 足された行の金額は `$39.62 (+23.02)`、入出力は `2.1M (+1.2M)`、キャッシュは `81M (+48M)`

#### Scenario: 初回の行
- **WHEN** コメントが無い状態で、累計が $16.60 の時点で 1 行積む
- **THEN** 足された行の金額は `$16.60 (+16.60)`

#### Scenario: 累計が減った
- **WHEN** 前の累計が $5.00 のコメントに、累計が $3.80 の時点で 1 行積む
- **THEN** 足された行の金額は `$3.80 (-1.20)`

#### Scenario: 未知モデルのトークンも数える
- **WHEN** 料金表に無いモデルの応答（入力 1,000 トークン）だけがあるブランチで、標準入力を空にして 1 行積む
- **THEN** 終了コードは 0 で本文が出力され、足された行の金額は `$0.00 (+0.00)`、入出力は `1K (+1K)`

#### Scenario: 合計の行のあとの行は合計を基準にしない
- **WHEN** 表の行が `issue クローズ`（累計 $3.00）と合計の行（累計 $5.00）の 2 行のコメントに、より後の時刻で、区間の累計が $3.50 の時点で `timeline --issue 12 --trigger "issue 再オープン"` を実行する
- **THEN** 足された行の金額は `$3.50 (+0.50)`（`-1.50` ではない）

### Requirement: 前の節目の値はコメントの最終行から読む
システムは増分の計算に使う前の行の累計を、既存のコメントの最終行（`<!-- cost-ledger:timeline v1 <記録> ... -->`）の記録から SHALL 読む。表に表示した丸めた数字から読み戻してはなら MUST NOT ない。前の値を手元のファイルに保存してはなら MUST NOT ない（別のマシンから同じ PR に積んでも増分がつながるようにするため）。

最終行が読めないとき（目印の行が無い・記録の形が崩れている・値が数値でない）、システムは既存の表の行をそのまま残し、新しい行を末尾に足して 3 項目の増分を `(?)` と書 SHALL く。0 として計算してはなら MUST NOT ない。新しい最終行は今回の記録 1 つから始める。以後、表の行数が記録の数より多いあいだ、システムは先頭の余りの行をそのまま残し、最初の記録の行の増分を `(?)` のままに SHALL する。

守備範囲: この読み取りが受け取る入力は、この hook 自身が書いたコメントの本文（GitHub から取得したもの）に限る。本文を書き換えられるのは、書いたアカウントとリポジトリの管理権限を持つ人だけ。拾いたい誤りは、丸めた表示から増分を出して誤差を積むことと、読めない状態を 0 とみなして「この節目で全額増えた」行を書くことの 2 つ。次の入力は誤ったまま通ることを許す: 記録の形を保ったまま数値だけを手で書き換えた最終行は、その値がそのまま前の累計として使われる／表の行を手で並べ替えたり一部だけ消したりして、行数が記録の数以下になった本文は、行と記録の対応がずれたまま次の行が足される／目印の行を持つコメントを別の人が貼った場合は、GitHub が返す一覧で先に現れた 1 本が使われる／意図的な改ざんは検知しない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 丸めの誤差を持ち越さない
- **WHEN** 最終行の最後の記録が `<時刻>:16.604000:949999:33000000` のコメントに、それより後の時刻で、累計の入出力が 1,050,001 の時点で 1 行積む
- **THEN** 入出力の増分は `+100K`（表示の `950K` と `1.1M` の差ではなく、正確な値の差）

#### Scenario: 最終行が壊れている
- **WHEN** 目印の行はあるが記録の金額が数値でないコメント（表の行が 2 行）に 1 行積む
- **THEN** 既存の 2 行は書き換え前と同じで、足された行は末尾にあり増分は 3 項目とも `(?)`、新しい最終行の記録は今回の 1 つだけ

#### Scenario: 壊れたあとの次の行
- **WHEN** 表の行が 3 行で最終行の記録が 1 つのコメントに、その記録より後の時刻で 1 行積む
- **THEN** 既存の 3 行は書き換え前と同じで、足された行の増分は記録との正確な差、最終行の記録は 2 つ

### Requirement: 累計はきっかけの時刻で切る
システムは 1 行の累計を、きっかけの時刻（`--at`。hook の同期部分が取った時刻）以前の `timestamp` を持つ応答だけで MUST 数える。`timestamp` が読めない行は数える。issue の区間分割は、切ったあとの行だけで SHALL 行う。きっかけの時刻より後の応答を数えてはなら MUST NOT ない。同じ内容の台帳（会話ログ）を読めば、裏の処理が動いた時刻に関係なく同じ値にな MUST る。

きっかけの時刻以前の `timestamp` を持つ応答が、裏の処理が台帳を読んだあとで書かれた場合、その分はその行に入らず、そのあとで台帳を読んで積まれる行の増分に入 SHALL る（累計はその行で合う）。既に積んだ行の累計を、あとから書き直して合わせてはなら MUST NOT ない。

#### Scenario: きっかけより後の応答は数えない
- **WHEN** 時刻 T より前の応答（$1.00）と T より後の応答（$2.00）がある会話ログで、`timeline --at T` を実行する
- **THEN** 足された行の金額は `$1.00 (+1.00)` で、1 行目の金額も $1.00

#### Scenario: 同じ内容を読めば同じ本文になる
- **WHEN** 同じ会話ログと同じ標準入力で、`timeline --at T` を時間をおいて 2 回実行する
- **THEN** 2 回の出力は 1 文字も違わない

#### Scenario: 読んだあとに書かれた応答は次の行の増分に入る
- **WHEN** 時刻 T1 より前の応答（$1.00）だけがある会話ログで `timeline --at T1` を実行し、そのあとで T1 より前の `timestamp` を持つ応答（$0.50）と、T1 と T2 のあいだの応答（$2.00）を会話ログに足し、1 回目の出力を標準入力にして `timeline --at T2` を実行する
- **THEN** 表の 1 行目の金額は `$1.00 (+1.00)` のままで、表の 2 行目の金額は `$3.50 (+2.50)`

#### Scenario: issue も同じ時刻で切る
- **WHEN** issue #12 に帰属する区間に時刻 T の前後の応答がある会話ログで、`timeline --issue 12 --at T` を実行する
- **THEN** 足された行の累計は、T より後の応答を会話ログから除いて `cost_ledger.py cost 12` を実行した値と同じ

### Requirement: 行は時刻順に並べ、完了順によらず同じ本文にする
システムは表の行と最終行の記録を、次の鍵の昇順で SHALL 保ち、新しい記録をその順の位置に入れ MUST る。合計の行も同じ鍵で並べる（きっかけの欄が `合計（` で始まるので、同じ時刻の `issue クローズ` を含む節目の行のあとに来る）。

1. きっかけの時刻（ミリ秒まで）
2. 時刻が同じなら、きっかけの呼び名の文字列（UTF-8 のバイト順）。既存の行の呼び名は、表のその行の「きっかけ」の欄から読む
3. それも同じなら、累計の金額、入出力トークン、キャッシュトークンの順

3 つの鍵がすべて同じ記録が既にあるとき、システムは同じ節目の二重実行とみなし、行を足してはなら MUST NOT ない。節目の行と合計の行は別々に判定し、どちらも既にあれば本文を変えずに返す。

新しい行の増分の基準は「行の書式」に SHALL 従う。新しい節目の行より後ろになる既存の記録があるとき、システムは後ろにある行のうち、合計の行でない最初の 1 行の増分 3 項目を「その行の累計 − 新しい節目の行の累計」に書き直 MUST し、その行の時刻・きっかけ・累計の表示と、それ以外の行（合計の行を含む）を変えてはなら MUST NOT ない。合計の行を入れることで既存の行を書き直してはなら MUST NOT ない。1 行目は、いちばん最後の記録の金額から作 SHALL る（「1 本のコメントに行を積む」）。

同じ対象への複数のきっかけの処理は、それぞれが同じ内容の台帳（会話ログ）を読み、同じ `--closing-pr` を受け取ったかぎり、どの順で完了しても、すべて完了したあとの本文が同じで MUST ある。

#### Scenario: 逆順で完了する 2 つの呼び出し
- **WHEN** 同じ会話ログに対して、空の本文に `timeline --at T2 --trigger Ready` を実行し、その出力を標準入力にして `timeline --at T1 --trigger "PR コメント"` を実行する（T1 < T2。T1 以前の累計は $1.00、T2 以前の累計は $3.00）
- **THEN** 表の行は `PR コメント`・`Ready` の順で、金額は `$1.00 (+1.00)`・`$3.00 (+2.00)`、1 行目の金額は $3.00 で、本文全体が T1・T2 の順に実行した場合と 1 文字も違わない

#### Scenario: 同じ時刻の 2 つの呼び出し
- **WHEN** 同じ会話ログに対して、同じ `--at T` で `--trigger Ready` と `--trigger "PR コメント"` の 2 つを、Ready → PR コメント の順と、PR コメント → Ready の順のそれぞれで続けて実行する（2 回目は 1 回目の出力を標準入力にする）
- **THEN** 2 つの順の本文は 1 文字も違わず、表の行は呼び名のバイト順で並び、下の行の増分は 3 項目とも 0（`+0.00`・`+0`）

#### Scenario: 同じ節目の二重実行
- **WHEN** 表の行が 1 行のコメントに、その行と同じ時刻・同じきっかけ・同じ累計で `timeline` を実行する
- **THEN** 終了コードは 0 で、出力は標準入力の本文と同じ（行は増えない）

#### Scenario: 先のきっかけの処理が遅れる
- **WHEN** 同じ PR へのきっかけの hook JSON を 2 つ続けて流し、先に流した方の「対象の確認」の `gh` だけが遅れて、後に流した方が先に書き込む
- **THEN** 両方が終わったあとのコメントは 1 本で、表の行は 2 行で、先に流したきっかけの行が上にある

#### Scenario: ふつうの順では既存の行を変えない
- **WHEN** 表の行が 2 行のコメントに、どの記録よりも後の時刻で 1 行積む
- **THEN** 先頭の 2 行は書き換え前と 1 文字も違わない

#### Scenario: 合計の行がある本文でも完了順によらない
- **WHEN** 同じ会話ログに対して、T1 < T2 < T3 の 3 つの呼び出し（`--issue 12 --at T1 --trigger "issue コメント"`、`--issue 12 --at T2 --trigger "issue クローズ" --closing-pr 300:feat/a`、`--issue 12 --at T3 --trigger "issue 再オープン"`）を、T1 → T2 → T3 の順と、T3 → T2 → T1 の順のそれぞれで続けて実行する（2 回目以降は前の出力を標準入力にする）
- **THEN** 2 つの順の本文は 1 文字も違わず、表の行は `issue コメント`・`issue クローズ`・合計の行・`issue 再オープン` の順で、`issue 再オープン` の行の増分は `issue クローズ` の行の累計との差

#### Scenario: 合計の行つきの節目の二重実行
- **WHEN** `--closing-pr 300:feat/a` を付けた `timeline --issue 12 --trigger "issue クローズ"` の出力を標準入力にして、同じ引数でもう 1 回実行する
- **THEN** 終了コードは 0 で、出力は標準入力の本文と同じ（表の行は 2 行のまま）

### Requirement: 数字と書式は `timeline` サブコマンドから取る
システムは `cost_ledger.py timeline` を持ち、標準入力で既存のコメント本文（無ければ空）を受け取って、節目の行を 1 行（`--issue` に `--closing-pr` が 1 つ以上渡されたときは、続けて合計の行を 1 行）足した新しい本文を標準出力に返 MUST す。hook は集計・単価・書式を自分で持ってはなら MUST NOT ない。`timeline` は `gh` を呼んではなら MUST NOT ない（PR か issue かは hook が判別して `--pr <番号> --branch <ヘッドブランチ>` か `--issue <番号>` で渡し、issue を閉じた PR も hook が問い合わせて `--closing-pr <PR番号>:<ヘッドブランチ>` で渡す）。

節目の行の累計は、きっかけの時刻より後の応答が無いとき、PR では `cost_ledger.py cost <PR番号>` と、issue では `cost_ledger.py cost <issue番号>` と同じ値で MUST ある（`--closing-pr` を渡しても節目の行の累計は変わらない）。ただし子 issue を持つ issue では、`cost_ledger.py cost <issue番号>` の 1 行目は子 issue を含めた合計になるので（spec `cost-ledger-cost-command` の「子 issue を持つ issue では、子 issue ごとの内訳と合計を返す」）、節目の行の累計が一致する相手は `cost_ledger.py issue <issue番号>` の値（区間の合計）と MUST する。`timeline` は子 issue を調べず、子 issue を持つ issue に積む行も今までどおり、その issue の番号を触った区間だけの累計と SHALL する。`COST_LEDGER_PATH` があるときは、他の集計系サブコマンドと同じく、読む前に会話ログの差分を台帳へ追記してから台帳を読 SHALL む。差分の追記は、`--closing-pr` が何件あっても 1 回の呼び出しで 1 回だけと SHALL する。

次のときは何も出力せず終了コード 3 を返し、hook は何も書いてはなら MUST NOT ない。

- 節目の行の累計の金額・入出力トークン・キャッシュトークンがすべて 0 で、既存のコメント本文が空で、合計の行を積む場合はその累計もすべて 0（金額が 0 でもトークンがあれば積む）
- issue でも PR でも、対象のリポジトリ（`--target-repo`）が `--repo` の場所のリポジトリと一致しない（`--repo` の場所のリポジトリが判別できないときを含む。既存のコメント本文があっても積まない）

`--target-repo` を渡さない呼び出し（手で実行する場合）では、この照合を行わない。hook は常に `--target-repo` を渡 MUST す。

守備範囲: `timeline` が受け取る入力は、hook（`gate_report.py`）か手で実行する利用者が渡す引数（`--pr`・`--branch`・`--issue`・`--closing-pr`・`--target-repo`・`--at`）と、標準入力の既存のコメント本文、台帳または会話ログの行に限る。拾いたい誤りは、節目の行の累計が `cost_ledger.py cost`（子 issue を持つ issue では `cost_ledger.py issue`）の値とずれること・別のリポジトリの issue や PR に行を積むこと・`timeline` が `gh` を呼んで hook の待ち時間と呼び出し回数を増やすことの 3 つ。次のことは誤ったまま通ることを許す: 手で実行して `--target-repo` を省いたときは、リポジトリの照合を行わずに行を積む／`--issue` に渡された番号が実際には PR だった・`--closing-pr` のヘッドブランチが実際のものと違う、のように引数が事実と合わないときは、渡された値のまま集計する（判別と問い合わせは hook の受け持ち）／子 issue を持つ issue に積む行は、子 issue の分を含まない区間だけの累計になる。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 1 行目が `/cost` と一致する
- **WHEN** 同じ会話ログで、どの応答よりも後の時刻を `--at` に渡した `cost_ledger.py timeline --pr 300 --branch <ブランチ> ...` と `cost_ledger.py cost 300` を実行する
- **THEN** `timeline` の出力の 1 行目と `cost` の出力の 1 行目が一致する

#### Scenario: issue の累計が `/cost` と一致する
- **WHEN** issue #12 に帰属する区間がある会話ログで、どの応答よりも後の時刻を `--at` に渡した `cost_ledger.py timeline --issue 12 ...` と `cost_ledger.py cost 12` を実行する
- **THEN** `timeline` の出力の 1 行目と `cost` の出力の 1 行目が一致する

#### Scenario: 最後の追記以降の応答も含む
- **WHEN** `ledger-sync` のあとで会話ログに応答が増え、Stop hook を待たずに、その応答より後の時刻を `--at` に渡して `timeline` を実行する
- **THEN** 増えた応答も累計に含まれる

#### Scenario: コストが無くコメントも無い
- **WHEN** そのブランチの行が 1 つも無い状態で、標準入力を空にして `timeline --pr 300 --branch <ブランチ>` を実行する
- **THEN** 出力は空で、終了コードは 3

#### Scenario: 別リポジトリの issue
- **WHEN** `cwd` が acme/repo-a のリポジトリで、`gh issue comment 12 -R acme/repo-b --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 別リポジトリの PR
- **WHEN** `cwd` が acme/repo-a のリポジトリで、ヘッドブランチと同じ名前のブランチにコストがある状態で `gh pr comment https://github.com/acme/repo-b/pull/300 --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: `--target-repo` が違う PR
- **WHEN** そのブランチにコストがある状態で、`--repo` に acme/ra のリポジトリの場所、`--target-repo` に `acme/other` を渡して `timeline --pr 300 --branch <ブランチ>` を実行する
- **THEN** 出力は空で、終了コードは 3

#### Scenario: `--target-repo` を渡さない PR
- **WHEN** そのブランチにコストがある状態で、`--target-repo` を渡さずに `timeline --pr 300 --branch <ブランチ>` を実行する
- **THEN** 終了コードは 0 で、行が 1 行積まれた本文が出力される

#### Scenario: `--closing-pr` を渡しても節目の行は変わらない
- **WHEN** issue #12 に帰属する区間がある会話ログで、標準入力を空にして、`--closing-pr 300:feat/a` を付けた場合と付けない場合の `timeline --issue 12 --trigger "issue クローズ"` を同じ `--at` で実行する
- **THEN** 表の 1 行目（`issue クローズ` の行）は 2 つの出力で 1 文字も違わない

#### Scenario: 区間も合計も 0 でコメントも無い
- **WHEN** issue #13 に帰属する区間もブランチ `feat/none` の行も無い状態で、標準入力を空にして `timeline --issue 13 --trigger "issue クローズ" --closing-pr 300:feat/none` を実行する
- **THEN** 出力は空で、終了コードは 3

#### Scenario: 子 issue を持つ issue に積む行は区間だけの累計
- **WHEN** issue #10 に帰属する区間の行が 1 行（$1.00）あり、ブランチ `feat/a` の行が 2 行（各 $1.00）ある会話ログで、標準入力を空にし、どの行よりも後の時刻を `--at` に渡して `timeline --issue 10 --trigger "issue コメント"` を実行する（`gh` は、#10 が子 issue #11 を持ち、#11 を閉じた PR のヘッドブランチが `feat/a` だと答える状態にしておく）
- **THEN** 行の金額は `$1.00 (+1.00)` で、`gh` が呼ばれた回数は 0 回で、1 行目は `cost_ledger.py issue 10` の 1 行目と一致する

### Requirement: issue の集計は関係するセッションだけを読む
`COST_LEDGER_PATH` があるとき、システムは issue の累計を、台帳のうちその issue 番号を触った行を持つセッションの行だけを読んで SHALL 求める。結果は台帳の全行を読んで区間に切った場合と同じで MUST ある。`cost_ledger.py cost <issue番号>` と `cost_ledger.py issue <番号>` も同じ読み方を SHALL 使う。

#### Scenario: 絞っても値が変わらない
- **WHEN** 複数のセッションが複数の issue を触っている会話ログを台帳へ取り込み、`cost_ledger.py issue <番号> --json` を実行する
- **THEN** `total_usd`・`messages`・`intervals` は、`COST_LEDGER_PATH` を未設定にして同じ会話ログを直接読んだ場合と同じ

### Requirement: hook は判定だけをして、残りを裏で行う
システムは hook の同期部分でコマンド文字列の判定だけを行い、対象が見つかったら、GitHub への問い合わせ・集計・書き込みを hook のプロセスから切り離した別プロセスで行 MUST う。同期部分で `gh` を呼んだり台帳や会話ログを読んだりしてはなら MUST NOT ない。hook は裏のプロセスの終了を待たずに終了コード 0 で終わ MUST る。

同期部分も裏のプロセスも、stdout と stderr に何も出してはなら MUST NOT ない（会話の文脈に何も入れない）。どの失敗でも、hook は終了コード 0 で終わる。

環境変数 `COST_LEDGER_HOOK_FOREGROUND=1` のとき、システムは切り離さずにその場で最後まで実行 SHALL する（テストと実測のため）。

#### Scenario: gh が遅くても hook はすぐ終わる
- **WHEN** `gh` が 1 回の呼び出しに 3 秒かかる環境で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** hook は 1 秒未満で終了コード 0 で終わり、そのあとでコメントが作成される

#### Scenario: 何も出力しない
- **WHEN** きっかけの hook JSON を流す
- **THEN** hook の stdout と stderr は空

#### Scenario: その場で実行する
- **WHEN** `COST_LEDGER_HOOK_FOREGROUND=1` を付けてきっかけの hook JSON を流す
- **THEN** hook が終わった時点でコメントの作成または書き換えが済んでいる

### Requirement: 同じコメントへの同時の書き込みで行を失わない
システムは対象（リポジトリと番号）ごとの排他ロックを取ってから、コメントの読み取り・行の追加・書き込みを MUST 行う。同じマシンで同じ対象への処理が同時に走っても、積まれる行の数は処理の数と一致しなければなら MUST ない（時刻・きっかけ・累計がすべて同じ処理が 1 行にまとまる場合を除く）。

ロックファイルの置き場は、自分だけが読み書きできる権限（700）で作 SHALL る。置き場が既にあり、シンボリックリンクである・自分の持ち物でない・自分以外が書ける、のどれかに当たるとき、システムはロックを取れなかったものとして扱い、書いてはなら MUST NOT ない（共有の一時ディレクトリに他の利用者が先に作った場所へファイルを作らないため）。

#### Scenario: ロックの置き場がシンボリックリンク
- **WHEN** ロックの置き場の名前で別のディレクトリへのシンボリックリンクが既にある状態で、`gh pr comment 300 --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、リンク先にファイルは作られない

#### Scenario: 同時に 2 つ流す
- **WHEN** 目印付きのコメントが無い PR に、きっかけの違う hook JSON を 2 つ（`gh pr comment 300 --body x` と `gh pr ready 300`）同時に流す
- **THEN** コメントは 1 本で、表の行は 2 行

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

### Requirement: `issue クローズ` では、閉じた PR を合わせた合計の行を積む
システムは、PR でない issue に、きっかけに `issue クローズ` を含む行を積むとき、その issue を閉じた PR を GitHub に 1 回だけ問い合わせ MUST る。問い合わせは裏のプロセスが GraphQL の `closedByPullRequestsReferences`（既定の引数、先頭 100 件）で行い、ホストは他の呼び出しと同じく github.com に固定 SHALL する。それ以外のきっかけと、対象が PR のときは、問い合わせてはなら MUST NOT ない。

返った PR のうち、数えるのは次の両方を満たすものだけと MUST する。

- ベースのリポジトリ（`baseRepository.nameWithOwner`）が対象の issue のリポジトリと一致する（大文字と小文字は区別しない）
- ヘッドブランチが同じリポジトリにある（`isCrossRepository` が偽）

数える PR が 1 件以上あるとき、裏のプロセスは `cost_ledger.py timeline --issue <番号>` に `--closing-pr <PR番号>:<ヘッドブランチ>` を PR の数だけ渡 MUST す。`timeline` は `--closing-pr` を 1 つ以上受け取ったとき、今までどおりの節目の行（区間だけの累計）に続けて、合計の行を 1 行 SHALL 積む。

- 合計の行の時刻は節目の行と同じ
- 合計の行の金額・入出力・キャッシュの累計は、spec `cost-ledger-attribution` の「issue の合計は、閉じた PR の分と、PR のブランチ上に無い区間の分の和である」が定める合計を、きっかけの時刻以前の行だけで数えた値
- 合計の行の増分 3 項目は、同じ呼び出しで作った節目の行の累計との差（既存のコメントの記録が読めないときも `(?)` にしない）
- 合計の行のきっかけの欄は `合計（<PR の内訳> + PR 外 $<額>）`。PR の内訳は、数えた PR の件数によらず、`#<番号> $<額>` を番号の昇順に ` + ` でつないだもの（PR ごとの額を省いたり、まとめたりしてはなら MUST NOT ない）。額は `$` と小数 2 桁、3 桁区切り。手元に行が無い PR も `$0.00` で書く
- 合計の行は `timeline_row()` で作り、隠し行の記録も他の行と同じ形で 1 つ持つ

次のときは合計の行を積んではなら MUST NOT ず、節目の行は今までどおり積 MUST む: 数える PR が 0 件／問い合わせが失敗した／応答が読めない（JSON でない、PR の番号が整数でない、ヘッドブランチが空など、1 件でも形が崩れている）／`pageInfo.hasNextPage` が真。`--closing-pr` の値の形が崩れているとき（`:` が無い、番号が 1 以上の整数でない、ブランチ名が空）と、`--pr` と一緒に渡されたとき、`timeline` は何も出力せず終了コード 2 を返 MUST す。

守備範囲: この判定が受け取る入力は、`gh api graphql` が返す GitHub の応答と、そこから裏のプロセスが組み立てる `--closing-pr` の引数に限る（`timeline` を手で実行する人が打つ引数を含む）。拾いたい誤りは、一部の PR しか読めていない結果を合計として積むこと（100 件を超えた・応答の一部が崩れていた）・ヘッドブランチが別のリポジトリにある PR のブランチ名で手元の同じ名前のブランチの行を引き込むこと・問い合わせの失敗で `issue クローズ` の行まで積まなくなることの 3 つ。次の入力は誤ったまま通ることを許す: 数える PR が 0 件の場合と問い合わせが失敗した場合は、どちらも節目の行だけが積まれ、コメントの上では見分けが付かない／クローズ済みで未マージの PR は GitHub の既定の結果に含まれず、数えない／issue を手で閉じた時点でまだ開いている PR が結果に含まれていれば、その PR も数える／fork から出された PR と別のリポジトリの PR は、その作業が手元の台帳にあっても数えない／`Closes` を書かずに作業した PR は GitHub が結び付けないので数えない／閉じた PR が多い issue では、合計の行が PR の数に比例して長くなる（100 件を超えると積まない）／`timeline` を手で実行して実在しない PR 番号やブランチ名を渡した場合は、そのまま内訳に出る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 重なりのあるデータで合計の行が付く
- **WHEN** issue #12 に帰属する区間の行が 3 行（各 $1.00・入力 1,000,000 トークン。2 行はブランチ `main`、1 行はブランチ `feat/a`）あり、ブランチ `feat/a` の行が全部で 3 行（うち 1 行が前述の区間の行）ある会話ログで、標準入力を空にし、どの行よりも後の時刻を `--at` に渡して `timeline --issue 12 --trigger "issue クローズ" --closing-pr 300:feat/a` を実行する
- **THEN** 表の行は 2 行で、1 行目のきっかけは `issue クローズ`、金額は `$3.00 (+3.00)`、2 行目のきっかけは `合計（#300 $3.00 + PR 外 $2.00）`、金額は `$5.00 (+2.00)`、入出力は `5.0M (+2.0M)`、最終行の記録は 2 つ

#### Scenario: 合計の行はきっかけの時刻で切る
- **WHEN** 重なりのあるデータの Scenario の会話ログで、ブランチ `feat/a` の 3 行のうち 1 行（区間の外の行）だけが時刻 T より後にあり、`--at T` で同じコマンドを実行する
- **THEN** 合計の行のきっかけは `合計（#300 $2.00 + PR 外 $2.00）`、金額は `$4.00 (+1.00)`

#### Scenario: `--closing-pr` が無ければ今までと同じ
- **WHEN** 重なりのあるデータの Scenario の会話ログで、`--closing-pr` を付けずに `timeline --issue 12 --trigger "issue クローズ"` を実行する
- **THEN** 表の行は 1 行で、1 行目は `cost_ledger.py cost 12` の 1 行目と一致する

#### Scenario: PR が 4 件でも PR ごとの額が出る
- **WHEN** 重なりのあるデータの Scenario の会話ログで、`--closing-pr` を 4 つ（303:b3・300:feat/a・301:b1・302:b2 の順。`b1`〜`b3` の行は無い）渡して `timeline --issue 12 --trigger "issue クローズ"` を実行する
- **THEN** 合計の行のきっかけは `合計（#300 $3.00 + #301 $0.00 + #302 $0.00 + #303 $0.00 + PR 外 $2.00）`

#### Scenario: 区間が無くても PR の分があれば積む
- **WHEN** issue #13 に帰属する区間が無く、ブランチ `feat/a` に行がある会話ログで、標準入力を空にして `timeline --issue 13 --trigger "issue クローズ" --closing-pr 300:feat/a` を実行する
- **THEN** 終了コードは 0 で、表の行は 2 行で、1 行目の金額は `$0.00 (+0.00)`

#### Scenario: hook が閉じた PR を渡す
- **WHEN** `closedByPullRequestsReferences` が PR #704（ヘッドブランチ `feat/x`、ベースは対象と同じリポジトリ）を 1 件返す issue #12 に、`gh issue close 12` の hook JSON を流す
- **THEN** `timeline` は `--issue 12` と `--closing-pr 704:feat/x` を受け取り、コメントが 1 本書き込まれる

#### Scenario: 閉じた PR が 0 件
- **WHEN** `closedByPullRequestsReferences` が 0 件を返す issue #12 に、`gh issue close 12` の hook JSON を流す
- **THEN** `timeline` は `--closing-pr` を受け取らず、コメントが 1 本書き込まれる

#### Scenario: 問い合わせが失敗する
- **WHEN** GraphQL の呼び出しだけが失敗する環境で、`gh issue close 12` の hook JSON を流す
- **THEN** `timeline` は `--closing-pr` を受け取らず、コメントが 1 本書き込まれる

#### Scenario: 別のリポジトリの PR と fork の PR は数えない
- **WHEN** `closedByPullRequestsReferences` が 3 件（ベースが対象と同じリポジトリの #704、ベースが別のリポジトリの #9、`isCrossRepository` が真の #705）を返す issue #12 に、`gh issue close 12` の hook JSON を流す
- **THEN** `timeline` が受け取る `--closing-pr` は `704:feat/x` の 1 つだけ

#### Scenario: 100 件を超える
- **WHEN** `pageInfo.hasNextPage` が真の応答を返す issue #12 に、`gh issue close 12` の hook JSON を流す
- **THEN** `timeline` は `--closing-pr` を受け取らず、コメントが 1 本書き込まれる

#### Scenario: クローズ以外では問い合わせない
- **WHEN** issue #12 に `gh issue comment 12 --body x` の hook JSON を流す
- **THEN** GraphQL の呼び出しは 0 回

#### Scenario: 番号が PR だった
- **WHEN** PR である #300 に `gh issue close 300` の hook JSON を流す
- **THEN** GraphQL の呼び出しは 0 回で、行のきっかけは `PR クローズ`

#### Scenario: 形の崩れた `--closing-pr`
- **WHEN** `timeline --issue 12 --trigger "issue クローズ" --closing-pr 300` を実行する
- **THEN** 出力は空で、終了コードは 2

### Requirement: `gh api` の呼び出しの読み方
システムは `gh api` の呼び出しを、endpoint・メソッド・フィールドの 3 つに分けて SHALL 読む。きっかけの判定（「行を積むきっかけ」）と合格ラベルの付与の判定（`cost-ledger-gate-report`）は、どちらもこの読み方を MUST 使う。

- **endpoint**: `api` より後ろの語を前から見て、オプションとその値を除いた最初の語。endpoint は 1 つだけで、オプションの値を endpoint として読んではなら MUST NOT ない
- **値を取るオプション**: `-X` / `--method`・`-f` / `--raw-field`・`-F` / `--field`・`-H` / `--header`・`--input`・`-q` / `--jq`・`-t` / `--template`・`-p` / `--preview`・`--hostname`・`--cache`。次の語を値として読む。`--name=値` の形と、短いオプションに値を続けた形（`-XPATCH`・`-fstate=closed`）は 1 語で読む。これ以外の `-` で始まる語は値を取らないものとして読む
- **メソッド**: `-X` / `--method` の値（複数あれば最後のもの。大文字と小文字は区別しない）。指定が無ければ、フィールドか `--input` が 1 つでもあれば POST、どちらも無ければ GET（gh の既定と同じ）。値が解決できないときは、その呼び出しを積まずに飛ば MUST す
- **フィールド**: `-f` / `--raw-field` / `-F` / `--field` の値（`キー=値`）。`state=closed`・`state=open`・`labels[]=agent-review:passed` は、フィールドの値の全体がこの文字列に一致するときだけ認める。`state` のフィールドが複数あれば最後のものを使う。`--input` で渡した本文の中身は読まない

endpoint・メソッド・フィールドの値は、同じコマンドの中の単純な代入と `for` の展開で SHALL 解決する（`cost-ledger-gate-report` の付与の判定と同じ規則）。

守備範囲: この読み方が受け取る入力は、`tool_input.command` を語に分けたうちの、`gh api` の 1 回の呼び出しの語の並びに限る。拾いたい誤りは、オプションの値（`--input` のファイル名、`--jq` の式、`-H` のヘッダー）を endpoint やフィールドとして読んで、コマンドが触れていない PR / issue を対象にすることと、読み取り（GET）を書き込みとして読むことの 2 つ。次の入力は誤ったまま通ることを許す: 上の表に無い、値を取るオプションが `gh` に増えた場合、その値を endpoint として読むことがある（endpoint の形に一致しなければ積まれない）／`--` より後ろの語の扱いは区別しない／`--input` の JSON の中の `state` や `labels` は見えない／`-F state=@file` のように値をファイルから読む形は一致しないので積まれない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: メソッドを省いた投稿は POST
- **WHEN** `gh api repos/o/r/issues/300/comments -f body=x` の hook JSON を流す
- **THEN** #300 が `issue コメント` のきっかけの対象になる

#### Scenario: `--input` だけの投稿も POST
- **WHEN** `gh api repos/o/r/issues/300/comments --input body.json` の hook JSON を流す
- **THEN** #300 が `issue コメント` のきっかけの対象になる

#### Scenario: フィールドも `--input` も無ければ GET
- **WHEN** `gh api repos/o/r/issues/300/comments --paginate --jq '.[].body'` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: オプションの値を endpoint として読まない
- **WHEN** `gh api repos/acme/repo-a/issues/5/labels -X POST --input repos/acme/repo-a/issues/300/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** 対象の確認は #5 に対してだけ行われ、#300 は問い合わせも書き込みもされない

#### Scenario: `--jq` やヘッダーの値を endpoint として読まない
- **WHEN** `gh api --jq repos/o/r/issues/300/comments -H repos/o/r/pulls/300/merge -X PUT repos/o/r/pulls/7/merge` の hook JSON を流す
- **THEN** 対象の確認は #7 に対してだけ行われる

#### Scenario: 値を続けて書いた短いオプション
- **WHEN** `gh api -XPATCH repos/o/r/pulls/300 -fstate=closed` と `gh api --method=PATCH repos/o/r/pulls/300 --raw-field=state=closed` の hook JSON をそれぞれ流す（#300 の `state` は closed）
- **THEN** どちらも #300 に行が 1 行積まれ、きっかけの欄は `PR クローズ`

#### Scenario: フィールドの値の一部に含むだけでは認めない
- **WHEN** `gh api -X PATCH repos/o/r/pulls/300 -f body='state=closed'` や `gh api -X PATCH repos/o/r/pulls/300 -f title=x --jq state=closed` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 同じコマンドの中の代入を展開する
- **WHEN** `R=o/r; N=300` のあとに `gh api -X PUT repos/$R/pulls/$N/merge` が続くコマンドの hook JSON を流す（#300 はマージ済み）
- **THEN** o/r の #300 に行が 1 行積まれ、きっかけの欄は `マージ`

### Requirement: `--backfill` を付けた `timeline` は、既にある行を足さず、手元にコストが無ければ積まない
システムは `cost_ledger.py timeline` に `--backfill` を持 MUST つ。`--backfill` は後追い（`cost-ledger-backfill`）が渡すもので、`--at` には GitHub が記録した出来事の時刻（マージ・クローズの時刻）が入る。付けないときの振る舞いは、この要件で変えてはなら MUST NOT ない。この要件の 2 つの判定は、「1 本のコメントに行を積む」の「時刻・きっかけ・累計がすべて同じ行が既にあるときは足さない」に加えて行を足さない場合を定めるもので、`--backfill` を付けた呼び出しにだけ効く。

`--backfill` が付いているとき、システムは次の 2 つを、行を足す前に SHALL 判定する。

1. 既存の本文の表に、`--trigger` の呼び名を `+` 区切りの要素として含む行があり、その行の記録の時刻が「`--at` の 300 秒前」以降であるとき、システムは標準入力の本文をそのまま出力し、終了コード 0 を返 MUST す（行を足さない。合計の行も足さない）。記録と対応しない行（表の行数が記録の数より多いときの先頭の余りの行と、最終行が読めない本文のすべての行）は、時刻を見ずに呼び名だけで判定 SHALL する。合計の行（きっかけの欄が `合計（` で始まる行）は、この判定の対象にしない
2. 1 に当たらず、節目の行の累計の金額・入出力トークン・キャッシュトークンがすべて 0 で、合計の行を積む場合はその累計もすべて 0 のとき、システムは既存の本文があっても何も出力せず、終了コード 3 を返 MUST す

どちらにも当たらないとき、システムは `--backfill` を付けない場合と同じ本文を SHALL 返す（行の時刻・並び順・増分・合計の行・1 行目は既存の要件のまま）。

守備範囲: この判定が受け取る入力は、この hook 自身が書いたコメントの本文と、後追いが渡す `--at`（GitHub の時刻、秒単位）・`--trigger`（`マージ` か `issue クローズ`）に限る。拾いたい誤りは、手で `gh pr merge` / `gh issue close` を実行して積まれた行（時刻は hook が動いた手元の時刻）と同じ出来事の行をもう 1 行積むことと、作業していない PC が累計 0 の行を積んで、別の PC が積んだ累計を打ち消すように見せることの 2 つ。次の入力は誤ったまま通ることを許す: 手元の時計が GitHub の時計より 300 秒を超えて遅れていると、手で積んだ行があっても後追いの行が積まれ、同じ出来事の行が 2 行並ぶ（数字はどちらも正しい）／手で `gh pr merge` / `gh issue close` を実行した直後の 1〜2 秒（その hook が行を積み終える前）に別のセッションが始まると、後追いと PostToolUse の hook の両方が行を積み、同じ出来事の行が 2 行並ぶ（数字はどちらも正しい）／クローズ・再オープン・クローズが 300 秒以内に続いた issue では、2 回目のクローズの行が積まれない／`issue クローズ` の行はあるが合計の行が無い本文（閉じた PR の問い合わせが失敗した回）に、合計の行だけを後から足すことはしない／最終行が読めない本文では、同じ呼び名の行が 1 行でもあれば、どれだけ前のものでも積まない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 同じきっかけの行が近い時刻にある
- **WHEN** 表の行が 1 行（きっかけ `マージ`、記録の時刻 T+5 秒）の本文を標準入力にして、`timeline --pr 300 --branch feat/a --trigger マージ --at T --backfill` を実行する
- **THEN** 終了コードは 0 で、出力は標準入力の本文と同じ

#### Scenario: 複数のきっかけをつないだ行も見る
- **WHEN** 表の行が 1 行（きっかけ `PR コメント+マージ`、記録の時刻 T+5 秒）の本文を標準入力にして、同じコマンドを実行する
- **THEN** 出力は標準入力の本文と同じ

#### Scenario: 同じきっかけの行が無い
- **WHEN** 表の行が 1 行（きっかけ `PR コメント`、記録の時刻 T−600 秒、累計 $1.00）の本文を標準入力にして、ブランチ `feat/a` の T 以前の累計が $3.00 の会話ログで、同じコマンドを実行する
- **THEN** 表の行は 2 行で、2 行目のきっかけは `マージ`、金額は `$3.00 (+2.00)`

#### Scenario: 前のクローズの行は古い
- **WHEN** 表の行が 1 行（きっかけ `issue クローズ`、記録の時刻 T−3600 秒）の本文を標準入力にして、`timeline --issue 12 --trigger "issue クローズ" --at T --backfill` を実行する（issue #12 に帰属する区間のコストがある）
- **THEN** 表の行は 2 行で、2 行目のきっかけは `issue クローズ`

#### Scenario: 後ろに行があっても時刻の位置に入る
- **WHEN** 表の行が 2 行（`PR コメント` が T−600 秒・累計 $1.00、`PR コメント` が T+600 秒・累計 $3.00）の本文を標準入力にして、ブランチ `feat/a` の T 以前の累計が $2.00 の会話ログで、`timeline --pr 300 --branch feat/a --trigger マージ --at T --backfill` を実行する
- **THEN** 表の行は `PR コメント`・`マージ`・`PR コメント` の順で、`マージ` の行の金額は `$2.00 (+1.00)`、最後の行の金額は `$3.00 (+1.00)`

#### Scenario: 手元にコストが無ければ、既存の本文があっても積まない
- **WHEN** 表の行が 1 行（きっかけ `PR コメント`、累計 $39.62）の本文を標準入力にして、ブランチ `feat/none` の行が 1 つも無い状態で `timeline --pr 300 --branch feat/none --trigger マージ --at T --backfill` を実行する
- **THEN** 出力は空で、終了コードは 3

#### Scenario: `--backfill` が無ければ今までと同じ
- **WHEN** 前の Scenario と同じ入力で、`--backfill` を付けずに実行する
- **THEN** 終了コードは 0 で、`マージ` の行が 1 行足された本文が出力される

#### Scenario: 区間が 0 でも閉じた PR の分があれば積む
- **WHEN** issue #13 に帰属する区間が無く、ブランチ `feat/a` に行がある会話ログで、表の行が 1 行（きっかけ `issue コメント`）の本文を標準入力にして `timeline --issue 13 --trigger "issue クローズ" --closing-pr 300:feat/a --at T --backfill` を実行する
- **THEN** 終了コードは 0 で、`issue クローズ` の行と合計の行が足された本文が出力される

#### Scenario: 最終行が読めない本文は呼び名だけで見る
- **WHEN** 目印の行の記録が壊れていて、表にきっかけ `マージ` の行が 1 行ある本文を標準入力にして、`timeline --pr 300 --branch feat/a --trigger マージ --at T --backfill` を実行する
- **THEN** 出力は標準入力の本文と同じ

