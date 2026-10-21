## MODIFIED Requirements

### Requirement: 子 issue を持つ issue では、子 issue ごとの内訳と合計を返す
システムは、`cost_ledger.py cost <番号>` に子 issue を持つ issue（以下「エピック」）の番号が渡されたとき、エピック自身と子孫の issue ごとの額と、その合計を返 MUST す。合計と issue ごとの額の定義は spec `cost-ledger-attribution` の「エピックの合計は、エピック自身と子孫の issue が数える行を 1 回ずつ足した額である」に従 SHALL う。子 issue を持たない issue と PR の番号を渡したときの出力と `gh` の呼び出しは、変えてはなら MUST NOT ない。`cost_ledger.py issue`・`cost_ledger.py timeline` は子 issue を調べてはなら MUST NOT ない。

**子 issue の辿り方。** 子 issue と、それぞれを閉じた PR は、`gh api graphql` で SHALL 問い合わせる。1 回の問い合わせで、ある issue の `subIssues(first: 100)` と、その子 1 件ごとの番号・題名・状態・リポジトリ（`repository.nameWithOwner`）・子の数（`subIssuesSummary.total`）・閉じた PR（`closedByPullRequestsReferences(first: 100)` の番号・ヘッドブランチ・`isCrossRepository`・`baseRepository.nameWithOwner`）を取り、エピック自身への問い合わせでは、エピック自身を閉じた PR と、作業ディレクトリのリポジトリの `nameWithOwner` も同じ 1 回で取る。owner・name・番号は変数で渡し、問い合わせの文字列に埋め込んではなら MUST NOT ない。

- 子の数が 1 以上の子 issue には、同じ問い合わせをもう 1 回行って、その子（孫）を辿 SHALL る。子の数が 0 の issue には問い合わせてはなら MUST NOT ない
- open の子も closed の子も数え MUST る
- リポジトリが作業ディレクトリのリポジトリと違う（`nameWithOwner` が大文字と小文字を区別せずに一致しない）子 issue は、数えず、その子も辿らず、出力に別立てで示 MUST す（issue に帰属する行は実行した作業ディレクトリのリポジトリの行に限るため）
- 一度出てきた番号の issue は、2 回目以降は数えず、辿ってもなら MUST NOT ない（循環で止まらなくなることと、同じ issue を 2 回数えることを防ぐ）
- 辿る深さはエピックから 8 段下まで（GitHub が許す入れ子の上限）と SHALL する
- issue を閉じた PR のうち数えるのは、spec `cost-ledger-timeline` の「`issue クローズ` では、閉じた PR を合わせた合計の行を積む」と同じく、ベースのリポジトリが作業ディレクトリのリポジトリと一致し、`isCrossRepository` が偽の PR だけと MUST する

**読み切れないときは合計を出さない。** 次のときは、標準出力に何も書かず、標準エラーにどの issue で何が読めなかったかを書いて、終了コード 2 を返 MUST す（一部の子しか読めていない額を、エピックの合計として見せない）: GraphQL の呼び出しが失敗した／応答が JSON でない、または期待する形でない（番号が整数でない、ヘッドブランチが空など、1 件でも崩れている）／`subIssues` の `pageInfo.hasNextPage` が真／どれかの issue の `closedByPullRequestsReferences` の `pageInfo.hasNextPage` が真／エピックから 8 段下の issue がさらに子を持つ。

**表示（`--json` 無し）。** 1 行目は `headline()` で作り、金額はエピックの合計、帰属先は `issue #<番号> (<リポジトリ>)`、帰属の種別は `子 issue 込み` と MUST する。2 行目以降は次の順と SHALL する。

