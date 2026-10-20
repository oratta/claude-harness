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

- [ ] 4.1 `docs/public-private-split.md` の候補語で、dev-workflow の公開版の部品を `git grep -n` し直す（`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）。一覧に無い当たり（約 137 件のうち dev-workflow 分）を、載せない行の基準のどれに当たるか 1 件ずつ判定し、実施欄に「ファイル:行 — 当たる基準／直した／Orca の語なので #1177」の表で残す。当たらないものは 2・3 と同じ要領で直す。触る範囲: docs/public-private-split.md:254-266
- [ ] 4.2 一覧から、2・3・4.1 で直した行と、基準に当たると判定して外した行を消す
- [ ] 4.3 Orca の語を含む行（一覧の Orca の行と、4.1 で見つけた一覧に無い dev-workflow の Orca の行）の「直す issue」を `#1177` にする。Orca の行の本文は触らない。触る範囲: docs/public-private-split.md:131-248
- [ ] 4.4 一覧に残る `#1164` の行が、PR #1175 のマージ後も実ファイルに残っているかを確かめ、無ければ記録に事実を書く（この change では行を消さない。消すかは本体が決める）
- [ ] 4.5 `bats tests/public-private-split.bats` が通り、一覧に「担い手なし」の行が 0 件であることを `grep -c '担い手なし' docs/public-private-split.md` の行の表以外で確かめる（change A の分と合わせて）

## 5. 記録

- [ ] 5.1 変更の記録 `plugins/dev-workflow/changes/1168.md` に、外した固有名ごとに 1 行（元の場所・直し方）と、Orca の行を #1177 に付け替えたことを書く。触る範囲: plugins/dev-workflow/changes/1168.md（新規）
- [ ] 5.2 `bash scripts/test.sh` と `scripts/lint.sh` が通る
