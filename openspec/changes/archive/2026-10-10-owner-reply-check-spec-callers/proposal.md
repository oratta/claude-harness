## Why

issue #890（PR #888 のレビュー指摘）。`dev-workflow-owner-reply-check` の spec は、`owner-reply-check.sh` を回すのを pr-review-gate の G だけと書いている。#776 で、develop の本体が G に渡す前に先に回す経路（`plugins/dev-workflow/skills/develop/SKILL.md` の「保留」の行と「保留からの再開」の手順 2）が加わっており、spec の記述が実態より狭い。

## What Changes

- Purpose に、develop の本体も先に回すことを足す
- 要件「owner-reply-check.sh は会話ログに主の発言が実在するかを終了コードで返す」の守備範囲①に、呼び出し元の補足の段落を足す（守備範囲の既存の段落は 1 文字も変えない）
- MUST / MUST NOT / SHALL と Scenario は変えない。スクリプト・スキル・テストも変えない（記述の追補だけ）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-owner-reply-check`: 「owner-reply-check.sh は会話ログに主の発言が実在するかを終了コードで返す」（守備範囲①の補足の段落を足すだけ）

## Impact

- `openspec/specs/dev-workflow-owner-reply-check/spec.md` だけ。`plugins/` は変えないので変更記録（`plugins/<name>/changes/`）は書かない
