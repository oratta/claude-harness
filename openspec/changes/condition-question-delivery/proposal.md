# Proposal

## Why

develop では G がサブエージェントで主と話せない。G は段 B で条件を決められない指摘について `条件の確認待ち` の PR コメントと return の仕分け欄に質問文を残すが、質問を主に見せる役が手順書にない。G の Status は `次の段へ` で合格処理へ進むため、主が PR コメントを自分で開かない限り質問は届かず、指摘が `条件の確認待ち` のまま残る（無人運用・自動マージでも同じ）。issue #1013（PR #1002 の独立レビュー指摘 P1-F3・P2-F5・P3-F2・P4-F3）。

## What Changes

- 照合と振り分けの G の return の仕分け欄に `条件の確認待ち` の質問文があれば、G を起こした側（develop では本体）が、その質問文と PR コメントの URL を主への次の報告にそのまま載せる（無人運用では記録先にコメントする）。この義務を同じ 1 文で 3 か所に書く: `gate-runner.md`、`stages/triage.md`、`openspec/specs/dev-workflow-pr-review-gate/spec.md`。
- マージは止めないままにする（`needs-approval` を付けず、保留で return しない現行の規定を変えない）。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「条件を主に聞くときは条件だけを聞き、マージを止めない」に、質問文を主へ届ける担い手の義務を足す。

## Impact

- 実装対象: `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（「条件の答えを受け取ったとき」の段落の前に 1 段落）、`plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`（「条件を主に聞くとき」の段落）、`openspec/specs/dev-workflow-pr-review-gate/spec.md`（delta の archive で反映）、`plugins/dev-workflow/changes/1013.md`（新規）。
- 他の子（#1011〜#1016）と同じファイルを触るので、自分の issue の段落だけを直す。#1401・#580・#586・#589 の範囲には触れない。
- 受け入れ確認: 3 か所に同じ文が `grep -F` で見つかる、`openspec validate condition-question-delivery --type change --strict` の exit 0、`./scripts/test.sh` の exit 0。
