## MODIFIED Requirements

### Requirement: `/cost <番号>` の入力解釈
システムは `/cost <番号>` を受け取り、その番号が PR か issue かを GitHub に問い合わせて判別 SHALL する。PR ならその PR のヘッドブランチのコストを、子 issue を持たない issue ならその issue を触った区間のコスト合計と、その issue を閉じた PR の分を合わせた合計（閉じた PR があるとき）を、子 issue を持つ issue なら「子 issue を持つ issue では、子 issue ごとの内訳と合計を返す」が定める合計と内訳を返 MUST す。子 issue を持つかどうかは、番号の判別に使う issue の問い合わせ（REST の `repos/{owner}/{repo}/issues/<番号>`）の応答の `sub_issues_summary.total` が 1 以上かどうかで決め SHALL、判別のための `gh` の呼び出しを増やしてはなら MUST NOT ない。この値が応答に無いか整数として読めないときは、子 issue を持たない issue として扱 MUST う。

**子 issue を持たない issue の閉じた PR。** システムは、子 issue を持たない issue と判別したときに限り、その issue を閉じた PR を `gh api graphql` の 1 回の問い合わせ（`closedByPullRequestsReferences(first: 100)` の番号・ヘッドブランチ・`isCrossRepository`・`baseRepository.nameWithOwner`。`nameWithOwner` はその応答のリポジトリ名）で SHALL 取る。owner・name・番号は変数で渡し、問い合わせの文字列に埋め込んではなら MUST NOT ない。数える PR は、ベースが作業ディレクトリのリポジトリで `isCrossRepository` が偽のものだけで、同じヘッドブランチが複数あれば番号の小さい方だけを数える（`cost_ledger.py issue` の `--closing-pr` と同じ入力にして `cmd_issue` に渡す）。この問い合わせを、PR 番号・子 issue を持つ issue・番号なしの `/cost` で行ってはなら MUST NOT ない。

**1 行目は変えない。** 閉じた PR があっても、1 行目（`headline()`）の金額・帰属先・種別（`区間`）は、閉じた PR を数えない場合と同じ SHALL。合計と内訳（PR ごとの額と PR の外の額）は、spec `cost-ledger-attribution` の「issue の合計は、閉じた PR の分と、PR のブランチ上に無い区間の分の和である」が定める 2 行目以降の 1 行で出る。

**閉じた PR が 0 件のときの互換。** 通常出力（`--json` 無し）は、この要件を足す前と 1 文字も違わない MUST（読めなかった旨の行も出さない）。`--json` は既存の鍵の値を変えず、`closing_prs` は空の配列、`closing_prs_error` は `false` を足す（鍵が増えるのは `--json` だけ）。

**読み切れないとき。** 閉じた PR の問い合わせが失敗した・応答が JSON でない・期待する形でない（1 件でも形が崩れている）・`pageInfo.hasNextPage` が真のときは、終了コード 0 のまま閉じた PR を数えない出力を返す。表し方は出力の種類で分ける。通常出力は、標準出力に `  閉じた PR を読めなかったため、PR の分は合計に入っていません。` の行を 1 行 SHALL 足す（合計の行は出さない）。`--json` は標準出力を JSON だけに保ち MUST（警告行を混ぜない）、`closing_prs` を空の配列、`closing_prs_error` を `true` にする。区間の分が読めているのに、PR の分が読めないことで区間の額まで返さなくなってはなら MUST NOT ない。

**利用者への見せ方。** `commands/cost.md` は、`/cost <issue番号>` の結果に合計の行（`合計（閉じた PR 込み）:`）または読めなかった旨の行があるとき、1 行目に続けてその行も利用者に見せるよう指示 SHALL する（1 行目だけを見せる既存の指示のままでは、合計が利用者に届かない）。PR に貼るのは引き続き 1 行目だけ。

守備範囲: この判別が受け取る入力は、利用者が `/cost` に渡した番号と、その番号について `gh` が返す GitHub の応答（PR の問い合わせ・issue の問い合わせ・閉じた PR の問い合わせ）に限る。拾いたい誤りは、PR を issue として・issue を PR として集計すること、存在しない番号を 0 と表示すること、子 issue を持つ issue を区間だけの額（ほぼ 0）で返すこと、閉じた PR があるのに PR の分を黙って落として合計に見せることの 4 つ。次のことは誤ったまま通ることを許す: issue の問い合わせの応答に `sub_issues_summary` が無い・`total` が整数でない（古い応答の形、テスト用の偽の `gh` など）ときは、実際に子 issue があっても子を持たない issue として扱う／GitHub の子 issue の仕組みに登録されていない issue（本文の表に書いてあるだけ）は子として見ない／判別のあとで子 issue が足された・外されたことは、その実行には反映されない／閉じた PR を GraphQL が返さない issue（PR 本文の `Closes` を使わず手でリンクしたものなど）の PR の分は数えられない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: PR 番号を渡す
- **WHEN** 利用者が既存の PR の番号を `/cost` に渡す
- **THEN** その PR のヘッドブランチに帰属するコストが返り、閉じた PR の問い合わせ（GraphQL）は 0 回

