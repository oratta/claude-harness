# loops-goal-recipes Specification

## Purpose
TBD - created by archiving change goal-time-recipes. Update Purpose after archive.
## Requirements

### Requirement: goal レシピ 3 本が存在し固定見出し規約に準拠する

`plugins/loops/recipes/` 配下に `goal-tests-green.md`・`goal-acceptance-pass.md`・`goal-lighthouse.md` の 3 ファイルが存在しなければならない (MUST)。各ファイルは change-1 のレシピ形式規約に従い、固定見出し（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）の 7 見出しを全て含まなければならない (MUST)。ループ型の節には 4 分類のうち「ゴールベース」であることを明記すること。

#### Scenario: goal レシピ 3 ファイルが存在する

- **WHEN** `plugins/loops/recipes/` を一覧する
- **THEN** `goal-tests-green.md`・`goal-acceptance-pass.md`・`goal-lighthouse.md` の 3 ファイルが全て存在する

#### Scenario: 固定見出しが grep で確認できる

- **WHEN** 各 goal レシピに対して固定見出し 7 種（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）をそれぞれ grep する
- **THEN** 3 ファイル全てで 7 見出し全てがヒットする（欠落 0 件）

#### Scenario: ループ型がゴールベースと明記されている

- **WHEN** 各 goal レシピのループ型の節を grep する
- **THEN** 3 ファイル全てに「ゴールベース」の記載がある

### Requirement: goal レシピの成功基準は機械検証可能でなければならない

goal レシピの停止基準（成功基準）は、必ず検証コマンドと期待値の組で記述しなければならない (MUST)。「良くなったら」「十分に改善したら」のような主観基準を停止基準に用いてはならない (MUST NOT)。具体的には: `goal-tests-green.md` は「`find plugins -name '*.bats' -print0 | xargs -0 bats` が exit 0（全 PASS）」を、`goal-acceptance-pass.md` は「対象 longrun plan.md の受け入れ条件に列挙された機械検証コマンドが全て期待値で PASS」を、`goal-lighthouse.md` は「Lighthouse スコアが閾値（デフォルト 90）以上」を成功基準とすること。

#### Scenario: goal-tests-green の成功基準がコマンドと期待値で書かれている

- **WHEN** `goal-tests-green.md` の停止基準の節を読む
- **THEN** bats 実行コマンド（`find plugins -name '*.bats' -print0 | xargs -0 bats`）と期待値（exit 0 / 全 PASS）が明記されている

#### Scenario: goal-acceptance-pass の成功基準がコマンドと期待値で書かれている

- **WHEN** `goal-acceptance-pass.md` の停止基準の節を読む
- **THEN** 「対象 longrun の plan.md の受け入れ条件に列挙された機械検証コマンドが全て PASS すること」が成功基準として明記され、受け入れ条件の各項目をコマンド + 期待値として読み取る手順が書かれている

#### Scenario: goal-lighthouse の成功基準が公式例準拠のスコア閾値で書かれている

- **WHEN** `goal-lighthouse.md` の停止基準の節を読む
- **THEN** Lighthouse スコアの閾値（デフォルト 90 以上）と測定コマンド（または測定手段）が明記され、公式例（stop after 5 tries 相当の最大試行数）が反映されている

#### Scenario: 主観基準が存在しない

- **WHEN** 3 本の goal レシピの停止基準の節をレビューする
- **THEN** 全ての成功基準がコマンド + 期待値（exit code・PASS 件数・スコア閾値のいずれか）で構成され、「良くなったら」等の主観的表現による基準が 1 件も存在しない

### Requirement: goal レシピは最大試行数を必須とする

各 goal レシピの停止基準には、成功基準の達成に加えて、失敗継続時の打ち切り条件として最大試行数（または時間上限）を必ず含めなければならない (MUST)。最大試行数はデフォルト値を具体的な数値で記載し、利用者が変更する方法（/goal コマンド文字列中の該当箇所）を併記すること。停止基準の無い、または成功基準のみで打ち切り条件の無い goal レシピが存在してはならない (MUST NOT)。

#### Scenario: 各 goal レシピに最大試行数のデフォルト値がある

- **WHEN** 3 本の goal レシピの停止基準の節をそれぞれ読む
- **THEN** 全てのレシピに最大試行数（または時間上限）の具体的なデフォルト値と、その変更方法（起動コマンド中のどこを書き換えるか）が明記されている

#### Scenario: 打ち切り条件の無いレシピが 0 件である

- **WHEN** `plugins/loops/recipes/goal-*.md` の全ファイルについて停止基準の節を検査する
- **THEN** 成功基準のみで打ち切り条件（最大試行数 or 時間上限）を欠くレシピは 0 件である

### Requirement: goal レシピの起動コマンドはネイティブ /goal のみを使う

各 goal レシピの起動コマンドの節は、コピペ可能な `/goal` コマンド文字列 1 行以上を第一級の成果物として含まなければならない (MUST)。起動コマンドに独自 CLI・ラッパースクリプト・常駐 driver を用いてはならない (MUST NOT)。レシピ本文にモデル ID（`claude-` で始まる具体的なモデル識別子）を記載してはならない (MUST NOT)。

#### Scenario: 起動コマンドがコピペ可能な /goal 文字列である

- **WHEN** 各 goal レシピの起動コマンドの節を読む
- **THEN** 3 ファイル全てに `/goal` で始まるコピペ可能なコマンド文字列が含まれており、成功基準（コマンド + 期待値）と最大試行数がそのコマンド文字列内に埋め込まれている

#### Scenario: 独自ランタイム・モデル ID への参照が無い

- **WHEN** `plugins/loops/recipes/goal-*.md` に対して独自スクリプト起動（例: `bash .*loop.*\.sh`）と `claude-` で始まるモデル ID を grep する
- **THEN** いずれも 0 件である