1. `  対象: issue #<番号>（<リポジトリ>）と子孫の issue <件数> 件`
2. `  子 issue の合計: <額>`。額は、エピック以外の対象の issue すべてに割り当てた額の和（エピックの直下の子の行の額の和と同じ値）
3. `  issue #<番号> 自身: <額>`。額は、エピック自身に割り当てた額
4. 対象の issue 1 件につき 1 行。最初がエピック自身で、あとは GitHub が返した子の順に、子を持つ issue の直後にその子を並べる。行は空白 2 つで始め、エピックから 1 段下がるごとに空白を 2 つ足す。中身は `#<番号> <状態> <額>` で、状態は `open` か `closed`、額はその issue と、その下の対象の issue すべてに割り当てた額の和（`$` と小数 2 桁、3 桁区切り）。子を持つ issue では続けて `（自身 <その issue に割り当てた額>）`、そのあとに ` — <題名>` を書く。題名が 40 文字を超えるときは、先頭 39 文字と `…` にする
5. 割り当てた額が単独の合計と違う issue の行の末尾には、`（単独 <単独の合計>` に続けて、その issue を閉じた PR のうち別の issue に割り当てられたもの 1 件ごとに `、PR #<番号> は #<割り当て先の issue の番号> に計上` を書き、`）` で閉じる
6. 数えなかった子 issue があれば `  数えていない子 issue: <owner/repo>#<番号>（別のリポジトリ）` を 1 行（複数あれば `、` でつなぐ）
7. 対象の issue の番号に帰属した区間の行のうち、リポジトリ識別子が不明で、どのヘッドブランチにも割り当てられなかった行があれば、その件数と金額を「リポジトリ不明」として 1 行（合計には入れない）
8. 対象の issue に割り当てた区間の行（ヘッドブランチの一致で割り当てた行を除く）のうち、`repo_inferred` が `true` の行があれば、その件数と金額を `  推定で数えた行: <件数> 件 <額>（cwd が削除済みで、パスからリポジトリを推定した。合計に入れている）` として 1 行（金額は合計の内数。件数が 0 なら出さない）
9. 額が区間分割による推定であることと、issue ごとの区間の内訳は `/cost <その issue の番号>` で見られることを伝える 1 行
10. 単価表のずれの知らせ（`--no-drift-check` を渡したときは突き合わせを行わない。突き合わせの対象は、合計に数えた行のセッション）

「子 issue の合計」の行の額は、エピックの直下の子の行の額の和と一致 MUST する。1 行目の金額（エピックの合計）は、「子 issue の合計」の行の額に「自身」の行の額を足した値と一致 MUST する（エピック自身の番号を触った区間の額は実際にかかった額なので、合計から落とさない。エピック自身に割り当てた行が無ければ、1 行目の金額は子の行の額の和と同じになる）。エピック自身の行の額（その issue と下の issue すべての和）は 1 行目の金額と同じで MUST ある。表示の額は 1 行ずつ丸めるので、行の額の和が 1 セントずれることは SHALL 許す（`--json` の値で一致を確かめる）。

**題名とリポジトリ名の表示。** 内訳の行に出す題名と、「数えていない子 issue」の行に出すリポジトリ名は、表示の前に、制御文字（Unicode の一般カテゴリが `Cc`・`Cf`・`Zl`・`Zp` の文字。改行・タブ・ESC・双方向制御文字を含む）を空白 1 つに置き換え、連続する空白を 1 つに畳み、前後の空白を落と MUST す。題名を 40 文字に切るのは、そのあとと SHALL する。`--json` の `title` と `skipped` の `repo` は、GitHub から取った値のまま出 MUST す（機械が読む値を変えない）。

**`--json`。** 次の鍵を持つ JSON を出 MUST す。

- `issue`（番号の文字列）・`repo_id`・`repo_label`・`usd_jpy_rate`・`price_drift`: `cost_ledger.py issue --json` と同じ意味
- `total_usd`: エピックの合計
- `children_usd`: 子 issue の合計（エピック以外の対象の issue の `own_usd` の和。エピックの直下の子の `usd` の和と同じ値）
- `self_usd`: エピック自身に割り当てた額（エピック自身の `own_usd` と同じ値）
- `issues`: 対象の issue の配列（表示と同じ順）。1 件は `number`（整数）・`parent`（親の番号。エピック自身は null）・`depth`（エピック自身が 0）・`title`・`state`（`open` か `closed`）・`usd`（その issue と下の issue すべてに割り当てた額の和）・`own_usd`（その issue に割り当てた額）・`standalone_usd`（単独の合計）・`closing_prs`（数えた PR の配列。番号の昇順。1 件は `number`・`branch`・`usd`（そのヘッドブランチの行の合計）・`counted_in`（その行を割り当てた issue の番号））
- `skipped`: 数えなかった子 issue の配列。1 件は `repo`・`number`・`parent`
- `unknown_repo_usd`・`unknown_repo_messages`: 上の表示の「リポジトリ不明」と同じ行の金額と件数
- `inferred_repo_usd`・`inferred_repo_messages`: 上の表示の「推定で数えた行」と同じ行の金額と件数（無ければ 0。`total_usd` の内数）

`issues` の `own_usd` の和は `total_usd` と一致 MUST する。`children_usd` はエピックの直下の子（`parent` がエピックの番号の issue）の `usd` の和と一致 MUST し、`total_usd` は `children_usd` と `self_usd` の和と一致 MUST する。

