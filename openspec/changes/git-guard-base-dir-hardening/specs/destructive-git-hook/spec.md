## MODIFIED Requirements

### Requirement: 同じ子への拒否の繰り返しを打ち切る

子（`agent_id` が空でない文字列）に `deny` を返すたびに、`session_id` と `agent_id` の組ごとの拒否の回数を、環境変数 `TMPDIR` が空でない文字列ならその下、未設定か空なら `/tmp` の下の `dev-workflow-git-guard/` にあるファイルに数えなければならない（MUST）。書き込めない `TMPDIR` を飛ばして別の場所に書いてはならない（MUST NOT。`tempfile.gettempdir()` の候補探しを使わない）。ファイル名は `session_id` と `agent_id` から導いたハッシュとし、`agent_id` や `session_id` をそのままパスに使ってはならない（MUST NOT）。回数のファイルを作れない・読めない・中身が整数でないときは、その呼び出しを 1 回目として扱い、`deny` は返さなければならない（MUST。数えられないことで通してはならない）。`allow` を返した呼び出しは数えてはならない（MUST NOT）。要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の確かめを満たさないとき、および判定のファイル（`plugins/dev-workflow/scripts/git-guard-scratchpad.py`）を読めず確かめられないときは、回数のファイルを読みも書きもせず、その呼び出しを数えてはならない（MUST NOT。`deny` は返す。2 回目以降の扱いにもしない）。回数のファイルは symlink を辿らずに開かなければならない（MUST。symlink なら読めないものとして 1 回目に扱い、その先を書き換えない）。

親が許可を書くスクリプト（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）で許可を書いたときは、その子の回数を 0 に戻す（回数のファイルを消す）。許可のあとの最初の拒否は 1 回目として扱わなければならない（MUST）。

同じ組への 2 回目以降の `deny` では、`permissionDecisionReason` に「直ちに作業を終えて親に返す」を含め、出力のトップレベルに `"continue": false` と `stopReason` を含めなければならない（MUST）。この形は既存のコードの実機確認済みの決定を引き継いだもので、この change では決め直さない（子の中で `continue: false` を返すと子だけが終わり、親が子の結果を受け取って続けることを確かめた記録は、archive の `openspec/changes/archive/2026-10-19-subagent-git-guard-deny/design.md` の節「2 回目以降の拒否: 強い理由文は常に足し、`continue: false` は実機確認の結果で決める」にある）。1 回目の `deny` には `"continue"` のキーを出力してはならない（MUST NOT）。主の呼び出し（`agent_id` が無い・空・文字列でない）は数えず、出力も変えない（MUST）。

