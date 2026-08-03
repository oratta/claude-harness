# dev-workflow-automerge-templates

## ADDED Requirements

### Requirement: auto-merge workflow 一式がテンプレートとして配布される

dev-workflow プラグインは `templates/auto-merge/` に、展開先リポのツリーをそのまま鏡写しにした形（`.github/workflows/auto-merge.yml` / `.github/workflows/revert-pr.yml` / `docs/auto-merge.md` / `scripts/test-auto-merge-workflow.sh`）と展開手順 `README.md` を含む（SHALL）。テンプレートはリポ固有の差し替え箇所を既存マーカー（`# >>> sacred-paths` / `# >>> required-checks` 等）で明示し、README がそれ以外を変更せずに展開できる手順を提供する（SHALL）。

#### Scenario: テンプレートファイル群の存在

- **WHEN** `plugins/dev-workflow/templates/auto-merge/` を確認する
- **THEN** README.md と、展開先ツリーを鏡写しにした `.github/workflows/auto-merge.yml` / `.github/workflows/revert-pr.yml` / `docs/auto-merge.md` / `scripts/test-auto-merge-workflow.sh` の計 5 ファイルが存在する

#### Scenario: 差し替え箇所のマーカーが揃っている

- **WHEN** テンプレートの auto-merge.yml を検査する
- **THEN** `sacred-paths` / `sacred-paths-jq` / `required-checks` / `labeled-target` / `pre-merge-recheck` / `automerge-script` のマーカー対（`# >>> name` と `# <<< name`）がすべて存在し、revert-pr.yml には `revert-script` のマーカー対が存在する

#### Scenario: README が展開手順を提供する

- **WHEN** templates/auto-merge/README.md を読む
- **THEN** リポ展開時に必ず差し替える 3 点（聖域パス定義・REQUIRED_CHECKS と展開先 ci.yml のジョブ名の一致・`AUTOMERGE_PAT` の発行と Secrets 登録）と、`AUTOMERGE_PAUSED` による緊急停止・revert-pr.yml による巻き戻しの運用手順が記載されている

### Requirement: テンプレートは flatmate で実証済みの安全不変条件を維持する

テンプレートの auto-merge.yml は次の安全不変条件を維持する（SHALL）: 素の `pull_request` トリガーを持たない、`pull_request_target` のイベント種は labeled のみ、`actions/checkout` や head の clone を行わない、マージは `gh pr merge` ではなく REST API に検証済み HEAD SHA をピンして行う、PAT 未設定時と `AUTOMERGE_PAUSED` 設定時は fail-closed で何もマージしない。revert-pr.yml は revert PR の作成までを行いマージしない（SHALL NOT merge）。

#### Scenario: 安全不変条件の退行検知

- **WHEN** このリポの CI（bats テスト）がテンプレートを検査する
- **THEN** 素の `pull_request` トリガーの不在・checkout / clone の不在・`gh pr merge` の不在・`-f sha=` による SHA ピンの存在・`AUTOMERGE_PAUSED` と PAT 未設定の fail-closed 分岐の存在が機械的に検証され、破れていればテストが落ちる

#### Scenario: 攻撃再現テストが展開先で実行可能

- **WHEN** テンプレートを展開したリポの CI が test-auto-merge-workflow.sh を実行する
- **THEN** 聖域パス正規表現の挙動検査・rename 迂回の封鎖・REQUIRED_CHECKS と ci.yml ジョブ名の一致・埋め込みスクリプトの構文がすべて機械検証される

### Requirement: 運用ガイドはリポ非依存の記述で提供される

テンプレートの README と運用ガイド（`docs/auto-merge.md`）は特定リポの URL を直書きせず、`<owner>/<repo>` 形式のプレースホルダまたは相対参照で記述する（SHALL）。

#### Scenario: flatmate URL の不在

- **WHEN** templates/auto-merge/ 配下の全ファイルを検査する
- **THEN** `genetta-inc/flatmate` の直書きが存在しない
