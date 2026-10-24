## ADDED Requirements

### Requirement: 消費の記録に工程・試行・アカウントの印を書く
develop の本体は、記録先の消費の記録に、1 行の印 `[消費記録 工程=<工程> 試行=<n> アカウント=<provider>:<登録名> 引継ぎ=<k>]` を MUST 書く。キーの順は問わない。`引継ぎ=` は、同じ工程と試行で手渡しにより起こし直した k 番目の担当のときだけ書き、最初の担当には書かない。読み取り側（flatmate の `burn_consumption.py`）の契約に合わせ、この印以外の書き方（自由文）で工程・試行・アカウントを表してはならない（MUST NOT）。

- 工程の値は `spec`・`spec-review`・`implement`・`impl-review`・`finish`・`gate-prepare`・`gate-triage`・`gate-pass`・`gate-hold`・`decide`・`screen-check` のどれかとする
- 試行は、工程ごとに 1 から数え、差戻しの修正で同じ工程をやり直すたびに増やす
- アカウントは `claude:<登録名>` か `codex:<CODEX_HOME 対応表の登録名>` とする。登録名が分からないときは `アカウント=` のキーごと省き、推測で埋めてはならない（MUST NOT）
- 置き場は次の 3 か所とする: (1) `Codex 消費:` コメントの 2 行目以降（1 行目の `Codex 消費: <thread_id> <tokens>` の形は変えない）、(2) サブエージェントの `description`（`#N` と同じ文字列の中）、(3) `develop 開始` コメント（本体の起動アカウント。`工程=` と `試行=` は省いてよい）
- 印に時刻（`開始=` `終了=`）を書いてはならない（MUST NOT。読み取り側の契約に無いキーのため）

守備範囲: 想定する入力の出どころは、本体が書く記録先のコメントとサブエージェントの `description` である。拾いたい誤りは、別の工程・試行・アカウントの印を書くことと、印の形を読み取り側の契約から外すこと。通ることを許す入力は、印を書き忘れた記録（読み取り側が欠測にする）、`G-<PR>-<段>-<n>` / `V-<記録先番号>-<n>` の名前で工程が決まる G と画面確認のサブエージェントに印が無いこと。印の書き忘れを塞ぎ切ることは完了条件にしない。

#### Scenario: Codex 消費コメントの 2 行目に印を書く
- **WHEN** 本体が executor `codex` の W の implement 工程の 2 回目の試行の結果を記録する（thread_id `t1`・totalTokens 1200000・Codex の登録名 `current`）
- **THEN** 本体は 1 行目が `Codex 消費: t1 1200000` で、2 行目が `[消費記録 工程=implement 試行=2 アカウント=codex:current]` のコメントを投稿する

#### Scenario: サブエージェントの description に印を入れる
- **WHEN** 本体が記録先 #288 のために implement 工程の W を、手渡しで起こし直した 1 番目の担当として spawn する
- **THEN** `description` は `#288` と `[消費記録 工程=implement 試行=1 アカウント=claude:<登録名> 引継ぎ=1]` を同じ文字列の中に含む

#### Scenario: develop 開始コメントに起動アカウントを書く
- **WHEN** 本体が `develop 開始` コメントを投稿する
- **THEN** コメントに `[消費記録 アカウント=claude:<登録名>]` の行がある（`工程=` と `試行=` は無くてよい）

#### Scenario: 登録名が分からないときは推測しない
- **WHEN** Claude の起動アカウントの登録名が取れない
- **THEN** 印は `アカウント=` のキーを含まない

#### Scenario: SKILL.md に規約が書かれている
- **WHEN** `skills/develop/SKILL.md` を読む
- **THEN** 「PR トークン上限」節の紐付けの規約と Codex の消費の記録、「Role profile の選択」節の develop 開始コメントの記述に、印の形・置き場・工程名の語彙・試行と引継ぎの数え方が書かれている