守備範囲: 受け取る入力は、Claude Code が PreToolUse で渡す payload の `agent_id` と `session_id`、環境変数 `TMPDIR`、その下の回数のファイルである。拾いたい誤りは、拒否された子が打ち直しや言い換えで同じ hook に繰り返し当たり続けることである。次の入力は打ち切らずに通す（1 回目として扱う）ことを許す: 同じ子が並列の Bash 呼び出しで同時に拒否され、回数の読み書きが重なったもの／回数のファイルを作れない・読めない・中身が整数でないとき（毎回 1 回目になる）／一時ディレクトリが片付けられたあとの拒否（0 から数え直す）／hook に当たらない書き方（要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲で通ることを許した形）で子が同じことを試みたもの（拒否にならないので数えない）／他のプロセスが回数のファイルを書き換えたもの／`<base>` を確かめられないときの拒否と、判定のファイルを読めないときの拒否（数えないので毎回 1 回目になり、打ち切られない）。止めすぎる向きでは、SendMessage で再開された子は同じ `agent_id` を持つので回数が再開をまたいで続き、前の工程で 1 回拒否され親が許可を書かなかった子は次の工程の最初の拒否で 2 回目として扱われるが、これは許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 1 回目は打ち切らない

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を 1 回渡す
- **THEN** `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

#### Scenario: 同じ子への 2 回目は強く返す

- **WHEN** 空の `TMPDIR` で、`session_id` が `s1`・`agent_id` が `a1` の payload に `git checkout -- a` を渡して 1 回拒否されたあと、同じ `TMPDIR` で `session_id` が `s1`・`agent_id` が `a1` の payload に `git checkout -- b` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が含まれ、出力のトップレベルに `"continue": false` と `stopReason` が含まれる

#### Scenario: 別の子は 1 回目として数える

- **WHEN** `agent_id` が `a1` の payload で 1 回拒否されたあと、同じ `TMPDIR` で `agent_id` が `a2` の payload に `git checkout -- a` を渡す
- **THEN** 出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

#### Scenario: 回数を数えられなくても拒否する

- **WHEN** 書き込めないディレクトリを `TMPDIR` にして、`agent_id` が `a1` の payload に `git checkout -- a` を 2 回渡す
- **THEN** どちらも `permissionDecision` が `deny` になる

#### Scenario: 主の呼び出しは数えない

- **WHEN** 空の `TMPDIR` で、`agent_id` の無い payload と `agent_id` が空文字の payload（どちらも `permission_mode` が `auto`）に `git reset --hard` をそれぞれ 2 回渡す
- **THEN** どちらも出力に `"continue"` のキーが無く、`TMPDIR` の下に回数のファイルが作られない

#### Scenario: 親が許可を書いたら数え直す

- **WHEN** scratchpad の中の repo を `cwd` にした `agent_id` が `a1` の payload で `git checkout -- .` を渡して 1 回拒否され、その拒否の記録で親が許可を書き、同じ payload を渡して `allow` になったあと、同じ子の payload で `git reset --hard` を渡す
- **THEN** 最後の `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

### Requirement: 子への拒否を記録し、親が 1 回だけ通せるようにする

子の呼び出し（`agent_id` が空でない文字列）に `deny` を返すたびに、hook は拒否の記録を `<base>/denied/<key>.json` に書かなければならない（MUST）。`<base>` は要件「同じ子への拒否の繰り返しを打ち切る」の回数のファイルと同じ `dev-workflow-git-guard/`（環境変数 `TMPDIR` が空でない文字列ならその下、未設定か空なら `/tmp` の下）。`<key>` は payload の `session_id`・`agent_id`・`cwd`・`tool_input.command` を NUL でつないだ文字列の sha256 の 16 進とする（`session_id` と `cwd` が文字列でなければ空文字として扱う）。記録には `session_id`・`agent_id`・`cwd`・`command`（全文）・当たった種類・時刻を含めなければならない（MUST）。記録を書けなかったときも `deny` は返さなければならない（MUST）。`<base>` が要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の確かめを満たさないときは、この段落と次の段落の手順（記録を書く・許可を探す・回数を数える）を一つも行わずに `deny` を返さなければならない（MUST）。

子の呼び出しで破壊的 git 操作を見つけたとき、hook は同じ規則で `<key>` を計算し、`<base>/permits/<key>.json`（許可）を自分だけが使えるように `rename` で取ってから読まなければならない（MUST）。取れた許可の `session_id`・`agent_id`・`cwd`・`command` がすべて payload と一致し、`expires_at` が今より後で、かつ payload の `session_id`・`cwd`・`tool_input.command` が要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」の判定（以下「一時領域の判定」）をその時点のファイルシステムで満たすときに限り、`permissionDecision` を `allow` にし、取った許可を消さなければならない（MUST）。このとき拒否の回数を数えてはならず、拒否の記録も書いてはならない（MUST NOT）。一時領域の判定は、hook と許可を書くスクリプトが `plugins/dev-workflow/scripts/` に置いた同じ 1 つのファイルを読んで行わなければならない（MUST。判定を 2 か所に書き分けない）。許可ファイルが担うのは親の同意だけで、一時領域の外へ通さないことは hook のこの判定が担う。許可が無い・取れない・読めない・どれかの値が一致しない・期限切れのときは、取った許可を消し、今までどおり `deny` を返して回数を数えなければならない（MUST）。許可の 4 つの値は一致し期限内だが一時領域の判定を満たさないときも、取った許可を消して `deny` を返し回数を数え、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含めなければならない（MUST）。判定のファイルを読めないときは `<key>` を出せないので、許可を探さず拒否の記録も書かずに `deny` を返さなければならない（MUST。許可は残り、期限で切れる）。このときは `<base>` を確かめられないので、回数も数えてはならない（MUST NOT。要件「同じ子への拒否の繰り返しを打ち切る」）。

