## MODIFIED Requirements

### Requirement: `gh` の呼び出し回数
システムが 1 行積むために呼ぶ `gh` は、対象 1 件あたり 3 回（対象の確認・既存コメントの取得・書き込み）以下で MUST ある。ただし、PR でない issue にきっかけ `issue クローズ` を含む行を積むときは、閉じた PR の問い合わせ 1 回を足した 4 回以下で MUST ある。既存コメントの取得がコメント 100 件ごとに 1 ページ増える分と、issue 向けのコマンドや `gh api` の issue 向けの endpoint（`issues/<番号>/comments`・`issues/<番号>`）に渡された番号が PR だったときの 1 回は、この数に含めない。子 issue を持つ issue（対象の確認の応答の `sub_issues_summary.total` が 1 以上）に行を積むときは、子孫の問い合わせ（GraphQL）としてルートの 1 回を毎回足し、その先は「子 issue を持つ issue に積む行は子 issue の分を含む」の変更信号が変わった子、または保存の無い子のうち、子を持つ issue 1 件につき 1 回だけ足 SHALL す。変わっていない子の完全な保存済み部分木を使うとき、その子より先への問い合わせを省き、省いた分を回数に数えてはなら MUST NOT ない。ただし 1 行につき 5 回までとし、6 回目が必要になったときは失敗として扱う。このとき `issue クローズ` を含む行でも閉じた PR の問い合わせは足さない（子孫の問い合わせの応答に、その issue を閉じた PR が入っている）。子孫の問い合わせの有無は、対象の確認の応答だけで決め、そのために `gh` を足してはなら MUST NOT ない。回数は、その PR / issue に既に積まれている行の数にも、その issue を閉じた PR の数にも、子 issue の数にも比例してはなら MUST NOT ない（初回と保存が使えない回は子を持つ issue の数に比例する。保存が使える回は毎回のルート 1 回と、再取得が必要な子を持つ issue の分だけとする）。きっかけが `gh api`・`gh pr create`・`gh pr reopen` でも、この回数は変わってはなら MUST NOT ない。

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
- **WHEN** 保存が無く、子 issue #11 がさらに子を持つ issue #10 に `gh issue comment 10 --body x` の hook JSON を流す
- **THEN** `gh` が呼ばれた回数は 5 回（子孫の問い合わせが 2 回）

#### Scenario: 子孫の問い合わせが 5 回を超える
- **WHEN** 保存が無く、子を持つ子 issue が 5 件ある issue #10（子孫の問い合わせが 6 回要る）に `gh issue comment 10 --body x` の hook JSON を流す
- **THEN** 子孫の問い合わせは 5 回で止まり、`gh` が呼ばれた回数は 8 回（対象の確認・コメント取得・書き込み・子孫の問い合わせ 5 回）で、積まれた行のきっかけの欄の最後は `子 issue 照会失敗`

#### Scenario: 2 回目は変わっていない子の分だけ問い合わせが少ない
- **WHEN** #10 の子 #11・#12 がそれぞれ孫を持ち、初回の保存が無い状態から、同じ対象に `gh issue comment 10 --body x` の hook JSON を 2 回続けて流す（子の変更信号と木は同じ。コメントは 100 件未満）
- **THEN** 偽 `gh` の記録の GraphQL の問い合わせ先は、1 回目が #10・#11・#12 の 3 回、別プロセスで動く 2 回目が #10 だけの 1 回で、2 回目の `gh` は計 4 回。孫の番号と PR は両方の回で `timeline` に渡り、成功時に失敗の印は付かない

#### Scenario: 変わった子だけを再取得する
- **WHEN** 上の初回のあと、#11 の変更信号だけが変わり #11 の孫に #13 が増え、#12 の変更信号は同じ状態で、2 回目のコメントの hook JSON を流す
- **THEN** 偽 `gh` の記録の 2 回目の GraphQL の問い合わせ先は #10・#11 の 2 回だけで、#12 には問い合わせず、`timeline` の子孫には新しい #13 と保存した #12 の孫の両方が入る