守備範囲: この機能が受け取る入力は、`gh api graphql` が返す GitHub の応答と、台帳または会話ログの行に限る。拾いたい誤りは、エピックの額がエピックの番号を触った区間だけの額（ほぼ 0）のまま出ること・一部の子しか読めていない額を合計として出すこと・循環や深い入れ子で `gh` を呼び続けることの 3 つ。次のことは誤ったまま通ることを許す: GitHub の子 issue の仕組みに登録されていない issue（本文の表に書いてあるだけの issue）は子として数えない／別のリポジトリの子 issue は、その作業が手元の台帳にあっても数えない／open の子 issue では、結び付いている open の PR のブランチも数える（作業の途中の額になる）／`Closes` で結び付いていない PR は数えない／エピックのコメントに hook が積む行は、子 issue の分を含む（spec `cost-ledger-timeline` の「子 issue を持つ issue に積む行は子 issue の分を含む」）。hook が子を辿れなかった回の行は区間だけの累計で、きっかけの欄に `子 issue 照会失敗` が付く／子 issue を 1 件だけ `/cost <その番号>` で見た額（区間だけ）は、エピックの内訳のその issue の額（閉じた PR の分を含む）と一致しない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

守備範囲（題名とリポジトリ名の表示）: 出どころは、作業ディレクトリのリポジトリの issue の題名と、子 issue のリポジトリ名（どちらも `gh api graphql` の応答）。拾いたい誤りは、題名に入った改行で内訳に偽の行が足されて見えることと、ESC などの制御文字で端末の表示が書き換えられることの 2 つ。次のものは通す: 題名の自然文の内容（指示のように読める文を含む。文としての内容は検査しない）／絵文字や全角文字（ただしゼロ幅接合子 U+200D は `Cf` なので空白になり、接合子でつないだ絵文字は分かれて表示される）／`--json` の `title` と `repo`。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

以下の Scenario の共通のデータは、spec `cost-ledger-attribution` の「エピックの合計は、エピック自身と子孫の issue が数える行を 1 回ずつ足した額である」の Scenario の共通のデータと同じ（#10 の子が #11 と #12。どの行も $1.00）。題名は #10 が `epic`、#11 が `child a`、#12 が `child b`、状態は #10 と #12 が open、#11 が closed。

#### Scenario: 推定で数えた子 issue の行が合計に入り、件数と額が示される
- **WHEN** 子 issue #11 を触った行の `cwd` が削除済みで、推定によって作業ディレクトリのリポジトリに決まり、その行のブランチがどのヘッドブランチとも一致しない状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** その行の額は #11 の `own_usd` と `total_usd` に入り、`unknown_repo_messages` には数えられず、`inferred_repo_messages` と `inferred_repo_usd` がその行の件数と金額になる

#### Scenario: 別のリポジトリに推定された同じ番号の行はエピックに数えない
- **WHEN** 別のリポジトリの置き場の削除済みの `cwd` で子 issue と同じ番号の issue を触った行があり、推定でその別のリポジトリに決まる状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** その行は `total_usd` にも `unknown_repo_usd` にも `inferred_repo_usd` にも入らない

#### Scenario: 子ごとの額と合計が出る
- **WHEN** 共通のデータで、#11 を閉じた PR が #300（`feat/a`）、#12 を閉じた PR が #301（`feat/b`）のとき、`cost_ledger.py cost 10` を実行する
- **THEN** 1 行目は `コスト: $7.00 / ¥1,050 @150 — issue #10 (acme/ra) 帰属: 子 issue 込み` で、出力に `  #10 open $7.00（自身 $1.00） — epic`・`    #11 closed $4.00 — child a`・`    #12 open $2.00 — child b` の 3 行がこの順にある

#### Scenario: 合計が子の額の和と一致する
- **WHEN** 共通のデータから r4（issue #10 の区間の行）を除いた会話ログで、#11 を閉じた PR が #300（`feat/a`）、#12 を閉じた PR が #301（`feat/b`）のとき、`cost_ledger.py cost 10` と `cost_ledger.py cost 10 --json` を実行する
- **THEN** `total_usd` は 6.0 で、#11・#12 の `usd`（4.0・2.0）の和と一致し、`children_usd` は 6.0、`self_usd` は 0.0 で、表示の 1 行目の金額は `$6.00`、出力に `  子 issue の合計: $6.00` と `  issue #10 自身: $0.00` の行がある

