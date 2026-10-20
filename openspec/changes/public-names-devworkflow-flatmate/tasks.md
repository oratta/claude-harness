## 1. テストを先に書く（落ちることを確かめる）

- [ ] 1.1 `tests/public-private-split.bats` の末尾に、spec「dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない」の検索のテストを足す（語と対象ファイルは spec のとおり）。Scenario「Orca 経路の行に担い手が付く」のテストも足す（一覧の dev-workflow の行に「担い手なし」が無いこと）。触る範囲: tests/public-private-split.bats:422-460（末尾の `@test` のあと）
- [ ] 1.2 `bats tests/public-private-split.bats` で、足したテストが落ち、既存のテストが通ることを確かめる

## 2. flatmate の名指しを外す

各行は design D1 に従う。行番号は仕様づくりの時点の値で、ずれていたら候補語の `git grep` で探し直す。

- [ ] 2.1 `plugins/dev-workflow/README.md:137`。触る範囲: plugins/dev-workflow/README.md:137
- [ ] 2.2 develop `SKILL.md` の 337・400・541（Orca 経路の節に入らない行だけ。節をまたがない）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:337、plugins/dev-workflow/skills/develop/SKILL.md:400、plugins/dev-workflow/skills/develop/SKILL.md:541
- [ ] 2.3 `pr-body-format.md:110`・`issueify/SKILL.md:41`・`push-guard-setup/SKILL.md:23`・`escalation-tripwires.md:16`・`pr-state.sh:2`。触る範囲: plugins/dev-workflow/references/pr-body-format.md:110、plugins/dev-workflow/skills/issueify/SKILL.md:41、plugins/dev-workflow/skills/push-guard-setup/SKILL.md:23、plugins/dev-workflow/templates/escalation-tripwires.md:16、plugins/dev-workflow/scripts/pr-state.sh:2
- [ ] 2.4 `memory-refresh/SKILL.md` の 76・82・94（例の表と説明）。触る範囲: plugins/dev-workflow/skills/memory-refresh/SKILL.md:76-94

## 3. オーナーの環境の前提と検査の入力

- [ ] 3.1 `ci-watch.md:95`（`CLAUDE_HARNESS_DEV_DIR`）、`self-verification.md:41`（daily-report と Obsidian の vault）、`templates/auto-merge/docs/auto-merge.md:273`（agents 保管庫）。触る範囲: plugins/dev-workflow/references/ci-watch.md:95、plugins/dev-workflow/references/self-verification.md:41、plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md:273
- [ ] 3.2 `templates/auto-merge/scripts/test-auto-merge-workflow.sh` の 87・148 の `workspace/moko/CLAUDE.md` を `workspace/example/CLAUDE.md` に置き換え、スクリプトを走らせて結果が変わらないことを確かめる。触る範囲: plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh:87、plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh:148
- [ ] 3.3 文面を固定している dev-workflow の bats があれば、新しい文に合わせる（期待する挙動は変えない）。`bats plugins/dev-workflow/tests/` が通る

## 4. 候補語の判定と一覧

- [ ] 4.1 `docs/public-private-split.md` の候補語で、dev-workflow の公開版の部品を `git grep -n` し直す（`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）。一覧に無い当たり（約 137 件のうち dev-workflow 分）を、載せない行の基準のどれに当たるか 1 件ずつ判定し、実施欄に「ファイル:行 — 当たる基準／直した／Orca の語なので #1177」の表で残す。出典に当たる行は、spec の許可リストに載せる行として表に同じ内容（パス・固定の文字列・基準）を書く。当たらないものは 2・3 と同じ要領で直す。触る範囲: docs/public-private-split.md:254-266
- [ ] 4.2 一覧から、2・3・4.1 で直した行と、基準に当たると判定して外した行を消す
- [ ] 4.3 Orca 経路の行を #1177 に付け替える。手順: (1) 一覧の既存の dev-workflow の Orca 経路の行（README.md:15、develop SKILL.md の 46・207・350・353・375・481〜525、reply-after-idle.md、owner-reply-check.sh、declarations.md、stages/pass.md:95）を、行番号でなく内容で現在の行に照合し直す。(2) Orca の語だけでは拾えない関連段落（例: develop SKILL.md の `cld --model` で子セッションを起動する段落や、起動説明・上限の段落）も、一覧の行の内容と同じ話題なら #1177 の引き渡し対象に含める。(3) 結果を実施欄に「一覧の旧行 → 現在のファイル:行 — 内容 — 担い手 #1177」の対応表で残し、一覧の該当行の場所と「直す issue」を #1177 にする（Orca の語が無くて一覧に無い関連段落は行を足す）。Orca の行の本文は触らない。触る範囲: docs/public-private-split.md:131-248
- [ ] 4.4 一覧に残る担い手 `#1164` の行を、PR #1175 のマージ後の実ファイルで 1 行ずつ確かめる（`fmtoken` で `git grep`）。実ファイルから既に消えていた行（例: `plugin.json:3,14`・`browser-guard.sh:31`）は、この PR で一覧から消し、実施欄の表に「消えていることを確かめたコマンドと結果」を残す。消えていない行があれば担い手を `#1164` のまま残し、残した行と理由を実施欄に記録する。触る範囲: docs/public-private-split.md:131-248
- [ ] 4.5 `bats tests/public-private-split.bats` が通り、一覧に「担い手なし」の行が 0 件であることを `grep -c '担い手なし' docs/public-private-split.md` の行の表以外で確かめる（change A の分と合わせて）

## 5. 記録

- [ ] 5.1 変更の記録 `plugins/dev-workflow/changes/1168.md` に、外した固有名ごとに 1 行（元の場所・直し方）、Orca の行を #1177 に付け替えたこと、#1164 の行を一覧から消したことを書く。触る範囲: plugins/dev-workflow/changes/1168.md（新規）
- [ ] 5.2 `bash scripts/test.sh` と `scripts/lint.sh` が通る
