# Vercel (vercel)

- **verify**: `vercel whoami --token "$("${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh" vercel)"`
- **トークン**: `fmtoken.sh vercel`。すべてのサブコマンドに `--token` で渡せる（ログイン状態に依存しない）
- **できること**: プロジェクト作成・link、環境変数（`vercel env`）、デプロイ、ドメイン割当（`vercel domains add`）、GitHub 連携設定の大半

## ブラウザ必須の例外

- ドメインの新規購入・移管
- チームの課金・プラン設定
