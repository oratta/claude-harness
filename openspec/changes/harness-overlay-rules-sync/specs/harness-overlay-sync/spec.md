## ADDED Requirements

### Requirement: rules は出どころごとのサブディレクトリに張る

`scripts/sync.sh` は、公開版の `rules/*.md`（`README.md` を除く）を `<CLAUDE_DIR>/rules/claude-harness/` の下に symlink で張らなければならない（MUST）。サブディレクトリ名 `claude-harness` は固定の文字列で、marketplace のディレクトリ名から作ってはならない（MUST NOT）。`<CLAUDE_DIR>/rules/` の直下に公開版のファイルを新しく張ってはならない（MUST NOT）。

#### Scenario: 初回に新しい位置へ張る
- **WHEN** 使い捨ての `CLAUDE_CONFIG_DIR` で `scripts/sync.sh --no-pull` を実行する
- **THEN** `rules/claude-harness/communication-style.md` が公開版の `rules/communication-style.md` を指す symlink になり、`rules/communication-style.md`（直下）は無い

#### Scenario: 2 回目は何も変えない
- **WHEN** 続けてもう一度実行する
- **THEN** 終了コードは 0 で、symlink は同じまま

### Requirement: 旧位置の symlink は新位置に張ったあとで片付ける

`<CLAUDE_DIR>/rules/` 直下の `*.md` のうち、symlink で行き先が公開版の `rules/` 直下のファイルであるものは、新位置への symlink を張ったあとで消さなければならない（MUST）。実ファイルと、公開版の `rules/` 以外を指す symlink には触れてはならない（MUST NOT）。

#### Scenario: 旧位置の symlink が移る
- **WHEN** 直下に公開版を指す symlink がある状態で実行する
- **THEN** 新位置に symlink ができ、直下の symlink は無くなる

#### Scenario: 無関係なファイルは残る
- **WHEN** 直下に実ファイルと他所を指す symlink がある状態で実行する
- **THEN** どちらも残り、終了コードは 0

### Requirement: overlay は印のファイルで見つけて重ねる

`scripts/sync.sh` は、`<CLAUDE_DIR>/plugins/marketplaces/*/` のうち直下に `.harness-overlay` を持つディレクトリを overlay として扱わなければならない（MUST）。`.harness-overlay` の 1 行目をサブディレクトリ名とし、overlay の `rules/*.md`（`README.md` を除く）を `<CLAUDE_DIR>/rules/claude-harness/<名前>/` の下に symlink で張る。サブディレクトリ名が `[a-z0-9][a-z0-9-]*` に合わない、または空のときは、その overlay を飛ばして警告し、非 0 で終わる（MUST）。`scripts/sync.sh` は個人版の名前を書いてはならない（MUST NOT）。

#### Scenario: overlay の rules が重なる
- **WHEN** 印のファイル（中身 `ov`）と `rules/x.md` を持つ overlay を置いて実行する
- **THEN** `rules/claude-harness/ov/x.md` が overlay の `rules/x.md` を指し、公開版の分も `rules/claude-harness/` に残る

#### Scenario: 不正な名前の overlay は飛ばす
- **WHEN** 印のファイルの中身が `../x` の overlay を置いて実行する
- **THEN** その overlay の分は張られず、警告が出て、終了コードは 0 でなく、公開版の分は張られる

### Requirement: overlay が無い環境では警告なく公開版だけで動く

overlay が 1 つも見つからないとき、`scripts/sync.sh` は overlay に関する出力をしてはならず（MUST NOT）、公開版だけを張って終了コード 0 で終わらなければならない（MUST）。

#### Scenario: 客の Mac を模した環境
- **WHEN** `<CLAUDE_DIR>/plugins/marketplaces/` が無い状態で実行する
- **THEN** 標準エラーは空で、終了コードは 0

### Requirement: 同名のルールは別のディレクトリに張られ、両方読まれる

公開版と overlay が同じファイル名のルールを持つとき、`scripts/sync.sh` は両方を、それぞれのサブディレクトリに張らなければならない（MUST）。どちらかを飛ばしたり、上書きしたりしてはならない（MUST NOT）。

#### Scenario: 同名のルール
- **WHEN** 公開版の `communication-style.md` と同名の `rules/communication-style.md` を持つ overlay で実行する
- **THEN** `rules/claude-harness/communication-style.md` と `rules/claude-harness/<名前>/communication-style.md` が、それぞれの出どころを指す

### Requirement: output style は 1 階層のままで、同名なら公開版を優先する

`scripts/sync.sh` は公開版と overlay の `output-styles/*.md` を `<CLAUDE_DIR>/output-styles/` 直下に張る。overlay の分が既存の他所を指す symlink（公開版の分を含む）と同名のとき、その 1 本を張らず、警告して非 0 で終わらなければならない（MUST）。

#### Scenario: 同名の output style
- **WHEN** 公開版の `readable.md` と同名の `output-styles/readable.md` を持つ overlay で実行する
- **THEN** `output-styles/readable.md` は公開版を指したままで、警告が出て、終了コードは 0 でない

### Requirement: 古い overlay の symlink と壊れた symlink を掃除する

`scripts/sync.sh` は、張り先のディレクトリにある、公開版または overlay を指す壊れた symlink を消さなければならない（MUST）。overlay のディレクトリが無くなっても、`claude-harness/<名前>/` の下の壊れた symlink は次の実行で消えなければならない（MUST）。実ファイルと他所を指す symlink には触れない。

#### Scenario: overlay を外したあとの掃除
- **WHEN** overlay を張った実行のあと、overlay のディレクトリを消して再実行する
- **THEN** `claude-harness/<名前>/` の下の壊れた symlink が無くなる
