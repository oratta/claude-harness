## ADDED Requirements

### Requirement: 消費の記録に工程・試行・アカウントの印を書く
develop の本体は、記録先の消費の記録に、1 行の印 `[消費記録 工程=<工程> 試行=<n> アカウント=<provider>:<登録名> 引継ぎ=<k>]` を MUST 書く。キーの順は問わない。`引継ぎ=` は、同じ工程と試行で手渡しにより起こし直した k 番目の担当のときだけ書き、最初の担当には書かない。読み取り側（flatmate の `burn_consumption.py`）の契約に合わせ、この印以外の書き方（自由文）で工程・試行・アカウントを表してはならない（MUST NOT）。
- 置き場は次の 3 か所とする: (1) `Codex 消費:` コメントの 2 行目以降（1 行目の `Codex 消費: <thread_id> <tokens>` の形は変えない）、(2) サブエージェントの `description`（`#N` と同じ文字列の中）、(3) `develop 開始` コメント（本体の起動アカウント。`工程=` と `試行=` は省いてよい）

#### Scenario: Codex 消費コメントの 2 行目に印を書く
- **WHEN** 本体が executor `codex` の W の implement 工程の 2 回目の試行の結果を記録する（thread_id `t1`・totalTokens 1200000・Codex の登録名 `current`）
- **THEN** 本体は 1 行目が `Codex 消費: t1 1200000` で、2 行目が `[消費記録 工程=implement 試行=2 アカウント=codex:current]` のコメントを投稿する


#### Scenario: 1 つの工程・試行にしか使わないサブエージェントの description に印を入れる
- **GIVEN** Claude の登録名が `a` と取れていて、記録先 #288 の implement 工程のレビュアー（`impl-review`）の初回（試行 1・手渡しなし）を、再開しない 1 体として起こす
- **WHEN** 本体が spawn する
- **THEN** `description` は `#288` と `[消費記録 工程=impl-review 試行=1 アカウント=claude:a]` を同じ文字列の中に含む


#### Scenario: SKILL.md に規約が書かれている
- **WHEN** `skills/develop/SKILL.md` を読む
- **THEN** 「PR トークン上限」節の紐付けの規約と Codex の消費の記録、「Role profile の選択」節の develop 開始コメントの記述に、印の形・置き場・工程名の語彙・試行と引継ぎの数え方・再開される W の扱い・G とレビュアーの工程の決め方が書かれている

### Requirement: 消費の記録の印の工程と試行を決める
develop の本体は、印の工程と試行を次のとおり MUST 決める。
- 工程の値は `spec`・`spec-review`・`implement`・`impl-review`・`finish`・`gate-prepare`・`gate-triage`・`gate-pass`・`gate-hold`・`decide`・`screen-check` のどれかとする
- 試行は、工程ごとに 1 から数え、差戻しの修正で同じ工程をやり直すたびに増やす
- G 自身の工程は、本体が起こした段（G の名前 `G-<PR>-<prepare|triage|pass|hold>-<n>`）から `gate-<段>` と決める。Gate Result の `段:` の値は使わない。G が要求した Codex や Claude のレビュアーの工程は `impl-review` とする

#### Scenario: 手渡しで起こし直した W に引継ぎを書く
- **GIVEN** 登録名 `a` が取れていて、implement 工程の 2 回目の試行を、前任から手渡しで起こし直した 1 番目の担当の W に担わせる（再開しない）
- **WHEN** 本体が記録先 #288 のために spawn する
- **THEN** `description` の印は `工程=implement 試行=2 アカウント=claude:a 引継ぎ=1` を含む


#### Scenario: G と G が要求したレビュアーの工程
- **GIVEN** 登録名 `a` が取得済みで、名前が `G-1700-triage-1` の G（triage 段の初回・手渡しなし）が、full レビューで Codex を呼んだ（Gate Result の `段:` は日本語名）
- **WHEN** 本体が G とその Codex 消費を記録する
- **THEN** G の description の印は `工程=gate-triage 試行=1 アカウント=claude:a`、Codex の `Codex 消費:` コメントの印は `工程=impl-review`（試行は impl-review の回数）である


