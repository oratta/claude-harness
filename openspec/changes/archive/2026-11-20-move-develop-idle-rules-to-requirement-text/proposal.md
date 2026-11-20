# Proposal

## Why

`dev-workflow-develop` の子・親の待機後の返事に関する 2 要件で、既存の SHALL / MUST の規則段落がシナリオの後ろにあり、`openspec show --type spec --json` の要件 `text` から抜けている。#1696 の全 spec 調査で特定した 2 段落を要件本文へ戻し、要件だけを読んでも規則を把握できるようにする。

## What Changes

- 「時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める」の「根拠には、2026-10-23 の子のログで、」で始まる 1 段落を、同じ要件の最初の Scenario の直前に移す。
- 「親が長く待ったあとは親の表で続けるか起動し直すかを決める」の「親の状態はエピックと子 issue のコメント・依存グラフ・子の状態記録から復元できる」で始まる 1 段落を、同じ要件の最初の Scenario の直前に移す。
- 2 段落の全文・要件名・既存シナリオ・その他の規則文を保持し、配置の回帰テストを加える。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 待機後の子・親への返事に関する既存の規則段落を、シナリオの `rawText` から対応する要件の `text` に移す。

## Impact

実装対象は `openspec/specs/dev-workflow-develop/spec.md` と `tests/openspec-specs-format.bats`。CLI・実行時の返事の規則・過去の archive delta は変更しない。`move-memory-refresh-scope-to-requirement-text` とは独立して検証できるが、#1696 の本体の決定に従って同じ worktree・1 PR で本 change から順に進める。仕様レビューは change ごとに受ける。
