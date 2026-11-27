# Proposal

## Why

#1725 の一般化した配置検査が、`dev-workflow-develop` の依存待ちに関する既存の規則段落をシナリオの後ろで検出した。要件本文だけで依存待ちの優先規則を読めるようにし、既存 spec の変更を OpenSpec change 経由で反映するため、最初の「仕様化しない」の判断を取り直す。

## What Changes

- 要件「親は依存待ちの子を動いている子から外し既存操作で再起動する」の最後の Scenario の後ろにある「依存待ちに限り、この要件は、」で始まる段落を、同じ要件の最初の Scenario の直前へ移す。
- 段落の文言・要件名・全5シナリオ・その他の規則文を保持し、要件全文を MODIFIED delta に含める。
- main spec への直接編集は戻し、R1 承認後の apply 段で archive により反映する。既に追加済みの一般配置検査で、反映前に1件失敗し、反映後に成功することを確認する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 依存待ちの優先規則の既存段落を、最後のシナリオの `rawText` から同じ要件の `text` へ移す。

## Impact

反映先は `openspec/specs/dev-workflow-develop/spec.md` の1要件。#1725 で追加済みの `tests/openspec-specs-format.bats` の一般配置検査を検証に使う。親・子の実行手順、CLI、規則の内容、過去の archive delta は変更しない。単一 capability の1段落であり、分割は不要。文言合わせの条件が issue 本文に揃っていないため、artifact 一式と R1 レビューの経路で進める。
