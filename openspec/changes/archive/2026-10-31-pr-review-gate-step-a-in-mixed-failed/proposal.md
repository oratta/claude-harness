# Proposal

## Why

PR #1002 は、1 周目の段 A の指摘（止める指摘ではないが W が直す指摘）を止める指摘と同じ 1 回の failed に含めると決めた。ところが切り出しの確認の復帰と順 3 の再レビュー不要の文は、段 A に触れていない。そのため段 A の指摘が W に戻らない、または直しが再レビューされずに閉じると読める。

## What Changes

- 切り出しの確認で主が「切り出す」と答えたあと、ほかに止める指摘も、1 周目の段 A に当たる未解決の指摘も無いときだけ手順 3 以降へ進む。1 周目の段 A に当たる未解決の指摘が残っていれば、`agent-review:failed` で W に戻す
- 同じ failed に順 3 と段 A の指摘が含まれていれば、順 2・順 4 が含まれるときと同じに、差分限定の再レビューを行い、周を 1 つ消費する。failed の `次の段:` は `前提確認と重さ判定` にする
- 順 3 の照合の省略（順 3 だけで戻したとき）と未処理の順 6 を先に扱う処理順は変えない

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「一覧の一致で閉じる（順 3）」と「主への質問は推奨と見積もり付きで、その周で聞く（順 5）」を変える

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（復帰表の切り出しの確認の行、保留の解除の入力）
- `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`（順 3 の再レビュー不要の文、failed の `次の段:`）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`
- 開いた PR #1436 が hold.md と triage.md を分割しているので、先にマージされたら移動先の文を同じように直す
