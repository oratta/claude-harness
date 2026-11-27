## 1. 止まり検知のテストの欠け（元 #1542）

- [x] 1.1 `develop-skill.bats` の順序検査の切り出しパターン `親が自分で記録を …` を、直前行の新しい文面（`親が自分で今回の停止の記録（無ければ最後の発言）を …`）に直し、パターンを壊すと落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:1236-1242
- [x] 1.2 #1542 の残りの行（P8-F1・F4〜F9・P9-F2・F4〜F7）を、今の main で 1 行ずつ「まだ欠けているか」確かめ、欠けているものだけテストを足す。無い行（P8-F3: `EPIC_DISPATCH_STOP_BG_IDLE_SEC` は scripts・tests・skills に無い）の「済み」の証拠（コマンドかテスト名）は、PR 本文の「元の issue の確認」に書く（元の issue 番号は書かず、P の記号と行の中身で書く）。触る範囲: plugins/dev-workflow/tests/child-log-read.bats:1-400、plugins/dev-workflow/tests/epic-dispatch.bats:7591-7660、plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats:1-200
- [x] 1.3 足した各テストで、対応する行を削除・反転すると落ちることを 1 件ずつ確かめる（確かめた方法を PR に書く）

## 2. stop-judge の発言の囲み（元 #1544）

- [x] 2.1 発言を乱数の境界行（開始・終了）で囲む。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh:105-120、plugins/dev-workflow/scripts/stop-judge.sh:160-176
- [x] 2.2 基準に境界の内側の読み方を 1 行足す。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:90-96
- [x] 2.3 見出しを模した発言が境界の内側に収まるテストと、境界が呼ぶたびに変わるテストを足す。触る範囲: plugins/dev-workflow/tests/stop-judge.bats（末尾に追加）

## 3. tmux の最初の入力（元 #1824）

- [x] 3.1 原因の確認（直す前）: 実機の既定のモードで Claude Code を起動し、入力欄に文が残った状態の `tmux capture-pane -p` を取り、最下部に `? for shortcuts` が出るか・送った文の先頭（`head20`）が画面に出るか・`/develop` の補完候補が `DIALOG_PATTERN` に当たるかを調べる。結果（画面の抜粋）を #1829 にコメントする。仮説（印が消えて 4 秒目の `pane_ready` が失敗し、Enter を 1 回も重ねない）と違えば、原因に合わせて 3.2 の条件を design と spec に直してから進む。触る範囲: plugins/dev-workflow/scripts/epic-launch-tmux.sh:131-158（`send_and_confirm`）
- [x] 3.2 重ね送りの条件から入力待ちの印を外す（確認画面の印が無く、文の先頭が入力欄に残るときだけ重ねる）。触る範囲: plugins/dev-workflow/scripts/epic-launch-tmux.sh:131-158、定数 `READY_PATTERN`・`DIALOG_PATTERN`（ファイル先頭）
- [x] 3.3 `resend_hint` の案内に、ペイン（画面）とワークツリーが残っていて入力欄に文が残りうることを足す。触る範囲: plugins/dev-workflow/scripts/epic-launch-tmux.sh:281-290
- [x] 3.4 テスト: 既定のモードの画面（印なし・文が入力欄に残る）で `C-m` が重なり文は 1 回だけ打たれること、`start` は `failed send <ペイン ID>`・`deliver` は `failed send` で案内に残ることが書かれること。既存のスタブ画面（plan mode の行）は既定のモードの画面に差し替えるか両方を持つ。触る範囲: plugins/dev-workflow/tests/epic-launch-tmux.bats:224-260、469-515
- [x] 3.5 直したあとに実機で、最初の入力が手で Enter を送らずに確定することを確かめる（確認は #1829 にコメントする）

## 4. 仕上げ

- [x] 4.1 `plugins/dev-workflow/changes/1829.md` に変更の記録を書く。PR 本文は `Closes #1829` だけを issue 参照にする
