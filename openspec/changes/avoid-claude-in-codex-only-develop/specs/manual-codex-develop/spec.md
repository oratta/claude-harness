## MODIFIED Requirements

### Requirement: 品質工程を維持する
工程管理は develop の正本を使用し、W/R1/G/追加レビュアー/decider の各役割を解決済み executor へ委譲しなければならない（MUST）。executor が Claude でも Codex でも、レビューは作業者と別 thread かつ read-only でなければならない（MUST）。一時書き込みが必要で読み取り役では完了できないレビューは、要件「Claude を使わない構成では例外 4 役を起動せず主への確認に回す」に従い、未実行を合格扱いしてはならない（MUST NOT）。

#### Scenario: 仕様に差し戻し
- **WHEN** 独立仕様レビューが修正を要求する
- **THEN** 本体が正本の回数上限を確認し、profile の spec-write executor へ修正を委譲する

#### Scenario: 独立レビューへ到達する
- **WHEN** G が別レビューを要求し、読み取り役で実行できる
- **THEN** 本体は profile の impl-review executor で新しい read-only thread を作り、Claude と Codex のどちらを選んでも同じレビュー契約を適用する

## ADDED Requirements

### Requirement: 例外 4 役も共通 resolver を通す
本体は、一時領域への書き込みが必要なテスト再実行レビュー、画面確認 V、引き継ぎ判定、論点なし確認のいずれも、起動前に `codex-develop.py request` を通さなければならない（MUST）。開始時の実行先指定と account-home を保持し、依頼の種類を識別できなければならない（MUST）。本体は resolver が返す起動不可を無視して Claude を直接起動してはならない（MUST NOT）。

#### Scenario: 4 例外の各呼び出し元が resolver の結果に従う
- **WHEN** 本体が 4 例外のいずれかを要求する
- **THEN** その依頼と同じ実行先指定を request に渡し、起動不可なら役を起動せず理由を記録する。Claude を使える構成・環境での既存の確認内容と、depleted 時の判定役を起こさない条件は維持する

### Requirement: Claude を使わない構成では例外 4 役を起動せず主への確認に回す
`codex-standard` を含む Claude を使わない構成では、resolver は例外 4 役に起動不可と役ごとの理由を返し、実行可能な依頼ファイルを作ってはならない（MUST NOT）。本体は Claude も代替の Codex 役も起動せず、既存の主への確認・保留経路に接続しなければならない（MUST）。未実行を品質合格と扱ってはならない（MUST NOT）。

#### Scenario: 一時領域が必要なレビュー
- **WHEN** codex-standard で、一時領域への書き込みを必要とするテストの独立再実行が要求される
- **THEN** reviewer を起動せず、レビュー未完了と理由を記録して主の確認待ちとする。CI・W の実行で代用せず、合格処理に進まない

#### Scenario: 画面確認が必要
- **WHEN** codex-standard で W が画面確認を必要とする
- **THEN** V を起動せず、実行不能の理由を次の W に渡し、画面証拠を作らず既存のゲートの保留経路へ進む

#### Scenario: 引き継ぎ判定または論点なし確認が必要
- **WHEN** codex-standard で needs-carryover-judge または needs-no-point-check を受ける
- **THEN** 判定役を起動せず、本体が既存書式の「引き継ぎ判定: 判断できない」または「論点なしの確認: 判断できない」と起動しなかった理由を投稿する。その URL を渡して合格処理の G を新しく起こし、主への確認は G の既存手順に従う

#### Scenario: 書き込み不要な通常レビュー
- **WHEN** codex-standard で一時領域への書き込みを必要としない通常レビューを依頼する
- **THEN** 既存の独立した Codex 読み取り役へ委譲し、例外の起動不可を適用しない
