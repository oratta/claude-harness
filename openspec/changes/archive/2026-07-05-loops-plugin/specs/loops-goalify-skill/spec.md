# loops-goalify-skill Specification (Delta)

## ADDED Requirements

### Requirement: /loops:goalify は brain dump を入力に取る

`plugins/loops/skills/loops-goalify/SKILL.md` は、`/loops:goalify <テキスト|ファイルパス>` として起動し、引数のインラインテキストまたはファイルパスの内容を brain dump（やりたいことの書き出し）として読み込むフローを定義しなければならない (MUST)。

#### Scenario: インラインテキストを受け付ける

- **WHEN** ユーザーが `/loops:goalify` にやりたいことのテキストを直接渡して起動する
- **THEN** スキルはそのテキストを brain dump として解析を開始する

#### Scenario: ファイルパスを受け付ける

- **WHEN** ユーザーが `/loops:goalify` に既存ファイルのパスを渡して起動する
- **THEN** スキルはそのファイルの内容を brain dump として解析を開始する

### Requirement: 不足している情報だけをヒアリングする

`/loops:goalify` は、brain dump を 4 観点 — (1) 成功基準の機械検証可能化（コマンド + 期待値への変換）、(2) 停止条件（最大試行数 / 時間）、(3) スコープ境界（触ってよい範囲 / やらないこと）、(4) 前提（参照パス・環境）— で分析し、**不足しているものだけ**を AskUserQuestion でヒアリングしなければならない (MUST)。brain dump に既に書かれている項目について質問してはならない (MUST NOT)。ヒアリング方法論は `plugins/longrun/references/plan-interview-methodology.md` を参照流用すること。

#### Scenario: 不足観点のみ質問される

- **WHEN** 成功基準と前提は書かれているが停止条件とスコープ境界が無い brain dump を与えて `/loops:goalify` を実行する
- **THEN** 停止条件とスコープ境界についてのみ質問され、成功基準・前提についての質問は行われない

#### Scenario: 全情報が揃っていればヒアリングは 0 問

- **WHEN** 4 観点すべてが書かれている brain dump を与えて `/loops:goalify` を実行する
- **THEN** AskUserQuestion による質問は 0 問で、そのまま生成に進む

### Requirement: goal ブリーフと /goal 起動コマンドを生成する

`/loops:goalify` は、`goals/<name>.goal.md` と、それを参照する /goal 起動コマンド 1 行を生成しなければならない (MUST)。goal ブリーフは「目的」「成功基準」「制約」「参照パス」「エスカレーション条件」の見出しを持ち、「成功基準」の各項目は機械検証可能な形式（実行コマンド + 期待値）で書かれていること。「良くなったら」等の主観的基準を成功基準に含めてはならない (MUST NOT)。

#### Scenario: goal ブリーフが生成される

- **WHEN** `/loops:goalify` が生成を完了する
- **THEN** `goals/<name>.goal.md` が作成され、「目的」「成功基準」「制約」「参照パス」「エスカレーション条件」の見出しをすべて持つ

#### Scenario: 成功基準がすべて機械検証可能である

- **WHEN** 生成された `goals/<name>.goal.md` の「成功基準」節を確認する
- **THEN** 各項目が実行コマンドと期待値（exit code・出力・ファイル実在等）の組で書かれており、主観的基準が含まれない

#### Scenario: /goal 起動コマンド 1 行が提示される

- **WHEN** `/loops:goalify` が生成を完了する
- **THEN** 生成した goal ブリーフを参照するコピペ可能な /goal 起動コマンドが 1 行で出力に含まれる

### Requirement: 反復利用が見えたらレシピ昇格を促す

`/loops:goalify` の出力は、生成物が使い捨ての goal ブリーフであることを前提としつつ、反復利用が見込まれる場合にレシピ（`recipes/<name>.md`）への昇格を促す案内を 1 行含まなければならない (MUST)。

#### Scenario: レシピ昇格の案内が出力に含まれる

- **WHEN** `/loops:goalify` が生成を完了する
- **THEN** 出力に「反復利用するならレシピへ昇格する」旨の案内が 1 行含まれる
