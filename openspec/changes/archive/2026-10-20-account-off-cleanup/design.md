## 判断

- 3 件（#1005・#987・#988）は親エピック genetta-inc/flatmate#1656 の指示で 1 本の PR にする。change も 1 つにし、2 つの capability の delta を同居させる。
- stderr 文面は、既存テスト（`account b is off`、`enabled`、レジストリのパスを含む 1 行）を変えずに通るよう、それらを残したまま `accounts.sh on <id>` を足す。例: `account b is off (enabled is false in <登録簿のパス>): run <scripts のパス>/accounts.sh on b`。README の手順では scripts ディレクトリを PATH に入れないので、コマンド名のままでは `command not found` になる。案内は `select-account.sh` と同じディレクトリの `accounts.sh` のフルパスで書く（空白などを含むパスは `shlex.quote` で引用する）。
- レジストリを読む箇所に数えるのは `accounts.sh list` だけ。`on|off` は書き込み側で、入力の列挙に出力として足す。