### Requirement: 子 issue を持つ issue に積む行は子 issue の分を含む
システムは、`gh issue comment` などで行を積む対象の issue が子 issue を持つとき（対象の確認の応答の `sub_issues_summary.total` が 1 以上）、裏のプロセスで子孫の issue と、その issue と子孫を閉じた PR を GitHub に問い合わせ MUST る。問い合わせは GraphQL（子と子ごとの閉じた PR を 1 回で取る）で、毎回ルートを 1 回取得し、子孫への追加の問い合わせは変更信号と保存済み部分木に従って省 SHALL く。問い合わせ先のホストは他の呼び出しと同じく github.com に固定 SHALL する。`sub_issues_summary.total` が 0・無い・整数でないときと、対象が PR のときは、問い合わせてはなら MUST NOT ない。

子ごとの変更信号は、親の応答に含まれる `updatedAt`、`subIssuesSummary.total` と `completed`、`closedByPullRequestsReferences` の一覧と MUST する。一覧は PR の番号・ヘッドブランチ・ベースのリポジトリ・fork の別を含め、順番だけの違いは変更とみなさない。子を持つ子の信号が前回と同じで完全な保存済み部分木があれば、その子より先は問い合わせず保存を使 MUST う。変わった子と未保存の子だけを再取得し、そこで読んだ孫にも同じ判定を適用する。現在の一覧に無い子の保存は含めず、葉は親の応答だけで処理する。ルートと直接の子を閉じた PR は現在の応答を使う。保存は額を含めず、額は毎回手元の台帳または会話ログから計算する。

部分木・比較した信号・確認時刻は、対象のリポジトリとルート番号ごとのファイルとして、対象ロックを持ったまま SHALL 読み書きする。置き場は `${TMPDIR:-/tmp}/cost-ledger-timeline` のロック用の安全なディレクトリとし、ファイルの操作は検査済みのディレクトリ fd を基準とし、シンボリックリンクを辿ってはなら MUST NOT ない。保存が無い・読めない・壊れている・形や対象が違う場合は保存の無いものとして全件取得に戻 MUST り、保存の問題だけで `子 issue 照会失敗` を付けてはなら MUST NOT ない。保存は取得全体に成功したときだけ更新し、途中結果を書いてはなら MUST NOT ない。保存の書き込みができなくても、取得に成功した結果で行を積む。ロックを取れない場合の扱いは「同じコメントへの同時の書き込みで行を失わない」のままとする。

子孫に数えるのは、対象の issue と同じリポジトリの子だけ（別のリポジトリの子は数えず、その子の子も辿らない）。PR に数えるのは、ベースのリポジトリが対象のリポジトリ（大文字と小文字は区別しない）で、ヘッドブランチが同じリポジトリにある（`isCrossRepository` が偽）ものだけ。一度出た番号は辿り直さない。辿る深さは `cost_ledger.py cost` と同じ 8 段まで。保存を再利用するときも、ルートからの深さ・リポジトリの絞り込み・全体の重複排除を同じように適用しなければなら MUST ない。

裏のプロセスは `cost_ledger.py timeline --issue <番号>` に、子孫の issue を `--child-issue <番号>` で 1 件ずつ、数える PR を `--child-pr <PR番号>:<ヘッドブランチ>` で 1 件ずつ渡 MUST す。`issue クローズ` を含む行では、閉じた PR の問い合わせの代わりに子孫の問い合わせの応答を使い、数える PR を `--closing-pr` にも渡す。`--child-issue` と `--child-pr` は `--issue` と一緒にだけ渡せる（`--pr` と一緒のとき、または値の形が崩れているとき〔`--child-issue` は 1 以上の整数、`--child-pr` は `--closing-pr` と同じ形〕は、`timeline` は何も出力せず終了コード 2 を返 MUST す）。

