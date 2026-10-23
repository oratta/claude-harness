## 1. 基準の文面

- [ ] 1.1 `parent-pass-criteria.md` の「エピックの目的・原則から推奨が決まるとき」の段落のうしろに、表でない文章の段落「ランナーの状態の確認を含む推奨の読み方」を足す（`gh api` で見られる確認は実機操作でない／ランナーの機械での操作は実機操作／再実行だけを切り出せる条件と返事）。条件表は 9 条件のまま 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:29-31（「エピックの目的・原則から推奨が決まるとき」と「迷ったとき」の間）
- [ ] 1.2 同じファイルの節「CI の見張りのやり直しの上限で止まった子」に、この節が対象の止まり全体で通る例の「CI の再実行」より先に効くこと、原因は断定できないと書いた再実行だけの推奨は主に上げることを足す。通る例の「CI の再実行」の行に、上限で止まった子は節が先に効くと添える 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:35-49（節）、62（通る例の「CI の再実行」）

## 2. テスト

- [ ] 2.1 上の記述があること（確認の種類の分け方・再実行だけを切り出す条件・節が通る例より先に効くこと・原因は断定できない再実行だけの推奨は主に上げること）と、表の行数が 10 のままであることを確かめる 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3611-3650（テスト「criteria: the file states the nine conditions, the examples and the output form」の近く）
