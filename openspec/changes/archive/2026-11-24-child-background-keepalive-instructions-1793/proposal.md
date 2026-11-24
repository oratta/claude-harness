# Proposal

## Why

#1792（PR #1794）で作業待ち用の予約文とログ・状態フックの受信基盤は入ったが、子が読む手順は停止済み子だけを扱っている。#1793 で受信手順を接続し、声かけを通常入力や作業完了と取り違えて元作業・実行 ID・自己タイマーを失うことを防ぐ。

## What Changes

- `epic-keepalive.md` を両種類の受信契約の正本とし、作業待ち前にも共通 JSON の `background` を読み込む。
- `child-background-wait.md` に受信契約への参照と作業待ちでの分岐を置く。完全一致する予約文には共有定義どおりの一行だけを返してターンを終え、元作業・実行 ID・自己タイマーと最初のタイマー設置時刻を保持する。
- 予約文の受信は通常入力時のタイマー取消・再判定から除外する。本当の入力と元作業の完了通知は既存手順へ渡す。
- `child-background-wait.bats` に両手順の接続・予約文の先行分類・保持する対象・旧停止手順の非退行を確認する契約テストを加える。
- 親の送信を有効にせず、自己タイマーも撤去しない。これらは #1777 の範囲。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 共有定義の事前読み込みと子の受信契約を、停止前・停止中から作業待ち前・作業待ち中へ拡張する。

## Impact

実装対象は `plugins/dev-workflow/skills/develop/references/epic-keepalive.md`、同 `child-background-wait.md`、`plugins/dev-workflow/tests/child-background-wait.bats`。変更記録は `plugins/dev-workflow/changes/1793.md` に残す。共有 JSON・ログ読取・状態フック・親の送信処理・CLI は変更しない。

既存 `dev-workflow-child-background-wait` の自己通知・12時間上限・本当の入力と完了通知の優先・取消契約は維持する。追加する予約文の分類は既存の声かけ capability に集約し、自己通知の要件は書き換えない。

## 分割判定（Step C）

単一 change。issue の2つの受け入れ条件は「子の予約文受信手順の接続と既存経路の非退行」という一つの機能領域に閉じる。受信基盤は #1792 で確定・マージ済み、送信有効化は #1777 に分離済みで、新たな独立した設計判断や順序依存する別機能は加えない。
