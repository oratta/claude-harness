# injection-budget-gate Specification

## Purpose
常時注入される固定分（`rules/` / `CLAUDE.md` / `output-styles/` / plugins と `.claude/` 配下の `description`）の合計サイズに予算を置き、編集時のテストで上下両方向の逸脱を検出して「削るか、予算を動かすか」の判断を PR の diff に出す仕組み。測定対象の定義・測定単位・予算ファイルの位置と聖域扱い・変更手続きを含む。
## Requirements
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

1 と 3 の対象判定は、`scripts/sync.sh` が `~/.claude/rules/` および `~/.claude/output-styles/` へ symlink する条件と同一でなければならない（MUST）。テストは独自の除外リストを持ってはならない（MUST NOT）。

4〜8 の対象は、それぞれのディレクトリ配下を任意の深さで走査して集めなければならない（MUST）。1 階層深いディレクトリにファイルを置くことで集計から外れてはならない（MUST NOT）。

4〜8 の `description` は、`description: ` の接頭辞を落とした値の文字列そのもののバイト数を足すものとし、行末の改行を数えてはならない（MUST NOT）。この定義をテストのコメントに明記しなければならない（MUST）。

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

### Requirement: 予算値は独立ファイルに置き、値の変更だけで判定が変わる

予算値は `tests/injection-budget.txt` に数値のみを含む形で置かなければならない（MUST）。テストはこのファイルを読んで比較し、判定の閾値をテストスクリプト内に直書きしてはならない（MUST NOT）。予算値を変更すると、テストコードを変更せずに判定が変わらなければならない（MUST）。

#### Scenario: 予算超過を予算値の変更だけで解消できる

- **WHEN** 集計ヘルパに余分なファイルを足した一覧を渡して予算超過を作り、その後 `tests/injection-budget.txt` の数値だけを「超過量以上、かつ実測合計の 1.1 倍以下」の値に変更して再判定する
- **THEN** 1 回目は fail し、2 回目は pass する（`tests/injection-budget.bats` は 1 文字も変更していない）

#### Scenario: 予算値の変更が単独の diff として現れる

- **WHEN** 予算値を変更した PR で `git diff --stat` を見る
- **THEN** `tests/injection-budget.txt` が 1 行の変更として単独で現れる

### Requirement: 予算は実測に対して上下両方向のラチェットとして働く

予算値は、実測合計以上であり、かつ実測合計の 1.1 倍以下でなければならない（MUST）。すなわち判定は次のとおりとし、この 2 条件を常駐のテストとして毎回検査しなければならない（MUST）。初期値の一度きりの確認にとどめてはならない（MUST NOT）。

- 実測合計が予算値を超えたら fail する（超過側）
- 予算値が実測合計の 1.1 倍を超えたら fail する（下振れ側）
- 予算値と実測合計が等しいときは pass する（どちらの条件にも当たらない）

比較は整数演算で行い、浮動小数点を使ってはならない（MUST NOT）。予算の初期値は、この change を適用した時点の実測合計に約 5% の余裕を足した値とする（SHOULD）。

#### Scenario: 予算と実測が等しいときは pass する

- **WHEN** 予算値を実測合計とちょうど同じ値にして判定する
- **THEN** pass する

#### Scenario: 注入対象を減らしたまま予算を据え置くと fail する

- **WHEN** 集計ヘルパに渡す一覧から、実測合計の 10% を超える分のファイルを取り除き、予算値を据え置いて判定する
- **THEN** fail し、下振れ側の失敗であることが出力からわかる

#### Scenario: 予算を引き上げられる上限は実測の 1.1 倍

- **WHEN** 予算値を実測合計の 1.1 倍より大きい値に設定して判定する
- **THEN** 超過が無くても fail する（引き上げは実測の 1.1 倍までしか許されない）

#### Scenario: 導入時点の予算に約 5% の余裕がある

- **WHEN** `tests/injection-budget.txt` の値と、テストが測定した現状の合計値を比べる
- **THEN** 予算値が合計値以上で、かつ合計値の 1.1 倍以下である

### Requirement: 失敗時の出力は差分量・内訳・取るべき行動を示す

判定が fail したときのテストの出力には、次の 3 つがすべて含まれなければならない（MUST）。

1. 予算値・実測合計・その差分量（バイト）と、超過側と下振れ側のどちらの失敗かの区別
2. 測定対象 8 種それぞれの実測値の内訳
3. 取るべき行動。超過側では「削る」か「`tests/injection-budget.txt` を上げて PR 本文に理由を書く」かの 2 択、下振れ側では「`tests/injection-budget.txt` を推奨値（実測合計 + 約 5%）に下げる」旨と、その推奨値の具体的な数値

