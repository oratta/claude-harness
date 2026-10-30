## Why

段 C は記録先 issue の親を `--jq .number` で取って「エピックに属するか」を決める。親が別リポジトリにあると番号だけが返り、G は無関係な issue をエピックとして候補探しに渡す。また取得の失敗（レート制限・5xx・通信断）を「親が無い」と同じに読んで段 C を飛ばし、エピックの完了条件に効く指摘が参考コメントか「捨てる」に流れる。同じ手順書の候補探しは失敗を「候補なし」と読まないと決めており、倒し方が逆だった（#1011、PR #1002 の follow-up）。

## What Changes

- 親の取得で番号とリポジトリ（`repository_url`）の両方を取る。親のリポジトリが違うときは、エピックの本文と `## 条件の答え` を親のリポジトリで読み書きし、候補探しは `--epic` なしで走らせて全候補を `other` として読む
- 「エピックに属さない」と読むのは HTTP 404 のときだけにする。それ以外の失敗は 1 回やり直し、だめなら仕分けの PR コメントに失敗を書く。段 B で「範囲で成り立つ」に当たった指摘は段 E で捨てず issue にする
- 候補探しの `--epic` の条件と、段 D・段 E の例外（親の取得が失敗し続けたとき）も、同じ要件の差分で直す。親は候補探しの前に取る
- `triage.md` の段 C の文と main の spec の同じ要件を、同じ語句で同じ commit で直す

## Capabilities

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「エピックの完了条件に効く指摘は既存 issue との関係で分ける（段 C）」の親の取得の規定。要件「候補探しのスクリプトは 1 回だけ走らせ、失敗を候補なしと読まない」の `--epic` の条件。要件「相乗りの参考コメント（段 D）と費用対効果（段 E）」の例外

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`（段 C の段落の親の取得の文、表の段 D・段 E の行、候補探しの `--epic` の箇条、段 E の段落）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`（段 C の節の検査）
- `plugins/dev-workflow/changes/1011.md`
