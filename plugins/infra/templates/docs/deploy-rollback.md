# 本番デプロイのロールバック手順

deploy-production.yml が失敗した／デプロイ後に不具合が発覚したときの手順書。

## 1. アプリだけの問題（マイグレーションを伴わないデプロイ）

Vercel の直前デプロイメントに切り戻す:

```bash
# 直近のデプロイ一覧を確認
vercel ls <project> --prod --token=$VERCEL_TOKEN

# 一つ前の正常なデプロイメントへロールバック
vercel rollback <deployment-url> --token=$VERCEL_TOKEN
```

- `vercel rollback` は production エイリアスの付け替えのみ。ビルド不要で数秒で完了する
- ロールバック後、原因を修正して通常フローで再デプロイする

## 2. マイグレーション込みデプロイが失敗した場合の判断基準

| 状況 | 判断 |
|---|---|
| マイグレーション適用**前**に fail（ゲート/バックアップ段階） | 何も壊れていない。原因修正して再実行 |
| マイグレーション適用**後**、デプロイ前に fail | DB は新スキーマ・アプリは旧コード。**後方互換な expand 系ならそのまま再実行**が最速。破壊的変更なら 3. へ |
| デプロイ後にアプリ不具合が発覚 | まず `vercel rollback`。旧コードが新スキーマで動くか（expand-contract を守っていたか）を確認。動かないなら 3. へ |

原則: **expand-contract を守っている限り「DB は進んだまま・アプリだけ戻す」で安全**。
DB のロールバック（3.）は最終手段。

## 3. DB を戻す（最終手段）

デプロイワークフローが保存したバックアップ artifact（`db-backup-<run_id>`: roles.sql / schema.sql / data.sql）を使う:

```bash
# artifact をダウンロード
gh run download <run_id> -n db-backup-<run_id> -d ./restore

# 【破壊的】本番 DB を巻き戻す。実行前に必ず現状を再バックアップすること
supabase db dump --db-url "$PROD_SUPABASE_DB_URL" -f pre-restore-backup.sql
psql "$PROD_SUPABASE_DB_URL" -f restore/schema.sql   # 必要に応じて
psql "$PROD_SUPABASE_DB_URL" -f restore/data.sql
```

注意:

- data.sql の COPY はテーブルが空である前提。部分復旧は対象テーブルを絞って手動で行う
- 戻した後は `supabase_migrations.schema_migrations` の内容とローカル `supabase/migrations/` の整合を必ず確認する（ズレたままだと次回のマイグレーションゲートで fail する）
- Supabase Free tier には PITR がないため、このバックアップ artifact が唯一の復元手段

## 4. メンテナンスモードが解除されないまま停止した場合

maintenance=true のデプロイが途中で失敗すると、安全のためメンテ状態のまま停止する。手動解除:

```bash
# 書き込み再開（Supabase Management API・SQL Editor どちらでも可）
# grant insert, update, delete, truncate on all tables in schema public to anon, authenticated;

# メンテ表示解除（Edge Config の maintenance キーを false に）
curl -X PATCH "https://api.vercel.com/v1/edge-config/$EDGE_CONFIG_ID/items?teamId=$VERCEL_ORG_ID" \
  -H "Authorization: Bearer $VERCEL_TOKEN" -H "Content-Type: application/json" \
  -d '{"items":[{"operation":"upsert","key":"maintenance","value":false}]}'
```

解除は必ず「DB とアプリの整合が取れた状態」を確認してから行うこと。
