# Codex手動委譲worker

## Why
親の待機終了でCodex依頼や結果を失わず、登録アカウントで手動開発を始める共通入口が必要。

## What Changes
- App Serverへ接続するdetached workerとprivate SQLite台帳。
- register / submit / status / result / send / cancel / ack のJSON CLI。
- 冪等request ID、cwd排他、明示model、アカウントprofile固定、unknownの再投入禁止。

## Impact
Refs genetta-inc/flatmate#706。品質工程は#707、バーンの予算判定は#708以降。初版はmanualのみ、burnと実行中steerはunsupportedと明示する。既存companionは内部App Serverだが、account/cwd排他・unknown台帳契約を未確認のため直接transportを小さく実装。#705の接続実証を根拠とし、本番全要件完了とはしない。
