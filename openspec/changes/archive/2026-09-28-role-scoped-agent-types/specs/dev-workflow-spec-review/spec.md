## MODIFIED Requirements

### Requirement: 書いた仕様は実装前に別コンテキストがレビューする
develop スキルは、仕様化経路で、W が openspec CLI（`openspec new change` と artifact の直書き）で artifact を生成して return した直後・W を再開して実装に着手する前に、本体が spawn する R1（`references/roles/spec-reviewer.md` を読む、実装と別コンテキストのサブエージェント）による仕様レビューを挟まなければならない（MUST）。本体や主が W の起動前に `/opsx:ff` などで change を作っていた場合も、W がそれを確かめて return したあと同じ仕様レビューを挟む（SHALL）。レビューの入力は change ディレクトリの artifact・記録先の受け入れ条件・関連する既存 `openspec/specs/`（`grep` で当たりを付けた範囲）とし（MUST）、観点・出力書式は `references/roles/spec-reviewer.md` を正本とする（SHALL）。R1 が `APPROVE` を返し記録されるまで W を実装に進めてはならない（MUST NOT）。

#### Scenario: 1 ループにレビューが挟まっている
- **WHEN** SKILL.md の 1 ループを読む
- **THEN** W の change の作成（`openspec new change`）と W の再開（実装）の間に R1 の仕様レビューがあり、`references/roles/spec-reviewer.md` を参照し、APPROVE の記録まで実装に進まない旨が書かれている

#### Scenario: worker.md の仕様化の節にもレビューがある
- **WHEN** `references/roles/worker.md` の仕様化する場合の節を読む
- **THEN** `openspec new change` と artifact の直書きの後に本体へ return して仕様レビューを受けることと、R1 の APPROVE が記録されるまで実装に進まないことが書かれている
