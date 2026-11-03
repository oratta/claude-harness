## Why

エピックの回し方などを SKILL.md から `skills/develop/references/epic.md` へ移した（#1241、#1337 で spec の本文を直した）あとも、`openspec/specs/dev-workflow-develop/spec.md` のシナリオ題名 7 件が「SKILL.md の回し方…」「SKILL.md に…が書かれている」のまま残っている。題名を見て手順書を探した人が SKILL.md に行き、中身のある epic.md にたどり着けない。また #1241 で改名した要件名 2 件を、`epic-dispatch.bats`・`develop-skill.bats` のコメントが旧名のまま書いている。

## What Changes

- `openspec/specs/dev-workflow-develop/spec.md` のシナリオ題名 7 件の先頭「SKILL.md」を「epic.md」に直す（archive 後の spec を直接直す。本文の WHEN/THEN は変えない）。
- `plugins/dev-workflow/tests/epic-dispatch.bats`・`develop-skill.bats` のコメントの旧要件名 2 件を改名後の名前に直す。
- 題名を直さない 9 件（SKILL.md に中身が残る節を指すもの）は design.md に理由を書く。
- この change は delta spec を持たない（題名だけの変更は MODIFIED で書けない。design.md の Decisions）。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

なし（`dev-workflow-develop` の要件の規範は変わらない。表記だけを直す）

## Impact

`openspec/specs/dev-workflow-develop/spec.md` の題名行 7 件と、bats 2 本のコメント 2 行。実行時の動きは変わらない。
