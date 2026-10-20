## Context

#1128 の `docs/public-private-split.md` 小節「公開版に残る部品から `fmtoken.sh` への参照を外す作業」が対象の一覧と担い手（#1164）を決めた。この change はその一覧を実装する。公開版の部品は個人版の有無に依らず意味が通る必要がある。

## Decisions

### 1. 公開版の書き方は「在処はオーナーの環境の索引を見る」

注意喚起 (2) は「認証・トークンの在処は、オーナーの環境の索引（個人版）があればそちらで確かめる。無ければブラウザに行かず主に尋ねる」とする。`fmtoken.sh`・exit 44 のような個人版の道具の固有の振る舞いは書かない。案内の宛先が存在しなくても文が壊れないのが条件。

### 2. 索引の「トークン」列は環境変数名とログイン状態

各行は、CLI が読む環境変数名（GitHub は `GITHUB_TOKEN`、Supabase は `SUPABASE_ACCESS_TOKEN`、Vercel は `--token` または `VERCEL_TOKEN`、Stripe は `STRIPE_API_KEY`、1Password は `OP_SERVICE_ACCOUNT_TOKEN`）と、ログイン済みならそれで動く旨を書く。値の取得元は列に書かず、SKILL.md の「原則」の 1 か所で「在処はオーナーの環境の索引があればそちらを見る」と案内する。選ばなかった案は「列ごとに『個人版を参照』と繰り返す」（1 画面以内の制約に反して冗長）。

### 3. 公開版の索引から 1Password の行と `1password.md` への案内を外す

`1password.md` は個人版に決まった部品で、#1129 で公開版から消える。索引に 1Password の行と詳細ファイルの案内を残すと、#1129 のあと公開版の索引が存在しないファイルを指し、受け入れ条件の「個人版の有無に依らない書き方」を満たせない。#1128 の一覧(`docs/public-private-split.md`)でも SKILL.md の 1Password の行は #1164 の担当なので、同じ PR の中で外す(#1129 に先送りしない。先送りすると #1129 までの間、行が `fmtoken.sh --register` と保管庫名を案内し続け、fmtoken が 0 件の条件も崩れる)。外した行と案内は個人版の索引が持つ(重ねて読む設定は #1130)。

外すのは索引の 1Password の行と、遅延ロード一覧の `1password.md` だけ。`1password.md` 本体、「資格情報の階層」の節、ネガティブエントリの「1Password の SA 権限変更」(#1128 の一覧で担い手なし)は消さない。公開版の索引に残るのは GitHub・Supabase・Vercel・Stripe の 4 行。

### 4. `capability-registry-fmtoken` の仕様は個人版へ移す。この change では変更も REMOVED もしない

どちらを選んでも受け入れ条件と利用者に見える振る舞いは変わらないため、W が決めた。

- `fmtoken.sh` と `tests/fmtoken.bats` は #1129 まで公開版に残る。いま REMOVED にすると、実体があるのに仕様が無い期間ができる
- REMOVED は仕様そのものを消す。`fmtoken.sh` は個人版で使い続けるので、仕様も個人版へ持っていくほうが履歴と要件が残る（消すと個人版側で書き直しになる）
- 実際の移動（`openspec/specs/capability-registry-fmtoken/` を個人版へ）は、`fmtoken.sh` を移す #1129 の作業に含める

### 5. 説明文の追従範囲

受け入れ条件の grep の範囲（`plugins/capability-registry`・`plugins/dev-workflow/references`）の外だが、`.claude-plugin/marketplace.json` の capability-registry の description と keywords、`README.md` の行にも同じ案内が残る。公開版の説明が移した道具を指さないよう、同じ書き換えに含める。

## Risks / Trade-offs

- 個人版の索引が #1130 で重ねて読まれるまで、オーナーの環境では `fmtoken.sh` の案内が出ない期間ができうる。#1129 と #1130 を組で着地させる前提（#1129 の受け入れ条件に順序の手順がある）で、この change 単独では公開版が壊れない側に倒した
