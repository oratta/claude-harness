# Supabase (supabase)

- **verify**: `SUPABASE_ACCESS_TOKEN="<token>" supabase projects list`
- **トークン**: `SUPABASE_ACCESS_TOKEN`（Personal Access Token）。値の在処はオーナーの環境の索引があればそちら。transcript とファイルに値を残さないよう env で渡す
- **prod の service_role / DB URL**: 原本は秘密情報の保管庫（例: `<project>--SUPABASE_SERVICE_ROLE_KEY` / `<project>--PROD_SUPABASE_DB_URL`）、稼働コピーは repo の GitHub Actions secrets。エージェントが読める保管庫にあるのは dev 用（`_DEV` suffix）で、prod のデータを読む処理はワークフロー内に書いて CI に実行させる（SKILL.md の「資格情報の階層」）
- **できること**: プロジェクト作成・一覧、DB マイグレーション（`supabase db push` / `migration`）、`supabase link`、secrets、Edge Functions デプロイ

## 本番データを読む（KPI 集計・日報など）

集計処理は GitHub Actions のワークフロー内に書いて CI に実行させ、エージェントは出力された結果だけを読む。service_role は手元に持ってこない。実例（自分のリポジトリの集計用ワークフロー）: `PROD_SUPABASE_*` の Actions secrets をワークフロー内で `NEXT_PUBLIC_SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` にリネームして注入し、集計結果を issue コメントに出力する（2026-08-04 から毎朝稼働）。新しい集計要求が来たら同じ形（CI 実行 + 結果だけ読む）を適用する（階層の原則は SKILL.md の「資格情報の階層」）。

## ブラウザ必須の例外

- Organization の課金プラン変更
- Auth プロバイダの一部設定（外部 OAuth の redirect URL 登録はダッシュボード）
