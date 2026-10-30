## 1. テストを先に書く（落ちることを確かめる）

- [x] 1.1 `tests/public-private-split.bats` の末尾に、spec「dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない」の検索のテストを足す（語と対象ファイルは spec のとおり）。Scenario「Orca 経路の行に担い手が付く」のテストも足す（一覧の dev-workflow の行に「担い手なし」が無いこと）。触る範囲: tests/public-private-split.bats:422-460（末尾の `@test` のあと）
- [x] 1.2 `bats tests/public-private-split.bats` で、足したテストが落ち、既存のテストが通ることを確かめる

## 2. flatmate の名指しを外す

各行は design D1 に従う。行番号は仕様づくりの時点の値で、ずれていたら候補語の `git grep` で探し直す。

- [x] 2.1 `plugins/dev-workflow/README.md:137`。触る範囲: plugins/dev-workflow/README.md:137
- [x] 2.2 develop `SKILL.md` の 337・400・541（Orca 経路の節に入らない行だけ。節をまたがない）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:337、plugins/dev-workflow/skills/develop/SKILL.md:400、plugins/dev-workflow/skills/develop/SKILL.md:541
- [x] 2.3 `pr-body-format.md:110`・`issueify/SKILL.md:41`・`push-guard-setup/SKILL.md:23`・`escalation-tripwires.md:16`・`pr-state.sh:2`。触る範囲: plugins/dev-workflow/references/pr-body-format.md:110、plugins/dev-workflow/skills/issueify/SKILL.md:41、plugins/dev-workflow/skills/push-guard-setup/SKILL.md:23、plugins/dev-workflow/templates/escalation-tripwires.md:16、plugins/dev-workflow/scripts/pr-state.sh:2
- [x] 2.4 `memory-refresh/SKILL.md` の 76・82・94（例の表と説明）。触る範囲: plugins/dev-workflow/skills/memory-refresh/SKILL.md:76-94

## 3. オーナーの環境の前提と検査の入力

- [x] 3.1 `ci-watch.md:95`（`CLAUDE_HARNESS_DEV_DIR`）、`self-verification.md:41`（daily-report と Obsidian の vault）、`templates/auto-merge/docs/auto-merge.md:273`（agents 保管庫）。触る範囲: plugins/dev-workflow/references/ci-watch.md:95、plugins/dev-workflow/references/self-verification.md:41、plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md:273
- [x] 3.2 `templates/auto-merge/scripts/test-auto-merge-workflow.sh` の 87・148 の `workspace/moko/CLAUDE.md` を `workspace/example/CLAUDE.md` に置き換え、スクリプトを走らせて結果が変わらないことを確かめる。触る範囲: plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh:87、plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh:148
- [x] 3.3 文面を固定している dev-workflow の bats があれば、新しい文に合わせる（期待する挙動は変えない）。`bats plugins/dev-workflow/tests/` が通る

## 4. 候補語の判定と一覧

- [x] 4.1 `docs/public-private-split.md` の候補語で、dev-workflow の公開版の部品を `git grep -n` し直す（`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）。一覧に無い当たり（約 137 件のうち dev-workflow 分）を、載せない行の基準のどれに当たるか 1 件ずつ判定し、実施欄に「ファイル:行 — 当たる基準／直した／Orca の語なので #1177」の表で残す。出典に当たる行は、spec の許可リストに載せる行として表に同じ内容（パス・固定の文字列・基準）を書く。当たらないものは 2・3 と同じ要領で直す。触る範囲: docs/public-private-split.md:254-266
- [x] 4.2 一覧から、2・3・4.1 で直した行と、基準に当たると判定して外した行を消す
- [x] 4.3 Orca 経路の行を #1177 に付け替える。手順: (1) 一覧の既存の dev-workflow の Orca 経路の行（README.md:15、develop SKILL.md の 46・207・350・353・375・481〜525、reply-after-idle.md、owner-reply-check.sh、declarations.md、stages/pass.md:95）を、行番号でなく内容で現在の行に照合し直す。(2) Orca の語だけでは拾えない関連段落（例: develop SKILL.md の `cld --model` で子セッションを起動する段落や、起動説明・上限の段落）も、一覧の行の内容と同じ話題なら #1177 の引き渡し対象に含める。(3) 結果を実施欄に「一覧の旧行 → 現在のファイル:行 — 内容 — 担い手 #1177」の対応表で残し、一覧の該当行の場所と「直す issue」を #1177 にする（Orca の語が無くて一覧に無い関連段落は行を足す）。Orca の行の本文は触らない。触る範囲: docs/public-private-split.md:131-248
- [x] 4.4 一覧に残る担い手 `#1164` の行を、PR #1175 のマージ後の実ファイルで 1 行ずつ確かめる（`fmtoken` で `git grep`）。実ファイルから既に消えていた行（例: `plugin.json:3,14`・`browser-guard.sh:31`）は、この PR で一覧から消し、実施欄の表に「消えていることを確かめたコマンドと結果」を残す。消えていない行があれば担い手を `#1164` のまま残し、残した行と理由を実施欄に記録する。触る範囲: docs/public-private-split.md:131-248
- [x] 4.5 `bats tests/public-private-split.bats` が通り、一覧に「担い手なし」の行が 0 件であることを `grep -c '担い手なし' docs/public-private-split.md` の行の表以外で確かめる（change A の分と合わせて）

