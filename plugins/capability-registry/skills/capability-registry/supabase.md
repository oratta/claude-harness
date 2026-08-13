# Supabase (supabase)

- **verify**: `SUPABASE_ACCESS_TOKEN="$("${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh" supabase)" supabase projects list`
- **トークン**: `fmtoken.sh supabase`（Personal Access Token）。値を transcript とファイルに残さないためコマンド置換で渡す
- **prod の service_role / DB URL**: 原本は human-only 保管庫（例: `shukan--SUPABASE_SERVICE_ROLE_KEY` / `shukan--PROD_SUPABASE_DB_URL`）、稼働コピーは repo の GitHub Actions secrets。`agents` 保管庫にあるのは dev 用（`_DEV` suffix）で、prod のデータを読む処理はワークフロー内に書いて CI に実行させる（SKILL.md の「資格情報の階層」）
- **できること**: プロジェクト作成・一覧、DB マイグレーション（`supabase db push` / `migration`）、`supabase link`、secrets、Edge Functions デプロイ

## 本番データを読む（KPI 集計・日報など）

集計処理は GitHub Actions のワークフロー内に書いて CI に実行させ、エージェントは出力された結果だけを読む。service_role は手元に持ってこない。実例は suimei の `marketing-daily-report.yml`: `PROD_SUPABASE_*` の Actions secrets をワークフロー内で `NEXT_PUBLIC_SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` にリネームして注入し、集計結果を issue コメントに出力する（2026-08-04 から毎朝稼働）。新しい集計要求が来たら同じ形（CI 実行 + 結果だけ読む）を適用する（階層の原則は SKILL.md の「資格情報の階層」）。

## ブラウザ必須の例外

- Organization の課金プラン変更
- Auth プロバイダの一部設定（外部 OAuth の redirect URL 登録はダッシュボード）
