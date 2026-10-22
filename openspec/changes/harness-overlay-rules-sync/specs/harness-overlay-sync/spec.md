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

`<CLAUDE_DIR>/rules/` 直下の `*.md` のうち、symlink で行き先が公開版の `rules/` 直下のファイルであるものは、新位置への symlink を張ったあとで消さなければならない（MUST）。実ファイルと、公開版の `rules/` 以外を指す symlink には触れてはならない（MUST NOT）。ただし、行き先が `<CLAUDE_DIR>/plugins/marketplaces/` の下の壊れた symlink は、要件「壊れた symlink の掃除は行き先が marketplace の下のものだけを対象にする」に従って消す（この保持の対象から除く）。

#### Scenario: 旧位置の symlink が移る
- **WHEN** 直下に公開版を指す symlink がある状態で実行する
- **THEN** 新位置に symlink ができ、直下の symlink は無くなる

#### Scenario: 無関係なファイルは残る
- **WHEN** 直下に実ファイルと、行き先が marketplace の下でない（存在する、または存在しない）symlink がある状態で実行する
- **THEN** どれも残り、終了コードは 0（行き先が marketplace の下の壊れた symlink は掃除の要件で消える）

### Requirement: overlay は印のファイルで見つけて重ねる

`scripts/sync.sh` は、`<CLAUDE_DIR>/plugins/marketplaces/*/` のうち直下に `.harness-overlay` を持つディレクトリを overlay として扱わなければならない（MUST）。`.harness-overlay` の 1 行目をサブディレクトリ名とし、overlay の `rules/*.md`（`README.md` を除く）を `<CLAUDE_DIR>/rules/claude-harness/<名前>/` の下に symlink で張る。サブディレクトリ名が `[a-z0-9][a-z0-9-]*` に合わない、または空のときは、その overlay を飛ばして警告し、非 0 で終わる（MUST）。`scripts/sync.sh` は個人版の名前を書いてはならない（MUST NOT）。

#### Scenario: overlay の rules が重なる
- **WHEN** 印のファイル（中身 `ov`）と `rules/x.md` を持つ overlay を置いて実行する
- **THEN** `rules/claude-harness/ov/x.md` が overlay の `rules/x.md` を指し、公開版の分も `rules/claude-harness/` に残る

#### Scenario: 不正な名前の overlay は飛ばす
- **WHEN** 印のファイルの中身が `../x` の overlay を置いて実行する
- **THEN** その overlay の分は張られず、警告が出て、終了コードは 0 でなく、公開版の分は張られる

#### Scenario: 同じ名前の overlay が 2 つある
- **WHEN** 印のファイルの中身が同じ名前の overlay を 2 つ置いて実行する
- **THEN** marketplace のディレクトリ名が辞書順で先のものだけが張られ、後のものは警告して飛ばされ、終了コードは 0 でない

#### Scenario: overlay 名と同じ名前の実ファイルがある
- **WHEN** `rules/claude-harness/ov` が実ファイル（ディレクトリでない）の状態で、名前 `ov` の overlay を置いて実行する
- **THEN** 実ファイルは残り、その overlay の分は張られず、警告が出て、終了コードは 0 でなく、公開版の分は張られる

#### Scenario: 張り先に内容の違う実ファイルがある
- **WHEN** `rules/claude-harness/communication-style.md` が公開版と内容の違う実ファイルの状態で実行する
- **THEN** 実ファイルは残り、警告が出て、終了コードは 0 でない（内容が同じ実ファイルなら symlink に置き換わる）

### Requirement: overlay の印のファイルの検査の守備範囲

`scripts/sync.sh` が印のファイルに対して行う検査は、次の範囲に限らなければならない（MUST）。

