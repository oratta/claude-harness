# Proposal

## Why

「W の 1 周目モデルの変更は過去 PR の再実行による比較記録に基づく」要件の「issue の対象条件」は、どの issue かが曖昧。再実行の対象 PR を選ぶ基準が、PR ごとの記録先 issue に書かれた対象条件であることを明確にする（issue #619）。

## What Changes

- 当該 Requirement の 1 文で「issue の対象条件（…）」を「記録先 issue に書いた対象条件（例: …）」に置き換える。要件の意味・他の文は変えない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 上記 Requirement の文言の明確化のみ。

## Impact

`openspec/specs/dev-workflow-develop/spec.md` の 1 文のみ。
