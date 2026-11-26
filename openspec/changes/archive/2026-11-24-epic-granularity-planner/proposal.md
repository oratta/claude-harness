# Proposal

## Why

エピックの子を capability・受け入れ条件数・ファイル数だけで細かく割ると、子ごとの仕様化・レビュー・ゲートの手間を繰り返す。#1799 の確定結果を使い、関係の近さ・消費の上限・現在の W 空き枠から、まとめられる作業をまとめる。

## What Changes

- 作業項目、読む／直すファイルのトークン量、capability、依存、repo、聖域、承認待ち、変更行数などを渡す JSON と、決定的な粒度計算 CLI を追加する。
- 関係の近い項目からまとめ、文脈と記録先累計の見積もりに余裕がある子を提案する。別 repo・聖域の有無・承認待ちを境界とし、空き W 枠がある場合だけ独立項目の並列案を評価する。
- Step C と規模超過を「個数で分割」から「入力を更新して計算」に変える。epic 作成では計算結果に従い、逸脱の理由を記録する。
- 既存 issue も同じ入力へ展開し、まとまった分には代表の子 issue を 1 本設ける。元 issue は対応表で追跡し、親は代表の子を単位に進捗を数える。
- 過去のエピック 2 件以上について、固定した入力と CLI 出力、元の子数との比較、上限との差を再現可能な形で残す。

## Capabilities

### New Capabilities

- `epic-granularity`: 作業項目の入力検査、消費見積もり、子の梱包、W 枠を考慮した並列候補とその説明。

### Modified Capabilities

- `dev-workflow-develop`: 分割判断とエピック作成への計算の組込み、既存 issue の集約と親の完了判定。
- `dev-workflow-escalation-tripwires`: 規模超過を固定ファイル数から消費の再見積もりへ変更。

## Impact

対象は `plugins/dev-workflow/scripts/` の新規 Python CLI、出典付き係数設定、必要時だけ読む develop reference、対応するテスト・比較記録。既存の子 issue 単位の dispatch/state を利用し、元 issue を別々に起動しない。

#1802 の受け入れ条件 1〜8 を単一 change・1 PR で扱う（本体判断: https://github.com/oratta/claude-harness/issues/1802#issuecomment-7120407801 ）。計算スクリプトと手順への組込みは別 Requirement として検証する。上限値の変更、#1800 のモデル別しきい値、CLAUDE.md・hooks・権限設定・`tests/injection-budget.txt` の編集、#1799 の再測定は対象外。
