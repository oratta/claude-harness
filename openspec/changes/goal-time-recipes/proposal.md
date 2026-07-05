# Proposal: goal-time-recipes

## Why

公式記事「Getting started with loops」はゴールベースループについて「定量的な基準（テスト合格数・スコア閾値）が最も効果的」、タイムベースループについて「/loop はローカル・/schedule はクラウド」と定義しているが、現状このハーネスにはユーザーの定常業務（テスト緑化・longrun 完了ゲート・PR 面倒見・日次/週次レポート）をこれらのネイティブプリミティブに落としたコピペ可能なレシピが 1 本も存在しない。change-1 (loops-plugin) がレシピ形式の規約（固定見出し）と置き場所 `plugins/loops/recipes/` を整備するため、その規約に準拠した初期シード 6 本を今整備する。

## What Changes

- **goal レシピ 3 本**を `plugins/loops/recipes/` に新設する。全て定量的成功基準（コマンド + 期待値）と最大試行数を必須とする:
  - `goal-tests-green.md`: 「全 bats PASS まで、最大 N 回」（このリポジトリの開発用）
  - `goal-acceptance-pass.md`: 「longrun plan.md の受け入れ条件の機械検証が全て PASS まで」（longrun 完了ゲート用）
  - `goal-lighthouse.md`: 公式例（`/goal get the homepage Lighthouse score to 90 or above, stop after 5 tries`）の移植（Web プロジェクト汎用）
- **time レシピ 3 本**を `plugins/loops/recipes/` に新設する:
  - `loop-pr-babysit.md`: 公式例 `/loop 5m check my PR, address review comments, and fix failing CI` を、このリポジトリの Draft PR 運用（CLAUDE.md）向けに調整した版
  - `cron-daily-report.md` / `cron-weekly-report.md`: 既存 daily/weekly-report スキルの非対話モードを定期実行するレシピ。発火時プロンプト・推奨頻度・停止基準・実行環境の制約（ローカルデータ [Vault・セッション jsonl] を読むためローカル実行必須）のみ定義し、スケジューラへの登録は呼び出し側の責務とする
- 各レシピのコスト注意節に、公式トークン管理の該当項目（実行頻度の必要最小化・決定論的作業のスクリプト化・大規模実行前のパイロット）を明記する
- 全レシピは change-1 の固定見出し規約（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）に準拠し、起動コマンドはネイティブプリミティブ（/goal・/loop・/schedule・skill 起動）のみを使う
- この 6 本は**初期シード**という位置づけ。以降の棚の成長・実測チューニングは change-4 の recipe-miner ルーチンが担う
- レシピ規約準拠を検証する bats テストを `plugins/loops/tests/` に追加する

## Capabilities

### New Capabilities

- `loops-goal-recipes`: ゴールベースループの初期シードレシピ 3 本（tests-green / acceptance-pass / lighthouse）。機械検証可能な成功基準（コマンド + 期待値）と最大試行数の必須化、/goal ネイティブ起動コマンド、固定見出し規約準拠を定義する
- `loops-time-recipes`: タイムベースループの初期シードレシピ 3 本（pr-babysit / daily-report / weekly-report）。保守的な頻度デフォルトと変更方法の併記、実行環境制約の明記、スケジューラ登録の責務分離（呼び出し側の責務）、既存レポートプラグイン本文の非変更を定義する

### Modified Capabilities

（なし。既存 capability の要件変更はない。daily-report / weekly-report はレシピが参照するだけで本文を変更しない）

## Impact

- **新規ファイル**:
  - `plugins/loops/recipes/goal-tests-green.md`
  - `plugins/loops/recipes/goal-acceptance-pass.md`
  - `plugins/loops/recipes/goal-lighthouse.md`
  - `plugins/loops/recipes/loop-pr-babysit.md`
  - `plugins/loops/recipes/cron-daily-report.md`
  - `plugins/loops/recipes/cron-weekly-report.md`
  - `plugins/loops/tests/recipes-seed.bats`（レシピ規約準拠の grep 検証）
- **変更ファイル**: なし（daily-report / weekly-report / longrun の各プラグイン本文には触れない。loops の plugin.json version bump と marketplace.json 同期は change-5 が一括で行う）
- **依存**: change-1 (loops-plugin) の完了が前提（レシピ形式規約・`plugins/loops/recipes/` の置き場所・`references/loop-types.md` の責務分離節を参照する）
- **非対象**: 定期実行の機構・配線一式（セッション内 cron 登録・SessionStart hook・launchd・`claude -p` 配線。実行側は別セッションの Pikke プロセス整理が担う）、独自ループランタイム、プロアクティブ合成ルーチン（change-4）、既存レポートスキルの機能変更
