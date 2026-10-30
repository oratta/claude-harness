## 1. triage.md の段 C

- [ ] 1.1 親の取得のコマンドと「親が取れなければ」の文を、delta spec と同じ語句で書き換える（404 だけを属さないと読む・それ以外は 1 回やり直し・失敗を仕分けの PR コメントに書く・段 E で捨てず issue にする・親のリポジトリが違うときの扱い）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:102（段 C の段落の 1 文目と 2 文目）

## 2. テスト

- [ ] 2.1 段 C の節の検査に新しい語句を足す（`--jq '{number,repository_url}'`・`HTTP 404`・`1 回だけやり直し`・`段 E で捨てず`・`--epic` を付けず）。既存の `issues/<記録先 issue の番号>/parent` の検査は残す。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:757-764

## 3. 変更の記録

- [ ] 3.1 変更の記録を書く。version は上げない。触る範囲: plugins/dev-workflow/changes/1011.md（新規）
