# 仕様レビュー（github-issue スキル Step D）

`/opsx:ff`（または openspec CLI 直叩き）で生成した change の artifact を、**実装に入る前に**実装と別コンテキストのサブエージェントが審査する工程の正本。longrun の Build Contract レビュー（plan.md を実装前に審査する工程）を dev-workflow のパイプラインに置き直したもの。仕様レベルの穴（既存規約との整合・config に出すべき固有値・導入先の前提）を実装レビューに持ち込まないための工程で、実装 diff のレビュー（pr-review-gate）とは対象が違う。

## 前提

- `gh`（元 issue にコメントを投稿する権限）
- Agent ツール（サブエージェントは孫を spawn できないので、本体セッションが直接 spawn する）
- opsx コマンドまたは openspec CLI（どちらも無いリポは仕様化経路が無いので、この工程も発生しない）

## 判断記録の契約（Step B と後続の照合が共有する）

後続の pr-review-gate が「仕様化の判断が記録されているか」を機械照合するための取り決め。Step B・Step D の投稿と、照合側は同じ規則を使う。

| 項目 | 規則 |
|---|---|
| 判断記録の 1 行目 | 正規表現 `^仕様化判断: (する|しない)$` に完全一致。太字・全角コロン・末尾句点などの装飾を含めない |
| レビュー結果の 1 行目 | 正規表現 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致。照合側は**最新のレビュー結果**が APPROVE であることを見る（件数ではない） |
| 記録先 | 元 issue のコメント（PR ではない。PR 作成前に判断が済んでいるため） |
| 照合のしかた | `gh api --paginate --slurp … | jq -r 'add | …'` で**全ページ**を取り（`--slurp` は `--jq` と併用できない）、`body | split("\n")[0] | test("^…$")` のように**1 行目を切り出してから**正規表現に掛け、`last` で最新 1 件を選ぶ（jq の `^` `$` は文字列全体の先頭・末尾にしか掛からない。コメントは 30 件でページが切れる） |
| 同接頭辞のコメントが複数あるとき | 作成日時が**最新の 1 件**を正とする（判定のやり直しを許す） |
| PR から元 issue を解決する規則 | PR 本文中で**最初に現れる** `Closes #N` / `Fixes #N` / `Refs #N`（大文字小文字不問）。見つからなければ「記録なし」扱い |

## レビュアーの spawn

- **モデルは必ず明示する**。既定は中位ティア `opus`。仕様が SKILL.md Step D の「重要実装の事前分類」表（聖域パス等。正本はそこ）に当たる場合は `fable`
- 残量モード（`FABLE_BUDGET_MODE`）は `dev-workflow-execution-strategy` の規定どおり: `reserve` は**自動実行（unmanned / cron / loop 経由）のみ** `opus` 上限、`exhausted` は**全経路**で `opus` 上限。interactive の `reserve` は `conserve` と同一に扱う（仕様レビューは verify 側の役割なので `fable` 可）
- 実行戦略が **workflow 型**（`/lr:e` に委ねる）のときは、longrun の Build Contract レビューをもってこの工程の代替とし、二重にはレビューしない
- レビュアーは**読み取り専用**。仕様ファイル・コードを一切変更しない

## レビュアーへの入力

1. change ディレクトリ `openspec/changes/<name>/` の artifact（proposal / specs / design / tasks）を全部
2. 元 issue の本文（受け入れ条件）とコメント
3. 関連する既存 `openspec/specs/`。**全読みしない** — `grep -rn` で当たりを付けてから該当 spec だけ Read する（コンテキスト溢れ防止）
4. 触る予定のスキル・スクリプトの該当箇所

## レビュー観点（5 つ。すべて検査する）

1. **受け入れ条件の一意性**: Scenario の WHEN/THEN が一意に決まりテスト可能か（bats 等で検証できる粒度か）
2. **既存 spec との整合**: 既存 `openspec/specs/` の MUST/SHALL と衝突・重複しないか。衝突があれば **spec のパスと要件名**を挙げる
3. **固有値の直書き**: リポ固有の値（時刻・製品名・パス）が要件に直書きされていないか。config や引数に出す修正案を出す
4. **前提の明記**: 導入先・前提環境（プラグイン・CLI・権限）が書かれているか
5. **相互整合**: proposal ↔ specs ↔ design ↔ tasks が整合しているか（Capabilities と spec ファイル、design の決定と要件、tasks の網羅）

## 出力書式（レビュアーが return する）

```markdown
## Spec Review Result
- Change: <change-name>
- Status: APPROVE / REQUEST_CHANGES
### BLOCKER（実装に入れない欠陥。0 件なら「なし」）
- [file:section] 指摘 → 修正案
### SHOULD_FIX（マージ前に直した方がよいが実装は進められる）
### NOTE
```

判定基準: BLOCKER 0 件なら APPROVE。過剰品質は求めず「実装に支障がないか」を基準にする。

## 往復の上限

- **2 周で確定**: 初回 ＋ 修正後の差分再レビュー 1 回。再レビューは 1 周目の指摘が閉じたかと、修正で新たに生じた矛盾だけを見る（新規の気づきは NOTE に留める）
- 3 周目の例外は設けない（pr-review-gate の「新規の高深刻度 blocking のみ 3 周目可」は PR レビュー側の規定。仕様段階なら人に返す方が安い）
- 2 周目でも BLOCKER が残る場合: issue に `needs-approval` を付けて経緯をコメントし、interactive モードでは AskUserQuestion で判断を仰ぎ、unmanned モードではそのサイクルを終了する
