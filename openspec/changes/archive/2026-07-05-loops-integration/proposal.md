# Proposal: loops-integration

## Why

change-1〜4 で新プラグイン `loops`（レシピ集 + State 規約 + 設計ガイド）と既存スキルへの自己検証節が整備されるが、marketplace.json への登録・version 同期が行われない限り、`/plugin install loops@oratta-claude-harness` でユーザーに届かない（`~/.claude/rules/plugin-editing.md` 準拠: version bump しないと `~/.claude/plugins/cache/` の旧バージョンが使われ続ける）。また、公式記事「Getting started with loops」のトークン管理ベストプラクティスとコスト定量事実（ループはチャットの約4倍、マルチエージェント構成は約15倍）がレシピから参照できる 1 箇所（cost-guardrails.md）に集約されていないと、各レシピの「コスト注意」節が根拠を失う。本 change は run 全体の最終直列ステップとして、配布経路の確立・README での位置づけ提示・コストガードレール文書の新設・受け入れ条件の統合検証を行う。

## What Changes

- `.claude-plugin/marketplace.json` の `plugins[]` に新プラグイン `loops` を登録する（`source: ./plugins/loops`。version は `plugins/loops/.claude-plugin/plugin.json` と完全一致）
- 本 run（change-1〜4）で編集された全プラグインの plugin.json version を bump し、marketplace.json の対応エントリおよび top-level version と同期する
- ルート `README.md` に公式 4 ループタイプ（ターンベース / ゴールベース / タイムベース / プロアクティブ）と loops プラグイン（レシピ集）の位置づけを、公式記事リンク（https://claude.com/blog/getting-started-with-loops）付きで追記する。追記は要約に留め、詳細は `plugins/loops/` と `research/` に委ねる
- `plugins/loops/references/cost-guardrails.md` を新設する: 公式トークン管理 6 項目 + コスト定量事実（ループ≒チャットの約4倍・マルチエージェント≒約15倍）+ `/usage`・`/workflows` でのコストレビュー手順
- 受け入れ条件の統合検証を実装・実行する: 全 bats テスト PASS・全 *.json parse PASS・レシピ固定見出し規約の横断 grep 検証・独自ランタイム不在の検証・version 一致の機械検証

## Capabilities

### New Capabilities

- `loops-marketplace-sync`: 新プラグイン `loops` の marketplace.json 登録と、編集済み全プラグインの plugin.json ↔ marketplace.json version 完全一致（bump 含む）を定義する
- `loops-readme-positioning`: ルート README への公式 4 ループタイプとレシピ集の位置づけ追記（公式記事リンク付き・要約のみ・詳細は plugins/loops/ へ委譲）を定義する
- `loops-cost-guardrails`: `plugins/loops/references/cost-guardrails.md` の内容要件（公式トークン管理 6 項目・コスト定量事実・/usage//workflows レビュー手順・モデル ID 直書き禁止）を定義する
- `loops-integration-verification`: run 全体の受け入れ条件の統合検証（全 bats PASS・JSON parse・レシピ規約横断検証・独自ランタイム不在検証・エビデンス記録）を定義する

### Modified Capabilities

（なし。既存 capability の要件変更はない。既存プラグインへの変更は version bump のみで、機能・発火条件は変えない）

## Impact

- **変更ファイル**:
  - `.claude-plugin/marketplace.json`（loops エントリ追加・編集済みプラグインの version 同期・top-level version bump）
  - 編集済み各プラグインの `.claude-plugin/plugin.json`（version bump。対象リストは change-1〜4 の実変更から確定する）
  - `README.md`（loops プラグインと 4 ループタイプの要約追記）
- **新規ファイル**:
  - `plugins/loops/references/cost-guardrails.md`
  - `plugins/loops/tests/integration.bats`（統合検証テスト）
- **依存**: change-1〜4 の完了が前提（同期は最後に直列実行）。`plugins/loops/` の実体（recipes/ / references/ / skills/）が存在していること
- **非対象**: 定期実行の機構・配線（セッション内 cron・SessionStart hook・launchd・`claude -p` 配線）は別セッションの Pikke プロセス整理側の責務でありスコープ外。独自ループランタイムは作らない。既存プラグインの機能変更はしない（version bump のみ）
