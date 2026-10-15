## 1. テストを先に書く

- [ ] 1.1 `plugins/dev-workflow/tests/develop-skill.bats` に検査を足す: SKILL.md に節「主に聞かずに決めること」が 1 つだけあり、主に聞く 3 つの条件（主の側にしか無い情報・主の手でしかできない操作・規則が承認を求める操作）と 4 つの型（自分側の誤りの後始末・範囲外の問題の起票・小さな実装の選択・閉じる操作）、後始末の「控えを取って戻し」「事後報告」「git の破壊的操作」「destructive-git-guard」「聖域」、起票の「triage.md」「review-issue-candidates.sh」「gh issue list」「範囲外の問題の振り分け」「条件の確認待ち」「## 条件の答え」「注意書き」、2 つの型それぞれの守備範囲の段落が書かれている。「直し方の判定」の節の定義①に「利用者に見える振る舞いが変わらず」があり、「ループの終わり」の節に `gh issue close` と「主に渡さない」がある。既存の「only two conditions ask the owner」の検査が通り続ける。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:601-628（#722 の検査の後ろに足す）
- [ ] 1.2 `plugins/casting/tests/casting-structure.bats` に検査を足す: `rules/perspective-casting.md` と `plugins/casting/skills/casting/SKILL.md` の手順 1 の両方に「戻し先が差分から一意」「git の破壊的操作と聖域への変更を戻す操作は除く」があり、「回復不能側に倒す」も残っている。触る範囲: plugins/casting/tests/casting-structure.bats:61-72（rule の 5 手順の検査の近く）
- [ ] 1.3 1.1 と 1.2 の新しい検査が落ちることを確かめる（`bats plugins/dev-workflow/tests/develop-skill.bats plugins/casting/tests/casting-structure.bats`）

## 2. develop の SKILL.md を直す

- [ ] 2.1 節「本体の役割」と節「入口 0: 記録先を決める」の間に、節「主に聞かずに決めること」を足す。中身は spec の ADDED Requirement「本体は主の側にしか無い情報が要るときだけ主に聞く」のとおり（主に聞く条件、4 つの型の決め方、各型の例として #977・flatmate #1104・flatmate #1564・#693）。後始末には聖域（CLAUDE.md・hooks・権限設定）を除くことを書く。起票は triage.md を丸ごと当てず、段 B・D・E（エピックの子なら C）の問いを借りる形で、候補探し（ファイルを指すなら `review-issue-candidates.sh --exclude <記録先の番号>`、指さないなら `gh issue list --search` を 1 回）・判断結果の記録（1 行目 `範囲外の問題の振り分け` のコメントを記録先に 1 件）・段 B の確認待ち（条件の問いだけを聞き `needs-approval` を付けず、答えは `## 条件の答え` に足す）・エピックの親の注意書きを段 C より優先することを書く。後始末と起票のそれぞれに守備範囲の段落（入力の出どころ・拾う誤り・通してよい例・主に上げるもの・防がないもの）を置く。小さな実装の選択と閉じる操作は既存の節を指すだけにする。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:49-60（「本体の役割」の節の直後に新しい節を置く。「本体の役割」の本文は変えない）
- [ ] 2.2 節「ループの終わり」に、PR を伴わない記録先 issue で受け入れ条件を満たしたら本体が結果をコメントして `gh issue close <N> --reason completed` で閉じ、閉じる操作も推奨の採否も主に渡さないこと、閉じたあと `epic-dispatch.sh mark` を呼ぶことを足し、「呼ばない」の行に「PR を伴わない記録先 issue を閉じたときを除く」を足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:185-191（「ループの終わり」）
- [ ] 2.3 節「レビューの周を主に聞かずに続ける（直し方の判定）」の定義 1 を spec の MODIFIED のとおり広げ、守備範囲の段落の「拾いたい指摘」と「主に聞かずに通す指摘」の例を直す。「主に聞くのは…2 つだけ」の文は変えない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:235-241（「直し方が決まっている」の定義）、plugins/dev-workflow/skills/develop/SKILL.md:275（守備範囲の段落）

## 3. 返信前チェックの手順 1 を直す

- [ ] 3.1 `rules/perspective-casting.md` の手順 1 の末尾に、自分側（自分と自分が起こしたサブエージェント）が入れた誤りで戻し先が差分から一意に決まるものを戻す操作は、控えを取れば回復可能として扱い承認を求めない（git の破壊的操作と聖域への変更を戻す操作は除く）の 1 文を足す。「回復不能側に倒す」の文は残す。触る範囲: rules/perspective-casting.md:7
- [ ] 3.2 正本の `plugins/casting/skills/casting/SKILL.md` の手順 1 に同じ 1 文を足す。触る範囲: plugins/casting/skills/casting/SKILL.md:60

## 4. 記録と確認

- [ ] 4.1 変更の記録を書く。型ごとに「どの規則が聞くことを選ばせたか」と「規則のどこを変えたか」を 1 項目ずつ書き、2 週間後のログの再分類はこの PR の範囲外でエピック #1038 にコメントする後続作業であることを書く。触る範囲: plugins/dev-workflow/changes/1035.md（新規）、plugins/casting/changes/1035.md（新規）
- [ ] 4.2 1.1 と 1.2 の検査、`tests/injection-budget.bats`、`tests/always-on-injection-scope.bats`、`plugins/casting/tests/` の全件、`plugins/dev-workflow/tests/develop-skill.bats` の全件が通ることを確かめる。常時注入の合計が予算 40260 バイトの内側にあることを確かめ、予算ファイルは動かさない
- [ ] 4.3 `openspec validate develop-ask-owner-only-for-owner-info --type change --strict` を通す
