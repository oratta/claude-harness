## Why

#1128 の仕分けで、`fmtoken.sh`（オーナーの 1Password の保管庫からトークンを取るラッパー）は個人版の部品に決まり、#1129 で公開版から消える。公開版に残る browser-guard の hook・SKILL.md の索引・サービス別ファイルと、その既存仕様・テストは、いまも `fmtoken.sh` を案内することを必須にしている。参照を外さないまま #1129 が着地すると、公開版が存在しない道具を案内する。

## What Changes

- browser-guard.sh の注意喚起 (2) を、`fmtoken.sh` の名指しをやめて「認証・トークンの在処はオーナーの環境の索引があればそちらを見る。無ければブラウザへ行かず主に尋ねる」に直す
- SKILL.md の冒頭 description・「原則」の節・索引の「トークン」列と、`github.md`・`stripe.md`・`supabase.md`・`vercel.md` の取得手順から `fmtoken.sh` の呼び出しを外す。トークンの列は、各 CLI が読む環境変数名またはログイン状態と、在処は個人版の索引を見る旨を書く
- `plugin.json`・`.claude-plugin/marketplace.json` の capability-registry の description と keywords、`README.md` の行、`dev-workflow/references/self-verification.md` の表の 1 行から `fmtoken` を外す
- `tests/browser-guard.bats`・`tests/skill-registry.bats` の `fmtoken` 検査を、新しい書き方の検査に置き換える
- 仕様の要件 2 つ（browser-guard「hook は deny ではなく注意喚起から始める」・skill「索引は 1 サービス 1 行で 1 画面以内を維持する」）を MODIFIED にする
- `capability-registry-fmtoken` の仕様はこの change では変えない（行き先は design.md の決定 3）

触らないもの: `fmtoken.sh`・`tests/fmtoken.bats`・`1password.md`・SKILL.md の「資格情報の階層」の節（その中の「ブラウザで捕獲した資格情報を env から昇格させる」を含む）は個人版に決まった部品で、消すのは #1129、個人版側で重ねて読む設定は #1130。

## Capabilities

### Modified Capabilities

- `capability-registry-browser-guard`: 注意喚起のメッセージが `fmtoken.sh` を名指しすることをやめ、トークンの在処をオーナーの環境の索引に委ねる書き方にする
- `capability-registry-skill`: 索引の各行がトークン取得方法を `fmtoken.sh <service>` で書くことをやめ、環境変数名または CLI のログイン状態と、個人版の索引への案内にする

## Impact

- 公開版の hook が出す文面が変わる（hook の入出力の形・発火条件・deny しない性質は変えない）
- 個人版の環境では、トークンの具体的な取り方（`fmtoken.sh`）は個人版の索引が案内する。重ねて読む設定は #1130
- #1129 より前、または同じ PR で着地させる（後になると、公開版が存在しない道具を案内する期間ができる）
