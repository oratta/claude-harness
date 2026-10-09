## MODIFIED Requirements

### Requirement: 数字と書式は `timeline` サブコマンドから取る
システムは `cost_ledger.py timeline` を持ち、標準入力で既存のコメント本文（無ければ空）を受け取って、節目の行を 1 行（`--issue` に `--closing-pr` が 1 つ以上渡されたときは、続けて合計の行を 1 行）足した新しい本文を標準出力に返 MUST す。hook は集計・単価・書式を自分で持ってはなら MUST NOT ない。`timeline` は `gh` を呼んではなら MUST NOT ない（PR か issue かは hook が判別して `--pr <番号> --branch <ヘッドブランチ>` か `--issue <番号>` で渡し、issue を閉じた PR も hook が問い合わせて `--closing-pr <PR番号>:<ヘッドブランチ>` で渡す。子 issue を持つ issue では、子孫の issue を `--child-issue <番号>`、エピックと子孫を閉じた PR を `--child-pr <PR番号>:<ヘッドブランチ>` で渡す）。

節目の行の累計は、きっかけの時刻より後の応答が無いとき、PR では `cost_ledger.py cost <PR番号>` と、issue では `cost_ledger.py cost <issue番号>` と同じ値で MUST ある（`--closing-pr` を渡しても節目の行の累計は変わらない）。ただし子 issue を持つ issue では、`cost_ledger.py cost <issue番号>` の 1 行目は子 issue を含めた合計になる（spec `cost-ledger-cost-command` の「子 issue を持つ issue では、子 issue ごとの内訳と合計を返す」）。`--child-issue` を渡さない呼び出しでは、節目の行の累計が一致する相手は `cost_ledger.py issue <issue番号>` の値（区間の合計）と MUST する。`--child-issue` を渡す呼び出し（hook が子を持つ issue に積むとき）の扱いは「子 issue を持つ issue に積む行は子 issue の分を含む」に従う。`timeline` 自身は子 issue を調べない（子孫と PR は引数で受け取る）。`COST_LEDGER_PATH` があるときは、他の集計系サブコマンドと同じく、読む前に会話ログの差分を台帳へ追記してから台帳を読 SHALL む。差分の追記は、`--closing-pr` が何件あっても 1 回の呼び出しで 1 回だけと SHALL する。

次のときは何も出力せず終了コード 3 を返し、hook は何も書いてはなら MUST NOT ない。

- 節目の行の累計の金額・入出力トークン・キャッシュトークンがすべて 0 で、既存のコメント本文が空で、合計の行を積む場合はその累計もすべて 0（金額が 0 でもトークンがあれば積む）
- issue でも PR でも、対象のリポジトリ（`--target-repo`）が `--repo` の場所のリポジトリと一致しない（`--repo` の場所のリポジトリが判別できないときを含む。既存のコメント本文があっても積まない）

`--target-repo` を渡さない呼び出し（手で実行する場合）では、この照合を行わない。hook は常に `--target-repo` を渡 MUST す。

守備範囲: `timeline` が受け取る入力は、hook（`gate_report.py`）か手で実行する利用者が渡す引数（`--pr`・`--branch`・`--issue`・`--closing-pr`・`--child-issue`・`--child-pr`・`--target-repo`・`--at`）と、標準入力の既存のコメント本文、台帳または会話ログの行に限る。拾いたい誤りは、節目の行の累計が `cost_ledger.py cost`（`--child-issue` を渡さない子 issue を持つ issue では `cost_ledger.py issue`）の値とずれること・別のリポジトリの issue や PR に行を積むこと・`timeline` が `gh` を呼んで hook の待ち時間と呼び出し回数を増やすことの 3 つ。次のことは誤ったまま通ることを許す: 手で実行して `--target-repo` を省いたときは、リポジトリの照合を行わずに行を積む／`--issue` に渡された番号が実際には PR だった・`--closing-pr` のヘッドブランチが実際のものと違う、のように引数が事実と合わないときは、渡された値のまま集計する（判別と問い合わせは hook の受け持ち）／`--child-issue` に渡された番号が実際には子孫でない・`--child-pr` のヘッドブランチが実際のものと違う、のように引数が事実と合わないときは、渡された値のまま集計する。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

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

