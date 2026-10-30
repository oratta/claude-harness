## 1. triage.md

- [ ] 1.1 候補探しのコマンド形に `[--exclude <エピック番号>]` を足し、見出し「1 回」と本文「1 回だけ走らせる」に、打ち切りの再実行が例外であることを書く。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:94
- [ ] 1.2 再実行の項に、1 回目と同じ `--repo` と `--exclude` のまま、パスを絞って `--epic <エピック番号> --children-only` を付けると書く。再実行が失敗したら、打ち切られたパスの指摘を 1 回目に出た候補だけで振り分ける（相乗りも許す）と直す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:99

## 2. spec

- [ ] 2.1 triage.md と同じ commit で、main の spec の要件の本文と Scenario を delta のとおり直す（`--children-only` の箇条に再実行の例外、再実行の引数保持、失敗時の扱い、要件の本文の末尾に足した「守備範囲」の段落）。触る範囲: openspec/specs/dev-workflow-pr-review-gate/spec.md:2039-2084

## 3. テスト

- [ ] 3.1 bats の検査に、コマンド形の `--exclude <エピック番号>` 、見出しの例外、失敗時に 1 回目の候補で振り分ける旨の語を足す。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:785-798

## 4. 記録

- [ ] 4.1 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1517.md（新規）
