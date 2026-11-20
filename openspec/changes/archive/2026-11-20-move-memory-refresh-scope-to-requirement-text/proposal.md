# Proposal

## Why

`dev-workflow-memory-refresh` の整理手順の要件では、`patches:` による分類の守備範囲の段落がシナリオの後ろにあり、`openspec show --type spec --json` の要件 `text` から抜けている。#1696 の全 spec 調査で特定したこの段落を要件本文へ戻し、分類の規則とその限りを一緒に読めるようにする。

## What Changes

- 「memory-refresh スキルで承認と控えを取ってから整理する」の「`patches:` による分類の守備範囲は次のとおり。」で始まる 1 段落を、同じ要件の最初の Scenario の直前に移す。
- 段落の全文・要件名・既存シナリオ・その他の規則文を保持し、配置の回帰テストを加える。
- 両 change の実装後に全 spec を再走査し、シナリオ内に取り残した対象の規則段落が無いことを確認する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-memory-refresh`: `patches:` による分類の守備範囲の既存段落を、シナリオの `rawText` から対応する要件の `text` に移す。

## Impact

実装対象は `openspec/specs/dev-workflow-memory-refresh/spec.md` と `tests/openspec-specs-format.bats`。メモリ整理の実行手順・hook・CLI・過去の archive delta は変更しない。`move-develop-idle-rules-to-requirement-text` との仕様上の依存は無いが、#1696 の本体の決定に従って同じ worktree・1 PR の 2 番目として進める。仕様レビューは change ごとに受ける。
