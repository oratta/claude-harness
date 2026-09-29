## ADDED Requirements

### Requirement: 保留処理の依頼文は新しいセッションでの再開を案内する

`skills/pr-review-gate/stages/hold.md` の手順 6（保留処理）の主への確認依頼は、依頼の中身（許容の可否・動作確認の 3 点セット・切り出しの確認）に加えて、返事を新しいセッションで `/develop <記録先>` と一緒に渡せることを含めなければならない（MUST）。引き継ぎのコメント（`引き継ぎ: 主の返事待ち`）は develop の本体が書くので、G の依頼文は書式を再掲せず、`dev-workflow-develop` の要件を指すだけにする（MUST）。`stages/hold.md` は引き継ぎの項目一覧を持ってはならない（MUST NOT）。

#### Scenario: 依頼文に案内がある

- **WHEN** `plugins/dev-workflow/tests/` の bats が `stages/hold.md` の手順 6 を検査する
- **THEN** 新しいセッションで `/develop <記録先>` と一緒に返事を渡す案内があり、引き継ぎの項目名（`前任 W` など）の一覧は無い