#### Scenario: エピック自身の区間があるときは、子 issue の合計に自身の額を足す
- **WHEN** 「子ごとの額と合計が出る」と同じ状態（共通のデータ。issue #10 の区間の行 r4 がある）で `cost_ledger.py cost 10` と `cost_ledger.py cost 10 --json` を実行する
- **THEN** `children_usd` は 6.0 で #11・#12 の `usd`（4.0・2.0）の和と一致し、`self_usd` は 1.0、`total_usd` は 7.0（`children_usd` と `self_usd` の和。`issues` の `own_usd` の和とも一致）で、出力に `  子 issue の合計: $6.00` と `  issue #10 自身: $1.00` の 2 行がこの順にあり、1 行目の金額は `$7.00`

#### Scenario: 2 件の子が同じ PR を参照する
- **WHEN** 共通のデータで、#11 と #12 のどちらも PR #300（`feat/a`）が閉じたとき、`cost_ledger.py cost 10` と `cost_ledger.py cost 10 --json` を実行する
- **THEN** `total_usd` は 6.0 で、表示の #12 の行は `    #12 open $1.00 — child b（単独 $3.00、PR #300 は #11 に計上）` であり、JSON の #12 の `closing_prs` は `[{"number": 300, "branch": "feat/a", "usd": 2.0, "counted_in": 11}]`

#### Scenario: 孫を辿る
- **WHEN** 共通のデータに、#12 の子 issue #13（題名 `grandchild`、open、閉じた PR なし）と、`main` で issue #13 の区間に帰属する行 r9（$1.00）を足し、#11 と #12 を閉じた PR が無いとき、`cost_ledger.py cost 10` を実行する
- **THEN** 出力に `    #12 open $2.00（自身 $1.00） — child b` と `      #13 open $1.00 — grandchild` がこの順にあり、1 行目の金額は `$5.00`

#### Scenario: 循環していても止まる
- **WHEN** #10 の子が #11、#11 の子が #10 だと `gh` が答える状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** 終了コードは 0 で、`issues` は #10 と #11 の 2 件で、GraphQL の呼び出しは 2 回

#### Scenario: 別のリポジトリの子は数えない
- **WHEN** #10 の子が #11（acme/ra）と #5（acme/other。子を 3 件持つ）だと `gh` が答える状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** `issues` は #10 と #11 の 2 件、`skipped` は `[{"repo": "acme/other", "number": 5, "parent": 10}]` で、GraphQL の呼び出しは 1 回

#### Scenario: 子の問い合わせが失敗する
- **WHEN** issue の問い合わせは #10 の子の数を 2 と答え、GraphQL の呼び出しだけが失敗する状態で `cost_ledger.py cost 10` を実行する
- **THEN** 終了コードは 2 で、標準出力は空

#### Scenario: 子が 100 件を超える
- **WHEN** `subIssues` の `pageInfo.hasNextPage` が真の応答を返す状態で `cost_ledger.py cost 10` を実行する
- **THEN** 終了コードは 2 で、標準出力は空

#### Scenario: 応答の形が崩れている
- **WHEN** 子 #11 を閉じた PR の `headRefName` が空文字の応答を返す状態で `cost_ledger.py cost 10` を実行する
- **THEN** 終了コードは 2 で、標準出力は空

#### Scenario: 8 段より深い
- **WHEN** #10 から子を 1 件ずつ 8 段辿った先の issue が、さらに子を 1 件持つと `gh` が答える状態で `cost_ledger.py cost 10` を実行する
- **THEN** 終了コードは 2 で、標準出力は空で、GraphQL の呼び出しは 8 回

#### Scenario: 題名が長い
- **WHEN** 子 #11 の題名が 50 文字のとき `cost_ledger.py cost 10` を実行する
- **THEN** #11 の行の題名は先頭 39 文字と `…` の 40 文字

#### Scenario: 題名の制御文字は空白にして表示する
- **WHEN** 子 #11 の題名が `x`・ESC（U+001B）・`[2Ky`・改行・空白 4 つ・`#99 closed $9.00 — fake`・U+202E・`z` をこの順につないだ文字列のとき、`cost_ledger.py cost 10` と `cost_ledger.py cost 10 --json` を実行する
- **THEN** 標準出力に ESC と U+202E は無く、#11 の行は `    #11 closed $2.00 — x [2Ky #99 closed $9.00 — fake z` の 1 行で、内訳の行（`#<番号> <状態>` で始まる行）は #10 と #11 の 2 行だけであり、JSON の #11 の `title` は GitHub から取った値と一致する

#### Scenario: fork の PR は数えない
- **WHEN** 共通のデータで、#11 を閉じた PR として #300（`feat/a`、`isCrossRepository` が真）だけを返す状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** #11 の `closing_prs` は空の配列で、`own_usd` は 2.0
