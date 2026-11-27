## ADDED Requirements

### Requirement: エピックの子はオーナーにマージを頼むとき、マージ後の連絡を頼まない

`plugins/dev-workflow/references/ci-watch.md` は、エピックの子のセッション（`epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッション）がオーナーにマージを頼んで見張りを終えるすべての箇所（「`ready` を受けたあと」の 1 の見送りラベルの分岐で親の判断を待たずにオーナーに頼むとき・3 の自動マージの workflow が無いとき・4 の表の `--until-merged` で起動した `wait` の `timeout`）について、次を 1 か所にまとめて書かなければならない（MUST）。

- 頼む文面に「マージしたら教えてください」のような、マージ後にオーナーが子のタブへ戻って知らせる依頼を書いてはならない（MUST NOT）
- 代わりに「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書く（MUST）。理由として、親の `epic-dispatch.sh wait --watch-done` が、記録先が completed で閉じて子のセッションが止まった子を完了と推定することを添える（SHALL）

エピックの子でないセッションがオーナーにマージを頼む文面は変えない。

#### Scenario: ci-watch.md にエピックの子のマージ依頼の文面の規定がある
- **WHEN** `plugins/dev-workflow/references/ci-watch.md` の「`ready` を受けたあと」を読む
- **THEN** エピックの子のセッションがオーナーにマージを頼んで見張りを終えるとき（1・3・`--until-merged` の `timeout`）に、マージ後の連絡を頼まず「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くことと、親の `wait --watch-done` が完了を推定するという理由が書かれている
