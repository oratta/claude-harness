## Why

PR #1507（#1012）は pr-review-gate の候補探しに `--exclude <エピック番号>` と、打ち切り時の `--epic <番号> --children-only` での再実行を足したが、develop の本体が範囲外の問題を振り分ける候補探しには足していない。同じ欠陥（エピック自身が `other` の候補に返る・打ち切りで子の候補が落ちる）が残る（#1516、#1507 の指摘 F-8）。

## What Changes

- 本体の候補探しで、エピックに属するときは `--exclude` にエピックの番号も渡す
- 打ち切りが出たパスがあり、エピックに属するときは、そのパスだけ `--epic <番号> --children-only` で再実行して子の候補を足す。「1 回だけ」の規則の例外とする
- 再実行が失敗したときの扱いは `triage.md` の候補探しの段落に従うと書き、文面は重ねない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「本体は主の側にしか無い情報が要るときだけ主に聞く」の候補探しの項、およびシナリオ 2 つの追加

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（候補探しの項）
- `openspec/specs/dev-workflow-develop/spec.md`
- `plugins/dev-workflow/tests/develop-skill.bats`
- `triage.md` と `review-issue-candidates.sh` は変えない
