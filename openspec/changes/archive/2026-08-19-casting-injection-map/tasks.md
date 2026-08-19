## 1. テスト先行（Red）

- [x] 1.1 `tests/casting-injection.bats` を新設: ①catalog_version 一致②14観点の全掲載③タイミング欄が定義済み8語彙のみ④5節の存在⑤SKILL.md のポインタ、を検証（LC_ALL=C grep -F 照合・awk 文字列比較禁止）。injection.md 不在の状態で Red を確認する

## 2. 実装（Green）

- [x] 2.1 `catalog/injection.md` を新設: front matter `catalog_version: 1`＋8分類の語彙定義＋14観点の注入マップ表＋policies/ 置き場所規約（slug 対応表・既存文書の stub 許容）＋実装済み配線の実在パス一覧＋未実装配線の issue 参照
- [x] 2.2 `skills/casting/SKILL.md` に injection.md へのポインタを追記（マップ本文は複製しない）
- [x] 2.3 `.claude-plugin/plugin.json` の version を 0.2.0 に上げ、description に injection.md を追記
- [x] 2.4 bats を実行して Green を確認する（exit code を表示）

## 3. issue 切り出し

- [x] 3.1 ③の汎用化（pr-review-gate への repo 固有観点レンズ自動注入）を oratta/claude-harness に起票し、injection.md の未実装配線節に issue 番号を記載する
- [x] 3.2 ④の汎用化（アクション直前ゲートの汎用機構）を同様に起票・記載する

## 4. 整合・検証

- [x] 4.1 `openspec validate casting-injection-map --strict` を通す
- [x] 4.2 `scripts/test.sh casting` で casting スイート全体が green（exit code 表示）
- [x] 4.3 issue #122 の受け入れ条件5点を1件ずつ突き合わせて確認する
- [x] 4.4 `.claude/casting/precedents.md` に本判断の判例を追記する
