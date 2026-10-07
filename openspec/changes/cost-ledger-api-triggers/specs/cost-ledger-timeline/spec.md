## MODIFIED Requirements

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

守備範囲: この判定が受け取る入力は、PostToolUse が渡す `tool_input.command`（Claude Code のセッションが Bash ツールで実行したコマンド文字列）に限る。拾いたい誤りは、表に無いコマンドで行を積むこと・コマンドを文字列として含むだけの Bash で行を積むこと・1 つのコマンドで同じ対象に行を 2 行以上積むことの 3 つ。次の入力は誤ったまま通ることを許す: `eval`・`bash -c '...'`・シェル関数・エイリアス・スクリプトファイルの中から実行された `gh pr comment` などは見えず、行が積まれない／`gh` を変数で呼んだもの（`$GH pr comment`）と、`gh` と `pr` のあいだにオプションを置いたもの（`gh -R x pr comment`）は行が積まれない／`false && gh pr comment 300 --body x` のように実行されなかったコメントのコマンドでも行が積まれる（数字は正しく、きっかけの名前だけが実際と合わない）／`gh api graphql` の mutation での投稿や状態変更、`--input` で渡した JSON の中の `state` の変更は見えず、行が積まれない／hook の新規作成と同じ形のコマンド（`issues/<番号>/comments` への POST）を Bash で実行したものは、コメントの投稿として行が積まれる／Bash ツール以外（別の端末、GitHub の画面、auto-merge）で行われた投稿や状態変更は行が積まれない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

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

守備範囲: この確認が受け取る入力は、対象の確認で GitHub が返す応答（`state`・`draft`・`merged`・`merged_at`・`labels`・`created_at`）と、hook が起動した手元の時刻に限る。拾いたい誤りは、失敗したコマンドの節目を積むことの 1 つ。次の入力は誤ったまま通ることを許す: 手元の時計が GitHub の時計より 300 秒を超えてずれていると、`PR 作成` の行が積まれない／既に open の PR への `gh pr reopen`、既に Ready の PR への `gh pr ready` のように、状態が前からそうだった対象でも行が積まれる（数字は正しい）／`created_at` が無い・読めない応答では `PR 作成` を積まない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

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

### Requirement: `gh` の呼び出し回数
システムが 1 行積むために呼ぶ `gh` は、対象 1 件あたり 3 回（対象の確認・既存コメントの取得・書き込み）以下で MUST ある。ただし、PR でない issue にきっかけ `issue クローズ` を含む行を積むときは、閉じた PR の問い合わせ 1 回を足した 4 回以下で MUST ある。既存コメントの取得がコメント 100 件ごとに 1 ページ増える分と、issue 向けのコマンドや `gh api` の issue 向けの endpoint（`issues/<番号>/comments`・`issues/<番号>`）に渡された番号が PR だったときの 1 回は、この数に含めない。回数は、その PR / issue に既に積まれている行の数にも、その issue を閉じた PR の数にも比例してはなら MUST NOT ない。きっかけが `gh api`・`gh pr create`・`gh pr reopen` でも、この回数は変わってはなら MUST NOT ない。

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

## ADDED Requirements

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
