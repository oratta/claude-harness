## 1. spec

- [x] 1.1 守備範囲①の補足（呼び出し元）の「渡された記録で G が回して行う」を「本体から渡された値（セッション ID・日時・原文）で G が宣言コメントに記録を追記し、その記録で回して行う」に直す。触る範囲: openspec/specs/dev-workflow-owner-reply-check/spec.md:12
- [x] 1.2 archive 済みの proposal の「保留からの再開」を「新しいセッションでの再開」に直す。触る範囲: openspec/changes/archive/2026-10-10-owner-reply-check-spec-callers/proposal.md:3

## 2. 確認

- [x] 2.1 `openspec validate --specs --strict` と `tests/openspec-specs-format.bats` が通る
- [x] 2.2 `git diff origin/main -- openspec/specs/dev-workflow-owner-reply-check` に MUST・SHALL・Scenario を含む行の増減が無い（直した 1 行は MUST を含まない段落）
