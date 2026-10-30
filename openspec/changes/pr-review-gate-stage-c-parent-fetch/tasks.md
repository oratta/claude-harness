## 1. triage.md

- [ ] 1.1 段 C の段落の 1 文目と 2 文目を、delta spec と同じ語句で書き換える（候補探しの前に取る・出力の `HTTP 404` だけを属さないと読む・それ以外は 1 回やり直し・失敗を仕分けの PR コメントに書く・失敗時の動き・親のリポジトリが違うときの扱いと `sub_issues`・権限）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:102
- [ ] 1.2 候補探しの `--epic` の箇条に、親のリポジトリが違うときと親の取得が失敗し続けたときは付けない旨を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:96
- [ ] 1.3 表の段 D・段 E の行と段 E の段落に、親の取得が失敗し続けたときの例外を 1 句足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:73-74、115（表の句は、delta の要件「止めない指摘は振り分け表に上から当てる」の表と同じ句にする。上の 1.1・1.2 以外の段の文の言い回しは直さない）

## 2. テスト

- [ ] 2.1 段 C の節の検査に新しい語句を足す（`--jq '{number,repository_url}'`・`HTTP 404`・`1 回だけやり直し`・`--epic` を付けず・全候補を `other`・`sub_issues`・`段 D の参考コメントで済ませず`）。既存の `issues/<記録先 issue の番号>/parent` の検査は残す。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:761 から（段 C の検査）
- [ ] 2.2 同じ語句を spec 側でも検査する項目を足す（change の delta があればそれ、なければ main の spec を読む。既存の 832-833 行の形）。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats（上の 2.1 の直後に新規の項目）

## 3. 変更の記録

- [ ] 3.1 変更の記録を書く。version は上げない。触る範囲: plugins/dev-workflow/changes/1011.md（新規）
