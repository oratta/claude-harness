## 1. テスト先行（Red）

- [x] 1.1 フィクスチャ6本（code-fence-comment / code-fence-unclosed / code-fence-unclosed-swallow / code-fence-plus-unclosed / code-fence-example-row / comment-with-fence-marks）と退行テスト8件を追加し、origin/main のスクリプトでは Red になることを確認する

## 2. 実装（Green）

- [x] 2.1 `strip_html_comments` にコードフェンス状態を持たせ、フェンス内の `<!--` / `-->` を走査対象から外す
- [x] 2.1b フェンス内の行を出力からも落とし、記入例の表行が実在の配役として抽出されないようにする
- [x] 2.1c `strip_html_comments` の戻り値を 0/1/2 に拡張し、`check_unclosed_markers` がフェンスの閉じ忘れを `unclosed-fence` として報告する
- [x] 2.2 casting の bats 全テストが green になることを確認する

## 3. 追随

- [x] 3.1 `plugin.json`・`marketplace.json` の version を 0.5.2 に上げ、consultation.bats の version 照合を追随させる
- [x] 3.2 `SKILL.md`・スクリプト冒頭の検出項目説明にフェンス内を走査しない旨を追記する
- [x] 3.2b 検出項目数の表記（README ×2・SKILL.md・スクリプト冒頭 ×2・plugin.json・marketplace.json・spec）を8項目に揃え、casting-structure.bats の検出カテゴリ配列に unclosed-fence を足す
- [x] 3.3 `openspec validate casting-code-fence-comment --strict` を通し、archive して PR に含める
