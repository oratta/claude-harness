## ADDED Requirements

### Requirement: tmux の部品は最初の入力の確定に失敗したとき、画面と worktree が残っていることを出力に書く
`epic-launch-tmux.sh` の `send_and_confirm` は、最初の入力の Enter が効かないとき、入力を再送せず Enter だけを再試行しなければならない（MUST。二重入力にしない）。再試行でも会話ログに届かず `failed send` を返すとき、stderr の案内に、ペイン（画面）とワークツリーが残っていて閉じていないことを書かなければならない（MUST）。この案内は、先に確かめるコマンドとやり直すコマンドの順（要件「`start`・`deliver` が失敗したとき…」）を変えない。

#### Scenario: Enter だけが重なり、文は 1 回だけ打たれる
- **WHEN** 最初の入力が入力欄に残ったまま確定しない
- **THEN** 文を打つ `send-keys -l` は 1 回で、Enter の `C-m` は再試行の分だけ重なる

#### Scenario: 確定しなかったときの案内
- **WHEN** 再試行でも会話ログに現れず `failed send` で終わる
- **THEN** stdout は `failed send <ペイン ID>` で、stderr にペインと worktree が残っていることが書かれ、`capture-pane` の確認が `resend:` より先に出る
