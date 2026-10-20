# Vercel (vercel)

- **verify**: `vercel whoami --token "$VERCEL_TOKEN"`
- **トークン**: `VERCEL_TOKEN`（env）を `--token "$VERCEL_TOKEN"` として明示的に渡す（CLI は環境変数を自動では読まない）。値の在処はオーナーの環境の索引があればそちら。すべてのサブコマンドに `--token` で渡せる（ログイン状態に依存しない）
- **できること**: プロジェクト作成・link、環境変数（`vercel env`）、デプロイ、ドメイン割当（`vercel domains add`）、GitHub 連携設定の大半

## ブラウザ必須の例外

- ドメインの新規購入・移管
- チームの課金・プラン設定
