# Decisions Log — longrun-plan-mvp-mode

## D1: worktree なしで proud-rotate ブランチに直列実装
- **日時**: 2026-05-07 Setup フェーズ
- **判断**: change-A → B → C を proud-rotate ブランチで順番に実装。worktree は作らない
- **根拠**:
  - plan.md で change-A → B → C の依存関係が明記されている（並列実行不可）
  - 並列性が活きないため worktree オーバーヘッドのメリットなし
  - 実装対象がこのプラグイン本体（plugins/longrun/）であり、worktree 内で同じプラグインを編集すると検証時にどのバージョンを参照するか複雑化する
- **エビデンス**: plan.md の change-B 「依存関係: change-A 完了後」、change-C 「依存関係: change-A, change-B 完了後」
- **影響**: orchestrator SKILL.md の「Build前半 並列worktree」フローを「直列インライン」に置き換える

## D2: OpenSpec longrun-tdd スキーマセットアップをスキップ
- **日時**: 2026-05-07 Setup フェーズ
- **判断**: `openspec/config.yaml` と `schemas/longrun-tdd/` を作成せず、既存の spec-driven スキーマで `openspec new change` のみ使う
- **根拠**:
  - 実装対象は Markdown 駆動のプラグイン定義（SKILL.md / agent.md / template.md）。プログラミング言語のテストフレームワークが存在しない
  - plan.md の「テストフレームワーク: なし」を明記済み
  - longrun-tdd スキーマは TDD（Red/Green/Refactor）を強制するが、Markdown 編集に対して概念的に適用できない
- **エビデンス**: 検出コマンド `cat openspec/config.yaml` → `no config.yaml`
- **影響**: Build 時の `openspec apply` ではなく、proposal/spec/tasks を作成 → builder Agent が直接 SKILL.md 編集

## D3: longrun-browser-verifier をスキップ
- **日時**: 2026-05-07 Setup フェーズ
- **判断**: Verify フェーズは longrun-verifier（コードレビュー）のみ実行
- **根拠**:
  - 実装対象は CLI/Markdown プラグインで、ブラウザ UI が存在しない
  - plan.md の「動作確認方法 → 開発サーバー: なし」を明記済み
  - 機能性は手動 invocation 確認に置き換える（plan.md 受け入れ条件 #5〜#12）
- **エビデンス**: plan.md の動作確認方法セクション
- **影響**: 4軸評価のうち「機能性」「UX」は手動確認に委譲。verify 自動化は「品質」「完成度」のみ

## D5: version 同期 bump は 4.3.0 ではなく 5.2.0 に統一する
- **日時**: 2026-05-07 change-C 実装フェーズ
- **判断**: `plugin.json` を `5.1.0 → 5.2.0` に minor bump し、`SKILL.md` frontmatter を `4.2.0 → 5.2.0` に**揃える**（plan.md 当初指定の 4.3.0 ではない）
- **根拠**:
  - plan.md（受け入れ条件 #10）は両者を 4.3.0 にすると指示しているが、実際の `plugin.json` は既に 5.1.0 まで進んでいた（v5.0 / v5.1 のリネーム作業で先行 bump 済み）
  - plan.md の指示通り 4.3.0 にすると plugin.json を **downgrade** することになり、プラグインキャッシュの新旧判定が破綻し他プロジェクトで配信トラブルが起きる（plugin-editing.md ルール「バージョン単位でキャッシュされる」より）
  - 「同期 bump」の本質は「両ファイルが揃った状態でキャッシュ無効化を起こすこと」であり、特定数値 4.3.0 への固執ではない
  - SKILL.md frontmatter の 4.2.0 は v5.x への bump 取り込み漏れであり、本 change で揃えるのが正しい
- **エビデンス**: `plugin.json` 現状 `"version": "5.1.0"`、SKILL.md frontmatter `version: 4.2.0`
- **影響**: 受け入れ条件 #10 の数値解釈を「4.3.0」から「両者一致 minor bump」と読み替える。後の archive で本決定を spec.md にも反映する

## D4: Build Contract レビューは plan 段階の APPROVE と別に再実行
- **日時**: 2026-05-07 Setup フェーズ
- **判断**: plan 段階で longrun-reviewer から APPROVE を得ているが、orchestrator SKILL.md の指示通り Build Contract フェーズで再度 longrun-reviewer を呼ぶ
- **根拠**: orchestrator SKILL.md L168-170「『plan.mdは既にレビュー済み』『longrun-planでレビュー通過済み』は理由にならない。longrun-planのレビューとBuild Contractは別の検査である」
- **エビデンス**: orchestrator SKILL.md 引用
- **影響**: Build Contract で 2 回目のレビューを実施
