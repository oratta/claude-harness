# loops-routine-backlog-triage Specification (Delta)

## ADDED Requirements

### Requirement: backlog 消化ルーチンのレシピが固定見出し規約に従って存在する

`plugins/loops/recipes/routine-backlog-triage.md` が存在しなければならない (MUST)。レシピは change-1 のレシピ形式規約の固定見出し 7 節（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）をすべて含み、ループ型はプロアクティブと明記すること。起動コマンド節はネイティブプリミティブ（/schedule・/goal・/loop・skill 起動）のコピペ可能な文字列のみで構成し、独自 CLI・ラッパースクリプト・常駐 driver を参照してはならない (MUST NOT)。停止基準節には /goal による「このサイクルで選定したタスクが全て Draft PR または凍結記録に到達するまで」の定量的停止基準を含めること。

#### Scenario: レシピファイルが固定見出しを全て持つ

- **WHEN** `plugins/loops/recipes/routine-backlog-triage.md` に対して固定見出し 7 節（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）を grep する
- **THEN** 7 節すべてがヒットし、ループ型節にプロアクティブの記載がある

#### Scenario: 起動コマンドがネイティブプリミティブのみである

- **WHEN** レシピの起動コマンド節を検査する
- **THEN** /schedule・/goal・/loop・skill 起動のいずれかで構成されたコピペ可能なコマンド文字列が存在し、独自スクリプトのパス・独自 CLI 名は現れない

#### Scenario: 停止基準が定量的に宣言されている

- **WHEN** レシピの停止基準節を検査する
- **THEN** 「選定したタスクが全て Draft PR または凍結記録に到達するまで」に相当する /goal 停止基準の記載があり、停止基準節が空でない

### Requirement: レシピは非破壊制約を明記する

レシピは外向きアクションの上限を Draft PR / issue コメントまでと明記しなければならない (MUST)。禁止事項節（エスカレーション節内または独立節）に merge・close・force 系操作の禁止を列挙し、これらが必要になった場合は人間へのエスカレーションに倒すことを記載すること。ルーチンが自律的にマージを実行する手順を含めてはならない (MUST NOT)。

#### Scenario: Draft PR までの非破壊制約が明記されている

- **WHEN** レシピ本文に対して非破壊制約の記載を grep する
- **THEN** 「Draft PR まで」に相当する上限の明記と、merge・close・force 系操作の禁止の列挙が見つかる

#### Scenario: マージは人間へエスカレーションされる

- **WHEN** レシピのエスカレーション節を検査する
- **THEN** マージ等の不可逆操作を人間の判断に委ねる旨が記載されている

### Requirement: レシピは 1 サイクルの処理数上限を明記する

レシピの discovery ステップ（`openspec/backlog.md` と open issues からの着手可能タスク選定）は、1 サイクルで処理するタスク数の上限を具体的な数値で明記しなければならない (MUST)。上限なしの全件処理を許可してはならない (MUST NOT)。

#### Scenario: 処理数上限が数値で記載されている

- **WHEN** レシピの discovery 手順を検査する
- **THEN** 1 サイクルの処理数上限が具体的な数値（例: 最大 2 件）で記載されている

### Requirement: 拾ったが処理しなかったタスクは state に繰り越し記録する

レシピは、discovery で拾ったが当該サイクルで処理しなかったタスクを change-1 の State 規約（`loops/state/<name>.state.md`）に繰り越しとして必ず記録する手順を含まなければならない (MUST)。silent drop（記録なしの見送り）を許可してはならない (MUST NOT)。state 更新は処理済み / 繰り越し / 引き継ぎ待ちの 3 区分をカバーすること。

#### Scenario: 繰り越し記録の手順がある

- **WHEN** レシピの state 更新手順を検査する
- **THEN** 処理しなかったタスクを繰り越しとして state に記録するステップが存在し、silent drop 禁止の旨が明記されている

#### Scenario: state 更新が 3 区分をカバーする

- **WHEN** レシピの state 更新手順を検査する
- **THEN** 処理済み / 繰り越し / 引き継ぎ待ちの 3 区分すべてへの言及がある

### Requirement: 同一タスクの 2 連続失敗は凍結して人間へエスカレーションする

レシピの停止基準は、同一タスクが 2 連続で失敗した場合にそのタスクを凍結（当該サイクル以降の自動リトライ対象から除外）し、人間へエスカレーションすることを含まなければならない (MUST)。無限リトライを許可してはならない (MUST NOT)。

#### Scenario: 2 連続失敗の凍結条件が記載されている

- **WHEN** レシピの停止基準節・エスカレーション節を検査する
- **THEN** 同一タスク 2 連続失敗で凍結 + 人間へエスカレーションする旨の記載がある

### Requirement: 1 サイクルのデモ実行 evidence が残る

backlog 消化ルーチンの 1 サイクルデモをこのリポジトリ（または安全なサンドボックス）で実行し、その実行ログを `{longrun-dir}` に保存しなければならない (MUST)。ログには Draft PR 作成（または安全なサンドボックスでの相当物）・state 更新・繰り越し記録の確認結果を含めること。デモのレシピ規約検査は、未インストールの loops プラグインのスキル起動（`/loops:design`）に依存せず、`plugins/loops/references/` に記載された検査手順（停止基準必須・Bad Loop 検査）を手動実行して evidence に含めること (MUST)。

#### Scenario: デモ実行ログが存在する

- **WHEN** `{longrun-dir}` 配下を検査する
- **THEN** backlog-triage の 1 サイクルデモ実行ログが存在し、Draft PR 作成・state 更新・繰り越し記録の確認結果を含む

#### Scenario: 規約検査はスキル起動に依存せず手動実行される

- **WHEN** デモの evidence を検査する
- **THEN** `/loops:design` の起動記録ではなく、references の検査手順（停止基準必須・Bad Loop 検査）を手動実行した結果（各検査項目の PASS/FAIL）が記録されている
