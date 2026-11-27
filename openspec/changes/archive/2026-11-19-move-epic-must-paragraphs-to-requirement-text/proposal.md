## Why

PR #1690（#1684）で、エピックの手順書の置き場所を定める MUST 段落 10 件（develop 9 件・owner-question-style 1 件）を、最後の Scenario の後ろに書いた。`openspec show` は最初の Scenario より前の本文だけを要件本文として読むため、この 10 件が要件として読まれなかった。あわせて、子の引数を渡す手順の守備範囲が epic-multirepo.md だけを挙げ、通常進行の epic-loop.md が抜けていた。issue #1695。

## What Changes

- 10 件の段落を、文言を変えずに、同じ要件の最初の Scenario より前（要件本文）へ移す。移した先の要件は 3 つの capability にまたがる。
- 子の引数の守備範囲に、epic-multirepo.md に加えて epic-loop.md を挙げる。
- 移動元に残った 2 連続の空行を詰める。
- 実行時の動作と版は変えない。回帰テスト `tests/openspec-specs-format.bats` を足す。

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `dev-workflow-develop`: 9 要件の MUST 段落を要件本文へ移す
- `dev-workflow-epic-state`: 子の引数の守備範囲に epic-loop.md を足す
- `owner-question-style`: 1 要件の MUST 段落を要件本文へ移す

## Impact

`openspec/specs/` の 3 ファイルと `tests/openspec-specs-format.bats`、変更記録 `plugins/dev-workflow/changes/1695.md`。archive 済みの過去の change の delta は触らない。
