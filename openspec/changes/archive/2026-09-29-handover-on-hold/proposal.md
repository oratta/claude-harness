## Why

develop の本体（オーケストレータ）は、`needs-approval` を付けて主の返事を待つと止まる。主の返事が 1 時間以上あとに来ると、本体は同じ会話（20 万トークン前後）を再開し、1 時間有効のキャッシュが切れているので会話全体を書き直す（100 万トークンあたり 8 ドル）。#509 の実測ではマージ済み PR 12 本のうち 10 本でこれが起き、15 回・2.04M トークン・16.31 ドル（1 PR あたり 1.36 ドル）だった。待ったあとは、短い引き継ぎから新しいセッションで続ければこの代金を払わずに済む。

## What Changes

- 本体が保留（`needs-approval` を付けて主の返事を待つすべての場面）で止まるとき、記録先に `引き継ぎ: 主の返事待ち` のコメントを 1 種類の書式で残す。場面は pr-review-gate の保留（リスク許容・動作確認・切り出しの確認）、PR トークン上限の exit 2、レビューの 2 周キャップ超えの 3 つ。
- 主への依頼に「返事は新しいセッションで `/develop <記録先>` と一緒に渡す」という案内を含める。1 時間以内に返事ができるなら同じセッションで続けてよく、どちらにするかは主が決める。
- 新しいセッションの本体が、記録先の最新の `引き継ぎ:` コメントとラベルから状態を組み立てて続ける手順を develop/SKILL.md に足す。前のセッションの W には SendMessage できないので、W は手渡しの扱いにする。
- `commands/develop.md` の入口で、`引き継ぎ:` コメントのある記録先を指定されたときにこの再開手順へ進める。
- pr-review-gate の保留処理（`stages/hold.md` 手順 6）の依頼文に、同じ案内を含める。

## Capabilities

### Modified Capabilities

- `dev-workflow-develop`: 保留で止まるときの引き継ぎコメントと、新しいセッションでの再開手順の要件を足す（既存要件の本文は書き換えない）。
- `dev-workflow-pr-review-gate`: 保留処理の依頼文に新しいセッションでの再開の案内を含める要件を足す。

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（1 ループの「保留」の行・保留からの再開・「PR トークン上限」の exit 2 の節）
- `plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（手順 6 の依頼文）。issue が「触るファイル」に挙げた `pr-review-gate/SKILL.md` は索引で、保留処理の実体は `stages/hold.md` にあるため、実際に直すのは `stages/hold.md`。索引の変更は不要と見込む
- `plugins/dev-workflow/commands/develop.md`
- `plugins/dev-workflow/tests/` の bats（引き継ぎの書式と各面の記述の検査）
- 受け入れ条件 2・3（実機での再開・`--cap` を小さくした停止）は実装後に PR 本文へ記録する。受け入れ条件 4（マージ後の 5 PR の計測）はマージ後にエピック #511 へコメントする。
