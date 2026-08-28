# dev-workflow-spec-review Specification

## Purpose
github-issue スキルが、仕様化要否の判断を機械照合できる書式で元 issue に残し、書いた仕様（openspec の change artifact）を実装前に別コンテキストが審査してから実装に入ることを規定する。longrun の Build Contract レビューを dev-workflow のパイプラインに置き直したもの。
## Requirements
### Requirement: 仕様化要否の判定結果を固定書式で issue に記録する
github-issue スキルの SKILL.md は、Step B で仕様化要否を判定した直後に、その結果を元 issue のコメントとして記録する手順を明記しなければならない（MUST）。コメントの 1 行目は正規表現 `^仕様化判断: (する|しない)$` に完全一致し（装飾・全角コロン・末尾句点を含めない）（MUST）、2 行目以降に判定理由（`references/decision-criteria.md` のどの条件に当たったか）を書く（MUST）。同接頭辞のコメントが複数あるときは作成日時が最新の 1 件を正とし（SHALL）、この記録は interactive / unmanned の両モードで行い（MUST）、記録せずに Step C / Step D へ進んではならない（MUST NOT）。後続の照合で PR から元 issue を解決する規則（PR 本文中で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`、大文字小文字不問）は `references/spec-review.md` に定義する（SHALL）。

#### Scenario: Step B に記録手順と正規表現がある
- **WHEN** SKILL.md の Step B を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式と、`gh` で元 issue にコメントする手順、記録前に先へ進まない旨が書かれている

#### Scenario: unmanned でも免除されない
- **WHEN** SKILL.md の実行モード表または unmanned に関する記述を読む
- **THEN** 判定記録が unmanned でも必須であることが書かれている

#### Scenario: 複数記録時の選択規則と PR→issue の解決規則がある
- **WHEN** `references/spec-review.md` を読む
- **THEN** 同接頭辞のコメントが複数あるときは最新 1 件を正とする規則と、PR 本文の最初の `Closes` / `Fixes` / `Refs #N` で元 issue を解決する規則が書かれている

### Requirement: 書いた仕様は実装前に別コンテキストがレビューする
SKILL.md の Step D は、仕様化経路（opsx 利用時・openspec CLI 直叩き時の両方）で、artifact 生成の直後・`/opsx:apply`（または実装着手）の前に、実装と別コンテキストの Task サブエージェントによる仕様レビューを挟む手順を明記しなければならない（MUST）。レビューの入力は change ディレクトリの artifact・元 issue の受け入れ条件・関連する既存 `openspec/specs/`（`grep` で当たりを付けた範囲）とし（MUST）、観点・出力書式は `references/spec-review.md` を正本とする（SHALL）。レビュアーが `APPROVE` を返すまで実装に進んではならない（MUST NOT）。実行戦略が workflow 型（`/lr:e` に委ねる）の場合は longrun の Build Contract レビューをもって代替する（SHALL）。

#### Scenario: opsx 手順にレビューが挟まっている
- **WHEN** SKILL.md Step D の「仕様化する場合」のコマンド列を読む
- **THEN** `/opsx:ff` と `/opsx:apply` の間に仕様レビューの手順があり、`references/spec-review.md` を参照し、APPROVE まで apply に進まない旨が書かれている

#### Scenario: 縮退経路の記述にもレビューがある
- **WHEN** SKILL.md の「opsx コマンドが無く openspec CLI だけある場合」の記述を読む
- **THEN** artifact 生成の後に同じ仕様レビューを挟むことが書かれている

#### Scenario: workflow 型の代替が書かれている
- **WHEN** SKILL.md Step D または `references/spec-review.md` を読む
- **THEN** workflow 型では longrun の Build Contract レビューで代替する旨が書かれている

### Requirement: 仕様レビューの観点は既存 spec との整合と受け入れ条件の一意性を含む
`references/spec-review.md` は、レビュアーが検査する観点として少なくとも次の 5 つを含まなければならない（MUST）: ①受け入れ条件（Scenario の WHEN/THEN）が一意に決まりテスト可能か ②既存 `openspec/specs/` の要件と衝突・重複しないか（衝突時は spec パスと要件名を挙げる） ③リポ固有の値（時刻・名前・パス）が config や引数に出されているか ④導入先・前提環境（プラグイン・CLI・権限）が書かれているか ⑤proposal / specs / design / tasks の相互整合。レビュアーは読み取り専用で仕様ファイルを変更してはならず（MUST NOT）、既存 spec は `grep` で当たりを付けてから該当ファイルだけ読む（SHALL）。

#### Scenario: references に 5 観点がある
- **WHEN** `references/spec-review.md` を読む
- **THEN** 上記 5 観点がすべて列挙され、既存 spec との衝突時に spec パスと要件名を挙げる指示がある

#### Scenario: 読み取り専用と grep 先行が書かれている
- **WHEN** `references/spec-review.md` を読む
- **THEN** レビュアーが仕様ファイルを変更しないこと、既存 spec を全読みせず grep で当たりを付けることが書かれている

### Requirement: 仕様レビューは 2 周で確定し結果を issue に記録する
仕様レビューは初回と修正後の差分再レビュー 1 回の計 2 周を上限とし（MUST）、3 周目の例外は設けない（MUST NOT）。2 周目終了時点でも BLOCKER が残る場合は issue に `needs-approval` ラベルを付けて経緯をコメントし（MUST）、interactive モードでは AskUserQuestion で判断を仰ぎ、unmanned モードではそのサイクルを終了する（MUST）。判定結果は元 issue のコメントとして記録し、その手順は SKILL.md Step D に置く（MUST）。コメントの 1 行目は正規表現 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致し、2 行目以降に周回数・レビュアーのモデル・残課題を書く（MUST）。

#### Scenario: 2 周キャップと needs-approval が書かれている
- **WHEN** SKILL.md Step D または `references/spec-review.md` を読む
- **THEN** 上限 2 周・差分限定の再レビュー・2 周目でも BLOCKER が残れば `needs-approval` を付けて interactive は AskUserQuestion / unmanned はサイクル終了、が書かれている

#### Scenario: 結果コメントの書式と投稿手順が SKILL.md にある
- **WHEN** SKILL.md Step D を読む
- **THEN** `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` の書式と、周回数・モデル・残課題を含めて元 issue にコメントする手順が書かれている

### Requirement: 仕様レビュアーのモデルは役割で選ぶ
仕様レビューのサブエージェントは `model` を明示して spawn しなければならない（MUST）。既定は中位ティア（`opus`）とし（SHALL）、仕様が SKILL.md Step D の「重要実装の事前分類」表に当たる場合は最上位ティア（`fable`）に上げる（SHALL。分類表の正本は Step D であり、この要件に再掲しない）。残量モードは `dev-workflow-execution-strategy` の規定に従い、`FABLE_BUDGET_MODE=reserve` は自動実行のみ、`exhausted` は全経路で `opus` を上限とする（MUST）。

#### Scenario: モデル明示と既定 opus が書かれている
- **WHEN** SKILL.md Step D または `references/spec-review.md` を読む
- **THEN** `model` を明示すること、既定が `opus` であること、事前分類表に当たれば `fable` に上げることが書かれている

#### Scenario: 残量モードの扱いが既存規定と一致する
- **WHEN** SKILL.md Step D または `references/spec-review.md` の残量モードの記述を読む
- **THEN** `reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、と書き分けられている

