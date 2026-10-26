## 1. 参照の直し

- [ ] 1.1 `parent-pass-criteria.md` の「develop の SKILL.md の別セッション方式の手順 8」を「develop の references/epic.md の別セッション方式の手順 8」に直す 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:3-3
- [ ] 1.2 `commit-and-pr-operations.md` の「develop の SKILL.md の **マージ待ちの子**」を「develop の skills/develop/references/epic.md の **マージ待ちの子**」に直す 触る範囲: plugins/dev-workflow/references/commit-and-pr-operations.md:18-18
- [ ] 1.3 `README.md` の「SKILL.md に規定」を「skills/develop/references/epic.md に規定」に直す 触る範囲: plugins/dev-workflow/README.md:15-15

## 2. 検査の一覧

- [ ] 2.1 `referrers()` に `plugins/dev-workflow/skills/develop/references/epic.md` と `epic-child-stop.md` を足し、bats を通す 触る範囲: tests/owner-question-style.bats:30-40
- [ ] 2.2 受け入れ条件の grep（`grep -rn "SKILL.md.\{0,6\}\(別セッション方式の手順 8\|マージ待ちの子\)" plugins/dev-workflow --include='*.md'`）が 0 件であることを確かめる
