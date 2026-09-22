## 1. テストを先に書く（TDD）

- [x] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` の仕分け表の節（`# ===== 指摘の仕分け表（issue #354）=====` 以降）に、順 3 の節（`triage_row_section 3`）が次を含む検査を足す: `## 一覧（順 3）`・`修正前 SHA:`・`検索コマンド:`・`git grep -n`・`<rev>`・`| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |`・`| 軸の値 | 扱い |`・`直した`・`該当しない: <理由>`・`git cat-file -e`（実在確認。解決できないときだけ出し直し）、軸のときも `修正前 SHA:` を書き `検索コマンド:` に軸とその全域を書くこと、順 6 の「全部列挙してから直す」の一覧も `## 一覧（順 3）` を使うこと、2 段の照合（修正前 SHA で表の全行、HEAD で「該当しない」の行）、対応を「ファイル」と「ヒットした行の本文」の組で取り行番号で取らないこと
- [x] 1.2 同 bats に、手順 2-1 の混在の段落が順 5 と順 6 の混在を扱うこと（保留を先にする・主の回答後に未処理の順 6 を `needs-decider` で返す・両方済んでから 1 回の `agent-review:failed`・裁定を使い切った PR では 1 回の保留にまとめる）の検査と、手順 6 の保留表の「切り出しの確認」行に「未処理の順 6」と `needs-decider` があること、順 6 の節に「裁定なし（入力不足）」の扱い（`決める役の裁定:` を残さない・順 5 の経路）と、主が未回答の順 5 があれば「全部列挙してから直す」でも failed に付け替えない防御条件の検査を足す
- [x] 1.3 `plugins/dev-workflow/tests/develop-roles.bats` に、develop の SKILL.md (4) の `needs-decider` の行が `記録先の本文`・`関連コメント`・`W の直近の return` を含み、依頼文で返答の 1 行目を `裁定: 可`／`裁定: 否`／`不足: <足りないもの>` に指定しその 1 行目で分岐すること、1 行目が `不足:` なら裁定として扱わず 1 回だけ依頼し直し、2 回目も不足なら `裁定なし（入力不足）` を G に渡すと書かれていることの検査を足す（既存の #354 の検査の token 一覧は残す）
- [x] 1.4 同 bats に、gate-runner.md の `### 保留のとき` が未処理の順 6 を仕分け欄に載せること、`## 再開` の「保留の解除」と「決める役の裁定受領」が混在の処理順（pr-review-gate 手順 2-1 の混在の段落）を参照すること、「W の修正後の再レビュー」の順 3 の照合が修正前 SHA と HEAD の 2 段であること、「決める役の裁定受領」に「裁定なし（入力不足）」の扱いがあること、「レビュアーの要約受領」の分岐が順 5 と順 2〜4、または順 5 と順 6 の混在で保留だけを先に返し、保留と `needs-decider` を同じ return で指示しないことの検査を足す。worker.md の順 3 の段落が `修正前 SHA` を含み、列の並び `| ファイル | 行（修正前 SHA） |` を再掲していないことの検査も足す
- [x] 1.5 追加した検査が現行ファイルで落ちることを確認する（`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats`）

## 2. pr-review-gate の SKILL.md を書き換える

- [ ] 2.1 手順 2-1 の順 3 の節を、修正前 SHA・`<rev>` を含む `git grep` 形の検索コマンド・一覧表の書式（見出し行 3 行と 2 種の列、扱いの 2 値）・`git cat-file -e` の実在確認・2 段の照合・場合分けの軸は 1 段目だけ・差し戻し 1 回（表の出し直しを含む）に書き換える
- [ ] 2.2 手順 2-1 の混在の段落に、順 5 と順 6 の混在の処理順（3 段）と、裁定を使い切った PR では 1 回の保留にまとめること、両方済むまで W が着手しないことを足す
- [ ] 2.3 順 6 の節に、「裁定なし（入力不足）」を受け取ったときの扱いと、未回答の順 5 があれば「全部列挙してから直す」でも failed に付け替えないことを足す
- [ ] 2.4 手順 6 の保留表の「切り出しの確認」行（切り出す／この PR で直す）に、未処理の順 6 が残っていれば `agent-review:failed` を付けずに `needs-decider` で return する条件を足す

## 3. G・W・本体の指示書を揃える

- [ ] 3.1 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の `### 保留のとき` の切り出しの確認に、未処理の順 6 を仕分け欄に「順 6・未裁定」として載せることを足す。`### needs-decider のとき` に、主の回答後に未処理の順 6 を返す場合もここに当たることを足す
- [ ] 3.2 同ファイル `## 再開` の「W の修正後の再レビュー」の順 3 の照合を、修正前 SHA と HEAD の 2 段（書式と照合の正本は pr-review-gate 手順 2-1 の順 3）に書き換える。「レビュアーの要約受領」（88 行目付近）の分岐の「順 5 と順 2〜4 が混ざれば保留を先にする」を「順 5 と順 2〜4、または順 5 と順 6 が混ざれば保留だけを先に返す（処理順は pr-review-gate 手順 2-1 の混在の段落）」に書き換える。「保留の解除」と「決める役の裁定受領」に、混在の処理順への参照（未処理の順 6 か未回答の順 5 が残っていれば failed に進まない）と「裁定なし（入力不足）」の扱いを足す
- [ ] 3.3 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の「G から一覧を求められた指摘」の段落に、修正前 SHA（修正に着手する直前の HEAD）を表に記録することを足す。列は再掲せず、書式の正本が SKILL.md の順 3 であることを残す
- [ ] 3.4 `plugins/dev-workflow/skills/develop/SKILL.md` (4) の `needs-decider` の行の入力に、記録先の本文・判断に必要な関連コメント・W の直近の return を足し、決める役が不足を返したときの扱い（依頼文で返答の 1 行目を `裁定: 可`／`裁定: 否`／`不足: <足りないもの>` に指定し、その 1 行目で分岐する。`不足:` は裁定として扱わない・補って 1 回だけ再依頼・2 回目も不足なら `裁定なし（入力不足）` を G に渡す）を足す。`plugins/dev-workflow/agents/decider.md` は変えない

## 4. 検証と版

- [ ] 4.1 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats` が exit 0
- [ ] 4.2 `origin/main` の `plugins/dev-workflow/.claude-plugin/plugin.json` の version と open PR の version 変更を確認してから、`plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow の version を 1 つ上げ、`plugins/dev-workflow/CHANGELOG.md` に項目を足す
- [ ] 4.3 `bash scripts/test.sh` が exit 0（`tests/injection-budget.bats` を含む）
- [ ] 4.4 `openspec validate pr-review-gate-triage-followups --strict` と `openspec validate --specs --strict` が exit 0、`git diff origin/main -- plugins/dev-workflow/agents/decider.md` が空

## 5. PR とゲート（(3b) 以降）

- [ ] 5.1 PR 本文に `Closes #357`・`Closes #358`・`Closes #359` を併記する
