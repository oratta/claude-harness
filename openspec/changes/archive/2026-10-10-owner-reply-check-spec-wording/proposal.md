## Why

issue #930（PR #927 の一周目レビューで出た、マージを止めない言い回しの指摘）。`dev-workflow-owner-reply-check` の要件「owner-reply-check.sh は会話ログに主の発言が実在するかを終了コードで返す」の守備範囲①の補足（呼び出し元）に「渡された記録で G が回して行う」とあり、「記録」が 2 つの意味に読める。develop の本体が G に渡すのは値（セッション ID・日時・原文）で、「記録」は G が宣言コメントに追記する `会話で受領` の 1 行である（根拠: `plugins/dev-workflow/skills/pr-review-gate/stages/pass.md` の「会話で受けた許容（会話で受領）の真正性確認」、`openspec/specs/dev-workflow-pr-review-gate/spec.md` の「会話で受けた許容」の守備範囲①）。

## What Changes

- 守備範囲①の補足（呼び出し元）の 1 文を、「本体から渡された値（セッション ID・日時・原文）で G が宣言コメントに記録を追記し、その記録で回して行う」に直す
- MUST / MUST NOT / SHALL と Scenario、守備範囲の本体の段落（①〜④）は 1 文字も変えない。スクリプト・スキル・テストも変えない（言い回しだけ）
- あわせて、archive 済みの `2026-10-10-owner-reply-check-spec-callers/proposal.md` が develop の SKILL.md の見出しを「保留からの再開」と呼んでいた箇所を、実際の見出し「新しいセッションでの再開」に直す（規範ではない説明文の最小修正）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-owner-reply-check`: 「owner-reply-check.sh は会話ログに主の発言が実在するかを終了コードで返す」（守備範囲①の補足の 1 文の言い回しを直すだけ。規範の意味は変えない）

## Impact

- `openspec/specs/dev-workflow-owner-reply-check/spec.md` と、archive 内の proposal 1 行だけ。`plugins/` は変えないので変更記録（`plugins/<name>/changes/`）は書かない