- 想定する入力の出どころ: オーナーなどの管理者が自分の環境の marketplace に置く `.harness-overlay` と、その overlay の `rules/`・`output-styles/`。敵対的な入力（悪意のある第三者が marketplace を差し込む）は想定しない
- 拾う誤り: 名前が空・`[a-z0-9][a-z0-9-]*` に合わない・`claude-harness` の下に同名の実ファイルがある（ディレクトリを作れない）・別の overlay と名前が重なる、のいずれか。拾った overlay は飛ばして警告し、終了コードを 0 でなくする
- 通ることを許す入力: 形式が正しい overlay の中の、ルールの意味的な矛盾（公開版のルールと食い違う内容）、印のファイルの 2 行目以降の内容、overlay の中身が空であること。これらは検査しない
- 穴をすべて塞ぐことは完了条件にしない。上の誤りを拾えることと、overlay が無い環境で警告なく動くことが完了条件である

#### Scenario: 意味的な矛盾は検査しない
- **WHEN** 形式が正しい overlay が、公開版と内容の食い違うルールを持つ状態で実行する
- **THEN** 食い違いは検査されず、両方が張られ、終了コードは 0

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

`scripts/sync.sh` は公開版と overlay の `output-styles/*.md` を `<CLAUDE_DIR>/output-styles/` 直下に張る。公開版の分は overlay より先に張る。overlay の分が、公開版を指す symlink と同名のとき、その 1 本を張らず、警告して非 0 で終わらなければならない（MUST）。公開版の分を張るとき、同名の既存の symlink の行き先が `<CLAUDE_DIR>/plugins/marketplaces/` の下（別の Harness）なら、警告せず公開版を指すように張り替えなければならない（MUST）。張り先に公開版や overlay の同名ファイルと内容が同じ実ファイルがあるときは、rules と同じく symlink に置き換え（コピー運用からの移行）、内容が違う実ファイルと、それ以外の場所を指す symlink には触れない（MUST NOT）。

#### Scenario: 同名の output style
- **WHEN** 公開版の `readable.md` と同名の `output-styles/readable.md` を持つ overlay で実行する
- **THEN** `output-styles/readable.md` は公開版を指したままで、警告が出て、終了コードは 0 でない

#### Scenario: overlay の style を張ったあとで公開版に同名が足された
- **WHEN** overlay の `output-styles/x.md` を張った実行のあと、公開版に同名の `output-styles/x.md` が足された状態で再実行する
- **THEN** `output-styles/x.md` は公開版を指すように張り替わり、続く overlay の分で同名の衝突として警告が出て、終了コードは 0 でない

#### Scenario: 内容が同じ実ファイルは symlink になる
- **WHEN** `output-styles/readable.md` が公開版と内容の同じ実ファイルの状態で実行する
- **THEN** symlink に置き換わり、終了コードは 0

#### Scenario: 無関係な symlink の同名は触らない
- **WHEN** `output-styles/readable.md` が `/etc/hosts` を指す symlink の状態で実行する
- **THEN** symlink は残り、警告が出て、終了コードは 0 でない

### Requirement: 壊れた symlink の掃除は行き先が marketplace の下のものだけを対象にする

`scripts/sync.sh` は、`<CLAUDE_DIR>/rules/`・`<CLAUDE_DIR>/rules/claude-harness/`・`<CLAUDE_DIR>/rules/claude-harness/*/`・`<CLAUDE_DIR>/output-styles/` の `*.md` のうち、symlink で、リンク先が存在せず、行き先の文字列が `<CLAUDE_DIR>/plugins/marketplaces/` で始まるものを消さなければならない（MUST）。overlay を外すと印のファイルも消えるので、所有元は印のファイルでなく行き先の文字列で決める。行き先がそれ以外の壊れた symlink と実ファイルには触れてはならない（MUST NOT）。`claude-harness/<名前>/` が掃除のあとで空になったら、そのディレクトリを消す。

#### Scenario: overlay を外したあとの掃除
- **WHEN** overlay を張った実行のあと、overlay のディレクトリを消して再実行する
- **THEN** `claude-harness/<名前>/` の下の壊れた symlink が無くなり、空になったそのディレクトリも無くなる

#### Scenario: 無関係な壊れたリンクは残る
- **WHEN** `rules/claude-harness/ov/` の下に、行き先が `/nonexistent/other.md` の壊れた symlink と実ファイルがある状態で再実行する
- **THEN** どちらも残り、そのディレクトリも残る
