## MODIFIED Requirements

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
