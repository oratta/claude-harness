## Context

参照先の `triage.md` の項目「W の修正後の再レビュー」は origin/main に実在する（`stages/triage.md`）。`hold.md` の 3-c は PR #1420 のマージ前は旧い参照のままで、マージ後に spec と一致する。

## Decisions

- 直し方は参照先の差し替えの 1 通りで、要件の他の文と Scenario は変えない（MODIFIED の本文は元の要件全文から該当 1 か所だけ置き換える）
- 手順書は触らない。`hold.md` は #1420 が持ち、`triage.md` ほかは他の子 issue と重なるため

## Risks

マージ順によっては、#1420 より先にこの change が入り、spec が手順書より一時的に先に進む。どちらが先でも害は文書の食い違いだけで、#1420 のマージで解消する。
