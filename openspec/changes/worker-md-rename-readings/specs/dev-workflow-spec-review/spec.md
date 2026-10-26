## MODIFIED Requirements

### Requirement: 仕様化要否の判定結果を固定書式で issue に記録する
develop スキルの W の指示書（`references/roles/worker/spec.md`）は、仕様化要否を判定した直後に、その結果を記録先（元 issue。issue が無い場合は Draft PR）のコメントとして記録する手順を明記しなければならない（MUST）。コメントの 1 行目は正規表現 `^仕様化判断: (する|しない)$` に完全一致し（装飾・全角コロン・末尾句点を含めない）（MUST）、2 行目以降に判定理由（`references/decision-criteria.md` のどの条件に当たったか）を書く（MUST）。同接頭辞のコメントが複数あるときは作成日時が最新の 1 件を正とし（SHALL）、この記録は interactive / unmanned の両モードで行い（MUST）、記録せずに分割判定・実装へ進んではならない（MUST NOT）。後続の照合で PR から元 issue を解決する規則（PR 本文中で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`、大文字小文字不問。見つからなければ PR 自身のコメントを見る）は `references/roles/spec-reviewer.md` の「判断記録の契約」に定義する（SHALL）。

#### Scenario: worker.md に記録手順と正規表現がある
- **WHEN** `references/roles/worker/spec.md` の仕様化判断の節を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式と、`gh` で記録先にコメントする手順、記録前に先へ進まない旨が書かれている

#### Scenario: unmanned でも免除されない
- **WHEN** SKILL.md の実行モード表または unmanned に関する記述を読む
- **THEN** 判定記録が unmanned でも必須であることが書かれている

#### Scenario: 複数記録時の選択規則と PR→issue の解決規則がある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 同接頭辞のコメントが複数あるときは最新 1 件を正とする規則と、PR 本文の最初の `Closes` / `Fixes` / `Refs #N` で元 issue を解決し、無ければ PR 自身のコメントを見る規則が書かれている

### Requirement: 書いた仕様は実装前に別コンテキストがレビューする
develop スキルは、仕様化経路で、W が openspec CLI（`openspec new change` と artifact の直書き）で artifact を生成して return した直後・W を再開して実装に着手する前に、本体が spawn する R1（`references/roles/spec-reviewer.md` を読む、実装と別コンテキストのサブエージェント）による仕様レビューを挟まなければならない（MUST）。本体や主が W の起動前に `/opsx:ff` などで change を作っていた場合も、W がそれを確かめて return したあと同じ仕様レビューを挟む（SHALL）。レビューの入力は change ディレクトリの artifact・記録先の受け入れ条件・関連する既存 `openspec/specs/`（`grep` で当たりを付けた範囲）とし（MUST）、観点・出力書式は `references/roles/spec-reviewer.md` を正本とする（SHALL）。R1 が `APPROVE` を返し記録されるまで W を実装に進めてはならない（MUST NOT）。

例外は文言合わせの通し方（「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）だけとする（MUST）。記録先の最新の仕様化判断のコメントに `^通し方: 文言合わせ$` に完全一致する行があるとき、本体は R1 を spawn せず、W を実装に進める（SHALL）。本体は W の return の文面ではなく、記録先のコメントでこの行を確かめなければならない（MUST）。行が無ければ R1 を挟む（MUST）。

#### Scenario: 1 ループにレビューが挟まっている
- **WHEN** SKILL.md の 1 ループを読む
- **THEN** W の change の作成（`openspec new change`）と W の再開（実装）の間に R1 の仕様レビューがあり、`references/roles/spec-reviewer.md` を参照し、APPROVE の記録まで実装に進まない旨が書かれている

#### Scenario: worker.md の仕様化の節にもレビューがある
- **WHEN** `references/roles/worker/spec.md` の仕様化する場合の節と、`references/roles/worker/common.md` の「実装に入る前の確認」の節を読む
- **THEN** `openspec new change` と artifact の直書きの後に本体へ return して仕様レビューを受けることと、R1 の APPROVE が記録されるまで実装に進まないことが書かれている

#### Scenario: 文言合わせの通し方では R1 を挟まない
- **WHEN** 記録先の最新の仕様化判断のコメントが 1 行目 `仕様化判断: する` で、2 行目以降に `通し方: 文言合わせ` の行を持つ
- **THEN** 本体は R1 を spawn せず、記録先のコメントでその行を確かめたうえで W を `段: implement` で再開する

#### Scenario: 通し方の行が無ければ R1 を挟む
- **WHEN** W が「文言合わせで進める」と return したが、記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行が無い
- **THEN** 本体は W を実装に進めず、W を `段: spec` で再開して仕様化判断を投稿し直させる

### Requirement: 仕様レビュアーのモデルは役割で選ぶ
R1 は本体が `model` を明示して spawn しなければならない（MUST）。既定は中位ティア（`opus`）とし（SHALL）、仕様が `references/pre-classification.md` の「重要実装の事前分類」表のマージ権限・層間契約・課金/法務に当たる場合は、`model: fable` を付けた `general-purpose` ではなく `subagent_type: dev-workflow:decider` で spawn しなければならない（MUST。聖域パスだけでは上げない。分類表の正本は `pre-classification.md` であり、この要件に再掲しない）。`general-purpose` などの実行役の種別に `model: fable` を付ける spawn は `scripts/agent-model-guard.sh` に拒否される（SHALL）。残量モードは `dev-workflow-execution-strategy` の規定に従い、`FABLE_BUDGET_MODE=reserve` は自動実行のみ、`exhausted` は全経路で `opus` を上限とする（MUST）。

#### Scenario: モデル明示と既定 opus が書かれている
- **WHEN** SKILL.md の「モデル」節または `references/roles/spec-reviewer.md` を読む
- **THEN** `model` を明示すること、既定が `opus` であること、マージ権限・層間契約・課金/法務に当たれば `dev-workflow:decider` で spawn し、聖域パスだけでは上げないことが書かれている

#### Scenario: 残量モードの扱いが既存規定と一致する
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` の残量モードの記述を読む
- **THEN** `reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、と書き分けられている

#### Scenario: R1 のモデル選択が指す表

- **WHEN** `references/roles/spec-reviewer.md` のモデルの箇条を読む
- **THEN** 事前分類表の参照先が `references/pre-classification.md` である

## REMOVED Requirements

### Requirement: 仕様レビューまわりの要件が指す W の指示書の読み替え

**Reason**: 読み替えの対象だった「worker.md」の名指しを、移し先のファイル名で直接書いたため

**Migration**: 他の要件が移し先のファイル名で直接書き直されたので、読み替えの規則は要らない。
