## ADDED Requirements

### Requirement: Codex 消費コメントの印に実行の時刻を書く
develop の本体は、executor が `codex` の役割へ委譲した分の `Codex 消費:` コメントの印に、codex-worker の結果 JSON の `started_at` を `開始=`、`ended_at` を `終了=` の値として MUST 書く（値は結果 JSON の文字列をそのまま写す）。結果 JSON にそのキーが無いか値が `null` なら、そのキーを印から省き、別の時刻（本体が委譲した時刻・コメントを投稿した時刻など）で埋めてはならない（MUST NOT）。G が full レビューで Bash から呼んだ Codex の分は時刻が取れないので、`開始=` `終了=` を書かない。

#### Scenario: Codex の委譲の時刻を印に書く
- **WHEN** 本体が executor `codex` の W の implement 工程の 1 回目の試行の結果を記録する（thread_id `t1`・totalTokens 1200000・Codex の登録名 `current`・結果 JSON の `started_at` が `2026-10-19T23:50:00Z`、`ended_at` が `2026-10-20T00:10:00Z`）
- **THEN** 本体は 1 行目が `Codex 消費: t1 1200000` で、2 行目が `[消費記録 工程=implement 試行=1 アカウント=codex:current 開始=2026-10-19T23:50:00Z 終了=2026-10-20T00:10:00Z]` のコメントを投稿する

#### Scenario: 結果 JSON に時刻が無ければ省く
- **WHEN** 本体が受け取った結果 JSON に `started_at` が無く、`ended_at` が `null` である
- **THEN** `Codex 消費:` コメントの印は `開始=` も `終了=` も含まない

#### Scenario: G の full レビューの分には時刻を書かない
- **WHEN** 本体が G の return に書かれた thread_id で、G が full レビューで呼んだ Codex の消費を記録する
- **THEN** `Codex 消費:` コメントの印は `工程=impl-review` を含み、`開始=` も `終了=` も含まない

#### Scenario: SKILL.md に時刻の書き方が書かれている
- **WHEN** `skills/develop/SKILL.md` の「PR トークン上限」節を読む
- **THEN** Codex の消費の記録に、結果 JSON の `started_at` / `ended_at` から `開始=` / `終了=` を書くこと、取れなければキーごと省くこと、G の full レビューの分には書かないことが書かれ、「消費の記録の印」の時刻の行は `Codex 消費:` コメントの印にだけ書くことを示している

## MODIFIED Requirements

### Requirement: 消費の記録に工程・試行・アカウントの印を書く
develop の本体は、記録先の消費の記録に、1 行の印 `[消費記録 工程=<工程> 試行=<n> アカウント=<provider>:<登録名> 引継ぎ=<k>]` を MUST 書く。キーの順は問わない。`引継ぎ=` は、同じ工程と試行で手渡しにより起こし直した k 番目の担当のときだけ書き、最初の担当には書かない。読み取り側（flatmate の `burn_consumption.py`）の契約に合わせ、この印以外の書き方（自由文）で工程・試行・アカウントを表してはならない（MUST NOT）。
- 置き場は次の 3 か所とする: (1) `Codex 消費:` コメントの 2 行目以降（1 行目の `Codex 消費: <thread_id> <tokens>` の形は変えない）、(2) サブエージェントの `description`（`#N` と同じ文字列の中）、(3) `develop 開始` コメント（本体の起動アカウント。`工程=` と `試行=` は省いてよい）

#### Scenario: Codex 消費コメントの 2 行目に印を書く
- **WHEN** 本体が executor `codex` の W の implement 工程の 2 回目の試行の結果を記録する（thread_id `t1`・totalTokens 1200000・Codex の登録名 `current`・結果 JSON に `started_at` と `ended_at` が無い）
- **THEN** 本体は 1 行目が `Codex 消費: t1 1200000` で、2 行目が `[消費記録 工程=implement 試行=2 アカウント=codex:current]` のコメントを投稿する

#### Scenario: 1 つの工程・試行にしか使わないサブエージェントの description に印を入れる
- **GIVEN** Claude の登録名が `a` と取れていて、記録先 #288 の implement 工程のレビュアー（`impl-review`）の初回（試行 1・手渡しなし）を、再開しない 1 体として起こす
- **WHEN** 本体が spawn する
- **THEN** `description` は `#288` と `[消費記録 工程=impl-review 試行=1 アカウント=claude:a]` を同じ文字列の中に含む

#### Scenario: SKILL.md に規約が書かれている
- **WHEN** `skills/develop/SKILL.md` を読む
- **THEN** 「PR トークン上限」節の紐付けの規約と Codex の消費の記録、「Role profile の選択」節の develop 開始コメントの記述に、印の形・置き場・工程名の語彙・試行と引継ぎの数え方・再開される W の扱い・G とレビュアーの工程の決め方が書かれている

#### Scenario: 手渡しで起こし直した W に引継ぎを書く
- **GIVEN** 登録名 `a` が取れていて、implement 工程の 2 回目の試行を、前任から手渡しで起こし直した 1 番目の担当の W に担わせる（再開しない）
- **WHEN** 本体が記録先 #288 のために spawn する
- **THEN** `description` の印は `工程=implement 試行=2 アカウント=claude:a 引継ぎ=1` を含む

#### Scenario: develop 開始コメントに起動アカウントを書く
- **GIVEN** Claude の起動アカウントの登録名 `a` が取れている
- **WHEN** 本体が `develop 開始` コメントを投稿する
- **THEN** コメントに `[消費記録 アカウント=claude:a]` の行がある（`工程=` と `試行=` は無くてよい）

### Requirement: 消費の記録の印のアカウントと時刻の扱いを決める
develop の本体は、印のアカウントと時刻を次のとおり MUST 扱う。
- アカウントは `claude:<登録名>` か `codex:<CODEX_HOME 対応表の登録名>` とする。登録名が分からないときは `アカウント=` のキーごと省き、推測で埋めてはならない（MUST NOT）
- 時刻（`開始=` `終了=`）は `Codex 消費:` コメントの印にだけ書く（書き方は「Codex 消費コメントの印に実行の時刻を書く」）。サブエージェントの `description` と `develop 開始` コメントの印に書いてはならない（MUST NOT。読み取り側がそこでは読まないキーのため）

守備範囲: この段落は消費の記録の印の 5 要件すべてに掛かる。想定する入力の出どころは、本体が書く記録先のコメントとサブエージェントの `description` である。拾いたい誤りは、別の工程・試行・アカウントの印を書くことと、印の形を読み取り側の契約から外すこと。通ることを許す入力は、印を書き忘れた記録（読み取り側が欠測にする）、`G-<PR>-<段>-<n>` / `V-<記録先番号>-<n>` の名前で工程が決まる G と画面確認のサブエージェントに印が無いこと、時刻の取れない Codex の呼び出しの印に `開始=` `終了=` が無いこと（読み取り側が rollout か欠測で扱う）。印の書き忘れを塞ぎ切ることは完了条件にしない。

#### Scenario: 登録名が分からないときは推測しない
- **WHEN** Claude の起動アカウントの登録名が取れない
- **THEN** description・開始コメントの印は `アカウント=` のキーを含まない

#### Scenario: description と開始コメントの印には時刻を書かない
- **WHEN** 本体がサブエージェントを spawn する、または `develop 開始` コメントを投稿する
- **THEN** description と開始コメントの印は `開始=` も `終了=` も含まない
