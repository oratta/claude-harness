# Supabase (supabase)

- **verify**: `SUPABASE_ACCESS_TOKEN="$("${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh" supabase)" supabase projects list`
- **トークン**: `fmtoken.sh supabase`（Personal Access Token）。値を transcript とファイルに残さないためコマンド置換で渡す
- **prod の service_role / DB URL**: 原本は human-only 保管庫（例: `shukan--SUPABASE_SERVICE_ROLE_KEY` / `shukan--PROD_SUPABASE_DB_URL`）、稼働コピーは repo の GitHub Actions secrets。`agents` 保管庫にあるのは dev 用（`_DEV` suffix）で、prod のデータを読む処理はワークフロー内に書いて CI に実行させる（SKILL.md の「資格情報の階層」）
- **できること**: プロジェクト作成・一覧、DB マイグレーション（`supabase db push` / `migration`）、`supabase link`、secrets、Edge Functions デプロイ

## ブラウザ必須の例外

- Organization の課金プラン変更
- Auth プロバイダの一部設定（外部 OAuth の redirect URL 登録はダッシュボード）
