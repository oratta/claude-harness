# Proposal

## Why

develop と readable.md は「主の手でしかできない操作」の例に OAuth・ログイン・ダッシュボードの操作を挙げている。主は 2026-11-16 に、ログイン済みのブラウザで押せる操作（OAuth の認可ボタン、チャットの板の作成など）は主の操作に入れず、エージェントの手では通せないもの（パスワード・MFA・CAPTCHA）だけを主に回すよう指摘した。文面が古いままなので、利用側のメモリで上書きされ続けている（#1654。そのメモリは文面が直ったら消す）。

## What Changes

- `plugins/dev-workflow/skills/develop/SKILL.md` の節「主に聞かずに決めること」で、主の手でしかできない操作の例をパスワード・MFA・CAPTCHA に替え、ログイン済みのブラウザで押せる操作は入らないと書く。そうした操作でも主の名義で外へ公開・送信する・課金する・取り消せないものは、規則が主の承認を求める操作として聞くと書き分ける
- `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md` の条件「実機操作でない」と通らない例の「実機操作」の例を同じように替える（条件の数・名前は変えない）
- `output-styles/readable.md` の節 3 の主に聞く理由「主の手でしかできない操作」の例を、パスワード・MFA・CAPTCHA と人が押すと決まっているマージに替え、ログイン済みのブラウザで押せる操作は入らないと書く
- `plugins/dev-workflow/changes/1654.md` に変更の記録を書く（版は上げない）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「本体は主の側にしか無い情報が要るときだけ主に聞く」と「親が通してよい範囲の基準を 1 つのファイルに置く」の、主の手でしかできない操作（実機操作）の例
- `owner-question-style`: 要件「主に問いを返す文章の書き方の正本は readable.md の節 3 に置く」の、主に聞く理由の例

## Impact

- 文面だけの変更で、スクリプトと hook は変わらない
- `rules/communication-style.md`（readable.md の短い版）は「主の手でしかできない操作」の語だけを持ち例を挙げないので変えない
- 直さないもの: `skills/issueify/SKILL.md` の `human-only`（無人ループ単独で完結できるかの基準で、主の操作の定義とは別）、`parent-pass-criteria.md` の「ランナーの機械での操作（ログイン…）」（別の機械の操作の話）、capability-registry の「OAuth アプリ承認」（CLI でできないことの一覧）