hook と許可を書くスクリプトは、payload の `cwd` を、そのコマンドが実行されるディレクトリとして扱う（実機で確認済み: 子の Bash は呼び出しをまたいで作業ディレクトリを持ち越さず、`cd` だけを打った次の呼び出しの payload の `cwd` は起動ディレクトリのままで、コマンドが実行されるディレクトリと一致した。archive の design.md「cd のあとの payload の cwd」）。主の呼び出し（`agent_id` が無い・空・文字列でない）は許可を見てはならない（MUST NOT。今までどおり `ask` / `deny`）。`allow` の `permissionDecisionReason` には、親が書いた許可に一致したのでこの 1 回だけ通すことを書かなければならない（MUST）。

守備範囲: 受け取る入力は、要件「同じ子への拒否の繰り返しを打ち切る」の入力に payload の `cwd` と、`<base>` の下の `denied/` と `permits/` のファイルを足したものである。拾いたい誤りは、子が自分の scratchpad の検証用 repo を戻すだけの操作でも、親が代わりに打つと主の確認画面が出て、主が画面を押すまで作業が止まることである。次の入力は止めることを許す: 親が許可を書いたあと、子がコマンドを 1 文字でも変えて打ったもの・別の cwd から打ったもの／SendMessage で再開されずに新しい子として起こされ `agent_id` が変わったもの／期限が切れてから打ったもの。次の入力は通すことを許す: 子や他のプロセスが許可を書くスクリプトを経ずに `permits/` に直接書いた許可のうち、一時領域の判定を満たすもの（親の同意は経ないが、通るのは scratchpad の中の repo への操作だけに限られる）／hook が一時領域の判定を終えてからコマンドが実行されるまでの間に、scratchpad の中のディレクトリが外への symlink に差し替えられたもの。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一致する許可があれば 1 回だけ通す

- **WHEN** 空の `TMPDIR` で、`session_id` が scratchpad の形に合うセッション・`agent_id` が `a1`・`cwd` が scratchpad の中の repo の payload に `git checkout -- .` を渡して拒否され、拒否の記録のパスで許可を書くスクリプトが exit 0 で終わったあと、同じ payload を 2 回渡す
- **THEN** 1 回目は `permissionDecision` が `allow`、2 回目は `deny` になる

#### Scenario: 許可のあとで行き先が外に変わったら通さない

- **WHEN** 上と同じく許可を書いたあと、その repo の `.git` を、scratchpad の外の repo の git ディレクトリを指す symlink に差し替えてから、元の payload を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」が含まれ、許可のファイルが残っていない

#### Scenario: 直接書いた許可でも外は通さない

- **WHEN** 許可を書くスクリプトを使わずに、`cwd` が scratchpad の外の repo で 4 つの値が payload と一致し期限内の許可を `permits/<key>.json` に直接書いてから、その payload に `git checkout -- .` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」が含まれる

#### Scenario: 一致しない呼び出しには許可を使わない

- **WHEN** 上と同じく許可を書いたあと、コマンドの末尾に空白を 1 つ足した payload、`agent_id` が `a2` の payload、`cwd` が違う payload をそれぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になり、そのあと元の payload を渡すと `allow` になる（一致しない呼び出しで許可が消えない）

#### Scenario: 期限切れの許可は使わない

- **WHEN** 許可を書いたあと、許可のファイルの `expires_at` を過去の時刻に書き換えてから、元の payload を渡す
- **THEN** `permissionDecision` が `deny` になり、許可のファイルが残っていない

#### Scenario: 主の呼び出しは許可を見ない

- **WHEN** 許可を書いたあと、同じ `session_id`・`cwd`・コマンドで `agent_id` の無い、`permission_mode` が `default` の payload を渡す
- **THEN** `permissionDecision` が `ask` になり、許可のファイルが残っている