`--child-issue` が 1 つ以上あるとき、`timeline` は次のとおり行を作 MUST る。

- 節目の行の累計（金額・入出力・キャッシュ）は、対象の issue と `--child-issue` の issue すべての区間の行と、`--child-pr` のヘッドブランチすべての行を、きっかけの時刻以前で、行ごとに 1 回だけ数えた合計。`cost_ledger.py cost <対象の issue>`（子 issue 込み）の 1 行目と、どの応答よりも後の時刻では同じ値になる（後述の「穴を許す」範囲の取りこぼしがある場合を除く）
- 1 行目（先頭の見出し）の帰属の種別は `子 issue 込み`
- `--closing-pr` もあるとき（`issue クローズ`）、節目の行に続けて合計の行を 1 行積み、その累計は節目の行と同じ値。きっかけの欄は `合計（子 issue <n> 件込み: PR <m> 件 $<額> + PR 外 $<額>）`。`<n>` は `--child-issue` の件数、`<m>` は重複を除いた PR の件数、PR の額は PR のブランチの行の合計、PR 外の額は区間の行のうちどのヘッドブランチにも一致しない行の合計。額は `$` と小数 2 桁、3 桁区切り。PR ごとの額は並べない

`--child-issue` が無いときは、今までと同じ（区間だけの累計。合計の行は `--closing-pr` があるときの従来の書式）。

子孫の問い合わせが失敗したとき（`gh` の呼び出しの失敗・JSON でない応答・応答の形の崩れ・`pageInfo.hasNextPage` が真・深さ 8 段超・問い合わせの 6 回目が必要になった場合）、hook は `--child-issue`・`--child-pr`・`--closing-pr` を渡さず、従来どおりの行（区間だけの累計）を積み、節目の行のきっかけの欄の `+` 区切りの最後の要素として `子 issue 照会失敗` を足 SHALL す。このとき `issue クローズ` でも合計の行は積まない。成功した場合には印を足さない。保存がある回も、必要な問い合わせが失敗したら `epic_tree()` は `None` を返し、古い全体や部分結果を成功として使ってはなら MUST NOT ない。5 回上限に数えるのは実際に呼んだ GraphQL だけで、省いた問い合わせは数えない。

守備範囲: この判定が受け取る入力は、`gh api graphql` が返す GitHub の応答と、対象別の保存した信号・確認時刻・部分木、そこから裏のプロセスが組み立てる `--child-issue`・`--child-pr`・`--closing-pr` の引数に限る。拾いたい誤りは、一部の子孫や PR しか読めていない結果を子込みの額として積むこと（信号に出ない変更による取りこぼしは後述の許容範囲）・同じ行を 2 回数えること（複数の子が同じ PR に結び付くとき、区間の行が子の PR のブランチ上にあるとき）・子孫を持たない issue と PR の行や `gh` の回数が変わること・問い合わせの失敗で行そのものを積まなくなること・失敗したことにコメントを読んでも気づけないこと・変わっていない子にも再び問い合わせること・壊れた保存を使うこと、または保存の問題だけで失敗表示にすることの 7 つ。次の入力は誤ったまま通ることを許す（穴を許す）: 失敗した回の子込みの額は後から補わない／別のリポジトリの子 issue の分は数えない／GitHub の子 issue として登録されていない issue と、`Closes` で結び付いていない PR は数えない／子より深い issue の追加・削除・閉じた PR の変更が子の変更信号に現れないと、保存した部分木が再利用され、額が古くなりうる（保存を使わず全件取得する `/cost <番号>` では正しい額を確認できる。既存の行は補正しない）／既に積まれた区間だけの行は書き換えないので、子を持つ issue の既存のコメントでは次の行の増分が一度だけ大きく出る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

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

