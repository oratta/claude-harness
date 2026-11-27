## Context

#844（archive 済みの change `2026-10-08-epic-route-single-child-orca`）は、`route` が `orca` を返す条件を「子が 2 件以上」から「子が 1 件以上」に変え、SKILL.md・README・spec から「2 件以上」の条件を外した。そのとき足した要件の最後の文が「『経路の決め方』は、件数の条件を書いてはならない」である。

この文が禁じたかったものは、次の記録から「`orca` に入る条件としての 2 件以上のような下限」だと分かる。

- 同 change の `design.md` 決定 1: 「件数の条件は『2 件以上』を『1 件以上』にするだけにする」「子 0 件は `subagent` のまま」
- 同 change の `tasks.md` 4.1 と `plugins/dev-workflow/changes/844.md`: 「『件数の条件が残っていない』は 2 件以上の条件が無いことを指す」
- 同じ要件の本文と Scenario「子が 0 件なら Orca 管理下でも subagent を返す」が、子 0 件の結果を自分で定めている
- SKILL.md の記述を固定する bats（`skill: epic run section states the routing conditions and the subagent fallback`）は、段落に `2 件以上` の語が無いことだけを見ている

## Goals / Non-Goals

**Goals:**
- MUST NOT の文と Scenario を、禁じる対象が一意に読める文面にする
- SKILL.md に `route` の実際の結果（子 0 件は `subagent`、エピックの子のセッションは `nested`）を書けるようにする

**Non-Goals:**
- `route` の挙動、bats、README を変えること
- 「経路の決め方」に `orca` になる条件としての件数の下限を戻すこと

## Decisions

### 1. 禁じる対象を「`orca` になる条件としての件数の下限」と書く

「件数の条件」という語は、`orca` に入るための下限とも、子 0 件のときの結果の説明とも読める。#844 が外したのは前者だけなので、前者だと分かる語（`orca` になる条件として・下限・2 件以上など）に置き換える。「1 件以上」という下限を SKILL.md に書くことも引き続き禁じる（`orca` になる条件は「`orca` が PATH にあり、Orca 管理のワークツリーにいる」だけで書く）。

### 2. 書いてよいものを同じ文の次に書く

子 0 件は `subagent`、エピックの子のセッションでは件数によらず `nested`、の 2 つを書いてよいと明記する。どちらも同じ要件と要件「エピックの子への注意書きと…引き継ぐ」がすでに定めている `route` の結果で、SKILL.md に書いても規範は増えない。書くことを義務にはしない（SKILL.md の文面を spec で固定しすぎないため）。

### 3. 要件ごと MODIFIED で書き写す

直すのは 2 か所の文面だけだが、archive で現行 spec に機械的に反映させるため、要件の全文を MODIFIED に置く。#844 のときに全文の書き写しを避けた理由（同じファイルを直す別の子 #827 との衝突）は、issue #827 が閉じているので今は当たらない。

## Risks / Trade-offs

- Scenario の題が変わる → 題を参照しているのは archive 済みの delta spec だけで、テストは題を参照していない
