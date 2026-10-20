# rm-permission-hook Specification

## Purpose
TBD - created by archiving change rm-permission-parent-permit. Update Purpose after archive.
## Requirements
### Requirement: 子の rm の確認画面に、親の許可に従って答える

`plugins/dev-workflow/hooks/hooks.json` は `PermissionRequest`（matcher `Bash`）に `plugins/dev-workflow/scripts/rm-permission-guard.sh` を登録しなければならない（MUST）。hook は payload の `agent_id` が空でない文字列（サブエージェントの呼び出し）で、かつ `tool_input.command` が要件「rm の一時領域の判定」の入口の形（単純コマンドのどれかの先頭の語が `rm`）に当たるときだけ答えなければならない（MUST）。それ以外は何も出力せず exit 0 で終わらなければならない（MUST。主の呼び出し・`agent_id` が無い・空・文字列でない呼び出し・`rm` を含まない Bash の確認・読めない payload・`python3` が無い場合を含む。確認画面または今までの拒否に任せる）。

答え方は次のとおり。hook は `session_id`・`agent_id`・`cwd`・`tool_input.command` から、要件「子への拒否を記録し、親が 1 回だけ通せるようにする」（spec destructive-git-hook）と同じ規則で key を計算し、同じ `<base>/permits/<key>.json` を自分だけが使えるように `rename` で取って読む（`<base>` は `${TMPDIR:-/tmp}/dev-workflow-git-guard`）。許可の 4 つの値が payload と一致し、期限内で、使う時点の rm の一時領域の判定をその時点のファイルシステムで満たすときに限り、`hookSpecificOutput.decision.behavior` を `allow` にして、取った許可を消し、`permit-log.jsonl` に `event` が `use` の行を足さなければならない（MUST）。許可が無い・一致しない・期限切れ・判定を満たさない・判定のファイルを読めないときは `behavior` を `deny` にし、`message` に次を含めなければならない（MUST）: このコマンドは親の許可が無いので実行しなかったこと／何を（コマンド）・なぜ消したかったかを報告に書いて親に返すこと／同じコマンドを打ち直さないこと／拒否の記録を作れたときはそのパス（作れなかったとき、つまり判定のファイルを読めない・記録を書けないときは、パスの代わりに「拒否の記録を作れなかった」ことと、親に報告するときはコマンドの全文を書くこと）。許可があるが判定を満たさなかったときは「許可はあるが行き先を確かめられない」も含める。判定のファイルを読めたときは key を出せるので、deny のたびに拒否の記録を `<base>/denied/<key>.json` に（`kinds` を `["rm"]` として）書く。判定のファイルを読めないときは key を出せないので許可を探さず記録も書かず、記録を書けなかったときも、deny は返す（どちらも message はパスを示さない）。回数を数えての打ち切りはしない。

守備範囲: 受け取る入力は PermissionRequest の payload（`tool_name`・`tool_input.command`・`permission_mode`・`cwd`・`agent_id`・`session_id`）だけで、なぜ確認画面が出たかは入力に無いため、hook は確認の理由を見ずにコマンド文字列から自分で判定する。拾いたい誤りは、子が自分の一時領域の中のファイルを消すだけの `rm` が確認画面で止まり、親が代わりに打つと主の確認画面が出て作業が止まることである。入口の形に当たる `rm` で一時領域の外を指すものは、親の許可があっても通さない。判定へ渡す入力（`session_id`・`cwd`・`command`）は、hook では payload から、`git-guard-permit.sh` では拒否の記録（hook が payload から書いたもの）から、それぞれ渡す。次の入力は通す・止めることを許す: 子がコマンドを 1 文字でも変えたもの・別の `cwd` から打ったものは止まる／判定から実行までの間に一時領域の中が symlink に差し替えられるもの・`permits/` に直接書かれた許可のうち判定を満たすものは通る。これらの穴を見つけるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一致する許可があれば 1 回だけ allow を返す

- **WHEN** 空の `TMPDIR` で、scratchpad の形に合う `session_id`・`agent_id` が `a1`・`cwd` が scratchpad の中のディレクトリの payload に `cd ./tbl; rm -rf x/*` を渡して deny となり、その拒否の記録のパスで `git-guard-permit.sh` が exit 0 で終わったあと、同じ payload を 2 回渡す
- **THEN** 1 回目は `decision.behavior` が `allow`、2 回目は `deny` で、`permit-log.jsonl` に `permit` と `use` の行がこの順にある

#### Scenario: 許可が無ければ deny と報告の案内を返す

