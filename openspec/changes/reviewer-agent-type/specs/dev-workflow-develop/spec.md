## MODIFIED Requirements

### Requirement: W と G は役割ごとの種別で起こす
develop の本体は W を `subagent_type: dev-workflow:worker`、G を `subagent_type: dev-workflow:gate-runner` で spawn しなければならない（MUST）。`general-purpose` で起こしてはならない（MUST NOT）。種別を替えても `model` は従来どおり spawn のたびに明示しなければならない（MUST。W は事前分類に当たれば `opus`、それ以外 `sonnet`。G は `sonnet`）。手渡しで後任を起こすときと、段ごとに新しい G を起こすときも同じ種別を使う（SHALL）。

`references/codex-develop.md` の Claude role の起動（W / G を Claude で起こす経路）も同じ種別を使わなければならない（MUST。どの role をどの種別で起こすかは `manual-codex-develop` の「委譲は前景実行の 3 手順で行う」が定める）。

G が要求するレビュアー（決める役でないとき）は、本体が `subagent_type: dev-workflow:reviewer` で spawn しなければならない（MUST）。`general-purpose` で起こしてはならない（MUST NOT）。`model` は spawn のたびに明示する（MUST。既定 `opus`）。区画ごとに起こすときと、補足のレビュアーを起こすときも同じ種別を使う（SHALL）。レビュー対象がマージ条件・層間契約・課金/法務に触れるときは従来どおり `dev-workflow:decider` で起こす（SHALL）。pr-review-gate を develop 以外で回すときのフォールバックの Task サブエージェントも `dev-workflow:reviewer` で起こす（SHALL）。

仕様レビュー R1（決める役でないとき）の種別は変えない（SHALL。`general-purpose`。決める役に当たるときは従来どおり `dev-workflow:decider`）。

`develop/SKILL.md` の役割表と Agent ツールの行、(1)・(3)・(4) の spawn の記述とモデル表、`references/roles/worker.md`・`references/roles/gate-runner.md` の冒頭、`skills/pr-review-gate/stages/prepare.md` の needs-reviewer の payload、`skills/pr-review-gate/stages/review-run.md` 2-1 の優先順の表、`plugins/dev-workflow/README.md` の役割とモデルの説明は、それぞれの種別を書かなければならない（MUST）。

#### Scenario: 役割表が種別を書く
- **WHEN** `plugins/dev-workflow/skills/develop/SKILL.md` の役割表を読む
- **THEN** W の行に `dev-workflow:worker`、G の行に `dev-workflow:gate-runner` があり、R1 の行には `dev-workflow:worker` も `dev-workflow:gate-runner` も `dev-workflow:reviewer` も無い

#### Scenario: spawn の記述が種別を書く
- **WHEN** `develop/SKILL.md` の (1) と (4) の spawn の行、`worker.md` と `gate-runner.md` の冒頭、`references/codex-develop.md` の Claude role の起動、`plugins/dev-workflow/README.md` の役割とモデルの説明を読む
- **THEN** W には `dev-workflow:worker`、G には `dev-workflow:gate-runner` が書かれ、W / G を `general-purpose` で起こす記述が無い

#### Scenario: レビュアーの spawn の記述が種別を書く
- **WHEN** `develop/SKILL.md` の Agent ツールの行とモデル表の「G が要求するレビュアー」の行、`stages/prepare.md` の needs-reviewer の payload の前の段落と `推奨モデル` の行、`stages/review-run.md` 2-1 の表のフォールバックの行を読む
- **THEN** レビュアーの既定の種別として `dev-workflow:reviewer` が書かれ、事前分類に当たるときの `dev-workflow:decider` が残り、レビュアーを `general-purpose` で起こす記述が無い