#### Scenario: 拒否の記録が書かれる

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `TMPDIR` の下の `dev-workflow-git-guard/denied/` に、`session_id`・`agent_id`・`cwd`・コマンドの全文を含む記録が 1 つ作られ、`permissionDecisionReason` にそのパスが含まれる

#### Scenario: 判定のファイルを読めないときは許可を探さずに拒否する

- **WHEN** `git-guard-scratchpad.py` が無い場所に hook だけを置き、4 つの値が一致する許可を `permits/<key>.json` に置いてから、`agent_id` が `a1` の `git checkout -- a` の payload を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含まず、`denied/` は作られず、許可のファイルは残る。同じ payload をもう 1 回渡しても、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無く、回数のファイルが作られない

## ADDED Requirements

### Requirement: 拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う

hook と許可を書くスクリプトは、`<base>` とその下の `denied/`・`permits/` を使う前に、それぞれを lstat で見て、symlink でない・ディレクトリ・持ち主が自分の uid・グループと他者に書き込み権が無い、をすべて満たすか確かめなければならない（MUST）。無いものは 0700 で作ってから確かめる（MUST）。`<base>` の親が無ければ作らず、満たさないものとする（MUST）。既にあって満たすフォルダのモードは変えない（0755 でも使う）。確かめと作成は `git-guard-scratchpad.py` の 1 か所で行う（MUST）。

#### 守備範囲

受け取る入力は、環境変数 `TMPDIR`、`<base>`・`denied/`・`permits/` を lstat で見た結果（種類・持ち主の uid・モード）、hook と許可を書くスクリプトを動かしている自分の uid である。拾いたい誤りは、別の uid が `<base>`（またはその下の `denied/`・`permits/`）を先に作るか別の場所への symlink にしておき、そこへ偽の許可を置いて子のコマンドを通させる・hook に symlink の先のファイルを上書きさせる・拒否の記録（コマンドの全文と cwd）を読むことである。次の入力は通すことを許す: 同じ uid のプロセス（子のサブエージェントを含む）が作った・差し替えた `<base>` とその中身（子による許可の偽造は別の change で扱う）／確かめてから使うまでの間に同じ uid のプロセスが差し替えたもの／既にある 0755 の `<base>` と、その中の読み取り権付きの記録（別の uid に読まれうるが、書き換えや偽造にはつながらない）／root が作った・書き換えたもの／`<base>` の祖先（`TMPDIR`・`/tmp`・macOS の `/var` → `/private/var`）が symlink であるもの。止めすぎる向きでは、自分で 0775 や 0777 に変えた自分の `<base>` も満たさないものとして扱い、子の許可が通らなくなるが、これは許す（理由文に満たさなかった条件が出るので、主が手で直せる）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない（design.md「Non-Goals」）。

#### Scenario: 新しく作る `<base>` は所有者だけが使える

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`TMPDIR` の下の `dev-workflow-git-guard/` と `denied/` のモードが 0700 になる

#### Scenario: 既にある 0755 の `<base>` はそのまま使う

- **WHEN** `TMPDIR` の下に自分の持ち物の `dev-workflow-git-guard` をモード 0755 で作り、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`denied/` に拒否の記録が作られ、`dev-workflow-git-guard` のモードは 0755 のまま

#### Scenario: グループか他者が書ける `<base>` は使わない

- **WHEN** `TMPDIR` の下に `dev-workflow-git-guard` をモード 0777 で作り、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「拒否の記録を作れなかった」が含まれ、`dev-workflow-git-guard/` の下に何も作られない

#### Scenario: `denied/` や `permits/` が symlink なら使わない

- **WHEN** 確かめを満たす `<base>` の下の `denied/`（別の試行では `permits/`）を別のディレクトリへの symlink にして、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「拒否の記録を作れなかった」が含まれ、symlink の先に何も作られない

### Requirement: `<base>` の中のファイルを symlink を辿らずに開き、所有者だけのモードで作る