- **WHEN** `agent_id` が `a1` で許可の無い payload に `rm -rf <scratchpad>/tbl/*` を渡す
- **THEN** `decision.behavior` が `deny` で、`message` に「何を」「なぜ消したかった」「報告」「拒否の記録のパス」が含まれ、`denied/` にそのパスの記録が 1 つできる

#### Scenario: 主の呼び出しと rm でない確認には何も返さない

- **WHEN** `agent_id` の無い payload に `rm -rf <scratchpad>/tbl/*`、`agent_id` が `a1` の payload に `ls -la` と `git status` をそれぞれ渡す。許可が一致する状態にしても、主の payload は同じ
- **THEN** どれも何も出力せず exit 0 で終わり、許可のファイルは残っている

#### Scenario: 一致しない呼び出しには許可を使わない

- **WHEN** 許可を書いたあと、コマンドの末尾に空白を足した payload・`agent_id` が `a2` の payload・`cwd` が違う payload を渡し、そのあと元の payload を渡す
- **THEN** 前の 3 つは `deny`、最後は `allow` になる

#### Scenario: 許可のあとで行き先が外に変わったら通さない

- **WHEN** 許可を書いたあと、`rm` の対象の親ディレクトリを scratchpad の外のディレクトリを指す symlink に差し替えてから元の payload を渡す
- **THEN** `deny` で、`message` に「許可はあるが行き先を確かめられない」が含まれ、許可のファイルが残っていない

#### Scenario: 判定のファイルを読めないときは許可を探さずに deny する

- **WHEN** `git-guard-scratchpad.py` が無い場所に hook だけを置き、許可を `permits/<key>.json` に直接書いてから `agent_id` が `a1` の `rm` の payload を渡す
- **THEN** `deny` で、`denied/` は作られず、許可のファイルは残り、`message` は拒否の記録のパスを示さず「拒否の記録を作れなかった」ことを含む

#### Scenario: 記録を書けなくても deny を返す

- **WHEN** `<base>/denied` を通常のファイルで塞いだ状態で、許可の無い `agent_id` が `a1` の `rm` の payload を渡す
- **THEN** `deny` で、`message` は拒否の記録のパスを示さず「拒否の記録を作れなかった」ことを含む

### Requirement: rm の一時領域の判定

`plugins/dev-workflow/scripts/git-guard-scratchpad.py` は、`session_id`・`cwd`・`command` を入力とする rm 用の判定を置かなければならない（MUST。git 用の判定と同じファイルに置き、hook と `git-guard-permit.sh` がそれを読んで使う）。判定は次をすべて満たすときに満たすとし、満たさないときは理由を返す。判定のために `rm` も `git` も実行してはならない（MUST NOT）。

- `session_id` が英数字と `-` だけの空でない文字列で、`cwd` が実在する絶対パスのディレクトリである
- コマンドが英数字・空白・タブ・改行（LF だけ）・`/ . _ , : @ + % -`（`=` は含めない。zsh では語の先頭の `=名前` がその実体パスに展開され、判定と実行の削除先がずれるため）・`;`・`&&`・`*`・`?` だけでできている（変数・置換・引用符・リダイレクト・パイプ・`~`・`[` `]` `{` `}`・コメント・行継続・CR を含まない）
- `&&`・`;`・改行で区切った単純コマンドが、0 個か 1 個の `cd` のあとに 1 個以上の `rm` が続く形である（`cd` は最初の `rm` より前にだけ置く）。`cd` は引数 1 つで、`/`・`./`・`../` で始まるか `.`・`..` そのもの、移り先は実在するディレクトリで、字句で畳んだ道筋と `realpath` が同じ所に着く（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」の `cd` の規則と同じ）
- `rm` の引数は、フラグ（`-r`・`-R`・`-f` とその組み合わせ `-rf`・`-fr`・`-Rf` など、`-` のあとが `r`・`R`・`f` だけの語）と、1 個以上の削除先だけである。それ以外の `-` で始まる語（`--`・`-i`・`-v` など）は拒む
- 各削除先は、末尾の要素以外にグロブ文字（`*`・`?`）を含まない。削除先の末尾の要素が `.` ・`..` ・空のもの（`/` で終わる、`dir/.` など）は拒む。削除先を、`cd` の移り先（なければ `cwd`）を基準に絶対パスにし、末尾の要素の 1 つ前までを `realpath` で解決して、末尾の要素をつなぐ（末尾の要素が symlink でも辿らない。`rm` は symlink 自体を消すため）。解決した削除先（グロブなら、グロブを展開する親ディレクトリ）が、`session_id` のセッションの scratchpad の中にあり、scratchpad そのものではない。グロブの場合は親ディレクトリも scratchpad そのものであってはならない（scratchpad 直下の全消しを許さない）。scratchpad の定義は spec destructive-git-hook の同名の判定と同じ（`claude-<uid>` の所有者・権限・親が一時フォルダの置き場所であること）
- `cd` がある場合、基準を `cd` の移り先とした解決と、基準を `cwd` とした解決（`cd` が失敗して `rm` が元の `cwd` で走る場合）の両方で、すべての削除先が上の条件を満たす（区切りが `;` や改行でも `&&` でも同じに見る）。絶対パスの削除先は基準によらず同じ

