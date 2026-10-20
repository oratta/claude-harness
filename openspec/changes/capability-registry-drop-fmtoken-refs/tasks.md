## 1. 注意喚起と検査（hook）

- [ ] 1.1 `browser-guard.sh` の注意喚起 (2) を、fmtoken の名指しと exit 44 を外し「認証・トークンの在処はオーナーの環境の索引があればそちらを見る。無ければブラウザへ行かず主に尋ねる」に直す。(1)(3) と最終文は変えない。触る範囲: plugins/capability-registry/scripts/browser-guard.sh:28-35
- [ ] 1.2 `tests/browser-guard.bats` の検査語から `fmtoken` を外し、出力に `fmtoken` が含まれないこと・在処の案内の語が含まれることを検査する。触る範囲: plugins/capability-registry/tests/browser-guard.bats:49-61

## 2. 索引とサービス別ファイル

- [ ] 2.1 SKILL.md の description（3 行目）から「（fmtoken.sh）」を外す。触る範囲: plugins/capability-registry/skills/capability-registry/SKILL.md:3
- [ ] 2.2 SKILL.md の「原則」の 2 番を、トークンの在処はオーナーの環境の索引があればそちらを見る・手元に無ければブラウザに行かず主に発行を依頼する、に書き換え、fmtoken の取得・登録・確認・`--name` の子項目を外す。「資格情報の階層」以降は触らない。触る範囲: plugins/capability-registry/skills/capability-registry/SKILL.md:13-22（「原則」の節）
- [ ] 2.3 SKILL.md の索引（「トークン」列）の 5 行を、環境変数名またはログイン状態に書き換える（1Password 行の「`fmtoken.sh --register`」も外す）。触る範囲: plugins/capability-registry/skills/capability-registry/SKILL.md:52-64（「索引」の節）
- [ ] 2.4 `github.md`・`stripe.md`・`supabase.md`・`vercel.md` の fmtoken 呼び出しを、環境変数またはログイン状態での書き方に直す。触る範囲: plugins/capability-registry/skills/capability-registry/github.md:4、stripe.md:3-4、supabase.md:3-4、vercel.md:3-4
- [ ] 2.5 `tests/skill-registry.bats` の「fmtoken.sh token retrieval」の検査を、原則の節に在処の案内があり、description・原則・索引・サービス別ファイルに `fmtoken` が無いことの検査に置き換える（「資格情報の階層」の節は個人版なので検査の対象に入れない）。触る範囲: plugins/capability-registry/tests/skill-registry.bats:42-48

## 3. 説明文と他の参照

- [ ] 3.1 `plugin.json` の description の fmtoken.sh の記述と keywords の `fmtoken` を外す。触る範囲: plugins/capability-registry/.claude-plugin/plugin.json:3,14
- [ ] 3.2 `.claude-plugin/marketplace.json` の capability-registry の description と keywords から fmtoken を外す。触る範囲: .claude-plugin/marketplace.json:113,125
- [ ] 3.3 `README.md` の capability-registry の行から「`fmtoken.sh` を同梱」を外す。触る範囲: README.md:66
- [ ] 3.4 `self-verification.md` の表の capability-registry の行から `fmtoken.sh --register` の文を外す。触る範囲: plugins/dev-workflow/references/self-verification.md:53

## 4. 確認

- [ ] 4.1 `git grep -n fmtoken -- plugins/capability-registry plugins/dev-workflow/references` の当たりが、`fmtoken.sh`・`tests/fmtoken.bats`・`1password.md`・SKILL.md の「資格情報の階層」の節の中だけであることを確かめる
- [ ] 4.2 `bats plugins/capability-registry/tests/ plugins/dev-workflow/tests/self-verification-sections.bats tests/public-private-split.bats tests/marketplace-sync.bats` が通る
- [ ] 4.3 `openspec validate capability-registry-drop-fmtoken-refs --type change --strict` が通る
