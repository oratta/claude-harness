# dev-workflow-spec-review Specification

## Purpose
develop スキルが、仕様化要否の判断を機械照合できる書式で記録先（元 issue、無ければ Draft PR）に残し、書いた仕様（openspec の change artifact）を実装前に別コンテキストが審査してから実装に入ることを規定する。longrun の Build Contract レビューを dev-workflow のパイプラインに置き直したもの。
## Requirements
### Requirement: 仕様化要否の判定結果を固定書式で issue に記録する
develop スキルの W の指示書（`references/roles/worker.md`）は、仕様化要否を判定した直後に、その結果を記録先（元 issue。issue が無い場合は Draft PR）のコメントとして記録する手順を明記しなければならない（MUST）。コメントの 1 行目は正規表現 `^仕様化判断: (する|しない)$` に完全一致し（装飾・全角コロン・末尾句点を含めない）（MUST）、2 行目以降に判定理由（`references/decision-criteria.md` のどの条件に当たったか）を書く（MUST）。同接頭辞のコメントが複数あるときは作成日時が最新の 1 件を正とし（SHALL）、この記録は interactive / unmanned の両モードで行い（MUST）、記録せずに分割判定・実装へ進んではならない（MUST NOT）。後続の照合で PR から元 issue を解決する規則（PR 本文中で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`、大文字小文字不問。見つからなければ PR 自身のコメントを見る）は `references/roles/spec-reviewer.md` の「判断記録の契約」に定義する（SHALL）。

#### Scenario: worker.md に記録手順と正規表現がある
- **WHEN** `references/roles/worker.md` の仕様化判断の節を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式と、`gh` で記録先にコメントする手順、記録前に先へ進まない旨が書かれている

#### Scenario: unmanned でも免除されない
- **WHEN** SKILL.md の実行モード表または unmanned に関する記述を読む
- **THEN** 判定記録が unmanned でも必須であることが書かれている

#### Scenario: 複数記録時の選択規則と PR→issue の解決規則がある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 同接頭辞のコメントが複数あるときは最新 1 件を正とする規則と、PR 本文の最初の `Closes` / `Fixes` / `Refs #N` で元 issue を解決し、無ければ PR 自身のコメントを見る規則が書かれている

### Requirement: 書いた仕様は実装前に別コンテキストがレビューする
develop スキルは、仕様化経路（opsx 利用時・openspec CLI 直叩き時の両方）で、W が artifact を生成して return した直後・W を再開して `/opsx:apply`（または実装着手）する前に、本体が spawn する R1（`references/roles/spec-reviewer.md` を読む、実装と別コンテキストのサブエージェント）による仕様レビューを挟まなければならない（MUST）。レビューの入力は change ディレクトリの artifact・記録先の受け入れ条件・関連する既存 `openspec/specs/`（`grep` で当たりを付けた範囲）とし（MUST）、観点・出力書式は `references/roles/spec-reviewer.md` を正本とする（SHALL）。R1 が `APPROVE` を返し記録されるまで W を実装に進めてはならない（MUST NOT）。

#### Scenario: 1 ループにレビューが挟まっている
- **WHEN** SKILL.md の 1 ループを読む
- **THEN** W の `/opsx:ff` と W の再開（apply）の間に R1 の仕様レビューがあり、`references/roles/spec-reviewer.md` を参照し、APPROVE の記録まで apply に進まない旨が書かれている

#### Scenario: 縮退経路の記述にもレビューがある
- **WHEN** `references/roles/worker.md` の「opsx コマンドが無く openspec CLI だけある場合」の記述を読む
- **THEN** artifact 生成の後に本体へ return して同じ仕様レビューを受けることが書かれている

### Requirement: 仕様レビューの観点は既存 spec との整合と受け入れ条件の一意性を含む
`references/roles/spec-reviewer.md` は、レビュアーが検査する観点として少なくとも次の 5 つを含まなければならない（MUST）: ①受け入れ条件（Scenario の WHEN/THEN）が一意に決まりテスト可能か ②既存 `openspec/specs/` の要件と衝突・重複しないか（衝突時は spec パスと要件名を挙げる） ③リポ固有の値（時刻・名前・パス）が config や引数に出されているか ④導入先・前提環境（プラグイン・CLI・権限）が書かれているか ⑤proposal / specs / design / tasks の相互整合。レビュアーは読み取り専用で仕様ファイルを変更してはならず（MUST NOT）、既存 spec は `grep` で当たりを付けてから該当ファイルだけ読む（SHALL）。

