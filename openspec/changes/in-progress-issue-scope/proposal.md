# Proposal

## Why

#1377 では、作業の途中に別のセッションが受け入れ条件を 3 つ足し、主が「全く別イシュー」と答えて #1382 に切り出すまでの時間とトークンが無駄になった。調査（#1390 のコメント https://github.com/oratta/claude-harness/issues/1390#issuecomment-6525107643 ）で分かった原因は、足した親セッションが主の OK を取っていたのに #1377 が作業中かを確かめず、問いにも書かなかったため、主が作業中と知らずに OK したことである。足す前に作業中かを確かめる決まりはどこにも無い。

## What Changes

- 既存 issue の受け入れ条件を足す前の決まりを、常時注入の `rules/git-commit-policy.md` に足す
  - 足す前に、`develop 開始` のコメントと紐づく PR を見て作業中かを確かめる（本文だけでは分からない）
  - 作業中なら別 issue に切り出すのを既定にする
  - それでも同じ issue に足すときは、作業中であること（PR があればその URL）を書いて主に聞く
- `rules/README.md` の一覧表の `git-commit-policy.md` の行に、上の要点を足す
- `tests/always-on-injection-scope.bats` の目印に、上の決まりの 3 点を足す
- `tests/injection-budget.txt` を、足した後の実測に合わせて引き上げる（今の実測 40,904 に対して予算 40,905 で、余裕が 1 バイトしかない）

自動検査と hook は足さない。`triage.md` の段 C（レビュー指摘の振り分け）は触らない。ここを直す話は #1390 の本文のとおり別 issue の範囲である。

## Capabilities

### New Capabilities

- `in-progress-issue-scope`: 既存 issue の受け入れ条件を足す前に作業中かを確かめ、作業中なら別 issue に切り出すか、作業中と書いて主に聞く決まり

### Modified Capabilities

なし。

## Impact

- `rules/git-commit-policy.md`（全セッション・全サブエージェントの常時注入が増える）
- `rules/README.md`
- `tests/always-on-injection-scope.bats`
- `tests/injection-budget.txt`（聖域。動かす PR は本文に理由を書き、人間がマージする）
