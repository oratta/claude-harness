## 1. テストを先に直す（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/develop-skill.bats` の「entry-0: decision, review result and declaration live in record-target comments」を「仕様化判断・仕様レビュー結果は記録先、仕様宣言は PR コメント」を検証する形に書き換える（仕様宣言を含む行に `PR コメント` があること、`記録先のコメントに置く` を含む行に `仕様宣言` が無いこと）
- [ ] 1.2 `scripts/test.sh develop-skill` を実行し、書き換えたテストが現状の SKILL.md で落ちる（Red）ことを確認する

## 2. SKILL.md を直す（Green）

- [ ] 2.1 `plugins/dev-workflow/skills/develop/SKILL.md`「入口 0」の冒頭文（記録先に置くものの列挙）から仕様宣言を外す
- [ ] 2.2 同節末尾の箇条書きを「仕様化判断・仕様レビュー結果は記録先のコメントに置く」と「仕様宣言は記録先ではなく常に PR コメントに置く（理由と書式の正本＝pr-review-gate 手順 3-b）」の 2 行に分ける
- [ ] 2.3 同ファイル「1 ループ」の (3) の「仕様宣言を書く」を「仕様宣言を PR コメントに書く」に揃える
- [ ] 2.4 `scripts/test.sh develop-skill` が pass（exit 0）することを確認する

## 3. spec とバージョン

- [ ] 3.1 `openspec/specs/dev-workflow-develop/spec.md` の Requirement「入口 0 は記録先を決める」を delta spec（`specs/dev-workflow-develop/spec.md` の MODIFIED）の内容に同期する（`/opsx:archive` の sync で行う。手で先に直す場合は delta と一字一句一致させる）
- [ ] 3.2 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow エントリのバージョンを `2.0.2` に上げる
- [ ] 3.3 develop 配下の references（worker.md / spec-reviewer.md / gate-runner.md）に同じ食い違い（仕様宣言を記録先に置くと読める文）が無いことを grep で確認する

## 4. 検証

- [ ] 4.1 `scripts/test.sh` 全件と `scripts/lint.sh` を実行し、exit code 0 を確認する
- [ ] 4.2 `/opsx:verify develop-spec-declaration-target` で実装が artifact と一致することを確認する
- [ ] 4.3 `/opsx:archive develop-spec-declaration-target` で change をアーカイブし、main spec が更新されたことを `git diff` で確認する