#### Scenario: `--child-issue` を渡さなければ子 issue を持つ issue でも区間だけの累計
- **WHEN** issue #10 に帰属する区間の行が 1 行（$1.00）あり、ブランチ `feat/a` の行が 2 行（各 $1.00）ある会話ログで、標準入力を空にし、どの行よりも後の時刻を `--at` に渡して `timeline --issue 10 --trigger "issue コメント"`（`--child-issue` と `--child-pr` は無し）を実行する
- **THEN** 行の金額は `$1.00 (+1.00)` で、`gh` が呼ばれた回数は 0 回で、1 行目は `cost_ledger.py issue 10` の 1 行目と一致する
### Requirement: `gh` の呼び出し回数
システムが 1 行積むために呼ぶ `gh` は、対象 1 件あたり 3 回（対象の確認・既存コメントの取得・書き込み）以下で MUST ある。ただし、PR でない issue にきっかけ `issue クローズ` を含む行を積むときは、閉じた PR の問い合わせ 1 回を足した 4 回以下で MUST ある。既存コメントの取得がコメント 100 件ごとに 1 ページ増える分と、issue 向けのコマンドや `gh api` の issue 向けの endpoint（`issues/<番号>/comments`・`issues/<番号>`）に渡された番号が PR だったときの 1 回は、この数に含めない。子 issue を持つ issue（対象の確認の応答の `sub_issues_summary.total` が 1 以上）に行を積むときは、子孫の問い合わせ（GraphQL）を、子を持つ issue（その issue 自身を含む）1 件につき 1 回だけ足す。ただし 1 行につき 5 回までとし、6 回目が必要になったときは失敗として扱う。このとき `issue クローズ` を含む行でも閉じた PR の問い合わせは足さない（子孫の問い合わせの応答に、その issue を閉じた PR が入っている）。子孫の問い合わせの有無は、対象の確認の応答だけで決め、そのために `gh` を足してはなら MUST NOT ない。回数は、その PR / issue に既に積まれている行の数にも、その issue を閉じた PR の数にも、子 issue の数にも比例してはなら MUST NOT ない（子を持つ issue の数には比例する）。きっかけが `gh api`・`gh pr create`・`gh pr reopen` でも、この回数は変わってはなら MUST NOT ない。

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

#### Scenario: 子 issue を持たない issue の回数は変わらない
- **WHEN** `sub_issues_summary.total` が 0 の issue #12 に、`gh issue comment 12 --body x` と `gh issue close 12` の hook JSON をそれぞれ流す（コメントは 100 件未満）
- **THEN** `gh` が呼ばれた回数は、コメントが 3 回、クローズが 4 回（変更の前と同じ）で、子孫の問い合わせは 0 回

#### Scenario: 子 issue を 2 件持つ issue（孫なし）
- **WHEN** `sub_issues_summary.total` が 2 の issue #10 に、`gh issue comment 10 --body x` と `gh issue close 10` の hook JSON をそれぞれ流す（コメントは 100 件未満）
- **THEN** `gh` が呼ばれた回数は、コメントが 4 回（子孫の問い合わせ 1 回を含む）、クローズが 4 回（閉じた PR の問い合わせは足さず、子孫の問い合わせ 1 回を含む）

#### Scenario: 子の 1 件が孫を持つ
- **WHEN** 子 issue #11 がさらに子を持つ issue #10 に `gh issue comment 10 --body x` の hook JSON を流す
- **THEN** `gh` が呼ばれた回数は 5 回（子孫の問い合わせが 2 回）

#### Scenario: 子孫の問い合わせが 5 回を超える
- **WHEN** 子を持つ子 issue が 5 件ある issue #10（子孫の問い合わせが 6 回要る）に `gh issue comment 10 --body x` の hook JSON を流す
- **THEN** 子孫の問い合わせは 5 回で止まり、`gh` が呼ばれた回数は 8 回（対象の確認・コメント取得・書き込み・子孫の問い合わせ 5 回）で、積まれた行のきっかけの欄の最後は `子 issue 照会失敗`

## ADDED Requirements

### Requirement: 子 issue を持つ issue に積む行は子 issue の分を含む
システムは、`gh issue comment` などで行を積む対象の issue が子 issue を持つとき（対象の確認の応答の `sub_issues_summary.total` が 1 以上）、裏のプロセスで子孫の issue と、その issue と子孫を閉じた PR を GitHub に問い合わせ MUST る。問い合わせは GraphQL（子を持つ issue 1 件につき 1 回。子と子ごとの閉じた PR を 1 回で取る）で、ホストは他の呼び出しと同じく github.com に固定 SHALL する。`sub_issues_summary.total` が 0・無い・整数でないときと、対象が PR のときは、問い合わせてはなら MUST NOT ない。

