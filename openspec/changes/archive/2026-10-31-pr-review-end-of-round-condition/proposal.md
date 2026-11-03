# Proposal

## Why

PR レビューの段 B（`skills/pr-review-gate/stages/triage.md`）は止めない指摘の振り分け表にだけ掛かる。2 周目以降の周の終わりに止める指摘が残ると、運用上起きない場面への指摘でも、順 6 の裁定か直し方の判定か順 5 に進み、W への差し戻しやオーナーへの確認が発生する。#1121 は仕様レビューにだけ同じ段を入れ、`triage.md` を変えない制約のもとで PR レビュー側を残した。本体が判定の前に指摘を捨てても、G の照合と振り分けに届かないので、直すには `triage.md` の変更が要る。

## What Changes

- `stages/triage.md` の周の終わりの段落の直後に、段落「周の終わりの止める指摘の条件」を足す。G は 2 周目以降の周の終わりに残った止める指摘の条件を、順 6・直し方の判定・順 5 の振り分けより先に確かめ、成り立つ予定が無い指摘を PR コメントに条件と理由を 1 行残して閉じる
- G が条件を決められない指摘は閉じず、既存の仕分けへ進める。新しい質問も保留も足さない
- 手順 2-1 の周の終わりの言い直し（`triage.md` の手順 3）と、周の終わりの段落の書き出しをそろえる
- `stages/pass.md` の合格処理の前提の除外に、条件で閉じた指摘を足す
- `references/fix-check.md` の節「残った指摘の条件を確かめる」の PR レビューの文を、本体の手順は当てないが G が確かめる、に直す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 周の終わりに止める指摘の条件を確かめる段を足す。合格条件の除外に条件で閉じた指摘を足す
- `dev-workflow-develop`: 「条件の確かめは PR のレビューに当てない」を、本体の手順は当てず G が `triage.md` で確かめる、に直す

## Impact

- 文書: `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`、`plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`、`plugins/dev-workflow/skills/develop/references/fix-check.md`
- テスト: `plugins/dev-workflow/tests/pr-review-gate-skill.bats`、`plugins/dev-workflow/tests/spec-decision-and-review.bats`
- 変更の記録: `plugins/dev-workflow/changes/1486.md`（新規）
- 重なり: 開いている PR #1436（#580）が同じ段落と `pass.md` の同じ文を書き換える
