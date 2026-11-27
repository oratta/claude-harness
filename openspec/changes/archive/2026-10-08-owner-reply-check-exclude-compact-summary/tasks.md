## 1. スクリプト

- [x] 1.1 `owner_text()` の `isMeta` の判定と同じ箇所に、`isCompactSummary` が true の行で None を返す条件を足す（`is True` で比べる） 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:75-76（owner_text の isSidechain / isMeta の判定）
- [x] 1.2 冒頭コメントの「主の発言として数える行」の一覧に 8 番目（isCompactSummary が true でない）を足す 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:8-14

## 2. テスト

- [x] 2.1 bats に回帰テストを足す: 本文が `This session is being continued from a previous conversation…` で始まり原文を含む `isCompactSummary: true`・`isVisibleInTranscriptOnly: true`・`isMeta` なし・`origin` なしの `type: "user"` の行が exit 1 になる。本文が別の文字列（例 `<artifact-content-authored-by-others/>`）で始まる要約の行も exit 1 になる 触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:107-111（「isMeta line does not match」の直後に足す）
- [x] 2.2 bats に `isCompactSummary: false` で他の条件をすべて満たす行は exit 0 になるテストを足す 触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:24-31（「通す」の節）
- [x] 2.3 `bats plugins/dev-workflow/tests/owner-reply-check.bats` と `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が全件通ることを確かめる 触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats、plugins/dev-workflow/tests/pr-review-gate-skill.bats

## 3. 記録

- [x] 3.1 変更の記録を書く（何を足したか・なぜ・接頭辞でなく属性で判定した理由） 触る範囲: plugins/dev-workflow/changes/756.md（新規）
- [x] 3.2 spec の条件の数（①〜⑧、守備範囲の「8 条件」）は archive で `openspec/specs/dev-workflow-owner-reply-check/spec.md` に反映されることを確かめる（archive 後に `grep -n '7 条件' openspec/specs/dev-workflow-owner-reply-check/spec.md` が 0 件） 触る範囲: openspec/specs/dev-workflow-owner-reply-check/spec.md:54-56
