## MODIFIED Requirements

### Requirement: 子は許可を書くスクリプトを呼べない

子の呼び出しで、`tool_input.command` の文字列のどこかに `git-guard-permit` が含まれるもの（大文字小文字は区別する）に、hook は `deny` を返さなければならない（MUST）。ただし、コマンドを要件「コマンド文字列をシェルと同じ単位で読む」と同じ読み方で読み、`$(...)` の中・バッククォートの中・ヒアドキュメントの引用されていない本文の中の `$(...)` を含むすべての単純コマンドの先頭の語が、読むか表示するだけのコマンドの一覧（`grep`・`egrep`・`fgrep`・`cat`・`head`・`tail`・`wc`・`ls`・`echo` の 9 つ。語がこの文字列ちょうどのときだけ当たる）のどれかであるときは、名前はそれらの引数・ヒアドキュメントの本文・here-string・リダイレクトの行き先・コメントとしてだけ出ていて実行される位置に無いので、この要件で止めてはならない（MUST NOT）。先頭の語にパスを付けた形（`/usr/bin/grep`）・前置き（`command`・`env`・`sudo` など）・変数の代入を前に置いた形・`{` や予約語で始まる形は一覧に当たらない（MUST。止める側）。引用符が閉じていない・判定の仕事量の上限を超えたなど、最後まで読めないコマンドは止める側として扱わなければならない（MUST）。一覧のコマンドだけでできたコマンドを止めないことのほかは、書き方（直接の呼び出し・シェル経由・`-c` のコマンド文字列の中・`BASH_ENV` / `ENV` の設定・パイプで渡す先・`xargs`・`find -exec`・インタプリタ）を読み分けない。拒否理由・回数・拒否の記録は、破壊的 git 操作の拒否と同じに扱う（当たった種類は許可を書くスクリプトの子からの呼び出し）。ただし同じコマンドに要件「子は Bash のコマンドで許可の置き場所を名指しできない」も当たるときは、拒否の記録を書かない（その要件に従う。回数は数える）。この呼び出しには許可を使ってはならない（MUST NOT）。主の呼び出しは止めてはならない（MUST NOT）。

守備範囲: 受け取る入力は、Claude Code が PreToolUse で渡す payload の `tool_input.command`（子が書く値）と `agent_id` である。拾いたい誤りは、拒否された子が親に返らずに、コマンド文字列にスクリプトのパスを書いて自分で許可を書くことである。止めない一覧は、引数からほかのプログラムを起動する手段を持たないコマンドに限る（`sed`・`awk`・`rg`・`find`・`xargs`・`git`・`less`・`printf` は、命令やオプションや設定でほかのプログラムを起動するか変数を設定できるので入れない）。一覧に無いコマンドを 1 つでも含めば止めるので、名前をファイルに書いて同じコマンドの中で実行する形（`cat > x.sh <<EOF` のあとの `bash x.sh`）や、名前を出力してシェルに渡す形（`echo <パス> | bash`）は止まる。次の入力は通すことを許す: 一覧のコマンドで名前を含む中身をファイルに書き（スクリプトの上書き・シェルの起動ファイルへの追記を含む）、別の呼び出しでそのファイルを名前を書かずに実行するもの（同じことは、今も名前を引用符で割る・変数で組み立てる形で通る）／変数を組み合わせて名前を作る形・引用符で割った名前・別名・グロブ・シンボリックリンクやコピーを経て呼ぶ形・別のファイルの中から呼ぶ形など、コマンド文字列に名前が出ない書き方。名前の出ない書き方で呼ばれたスクリプトを、ほかの層は止めない（Write / Edit の hook と要件「子は Bash のコマンドで許可の置き場所を名指しできない」は、スクリプト自身が組み立てる置き場所のパスを見ない）。スクリプトを経ずに許可の置き場所へ直接書く形は、この要件では見ない（分かりやすい 2 つの書き方は要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」と要件「子は Bash のコマンドで許可の置き場所を名指しできない」が止め、残りは要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲で通ることを許す）。通っても、許可が効くのは使う時点の一時領域の判定（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）を満たす scratchpad の中だけで、許可を書いたことは `permit-log.jsonl` に残る。次の入力は止めることを許す（止めすぎる向き）: 一覧に無いコマンドで名前を文字列として扱うもの（`sed -n`・`rg`・`git log`・`git diff`・`cd` のあとの `grep`・`for` の中の `grep`・テストの実行を後ろにつないだもの）。子はコマンドを打つ前の書き方の選択として、Read / Edit / Write ツールで読み書きするか、一覧のコマンドだけで書く形を使える。拒否されたあとは、要件「拒否理由は承認の取り方を案内する」の理由文どおり打ち直さず親に返す（一覧のコマンドで書き直して打ち直すことは、この要件が許す手順ではない）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 子がスクリプトを呼ぶと拒否する

