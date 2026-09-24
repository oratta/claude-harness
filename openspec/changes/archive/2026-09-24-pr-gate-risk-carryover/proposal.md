## Why

pr-review-gate は宣言を「対象 HEAD: <今の HEAD>」で出し直すことを求めるが、前の HEAD で得た主のリスク許容を新しい HEAD に引き継いでよいかを書いていない。そのためゲート担当は main の取り込みだけで HEAD が動いたときも `needs-approval` で止まり、主に同じ確認を繰り返す（PR #428 / issue #420 では、主が許容したあと main が進むたびに同じ確認が 2 回目・3 回目と発生した）。main に PR が次々入る時期ほど、許容を要する PR がマージまでたどり着けなくなる。

## What Changes

- pr-review-gate の手順 3（リスク宣言）に「前の HEAD の許容を引き継いでよい条件」と「引き継いだ宣言の書式」を足す。条件を満たすときは主に聞き直さず、新しい HEAD の宣言に `主の回答: 許容（引き継ぎ） — <元の回答リンク>` と引き継ぎの根拠を書く。満たさないときは今までどおり主に聞く
- 許容が必要な場合の宣言の雛形に、許容したリスクの根拠ファイルを列挙する行（`- 根拠ファイル:`）を足す。この行が無い宣言からは引き継げない
- 差分の範囲（main の取り込みとその衝突解消だけか）と根拠ファイルの無変更は、新しいスクリプト `plugins/dev-workflow/scripts/risk-carryover-check.sh` が git の履歴から機械で判定する。元の許容の真正性と、リスクの中身が同じであることはゲート担当が確かめる
- 引き継ぎの元になる許容は、真正性確認が済んだ主の直接の回答に限る。引き継ぎの記録は元の直接の回答を指し、引き継ぐたびに元の回答の真正性を確かめ直す
- 手順 5 の合格条件の表と、手順 6 の保留からの復帰の表に、引き継いだ宣言の扱いを足す
- G の指示書（`gate-runner.md`）の取り直しの節に、許容済み PR の HEAD が動いたときは引き継ぎを先に試すことを足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: リスク許容の引き継ぎ条件・書式・機械判定スクリプト・捏造防止の条件を要件として足す。許容が必要な場合の雛形に根拠ファイル行を足す

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（手順 3・手順 5・手順 6 の表）
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（取り直し時の扱い）
- 新規 `plugins/dev-workflow/scripts/risk-carryover-check.sh` と `plugins/dev-workflow/tests/risk-carryover-check.bats`
- 既存 bats（`pr-review-gate-skill.bats` 等）に SKILL.md の記述の検査を足す
- `plugins/dev-workflow/changes/441.md`
- `対象 HEAD:` 規約（宣言 1 行目・2 行目の文言形式）と auto-merge workflow は変えない
