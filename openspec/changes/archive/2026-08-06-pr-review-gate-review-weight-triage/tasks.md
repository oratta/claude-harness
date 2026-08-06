# Tasks: pr-review-gate-review-weight-triage

## 1. テスト先行（TDD Red）

- [x] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` にレビュー重量判定の assert を追加する — 判定節の見出し・機械的な判定材料（`--name-only` / 行数カウント）・light 条件 (a)(b)・既定 full と fail-closed 文言・免除しない工程の明示・PR コメント1行記録・事前判定とフォールバックの書き分けの存在
- [x] 1.2 既存のフォールバック記述が削られていないこと（回帰ガード）を assert する
- [x] 1.3 bats を実行して追加分が Red になることを確認する

## 2. スキルへの判定手順の追加

- [x] 2.1 手順2 の冒頭に「2-0. レビュー重量の判定（light / full）」を追加する — 判定材料の取得コマンド・条件表・light の条件 (a)(b)・既定 full／迷ったら full（fail-closed）・PR コメント1行記録
- [x] 2.2 手順2 の優先順表の「使う条件」を light / full で書き分け、事前判定と障害時フォールバックの役割の違いを1行で明記する（既存のフォールバック記述は残す）
- [x] 2.3 light で免除されない工程（別コンテキスト・リスク宣言・動作確認証拠・HEAD SHA 照合・合格前の API 実測・収束ルール）を明示する

## 3. バージョン bump と検証（Green）

- [x] 3.1 スキル frontmatter の version を 1.0.0 → 1.1.0 に上げる
- [x] 3.2 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を 1.7.0 → 1.8.0 に上げ、description にレビュー重量判定の一文を追加する
- [x] 3.3 `.claude-plugin/marketplace.json` の dev-workflow entry の version と description を plugin.json に同期する（整合ガード S131 / S132）
- [x] 3.4 bats 全件 Green を確認する（exit code を記録）
