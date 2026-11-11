## MODIFIED Requirements

### Requirement: rm の一時領域の判定

`plugins/dev-workflow/scripts/git-guard-scratchpad.py` は、`session_id`・`cwd`・`command` を入力とする rm 用の判定を置かなければならない（MUST。git 用の判定と同じファイルに置き、hook と `git-guard-permit.sh` がそれを読んで使う）。判定は次をすべて満たすときに満たすとし、満たさないときは理由を返す。判定のために `rm` も `git` も実行してはならない（MUST NOT）。

- `session_id` が英数字と `-` だけの空でない文字列で、`cwd` が実在する絶対パスのディレクトリである
- コマンドが英数字・空白・タブ・改行（LF だけ）・`/ . _ , : @ + % -`（`=` は含めない。zsh では語の先頭の `=名前` がその実体パスに展開され、判定と実行の削除先がずれるため）・`;`・`&&`・`*`・`?` だけでできている（変数・置換・引用符・リダイレクト・パイプ・`~`・`[` `]` `{` `}`・コメント・行継続・CR を含まない）
- `&&`・`;`・改行で区切った単純コマンドが、0 個か 1 個の `cd` のあとに 1 個以上の `rm` が続く形である（`cd` は最初の `rm` より前にだけ置く）。`cd` は引数 1 つで、`/`・`./`・`../` で始まるか `.`・`..` そのもの、移り先は実在するディレクトリで、字句で畳んだ道筋と `realpath` が同じ所に着く（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」の `cd` の規則と同じ）
- `rm` の引数は、フラグ（`-r`・`-R`・`-f` とその組み合わせ `-rf`・`-fr`・`-Rf` など、`-` のあとが `r`・`R`・`f` だけの語）と、1 個以上の削除先だけである。それ以外の `-` で始まる語（`--`・`-i`・`-v` など）は拒む
- 各削除先は、末尾の要素以外にグロブ文字（`*`・`?`）を含まない。削除先の末尾の要素が `.` ・`..` ・空のもの（`/` で終わる、`dir/.` など）は拒む。削除先を、`cd` の移り先（なければ `cwd`）を基準に絶対パスにし、末尾の要素の 1 つ前までを `realpath` で解決して、末尾の要素をつなぐ（末尾の要素が symlink でも辿らない。`rm` は symlink 自体を消すため）。解決した削除先（グロブなら、グロブを展開する親ディレクトリ）が、`session_id` のセッションの scratchpad の中にあり、scratchpad そのものではない。グロブの場合は親ディレクトリも scratchpad そのものであってはならない（scratchpad 直下の全消しを許さない）。scratchpad の定義は spec destructive-git-hook の同名の判定と同じ（`claude-<uid>` の所有者・権限・親が一時フォルダの置き場所であること）
- `cd` がある場合、単純コマンドの区切りが `&&` だけ（コマンドに `;` も改行も無い）なら、基準を `cd` の移り先とした解決だけで、すべての削除先が上の条件を満たす（`cd` が失敗すると後ろの `rm` は走らないため）。区切りに `;` か改行が 1 つでもあれば（`cd ./a && rm x; rm y` のように `&&` と混ざる形を含む）、基準を `cd` の移り先とした解決と、基準を `cwd` とした解決（`cd` が失敗して `rm` が元の `cwd` で走る場合）の両方で、すべての削除先が上の条件を満たす。絶対パスの削除先は基準によらず同じ

守備範囲: 判定への入力の出どころは、hook では PermissionRequest の payload の `session_id`・`cwd`・`tool_input.command`、`git-guard-permit.sh` では拒否の記録の同名の項目で、どちらも呼び出し側が判定に渡す（判定は他から読まない）。拾いたい誤りは、親が「子が自分の一時領域を片づけるだけ」と判断を誤って、一時領域の外・ホーム・作業ツリーの削除を許可することである。止めすぎる向きでは、引用符・変数・`{}` の展開・パイプを使った `rm`、`rm` 以外のコマンド（`find -delete` など）、`cd` を複数含むもの、`rm` のあとに `cd` が来るもの、`cwd` が一時領域の外で `cd` と相対の削除先を `;` や改行（`&&` と混ざる形を含む）でつないだものは、一時領域の中でも許可できないが、これは許す。判定の後に glob の展開結果が変わること・削除先の中身は見ない（削除先は一時領域の中の任意のファイルやディレクトリ。中に他の場所への symlink があっても `rm -r` は辿らない）。これらの穴を見つけるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一時領域の中の削除先は満たす

