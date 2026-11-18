## 1. 本体 spec を元に戻す

- [x] 1.1 `openspec/specs/dev-workflow-develop/spec.md`・`openspec/specs/dev-workflow-epic-state/spec.md`・`openspec/specs/owner-question-style/spec.md` の直接編集を、`git show bc753b97:<path> > <path>` で書き戻して取り消す（`git checkout -- <path>` / `git restore` は使わない）。本体 spec への反映は archive で行う。 触る範囲: openspec/specs/dev-workflow-develop/spec.md（全体）、openspec/specs/dev-workflow-epic-state/spec.md（全体）、openspec/specs/owner-question-style/spec.md（全体）

## 2. 回帰テストと変更記録

- [x] 2.1 `tests/openspec-specs-format.bats` が、archive 後の本体 spec に対して通ることを確かめる（段落が最初の Scenario より前にあること、守備範囲に epic-loop.md と epic-multirepo.md の両方があること）。 触る範囲: tests/openspec-specs-format.bats:1-86
- [x] 2.2 `plugins/dev-workflow/changes/1695.md` の記述が archive 後の内容と合っていることを確かめる。 触る範囲: plugins/dev-workflow/changes/1695.md:1-5

## 3. 検証と archive

- [x] 3.1 `openspec validate move-epic-must-paragraphs-to-requirement-text --type change --strict` を通す。 触る範囲: openspec/changes/move-epic-must-paragraphs-to-requirement-text/（全体）
- [ ] 3.2 (3b) の archive で delta を本体 spec に反映し、結果が commit d62d7b7c の本体 spec（空行 2 連続の整理を除く）と同じであることを `git diff d62d7b7c -- openspec/specs` で確かめる。 触る範囲: openspec/specs/（3 ファイル）