守備範囲: 判定への入力の出どころは、hook では PermissionRequest の payload の `session_id`・`cwd`・`tool_input.command`、`git-guard-permit.sh` では拒否の記録の同名の項目で、どちらも呼び出し側が判定に渡す（判定は他から読まない）。拾いたい誤りは、親が「子が自分の一時領域を片づけるだけ」と判断を誤って、一時領域の外・ホーム・作業ツリーの削除を許可することである。止めすぎる向きでは、引用符・変数・`{}` の展開・パイプを使った `rm`、`rm` 以外のコマンド（`find -delete` など）、`cd` を複数含むもの、`rm` のあとに `cd` が来るものは、一時領域の中でも許可できないが、これは許す。判定の後に glob の展開結果が変わること・削除先の中身は見ない（削除先は一時領域の中の任意のファイルやディレクトリ。中に他の場所への symlink があっても `rm -r` は辿らない）。これらの穴を見つけるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一時領域の中の削除先は満たす

- **WHEN** `cwd` が scratchpad の中で、`rm -rf ./a`・`rm -f <scratchpad>/tbl/*.tmp`・`cd ./tbl; rm -rf x/*`・`cd ./tbl && rm -f a b`・`rm -rf ./link`（scratchpad の外への symlink）を判定にかける
- **THEN** どれも満たす

#### Scenario: 一時領域の外や広すぎる削除先は満たさない

- **WHEN** `rm -rf /`・`rm -rf ~`・`rm -rf $HOME/x`・`rm -rf ../../..`（scratchpad の外に出る）・`rm -rf <scratchpad>`・`rm -rf <scratchpad>/*`・`rm -rf <scratchpad>/tbl/.`・`rm -rf <scratchpad>/tbl/`（末尾 `/`）・`rm -rf <作業ツリー>/x`・別セッションの scratchpad の中・`rm -rf <scratchpad>/a/*/b`（途中のグロブ）・`rm -rf <scratchpad>/linkdir/x`（`linkdir` が外への symlink）・`rm -- x`・`rm -i x`・`rm -rf "x"`・`rm -rf x > o`・`rm -rf x | cat`・`rm -rf x && ls`・`ls && rm -rf x`・`rm -rf x; cd ./y`・`cd ./a; cd ./b; rm -rf x` を判定にかける
- **THEN** どれも満たさず、理由を返す

#### Scenario: cd が失敗した場合の基準でも一時領域の中であること

- **WHEN** `cwd` が scratchpad の外で、`cd <scratchpad>/tbl; rm -rf x/*`（`cd` が成功すれば中、失敗すれば `cwd` 基準の `x/*` は外）を判定にかける。また `cwd` が scratchpad の中で `cd ./tbl; rm -rf x/*` を判定にかける
- **THEN** 前者は満たさず、後者は満たす

#### Scenario: 判定は rm も git も実行しない

- **WHEN** 削除先の実在するファイルを対象に判定を 1 回かけ、続けて同じファイルを調べる
- **THEN** ファイルは残っていて、判定は `rm` を実行していない（PATH の先頭に置いた `rm` のスタブが呼ばれた記録が無い）

### Requirement: 実機で確認画面が出ずに通り、許可の無いものは拒否されて親に返る

この変更の PR には、`claude -p --plugin-dir <worktree>` で動かした実機確認の結果を記録しなければならない（MUST）。記録するのは次の 3 点: サブエージェントが許可済みの一時領域の `rm`（`cd <dir>; rm … <rel>/*` の形）を打つと確認画面が出ずに実行されて消えること／許可の無い `rm` は確認画面が出ずに拒否され、サブエージェントが拒否の理由に従って報告に何を・なぜを書いて親に返ること／主の `rm` には hook が何も返さず今までどおりの確認になること。確認に使った Claude Code の版とコマンドも書く。

#### Scenario: PR に実機確認の結果がある

- **WHEN** PR 本文と記録先のコメントを見る
- **THEN** 上の 3 点それぞれに、試したコマンドと結果が書かれている
