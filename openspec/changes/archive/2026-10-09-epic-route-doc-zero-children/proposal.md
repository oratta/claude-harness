## Why

`dev-workflow-develop` の要件「着手できる子が 1 件でも Orca 経路で回す」は、develop の SKILL.md の「経路の決め方」に「件数の条件を書いてはならない」と定めている。この文は #844 で、`orca` になる条件から「子が 2 件以上」を外すために入れたもので、`plugins/dev-workflow/changes/844.md` も「『件数の条件が残っていない』とは、2 件以上という条件が無いことを指す」と注記している。同じ要件は、子が 0 件のとき `route` が `subagent` を返すことも定めている。

ところが文面だけを読むと、「子が 0 件なら `subagent` になる」という `route` の結果の説明を SKILL.md に書くことまで禁じているように読める。issue #865 はその説明を SKILL.md に足すことを求めており、PR #904 のレビューでこの食い違いが指摘された。

## What Changes

- 要件「着手できる子が 1 件でも Orca 経路で回す」の MUST NOT の文を、禁じる対象が「`orca` になる条件としての子の件数の下限（2 件以上など）」であると読める文に狭める。子が 0 件のとき `subagent`、エピックの子のセッションでは件数によらず `nested` になることは書いてよいと明記する
- 同じ要件の Scenario「SKILL.md の経路の決め方に件数の条件が書かれていない」の題と THEN を、同じ意味に合わせる
- `route` の挙動と、要件のほかの文・ほかの Scenario は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「着手できる子が 1 件でも Orca 経路で回す」の MUST NOT の文と、SKILL.md の記述の Scenario の文面

## Impact

- `openspec/specs/dev-workflow-develop/spec.md`（上の 2 か所の文面だけ）
- `plugins/dev-workflow/skills/develop/SKILL.md` の「経路の決め方」の段落（子 0 件は `subagent`、エピックの子のセッションは `nested` と書く。#865）
- スクリプト・テスト・hook の変更は無い。`route` の出力は変わらない