## 5. 記録

- [x] 5.1 変更の記録 `plugins/dev-workflow/changes/1168.md` に、外した固有名ごとに 1 行（元の場所・直し方）、Orca の行を #1177 に付け替えたこと、#1164 の行を一覧から消したことを書く。触る範囲: plugins/dev-workflow/changes/1168.md（新規）
- [x] 5.2 `bash scripts/test.sh` と `scripts/lint.sh` が通る

## 実施欄

### 2・3 で直した行（実行コマンド: `bats tests/public-private-split.bats` exit 0、`bats plugins/dev-workflow/tests/ci-watch.bats` は 3.3 の修正後に通る）

| 元の場所 | 直し方 |
|---|---|
| `README.md:137` | 憲法の正本を「各リポに配るリポジトリ側」と書いた |
| develop `SKILL.md` 337・400・541（現在は 561） | 起動のきっかけの置き場・channel の説明・棲み分け相手の保守先から flatmate を外した |
| `pr-body-format.md:110`・`issueify/SKILL.md:41`・`push-guard-setup/SKILL.md:23` | `new-resident` が配る・設置する書き方をやめた |
| `escalation-tripwires.md:16`・`pr-state.sh:2` | 「それを配るリポジトリ」「常駐の見張り（pr-watch など）」にした |
| `memory-refresh/SKILL.md` 76・82・94 | 配布元のリポジトリ・開発用 clone の方式・別リポジトリ側の事実と一般の言い方にした |
| `ci-watch.md:95`・`self-verification.md:41,42`・`auto-merge.md:273` | 環境変数名・Obsidian の保管庫・agents 保管庫を外した |
| `test-auto-merge-workflow.sh:87,148` | `workspace/example/CLAUDE.md` に置換。テンプレートは単体では `ci.yml` が無く走らないので、ci.yml を足した一時ツリーで置換前後を実行し、どちらも `115 passed, 0 failed`（出力の差は置換した 2 行のパスだけ） |

3.3: `plugins/dev-workflow/tests/ci-watch.bats:338` の語の一覧が `CLAUDE_HARNESS_DEV_DIR` を求めていたので外した。同じ語を求める既存の仕様 `dev-workflow-ci-watch` の要件も、この change の `specs/dev-workflow-ci-watch/spec.md` の MODIFIED で直した（実装中に見つけて足した決定。要件の本文は語の 2 か所以外そのまま）。

### 4.1 候補語の判定（dev-workflow の公開版。一覧に無かった当たり）

検索: `git grep -n -E '<候補語>' -- plugins/dev-workflow ':!*/changes/*' ':!*/CHANGELOG.md' ':!*/tests/*' ':!*/evals/*' ':!plugins/dev-workflow/docs/auto-merge-deployments.md'`。当たり 102 行のうち一覧に無かったもの:

