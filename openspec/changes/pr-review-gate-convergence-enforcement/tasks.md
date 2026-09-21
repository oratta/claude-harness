## 1. テストを先に書く（TDD）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` の収束ルール検査に、新手順の文言（2 周目の結果を受け取った直後に G が違反文を引用する・深刻度ラベルは参考・引用できない指摘は follow-up issue・引用できる指摘が残れば `needs-approval` で停止し 3 周目を自動で開けない・無人運用でも止まる・方式の書き換え後は全体レビューで周回は数え続ける・決める役はキャップ判定に関与しない）の検査を足す
- [ ] 1.2 同 bats に「新規の高深刻度 blocking なら 3 周目に入ってよい」の許可条件が残っていないことの検査を足し、既存の固定文言（「2周」「高深刻度」「差分」「follow-up issue」「マージ後に issue で直せるものは blocking にしない」）は新しい文脈で残す
- [ ] 1.3 `plugins/dev-workflow/tests/develop-roles.bats` に、gate-runner.md の 2 周目 return の仕分け（引用 / follow-up issue URL）・引用できる指摘が残ったら保留で返し 3 周目を提案しない・`周回:` 欄が 3 周目以降と全体レビューを表せることの検査と、gate-runner.md に「新規の高深刻度 blocking のみ」の 3 周目許可条件が残っていないことの検査を足す
- [ ] 1.4 追加した検査が現行ファイルで落ちることを確認する

## 2. SKILL.md の収束ルールを書き換える

- [ ] 2.1 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の「収束ルール（レビュー周回のキャップ）」節を、2 周目終了時の仕分け手順（誰が・いつ・引用元の範囲・PR コメントへの記録）、引用できない指摘の follow-up issue 化、引用できる指摘が残ったときの `needs-approval` 停止と主への 1 択、方式の書き換え後の全体レビューと周回の数え方、決める役の不関与に書き換える
- [ ] 2.2 手順 1 の「再レビューの範囲は手順2の収束ルールに従い差分限定」の記述を、全体レビューの例外を含む形に揃える
- [ ] 2.3 `plugins/dev-workflow` 配下（tests と CHANGELOG を除く）で収束ルールを参照する箇所（SKILL.md の「収束ルール（2周キャップ）との関係」など）の字面が新手順と矛盾しないことを grep で確認し、矛盾があれば直す（手順 2-2 の原因分類とモデル昇格の中身は変えない）。`skills/develop/references/roles/spec-reviewer.md` 82 行目の括弧書きは「pr-review-gate 側は 2 周目終了時に引用で仕分けて主に上げる」に直す（`develop-roles.bats` 107〜109 行目が見る「2 周で確定し 3 周目の例外を設けない」の文は変えない）
- [ ] 2.4 SKILL.md 手順 6 の復帰表に保留種別「2 周目キャップ」の行を足す（「続ける」→ 回答リンクを PR コメントに記録し `needs-approval` を外して `agent-review:failed` に付け替え周回 3 以降へ／「範囲外として閉じる」→ 引用できた指摘も follow-up issue に切って URL を記録し `needs-approval` を外して手順 3 以降へ）

## 3. gate-runner.md を揃える

- [ ] 3.1 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の return 書式の `周回:` 欄を 3 周目以降（主の続行指示あり）と全体レビュー（2 つの行数）を表せる形にする
- [ ] 3.2 failed 節に 2 周目の仕分け結果（引用 / follow-up issue URL）を含めることを足し、保留節に「2 周目終了時に引用できる指摘が残った」場合の return（引用と指摘・主への 1 択・3 周目を提案しない）を足す
- [ ] 3.3 gate-runner.md の再開節を揃える: 「W の修正後の再レビュー」（現行 82 行目の「3 周目に入れるのは新規の高深刻度 blocking のみ」）を全体レビューの例外と主の続行指示に置き換え、「保留の解除」（現行 84 行目）に 2 周目キャップへの主の回答を含める

## 4. 検証と付随作業

- [ ] 4.1 `plugins/dev-workflow/tests/model-escalation-policy.bats` を含む関連 bats を実行し、文言変更の巻き込みが無いことを確認する（落ちたら追随）
- [ ] 4.2 `scripts/test.sh` で全件を実行して通す（`tests/injection-budget.bats` を含む）
- [ ] 4.3 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow の version を上げ、`CHANGELOG.md` に記載する
- [ ] 4.4 `openspec validate pr-review-gate-convergence-enforcement --strict` を通す
