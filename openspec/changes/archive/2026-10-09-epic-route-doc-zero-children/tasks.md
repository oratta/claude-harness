## 1. spec の文面

- [x] 1.1 要件「着手できる子が 1 件でも Orca 経路で回す」の MUST NOT の文を、「`orca` になる条件として子の件数の下限（2 件以上など）を書いてはならない」に狭め、子 0 件は `subagent`・エピックの子のセッションは `nested` と書いてよい旨を足す。触る範囲: openspec/specs/dev-workflow-develop/spec.md（要件の本文 1 行目の最後の文）
- [x] 1.2 同じ要件の Scenario「SKILL.md の経路の決め方に件数の条件が書かれていない」の題と THEN を同じ意味に合わせる。触る範囲: openspec/specs/dev-workflow-develop/spec.md（その Scenario だけ）

## 2. SKILL.md と変更の記録

- [x] 2.1 SKILL.md「経路の決め方」の、子 0 件は `subagent` が返るという文に「（エピックの子のセッションでは件数によらず `nested`）」を添える。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md（「経路の決め方」の段落だけ）
- [x] 2.2 `plugins/dev-workflow/changes/865.md` に、spec の文面を狭めたことと根拠の所在を書く

## 3. 検証

- [x] 3.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/develop-command.bats tests/openspec-specs-format.bats tests/injection-budget.bats tests/plugin-release-convention.bats`、`scripts/lint.sh`、`openspec validate --specs --strict` が exit 0
