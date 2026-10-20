## 1. hook の拒否理由と子の定義

- [ ] 1.1 `git-destructive-guard.sh` の子への理由文の「何を・なぜ実行したかったかを報告に書いて親に返す」を、4 項目（コマンドの全文・対象のパス・自分で作ったか（作ったなら作ったコマンド）・なぜ要るか）を書く文に直す。許可を書くスクリプトの名前・`!`・確認画面は書かない（既存の禁止のまま） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:917-928（`if is_child:` の `body`）
- [ ] 1.2 `agents/reviewer.md`・`worker.md`・`gate-runner.md` の本文 9 行目の「作り直す」の文のあとに、拒否されたら作業を止めて 4 項目を報告に書いて返す文を足す（「コマンドの全文」「対象のパス」「自分で作った」を含める） 触る範囲: plugins/dev-workflow/agents/reviewer.md:9、plugins/dev-workflow/agents/worker.md:9、plugins/dev-workflow/agents/gate-runner.md:9
- [ ] 1.3 `git-destructive-guard.bats` の「子への理由」のテストと、3 つの定義を読むテスト（945 行付近）に、4 項目の文字列の検査を足す 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:725-745、plugins/dev-workflow/tests/git-destructive-guard.bats:935-950

## 2. develop の本体の手順

- [ ] 2.1 SKILL.md の「1 ループ」の `returned no output` を含む段落（1 行）を直す。報告を求める項目を 5 項目（4 項目＋拒否の記録のパス）にし、「打ち切られたとあれば同じ指示で起こし直さない」を、許可を書けなかったときは主に上げる形にして、許可を書いて同じ W を再開する分岐を同じ段落に足す。許可を書く 4 条件・`git-guard-permit.sh` の実行・対象に git を実行しない・再開の文面（15 分・同じ cwd・同じコマンド 1 回）・コマンドの全文・cwd・操作対象を分けて照合すること（`git -C` の例を含む。cwd と対象を同一視しない）・再開できないとき（上限超過）は新しい W に転用せずオーナーに上げること・オーナーに上げる条件（スクリプトの失敗・4 条件を満たさない・再開後の再拒否・再開できない・再開しない役）・再開しない役・承認後はオーナーが自分で実行、を書く。#1117 の既存の語（`SendMessage で 1 回だけ報告を求める`・`git -C <path> status --porcelain`・`同じ指示で起こし直さない`・`1 回求めても報告が空`・`再開しない役`・`範囲外`）は残し、段落は 1 行のままにする 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:202（「1 ループ」の節。段落の見出しは `W が (Subagent completed but returned no output.) だけを返したとき`）
- [ ] 2.2 `develop-skill.bats` に、許可を書く条件・再開・オーナーに上げる条件・4 項目の検査を足す（既存の #1117 のテストは変えない） 触る範囲: plugins/dev-workflow/tests/develop-skill.bats:756-775（既存のテストの直後に足す）

## 3. 実機確認と記録

- [ ] 3.1 実機: W に scratchpad の検証用 repo（本体の指示で W が作ったもの）を `git checkout --` で戻させ、拒否 → 本体が許可を書く → SendMessage で再開 → 実行されるまでを、人が確認画面を押さずに通ることを確かめる。2 回目の拒否で打ち切られて空で返る経路も 1 回確かめ、結果を PR 本文に書く
- [ ] 3.2 変更の記録 `plugins/dev-workflow/changes/1135.md` を書く 触る範囲: plugins/dev-workflow/changes/1135.md（新規）
