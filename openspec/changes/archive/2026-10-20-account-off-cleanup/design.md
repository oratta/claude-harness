## 判断

- 3 件（#1005・#987・#988）は親エピック genetta-inc/flatmate#1656 の指示で 1 本の PR にする。change も 1 つにし、2 つの capability の delta を同居させる。
- stderr 文面は、既存テスト（`account b is off`、`enabled`、レジストリのパスを含む 1 行）を変えずに通るよう、それらを残したまま `accounts.sh on <id>` を足す。例: `account b is off (enabled is false in <登録簿のパス>): run accounts.sh on b`。`accounts.sh` は `select-account.sh` と同じディレクトリにあるので、案内は絶対パスにせずコマンド名で書く。
- レジストリを読む箇所に数えるのは `accounts.sh list` だけ。`on|off` は書き込み側で、入力の列挙に出力として足す。