#### Scenario: 変わった子の孫以下の合計が更新される
- **WHEN** #10 → #11 → #13 の木を保存したあと、#11 の変更信号が変わり、新しい孫 #14（閉じた PR #314、ブランチ `feat/new`）が加わり、#14 の区間または PR の台帳の行に $2.00 がある状態でコメントの hook JSON を流す（どの応答もきっかけの時刻より前）
- **THEN** #11 を再取得し、`timeline` に #14 と PR #314 が渡り、節目の行の累計には新しい $2.00 が 1 回だけ含まれる。変更のない別の子の部分木は再取得しない

#### Scenario: 未変更と変更の両方で合計行の額が `/cost` の 1 行目と一致する
- **WHEN** 閉じた PR のある #10 の木を保存したあと、木が同じ場合と、子の信号が変わって孫と PR が増えた場合のそれぞれで、同じ合成ログを使って `gh issue close 10` の hook JSON と `/cost 10` 相当の `cost_ledger.py cost 10` を実行する（全応答より後の時刻で行を積み、信号に出ない変更は無い）
- **THEN** どちらの合計行の額も、保存を使わず全件取得した `cost 10` の 1 行目の額と一致する。未変更の部分木の保存に含まれる issue / PR に手元の行が増えていても、その分を含めて再集計する

#### Scenario: 保存が使えなければ失敗表示なしで全件取得に戻る
- **WHEN** 保存が無い・読めない・JSON が壊れている・必要な部分木や信号が欠けている・形式の版や対象が違う、のそれぞれで、#10 → #11 → #13 のコメントの hook JSON を流す（GitHub は正常な応答を返す）
- **THEN** 問い合わせ先は #10・#11 で、全件取得した子孫と PR を `timeline` に渡し、`子 issue 照会失敗` は付かない

#### Scenario: 保存があっても必要な問い合わせの失敗を隠さない
- **WHEN** 正常な保存がある状態で、ルートの問い合わせ、または変更信号が変わった子の必要な問い合わせが、取得不能・JSON でない・形の崩れ・`hasNextPage` が真のいずれかになる
- **THEN** `epic_tree()` は `None` を返し、子の引数と `--closing-pr` を渡さず区間だけの行を積み、きっかけの最後は `子 issue 照会失敗`。クローズでも合計行を積まず、前回の保存を途中結果で上書きしない

#### Scenario: 保存を使う回も実際の問い合わせは 5 回で止まる
- **WHEN** 保存済みの木から一部の子を再利用しても、未保存または変更された子の問い合わせにルートを含めて 6 回必要な状態で hook JSON を流す
- **THEN** GraphQL は 5 回で止まり、6 回目は呼ばず `epic_tree()` は `None`、きっかけの最後は `子 issue 照会失敗`。省いた問い合わせは 5 回に含めない

#### Scenario: 子の信号に出ない深い変更は取りこぼしを許す
- **WHEN** #10 → #11 → #13 の保存後、#13 以下の関係が変わるが #10 の応答の #11 の変更信号がすべて同じまま、hook JSON と `/cost 10` を実行する
- **THEN** hook は #11 の保存済み部分木を再利用し、額が古くなることを許す。`/cost 10` は保存を使わない全件取得で現在の正しい額を表示する

#### Scenario: 保存ファイルのリンクを辿らない
- **WHEN** 安全なロック用ディレクトリの中で対象の保存ファイルだけが外部ファイルへのシンボリックリンクになった状態で hook JSON を流す（GitHub の全件取得は成功する）
- **THEN** リンク先を読み書きせず全件取得の結果を使い、保存の問題による失敗表示は付かない

#### Scenario: 保存への書き込みだけが失敗する
- **WHEN** GitHub の取得全体は成功し、保存ファイルへの書き込みだけが失敗する状態で hook JSON を流す
- **THEN** 正常に取得した子孫と PR で行を積み、保存の問題による失敗表示は付かず、途中まで書いた保存を次回の正常な部分木として使わない