#### Scenario: issue 番号を渡す
- **WHEN** 利用者が、子 issue を持たない既存の issue の番号を `/cost` に渡す
- **THEN** その issue を触った区間のコスト合計が 1 行目に返る

#### Scenario: 子 issue を持つ issue の番号を渡す
- **WHEN** issue の問い合わせの応答の `sub_issues_summary.total` が 2 である issue #10 の番号を `/cost` に渡す
- **THEN** 1 行目の帰属の種別は `子 issue 込み` で、2 行目以降に子 issue ごとの行があり、閉じた PR だけを問い合わせる GraphQL は呼ばれない（エピックの経路の問い合わせだけ）

#### Scenario: 子 issue の数が応答に無い
- **WHEN** issue の問い合わせが番号だけを返す（`sub_issues_summary` が無い）issue #12 の番号を `/cost` に渡し、閉じた PR の問い合わせは 0 件を返す
- **THEN** 出力は `cost_ledger.py issue 12` と同じで、GraphQL の呼び出しは閉じた PR の問い合わせの 1 回だけ

#### Scenario: 閉じた PR が 1 件ある issue
- **WHEN** 子 issue を持たない issue #12 を閉じた PR #300（ヘッドブランチ `feat/a`、同じリポジトリ）があり、`/cost 12` を実行する
- **THEN** 終了コード 0 で、1 行目は閉じた PR を数えない場合と同じ書式（種別 `区間`）で、2 行目以降に合計・`PR #300` の額・`PR 外` の額を含む行が 1 行ある

#### Scenario: 閉じた PR が 0 件の issue
- **WHEN** 閉じた PR の問い合わせが 0 件を返す issue #12 に `/cost 12` を実行する
- **THEN** 出力は `cost_ledger.py issue 12`（`--closing-pr` なし）と完全に同じ

#### Scenario: 閉じた PR の問い合わせが失敗する
- **WHEN** 閉じた PR の問い合わせ（`gh api graphql`）が失敗する状態で `/cost 12` を実行する
- **THEN** 終了コードは 0 で、区間の分の出力はそのまま返り、`閉じた PR を読めなかったため、PR の分は合計に入っていません。` の行が 1 行あり、合計の行は無い

#### Scenario: 別のリポジトリやフォークの PR は数えない
- **WHEN** 閉じた PR の応答に、ベースが別のリポジトリの PR と `isCrossRepository` が真の PR が含まれる
- **THEN** それらの PR の分は合計にも内訳にも入らない

#### Scenario: 存在しない番号を渡す
- **WHEN** 渡された番号の PR も issue も存在しない
- **THEN** コストを 0 と表示せず、番号が見つからないことを利用者に伝える。閉じた PR の問い合わせは行わない

### Requirement: エピックの集計で呼ぶ `gh` は子を持つ issue ごとに 1 回で、台帳の読み取りは issue の数に比例しない
システムが `cost_ledger.py cost <エピックの番号>` 1 回で呼ぶ `gh` は、番号の判別の 2 回（PR の問い合わせと issue の問い合わせ）に、子を持つ対象の issue の数（エピック自身を含む）を足した回数で MUST ある。GraphQL の呼び出しは子を持つ対象の issue 1 件につき 1 回で、子を持たない子 issue の数と、issue を閉じた PR の数では増えてはなら MUST NOT ない（子が 1 件ずつ入れ子になった鎖では、子を持つ issue の数が段の数だけあるので、その数だけ呼ぶ）。`COST_LEDGER_PATH` があるとき、台帳への差分の追記は 1 回の呼び出しで 1 回だけと SHALL し、台帳を読み通す回数は子 issue の数にも PR の数にも比例してはなら MUST NOT ない（区間の行は対象の issue すべての分を、PR の分はヘッドブランチすべての分を、それぞれまとめて読む）。

#### Scenario: 子が 2 件で孫が無い
- **WHEN** 子 issue を 2 件持ち、それぞれに閉じた PR が 1 件ずつある issue #10 に `cost_ledger.py cost 10` を実行する
- **THEN** `gh` が呼ばれた回数は 3 回（うち GraphQL は 1 回）

#### Scenario: 子の 1 件が孫を持つ
- **WHEN** 「孫を辿る」の状態で `cost_ledger.py cost 10` を実行する
- **THEN** `gh` が呼ばれた回数は 4 回（うち GraphQL は 2 回）

#### Scenario: 子を持たない issue と PR の回数
- **WHEN** 子 issue を持たない issue #12 と、PR #300 に、それぞれ `cost_ledger.py cost <番号>` を実行する
- **THEN** `gh` が呼ばれた回数は issue が 3 回（うち GraphQL は閉じた PR の問い合わせの 1 回）、PR が 1 回で PR の GraphQL は 0 回

