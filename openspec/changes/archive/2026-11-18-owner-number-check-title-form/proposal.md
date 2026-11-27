# Proposal

## Why

change `owner-request-eight-items` が正本（`~/.claude/output-styles/readable.md` の節 3）の 1 行目の書き分けを「1 行目を質問、最後の行を答え方」から「1 行目を題名（質問にしない）、2 行目を `アクション:` の行」に変える。番号の検査の hook（`owner-message-number-check.sh`）は、1 行目が `？` で終わるか最後の行に答え方の語があるときだけ発言を主への依頼として拾うので、新しい形で書いた依頼はどちらにも当たらず、番号が残っていても差し戻されなくなる。

## What Changes

- 発言の並びの 2 番目の行（前後の空白と `*` を除く）が `アクション` で始まり `:` か `：` が続くとき、主への依頼として拾う条件を足す
- 旧い 2 つの条件（1 行目が質問・区切りより上の最後の行に答え方の語）は狭めずに残す（旧い形で書かれた発言を拾い続けるため）
- スクリプトの冒頭の見分け方の説明とテストを、足した条件に合わせる
- 差し戻しの理由の文は変えない（指す先の「ほかの決まり」の段落と 1 行目の書き分けの段落は、change A のあとも節 3 に残る）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-owner-message-number-check`: 要件「主に判断・確認・操作を求める発言だけを対象にする」に、2 行目のアクションの行で対象に入る条件を足す

## Impact

- `plugins/dev-workflow/scripts/owner-message-number-check.sh`（見分け方の説明と判定）
- `plugins/dev-workflow/tests/owner-message-number-check.bats`
- change A（`owner-request-eight-items`）・B（`owner-message-title-first-line`）の後に、同じ PR に積む
