## Why

PR #268 でレビューと修正の往復が 5 周続き、1 本の PR に約 1.2 億トークンを使った（issue #281）。pr-review-gate には「既定 2 周・3 周目は新規の高深刻度 blocking のみ・マージ後に直せるものは blocking にしない」という収束ルールが既にあったが、ゲート実行者（G）がレビュアーの深刻度ラベルをそのまま blocking と扱い、ルールを適用しなかった。ルールが無かったのではなく適用されなかったので、ルールを足すのではなく、2 周目の終わりに誰が何をするかを手順として固定し、適用を避けられない形にする。方針は 2026-09-11 に主が承認済み（issue #281 のコメント「方針の確定」の PR-A）。

## What Changes

- 2 周目の結果を受け取った直後に、G が残った指摘ごとに「受け入れ条件または仕様の守備範囲のどの文に違反するか」を引用する手順を加える。レビュアー（Codex など）の深刻度ラベルは参考にとどめ、blocking かどうかは引用できるかで決める
- 引用できない指摘は follow-up issue に切り出し、`passed` の判定へ進む（既存の「マージ後に issue で直せるものは blocking にしない」を実行手順にしたもの）
- 引用できる指摘が 1 件でも残れば 3 周目に入らず、`needs-approval` を付けて止まり、主に「続けるか、範囲外として閉じるか」の 1 択を出す。無人運用（loop-dev-agent）でも同じく止まる。**BREAKING**（運用上）: 従来は「新規の高深刻度 blocking」なら G の判断で 3 周目に入れたが、自動では入れなくなる
- W の修正が方式の書き換え（修正の差分が前周の指摘の行数を大きく超える）だった場合、次の再レビューは差分限定ではなく全体レビューにする。周回は 1 周目に戻さず、そのまま数える
- 決める役（`dev-workflow:decider`）の裁定は既存の出力契約（原因分類・直し方・次のモデル）のままとし、キャップの判定には関与させないことを明記する
- `gate-runner.md` の failed 節と return の `周回:` 欄を上記に揃える

範囲外: R1 の観点に守備範囲を足すこと（#287）、PR 単位のトークン累計で止める仕組み（#288）、指摘 1 件の固定書式（#349）、`agents/decider.md` の出力契約。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 収束ルールの要件を変える。3 周目の許可条件（新規の高深刻度 blocking）を「2 周目終了時に違反文を引用できる指摘が残れば `needs-approval` で停止」に置き換え、再レビューの差分限定に「方式の書き換え後は全体レビュー（周回は数える）」の例外を加え、決める役がキャップ判定に関与しないことと G の指示書の対応箇所を要件にする

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`: 「収束ルール（レビュー周回のキャップ）」節と、手順 1 の「再レビューの範囲は差分限定」の記述
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`: failed 節、return の `周回:` 欄、保留（`needs-approval`）の return
- `openspec/specs/dev-workflow-pr-review-gate/spec.md`（archive 時に delta を反映）
- テスト: `plugins/dev-workflow/tests/pr-review-gate-skill.bats`（収束ルールの固定文言）、`plugins/dev-workflow/tests/develop-roles.bats`（gate-runner の failed 返却と `周回:` 欄）、`plugins/dev-workflow/tests/model-escalation-policy.bats`（「2 周キャップ」「最終周」。手順 2-2 は触らないので影響しない見込み）
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の version bump、`CHANGELOG.md`
- 運用: 無人運用で 2 周目に引用できる指摘が残った PR は自動で片付かず主の判断待ちになる（主が承認済みのトレードオフ）
