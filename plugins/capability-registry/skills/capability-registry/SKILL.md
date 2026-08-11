---
name: capability-registry
description: 外部サービスを操作する前に必ず参照するレジストリ（GitHub/Supabase/Vercel/Stripe/1Password 等）。CLI の有無・認証確認コマンド・トークンの在処（fmtoken.sh）を索引で返す。ブラウザを開こうとした時・ユーザーにログインを依頼したくなった時も、その前にここで CLI 代替を確認する。
version: 1.3.0
---

# capability-registry — 外部サービスの CLI とトークンの在処

## 原則

1. 索引の記述を信じず、verify（認証確認コマンド）を実行して確かめる
2. トークンは `"${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh" <service>` で取得する。値を transcript に出さないため必ずコマンド置換で使う（例: `GITHUB_TOKEN="$(fmtoken.sh github)" gh api ...`）
   - 未登録なら exit 44 → ブラウザに行かず、主に 1Password `agents` 保管庫への登録（`<project>--<service>` / フィールド `credential`）を依頼する（prod の書き込み可能キーは例外 — 後述『資格情報の階層』参照）
   - SA トークン未配布なら exit 43 → 主に SA トークンの配布を依頼する
   - 存在確認だけなら `fmtoken.sh --check <service>`、一覧は `fmtoken.sh --list`
3. ブラウザ操作が正当なのは、索引の「ブラウザ必須の例外」とネガティブエントリに該当する場合のみ

## 資格情報の階層（どこに置くかはプロジェクトごとに決めない）

シークレットの置き場は書き込み先の環境で決まる。**三択を主に投げない** — 下の表に従い、
該当行が無い場合だけ論点として上げる。

| 階層 | 置き場 | エージェントのアクセス |
|---|---|---|
| dev / test / 読み取り系 | `agents` 保管庫（fmtoken 経由） | 自由 |
| **prod の書き込み可能キー**（service_role・live secret key 等） | **GitHub Actions secrets のみ**。保管庫にも `.env.local` にも置かない | 不可。CI ジョブだけが触る |

- 根拠: `agents` 保管庫の SA は vault 単位スコープで、fmtoken のプロジェクト別プレフィックスは
  アクセス制御ではない。prod 書き込みキーを保管庫に入れる ＝ 全プロジェクトの全エージェントに配るのと同義
- prod のデータが要る処理（集計・レポート等）は、キーを手元に持ってくるのではなく
  **処理を Actions 内に持っていく**（例: suimei のマーケ日報 PR #235 — `PROD_SUPABASE_*` secrets を
  ワークフロー内で同名 env にリネームして注入するパターン）
- 同一サービスで dev/prod を分けたい場合の保管庫側の命名は suffix で表現する
  （例: `suimei--SUPABASE_ACCESS_TOKEN`。prod 書き込みキーはそもそも登録しない）

## 索引（1 サービス 1 行）

| サービス | CLI | 認証確認（verify） | トークン | ブラウザ必須の例外 |
|---|---|---|---|---|
| 1Password | op | `op whoami` | SA トークン（env / 600 ファイル / Keychain） | アイテム登録・SA 権限変更（人間が行う） |
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
