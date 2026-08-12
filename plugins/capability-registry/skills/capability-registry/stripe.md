# Stripe (stripe)

- **verify**: `STRIPE_API_KEY="$("${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh" stripe)" stripe products list --limit 1`
- **トークン**: `fmtoken.sh stripe`。`agents` 保管庫には test key（`sk_test_`）または restricted key が入っていて、エージェントはこれで動く
- **live の書き込みキー**: 原本は human-only 保管庫（例: `uranai--STRIPE_SECRET_KEY_PROD`）、稼働コピーは repo の GitHub Actions secrets。live の課金データを触る処理はワークフロー内に書いて CI に実行させる（SKILL.md の「資格情報の階層」）
- **できること**: 商品・価格の作成、テストモードの決済確認（`stripe trigger`）、webhook のローカル転送（`stripe listen`）

## ブラウザ必須の例外

- 本番モードへの切替・アカウント審査（本人確認）
- 事業情報・銀行口座の設定
