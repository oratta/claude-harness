# Stripe (stripe)

- **verify**: `STRIPE_API_KEY="<test key>" stripe products list --limit 1`
- **トークン**: `STRIPE_API_KEY`（env）。値の在処はオーナーの環境の索引があればそちら。そこには test key（`sk_test_`）または restricted key が入っていて、エージェントはこれで動く
- **live の書き込みキー**: 原本は秘密情報の保管庫（例: `<project>--STRIPE_SECRET_KEY_PROD`）、稼働コピーは repo の GitHub Actions secrets。live の課金データを触る処理はワークフロー内に書いて CI に実行させる（置き場の決め方は、オーナーの環境の索引（個人版）があればそちら）
- **できること**: 商品・価格の作成、テストモードの決済確認（`stripe trigger`）、webhook のローカル転送（`stripe listen`）

## ブラウザ必須の例外

- 本番モードへの切替・アカウント審査（本人確認）
- 事業情報・銀行口座の設定
