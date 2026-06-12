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

## Build Contract フェーズ

### D-BC1: longrun-reviewer 判定 APPROVE、指摘 3 件を全て採用（バイアス緩和ガード判定込み）

- **日時**: 2026-06-12 11:17
- **エビデンス**: longrun-reviewer Agent (a0db2a4dc44e611c5) のレビュー結果。BLOCKER 0 / SHOULD_FIX 2 / NOTE 1
- **指摘ごとの (a)採用 / (b)反論 判定**:
  - **指摘1（採用 (a)・契約の穴）**: 受け入れ条件11の grep 対象に `.claude-plugin/marketplace.json` が漏れていた。実機確認で marketplace.json L40 の lr description に `/lr:s, /lr:d` 文字列が現存 → grep 対象に追加修正
  - **指摘2（採用 (a)・事実誤認）**: 「実測約230本」は bats **ファイル数**で、実 `@test` 数は 313。母数の混在は回帰見逃しリスク → plan.md の 3 箇所を 313 本基準に統一
  - **指摘3（採用 (a)・事実誤認）**: `templates/plan-template.md` の実パスは `plugins/longrun/templates/plan-template.md`。リポジトリ直下 `templates/` には rules/ しかない → フルパスに修正
  - 嗜好レベルの指摘（(b) 反論対象）は今回なし。3 件とも事実ベースのため全採用は過剰受容バイアスに該当しない
- **補足メモ（builder への引き継ぎ）**: reviewer の実機確認によると `plugins/lr/commands/e.md` は既に exec.md への単純委譲形であり「インライン展開ハック」は exec.md 側（SKILL.md を読んでインライン実行する構造）に存在する。change-2 では e.md の微修正 + exec.md の全面書き換えが実体。re-review は不要（APPROVE 済みのため 2 ラウンド目はスキップ）。
