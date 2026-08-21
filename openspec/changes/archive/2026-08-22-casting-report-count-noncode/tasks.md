## 1. テスト先行（Red）

- [x] 1.1 `casting-structure.bats` に、ヒアドキュメント本文・行末コメント・文字列リテラル（単引用・二重引用）の中の `report` を含む合成スクリプトで `count_report_calls` / `detection_category_count` が 0 になることを assert する test を追加し、現行の grep 実装で Red を確認する
- [x] 1.2 同じ合成スクリプトに本物の `report` 呼び出しを 1 件足すと 1 になることを同 test に続けて assert する（カウンタを緩めて数え落とし側へ逃げるのを防ぐ）

## 2. 実装（Green）

- [x] 2.1 `plugins/casting/tests/lib/report-calls.py` を新設: 引用（単・二重、行またぎ）・コメント（語頭の `#` のみ）・ヒアドキュメント（`<<` / `<<-` / 引用付き区切り語。`<<<` は herestring として除外）を追う軽量スキャナで、コード領域の `report` 呼び出しを1行1件で列挙する
- [x] 2.2 `casting-structure.bats` の `check_script_body` を廃し、`report_calls` / `literal_report_categories` 経由に `detection_categories`・`detection_category_count`・`count_report_calls`・`count_literal_report_calls` を付け替える。非リテラル呼び出しの失敗診断も `report_calls | grep -F ' nonliteral '` に差し替える
- [x] 2.3 `setup()` に `REPORT_CALLS` を追加する

## 3. 整合・検証

- [x] 3.1 既存の 3 検査（同一行に 2 件・行継続・非リテラル第1引数）を変更せずに pass することを確認する
- [x] 3.2 issue #163 の再現手順（3 形を `casting-check.sh` に実追記）で、以前落ちていた 23・24 が落ちなくなることを実出力で確認する
- [x] 3.3 `openspec/specs/casting-project-files/spec.md` の「検出項目数の表記と実装の一致」に、コード領域限定と偽陽性側へ倒す方向の要件・Scenario を追加する
- [x] 3.4 `openspec validate casting-project-files --type spec --strict` を通す
- [x] 3.5 `bash scripts/lint.sh` と `bash scripts/test.sh` がともに exit 0（exit code を PR に添付）
