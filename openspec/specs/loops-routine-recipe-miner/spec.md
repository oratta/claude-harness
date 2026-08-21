# loops-routine-recipe-miner Specification

## Purpose
TBD - created by archiving change proactive-routines. Update Purpose after archive.
## Requirements

### Requirement: レシピ採掘ルーチンのレシピが固定見出し規約に従って存在する

`plugins/loops/recipes/routine-recipe-miner.md` が存在しなければならない (MUST)。レシピは change-1 のレシピ形式規約の固定見出し 7 節（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）をすべて含み、ループ型はプロアクティブ（メタループ）と明記すること。起動コマンド節はネイティブプリミティブのみで構成し、レシピが宣言するのは発火時に投入するプロンプト・推奨頻度（週 1 想定）・停止基準・実行環境の制約までとすること。スケジューラへの登録手順・セッション運用・課金選択を含めてはならない (MUST NOT)。

#### Scenario: レシピファイルが固定見出しを全て持つ

- **WHEN** `plugins/loops/recipes/routine-recipe-miner.md` に対して固定見出し 7 節を grep する
- **THEN** 7 節すべてがヒットし、ループ型節にプロアクティブの記載がある

#### Scenario: 定期実行の配線はスコープ外である

- **WHEN** レシピ本文を検査する
- **THEN** 発火時プロンプト・推奨頻度・停止基準・実行環境の制約は記載されているが、スケジューラ登録手順（cron 設定・launchd・`claude -p` 配線）は記載されていない

### Requirement: ローカル実行必須の制約と登録責務の分離を明記する

レシピは、`~/.claude/projects/` 配下のセッション jsonl を読むためローカル実行が必須である旨の制約を明記しなければならない (MUST)。あわせて、定期実行への登録・実行方法の選択は呼び出し側の責務でありレシピのスコープ外であることを明記すること (MUST)。

#### Scenario: ローカル実行必須の制約が明記されている

- **WHEN** レシピの前提節または実行環境の制約の記載を検査する
- **THEN** セッション jsonl（`~/.claude/projects/`）を読むためローカル実行が必須である旨の記載がある

#### Scenario: 実行登録が呼び出し側の責務であることが明記されている

- **WHEN** レシピ本文を検査する
- **THEN** 定期実行への登録・実行方法は呼び出し側の責務でスコープ外である旨の記載がある

### Requirement: ログ解析はサブエージェントに隔離する

レシピの discovery 手順は、直近 7 日のセッション jsonl の解析をサブエージェントに隔離して実行し（daily-report の llm-log-compactor の jq パターンを流用した圧縮解析）、抽出結果（候補リスト）のみをメインセッションに返すことを定めなければならない (MUST)。生ログをメインセッションのコンテキストに載せてはならない (MUST NOT)。抽出対象は (a) 同型依頼の 3 回以上の反復 = ループ化候補、(b) 修正→テスト→修正の長い往復 = /goal 化候補、(c) 定時性のある依頼 = /schedule 化候補、(d) 既存レシピの実行痕跡 = 停止基準・頻度の実測チューニング候補、の 4 種とする。

#### Scenario: サブエージェント隔離が明記されている

- **WHEN** レシピの discovery 手順を検査する
- **THEN** jsonl 解析をサブエージェントで実行し候補リストのみをメインに返す旨と、生ログをメインに載せない旨の記載がある

#### Scenario: 4 種の抽出候補が定義されている

- **WHEN** レシピの discovery 手順を検査する
- **THEN** ループ化候補・/goal 化候補・/schedule 化候補・実測チューニング候補の 4 種の抽出基準が記載されている

### Requirement: 1 サイクルの提案は最大 3 件とし規約検査を通す

レシピの生成手順は、1 サイクルで提案するレシピ新規案 / 更新 diff を最大 3 件に制限しなければならない (MUST)。各提案は停止基準必須・Bad Loop 検査（停止基準の欠如 / 検証なき成功宣告 / 報酬ハッキング余地 / 過剰な実行頻度）の規約検査を必ず通し、検査を通らない提案は Draft PR に含めず見送りとして state に理由つきで記録すること (MUST)。

#### Scenario: 提案上限 3 件が明記されている

- **WHEN** レシピの生成手順を検査する
- **THEN** 1 サイクル最大 3 件の提案上限が記載されている

#### Scenario: 検査を通らない提案は見送り記録される

- **WHEN** レシピの生成手順を検査する
- **THEN** 停止基準必須・Bad Loop 検査を通らない提案は Draft PR に含めず、見送り理由を state に記録する旨が記載されている

### Requirement: 出力は Draft PR までとし自動 merge を禁止する

レシピの出力手順は、提案をこの marketplace リポジトリへの Draft PR として出力することを定めなければならない (MUST)。自動 merge を禁止し、レシピの採否は人間が判断することを明記すること (MUST)。merge・close・force 系操作を実行する手順を含めてはならない (MUST NOT)。

#### Scenario: Draft PR 出力と自動 merge 禁止が明記されている

- **WHEN** レシピの出力手順を検査する
- **THEN** Draft PR として出力する旨・自動 merge 禁止・採否は人間が判断する旨の記載がある

### Requirement: state に提案済み・見送り・繰り越しを記録し候補ゼロは正常終了する

レシピの persistence 手順は、change-1 の State 規約に従い、提案済み / 見送り理由 / 繰り越し候補を state に記録することを定めなければならない (MUST)。discovery で拾ったが処理しなかった候補の silent drop を許可してはならない (MUST NOT)。候補がゼロのサイクルは「提案なし」として正常終了すること (MUST)。

#### Scenario: state 記録の 3 区分が定義されている

- **WHEN** レシピの persistence 手順を検査する
- **THEN** 提案済み / 見送り理由 / 繰り越し候補の 3 区分を state に記録する旨の記載がある

#### Scenario: 候補ゼロで正常終了する

- **WHEN** レシピの手順を検査する
- **THEN** 候補ゼロのサイクルは「提案なし」で正常終了する旨の記載がある

### Requirement: 実ログに対する手動 1 サイクルデモの evidence が残る

直近の実セッションログに対して recipe-miner の 1 サイクルを手動起動で実行し、提案（Draft PR）または「提案なし」の正常終了と、state 更新・繰り越し記録を確認したデモログを `{longrun-dir}` に保存しなければならない (MUST)。定期実行への登録は行わないこと (MUST NOT)。デモ内の提案レシピの規約検査は `/loops:design` の起動に依存せず、`plugins/loops/references/` の検査手順（停止基準必須・Bad Loop 検査）を手動実行して各検査項目の結果を evidence に含めること (MUST)。

#### Scenario: 手動 1 サイクルデモのログが存在する

- **WHEN** `{longrun-dir}` 配下を検査する
- **THEN** 実ログに対する手動 1 サイクルデモの実行ログが存在し、提案 Draft PR（または「提案なし」の正常終了）と state 更新・繰り越し記録が確認できる

#### Scenario: デモで定期実行への登録を行わない

- **WHEN** デモの evidence を検査する
- **THEN** スケジューラ登録・cron 設定の実行記録が含まれていない（手動起動のみ）

#### Scenario: 規約検査はスキル起動に依存せず手動実行される

- **WHEN** デモの evidence を検査する
- **THEN** references の検査手順（停止基準必須・Bad Loop 検査）を手動実行した結果（各検査項目の PASS/FAIL）が記録されている