子孫に数えるのは、対象の issue と同じリポジトリの子だけ（別のリポジトリの子は数えず、その子の子も辿らない）。PR に数えるのは、ベースのリポジトリが対象のリポジトリ（大文字と小文字は区別しない）で、ヘッドブランチが同じリポジトリにある（`isCrossRepository` が偽）ものだけ。一度出た番号は辿り直さない。辿る深さは `cost_ledger.py cost` と同じ 8 段まで。

裏のプロセスは `cost_ledger.py timeline --issue <番号>` に、子孫の issue を `--child-issue <番号>` で 1 件ずつ、数える PR を `--child-pr <PR番号>:<ヘッドブランチ>` で 1 件ずつ渡 MUST す。`issue クローズ` を含む行では、閉じた PR の問い合わせの代わりに子孫の問い合わせの応答を使い、数える PR を `--closing-pr` にも渡す。`--child-issue` と `--child-pr` は `--issue` と一緒にだけ渡せる（`--pr` と一緒のとき、または値の形が崩れているとき〔`--child-issue` は 1 以上の整数、`--child-pr` は `--closing-pr` と同じ形〕は、`timeline` は何も出力せず終了コード 2 を返 MUST す）。

`--child-issue` が 1 つ以上あるとき、`timeline` は次のとおり行を作 MUST る。

- 節目の行の累計（金額・入出力・キャッシュ）は、対象の issue と `--child-issue` の issue すべての区間の行と、`--child-pr` のヘッドブランチすべての行を、きっかけの時刻以前で、行ごとに 1 回だけ数えた合計。`cost_ledger.py cost <対象の issue>`（子 issue 込み）の 1 行目と、どの応答よりも後の時刻では同じ値になる
- 1 行目（先頭の見出し）の帰属の種別は `子 issue 込み`
- `--closing-pr` もあるとき（`issue クローズ`）、節目の行に続けて合計の行を 1 行積み、その累計は節目の行と同じ値。きっかけの欄は `合計（子 issue <n> 件込み: PR <m> 件 $<額> + PR 外 $<額>）`。`<n>` は `--child-issue` の件数、`<m>` は重複を除いた PR の件数、PR の額は PR のブランチの行の合計、PR 外の額は区間の行のうちどのヘッドブランチにも一致しない行の合計。額は `$` と小数 2 桁、3 桁区切り。PR ごとの額は並べない

`--child-issue` が無いときは、今までと同じ（区間だけの累計。合計の行は `--closing-pr` があるときの従来の書式）。

子孫の問い合わせが失敗したとき（`gh` の呼び出しの失敗・JSON でない応答・応答の形の崩れ・`pageInfo.hasNextPage` が真・深さ 8 段超・問い合わせの 6 回目が必要になった場合）、hook は `--child-issue`・`--child-pr`・`--closing-pr` を渡さず、従来どおりの行（区間だけの累計）を積み、節目の行のきっかけの欄の `+` 区切りの最後の要素として `子 issue 照会失敗` を足 SHALL す。このとき `issue クローズ` でも合計の行は積まない。成功した場合には印を足さない。

守備範囲: この判定が受け取る入力は、`gh api graphql` が返す GitHub の応答と、そこから裏のプロセスが組み立てる `--child-issue`・`--child-pr`・`--closing-pr` の引数に限る。拾いたい誤りは、一部の子孫や PR しか読めていない結果を子込みの額として積むこと・同じ行を 2 回数えること（複数の子が同じ PR に結び付くとき、区間の行が子の PR のブランチ上にあるとき）・子孫を持たない issue と PR の行や `gh` の回数が変わること・問い合わせの失敗で行そのものを積まなくなること・失敗したことにコメントを読んでも気づけないことの 5 つ。次の入力は誤ったまま通ることを許す: 失敗した回の子込みの額は後から補わない／別のリポジトリの子 issue の分は数えない／GitHub の子 issue として登録されていない issue と、`Closes` で結び付いていない PR は数えない／既に積まれた区間だけの行は書き換えないので、子を持つ issue の既存のコメントでは次の行の増分が一度だけ大きく出る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 子 2 件を持つエピックを閉じると、合計の行の額が `/cost` の 1 行目と一致する
- **WHEN** エピック #10 に帰属する区間の行が 1 行（$1.00）、子 #11 の区間の行が 1 行（$1.00）、子 #12 の区間の行が 1 行（$1.00）、#11 を閉じた PR のブランチ `feat/a` の行が 2 行（各 $1.00。うち 1 行は #11 の区間の行と同じ行）、#12 を閉じた PR のブランチ `feat/b` の行が 1 行（$1.00）ある会話ログで、標準入力を空にし、どの行よりも後の時刻を `--at` に渡して `timeline --issue 10 --child-issue 11 --child-issue 12 --child-pr 300:feat/a --child-pr 301:feat/b --closing-pr 300:feat/a --closing-pr 301:feat/b --trigger "issue クローズ"` を実行する
- **THEN** 合計の行の金額は `cost_ledger.py cost 10`（`gh` は #10 の子が #11・#12、閉じた PR が 300・301 だと答える状態）の 1 行目の金額と一致し（$5.00）、節目の行の金額も同じ

