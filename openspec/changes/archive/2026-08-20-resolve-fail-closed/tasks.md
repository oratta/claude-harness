## 1. テスト先行（Red）

- [x] 1.1 `casting-resolve.bats` に fail-closed 5 フィクスチャ（malformed-row / unknown-vocab / version-mismatch / missing-version / no-front-matter）の「exit 1・stdout 空・stderr に理由」テストと、起案シグナル 2 フィクスチャの「resolve は止まらない」テストを追加し、現行実装で Red を確認する（既存の malformed フォールバックテストは新契約に置き換え）

## 2. 実装（Green）

- [x] 2.1 `casting-check.sh` の resolve 分岐を検証定義の後ろへ移動し、`check_layer_files`（project.md / local.md の malformed-row・unknown-vocab・version 検証）を check / resolve の両モードで共通化する。resolve は検証失敗時に stderr へ理由を出して exit 1
- [x] 2.2 bats 全テスト green を確認（AC1〜AC4 の実測込み。正常系 3 フィクスチャは修正前後で出力バイト一致を diff で確認）

## 3. 追随

- [x] 3.1 `plugin.json` の version を 0.2.2 に上げる（main の 0.2.1 の次に取り直し）
- [x] 3.2 `SKILL.md`・`README.md` に fail-closed 挙動を追記する
- [x] 3.3 `openspec validate resolve-fail-closed --strict` を通し、archive して PR に含める
