## Why

`/longrun:plan` のフルモードは Build Contract / TDD / Verifier を含む重装備で、短時間で人間が手で MVP を実装するシナリオには過剰である。MVP モード（`--mode=mvp`）を新設するにあたり、ヒアリング後に並列リサーチと並列レビューを行う軽量フローが必要となる。本 change は、その MVP フローから呼び出される 3 種の subagent 定義（research / plan-reviewer / bestpractice-reviewer）を独立して追加する。

特にリサーチ系では「類似サービス調査」と「実装パターン調査」を別 agent で実行すると同一クエリでの重複検索が発生しやすく、トークンが爆発する懸念がある。本 change では **1 つの research subagent が 1 度の調査で 2 セクション（## 類似サービス事例 / ## 実装パターン）を出力する**設計を採用し、レポート末尾に必ず `## Search Audit` を付与してクエリ実行回数を定量検証可能にする。

## What Changes

- `plugins/longrun/agents/longrun-mvp-research.md` を新規作成
  - 類似サービス + 実装パターンの調査を **1 回の調査** で実行し、1 レポート 2 セクションで出力
  - 同一クエリでの重複検索を禁止、検索回数の最小化（理想は 1 回）
  - レポート末尾に `## Search Audit`（queries: 数 / list: クエリ配列）を必ず付与
- `plugins/longrun/agents/longrun-mvp-plan-reviewer.md` を新規作成
  - 初期プラン v0 を input として受け取り、スコープ過大／矛盾／受け入れ条件の検証可能性をレビュー
  - **特定の時間枠（例: 1h）に依存しない汎用レビュー**として記述
  - 出力は APPROVE / REQUEST_CHANGES の二値 + 具体的指摘
  - 外部検索は最大 1 回まで。`## Search Audit` を必ず付与（不実施時も `queries: 0`）
- `plugins/longrun/agents/longrun-mvp-bestpractice-reviewer.md` を新規作成
  - 該当ドメインの落とし穴・anti-pattern を外部知識ベースで指摘
  - 外部検索は **最大 1 回まで**（トークン爆発防止）
  - レポート末尾に `## Search Audit`（queries: <=1 / list: クエリ配列）を必ず付与

## Capabilities

### New Capabilities
- `longrun-mvp-research`: MVP モードの並列リサーチを担う subagent。類似サービスと実装パターンを 1 回の調査で 2 セクション化し、検索クエリ数を Search Audit で監査可能にする。
- `longrun-mvp-plan-reviewer`: MVP 用の汎用プランレビュア subagent。スコープ過大／矛盾／受け入れ条件の検証可能性を APPROVE/REQUEST_CHANGES 形式で評価し、Search Audit でレビュー時の検索量を監査する。
- `longrun-mvp-bestpractice-reviewer`: MVP 用の anti-pattern 指摘 subagent。外部検索を最大 1 回に制限し、Search Audit によりトークン爆発の有無を検証可能にする。

### Modified Capabilities
（なし。既存 `longrun-reviewer` agent には触らない）

## Impact

- **新規ファイル**:
  - `plugins/longrun/agents/longrun-mvp-research.md`
  - `plugins/longrun/agents/longrun-mvp-plan-reviewer.md`
  - `plugins/longrun/agents/longrun-mvp-bestpractice-reviewer.md`
- **変更ファイル**: なし（本 change のスコープでは plan.json / SKILL.md / commands は触らない。change-B / change-C で扱う）
- **依存**:
  - 既存 `longrun-reviewer.md` の frontmatter フォーマット（name / description / tools / model / permissionMode）に整合
  - 後続 change-B（SKILL.md MVP 分岐追加）から `Agent` ツール経由で呼び出される
- **regression リスク**: なし。既存 agent 定義は一切変更せず、新規 3 ファイル追加のみ
- **トークン消費**: research / bestpractice-reviewer に対する Search Audit 制約により、外部検索の総回数を 1 回／1 回／最大 1 回（合計 ≤ 3 回）に制限可能