#### Scenario: 節目の行も子込みになる
- **WHEN** 上のデータで `--closing-pr` を付けずに `timeline --issue 10 --child-issue 11 --child-issue 12 --child-pr 300:feat/a --child-pr 301:feat/b --trigger "issue コメント"` を実行する
- **THEN** 行の金額は $5.00 で、1 行目の帰属の種別は `子 issue 込み`、合計の行は積まれない

#### Scenario: 合計の行のきっかけの欄は件数だけ
- **WHEN** 上のデータで `issue クローズ` の `timeline` を実行する
- **THEN** 合計の行のきっかけの欄は `合計（子 issue 2 件込み: PR 2 件 $3.00 + PR 外 $2.00）` で、PR ごとの額は含まれない

#### Scenario: 複数の子が同じ PR に結び付くとき一度だけ数える
- **WHEN** #11 と #12 が同じ PR #300（ブランチ `feat/a`）に結び付く状態で、`--child-pr 300:feat/a` と `--child-pr 300:feat/a` を渡して `timeline` を実行する
- **THEN** `feat/a` の行は 1 回だけ数えられる

#### Scenario: `--child-issue` を `--pr` と一緒に渡す
- **WHEN** `timeline --pr 300 --branch feat/a --child-issue 11` を実行する
- **THEN** 何も出力されず、終了コードは 2

#### Scenario: hook が子を持つ issue に子孫を渡す
- **WHEN** `sub_issues_summary.total` が 2 の issue #10 に `gh issue comment 10 --body x` の hook JSON を流す（`gh` は子 #11・#12 とそれぞれを閉じた PR を答える）
- **THEN** `timeline` は `--issue 10`・`--child-issue 11`・`--child-issue 12`・`--child-pr` を受け取り、`--closing-pr` は受け取らず、コメントが 1 本書き込まれる

#### Scenario: 子を持つ issue を閉じる
- **WHEN** 同じ状態で `gh issue close 10` の hook JSON を流す（#10 は閉じた状態）
- **THEN** `timeline` は `--child-issue`・`--child-pr` と、同じ PR の `--closing-pr` を受け取り、`issue クローズ` の行と合計の行が積まれる

#### Scenario: 子を持たない issue は今までと同じ引数
- **WHEN** `sub_issues_summary.total` が 0 の issue #12 に `gh issue comment 12 --body x` の hook JSON を流す
- **THEN** `timeline` は `--child-issue` も `--child-pr` も受け取らず、`gh` の呼び出しは 3 回

#### Scenario: 子孫の問い合わせが失敗した
- **WHEN** 子孫の問い合わせ（GraphQL）が失敗する状態で、`sub_issues_summary.total` が 2 の issue #10 に `gh issue close 10` の hook JSON を流す
- **THEN** `timeline` は `--child-issue`・`--child-pr`・`--closing-pr` を受け取らず、節目の行のきっかけの欄は `issue クローズ+子 issue 照会失敗`、合計の行は積まれず、コメントは 1 本書き込まれる

#### Scenario: 子孫の応答の形が崩れている
- **WHEN** 子孫の問い合わせの応答の子 1 件の `number` が整数でない状態で、子を持つ issue に `gh issue comment` の hook JSON を流す
- **THEN** 一部の子だけを渡さず、`timeline` は `--child-issue` を受け取らず、きっかけの欄の最後は `子 issue 照会失敗`

#### Scenario: 別のリポジトリの子と fork の PR は数えない
- **WHEN** 子孫の応答に、別のリポジトリの子 issue と、`isCrossRepository` が真の PR が含まれる状態で子を持つ issue に行を積む
- **THEN** `--child-issue` にも `--child-pr` にも渡されない
