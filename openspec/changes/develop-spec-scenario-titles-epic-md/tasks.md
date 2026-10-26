## 1. spec の題名

- [x] 1.1 シナリオ題名 7 件の「SKILL.md」を「epic.md」に直す。触る範囲: `openspec/specs/dev-workflow-develop/spec.md:217`、`:691`、`:1925`、`:1947`、`:2206`、`:2783`、`:3248`

## 2. テストのコメント

- [x] 2.1 コメントの旧要件名を「epic.md の回し方は再開時に adopt を呼び、待ちを終えるときに clear を呼ぶ」に直す。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats:5096`
- [x] 2.2 コメントの旧要件名を「別のリポジトリの子を含むエピックの回し方を epic.md に書く」に直す。触る範囲: `plugins/dev-workflow/tests/develop-skill.bats:1159`

## 3. 検証

- [ ] 3.1 `grep -rn "SKILL.md の回し方は再開時に adopt\|回し方を SKILL.md に書く" plugins/ openspec/specs/` が 0 件
- [ ] 3.2 `openspec validate --specs --strict` の failed 件数が変更前（86）より増えない
