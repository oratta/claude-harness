## 1. テストを先に書く（落ちることを確かめる）

- [x] 1.1 `tests/public-private-split.bats` の末尾に、spec「dev-workflow 以外の公開版の部品は決めた固有名とオーナーの PC のパスを持たない」の検索のテストを足す（固定の語・対象の公開版のファイル・節・許可リストの作り方は spec のとおり。個人版に決まるファイルと節、`changes/`・`CHANGELOG.md`・`tests/`・`evals/` は除く）。許可リストの件は 4.1 の判定の表と同じ内容で足す。触る範囲: tests/public-private-split.bats:422-440（末尾の `@test` のあと）
- [x] 1.2 statusline の bats に、新名 `CLAUDE_RATE_SHARE_DIR`・`CLAUDE_RATE_SHARE_CONF`、旧名の互換、新名が旧名に優先、空文字・空白だけで共有を無効にする（新名・旧名の両方）の Scenario を足す。spec の Scenario のとおり、旧 DIR（新 DIR 未定義）・新 CONF（両 DIR 未定義で新旧 CONF が競合）・新 CONF の欠落や有効行なしのときの旧 CONF・旧 DIR と新 CONF の競合（旧 DIR が勝つ）を含める。触る範囲: plugins/statusline/tests/statusline-rate-snapshot.bats:50-90
- [x] 1.3 `bats tests/public-private-split.bats plugins/statusline/tests/` で、足したテストが落ち、既存のテストが通ることを確かめる

## 2. statusline の振る舞い

- [x] 2.1 `resolve_rate_share_dir` を spec の優先順（新名 DIR → 旧名 DIR → 新名 CONF → 旧名 CONF）に直す。旧名を読む箇所に「互換。主は新名」とコメントする。触る範囲: plugins/statusline/scripts/statusline.sh:71-95
- [x] 2.2 README の共有先の説明を新名を主に書き、旧名は互換と書く。触る範囲: plugins/statusline/README.md:94-96、plugins/statusline/README.md:6（表示例の workspace のパスとアカウント名を example に）
- [x] 2.2b README に移行の説明を足す: 連携先の reader が旧名だけを読む間は、新名（`CLAUDE_RATE_SHARE_DIR` か `CLAUDE_RATE_SHARE_CONF`）だけに移すと reader が追従できないので、新旧を同じ共有先に揃える（旧名を残すか、新旧に同じパスを書く）。連携先が新名に対応してから旧名を消せる。触る範囲: plugins/statusline/README.md:94-96
- [x] 2.3 既存の `openspec/specs/rate-snapshot/spec.md` の該当要件は archive で更新される（この change の差分のとおり）。ほかのテスト（`statusline-copy-update.bats`・`statusline-multi-account.bats`）が旧名で通ることを確かめる（書き換えない）

## 3. 固有名の置き換え

各行は design D1 の選び方に従う。行番号は仕様づくりの時点の値で、ずれていたら候補語の `git grep` で探し直す。

- [x] 3.1 rules と scripts: `rules/README.md` の 5・20〜22・37・43、`scripts/sync.sh` の 12・13、`scripts/test-auto-merge-workflow.sh` の 97・174。触る範囲: rules/README.md:5-43、scripts/sync.sh:12-13、scripts/test-auto-merge-workflow.sh:97、scripts/test-auto-merge-workflow.sh:174
- [x] 3.2 capability-registry: `SKILL.md:65`（個人版の有無に依らない書き方）、`stripe.md:5`、`supabase.md` の 5・10。触る範囲: plugins/capability-registry/skills/capability-registry/SKILL.md:65、plugins/capability-registry/skills/capability-registry/stripe.md:5、plugins/capability-registry/skills/capability-registry/supabase.md:5-10
- [x] 3.3 worktree: `wt-clean/SKILL.md` の 50・336・337・368〜370・1199・1201・1251〜1268 の出力例と cron の例、`wt-clean-orphan-detection.md:18`。触る範囲: plugins/worktree/skills/wt-clean/SKILL.md:50、plugins/worktree/skills/wt-clean/SKILL.md:336-370、plugins/worktree/skills/wt-clean/SKILL.md:1199-1268、plugins/worktree/references/wt-clean-orphan-detection.md:18
- [x] 3.4 product-handover: `plugin.json:3`、README の 28・57・58・60。触る範囲: plugins/product-handover/.claude-plugin/plugin.json:3、plugins/product-handover/README.md:28-60
- [x] 3.5 casting: `catalog/injection.md` の 42・79・80、`catalog/delegation.md:24`。触る範囲: plugins/casting/catalog/injection.md:42-80、plugins/casting/catalog/delegation.md:24
- [x] 3.6 cost-ledger: `README.md` の 107・238、`commands/cost.md:58`。触る範囲: plugins/cost-ledger/README.md:107、plugins/cost-ledger/README.md:238、plugins/cost-ledger/commands/cost.md:58
- [x] 3.7 infra: 2 つのテンプレートの手本の参照。触る範囲: plugins/infra/templates/workflows/deploy-production.yml.template:77、plugins/infra/templates/workflows/weekly-full.yml.template:53
- [x] 3.8 `bash scripts/test.sh` のうち触ったプラグインの bats と `bats tests/public-private-split.bats` が通る

## 4. 候補語の判定と一覧

