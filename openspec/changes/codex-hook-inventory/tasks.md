## 1. 一覧と完全性検査
- [x] 1.1 両 hooks.json の全登録について本体の入力・出力依存を読み、design の列を持つ独立一覧を作る。方針と現状を分け、各行に理由・コード根拠・後続担当・3 対象の確認状態を付ける。17＋2 件を基準に、同一 script の別 event が残ることを確認する。触る範囲: plugins/dev-workflow/docs/codex-hook-inventory.md（新規）
- [x] 1.2 実 hooks.json と一覧の多重集合の照合、分類・理由・根拠の検査を新規 unittest に作る。行削除、登録追加・削除、event/matcher/command の各変更、重複、不正分類・空の理由・根拠を一時コピーで試し、それぞれの非 0 を assert する。識別情報・必須列・許容分類を保ち、理由だけを無関係な非空文へ変更した入力は通ることも assert し、意味の妥当性を保証しない範囲を示す。`python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_codex_hook_inventory.py' -v` が exit 0 となることを確認する。触る範囲: plugins/dev-workflow/tests/test_codex_hook_inventory.py（新規）

## 2. 参照・安全な確認手順・変更記録
- [x] 2.1 既存 Codex 案内から一覧へリンクし、#1856 A1 の Codex 用ファイルは作らず将来の参照契約を一覧に記す。新規テストでリンク先の実在と接続契約を検査し、同じ unittest コマンドが exit 0 となることを確認する。触る範囲: plugins/dev-workflow/docs/codex-develop.md:1-26（導入と進め方）、plugins/dev-workflow/docs/codex-hook-inventory.md（新規）、plugins/dev-workflow/tests/test_codex_hook_inventory.py（新規）
- [x] 2.2 一覧に一時 repo・ローカル bare remote・ダミー秘密だけを使う実機確認手順と、対象別の拒否／未実行の証拠・未取得理由の記録方法を記す。remote の照合・本物の秘密を表示しないこと・G003 が実行することを文書確認する。触る範囲: plugins/dev-workflow/docs/codex-hook-inventory.md（新規）
- [x] 2.3 共用 changes/1858.md に G001 の分類・検査・参照と未完了の後続を記し、ファイルの存在を新規テストで確かめる。既存記録ができていた場合は上書きせず追記する。同じ unittest コマンドが exit 0 となることを確認する。触る範囲: plugins/dev-workflow/changes/1858.md（新規）、plugins/dev-workflow/tests/test_codex_hook_inventory.py（新規）
- [x] 2.4 新規一覧を既存の委譲一覧に「言及のみ」として登録し、対象名・ソース根拠に含む `codex-worker.py` が呼び出し語検索に現れても分類漏れにならないようにする。`bats plugins/dev-workflow/tests/codex-delegation-inventory.bats` が exit 0 となることを確認する。触る範囲: plugins/dev-workflow/docs/codex-delegation-inventory.md:21-50（表）

## 3. 統合確認
- [x] 3.1 新規 unittest、既存 `bats plugins/dev-workflow/tests/codex-delegation-inventory.bats`、`openspec validate codex-hook-inventory --type change --strict`、`git diff --check` の exit 0 を確認する。差分が docs・テスト・changes・本 change のみで、hook・CLAUDE.md・権限設定・他の子の実装に及ばないことを確認する。触る範囲: plugins/dev-workflow/docs/codex-hook-inventory.md（新規）、plugins/dev-workflow/docs/codex-develop.md:1-26、plugins/dev-workflow/docs/codex-delegation-inventory.md:21-50（表）、plugins/dev-workflow/tests/test_codex_hook_inventory.py（新規）、plugins/dev-workflow/changes/1858.md（新規）、openspec/changes/codex-hook-inventory/tasks.md（新規）

## Workflow follow-up
- 実装の開始条件は記録先 #1861 の R1 APPROVE。archive・PR・レビューは coordinator の正本手順で行う。この spec 段では実装・実機実行・Draft PR 作成を行わない。
- G002/G003 は同じ一覧に結果を反映し、共用 changes/1858.md に追記する。#1856 A1 は Codex 用ファイルから一覧へ参照を置く。これらの後続の作業を G001 の完了条件に追加しない。