- **WHEN** `cwd` が scratchpad の中で、`rm -rf ./a`・`rm -f <scratchpad>/tbl/*.tmp`・`cd ./tbl; rm -rf x/*`・`cd ./tbl && rm -f a b`・`rm -rf ./link`（scratchpad の外への symlink）を判定にかける
- **THEN** どれも満たす

#### Scenario: 一時領域の外や広すぎる削除先は満たさない

- **WHEN** `rm -rf /`・`rm -rf ~`・`rm -rf $HOME/x`・`rm -rf ../../..`（scratchpad の外に出る）・`rm -rf <scratchpad>`・`rm -rf <scratchpad>/*`・`rm -rf <scratchpad>/tbl/.`・`rm -rf <scratchpad>/tbl/`（末尾 `/`）・`rm -rf <作業ツリー>/x`・別セッションの scratchpad の中・`rm -rf <scratchpad>/a/*/b`（途中のグロブ）・`rm -rf <scratchpad>/linkdir/x`（`linkdir` が外への symlink）・`rm -- x`・`rm -i x`・`rm -rf "x"`・`rm -rf x > o`・`rm -rf x | cat`・`rm -rf x && ls`・`ls && rm -rf x`・`rm -rf x; cd ./y`・`cd ./a; cd ./b; rm -rf x` を判定にかける
- **THEN** どれも満たさず、理由を返す

#### Scenario: cd が失敗した場合の基準でも一時領域の中であること

- **WHEN** `cwd` が scratchpad の外で、`cd <scratchpad>/tbl; rm -rf x/*`（`cd` が成功すれば中、失敗すれば `cwd` 基準の `x/*` は外）を判定にかける。また `cwd` が scratchpad の中で `cd ./tbl; rm -rf x/*` を判定にかける
- **THEN** 前者は満たさず、後者は満たす

#### Scenario: 区切りが && だけなら cd が成功した場合の基準だけで見る

- **WHEN** `cwd` が scratchpad の外で、`cd <scratchpad>/tbl && rm -f x/*`・`cd <scratchpad>/tbl && rm -f x/a && rm -f x/b` を判定にかける。また同じ `cwd` で、`cd <scratchpad>/tbl; rm -f x/*`・`cd <scratchpad>/tbl` と `rm -f x/*` を改行でつないだもの・`cd <scratchpad>/tbl && rm -f x/a; rm -f x/b` を判定にかける
- **THEN** 前の 2 つは満たし、後の 3 つは満たさず理由を返す

#### Scenario: && の形は親が許可を書けて、; の形は書けない

- **WHEN** `cwd` が scratchpad の外の子（`agent_id` が `a1`）の payload に `cd <scratchpad>/tbl && rm -f x/*` を渡して deny となり、その拒否の記録のパスで許可を書くスクリプトを動かし、同じ payload をもう一度渡す。別に、同じ `cwd` の payload に `cd <scratchpad>/tbl; rm -f x/*` を渡して deny となった拒否の記録のパスで、許可を書くスクリプトを動かす
- **THEN** 前者は許可を書くスクリプトが exit 0 で終わり、もう一度渡した payload は `decision.behavior` が `allow` になる。後者は許可を書くスクリプトが 0 でない終了コードで終わり、許可は書かれない

#### Scenario: 判定は rm も git も実行しない

- **WHEN** 削除先の実在するファイルを対象に判定を 1 回かけ、続けて同じファイルを調べる
- **THEN** ファイルは残っていて、判定は `rm` を実行していない（PATH の先頭に置いた `rm` のスタブが呼ばれた記録が無い）
