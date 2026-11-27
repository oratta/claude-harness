## 1. 止まり検知のテストの欠け（元 #1542）

- [ ] 1.1 `develop-skill.bats` の順序検査の切り出しパターン `親が自分で記録を …` を、直前行の新しい文面（`親が自分で今回の停止の記録（無ければ最後の発言）を …`）に直し、パターンを壊すと落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:1236-1242
- [ ] 1.2 #1542 の残りの行（P8-F1・F4〜F9・P9-F2・F4〜F7）を、今の main で 1 行ずつ「まだ欠けているか」確かめ、欠けているものだけテストを足す。無い行（P8-F3: `EPIC_DISPATCH_STOP_BG_IDLE_SEC` は scripts に無い）は証拠を書いて済みにする。触る範囲: plugins/dev-workflow/tests/child-log-read.bats:1-400、plugins/dev-workflow/tests/epic-dispatch.bats:7591-7660、plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats:1-200
- [ ] 1.3 足した各テストで、対応する行を削除・反転すると落ちることを 1 件ずつ確かめる（確かめた方法を PR に書く）

## 2. stop-judge の発言の囲み（元 #1544）

- [ ] 2.1 発言を乱数の境界行（開始・終了）で囲む。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh:105-120、plugins/dev-workflow/scripts/stop-judge.sh:160-176
- [ ] 2.2 基準に境界の内側の読み方を 1 行足す。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:90-96
- [ ] 2.3 見出しを模した発言が境界の内側に収まるテストと、境界が呼ぶたびに変わるテストを足す。触る範囲: plugins/dev-workflow/tests/stop-judge.bats（末尾に追加）

## 3. tmux の最初の入力（元 #1824）

- [ ] 3.1 `resend_hint` の案内に、ペイン（画面）と worktree が残っていて閉じていないことを足す。触る範囲: plugins/dev-workflow/scripts/epic-launch-tmux.sh:281-290
- [ ] 3.2 `start` と `deliver` の `failed send` のテストで案内の文を確かめ、既存の Enter だけを再試行するテスト（`start: only Enter is resent every 4 seconds…`）が文を 1 回しか打たないことを引き続き確かめる。触る範囲: plugins/dev-workflow/tests/epic-launch-tmux.bats:224-232、plugins/dev-workflow/tests/epic-launch-tmux.bats:469-515
- [ ] 3.3 起動直後の実画面（tmux）で、最初の入力が手で Enter を送らずに確定することを確かめる（確認は W の記録に残す）

## 4. 仕上げ

- [ ] 4.1 `plugins/dev-workflow/changes/1829.md` に変更の記録を書く。PR 本文は `Closes #1829` だけを issue 参照にする
