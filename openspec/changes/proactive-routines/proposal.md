# Proposal: proactive-routines

## Why

公式記事「Getting started with loops」が定義する 4 ループタイプのうち、プロアクティブループ（イベント/スケジュールがトリガー、人間不在で回る定期業務）だけがハーネスにレシピとして存在しない。change-1（loops-plugin）でレシピ形式規約・State 規約・設計ガイドが、change-3（goal-and-time-recipes）で初期シードレシピ 6 本が整備されるため、その上に公式の合成パターン（/schedule + /goal + 動的ワークフロー + オートモード）で「人間は例外だけ処理する」ルーチンを 3 本実装する。3 本目の recipe-miner はハーネス自身を実使用ログで改善し続けるメタループであり、レシピ棚の成長を人手に依存させないための要である。

## What Changes

- `plugins/loops/recipes/routine-backlog-triage.md` を新設する: /schedule 起動 → `openspec/backlog.md` と open issues から着手可能タスクを選定（1 サイクル処理数上限あり）→ worktree 隔離で実装 → 第二エージェントレビュー → **Draft PR まで**（マージは人間）→ state 更新（処理済み / 繰り越し / 引き継ぎ待ち）
- `plugins/loops/recipes/routine-long-build.md` を新設する: harnesses 論文の外部状態設計（feature-list JSON + progress notes）をネイティブ合成で実現。1 サイクル = smoke check → `passes:false` の先頭 1 項目のみ実装 → verification コマンド exit 0 の evidence がある場合のみ `passes:true` 更新 → 説明的 commit → progress 追記
- `plugins/loops/references/feature-list-format.md` を新設する: feature-list の形式（`{id, description, verification, passes:false}`、項目・テスト削除禁止）を記載する。JSON Schema による強制はしない
- `plugins/loops/recipes/routine-recipe-miner.md` を新設する: 週 1 想定の手動/外部トリガーで、直近 7 日のセッション jsonl をサブエージェントで圧縮解析し、ループ化候補（反復依頼 / goal 化候補 / schedule 化候補 / 既存レシピの実測チューニング候補）を抽出 → 停止基準必須・Bad Loop 検査を通したレシピ新規案/更新 diff（1 サイクル最大 3 件）→ この marketplace リポジトリへ Draft PR（自動 merge 禁止）→ state に提案済み / 見送り理由 / 繰り越しを記録
- 各ルーチンの 1 サイクルデモをこのリポジトリ（または安全なサンドボックス）で実施し、実行ログを `{longrun-dir}` に evidence として残す。デモは未インストールの loops プラグインのスキル起動（`/loops:design`）に依存せず、`plugins/loops/references/` の規約検査手順（停止基準必須・Bad Loop 検査）を手動実行して evidence を残す
- 3 ルーチン + 各デモは独立したサブマイルストーン（独立 commit）とし、1 ルーチンのデモ失敗が他をブロックしない

**スコープ外（plan.md「含まないもの」準拠）**: 定期実行の機構・配線一式（cron 登録スキル・SessionStart hook・session-host supervisor・launchd・`claude -p` 配線）は別トラック（Pikke プロセス整理）の責務。レシピは実行方法非依存に書き、宣言するのは発火時プロンプト・推奨頻度・停止基準・実行環境の制約まで。独自ループランタイム（常駐スクリプト・カスタム driver）は作らない。

## Capabilities

### New Capabilities

- `loops-routine-backlog-triage`: backlog 消化ルーチンのレシピ。非破壊制約（Draft PR まで）・処理数上限・繰り越し記録・2 連続失敗凍結の 4 点と、1 サイクルデモの evidence 要件を定義する
- `loops-routine-long-build`: 長期ビルドルーチンのレシピと feature-list 形式リファレンス。1 サイクル 1 項目・evidence 必須の passes 更新・smoke check・凍結条件と、複数サイクル完走デモの evidence 要件を定義する
- `loops-routine-recipe-miner`: レシピ採掘・更新メタループのレシピ。ローカル実行必須の制約明記・1 サイクル最大 3 提案・Draft PR 出力（自動 merge 禁止）・サブエージェント隔離のログ解析と、手動 1 サイクルデモの evidence 要件を定義する

### Modified Capabilities

（なし。change-1 のレシピ形式規約・State 規約には従うが、それらの要件自体は変更しない）

## Impact

- **新規ファイル**:
  - `plugins/loops/recipes/routine-backlog-triage.md`
  - `plugins/loops/recipes/routine-long-build.md`
  - `plugins/loops/recipes/routine-recipe-miner.md`
  - `plugins/loops/references/feature-list-format.md`
  - `plugins/loops/tests/*.bats`（本 change 分のレシピ検証テスト）
  - `{longrun-dir}/` 配下のデモ実行ログ（backlog-triage 1 サイクル / long-build 2 サイクル以上 / recipe-miner 1 サイクル）
- **変更ファイル**: なし（既存プラグイン・既存レシピの本文は変更しない。version bump / marketplace.json 同期は change-5 の責務）
- **依存**: change-1（loops-plugin: レシピ形式規約・State 規約・references の置き場所）、change-3（goal-and-time-recipes: /goal レシピの流用。miner はシードレシピの存在が前提）
- **参照**: `plugins/worktree/`（backlog-triage の隔離）、daily-report の llm-log-compactor jq パターン（miner のログ圧縮）、`plugins/longrun/references/model-tiers.md`（モデル ID を書く必要が生じた場合の唯一のソース。原則レシピにはモデル ID を書かない）