#### Scenario: G を手渡しで起こし直しても試行は増えない
- **GIVEN** 登録名 `a` が取得済みで、`G-1700-triage-1` が `工程中断:` で止まり、triage 段の初回の試行のまま手渡しで新しい G を起こす
- **WHEN** 本体が `G-1700-triage-2` を spawn する
- **THEN** description の印は `工程=gate-triage 試行=1 アカウント=claude:a 引継ぎ=1` である（名前の `<n>` は起動回数で、試行ではない）


#### Scenario: 差戻しのあとの G の試行は増える
- **GIVEN** 登録名 `a` が取得済みで、triage 段の 1 回目の試行が差戻しで終わり、手渡しは無い
- **WHEN** 本体が `G-1700-triage-2` を spawn する
- **THEN** description の印は `工程=gate-triage 試行=2 アカウント=claude:a` で、`引継ぎ=` を含まない

### Requirement: 消費の記録の印のアカウントと時刻の扱いを決める
develop の本体は、印のアカウントと時刻を次のとおり MUST 扱う。
- アカウントは `claude:<登録名>` か `codex:<CODEX_HOME 対応表の登録名>` とする。登録名が分からないときは `アカウント=` のキーごと省き、推測で埋めてはならない（MUST NOT）
- 印に時刻（`開始=` `終了=`）を書いてはならない（MUST NOT。読み取り側の契約に無いキーのため）

守備範囲: 想定する入力の出どころは、本体が書く記録先のコメントとサブエージェントの `description` である。拾いたい誤りは、別の工程・試行・アカウントの印を書くことと、印の形を読み取り側の契約から外すこと。通ることを許す入力は、印を書き忘れた記録（読み取り側が欠測にする）、`G-<PR>-<段>-<n>` / `V-<記録先番号>-<n>` の名前で工程が決まる G と画面確認のサブエージェントに印が無いこと。印の書き忘れを塞ぎ切ることは完了条件にしない。

#### Scenario: develop 開始コメントに起動アカウントを書く
- **GIVEN** Claude の起動アカウントの登録名 `a` が取れている
- **WHEN** 本体が `develop 開始` コメントを投稿する
- **THEN** コメントに `[消費記録 アカウント=claude:a]` の行がある（`工程=` と `試行=` は無くてよい）


#### Scenario: 登録名が分からないときは推測しない
- **WHEN** Claude の起動アカウントの登録名が取れない
- **THEN** description・開始コメントの印は `アカウント=` のキーを含まない

### Requirement: 再開されるサブエージェントの印を再開の指示文に書く
- 同じサブエージェントを SendMessage で別の工程・試行へ再開しうるとき（既定の W）は、`description` の印に `工程=` と `試行=` を書いてはならない（MUST NOT。読み取り側は 1 体を 1 行にして description の印から 1 つだけ読むため、再開後の消費が起動時の工程・試行へ誤帰属する）。`アカウント=`（と該当すれば `引継ぎ=`）だけを書く。本体は再開のたびに、再開の指示文の先頭にその再開が担う工程・試行の印を 1 行置く MUST

#### Scenario: 再開される W は spec から implement へ
- **GIVEN** 登録名 `a` が取得済みで、同じ W が spec 工程のあと、implement の初回（試行 1・手渡しなし）として SendMessage で再開される
- **WHEN** 本体が W を spawn し、のちに再開する
- **THEN** spawn 時の `description` の印は `工程=` と `試行=` を含まず（`アカウント=` だけ）、implement への再開の指示文の先頭に `[消費記録 工程=implement 試行=1 アカウント=claude:a]` の行がある


#### Scenario: 差戻しの修正で implement を試行 1 から 2 へ再開する
- **GIVEN** 登録名 `a` が取得済みで、同じ W が implement 試行 1 のあと、差戻しの修正（試行 2・手渡しなし）のために SendMessage で再開される
- **WHEN** 本体が再開する
- **THEN** 再開の指示文の先頭に `[消費記録 工程=implement 試行=2 アカウント=claude:a]` の行があり、spawn 時の `description` の印は `工程=` と `試行=` を含まない

