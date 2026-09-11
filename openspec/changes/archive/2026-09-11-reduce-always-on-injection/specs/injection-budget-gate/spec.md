## MODIFIED Requirements

### Requirement: 常時注入される固定分の合計サイズを測る

`scripts/test.sh` の全件実行に、常時注入される固定分の合計サイズを測る bats スイート `tests/injection-budget.bats` が含まれなければならない（MUST）。測定対象は次の 8 種の合計とし、単位はバイト（`wc -c` 相当）とする。ロケールに依存する文字数計測（`wc -m`）を使ってはならない（MUST NOT）。

1. **rules**: `rules/*.md` のうち basename が `README.md` でないもの
2. **CLAUDE.md**: リポジトリ直下の `CLAUDE.md`。同期複製である `AGENTS.md` を合計に含めてはならない（MUST NOT）
3. **output-styles**: `output-styles/*.md` のうち basename が `README.md` でないもの
4. **SKILL description**: `plugins/*/skills/*/SKILL.md` の frontmatter `description` の値
5. **agent description**: `plugins/*/agents/*.md` の frontmatter `description` の値
6. **command description**: `plugins/*/commands/*.md` の frontmatter `description` の値
7. **local SKILL description**: `.claude/skills/` 配下の `SKILL.md` の frontmatter `description` の値
8. **local command description**: `.claude/commands/` 配下の `*.md` の frontmatter `description` の値

1 と 3 の**配布対象**の判定は、`scripts/sync.sh` が `~/.claude/rules/` および `~/.claude/output-styles/` へ symlink する条件と同一でなければならない（MUST）。

1 と 3 の**常時注入対象**は、その配布対象から frontmatter に `paths:` を持つファイルを除いたものでなければならない（MUST）。`paths:` を持つファイルは対象パスに一致するファイルを読んだときだけ載るので、常時注入の合計に数えてはならない（MUST NOT）。テストはこの `paths:` の有無以外の除外条件を持ってはならない（MUST NOT）。独自の除外リスト（ファイル名の直書き等）を持ってはならない（MUST NOT）。

`paths:` の値に含まれる各 glob は、**リテラルのパスセグメントを 1 つ以上含まなければならない**（MUST）。リテラルのパスセグメントとは、`/` で区切った要素のうち、ワイルドカード文字（`*` `?` `[` `]` `{` `}`）を 1 つも含まず、英数字を 1 文字以上含むものをいう。これを満たさない glob（`**`・`*`・`**/*`・`**/*.md` 等）を持つファイルがあれば、テストは fail しなければならない（MUST）。この条件が無いと、`paths: ["**"]` を付けたルールが実際には常時載ったまま合計からだけ消え、削減を偽装できてしまう。

4〜8 の対象は、それぞれのディレクトリ配下を任意の深さで走査して集めなければならない（MUST）。1 階層深いディレクトリにファイルを置くことで集計から外れてはならない（MUST NOT）。

4〜8 の `description` は、`description: ` の接頭辞を落とした値の文字列そのもののバイト数を足すものとし、行末の改行を数えてはならない（MUST NOT）。この定義をテストのコメントに明記しなければならない（MUST）。

**内訳の形式**: 内訳は上の 8 種に対応する 8 行のままでなければならない（MUST）。`paths:` によって除外したファイルは、合計に入らないことが分かる形で失敗時の出力に示さなければならない（MUST）。内訳の合計は「表示名 <TAB> バイト数」の 2 列目を足して求めるため、除外分の行は **TAB 文字を含まない注記行**として出さなければならない（MUST）。TAB 区切りの同じ形式で出してはならない（MUST NOT。除外したはずのバイト数が合計に戻る）。

#### Scenario: 現状の main で予算テストが pass する

- **WHEN** リポジトリのルートで `scripts/test.sh injection-budget` を実行する
- **THEN** exit code が 0 で、TAP 出力に `not ok` が含まれない

#### Scenario: 予算テストが全件実行の経路に載っている

- **WHEN** `git ls-files '*.bats'` の出力を見る
- **THEN** `tests/injection-budget.bats` が含まれ、`scripts/test.sh` を引数なしで実行したときの `▶ bats suites:` の一覧にも現れる

#### Scenario: README.md は rules と output-styles のどちらでも合計に含まれない

- **WHEN** 一時ディレクトリに `README.md` と別の `*.md` を置き、集計ヘルパにそのディレクトリを渡す
- **THEN** 返るバイト数は `README.md` を除いた `*.md` の合計と等しい

#### Scenario: AGENTS.md は合計に含まれない

- **WHEN** テストが出力する内訳の一覧を見る
- **THEN** `CLAUDE.md` は 1 回だけ数えられており、`AGENTS.md` は測定対象に現れない

#### Scenario: description の集計は末尾改行を数えない

- **WHEN** 一時ディレクトリに frontmatter の `description` が既知の長さ N バイトのファイルを 3 本置き、description 集計ヘルパに渡す
- **THEN** 返るバイト数がちょうど 3N であり、ファイル本数ぶんの加算（3N+3）になっていない

#### Scenario: paths を持つファイルが常時注入の合計から外れる

- **WHEN** 一時ディレクトリに frontmatter に `paths:` を持つ `*.md` と持たない `*.md` を置き、常時注入の集計ヘルパに渡す
- **THEN** 返るバイト数は `paths:` を持たないファイルのバイト数だけの和であり、配布対象の集計ヘルパに同じディレクトリを渡すと両方のファイルを含む和が返る

#### Scenario: paths を持つファイルが無いときの内訳と出力

- **WHEN** `paths:` を持つルールが 1 本も無い状態で `scripts/test.sh injection-budget` を実行し、内訳と失敗時の出力を見る
- **THEN** `rules/*.md` の行のバイト数が README を除く全ファイルのバイト数の和と一致し、除外分の注記行は出力に 1 行も現れない

#### Scenario: 除外分の注記行が合計に戻らない

- **WHEN** `paths:` を持つルールがある状態で、内訳と注記行を合わせた出力を合計ヘルパ（`sum_breakdown`）に渡す
- **THEN** 返る合計は内訳 8 行の 2 列目の和と等しく、除外したファイルのバイト数は加算されていない（注記行が TAB を含まないため 2 列目が存在しない）

#### Scenario: 内訳は 8 行のままである

- **WHEN** 予算超過時の出力を見る
- **THEN** `rules/*.md`・`CLAUDE.md`・`output-styles/*.md`・`plugins SKILL.md description`・`plugins agent description`・`plugins command description`・`.claude/skills SKILL.md description`・`.claude/commands description` の 8 つの表示名がすべて現れる（除外分の注記行はこの 8 行に加えない）

#### Scenario: 全体一致の glob を持つファイルを落とす

- **WHEN** 一時ディレクトリに `paths: ["**"]` を持つファイルを置き、glob 検査ヘルパに渡す
- **THEN** 違反として検出され、該当ファイル名が出力される。`**/*`・`*`・`**/*.md` も同じく違反となり、`rules/**`・`plugins/dev-workflow/**` のようにリテラルのパスセグメントを含む glob は違反にならない
