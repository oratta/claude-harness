## Why
Codex の本体と各役で Claude のどの hook が働くかを確認できる一覧がなく、未移植の歯止めを有効と誤認するおそれがある。#1858 を分割した #1861（G001）として、19 登録の分類と未対応の根拠を残し、後続の拒否判定・配布の作業につなぐ。

## What Changes
- `plugins/dev-workflow/docs/codex-hook-inventory.md` に、両プラグインの登録ごとの方針・現状・理由・コード根拠・後続担当を記す。
- 既存 `docs/codex-develop.md` から一覧へ参照を置き、#1856 の Codex 用ファイルからも同じ一覧を参照する接続契約を明記する。
- `docs/codex-delegation-inventory.md` に新規一覧を「言及のみ」として登録し、既存の呼び出し語検索との整合を保つ。
- 登録の追加・削除・変更と一覧の欠落・重複・古い行を検出するテストを作る。
- 一時 git repo・ローカル bare remote・ダミーの秘密だけを使う将来の実機確認手順と、共用の `plugins/dev-workflow/changes/1858.md` を作る。

## Capabilities
### New Capabilities
- `codex-hook-coverage`: 登録済み hook の Codex 向け分類・証拠・対象別の確認状態と、一覧の完全性を維持する契約。
### Modified Capabilities
なし。既存の guard の判定・権限・注入・worker 起動の要件は変更しない。

## Impact
対象は #1861 の受け入れ条件のみ。元 issue の判断・分割は #1858 のコメント 7234062095 / 7234092634 / 7234255369 に従う。hook 17＋2 登録は指定 HEAD `93543270038cdf040edb6cd9d3a8b4b41a540ae4` の数であり、恒久的な固定件数ではない。
実装時の編集は docs・新規テスト・changes のみ。`plugins/*/hooks/`・`CLAUDE.md`・権限設定には触れない。#1856 のファイル構成・操作対応表、#1862（G002）の拒否判定、#1863（G003）の配布・信頼・実機実行は対象外。版は上げない。
