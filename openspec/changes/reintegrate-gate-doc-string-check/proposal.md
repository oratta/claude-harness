## Why

pr-review-gate は、テストの成功と受け入れ条件の実行の証拠があれば合格を出すので、実装と説明文（JSDoc・`--help` の usage・README・エラーメッセージ）が食い違ったまま `agent-review:passed` が付く。auto-merge を配備したリポではその場でマージされ、直すための PR がもう 1 本要る（issue #166 の実測）。

この確認は PR #174 で一度作ってレビューを通したが、マージ前に main の pr-review-gate が索引（`SKILL.md`）と段のファイル（`stages/`）に分割され、版番号の運用も撤去されたため、衝突してマージできない。main の今の形へ入れ直す。

## What Changes

- `stages/pass.md` の手順 4 を `4-1. 振る舞いの確認`（既存の本文）と `4-2. ドキュメント文字列の整合確認` に分ける。4-2 は確認対象の 4 種、`git grep -n` の実行例、0 件の記録、HEAD SHA 付きの証拠コメントを定める
- 手順 5 の合格前の実測の見出しを 3 つから 4 つにする
- 通過の必須点は 4 点のままとし、③動作確認の証拠に整合確認を含める
- 4-2 で食い違いが残れば、G は `agent-review:failed` で W に戻す。この取り直しはレビューの周に数えない
- この PR が変えた振る舞いの説明の食い違いを指摘の振り分けの段 A（この PR で直す）に足し、別 issue に流れないようにする
- 必須点を列挙する文書（`SKILL.md`・dev-workflow の README・auto-merge の README・`references/commit-and-pr-operations.md`・`skills/develop/SKILL.md` の見出し数の言及）を揃える
- **PR #174 の旧設計から落とすもの**: 説明文 5 か所の同時更新の要件とその bats（main は `description` の変更を固定テストで禁じている）、版番号の更新と版のテスト（main は版を撤去した）。変更の記録は `plugins/dev-workflow/changes/166.md`

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 整合確認の要件を足し、light の免除範囲・合格処理の実測・指摘の振り分けの要件を変える
- `dev-workflow-develop`: 周回の引き継ぎに、整合確認の取り直しは周を足さないという例外を足す

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/`（聖域。人間がマージする）、`skills/develop/`、README 2 本、references 1 本、bats、`tests/gate-reading-budget.txt`、`tests/fixtures/gate-contracts/`
- すべての PR のゲートに、検索と PR コメント 1 件が増える
- archive 済みの `openspec/changes/archive/2026-08-21-pr-review-gate-doc-string-consistency/` は当時の記録として変えない
