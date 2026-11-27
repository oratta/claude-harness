## Context

文書の記述を実装に合わせる小さな直しで、新しい設計判断は無い。決めたのは次の 2 点だけ。

## Decisions

- **`cost-ledger-timeline` の 1 行目の定めは場合分けで直す**。issue 本文は timeline の 1 行目が `区間` になる前提で書かれているが、その後の変更で `--child-issue` を渡した回は `子 issue 込み` になり `/cost` の 1 行目と一致する。一方 `--child-issue` を渡さない回の子 issue を持つ issue（子孫の問い合わせの失敗など）は `区間` のままで `/cost` と一致しない。実装（`cmd_timeline`）の場合分けをそのまま文にする
- **README の「エピックのコメントに積む行」の記述は、本文の項目に無いが同じ前提の食い違いなので直す**。`cost-ledger-timeline` の定め（子 issue 込み、`/cost` の 1 行目と同じ値）と矛盾したまま残すと、本文の項目を直しても同じ誤読が残る
- archive 済みの文書にも現行 spec と同じ直しを入れる（決定履歴が現行の spec と食い違うと読む人を誤らせるため。issue 本文の指示）。`children_usd` の 6 桁の直しも、同じ文面が 3 つの archive にあるので 3 つとも直す

## Risks / Trade-offs

- 現行 spec の MODIFIED は要件全体を書き直すため、delta spec が長い。中身の差分は上の「What Changes」の文だけ
