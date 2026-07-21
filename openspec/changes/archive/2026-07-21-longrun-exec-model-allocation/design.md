## Context

longrun のモデル割り当て機構（change-4 で導入）は plan.md の表 → `resolve-model-allocation.mjs` → Workflow `opts.model` の一本道で、tier 語彙は haiku / sonnet / inherit の3値。inherit は agent frontmatter の `model: opus` に解決される。issue #26 の4象限設計により、longrun:exec は「④ トークン大 × 判断多」の実行バックエンドとなり、記事準拠のモデル配置（builder=安、判断点=Fable）を表現する必要が生じた。`FABLE_BUDGET_MODE` は dev-workflow-execution-strategy（archived 2026-07-21）が定義済み。

## Goals / Non-Goals

**Goals:**

- plan.md で Fable を指せるようにする（`fable` tier）
- reserve モードの自動実行で Fable を使わない降格経路を resolver に実装する
- ロール別推奨を4象限準拠に更新する

**Non-Goals:**

- 実行中のモデル昇格（トリップワイヤー②）の実装 — これは実行時の振る舞いで、静的な割り当て解決の外
- loop-dev-agent 憲法への組み込み（別 change `loop-dev-agent-tripwires`）
- agent frontmatter（`model: opus`）の変更 — inherit のセマンティクスは不変

## Decisions

1. **`fable` は第4ティア**（`opts.model` 渡し値はエイリアス `'fable'`）。既存3値の意味は変えない（後方互換。fable を含まない既存 plan.md は無変更で動く）。
2. **reserve 降格は resolver 内で行う**。条件: `FABLE_BUDGET_MODE=reserve` かつ `LONGRUN_AUTOMATED=1` の両方が環境変数に設定されているとき、`fable` ティアを `'opus'` に解決し warning を JSON に含める。`LONGRUN_AUTOMATED` は無人配線（cron / loop-dev-agent。組み込みは別 change）が設定する。interactive セッションでは未設定のため降格しない。代替案「exec.md のプロンプト指示で降格」は、決定論的にできる処理を LLM 判断に残すため却下（resolver は既に決定論スクリプト）。
3. **推奨出発点の更新**: builder=sonnet（実行はテストと verify に守られ、失敗ループは昇格トリップワイヤーが救済する）、verifier / reviewer=fable（判断が集中する場所は常に賢いモデル、のモード不変ルール）。定型的検証のみなら haiku、「迷ったら inherit」は維持（inherit=opus は安全なフォールバック）。
4. **fail-soft 維持**: 未知ティア → inherit + 警告の既存挙動は変えない。reserve 降格も run を止めない（警告のみ）。

## Risks / Trade-offs

- [`LONGRun_AUTOMATED` の設定漏れで reserve が自動実行に効かない] → 配線側（別 change / flatmate cron）の責務として model-tiers.md に明記。設定漏れ時は「Fable が使われる」方向に倒れる（品質は守られ、温存だけが効かない）
- [既存 plan.md の verifier=haiku 推奨と新推奨の混在] → 既存 plan.md は書き換えない。新規生成分から新ヒューリスティクスが効く
- [エイリアス 'fable' が Workflow ツールで未サポートの環境] → model-tiers.md の対応表を 1 行変えるだけで修正できる集約設計を維持
