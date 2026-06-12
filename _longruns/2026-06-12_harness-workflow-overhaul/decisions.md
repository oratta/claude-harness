# Decisions — harness 大型改修 run

全 change の設計判断を集約する。各判断にはエビデンス（実行コマンドと出力）を必須とする。

## Setup フェーズ

### D-S1: openspec のバージョン乖離を発見、change-1 実機検証の検証対象に追加

- **日時**: 2026-06-12 11:09
- **エビデンス**:
  ```
  $ which openspec
  /Users/oratta/.volta/bin/openspec
  $ openspec --version
  1.2.0
  $ npx --no-install openspec --version
  0.23.0
  ```
- **判断**: volta グローバル（1.2.0）と npx 解決（0.23.0）が別物。plan.md の change-1 は `npx openspec` を前提条件チェックの対象としているため、実機検証タスクで「どちらを正とするか + バージョン差による挙動差」を確定する。Setup 時点ではどちらも動くため進行に支障なし。

### D-S2: ベースライン 3 スイート全 PASS を確認してから開始

- **日時**: 2026-06-12 11:11
- **エビデンス**: e2s 24 ok / daily-report 48 ok / harvest 313 ok（checkpoint.md 参照）
- **判断**: 回帰判定の基準線として記録。plan.md の「既存 bats スイートを壊さない」（change-5 config rules）の比較対象は harvest 313 本。
