# Tasks

範囲の注意: #1541 が求める `dismiss` の条件のうち、この change で入るのは `止まった理由:` の行が無いことだけで、`.questions`・`unreadable` の条件は足さず #1541 は解消しない。#1541〜#1545 の中身は取り込まない。

## 1. 子の手順

- [ ] 1.1 `epic-child-stop.md` を書き換える: `mark` の語を全部消し（声かけの段落の `mark resumed` / `mark stopped` を含む）、親からの返事を受けるときの `mark resumed` もなくし、記録を残す場面を PR のリスク許容だけにする。`--relayed` / `--delegated` と委任の 6 条件・4 条件の文は変えない（`develop-skill.bats` と `pr-review-gate-skill.bats` が同じ文字列を検査する）。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:7-37
- [ ] 1.2 同じファイルに定型の止まりの節を足す（`止まった理由:` の行を最後の発言の末尾に書く 3 種）。「記録の形」に、定型の止まりは記録を残さず行で渡す旨の 1 行を足す。記録を残さない止まりでも発言の中で質問・推奨・根拠を中身で書く 1 文を足す。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:7-37（節「記録の形」を含む）

## 2. 親の手順と基準

- [ ] 2.1 `epic.md` に「今回の止まった理由」の定義を 1 か所書き、記録の値で分岐する文をこの語に置き換える。手順 8 の `dismiss` の条件に `止まった理由:` の行が無いことを足す。`mark resumed` の説明（手順 7 付近）、手順 2 の「記録も印も無く会話ログも読めない子」→「会話ログを読めない子」、手順 5 の「記録と印を残さずに」を直す。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:80-86（手順 2・5・7・8）、plugins/dev-workflow/skills/develop/references/epic.md:112-114（マージ待ちの子・PR トークン上限の子）
- [ ] 2.2 記録を前提にした文を最後の発言に読み替える: CI の対象の読み方、`問いではない` の条件、決める役の入力（`子の停止の記録`）。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:37-49、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:99-103、plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md:3、plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md:39
- [ ] 2.3 `mark stopped` で止まる 3 か所を直し、マージ待ちの 6 項目の例を最後の発言に書く内容へ直す。別セッション方式の子の 1 行も直す。触る範囲: plugins/dev-workflow/references/ci-watch.md:69、plugins/dev-workflow/references/ci-watch.md:71、plugins/dev-workflow/references/ci-watch.md:84-91、plugins/dev-workflow/skills/develop/SKILL.md:264

## 3. スクリプト

- [ ] 3.1 `stop-judge.sh`: 止まりの JSON の `.text` に行頭 `止まった理由: ` の行があるのに `判断: 問いではない` を出したら、形の崩れとして exit 1 にする。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh:202-206
- [ ] 3.2 `epic-dispatch.sh`: ヘッダーのコメントに `stopped` / `resumed` が子の義務でないことを書く。動作は変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:10、plugins/dev-workflow/scripts/epic-dispatch.sh:147-150、plugins/dev-workflow/scripts/epic-dispatch.sh:171

## 4. テスト

- [ ] 4.1 手順書の文言の検査を更新する（`mark stopped` / `mark resumed` が無いこと、定型の行があること。`# spec:` のコメントの要件名も新しい名前に直す）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3780-3799、plugins/dev-workflow/tests/epic-dispatch.bats:3886、plugins/dev-workflow/tests/epic-dispatch.bats:3968、plugins/dev-workflow/tests/epic-dispatch.bats:6768、plugins/dev-workflow/tests/ci-watch.bats:477、plugins/dev-workflow/tests/ci-watch.bats:488、plugins/dev-workflow/tests/develop-skill.bats:541、plugins/dev-workflow/tests/develop-skill.bats:1220、plugins/dev-workflow/tests/develop-skill.bats:1526、plugins/dev-workflow/tests/develop-skill.bats:1669-1674、plugins/dev-workflow/tests/parent-merge.bats:69、plugins/dev-workflow/tests/parent-merge.bats:114
- [ ] 4.2 `stop-judge.bats` に `問いではない` の 2 シナリオを足す（`止まった理由:` の行があると exit 1、行が無ければ今どおり）。触る範囲: plugins/dev-workflow/tests/stop-judge.bats（節は `問いではない` の検査）

## 5. 記録と受け入れの確認

- [ ] 5.1 変更の記録を書く。`plugins/dev-workflow/changes/1382.md` は 1 本目の記録として main にあるので、この PR の番号のファイルにする。触る範囲: plugins/dev-workflow/changes/<PR 番号>.md（新規）
- [ ] 5.2 受け入れを確かめる: `scripts/test.sh owner-reply-check`、`pr-review-gate-skill`、`epic-stop-from-log-scenario` が通ること（#1382 の受け入れ条件の 1 件目と 3 件目）、`epic-child-stop.md` に `mark stopped` / `mark resumed` が無いこと（2 件目）、`openspec validate epic-child-stop-drop-mark --type change --strict` が exit 0 のこと。触る範囲: なし（確認のみ）
