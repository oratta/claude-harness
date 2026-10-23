## 1. 基準の文面

- [ ] 1.1 `parent-pass-criteria.md` の「エピックの目的・原則から推奨が決まるとき」の段落のうしろに、表でない文章の段落「ランナーの状態の確認を含む推奨の読み方」を足す（`gh api` で見られる確認は実機操作に当たらない／ランナーの機械での操作が要る確認は実機操作に当たる／判断できなければ当たる側／`gh api` だけで済む確認はそのまま通し返事に書く／機械での確認が要る推奨は独立した再実行だけを切り出して通し、結果に依るときは主に上げる）。節の対象の止まりには当てないと明記する。条件表は 9 条件のまま。「Mac が空いてからの CI の再実行」という語順は書かない（既存の bats が無いことを確かめている） 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:29-31（「エピックの目的・原則から推奨が決まるとき」と「迷ったとき」の間）
- [ ] 1.2 同じファイルの節「CI の見張りのやり直しの上限で止まった子」に、(a) 節が対象全体で通る例の「CI の再実行」と 1.1 の段落のどちらよりも先に効くこと、(b) 原因は断定できないと書いた再実行だけの推奨は主に上げること、(c) 確認が先の推奨は確認が `gh api` だけで済む場合も主に上げること、を足す。「主に上げる場合」の `job-timeout` の括弧「ランナーの状態確認を求めるので実機操作に当たる」を「ランナーの側に原因があり、PR の差分でもやり直しでも直らないため」に書き換える。通る例の「CI の再実行」の行は、行末に節が先に効くと一言足す（先頭の括弧の中は変えない） 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:35-49（節。43 行が「主に上げる場合」）、62（通る例の「CI の再実行」）
- [ ] 1.3 親の守備範囲（入力・拾いたい誤り・通ってよい入力・塞ぎ切らない）は節の「守備範囲」の段落に 1 文足す。新しい節は作らない 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:49（節の守備範囲の段落）

## 2. テスト

- [ ] 2.1 節の優先順位・原因は断定できない再実行だけの推奨を主に上げること・確認が先は `gh api` だけでも主に上げること・`job-timeout` の新しい理由があり、古い括弧の理由が無いこと、を確かめる。節を awk で切り出している既存テストに足す 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（テスト「criteria: the CI watch rerun cap section decides pass or escalate to the owner」）
- [ ] 2.2 1.1 の段落の記述（確認の種類の分け方・`gh api` の確認をそのまま通すこと・独立した再実行だけを切り出す条件・結果に依るときは主に上げること）、通る例の行末の添え書き、表の行数が 10 のままであること、「Mac が空いてからの CI の再実行」の文字列が無いままであること、を確かめる 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3611-3650（テスト「criteria: the file states the nine conditions, the examples and the output form」の近く）
