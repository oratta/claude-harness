# Supabase (supabase)

- **verify**: `SUPABASE_ACCESS_TOKEN="$("${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh" supabase)" supabase projects list`
- **トークン**: `fmtoken.sh supabase`（Personal Access Token）。env に直書きせずコマンド置換で渡す
- **できること**: プロジェクト作成・一覧、DB マイグレーション（`supabase db push` / `migration`）、`supabase link`、secrets、Edge Functions デプロイ

## ブラウザ必須の例外

- Organization の課金プラン変更
- Auth プロバイダの一部設定（外部 OAuth の redirect URL 登録はダッシュボード）
