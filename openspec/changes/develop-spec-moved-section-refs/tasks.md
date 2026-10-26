## 1. spec の文言を直す

- [ ] 1.1 `specs/` の差分（5 capability）を archive で `openspec/specs/` に反映する（`openspec archive develop-spec-moved-section-refs`）。反映後、差分に無い要件が変わっていないことを `git diff` で確かめる。触る範囲: openspec/specs/dev-workflow-develop/spec.md:1-3700、openspec/specs/dev-workflow-ci-watch/spec.md:253、openspec/specs/dev-workflow-pr-review-gate/spec.md:1641、openspec/specs/dev-workflow-pr-review-gate/spec.md:1681、openspec/specs/harness-public-private-split/spec.md:287、openspec/specs/owner-question-style/spec.md:73

## 2. 確かめる

- [ ] 2.1 `grep -n "SKILL.md.\{0,4\}「エピックの扱い」\|SKILL.md.\{0,4\}『エピックの扱い』" openspec/specs/` が 0 件であることを確かめる。触る範囲: openspec/specs/（読むだけ）
- [ ] 2.2 `openspec validate --specs --strict` が通ることと、`bats plugins/dev-workflow/tests/develop-channel-mode.bats tests/owner-question-style.bats` が通ることを確かめる。触る範囲: plugins/dev-workflow/tests/develop-channel-mode.bats（読むだけ）、tests/owner-question-style.bats（読むだけ）
