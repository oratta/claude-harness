# Stripe (stripe)

- **verify**: `STRIPE_API_KEY="$("${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh" stripe)" stripe products list --limit 1`
- **トークン**: `fmtoken.sh stripe`（restricted key または test key を登録して使う。live の書き込みキーはエージェントに渡さない運用）
- **できること**: 商品・価格の作成、テストモードの決済確認（`stripe trigger`）、webhook のローカル転送（`stripe listen`）

## ブラウザ必須の例外

- 本番モードへの切替・アカウント審査（本人確認）
- 事業情報・銀行口座の設定
