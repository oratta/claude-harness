# loops-integration-verification Specification

## Purpose
TBD - created by archiving change loops-integration. Update Purpose after archive.
## Requirements

### Requirement: 統合検証を bats テストとして実装する

本 change は、run 全体の機械検証可能な受け入れ条件を横断的に再検証する統合テストを `plugins/loops/tests/integration.bats` として実装しなければならない (MUST)。統合テストは grep / jq / find のみで構成し、独自の検証ランタイムやラッパー CLI を導入してはならない (MUST NOT)。統合テストは少なくとも以下を検証すること: (a) marketplace.json ↔ 各 plugin.json の version 完全一致、(b) 全レシピの固定見出し規約、(c) plugins/loops/ に独自ランタイムが存在しないこと、(d) README の loops セクションの存在。

#### Scenario: 統合テストが存在し全 PASS する

- **WHEN** ユーザーが `bats plugins/loops/tests/integration.bats` を実行する
- **THEN** 全テストケースが PASS し exit 0 で終了する

#### Scenario: リポジトリ全体の bats スイートが PASS する

- **WHEN** ユーザーが `find plugins -name '*.bats' -print0 | xargs -0 bats` を実行する
- **THEN** 全テストが PASS し exit 0 で終了する

### Requirement: 全レシピが固定見出し規約を満たし停止基準欠落が 0 件である

統合検証は、`plugins/loops/recipes/` 配下の全レシピ（`*.md`）が change-1 で定義された固定見出し（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）を持つことを grep で確認しなければならない (MUST)。「停止基準」見出しを欠くレシピは 0 件でなければならない (MUST)。

#### Scenario: 固定見出しの横断 grep 検証が PASS する

- **WHEN** ユーザーが `plugins/loops/recipes/*.md` の各ファイルに対して 7 つの固定見出しの存在を grep で確認するループを実行する
- **THEN** 全レシピで 7 見出しすべてがヒットし、欠落は 0 件である

#### Scenario: 停止基準の無いレシピが存在しない

- **WHEN** ユーザーが `grep -L '停止基準' plugins/loops/recipes/*.md` を実行する
- **THEN** 出力は空である（停止基準見出しを持たないレシピが 0 件）

### Requirement: plugins/loops/ に独自ランタイムが存在せず起動コマンドが全てネイティブである

統合検証は、`plugins/loops/` 配下にループを回す常駐スクリプト・カスタム driver（反復実行やスケジューリングを自前実装するスクリプト）が存在しないことを確認しなければならない (MUST)。また、全レシピの「起動コマンド」節に記載されたコマンドがネイティブプリミティブ（`/goal`・`/loop`・`/schedule`・skill/スラッシュコマンド起動）のいずれかであることを確認すること (MUST)。

#### Scenario: 常駐スクリプト・driver が存在しない

- **WHEN** ユーザーが `plugins/loops/` 配下のスクリプトファイルを `find` で列挙し、反復実行・スケジューリングの自前実装（例: `while true`・sleep ループによる常駐処理）を grep で検査する
- **THEN** 該当するスクリプトは 0 件である

#### Scenario: 起動コマンドが全てネイティブプリミティブである

- **WHEN** ユーザーが全レシピの「起動コマンド」節からコマンド行を抽出する
- **THEN** すべての行が `/goal`・`/loop`・`/schedule` またはスラッシュコマンド（skill）起動のいずれかで始まり、独自 CLI やラッパースクリプトの呼び出しが 0 件である

### Requirement: 統合検証の実行エビデンスを記録する

統合検証の実行結果（bats 出力・grep/jq 検証の exit code）は、完了宣言の前にエビデンスとして `{longrun-dir}` 配下に記録しなければならない (MUST)。「完了は主張であり証明ではない」原則に従い、エビデンスなしに受け入れ条件を PASS と報告してはならない (MUST NOT)。

#### Scenario: エビデンスログが残っている

- **WHEN** ユーザーが `{longrun-dir}` 配下の統合検証ログを開く
- **THEN** 全 bats 実行の出力（PASS 件数と exit 0）および version 一致・レシピ規約・ランタイム不在の各検証コマンドの実行結果が確認できる
