# Proposal: promote-pr-review-gate-to-dev-workflow

## Why

flatmate に新設した PR レビューゲートスキル（genetta-inc/flatmate PR #232 の `.claude/skills/pr-review-gate/SKILL.md`）は「PR 作成 → 別コンテキストレビュー → リスク宣言の positive affirmation（fail-closed）→ 動作確認証拠 → `agent-review:passed` → auto-merge」というリポ非依存の汎用開発フロー規約だが、flatmate 内スキルのため flatmate でしか発火しない。他リポ（claude-harness / marketing-harness / shukan 等）で同じゲートを効かせるには dev-workflow プラグインへの昇格が必要（issue #82）。同時に auto-merge workflow 一式（flatmate PR #234: auto-merge.yml / revert-pr.yml / 攻撃再現テスト）もリポごとに配るテンプレート性質のものなので、正本をプラグイン側に置いて配布する。

初回運用（2026-08-03 の 10 PR）でレビュー精度は実証済み。運用面の収束ルール（flatmate issue #240: リンク真正性確認・既定2周キャップ・差分限定再レビュー・blocking 定義の限定・重複説明の減量）は flatmate 側に未反映のため、正本がプラグインへ移るこの機会に移植版へ織り込む。

## What Changes

- `pr-review-gate` スキルを `plugins/dev-workflow/skills/pr-review-gate/` に新設（flatmate 版 212 行を正本として移植）
  - flatmate 固有参照（`memory/pending-owner.md` / `scripts/pending-mirror.sh` / `openspec/specs/channel-reply-policy/spec.md` / `docs/agent-loop-steps.md`）をリポ非依存の記述に置き換え（各リポに同等の仕組みがあれば従う、無ければ縮退、の条件分岐に）
  - flatmate issue #240 の収束ルールを織り込む: ①リスク許容リンクの真正性確認（GitHub リンクは `gh api` で author 実測）②既定2周キャップ（3周目は新規の高深刻度 blocking のみ）③再レビューは差分限定 ④マージ後に issue で直せるものは blocking にしない ⑤「リスク承認待ちの間に動作確認を並行する」の明示 ⑥HEAD SHA 必須の理由等の重複説明を冒頭に集約して減量
- auto-merge workflow テンプレート一式を `plugins/dev-workflow/templates/auto-merge/` に新設: `auto-merge.yml` / `revert-pr.yml` / `test-auto-merge-workflow.sh` / 展開手順 `README.md`（聖域定義・`AUTOMERGE_PAT`・必須チェック名の差し替え箇所を明記）
- `plugin.json` の skills 配列に pr-review-gate を追加し、version を 1.6.2 → 1.7.0 に bump（キャッシュ反映）
- プラグイン README にスキルとテンプレートの説明を追記
- bats テスト新設（スキルの構造・リポ非依存性・収束ルールの存在、テンプレートのマーカー・安全不変条件）
- flatmate 側のポインタ化（正本移動の案内）は本 change の実装対象外（別リポの follow-up。マージ後に実施）

## Capabilities

### New Capabilities

- `dev-workflow-pr-review-gate`: PR 作成後に必ず通す品質ゲートスキル。別コンテキストレビュー・リスク宣言（positive affirmation・fail-closed）・動作確認証拠・`agent-review:passed` 付与・保留/復帰手順・収束ルール（2周キャップ）を、プラグイン導入済みの全リポで同一手順として提供する
- `dev-workflow-automerge-templates`: auto-merge / revert-pr workflow と攻撃再現テストのリポ展開用テンプレート。リポ固有の差し替え箇所（聖域パス・必須チェック名・PAT）をマーカーで明示し、展開手順を README で提供する

### Modified Capabilities

（なし — 既存 dev-workflow 系 spec の要件は変更しない）

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（新設）
- `plugins/dev-workflow/templates/auto-merge/`（新設: yml×2 + sh + README）
- `plugins/dev-workflow/.claude-plugin/plugin.json`（skills 追加 + version bump）
- `plugins/dev-workflow/README.md`（説明追記）
- `plugins/dev-workflow/tests/`（bats テスト追加。ルート `tests/` は触らない）
- flatmate リポ（genetta-inc/flatmate）: 本 change のマージ後に `.claude/skills/pr-review-gate/SKILL.md` をポインタ化する follow-up が必要（flatmate issue #240 もそこで close 可能になる）
- 既存 CI（shellcheck + bats）: 追加する `.sh` テンプレートが shellcheck 対象に入る