- [x] 4.1 `docs/public-private-split.md` の候補語で、dev-workflow を除く公開版の部品を `git grep -n` し直す（`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）。一覧に無い当たり（約 137 件のうち dev-workflow 以外）を、載せない行の基準のどれに当たるか 1 件ずつ判定し、実施欄に「ファイル:行 — 当たる基準／直した」の表で残す。当たらないものは 3 と同じ要領で直す。触る範囲: docs/public-private-split.md:254-266
- [x] 4.2 「載せない行の基準」に「互換のために残す旧名の読み取り」を足す（spec のとおり）。触る範囲: docs/public-private-split.md:258-266
- [x] 4.3 一覧から、3・4.1 で直した行と、基準に当たると判定して外した行（理由は 4.1 の表）を消す。dev-workflow 以外の「担い手なし」が 0 件になる。触る範囲: docs/public-private-split.md:131-248
- [x] 4.4 `bats tests/public-private-split.bats` が通る

## 5. 記録

- [x] 5.1 変更の記録を書く: `plugins/statusline/changes/1168.md`（新名の追加と旧名の互換）、触ったほかのプラグインの `changes/1168.md`（capability-registry・worktree・product-handover・casting・cost-ledger・infra）。外した固有名ごとに 1 行（元の場所・直し方）。触る範囲: plugins/statusline/changes/1168.md（新規）ほか各 plugins/<name>/changes/1168.md（新規）
- [x] 5.2 `bash scripts/test.sh` と `scripts/lint.sh` が通る

## 実施欄: 4.1 の判定の表

対象は仕分けの表で公開版に決まる dev-workflow 以外の部品（`rules/`（`plugin-editing.md` を除く）・`output-styles/`・`scripts/`・worktree・infra・capability-registry の公開版のファイルと節・casting・cost-ledger・statusline・product-handover。`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）。候補語は `docs/public-private-split.md` の候補語。リポジトリ直下の `README.md`・`CLAUDE.md`・`.claude-plugin/marketplace.json`・`_longruns/` などは仕分けの表の公開版の部品に載っていないので、この change では見ていない。下の表の行は、`tests/public-private-split.bats` の許可リストの各件と対応する（出典・互換の行）。

### 許可リストの件（出典・互換）

| ファイル:行 | 判定 |
|---|---|
| `rules/README.md:41` 経緯（flatmate#599 / #608） | 出典 |
| `scripts/sync.sh:5` flatmate#362 | 出典 |
| `plugins/infra/agents/infra-phase-1-hearing.md:143`・`skills/infra-setup/SKILL.md:258`・`templates/workflows/ci.yml.template:24` 「2026-07 に suimei で」 | 出典 |
| `plugins/infra/skills/infra-setup/SKILL.md:270` 「flatmate で 2026-10 に実発生」 | 出典 |
| `plugins/infra/templates/workflows/weekly-full.yml.template:72` 「2026-07-25 に suimei で実発生」 | 出典 |
| `plugins/statusline/README.md:94` 旧名 `FLATMATE_RATE_SHARE_*` の記述 | 互換（新名が主と同じ箇所に書いた） |
| `plugins/statusline/scripts/statusline.sh:76,77,80,81,91` | 互換（同じ関数の冒頭に「旧名は互換、主は CLAUDE_*」と書いた） |
| `plugins/statusline/scripts/statusline.sh:174` flatmate#605 | 出典 |
| `plugins/worktree/.claude-plugin/plugin.json:3`・`scripts/wt-setup.sh:28,118,177` flatmate#320 | 出典 |
| `plugins/worktree/scripts/wt-setup.sh:185` 「実例: suimei の .env.local.example」 | 出典 |
| `plugins/worktree/references/wt-clean-orphan-detection.md:9`・`wt-clean-verification.md:25`・`skills/wt-clean/SKILL.md:103,140,448` 「2026-08-xx に flatmate で」 | 出典 |
| `plugins/worktree/skills/wt-clean/SKILL.md:566` 「2026-08-07 に shukan-dev で実走」 | 出典 |

### 許可リストに載せない当たり（基準で説明でき、検索語にも当たらない）

| ファイル:行 | 判定 |
|---|---|
| 各プラグインの `.claude-plugin/plugin.json` の `author` の `Oratta`・`plugins/infra/README.md:94` | 公開版自身の名前 |
| `plugins/cost-ledger/scripts/cost_ledger.py:887` `LLM_LOG_DIR` | 公開版自身の名前（この公開版の CLAUDE.md が定める環境変数） |
| `scripts/test-auto-merge-workflow.sh:669,789` `human-only` | GitHub のラベル名 |
| `scripts/test-auto-merge-workflow.sh:711` 出典: oratta/marketing-harness#36 | 出典 |
| `plugins/infra/agents/infra-phase-2-supabase.md:115`・`plugins/worktree/references/session-devserver-cleanup.md:36`・`plugins/worktree/skills/wt-clean/SKILL.md:729` | 一般の製品を例の 1 つとして並べる行（1Password / Bitwarden / Keychain、Orca、Dropbox） |
| `plugins/worktree/skills/wt-clean/SKILL.md:778`、`plugins/statusline/README.md:151` `/Users/x`・`/Users/example` | 置き換える前提の例 |
| `plugins/worktree/skills/wt-clean/SKILL.md:50` `~/repos/example-app` と、直した出力例の `/Users/example/...` | 置き換え後の例（直した） |
| `rules/README.md:36`・`rules/browser-infra-env-capture.md:10` 「保管庫」 | 固有名でない一般語（直す箇所なし） |
| `plugins/capability-registry/skills/capability-registry/SKILL.md:28,34,45` | 個人版に決まる節「資格情報の階層」の中（検索の対象外） |

### 直した行

一覧にあった 49 行（一覧から外した）と、一覧に無かった次の 2 行を直した: `rules/README.md:38`（flatmate の boot での毎世代実行）、`plugins/worktree/scripts/wt-setup.sh:123`（flatmate の workspace を例にした行）。
