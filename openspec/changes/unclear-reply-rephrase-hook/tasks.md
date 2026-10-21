## 1. テストを先に書く

- [ ] 1.1 `plugins/dev-workflow/tests/unclear-reply-rephrase.bats` を新しく作り、spec `dev-workflow-unclear-reply-rephrase` の Scenario をテストにする（hooks.json の 2 件目のエントリと 1 件目が変わらないこと・実行権限・語の一覧の全語で差し込みが出ること・語の無い発言と逆引用符のブロックや引用の行の中だけの語で出ないこと・引用の外の語で出ること・言語名つきの開き（```bash）のブロックと閉じられないブロックの中の語で出ず、閉じのあとの語で出ること・「意味わからん」で示す語が `意味わから` であること・`\uXXXX` の逃がしで当たること・差し込む文が正本のパスと「節 3」と当たった語と「新しい依頼」を含み型の中身の語を含まないこと・正本に `## 3. 判断を求めるときは` の見出しがあること・壊れた入力で出力も標準エラーも空で exit 0）。テスト名は ASCII のみ。HOME は一時ディレクトリに向ける。触る範囲: plugins/dev-workflow/tests/unclear-reply-rephrase.bats（新規）。書き方の手本: plugins/dev-workflow/tests/prompt-tripwires-refresh.bats:1-70

## 2. hook を足す

- [ ] 2.1 `plugins/dev-workflow/scripts/unclear-reply-rephrase.sh` を新しく作り、実行権限を付ける。生の標準入力に語の一覧か `\u` の逃がしが当たらなければ python3 を起動せずに exit 0、当たれば `python3 -I` で `prompt` を取り出し、逆引用符のブロックと引用の行を除いて語を探し直し、当たれば design の固定文に当たった語を入れて JSON 1 つを出す。どの経路も exit 0・標準エラーなし。冒頭のコメントに契約（なぜ別スクリプトか・語の選び方の要点・fail-soft）を書く。触る範囲: plugins/dev-workflow/scripts/unclear-reply-rephrase.sh（新規）。書き方の手本: plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh:1-50
- [ ] 2.2 `plugins/dev-workflow/hooks/hooks.json` の `UserPromptSubmit` の配列に 2 件目のエントリを足す（`matcher`・`timeout` なし、1 件目はそのまま）。触る範囲: plugins/dev-workflow/hooks/hooks.json:23-32

## 3. 文書と記録

- [ ] 3.1 `docs/public-private-split.md` の「dev-workflow の `hooks/hooks.json` の配線先 10 本はどれも公開版の部品」を 11 本に直す。触る範囲: docs/public-private-split.md:36
- [ ] 3.2 変更の記録 `plugins/dev-workflow/changes/1184.md` を書く（何を足したか・なぜ・hook は聖域なのでマージは主）。触る範囲: plugins/dev-workflow/changes/1184.md（新規）。書き方の手本: plugins/dev-workflow/changes/991.md

## 4. 確かめる

- [ ] 4.1 `bats plugins/dev-workflow/tests/unclear-reply-rephrase.bats plugins/dev-workflow/tests/prompt-tripwires-refresh.bats plugins/dev-workflow/tests/subagent-stop-guard.bats plugins/dev-workflow/tests/context-tripwire.bats tests/hook-python-isolation.bats tests/injection-budget.bats tests/public-private-split.bats tests/owner-question-style.bats` が通り、続けて全テスト（`scripts/test.sh`）が通る。予算ファイル `tests/injection-budget.txt` は動かさない。触る範囲: なし（実行だけ）
- [ ] 4.2 `openspec validate unclear-reply-rephrase-hook --type change --strict` が通る。触る範囲: なし（実行だけ）
