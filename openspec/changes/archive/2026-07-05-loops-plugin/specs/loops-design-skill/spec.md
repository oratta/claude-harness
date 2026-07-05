# loops-design-skill Specification (Delta)

## ADDED Requirements

### Requirement: /loops:design は公式選択フレームワークでループ型を選ぶ

`plugins/loops/skills/loops-design/SKILL.md` は、公式の選択フレームワーク「何を手放すか」に沿った対話フローを定義しなければならない (MUST)。すなわち、ユーザーへのインタビューを通じて手放す対象を特定し（検証ステップ → ターンベース / 停止条件 → ゴールベース / トリガー → タイムベース / プロンプト自体 → プロアクティブ）、4 ループタイプのうち 1 つを選定すること。SKILL.md は `references/loop-types.md` を参照すること。

#### Scenario: 選択フレームワークの対応が記載されている

- **WHEN** `plugins/loops/skills/loops-design/SKILL.md` を読む
- **THEN** 「検証ステップ」「停止条件」「トリガー」「プロンプト自体」の 4 つの手放す対象と、ターンベース / ゴールベース / タイムベース / プロアクティブの 4 ループタイプの対応に基づく選定フローが記載されている

#### Scenario: loop-types リファレンスを参照している

- **WHEN** SKILL.md 本文を grep する
- **THEN** `references/loop-types.md` への参照が存在する

### Requirement: 停止基準の無いレシピを出力しない

`/loops:design` は、停止基準（最大試行数・時間・定量ゴールのいずれか 1 つ以上）が確定するまでレシピ定義を出力してはならない (MUST NOT)。ユーザーが停止基準を提示しない場合、スキルは出力を拒否して停止基準のヒアリングを継続すること。この挙動は SKILL.md に出力前の必須チェックとして明記し、テストで確認できるようにすること。

#### Scenario: 停止基準が無い場合は出力を拒否する

- **WHEN** ユーザーが `/loops:design` の対話で停止基準を提示しないままレシピの書き出しを求める
- **THEN** スキルはレシピを出力せず、停止基準（最大試行数 / 時間 / 定量ゴール）の指定を求めるヒアリングを続ける

#### Scenario: SKILL.md に停止基準必須のゲートが明記されている

- **WHEN** `plugins/loops/skills/loops-design/SKILL.md` を grep する
- **THEN** 停止基準が確定しない限りレシピを出力しない旨の必須チェックが記載されている

### Requirement: 出力前に Bad Loop 検査を実施する

`/loops:design` は、レシピ定義の出力前に Bad Loop 検査として以下 4 項目を検査しなければならない (MUST): (1) 停止基準の欠如、(2) 検証なき成功宣告（evidence なしで完了を宣言する設計）、(3) 報酬ハッキング余地（成功基準が主観的・改竄可能）、(4) 過剰な実行頻度。検査に該当した場合は、該当項目と修正案をユーザーに提示してから再設計すること。

#### Scenario: Bad Loop 検査 4 項目が SKILL.md に定義されている

- **WHEN** `plugins/loops/skills/loops-design/SKILL.md` を grep する
- **THEN** 停止基準の欠如・検証なき成功宣告・報酬ハッキング余地・過剰な実行頻度の 4 検査項目がすべて記載されている

#### Scenario: 検査に該当したら修正提示して再設計する

- **WHEN** 設計中のループが Bad Loop 検査のいずれかに該当する
- **THEN** スキルは該当項目と修正案をユーザーに提示し、そのままの出力は行わない

### Requirement: 出力はレシピ形式規約に準拠する

`/loops:design` が書き出すレシピ定義は、レシピ形式規約の固定見出し 7 項目（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）を持たなければならない (MUST)。「起動コマンド」はネイティブプリミティブ（/goal・/loop・/schedule・skill 起動）のコピペ可能な文字列でなければならず、独自 CLI・ラッパースクリプトの新設を提案してはならない (MUST NOT)。

#### Scenario: 出力レシピが 7 見出しを持つ

- **WHEN** `/loops:design` で小さなループを 1 本設計しレシピを書き出す
- **THEN** 出力された `recipes/<name>.md` に固定見出し 7 項目がすべて存在する

#### Scenario: 起動コマンドがネイティブプリミティブである

- **WHEN** 出力されたレシピの「起動コマンド」節を確認する
- **THEN** /goal・/loop・/schedule・skill 起動のいずれかのコピペ可能なコマンド文字列であり、独自 CLI やラッパースクリプトへの言及がない