| ファイル:行 | 当たる基準 |
|---|---|
| `.claude-plugin/plugin.json:5`（author Oratta） | 公開版自身の名前 |
| `README.md:21`・`templates/auto-merge/.github/workflows/auto-merge.yml:4`・`templates/auto-merge/README.md:5`（「genetta-inc の flatmate リポで実運用検証済み」） | 出典 |
| `references/ci-watch.md:93`（flatmate の `docs/project-modes.md` から移したもの） | 出典 |
| `references/one-off-operations.md:7`（flatmate#599 / #608）、`skills/develop/references/roles/worker/common.md:15`（flatmate #701） | 出典 |
| develop `SKILL.md:66,71`（例: flatmate #1104・#1564） | 出典 |
| `templates/auto-merge/.github/workflows/staging-smoke.yml:11`（suimei の初回実戦）、`templates/auto-merge/README.md:117`（flatmate でのレビュー）、`templates/auto-merge/scripts/test-auto-merge-workflow.sh:606`（oratta/marketing-harness#36） | 出典 |
| `ci-watch.md:78`・`parent-merge-criteria.md:15`・`issueify/SKILL.md:71`・`auto-merge.yml:195`・`auto-merge.md` の 28・138・146・174・196・303・`test-auto-merge-workflow.sh` の 564・684 の `human-only` | GitHub のラベル名 |
| `oratta/claude-harness`・`oratta-claude-harness` を含む行 | 公開版自身の名前 |
| Orca の語を含む行（SKILL.md・README.md:15・reply-after-idle.md・owner-reply-check.sh・declarations.md・pass.md） | Orca の語なので #1177（一覧に既にある行のほか、SKILL.md:524・530 を足した） |
| `epic-dispatch.sh`・`epic-launch-orca.sh`・`stop-judge.sh`・`parent-pass-criteria.md`・`parent-merge-criteria.md` の Orca の語 | 保留の部品なので一覧の対象外 |

spec の検索の範囲（`moko`・`new-resident`・`flatmate`・`CLAUDE_HARNESS_DEV_DIR` の対象ファイル）には、出典に当たる行が残っていないので、`tests/public-private-split.bats` の許可リスト `DEVWF_ALLOW` は空。

### 4.3 Orca 経路の行の対応表（一覧の旧行 → 現在のファイル:行 — 担い手 #1177）

行番号のずれは `SKILL.md` だけで、ほかは同じ番号のまま。内容は `git grep -n -E 'Orca|\bcld\b'` で照合した。

| 旧行 | 現在 | 内容 |
|---|---|---|
| `README.md:15` | 同じ | エピックの子を Orca の子ワークツリーで起動する経路 |
| develop `SKILL.md` 46・207・350・353・375・481・485・487・489・491・498・499・504 | 同じ | 判定 `orca`・片付け・子の停止の記録と印・経路の決め方・`nested`（`cld`）・Orca 経路・状態の正本・親の発言・失敗の扱い・再開・マージ待ちの子 |
| `SKILL.md:506` | 526 | 子セッションを `cld --model` で起動する |
| `SKILL.md:508` | 528 | 同時に動く子の上限 |
| `SKILL.md:514` | 534 | サブエージェント方式の上限を Orca 経路と同じにする（別のリポジトリの子を Orca 経路でだけ起動する文も同じ行） |
| `SKILL.md:525` | 545 | 状態ディレクトリの確認 |
| 一覧に無かった関連段落 | `SKILL.md:524`、`SKILL.md:530` | 別のリポジトリの子の clone を Orca に登録済みのリポジトリから探す段落（Orca の語あり）、`cld`（`EPIC_DISPATCH_CLAUDE_CMD`）が付ける `--dangerously-skip-permissions` の起動の説明（Orca の語なし） |
| `reply-after-idle.md` 3・5・64、`owner-reply-check.sh` 33・52、`declarations.md` 83・91・103、`stages/pass.md:95` | 同じ | 返事の規則・prompt の書式・親が打ち込んだ文の扱い |

### 4.4 #1164 の行

PR #1175 のマージ後の木（`origin/main` 04eae7a7 を含む）で、`git grep -n fmtoken -- <ファイル>` を 11 ファイル（`plugin.json`・`browser-guard.sh`・`github.md`・`stripe.md`・`supabase.md`・`vercel.md`・`self-verification.md`）に実行し、すべて当たり 0 件。担い手 #1164 の 11 行を一覧から消した。残した行は無い。

### 4.5

`grep -F '| `' docs/public-private-split.md | grep -c '担い手なし'` が 0。`bats tests/public-private-split.bats` は 26 件すべて ok、exit 0。

