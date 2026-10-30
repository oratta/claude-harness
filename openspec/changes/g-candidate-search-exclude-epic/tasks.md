## 1. triage.md

- [ ] 1.1 候補探しの段落の `--exclude` の項に、エピックに属する PR ではエピックの番号を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:94-100
- [ ] 1.2 出力の読み方の項のあとに、打ち切りが出たパスがありエピックに属する PR のときの `--epic <番号> --children-only` の再実行を足し、見出しと段 B 後の表の行の「1 回」に例外があることを書く。再実行が 0 以外で終わったら走らせ直さず、仕分けの PR コメントに失敗と終了コードを書き、打ち切られたパスの指摘は相乗りせず、打ち切られていないパスは 1 回目の結果を使うこと、再実行でも打ち切られたら出た候補だけで振り分けること、重なる番号は 1 件と数えることも書く。既存の失敗の段落は 1 回目の実行についての文だと分かるように書く。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:71、94-100

## 2. spec

- [ ] 2.1 triage.md と同じ commit で、main の spec の要件の本文と Scenario を delta のとおり手で直す。触る範囲: openspec/specs/dev-workflow-pr-review-gate/spec.md:2024-2056

## 3. テスト

- [ ] 3.1 `pr-review-gate-skill.bats:752` の検査が見る「`--children-only` は付けない」「1 回だけ」の語を triage.md に残したまま、足した文を検査に足す
