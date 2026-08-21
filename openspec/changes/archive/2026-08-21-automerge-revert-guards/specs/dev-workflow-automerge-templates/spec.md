## MODIFIED Requirements

### Requirement: テンプレートは flatmate で実証済みの安全不変条件を維持する

テンプレートの auto-merge.yml は次の安全不変条件を維持する（SHALL）: 素の `pull_request` トリガーを持たない、`pull_request_target` のイベント種は labeled のみ、`actions/checkout` や head の clone を行わない、マージは `gh pr merge` ではなく REST API に検証済み HEAD SHA をピンして行う、PAT 未設定時と `AUTOMERGE_PAUSED` 設定時は fail-closed で何もマージしない。revert-pr.yml は revert PR の作成までを行いマージしない（SHALL NOT merge）。revert-pr.yml は、対象 PR の base（`.base.ref`）が既定ブランチ以外なら拒否し（SHALL）、マージコミットが既定ブランチの履歴に含まれること（`git merge-base --is-ancestor`）を副作用（ブランチ作成・push）より前に検証し（SHALL）、部分失敗後の re-run（RUN_ID 同一・attempt 増加）では既存の revert ブランチと revert PR を発見して残工程だけを続行する（SHALL）。

#### Scenario: 安全不変条件の退行検知

- **WHEN** このリポの CI（bats テスト）がテンプレートを検査する
- **THEN** 素の `pull_request` トリガーの不在・checkout / clone の不在・`gh pr merge` の不在・`-f sha=` による SHA ピンの存在・`AUTOMERGE_PAUSED` と PAT 未設定の fail-closed 分岐の存在が機械的に検証され、破れていればテストが落ちる

#### Scenario: 攻撃再現テストが展開先で実行可能

- **WHEN** テンプレートを展開したリポの CI が test-auto-merge-workflow.sh を実行する
- **THEN** 聖域パス正規表現の挙動検査・rename 迂回の封鎖・REQUIRED_CHECKS と ci.yml ジョブ名の一致・埋め込みスクリプトの構文がすべて機械検証される

#### Scenario: revert の base/ancestor 検証と再開の退行検知

- **WHEN** CI（automerge-templates.bats と test-auto-merge-workflow.sh）が revert-pr.yml の実行コード（コメント除去済みの revert-script ブロック）を検査する
- **THEN** `.base.ref` の取得と `$BASE_BRANCH` 不一致の拒否・`merge-base --is-ancestor` が revert / push より前にあること・`ls-remote` / `gh pr list` による既存状態の発見が push / `gh pr create` より前にあることが機械検証され、破れていればテストが落ちる
