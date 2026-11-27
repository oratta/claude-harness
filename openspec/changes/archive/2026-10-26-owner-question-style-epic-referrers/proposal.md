## Why

#1219 で develop の SKILL.md の「エピックの扱い」節と「エピックの子が主の返事を待って止まるとき」節を `skills/develop/references/epic.md` と `skills/develop/references/epic-child-stop.md` へ移した。移した手順 8 の報告や記録の形が古い問いの型に戻っても、`tests/owner-question-style.bats` の `referrers()` に移設先が無いため検査に引っかからない。あわせて、移した節を「SKILL.md の節」として名指しする参照が 3 文書に残っている（issue #1250）。

## What Changes

- `tests/owner-question-style.bats` の `referrers()` に `epic.md` と `epic-child-stop.md` を足す
- spec `owner-question-style` の要件「主に問いを返す各所は正本を参照し、固有の事柄だけを残す」の一覧に、同じ 2 ファイルを足す（`referrers()` のコメントがこの一覧を指すので揃える）
- `parent-pass-criteria.md` の 3 行目、`commit-and-pr-operations.md` の 18 行目、`README.md` の 15 行目の参照を、移設先のファイルに直す（spec の外の文書の直しで、仕様の変更ではない）

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `owner-question-style`: 要件「主に問いを返す各所は正本を参照し、固有の事柄だけを残す」の一覧に、移設先の 2 ファイルを足す。既存の SKILL.md の項目の説明文は #1241（spec 側の名指しの食い違い）が扱うので、ここでは触れない

## Impact

- `tests/owner-question-style.bats`、`openspec/specs/owner-question-style/spec.md`（archive 時）、`plugins/dev-workflow/` 配下の文書 3 つ
