## 1. テスト先行（Red）

- [x] 1.1 4経路（6列超え行 / 配役表ゼロ・対象不在 / 閉じ忘れコメント / 引数順）の退行テストと、壊れた local.md 経由の fail-closed テストを追加し、origin/main で Red を確認する（resolve 10件・check 2件が fail）
- [x] 1.2 起案シグナル2フィクスチャ（catalog-external-precedent / repeated-not-issue）に有効な project.md を同居させ、「起案シグナルは resolve を止めない」の検証を実質化する

## 2. 実装（Green）

- [x] 2.1 `check_malformed_rows` / `table_rows` の列数判定を `!= 6` にし、6列以上は専用メッセージで報告する
- [x] 2.2 `check_comment_balance` を追加し、配役表2層（resolve でも fail-closed）と precedents.md（check モード）に掛ける
- [x] 2.3 resolve に配役表ゼロの分岐（exit 3）と、対象 repo ルート不在のチェック（exit 2）を追加する
- [x] 2.4 引数パーサを書き直し、`resolve` を順不同で受け、positional 1個に限定して超過は exit 2 にする
- [x] 2.5 bats 全テスト green を確認し、正常系3フィクスチャの resolve 出力が修正前後で一致することを shasum で確かめる

## 3. 追随

- [x] 3.1 `plugin.json` の version を 0.2.3 に上げる
- [x] 3.2 `SKILL.md`・`README.md` に検出項目と exit code 体系を追記する
- [x] 3.3 `openspec validate casting-resolve-fail-open-gaps --strict` を通し、archive して PR に含める