#### Scenario: spec-reviewer.md に 5 観点がある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 上記 5 観点がすべて列挙され、既存 spec との衝突時に spec パスと要件名を挙げる指示がある

#### Scenario: 読み取り専用と grep 先行が書かれている
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** レビュアーが仕様ファイルを変更しないこと、既存 spec を全読みせず grep で当たりを付けることが書かれている

### Requirement: 仕様レビューは 2 周で確定し結果を issue に記録する
仕様レビューは初回と修正後の差分再レビュー 1 回の計 2 周を上限とし（MUST）、3 周目の例外は設けない（MUST NOT）。2 周目終了時点でも BLOCKER が残る場合は記録先に `needs-approval` ラベルを付けて経緯をコメントし（MUST）、interactive モードでは本体が AskUserQuestion で判断を仰ぎ、unmanned モードではそのサイクルを終了する（MUST）。判定結果は記録先のコメントとして記録しなければならず（MUST）、その書式は `references/roles/spec-reviewer.md` に置く（SHALL）。コメントの 1 行目は正規表現 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致し、2 行目以降に周回数・レビュアーのモデル・残課題を書く（MUST）。

投稿者は R1 の spawn 方法で分かれる（SHALL）。`general-purpose` に `model` を明示して spawn した R1 は、従来どおり自分で `gh issue comment` / `gh pr comment` を実行して投稿する。`subagent_type: dev-workflow:decider` で spawn した R1 は `Bash` を持たず投稿できないため、**本体が R1 の return を同じ書式で代理投稿しなければならない**（MUST）。代理投稿でも書式・記録先・「APPROVE が記録されるまで実装に進まない」の判定は変わってはならない（MUST NOT）。同様に decider として起こした R1 は記録先を `gh` で読めないため、**呼び出し側が記録先の本文と関連コメント（受け入れ条件・`仕様化判断:` の記録）を入力文に貼り付けなければならない**（MUST）。`references/roles/spec-reviewer.md` は、レビュアーへの入力と結果の記録の節にこの 2 経路（自分で投稿する場合と本体が代理投稿する場合）を書き分けなければならない（MUST）。

#### Scenario: 2 周キャップと needs-approval が書かれている
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` を読む
- **THEN** 上限 2 周・差分限定の再レビュー・2 周目でも BLOCKER が残れば `needs-approval` を付けて interactive は AskUserQuestion / unmanned はサイクル終了、が書かれている

#### Scenario: 結果コメントの書式と投稿手順が spec-reviewer.md にある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` の書式と、周回数・モデル・残課題を含めて記録先にコメントする手順が書かれている

#### Scenario: decider として起こした R1 は本体が代理投稿する
- **WHEN** 本体が R1 を `subagent_type: dev-workflow:decider` で spawn し、R1 が判定を return する
- **THEN** R1 は `gh` を実行せず判定と理由を return し、本体が同じ 1 行目書式で記録先にコメントする

#### Scenario: decider として起こした R1 には記録先の本文が入力で渡る
- **WHEN** `references/roles/spec-reviewer.md` の「レビュアーへの入力」を読む
- **THEN** decider 経路では記録先の本文と関連コメントを呼び出し側が入力文に貼ること、`gh` で自分で取りに行かないことが書かれている

### Requirement: 仕様レビュアーのモデルは役割で選ぶ
R1 は本体が `model` を明示して spawn しなければならない（MUST）。既定は中位ティア（`opus`）とし（SHALL）、仕様が `references/roles/worker.md` の「重要実装の事前分類」表のマージ権限・層間契約・課金/法務に当たる場合は、`model: fable` を付けた `general-purpose` ではなく `subagent_type: dev-workflow:decider` で spawn しなければならない（MUST。聖域パスだけでは上げない。分類表の正本は worker.md であり、この要件に再掲しない）。`general-purpose` などの実行役の種別に `model: fable` を付ける spawn は `scripts/agent-model-guard.sh` に拒否される（SHALL）。残量モードは `dev-workflow-execution-strategy` の規定に従い、`FABLE_BUDGET_MODE=reserve` は自動実行のみ、`exhausted` は全経路で `opus` を上限とする（MUST）。

#### Scenario: モデル明示と既定 opus が書かれている
- **WHEN** SKILL.md の「モデル」節または `references/roles/spec-reviewer.md` を読む
- **THEN** `model` を明示すること、既定が `opus` であること、マージ権限・層間契約・課金/法務に当たれば `dev-workflow:decider` で spawn し、聖域パスだけでは上げないことが書かれている

#### Scenario: 残量モードの扱いが既存規定と一致する
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` の残量モードの記述を読む
- **THEN** `reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、と書き分けられている

