## 1. テスト先行（Red）

- [x] 1.1 フィクスチャ4本（code-fence-comment / code-fence-unclosed / code-fence-plus-unclosed / comment-with-fence-marks）と退行テスト5件を追加し、origin/main のスクリプトでは3件が Red になることを確認する

## 2. 実装（Green）

- [x] 2.1 `strip_html_comments` にコードフェンス状態を持たせ、フェンス内の `<!--` / `-->` を走査対象から外す
- [x] 2.2 casting の bats 全テストが green になることを確認する

## 3. 追随

- [x] 3.1 `plugin.json`・`marketplace.json`・`SKILL.md` の version を 0.4.3 に上げ、consultation.bats の version 照合を追随させる
- [x] 3.2 `SKILL.md`・スクリプト冒頭の検出項目説明にフェンス内を走査しない旨を追記する
- [x] 3.3 `openspec validate casting-code-fence-comment --strict` を通し、archive して PR に含める
