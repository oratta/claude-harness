## ADDED Requirements

### Requirement: G は段ごとに要るファイルだけを読む

`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` は、`skills/pr-review-gate/SKILL.md` 全体を読む指示を持ってはならない（MUST NOT）。代わりに、G がどの時点でどのファイルを読むかを表で示さなければならない（MUST）。表は少なくとも次を含む: 起動したら `stages/prepare.md`、従来経路でレビューを自分で起動するときだけ `stages/review-run.md`、レビュー結果に指摘が残っていたら `stages/triage.md`、宣言を書く前に `declarations.md`、合格処理で `stages/pass.md`、主のリスク許容が要る・保留に入る・保留から再開するときは `stages/hold.md`。

gate-runner.md に残すのは、役割と入力、レビュー経路の判別、上の表、一周目の三表の機械照合と補足レビュー結果の受領、return の共通部分（1 行目の宣言と Gate Result の共通欄）、再開の振り分け、モデルとコンテキスト上限とする（MUST）。特定の段でしか使わない G の規則（needs-reviewer の payload、従来経路のレビュー実行者の表と Codex の起動、Status ごとの return 書式、再開のうち段に固有のもの）は、その段のファイルの「G として動くとき（develop）」節に置かなければならない（MUST）。

#### Scenario: SKILL.md 全体を読む指示が無い

- **WHEN** gate-runner.md を読む
- **THEN** 「`pr-review-gate/SKILL.md` を Read し、手順 1〜5 を実行する」に当たる指示が無く、段ごとに読むファイルの表がある

#### Scenario: return の書式が段のファイルにある

- **WHEN** `stages/pass.md`・`stages/triage.md`・`stages/hold.md`・`stages/prepare.md` の「G として動くとき」節を読む
- **THEN** それぞれに passed・failed / needs-decider / review-incomplete・保留・needs-reviewer の return 書式がある

#### Scenario: 読み込み量の実測

- **WHEN** この変更を develop で PR にし、`scripts/subagent-context-audit.sh --by-role` で G の `docs_median` を測る
- **THEN** 実測値が PR 本文に記録されている（目標は 15K トークン以下。超えたときは実測値とファイルごとの内訳と follow-up issue の URL が記録されている）

### Requirement: W の (3b) は宣言の書式ファイルを指す

`plugins/dev-workflow/skills/develop/references/roles/worker.md` の (3b) の仕様宣言は、書式と `対象 HEAD:` 規約の正本として `skills/pr-review-gate/declarations.md` を指さなければならない（MUST）。`skills/develop/SKILL.md` の「仕様宣言は記録先ではなく常に PR コメントに置く」の書式の正本の参照も同じファイルを指す（MUST）。

#### Scenario: W の参照先

- **WHEN** worker.md の (3b) を読む
- **THEN** 仕様宣言の書式の正本として `skills/pr-review-gate/declarations.md` が書かれている

### Requirement: レビュー担当に渡す指示は reviewer-brief.md を指す

gate-runner.md の needs-reviewer の payload（`stages/prepare.md` に移ったもの）と `plugins/dev-workflow/references/subagent-waiting.md` の Codex 指示文の雛形は、レビュアーに渡す指示として `skills/pr-review-gate/stages/reviewer-brief.md` のレビュアー向け指示ブロックを指さなければならない（MUST）。

#### Scenario: needs-reviewer の payload

- **WHEN** `stages/prepare.md` の needs-reviewer の payload を読む
- **THEN** 「レビュアーに渡す指示」の行が `stages/reviewer-brief.md` のレビュアー向け指示ブロックを指している

### Requirement: Codex に渡す正本の一覧を段のファイルに合わせる

`plugins/dev-workflow/scripts/codex-develop.py` は、phase `gate` の request に `skills/pr-review-gate/SKILL.md`・`stages/` の 6 ファイル・`declarations.md` を正本として含めなければならない（MUST）。phase `review` の request には `skills/develop/references/roles/gate-runner.md` と `skills/pr-review-gate/stages/reviewer-brief.md` を正本として含めなければならない（MUST）。

#### Scenario: review phase の正本

- **WHEN** `codex-develop.py` で phase `review` の request を作る
- **THEN** prompt に `CANONICAL SOURCE skills/pr-review-gate/stages/reviewer-brief.md` と `CANONICAL SOURCE skills/develop/references/roles/gate-runner.md` があり、`変更点の一覧`・`照合表`・`ハンク被覆` を含む

#### Scenario: gate phase の正本

- **WHEN** `codex-develop.py` で phase `gate` の request を作る
- **THEN** prompt に索引・6 つの段のファイル・`declarations.md` の `CANONICAL SOURCE` 行がある
