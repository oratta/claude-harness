# casting-injection-map Specification

## Purpose
TBD - created by archiving change casting-injection-map. Update Purpose after archive.
## Requirements
### Requirement: 注入マップ正本の存在と構成

`plugins/casting/catalog/injection.md` は観点の注入設計（14観点それぞれの注入タイミング・配線先機構・注入文書と置き場所）の唯一の正本として存在しなければならない (MUST)。front matter に `catalog_version`（catalog.md の `version` と一致する整数）を持ち、本文に①注入タイミングの語彙定義（9分類: 常時／毎ターンの配役判定／論点相談／PR 時レンズ／アクション直前ゲート／定期監査／注入しない／起票・選定時／設計時）②catalog.md の14観点すべてを行に持つ注入マップ表③注入文書の置き場所規約④実装済み配線の実在パス一覧⑤未実装配線の実装 issue への参照、の5節を含まなければならない (MUST)。カタログ本文（判定条件・担い手）を複製してはならない (MUST NOT)。

#### Scenario: 注入マップに catalog_version と14観点が入っている

- **WHEN** `plugins/casting/catalog/injection.md` を読む
- **THEN** front matter の `catalog_version` が catalog.md の `version` と一致し、注入マップ表に catalog.md の14観点すべてが行として存在する

#### Scenario: タイミング語彙の9分類が定義されている

- **WHEN** injection.md の語彙定義節を読む
- **THEN** 9分類すべての名前と意味、対応する実装機構が定義されている

### Requirement: 注入マップ行のタイミング語彙の固定

注入マップ表の各観点行の「注入タイミング」は、injection.md 自身が定義する9分類の語彙のみを使わなければならない (MUST)。定義されていないタイミング名を使う場合は、先に語彙定義節へ追加しなければならない (MUST)。

#### Scenario: 全行のタイミングが定義済み語彙に収まる

- **WHEN** 注入マップ表の全14行のタイミング欄を語彙定義と突き合わせる
- **THEN** 定義外のタイミング名が1つも使われていない

### Requirement: 注入文書の置き場所規約

injection.md は、観点の移譲に必要な注入文書（予算方針文・ブランド許容基準・フェーズ宣言文・優先基準文・許容工数宣言・業種固有規制メモ）の置き場所を `<repo>/.claude/casting/policies/<slug>.md` に定め、観点と slug の対応表を持たなければならない (MUST)。既存の別置き文書がある repo では policies/ からの参照 stub を許容することを明記しなければならない (MUST)。

#### Scenario: policies 規約と slug 対応表がある

- **WHEN** injection.md の置き場所規約節を読む
- **THEN** `.claude/casting/policies/` のパス規約と、注入文書を持つ全観点の slug 対応表が読み取れる

### Requirement: 注入のサブエージェント限定と人格規約

injection.md は「注入文書はメインセッションに読み込まない（観点の文書を読むのはその観点を担う専任サブエージェントだけ）」という大原則を明記しなければならない (MUST)。あわせて人格規約 — 各 policy 文書が判断基準に加えて人格ブロック（スペシャリストの名前・スタンス・口調）を持ち、観点スペシャリストがそれを纏い、仲裁報告と判例台帳が人格名で発言を帰属すること、人格は判断基準の代替ではないこと — を明記しなければならない (MUST)。論点相談タイミングの意味には、仲裁エージェントが新品コンテキスト（フェーズ宣言文と双方の主張のみ）で裁定し主へは事後報告とすることを含めなければならない (MUST)。

#### Scenario: 大原則と人格規約が読み取れる

- **WHEN** injection.md を読む
- **THEN** 注入文書をメインセッションに読み込まない原則、人格ブロックの規約、仲裁の事後報告方式が読み取れる

### Requirement: SKILL.md からの参照

`plugins/casting/skills/casting/SKILL.md` は injection.md を注入設計の正本として参照しなければならない (MUST)。注入マップの内容を SKILL.md に複製してはならない (MUST NOT)。

#### Scenario: SKILL.md にポインタがある

- **WHEN** SKILL.md を読む
- **THEN** `catalog/injection.md` への参照が存在し、14観点の注入マップ表そのものは含まれない

### Requirement: カタログとの整合検査

`plugins/casting/tests/` の bats テストは、injection.md について次を検査しなければならない (MUST): ①front matter `catalog_version` が catalog.md の `version` と一致する ②catalog.md の14観点すべてが注入マップ表の行に存在する ③注入マップ行のタイミング欄が定義済み語彙のみを使う ④5節（語彙定義・注入マップ・置き場所規約・実装済み配線・未実装配線）が存在する。日本語語彙の照合に awk のマルチバイト文字列比較を使ってはならない (MUST NOT)。

#### Scenario: カタログ改版時のドリフトが検出される

- **WHEN** catalog.md の `version` だけを上げて injection.md を据え置いた状態でテストを実行する
- **THEN** catalog_version 不一致が検出されテストが fail する

