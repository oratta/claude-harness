# Proposal

## Why

PR #1749 で送信前の古い待機履歴の解除を厳密にした結果、送信後に完了行の後へ送信文のエコーが加わると、届いた声かけでも `failed send` と記録する。#1752（親 #1732）の到達確認を進めるため、送信前の安全条件を保ちつつ、履歴の待機解除と送信後の到達確認の責務を分ける。

## What Changes

- 送信前の二度の観測では、既存の待機解除・空欄・dialog・入力枠の規則を維持する。
- `send` が exit 0 で `turn_started` を返さない場合、送信後の一度の再観測では履歴の待機解除結果を到達判定に流用しない。新しい前景実行と、一意な既知入力枠全体・任意 draft の空欄を独立して確認する。
- 古い待機→完了→送信文エコー＋前景実行＋空欄の回帰 fixture と、背景待機だけ・入力済み・未知枠・dialog の拒否テストを追加する。再送・入力消去は行わない。
- マージ後の実機確認で、背景エージェント待機中の子を対象にせず、会話15万トークン未満で前景が入力待ちの子を選び、候補が無ければ未完了とする手順を残す。実機 send / 返事 / cache 利用は fixture 成功と分け、#1728 と #1732 に記録する。
- 非bypass の未知フッター（P2-F2）は実画面未確認のため対応を拡張しない。将来の対応には実測と匿名化 fixture を必要とする。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-epic-state`: Orca keepalive の送信前待機解除と送信後到達確認の分離、未観測画面の扱い、および実機確認手順。

## Impact

- 実装予定: `plugins/dev-workflow/scripts/epic-launch-orca.sh`、`plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/skills/develop/references/epic-keepalive-watch.md`、変更記録 `plugins/dev-workflow/changes/1752.md`。
- 既存の `list` / `read` / 一度の `send`、stdout の結果語・exit code、dispatch の記録形式、tmux の動作、閾値は維持する。新規依存・データ移行は無い。
- 単一 change: 一つの機能領域・一つの責務分離の設計判断としてまとめる。Draft PR は依頼どおり工程 (3b) で作る。
- 本 artifact の案は独立仕様レビューで確定する。仕様段では実装・実機送信・実機成功の宣言を行わない。
