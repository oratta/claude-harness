## MODIFIED Requirements

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

問い合わせが「失敗した」ときだけ、システムは節目の行のきっかけの欄に、`+` 区切りの最後の要素として `PR 照会失敗` を SHALL 足す（例: `issue クローズ+PR 照会失敗`、`issue コメント+issue クローズ+PR 照会失敗`）。ここでの失敗は、合計を作れなかった理由が問い合わせ側にあるすべての場合で、`gh` の呼び出しの失敗（ネットワーク・認証・時間切れ）・JSON でない応答・応答の形の崩れ（1 件でも崩れていれば）・`pageInfo.hasNextPage` が真、を指す。成功して 0 件だった場合と、成功して数える PR が 0 件だった場合（別のリポジトリの PR や fork の PR だけが返った場合）には足さない。印を足す以外は何も変えない: 問い合わせが成功する場合の行（きっかけの欄・金額・入出力・キャッシュ・合計の行・1 行目）と、`gh` の呼び出し回数（PR でない issue の `gh issue close` だけ 4 回）は、この印を足す前と 1 文字も 1 回も違ってはなら MUST NOT ない。印は `cost_ledger.py timeline` の `--trigger` の値として渡すだけで、`cost_ledger.py` は印を知らない。

守備範囲: この判定が受け取る入力は、`gh api graphql` が返す GitHub の応答と、そこから裏のプロセスが組み立てる `--closing-pr` の引数に限る（`timeline` を手で実行する人が打つ引数を含む）。拾いたい誤りは、一部の PR しか読めていない結果を合計として積むこと（100 件を超えた・応答の一部が崩れていた）・ヘッドブランチが別のリポジトリにある PR のブランチ名で手元の同じ名前のブランチの行を引き込むこと・問い合わせの失敗で `issue クローズ` の行まで積まなくなることの 3 つに加え、問い合わせが失敗して合計が抜けたことにコメントを読んでも気づけないこと。次の入力は誤ったまま通ることを許す: 失敗した回の合計は後から補わない（後追い `cost-ledger-backfill` は、`PR 照会失敗` の付いた行を含め、`issue クローズ` の行がある issue を候補から外す。手動で合計を確認する手段は `/cost <issue番号>`。合計を再表示するだけで、既存コメントの行は補わない）／印は問い合わせの失敗を示すだけで、失敗の理由は区別しない／クローズ済みで未マージの PR は GitHub の既定の結果に含まれず、数えない／issue を手で閉じた時点でまだ開いている PR が結果に含まれていれば、その PR も数える／fork から出された PR と別のリポジトリの PR は、その作業が手元の台帳にあっても数えない／`Closes` を書かずに作業した PR は GitHub が結び付けないので数えない／閉じた PR が多い issue では、合計の行が PR の数に比例して長くなる（100 件を超えると積まない）／`timeline` を手で実行して実在しない PR 番号やブランチ名を渡した場合は、そのまま内訳に出る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

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
- **THEN** `timeline` は `--closing-pr` を受け取らず、`--trigger` は `issue クローズ+PR 照会失敗` で、コメントが 1 本書き込まれる

#### Scenario: 失敗した回と 0 件の回でコメントが違う
- **WHEN** GraphQL が失敗する環境と、0 件を返す環境のそれぞれで、同じ会話ログに対して `gh issue close 12` の hook JSON を流す（本物の `cost_ledger.py` を使う）
- **THEN** 失敗した回の表の 1 行目のきっかけは `issue クローズ+PR 照会失敗`、0 件の回は `issue クローズ`。2 つのコメントはきっかけの欄以外（金額・入出力・キャッシュ・1 行目）が同じで、どちらにも合計の行は無い

#### Scenario: 成功する場合は印も呼び出し回数も増えない
- **WHEN** PR #704 を 1 件返す環境と、0 件を返す環境と、別のリポジトリの PR だけを返す環境のそれぞれで、`gh issue close 12` の hook JSON を流す
- **THEN** どの回も `--trigger` は `issue クローズ` で `PR 照会失敗` を含まず、`gh` は 4 回

#### Scenario: 失敗の印は応答の崩れと 100 件超にも付く
- **WHEN** GraphQL の応答が JSON でない、PR の番号が文字列の要素を含む、`pageInfo.hasNextPage` が真、のそれぞれで、`gh issue close 12` の hook JSON を流す
- **THEN** どの回も `--trigger` は `issue クローズ+PR 照会失敗`

#### Scenario: コメントと同時のクローズで失敗する
- **WHEN** GraphQL が失敗する環境で、`gh issue comment 12 --body x && gh issue close 12` の hook JSON を流す
- **THEN** `--trigger` は `issue コメント+issue クローズ+PR 照会失敗`

#### Scenario: 失敗した行を後追いは補わない
- **WHEN** きっかけが `issue クローズ+PR 照会失敗`（記録の時刻 T+5 秒）の行がある本文を標準入力にして、`timeline --issue 12 --trigger "issue クローズ" --at T --backfill` を実行する
- **THEN** 終了コードは 0 で、出力は標準入力の本文と同じ

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
