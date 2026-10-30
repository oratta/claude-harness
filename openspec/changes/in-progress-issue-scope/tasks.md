# Tasks

## 1. 決まりを rules に足す

- [ ] 1.1 `rules/git-commit-policy.md` の「運用の判定の詳細」の段落の前に、次の文を 1 段落で足す: 既存 issue の受け入れ条件を足す前（足してよいかを主に聞くならその前）に、`gh issue view <番号> -R <owner/repo> --json comments` の `develop 開始` のコメントと、`gh pr list -R <owner/repo> --state open --search "<番号> in:body" --json url,body` の PR のうち本文に `Closes` / `Fixes` / `Refs #<番号>` があるものを確かめる（issue の本文だけでは分からない）。どちらかがあれば作業中で、新しい issue に切り出す。同じ issue に足すなら、作業中であること（PR があればその URL）を書いて主に聞く。G がレビュー指摘の振り分けで足す場合は `dev-workflow:pr-review-gate` に従う。確かめ方: `grep -c 'in:body' rules/git-commit-policy.md` が 1 で、`grep -c closedByPullRequestsReferences rules/git-commit-policy.md` が 0。触る範囲: rules/git-commit-policy.md:7-9
- [ ] 1.2 `rules/README.md` の一覧表の `git-commit-policy.md` の行の「常時注入に残した要点」に、1.1 の要点を足す。確かめ方: 行に「受け入れ条件」が含まれる。触る範囲: rules/README.md:55-55（一覧表の `git-commit-policy.md` の行）
- [ ] 1.3 `tests/always-on-injection-scope.bats` の目印に `git-commit-policy.md` の行を 3 つ足す（作業中かを確かめること・新しい issue に切り出すこと・作業中と書いて主に聞くことの、それぞれその文にしか現れない語句）。確かめ方: `bats tests/always-on-injection-scope.bats` が通り、目印を消すと落ちるテストが新しい行にも効く。触る範囲: tests/always-on-injection-scope.bats:45-50（目印の表の `git-commit-policy.md` の行）

## 2. 予算を実測に合わせる

- [ ] 2.1 `tests/injection-budget.txt` を足した後の実測の値にする（余裕を足さない）。実測は `tests/injection-budget.bats` の失敗時の出力で読む。origin/main を取り込んだ後に実測を取り直し、値が変わっていたら合わせ直す。確かめ方: origin/main を取り込んだ後の木で `bats tests/injection-budget.bats` が通る。触る範囲: tests/injection-budget.txt:1

## 3. 全体の確認

- [ ] 3.1 既存のテストを通す。確かめ方: `bats tests/` が通る（#1390 の受け入れ条件の 3 つ目）

## Workflow follow-up

- PR 本文に、予算を動かす理由（何を足したか・なぜ他を削らず実測に合わせるか）を書く（`CLAUDE.md`「常時注入の予算」）
- `rules/` と `tests/injection-budget.txt` は聖域なので、マージは人間が行う
- PR 本文の受け入れ条件の説明で、#1390 の「該当する手順書」は `rules/git-commit-policy.md` で満たしたと書く