`<base>` の中のファイル（回数・拒否の記録・許可・`permit-log.jsonl`・一時ファイル）は symlink を辿らずに開かなければならない（MUST）。新しく作るファイルは、予測できない名前・既にあれば失敗する排他的な作成・0600 で作り、回数・拒否の記録・許可はその一時ファイルからの `rename` で置く（MUST）。`permit-log.jsonl` は symlink を辿らない追記で開き、無ければ 0600 で作る（MUST）。`rename` で取った許可と、許可を書くスクリプトが読む拒否の記録も symlink を辿らずに読み、symlink なら読めないものとして扱う（MUST。取った許可は消し、許可を書くスクリプトは 0 以外で終わる）。

#### 守備範囲

受け取る入力は、確かめを満たした `<base>` の中の名前（回数のファイル・`denied/<key>.json`・`permits/<key>.json`・`permit-log.jsonl`・一時ファイル）が symlink かどうかとその中身、許可を書くスクリプトに引数で渡された拒否の記録のパスである。拾いたい誤りは、`<base>` の中の名前が別のファイルへの symlink にされていて、hook や許可を書くスクリプトがその先のファイル（自分が書けるリポジトリのファイルなど）を上書き・追記すること、symlink の先の偽の許可や記録を読んで使うこと、予測できる一時ファイルの名前を先に作られてそこへ書くことである。次の入力は通すことを許す: 同じ uid のプロセスが symlink でない普通のファイルとして直接置いた許可・拒否の記録（子による偽造は別の change で扱う）／ハードリンク（`O_NOFOLLOW` はハードリンクを見分けないが、別の uid は確かめを満たす `<base>` の中に名前を作れない）／`rename` で置く直前やその直後に同じ uid のプロセスが置き先を差し替えたもの／既にある 0644 などのファイル（モードを締め直さない）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 許可のファイルが symlink なら使わず、先を書き換えない

- **WHEN** 確かめを満たす `<base>` の下で、4 つの値が payload と一致し期限内で一時領域の判定を満たす許可の中身を書いたファイル C を `<base>` の外に置き、`permits/<key>.json` を C への symlink にしてから、その payload に `git checkout -- .` を渡す
- **THEN** `permissionDecision` が `deny` で、C の中身が変わらず残っている

#### Scenario: 新しく作るファイルは 0600

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** 拒否の記録と回数のファイルのモードが 0600 になる

#### Scenario: `<base>` の中の symlink の先を書き換えない

- **WHEN** 確かめを満たす `<base>` の下で、回数のファイルを別のファイル A への symlink に、`permit-log.jsonl` を別のファイル B への symlink にし、期限切れの許可を `permits/<key>.json` に置いてから、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、A と B の中身が変わっていない

#### Scenario: symlink の拒否の記録からは許可を書かない

- **WHEN** `denied/<key>.json` を、中身が正しい記録の別のファイルへの symlink にしてから、そのパスで許可を書くスクリプトを実行する
- **THEN** 終了コードが 0 以外で、`permits/` に許可が無い

### Requirement: `<base>` を確かめられない子の呼び出しには deny だけを返す

確かめを満たさないとき、hook は子の呼び出しで許可を探さず、拒否の記録を書かず、回数を数えずに（2 回目以降の扱いと `"continue"` のキーも出さない）、`permissionDecision` を `deny` にしなければならない（MUST）。`permissionDecisionReason` には子向けの文に加えて、文字列「拒否の記録を作れなかった」・`<base>` のパス・満たさなかった条件・親に返す報告にコマンドの全文を書くことを含める（MUST）。拒否の記録のパスは載せない。

#### 守備範囲

受け取る入力は、要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の確かめの結果（満たしたか・満たさなかった条件・パス）と、payload の `agent_id`・`tool_input.command` である。拾いたい誤りは、確かめを満たさない場所へ記録や回数を書いて symlink の先を書き換えること、そこに置かれた許可で子のコマンドを通すこと、子に落ち度の無い環境の問題で子を打ち切ること、の 3 つである。次の入力は止める・通すことを許す: 自分で 0777 に変えた `<base>` など確かめを満たさない環境では、子の破壊的 git 操作は親の許可で通せなくなる（止めすぎる向き。打ち切らないので子は親に返り、主の呼び出しは止まらない）／確かめを満たさないあいだ、子が同じコマンドを何度打ち直しても打ち切られず毎回 1 回目として返る（通しすぎる向き。拒否は返るのでコマンドは実行されない）。1 台の Mac を別のユーザーが同時に使い、そのユーザーが先に `/tmp/dev-workflow-git-guard` を作る形は想定しない（エピック #1476 の本文の節「条件の答え」）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: `<base>` が symlink なら記録も回数も書かず、置かれた許可も使わない

