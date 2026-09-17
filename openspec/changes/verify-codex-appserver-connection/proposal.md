# Codex App Server接続の小規模検証

## Why
既存のCodex CLI委譲で途中停止が報告されている。App Server常駐化だけで解決したと判断せず、停止箇所を分類し、手動・バーン共通実行基盤に進める接続契約を検証する。

## What Changes
- 既存CLI経路とタイムアウト境界の調査。
- App Serverによる一件の受付・進捗・結果取得・中断の検証仕様。
- CLIとの差、未解決の制約、後続への引継ぎ。

## Impact
管理issue: genetta-inc/flatmate#705。実装所有repo: oratta/claude-harness。
本PRは仕様レビュー用Draft。実装・モデル呼び出し・本番設定変更は未着手。
#706の本番worker、#707の開発品質ワークフロー、#708のバーン統合は対象外。既存CLI経路を今このPRで置換しない。App Server失敗時の暗黙のexec fallbackは導入しない。