#### Scenario: 超過時に差分量と内訳が出る

- **WHEN** 集計ヘルパに余分なファイルを足した一覧を渡して予算超過を作り、失敗出力を読む
- **THEN** 予算値・合計・超過量の 3 つの数値と、8 種の内訳の行が出力されている

#### Scenario: 超過時に取りうる 2 つの選択肢が出る

- **WHEN** 上と同じ失敗出力を読む
- **THEN** 「削る」旨と「`tests/injection-budget.txt` を上げて PR 本文に理由を書く」旨の両方が書かれている

#### Scenario: 下振れ時に推奨値付きの指示が出る

- **WHEN** 注入対象を実測の 10% を超えて減らした状態で失敗出力を読む
- **THEN** 下振れであることと、`tests/injection-budget.txt` を下げるべき推奨値が具体的な数値で書かれている

### Requirement: 折りたたみ記法で description を集計から逃がせない

`plugins/*/skills/*/SKILL.md`・`plugins/*/agents/*.md`・`plugins/*/commands/*.md`、および `.claude/skills/` 配下の `SKILL.md`・`.claude/commands/` 配下の `*.md` の frontmatter において、`description:` の値は単一行でなければならない（MUST）。YAML の折りたたみ・リテラル記法（`description: >`、`description: |` およびその変種）を使ってはならない（MUST NOT）。テストはこれを検査し、違反があれば fail しなければならない（MUST）。

これは 2 行目以降が集計から漏れて `description` を無制限に増やせる抜け道を塞ぐためのガードである。

#### Scenario: 現状の全ファイルが単一行 description である

- **WHEN** `scripts/test.sh injection-budget` を実行する
- **THEN** 折りたたみ記法の検査が pass する（`description:` の次の行がいずれも別のトップレベル frontmatter キーか frontmatter の終端である）

#### Scenario: 折りたたみ記法を検出して落とす

- **WHEN** 一時ディレクトリに `description: >` と次行にインデントされた継続行を持つファイルを置き、検査ヘルパに渡す
- **THEN** 違反として検出され、該当ファイル名が出力される

### Requirement: 予算ファイルは聖域として機械マージの対象外にする

`.github/workflows/auto-merge.yml` の `SACRED` 正規表現は `tests/injection-budget.txt` に一致しなければならない（MUST）。`scripts/test-auto-merge-workflow.sh` の「聖域と必ず一致しなければならないパス」の一覧にも同じパスを足さなければならない（MUST。workflow 内のコメントがこの二重化を要求している）。

#### Scenario: 予算ファイルが聖域と判定される

- **WHEN** `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 で、`tests/injection-budget.txt` が「聖域と判定される」側の検査に含まれている

#### Scenario: 無関係なファイルは聖域のままにならない

- **WHEN** 同じスクリプトの「聖域と判定されてはならないパス」の検査結果を見る
- **THEN** `docs/innocuous-notes.md` などの既存の非聖域パスが引き続き非聖域と判定されている

### Requirement: 予算ファイルの変更手続きを CLAUDE.md に定める

予算ファイル `tests/injection-budget.txt` の変更を聖域扱いとし、動かす PR の本文に理由（何を削ろうとして、なぜ超えるままにするか）を書くことを求める記述を、リポジトリ直下の `CLAUDE.md` に置かなければならない（MUST）。`CLAUDE.md` 自体が測定対象であるため、この記述は 1〜2 文に収めなければならない（MUST）。詳しい手順はテストの失敗メッセージ側に置く。

`AGENTS.md` は `tests/agents-md-sync.bats` が要求する同期を保たなければならない（MUST）。

この記述を `rules/*.md` に置いてはならない（MUST NOT）。`rules/` は全プロジェクトのセッションに注入されるため、このリポジトリ固有の規約をそこに置くと固定分を増やすことになる。

#### Scenario: CLAUDE.md に予算変更の規約がある

- **WHEN** `grep -n 'injection-budget' CLAUDE.md` を実行する
- **THEN** 1 件以上一致し、その行の周辺に「PR 本文に理由を書く」旨が書かれている

#### Scenario: 追記は 1〜2 文に収まっている

- **WHEN** `CLAUDE.md` に足した記述を読む
- **THEN** 文の数が 2 以下である

#### Scenario: AGENTS.md との同期が保たれている

- **WHEN** `scripts/test.sh agents-md-sync` を実行する
- **THEN** exit code が 0 である

#### Scenario: 規約は rules に置かれていない

- **WHEN** `grep -rn 'injection-budget' rules/` を実行する
- **THEN** 一致件数が 0 件である

