## Why

PR #1002 の段 C の候補探しには 2 つの欠陥がある（#1012）。(1) エピックの本文に指摘のファイル名が書かれていると、エピック自身が `other` の候補として返り、G が段 C のコメントの相手や「エピックの外の issue」にエピックを選べる。(2) `SKILL.md` や `spec.md` のように多くの open issue に出るパスでは結果が 15 件で打ち切られ、エピックの子が 15 件の外に落ちて、G が新しい子 issue を作ってしまう。

## What Changes

- `--exclude` に、いまの PR の番号・記録先が issue ならその番号に加え、エピックに属する PR ではエピックの番号を渡す
- 結果に「(15 件で打ち切り。ほかにも一致あり)」が出たパスがあり、エピックに属する PR のときは、そのパスだけ `--epic <番号> --children-only` を付けてもう 1 回走らせ、子の候補を足す。「1 回だけ」にこの例外を足す
- `stages/triage.md` と spec を同じ commit で直す

## Capabilities

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「候補探しのスクリプトは 1 回だけ走らせ、失敗を候補なしと読まない」

## Impact

`plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`（候補探しの段落と段 B 後の表の行）、`openspec/specs/dev-workflow-pr-review-gate/spec.md`。スクリプト `review-issue-candidates.sh` は変えない（`--children-only` は既にある）。
