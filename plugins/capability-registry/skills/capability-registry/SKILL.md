---
name: capability-registry
description: 外部サービスを操作する前に必ず参照するレジストリ（GitHub/Supabase/Vercel/Stripe/1Password 等）。CLI の有無・認証確認コマンド・トークンの在処（fmtoken.sh）を索引で返す。ブラウザを開こうとした時・ユーザーにログインを依頼したくなった時も、その前にここで CLI 代替を確認する。
version: 1.0.0
---

# capability-registry — 外部サービスの CLI とトークンの在処

## 原則

1. 索引の記述を信じず、verify（認証確認コマンド）を実行して確かめる
2. トークンは `"${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh" <service>` で取得する。値を transcript に出さないため必ずコマンド置換で使う（例: `GITHUB_TOKEN="$(fmtoken.sh github)" gh api ...`）
   - 未登録なら exit 44 → ブラウザに行かず、主に 1Password `agents` 保管庫への登録（`<project>--<service>` / フィールド `credential`）を依頼する
   - SA トークン未配布なら exit 43 → 主に SA トークンの配布を依頼する
   - 存在確認だけなら `fmtoken.sh --check <service>`、一覧は `fmtoken.sh --list`
3. ブラウザ操作が正当なのは、索引の「ブラウザ必須の例外」とネガティブエントリに該当する場合のみ

## 索引（1 サービス 1 行）

| サービス | CLI | 認証確認（verify） | トークン | ブラウザ必須の例外 |
|---|---|---|---|---|
| 1Password | op | `op whoami` | SA トークン（Keychain / 600 ファイル） | アイテム登録・SA 権限変更（人間が行う） |
| GitHub | gh | `gh auth status` | `fmtoken.sh github` | OAuth アプリ承認・組織設定の一部 |
| Supabase | supabase | `supabase projects list` | `SUPABASE_ACCESS_TOKEN="$(fmtoken.sh supabase)"` | ダッシュボード限定の設定変更 |
| Vercel | vercel | `vercel whoami` | `vercel --token "$(fmtoken.sh vercel)"` | ドメイン購入・課金設定 |
| Stripe | stripe | `stripe products list --limit 1` | `STRIPE_API_KEY="$(fmtoken.sh stripe)"` | 本番モード切替・アカウント審査 |

セットアップ手順・運用知見・例外の具体例は同ディレクトリのサービス別ファイルに遅延ロード:
`1password.md` / `github.md` / `supabase.md` / `vercel.md` / `stripe.md`

## CLI が無いサービス（ネガティブエントリ）

無い CLI を探し回るのが一番高くつく。以下はブラウザ操作が正当:

- **Google OAuth 同意画面・クライアント作成**: gcloud では不可。生成された credential はワンタイム表示 — 表示された次のアクションで env ファイルに保存する
- **1Password の SA 権限変更**: CLI/API 不可（Individual プラン）。取り消して再発行のみ

## 新サービスの追加

実際に使った実績が出たら索引に 1 行 + サービス別ファイルを追加する。CLI が無いと判明したら、その事実をネガティブエントリに記録して調査の重複を防ぐ。
