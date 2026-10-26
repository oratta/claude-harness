## 1. child-log サブコマンド

- [ ] 1.1 `epic-dispatch.sh` に `child-log` を足す（使い方の一覧・先頭コメント・ディスパッチ・`cmd_child_log`。会話ログの最後の主の発言と子の発言を python3 で読む）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-25、plugins/dev-workflow/scripts/epic-dispatch.sh:211-225、plugins/dev-workflow/scripts/epic-dispatch.sh:1356-1366（`cmd_pending_owner` の直後）、plugins/dev-workflow/scripts/epic-dispatch.sh:1636-1644
- [ ] 1.2 bats を足す（最後のやり取り・ツールの結果を数えない・unreadable で続行・読み取り専用）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:4823-4860（`pending-owner` の節の近く）

## 2. 報告の規定

- [ ] 2.1 `epic.md` の別セッション方式「親が別セッション方式でターンを終えるときに主に出す発言すべて」の段落に、表の規定（列・確かめた時刻・URL・片付いたもの・会話ログを先に読む・読めなければ確かめられなかった）を足す。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:46
- [ ] 2.2 サブエージェント方式の主への報告に同じ表の規定を当てる（本文は 2.1 を参照し複写しない）。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:115（「サブエージェント方式」の段落）

## 3. 記録

- [ ] 3.1 変更の記録を書く（版は上げない）。触る範囲: plugins/dev-workflow/changes/1377.md（新規）
- [ ] 3.2 受け入れ条件の grep を確かめる（`issue 番号・内容・ステータス・確認内容・推奨・答え方`、`会話ログ`）と、bats `plugins/dev-workflow/tests/epic-dispatch.bats` を通す
