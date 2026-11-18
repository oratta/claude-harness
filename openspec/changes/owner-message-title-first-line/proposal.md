# Proposal

## Why

change `owner-request-eight-items` が正本（`~/.claude/output-styles/readable.md` の節 3）の 1 行目の書き分けを「1 行目を質問、最後の行を答え方」から「1 行目を題名（質問にしない）、2 行目を `アクション:` の行」に変える。develop の `references/epic.md`・`channel.md`・`handover.md` と spec `dev-workflow-develop` は旧い書き分けを自前で書き直しているので、そのままだと正本と食い違い、親と channel の本体は旧い形で主に頼み続ける。

## What Changes

- エピックの親が主に出す発言の規定（Orca 経路の導入部・待ちに入る通知・手順 8）を、1 行目を題名、2 行目をアクションの行にする形に合わせる。「1 行目は OK すると何が起きるかを中身で書いた質問」を「中身で書いた題名」に直す
- channel の主への発言の規定（`channel.md`）とリスク許容の案内の位置を、「最後の答え方の行」から「2 行目のアクションの行」に直す
- 引き継ぎの主への案内（`handover.md`）の「依頼の最後の答え方の行」を「アクションの行」に直す
- 状態表の規定のうち、区切りより上の最後の行を答え方のままにする文を、依頼がある報告は 1 行目を題名・2 行目をアクションの行、依頼が無い報告は 1 行目を `主がすること: なし` にしてアクションの行を書かない、の文に直す。状態表の列名 `答え方` は変えない
- 止まった子を主に上げる報告で、子の停止の記録の項目を旧い 6 段（質問・主に聞く理由・いま困っていること…）に置き直す規定を、新しい項目（題名・詳細・論点・推奨と根拠・リスク。アクションは親が書く）に置き直す規定に直し、使う項目と長さと論点なしの行数は正本を指す（`epic.md` 手順 8 の対応と「3〜4 行」）
- 該当するテストを直す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: エピックの親の発言の 1 行目の書き分け、channel の主への発言、channel のリスク許容の案内の位置、状態表と区切りの関係（依頼の有無で分ける）、止まった子の記録の項目の置き直し先

## Impact

- `plugins/dev-workflow/skills/develop/references/epic.md`・`channel.md`・`handover.md`
- `plugins/dev-workflow/tests/epic-dispatch.bats`・`develop-channel-mode.bats`・`develop-handover.bats`
- change A（`owner-request-eight-items`）の後に、同じ PR に積む