- **WHEN** `agent_id` が `a1` の payload に `/x/scripts/git-guard-permit.sh /y/denied/k.json ok` と `bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok` をそれぞれ渡す
- **THEN** どちらも `permissionDecision` が `deny` になる

#### Scenario: 書き方を問わず名前があれば拒否する

- **WHEN** `agent_id` が `a1` の payload に `bash -o errexit /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash --rcfile /x/scripts/git-guard-permit.sh -i`・`zsh -O /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash -c '/x/scripts/git-guard-permit.sh /y/denied/k.json ok'`・`BASH_ENV=/x/scripts/git-guard-permit.sh bash -c true`・`BASH_ENV[0]=/x/scripts/git-guard-permit.sh bash /x/y.sh`・`BASH_ENV+=/x/scripts/git-guard-permit.sh bash /x/y.sh`・`declare -x BASH_ENV=/x/scripts/git-guard-permit.sh; bash /x/y.sh`・`typeset -x ENV=/x/scripts/git-guard-permit.sh; sh -i`・`printf -v BASH_ENV %s /x/scripts/git-guard-permit.sh; export BASH_ENV; bash /x/y.sh`・`read BASH_ENV <<< /x/scripts/git-guard-permit.sh; export BASH_ENV; bash /x/y.sh` をそれぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 一覧のコマンドに一覧に無いコマンドが混じれば拒否する

- **WHEN** `agent_id` が `a1` の payload に `echo /x/scripts/git-guard-permit.sh /y/denied/k.json ok | bash`・`ls /x/scripts/git-guard-permit.sh | xargs bash`・`cat /x/scripts/git-guard-permit.sh; bash /x/y.sh`・`grep x "$(bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok)"`・`` echo `/x/scripts/git-guard-permit.sh /y/denied/k.json ok` ``・1 行目が `cat <<EOF`、2 行目が `$(/x/scripts/git-guard-permit.sh /y/denied/k.json ok)`、3 行目が `EOF` のコマンド・1 行目が `cat > /x/y.sh <<'EOF'`、2 行目が `/x/scripts/git-guard-permit.sh /y/denied/k.json ok`、3 行目が `EOF`、4 行目が `bash /x/y.sh` のコマンド・`/usr/bin/grep x /x/scripts/git-guard-permit.sh`・`command cat /x/scripts/git-guard-permit.sh`・`PATH=/x/bin grep x /x/scripts/git-guard-permit.sh`・`grep 'x /x/scripts/git-guard-permit.sh`（引用符が閉じていない）をそれぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 読むか表示するだけのコマンドの中の名前は止めない

- **WHEN** 空の `TMPDIR` を T として、`agent_id` が `a1` の payload に `grep -rn "git-guard-permit" /x/dir`・`grep -rln "git-guard-permit" --include=*.bats .`・`cat /x/scripts/git-guard-permit.sh`・`grep -n x /x/scripts/git-guard-permit.sh | head -5`・`ls /x/scripts | grep git-guard-permit`・`grep x /x/a <<< git-guard-permit`・1 行目が `cat >> /x/spec.md <<'EOF'`、2 行目が `` `git-guard-permit.sh` を呼ぶ ``、3 行目が `EOF` のコマンドを、それぞれ 2 回ずつ渡す
- **THEN** どれも exit 0 で何も出力せず、T の下に何も作られない

#### Scenario: 主の呼び出しは止めない

- **WHEN** `agent_id` の無い payload に `/x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`BASH_ENV=/x/scripts/git-guard-permit.sh bash -c true`・`cat /x/scripts/git-guard-permit.sh` をそれぞれ渡す
- **THEN** どれも何も出力しない
