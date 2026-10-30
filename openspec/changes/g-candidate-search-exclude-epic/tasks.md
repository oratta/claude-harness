## 1. triage.md

- [ ] 1.1 候補探しの段落の `--exclude` の項に、エピックに属する PR ではエピックの番号を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:94-100
- [ ] 1.2 出力の読み方の項のあとに、打ち切りが出たパスがありエピックに属する PR のときの `--epic <番号> --children-only` の再実行を足し、見出しと段 B 後の表の行の「1 回」に例外があることを書く。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:71、94-100

## 2. spec

- [ ] 2.1 main の spec の要件の本文と Scenario を delta のとおり直す（archive で反映される）。触る範囲: openspec/specs/dev-workflow-pr-review-gate/spec.md:2024-2056

## 3. テスト

- [ ] 3.1 triage.md の文言を見る既存の bats を確かめ、足した文を検査に足す
