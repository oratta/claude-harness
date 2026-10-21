---
name: capability-registry
description: 外部サービスを操作する前に必ず参照するレジストリ（GitHub/Supabase/Vercel/Stripe 等）。CLI の有無・認証確認コマンド・トークンを渡す環境変数名を索引で返す（値の在処はオーナーの環境の索引があればそちら）。ブラウザを開こうとした時・ユーザーにログインを依頼したくなった時も、その前にここで CLI 代替を確認する。
version: 1.7.0
---

# capability-registry — 外部サービスの CLI とトークンの在処

## 表記規約（生成文にも適用すること）

1Password 側は裸の「vault」を使わず保管庫名を付けて「agents 保管庫」「human-only 保管庫」（文脈が曖昧なら「1Password の agents 保管庫」）と書く。Obsidian 側の vault とは常に区別し、必ず「Obsidian vault」と修飾する。CLI 引数（`op item list --vault agents` 等）は原文のまま変更しない。

## 原則

1. 索引の記述を信じず、verify（認証確認コマンド）を実行して確かめる
2. トークンの値の在処は、オーナーの環境の索引（個人版）があればそちらを見る。索引のトークン列は CLI が読む環境変数名（またはログイン状態）で、値は transcript に出さないためコマンド置換か env で渡す。在処が分からず手元に値も無ければ、ブラウザに行かず主に発行を依頼する
3. ブラウザ操作が正当なのは、索引の「ブラウザ必須の例外」とネガティブエントリに該当する場合のみ

## 資格情報の階層（どこに置くかはプロジェクトごとに決めない）

保管は 3 層ある — **`agents` 保管庫**（エージェントの read-only SA が読む）、**human-only 保管庫**
（同じ SA からは見えない。prod 書き込みキーの原本）、**GitHub Actions secrets**（CI を動かすための稼働コピー）。
**三択を主に投げない** — 下の表の該当行どおりに動き、該当行が無い場合だけ論点として上げる。

| 階層 | 原本の置き場 | 稼働コピー | エージェントはどう動くか |
|---|---|---|---|
| dev / test / 読み取り系 | `agents` 保管庫（`<project>--<service>` / フィールド `credential`） | 各 repo の `.env.local` | `fmtoken.sh <service>` で引いて手元で実行する。未登録（exit 44）なら、値が手元にあれば `fmtoken.sh --register` で登録し、無ければ主に発行を依頼する |
| prod の書き込み可能キー（service_role・live secret key 等） | human-only 保管庫（例: `uranai--STRIPE_SECRET_KEY_PROD`） | 対象 repo の GitHub Actions secrets | 処理を Actions のワークフロー内に置き、CI に実行させる。secrets が無ければ主に Actions secrets への登録を依頼する |

- 境界の根拠: SA の権限は保管庫単位スコープで、fmtoken のプロジェクト別プレフィックスはアクセス制御ではない。
  だから `agents` 保管庫は「全プロジェクトの全エージェントが読む場所」として扱い、
  prod 書き込みキーの原本は SA の見えない human-only 保管庫に置いて、保管庫の境界をそのまま権限境界に使う
- prod のデータが要る処理（集計・レポート等）は、**処理を Actions 内に持っていく**
  （例: suimei のマーケ日報 PR #235 — `PROD_SUPABASE_*` secrets をワークフロー内で同名 env に
  リネームして注入するパターン）
- 同一サービスで dev/prod を分けるときは suffix（`_DEV` / `_PROD`）で表現する

### ブラウザで捕獲した資格情報を env から昇格させる

ダッシュボード操作（Cloudflare / GCP / Stripe / Supabase / Vercel 等）で生成・表示された資格情報は、まず作業 repo の `.env.local` 等にその場で保存する（手順とタイミングの正本は常時注入される `browser-infra-env-capture` ルール）。**この env 保存は消失防止の仮置きであって、恒久の置き場ではない。** 捕獲した同じターンで次まで進める。

1. エージェントは 1Password に書き込めない場面がある（ro SA は read-only、アイテムの新規登録は rw SA か人間の作業）。rw SA が使えるなら `fmtoken.sh --register <project>--<service>` で自分で登録する。使えないなら **主に `agents` 保管庫への登録を依頼する**（アイテム名 `<project>--<service>` / フィールド `credential`）
2. ただし **prod の書き込み可能キー**（service_role・live secret key 等）は、原本を **human-only 保管庫**へ、稼働コピーを **GitHub Actions secrets** へ登録依頼する（上の「資格情報の階層」の 2 行目）
3. 登録が確認できたら、env 側のコメントに「正本: 1Password / Actions secrets」と追記する。env から消すかは主の判断で、無断で消さない
  （例: `shukan--SUPABASE_SERVICE_ROLE_KEY_DEV` は `agents` 保管庫）。suffix の無い既存アイテムもあるため、
  そのキーがどちらの階層かはアイテム名ではなく**どの保管庫にあるか**で判断する

## 索引（1 サービス 1 行）

| サービス | CLI | 認証確認（verify） | トークン | ブラウザ必須の例外 |
|---|---|---|---|---|
| GitHub | gh | `gh auth status` | ログイン済みの `gh`（別アカウントは `GITHUB_TOKEN`） | OAuth アプリ承認・組織設定の一部 |
| Supabase | supabase | `supabase projects list` | `SUPABASE_ACCESS_TOKEN`（env） | ダッシュボード限定の設定変更 |
| Vercel | vercel | `vercel whoami` | `vercel --token "$VERCEL_TOKEN"`（env を `--token` へ明示的に渡す。CLI は自動では読まない） | ドメイン購入・課金設定 |
| Stripe | stripe | `stripe products list --limit 1` | `STRIPE_API_KEY`（env） | 本番モード切替・アカウント審査 |

セットアップ手順・運用知見・例外の具体例は同ディレクトリのサービス別ファイルに遅延ロード:
`github.md` / `supabase.md` / `vercel.md` / `stripe.md`

## CLI が無いサービス（ネガティブエントリ）

無い CLI を探し回るのが一番高くつく。以下はブラウザ操作が正当:

- **Google OAuth 同意画面・クライアント作成**: gcloud では不可。生成された credential はワンタイム表示 — 表示された次のアクションで env ファイルに保存する
- **サービスアカウントの権限変更**: 保管庫の製品によっては CLI/API から変えられない。その場合は取り消して再発行のみ（個人版が入っていれば、使っている保管庫の制約はそちらを見る）

## 新サービスの追加

実際に使った実績が出たら索引に 1 行 + サービス別ファイルを追加する。CLI が無いと判明したら、その事実をネガティブエントリに記録して調査の重複を防ぐ。
