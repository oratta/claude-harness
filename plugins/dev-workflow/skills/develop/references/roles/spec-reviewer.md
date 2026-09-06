# R1（仕様レビュアー）の指示書 — develop スキル

`/opsx:ff`（または openspec CLI 直叩き）で W が生成した change の artifact を、**実装に入る前に**実装と別コンテキストで審査する工程の正本。longrun の Build Contract レビュー（plan.md を実装前に審査する工程）を dev-workflow のパイプラインに置き直したもの。仕様レベルの穴（既存規約との整合・config に出すべき固有値・導入先の前提）を実装レビューに持ち込まないための工程で、実装 diff のレビュー（pr-review-gate。G の担当）とは対象が違う。

R1 は develop の本体が spawn するサブエージェント（W とは別コンテキスト）。R1 が読むのは**このファイル**と、本体から渡される change ディレクトリ・記録先。

## 前提

- `gh`（記録先＝issue または Draft PR にコメントを投稿する権限）
- Agent ツール（本体側。サブエージェントは孫を spawn できないので、R1 は本体が直接 spawn する）
- opsx コマンドまたは openspec CLI（どちらも無いリポは仕様化経路が無いので、この工程も発生しない）

## 判断記録の契約（W の記録・R1 の記録・後続の照合が共有する）

後続の pr-review-gate（G）が「仕様化の判断が記録されているか」「最新の仕様レビューが APPROVE か」を機械照合するための取り決め。W の仕様化判断の投稿・R1 の結果投稿・照合側は同じ規則を使う。

| 項目 | 規則 |
|---|---|
| 判断記録の 1 行目 | 正規表現 `^仕様化判断: (する|しない)$` に完全一致。太字・全角コロン・末尾句点などの装飾を含めない |
| レビュー結果の 1 行目 | 正規表現 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致。照合側は**最新のレビュー結果**が APPROVE であることを見る（件数ではない） |
| 記録先 | 元 issue のコメント。issue が無い依頼では Draft PR 自身のコメント（develop の入口 0 が W に先に作らせる） |
| 照合のしかた | `gh api --paginate --slurp … | jq -r 'add | …'` で**全ページ**を取り（`--slurp` は `--jq` と併用できない）、`body | split("\n")[0] | test("^…$")` のように**1 行目を切り出してから**正規表現に掛け、`last` で最新 1 件を選ぶ（jq の `^` `$` は文字列全体の先頭・末尾にしか掛からない。コメントは 30 件でページが切れる） |
| 同接頭辞のコメントが複数あるとき | 作成日時が**最新の 1 件**を正とする（判定のやり直しを許す） |
| PR から元 issue を解決する規則 | PR 本文中で**最初に現れる** `Closes #N` / `Fixes #N` / `Refs #N`（大文字小文字不問）。見つからなければ **PR 自身のコメント**を記録先として見る（issue 参照が無く PR にも記録が無ければ「記録なし」扱い） |

## R1 の spawn（本体が行う。R1 は確認だけ）

- **モデルは必ず明示する**（Agent ツールの `model` パラメータ）。既定は `opus`。仕様が `references/roles/worker.md` の「重要実装の事前分類」表の `fable` 行（マージ権限・層間契約・課金/法務。正本はそこ）に当たる場合、またはマージ条件・層間契約に触れる場合は `fable`（聖域パスだけでは上げない）。ただし共有枠モードが上限を先に決める（次項）
- モデルの優先順位は全役割共通: ①共有枠モード `SHARED_BUDGET_MODE`（`depleted` → 全役割 `sonnet` 固定・昇格なし。`throttled` → 既定 `sonnet`・昇格上限 `opus`・`abundant` 無効）②その範囲内で事前分類の `fable` 行（マージ権限・層間契約・課金/法務）による `fable`（聖域パスは `opus` 止まり） ③Fable 残量モード（`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限）。正本は `references/decision-criteria.md`。 interactive の `reserve` は `conserve` と同一に扱う（仕様レビューは verify 側の役割なので `fable` 可）。`throttled` では事前分類に当たっても `opus` 止まり、`depleted` では `sonnet`
- R1 は**読み取り専用**。仕様ファイル・コードを一切変更しない（修正は本体が W を再開して行わせる）

## レビュアーへの入力

1. change ディレクトリ `openspec/changes/<name>/` の artifact（proposal / specs / design / tasks）を全部
2. 記録先の受け入れ条件（issue 本文、または Draft PR 本文）とコメント
3. 関連する既存 `openspec/specs/`。**全読みしない** — `grep -rn` で当たりを付けてから該当 spec だけ Read する（コンテキスト溢れ防止）
4. 触る予定のスキル・スクリプトの該当箇所

## レビュー観点（5 つ。すべて検査する）

1. **受け入れ条件の一意性**: Scenario の WHEN/THEN が一意に決まりテスト可能か（bats 等で検証できる粒度か）
2. **既存 spec との整合**: 既存 `openspec/specs/` の MUST/SHALL と衝突・重複しないか。衝突があれば **spec のパスと要件名**を挙げる
3. **固有値の直書き**: リポ固有の値（時刻・製品名・パス）が要件に直書きされていないか。config や引数に出す修正案を出す
4. **前提の明記**: 導入先・前提環境（プラグイン・CLI・権限）が書かれているか
5. **相互整合**: proposal ↔ specs ↔ design ↔ tasks が整合しているか（Capabilities と spec ファイル、design の決定と要件、tasks の網羅）

## 出力書式（R1 が本体に return する）

```markdown
## Spec Review Result
- Change: <change-name>
- Round: <1|2>
- Status: APPROVE / REQUEST_CHANGES
### BLOCKER（実装に入れない欠陥。0 件なら「なし」）
- [file:section] 指摘 → 修正案
### SHOULD_FIX（マージ前に直した方がよいが実装は進められる）
### NOTE
```

判定基準: BLOCKER 0 件なら APPROVE。過剰品質は求めず「実装に支障がないか」を基準にする。

## 結果を記録先に記録する（R1 が投稿する）

return する前に、結果を記録先のコメントとして記録する。1 行目は正規表現 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致、2 行目以降に周回数（何周目で確定したか）・レビュアーのモデル・残課題を書く:

```bash
# issue が記録先
gh issue comment <issue番号> --body "$(printf '仕様レビュー: APPROVE\n2 周目・レビュアー opus。1 周目 BLOCKER 1 件を修正して確定。残課題: なし')"
# Draft PR が記録先
gh pr comment <PR番号> --body "$(printf '仕様レビュー: REQUEST_CHANGES\n1 周目・レビュアー opus。BLOCKER 2 件（specs/x: Scenario の THEN が曖昧、design D2 と tasks 2.1 が不整合）')"
```

**APPROVE が記録されるまで本体は W を実装（apply）に進めない。**

## 往復の上限

- **2 周で確定**: 初回 ＋ 修正後の差分再レビュー 1 回。再レビューは 1 周目の指摘が閉じたかと、修正で新たに生じた矛盾だけを見る（新規の気づきは NOTE に留める）
- 3 周目の例外は設けない（pr-review-gate の「新規の高深刻度 blocking のみ 3 周目可」は PR レビュー側の規定。仕様段階なら人に返す方が安い）
- 2 周目でも BLOCKER が残る場合: 記録先に `needs-approval` を付けて経緯をコメントし、interactive モードでは本体が AskUserQuestion で判断を仰ぎ、unmanned モードではそのサイクルを終了する