- **WHEN** `TMPDIR` の下の `dev-workflow-git-guard` を別のディレクトリへの symlink にし、その先の `permits/<key>.json` に 4 つの値が一致し期限内の許可を置いてから、scratchpad の中の repo を `cwd` にした `agent_id` が `a1` の payload に `git checkout -- .` を 2 回渡す
- **THEN** どちらも `permissionDecision` が `deny` で、`permissionDecisionReason` に「拒否の記録を作れなかった」と `<base>` のパスが含まれ、「直ちに作業を終えて親に返す」が無く、出力に `"continue"` のキーが無い。symlink の先には `denied/` も回数のファイルも作られず、置いた許可が残っている

### Requirement: 主の呼び出しは `<base>` を作りも確かめもしない

主の呼び出し（`agent_id` が無い・空・文字列でない）では、hook は `<base>` を作りも確かめもしてはならず（MUST NOT）、`<base>` の状態で `ask` / `deny` と理由文を変えてはならない（MUST NOT）。主の対話セッションの確認画面と、印のあるセッションの `deny` は、`<base>` が他人に作られていても今までどおり出る。

#### 守備範囲

受け取る入力は payload の `agent_id` だけで、`<base>` の状態は見ない。拾いたい誤りは、`<base>` が symlink や他人の持ち物であることで、主の確認画面が出なくなる・理由文が変わる・主の呼び出しで `<base>` が作られることである。次の入力は通すことを許す: 主の呼び出しが続くあいだは、`<base>` が確かめを満たさなくても hook は何も知らせない（気づくのは子の呼び出しの拒否の理由文から）。この穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 主の呼び出しは `<base>` の状態によらず今までどおり

- **WHEN** `TMPDIR` の下の `dev-workflow-git-guard` を別のディレクトリへの symlink にして、`agent_id` の無い `permission_mode` が `default` の payload に `git reset --hard` を渡す
- **THEN** `permissionDecision` が `ask` で、理由文が `<base>` が正常なときと同じで、symlink の先に何も作られない

### Requirement: 許可を書くスクリプトは確かめを満たさない `<base>` に書かない

許可を書くスクリプトは、拒否の記録のパスの 2 つ上を `<base>` として確かめ、満たさないときは許可も `permit-log.jsonl` の行も書かず、回数のファイルも消さずに、満たさなかった条件と場所を stderr に書いて 0 以外で終わらなければならない（MUST）。親はこれを今までどおり「許可を書くスクリプトが 0 以外で終わった」としてオーナーに上げる（`skills/develop/SKILL.md` の手順は変えない）。

#### 守備範囲

受け取る入力は、許可を書くスクリプトに引数で渡された拒否の記録のパスと、その 2 つ上のディレクトリ（`<base>`）と `denied/`・`permits/` を lstat で見た結果である。拾いたい誤りは、別の uid が作った・symlink にした `<base>` の中に許可や `permit-log.jsonl` の行を書き、偽の許可が使える場所に親の許可を置いたり symlink の先を書き換えたりすることである。次の入力は止める・通すことを許す: 自分で 0777 に変えた自分の `<base>` の記録からも許可を書けない（止めすぎる向き。親はオーナーに上げ、オーナーが直す）／確かめてから書くまでの間に同じ uid のプロセスが `<base>` を差し替えたものには書く（通しすぎる向き。同じ uid は守らない）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 確かめを満たさない `<base>` に許可を書かない

- **WHEN** 拒否の記録を書かせたあと、`<base>` のモードを 0777 に変えてから、その記録のパスで許可を書くスクリプトを実行する
- **THEN** 終了コードが 0 以外で、stderr に `<base>` のパスが含まれ、`permits/` に許可が無く、`permit-log.jsonl` に `permit` の行が無い

