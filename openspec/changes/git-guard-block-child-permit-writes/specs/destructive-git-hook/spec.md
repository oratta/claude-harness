## ADDED Requirements

### Requirement: 子は Write / Edit / NotebookEdit で許可の置き場所に書けない

hook `scripts/git-guard-base-write-guard.sh` は、子（`agent_id` が空でない文字列）の書き先（Write / Edit は `tool_input.file_path`、NotebookEdit は `tool_input.notebook_path`）の部品のどれかが、大文字小文字を区別せずに `<base>` の名前 `dev-workflow-git-guard` と一致すれば、`permissionDecision` が `deny` の JSON を出さなければならない（MUST。`permits/` に限らず `<base>` の中はすべて）。書き先は、相対なら payload の `cwd` を前に付け、`..` を畳んだパスと、既にある部分の symlink を辿ったパスの両方で見る（MUST）。この hook は `<base>` を作らず、回数・拒否の記録・許可に触れない（MUST NOT。数えない）。

#### 守備範囲

この要件と、要件「子は Bash のコマンドで許可の置き場所を名指しできない」「許可の置き場所への書き込みの拒否は親に返すよう案内する」の目的は、ルールを読み飛ばした子が許可の置き場所に分かりやすく書こうとしたときに止めることで、セキュリティ境界ではない。子・hook・親は同じ uid で動き、hook が読める秘密は子も読めるので、子が作れない印で許可を見分けることはできない。受け取る入力は、Claude Code が PreToolUse で渡す payload の `tool_name`・`tool_input.file_path`・`tool_input.notebook_path`・`tool_input.command`・`cwd`・`agent_id`（どれも子の呼び出しでは子が決める値）、書き先のパスを辿った時点のファイルシステム、環境変数 `DEV_WORKFLOW_GIT_GUARD` である。拾いたい誤りは、拒否された子が親に返らずに、Write / Edit / NotebookEdit ツールか、置き場所の名前を書いた Bash のコマンドで、自分で許可を置くことである。次の入力は通すことを許す: 変数や置換で組み立てたパス（`d=dev-workflow-git-; "$TMPDIR/${d}guard/permits/k.json"`）／グロブ（`"$TMPDIR"/dev-workflow-*/permits/k.json`、`.../dev-workflow-git-guard/p*/k.json`）／置き場所に移ってから `permits` の名前を書かずに書くもの（`cd .../dev-workflow-git-guard/perm*` のあとの書き込み）／スクリプトファイル・Makefile・別のファイルの中から書くもの／大文字小文字を変えた名前の Bash のコマンド（大文字小文字を区別しないファイルシステムでは同じ場所に届く）／Write / Edit / NotebookEdit 以外のツール（MCP のファイル書き込みなど）で書くもの／hook が書き先を辿ってから書かれるまでの間に、途中のフォルダが置き場所への symlink に差し替えられたもの／主の呼び出しが書くもの。通っても、許可が効くのは使う時点の一時領域の判定（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）を満たす scratchpad の中だけである。次の入力は止めることを許す（止めすぎる向き）: このガードの置き場所そのものを扱う開発で、子が 2 つの名前を両方含むコマンド（spec の書き換え・grep・偽造の確かめ）を打つもの（2026-11-10 時点の会話ログで Bash の呼び出し 109,484 件のうち 8 件。子は親に返り、親が打つ）／置き場所の名前の部品を持つ、置き場所でないフォルダへの書き込み。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: Write / Edit / NotebookEdit で `<base>` の中に書くと拒否する

- **WHEN** 空の `TMPDIR` を T として、`agent_id` が `a1` の Write の payload の `file_path` を `T/dev-workflow-git-guard/permits/k.json` に、Edit の payload の `file_path` を `T/dev-workflow-git-guard/<回数のファイルの名前>` に、NotebookEdit の payload の `notebook_path` を `T/dev-workflow-git-guard/x.ipynb` にして、それぞれ新しい hook に渡す
- **THEN** どれも `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、T の下に何も作られない

#### Scenario: 書き先の書き方を変えても拒否する

- **WHEN** `agent_id` が `a1` の Write の payload の `file_path` を、`T/Dev-Workflow-Git-Guard/permits/k.json`・`T/x/../dev-workflow-git-guard/permits/k.json`・`cwd` を T にした相対パス `dev-workflow-git-guard/permits/k.json`・`T/dev-workflow-git-guard` を指す symlink `T/link` を経た `T/link/permits/k.json` にして、それぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になる

### Requirement: 置き場所への書き込みを止める hook の配線と逃げ道

dev-workflow は `scripts/git-guard-base-write-guard.sh` を、`hooks/hooks.json` の PreToolUse に `matcher: "Write|Edit|NotebookEdit"` で、`command` を `"${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-base-write-guard.sh"` と引用符で囲み、`if` を付けずに登録しなければならない（MUST）。PreToolUse の末尾は git ガードの Bash のエントリのまま保つ（MUST）。この hook は、主の呼び出し（`agent_id` が無い・空・文字列でない）・部品が一致しない書き先・`DEV_WORKFLOW_GIT_GUARD=off`・python3 が無い・stdin が JSON でない・payload がオブジェクトでない・`tool_name` が 3 つのどれでもない・書き先が文字列でないときは、何も出さずに exit 0 としなければならない（MUST）。

#### 守備範囲

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲と同じ。

#### Scenario: 主の呼び出しと置き場所の外への書き込みは止めない

- **WHEN** `agent_id` の無い Write の payload の `file_path` を `T/dev-workflow-git-guard/permits/k.json` にしたもの、`agent_id` が `a1` の Write の payload の `file_path` を `plugins/dev-workflow/tests/git-destructive-guard.bats` と `T/notes/dev-workflow-git-guard.md` にしたもの、`DEV_WORKFLOW_GIT_GUARD=off` で `agent_id` が `a1` の `file_path` を `T/dev-workflow-git-guard/permits/k.json` にしたもの、`tool_name` が `Bash` の payload、JSON でない文字列を、それぞれ新しい hook に渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 新しい hook が hooks.json に登録されている

- **WHEN** `plugins/dev-workflow/hooks/hooks.json` の PreToolUse を読む
- **THEN** `matcher` が `Write|Edit|NotebookEdit` で `"${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-base-write-guard.sh"` の command hook を持ち `if` の無いエントリがあり、配列の末尾は git ガードの `matcher` が `Bash` のエントリのままである

### Requirement: 子は Bash のコマンドで許可の置き場所を名指しできない

git ガード（`scripts/git-destructive-guard.sh`）は、子の呼び出しの `tool_input.command` のどこかに `dev-workflow-git-guard` と `permits` の両方が含まれるとき（部分文字列で、大文字小文字を区別する）、書き方を読み分けずに `deny` を返さなければならない（MUST。当たった種類は「許可の置き場所を名指しするコマンド」）。拒否の記録を書かず、許可を探さない（MUST NOT）。ほかの種類（破壊的 git 操作の 9 種・判定しきれなかったもの・許可を書くスクリプトの子からの呼び出し）に当たらなければ、回数を数えず `<base>` を作りも確かめもしない（MUST NOT）。当たれば今までどおり数える（MUST）。主の呼び出しはこの判定で止めない（MUST NOT）。

#### 守備範囲

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲と同じ。2 つの名前の選び方と止めすぎの頻度の根拠は、この change の design.md の決定 2。

#### Scenario: Bash のコマンドに 2 つの名前があれば拒否し、数えない

- **WHEN** 空の `TMPDIR` を T として、`agent_id` が `a1` の payload に `printf '{}' > T/dev-workflow-git-guard/permits/k.json` を 2 回、続けて `cd T/dev-workflow-git-guard && python3 -c "open('permits/k.json','w')"` を 1 回渡す
- **THEN** どれも `permissionDecision` が `deny` で、「直ちに作業を終えて親に返す」は無く、出力に `"continue"` のキーが無い。T の下に `dev-workflow-git-guard/` が作られない

#### Scenario: 名前が 1 つだけのコマンドと主の呼び出しは止めない

- **WHEN** `agent_id` が `a1` の payload に `cat T/dev-workflow-git-guard/denied/k.json` と `echo permits` を、`agent_id` の無い `permission_mode` が `default` の payload に `printf '{}' > T/dev-workflow-git-guard/permits/k.json` を、それぞれ渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 破壊的 git 操作も含むなら数えるが、記録を書かず許可も使わない

- **WHEN** scratchpad の中の repo を `cwd` にした `agent_id` が `a1` の payload のコマンド C を `git checkout -- . ; ls T/dev-workflow-git-guard/permits` として、4 つの値が C の payload と一致し期限内の許可を `permits/<key>.json` に置いてから、C を 2 回渡す
- **THEN** どちらも `permissionDecision` が `deny` で、2 回目の出力のトップレベルに `"continue": false` があり、置いた許可が残っていて、`denied/` に記録が無い

### Requirement: 許可の置き場所への書き込みの拒否は親に返すよう案内する

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」と「子は Bash のコマンドで許可の置き場所を名指しできない」の拒否の `permissionDecisionReason` は、「許可の置き場所」を含み、打ち直さず別の書き方も試さずに作業を止め、要るものを報告に書いて親に返すよう案内しなければならない（MUST）。Bash の拒否では、このコマンドには拒否の記録を作らないことを、文字列「拒否の記録を作らない」を含む文で書かなければならない（MUST）。どちらの理由文も `dev-workflow-git-guard` と `permits` を両方は含んではならない（MUST NOT。子が理由文を報告用のコマンドに写したとき、そのコマンドが止まらないようにするため）。

#### 守備範囲

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲と同じ。理由文の中身で子の振る舞いを縛ることはできず、案内に従わない子は止められない（拒否は返るのでコマンドは実行されない）。

#### Scenario: 理由文が親に返すよう案内し、2 つの名前を並べない

- **WHEN** `agent_id` が `a1` の Write の payload の `file_path` を `T/dev-workflow-git-guard/permits/k.json` にして新しい hook に渡し、`agent_id` が `a1` の payload に `printf '{}' > T/dev-workflow-git-guard/permits/k.json` を git ガードに渡す
- **THEN** どちらの `permissionDecisionReason` にも「許可の置き場所」と「親に返す」が含まれ、`dev-workflow-git-guard` と `permits` の両方は含まれない。git ガードの理由文には「許可の置き場所を名指しするコマンド」と「拒否の記録を作らない」が含まれる

## MODIFIED Requirements

### Requirement: 同じ子への拒否の繰り返しを打ち切る

子（`agent_id` が空でない文字列）に `deny` を返すたびに、`session_id` と `agent_id` の組ごとの拒否の回数を、環境変数 `TMPDIR` が空でない文字列ならその下、未設定か空なら `/tmp` の下の `dev-workflow-git-guard/` にあるファイルに数えなければならない（MUST）。書き込めない `TMPDIR` を飛ばして別の場所に書いてはならない（MUST NOT。`tempfile.gettempdir()` の候補探しを使わない）。ファイル名は `session_id` と `agent_id` から導いたハッシュとし、`agent_id` や `session_id` をそのままパスに使ってはならない（MUST NOT）。回数のファイルを作れない・読めない・中身が整数でないときは、その呼び出しを 1 回目として扱い、`deny` は返さなければならない（MUST。数えられないことで通してはならない）。`allow` を返した呼び出しは数えてはならない（MUST NOT）。要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の確かめを満たさないとき、および判定のファイル（`plugins/dev-workflow/scripts/git-guard-scratchpad.py`）を読めず確かめられないときは、回数のファイルを読みも書きもせず、その呼び出しを数えてはならない（MUST NOT。`deny` は返す。2 回目以降の扱いにもしない）。回数のファイルは symlink を辿らずに開かなければならない（MUST。symlink なら読めないものとして 1 回目に扱い、その先を書き換えない）。要件「子は Bash のコマンドで許可の置き場所を名指しできない」が止める呼び出しのうち、ほかの種類（破壊的 git 操作の 9 種・判定しきれなかったもの・許可を書くスクリプトの子からの呼び出し）に当たらないものは、数えてはならない（MUST NOT。`deny` は返す。2 回目以降の扱いにもせず、`"continue"` のキーも出さない）。ほかの種類にも当たるものは、今までどおり数える（MUST）。

親が許可を書くスクリプト（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）で許可を書いたときは、その子の回数を 0 に戻す（回数のファイルを消す）。許可のあとの最初の拒否は 1 回目として扱わなければならない（MUST）。

同じ組への 2 回目以降の `deny` では、`permissionDecisionReason` に「直ちに作業を終えて親に返す」を含め、出力のトップレベルに `"continue": false` と `stopReason` を含めなければならない（MUST）。この形は既存のコードの実機確認済みの決定を引き継いだもので、この change では決め直さない（子の中で `continue: false` を返すと子だけが終わり、親が子の結果を受け取って続けることを確かめた記録は、archive の `openspec/changes/archive/2026-10-19-subagent-git-guard-deny/design.md` の節「2 回目以降の拒否: 強い理由文は常に足し、`continue: false` は実機確認の結果で決める」にある）。1 回目の `deny` には `"continue"` のキーを出力してはならない（MUST NOT）。主の呼び出し（`agent_id` が無い・空・文字列でない）は数えず、出力も変えない（MUST）。

守備範囲: 受け取る入力は、Claude Code が PreToolUse で渡す payload の `agent_id` と `session_id`、環境変数 `TMPDIR`、その下の回数のファイルである。拾いたい誤りは、拒否された子が打ち直しや言い換えで同じ hook に繰り返し当たり続けることである。次の入力は打ち切らずに通す（1 回目として扱う）ことを許す: 同じ子が並列の Bash 呼び出しで同時に拒否され、回数の読み書きが重なったもの／回数のファイルを作れない・読めない・中身が整数でないとき（毎回 1 回目になる）／一時ディレクトリが片付けられたあとの拒否（0 から数え直す）／hook に当たらない書き方（要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲で通ることを許した形）で子が同じことを試みたもの（拒否にならないので数えない）／他のプロセスが回数のファイルを書き換えたもの／`<base>` を確かめられないときの拒否と、判定のファイルを読めないときの拒否（数えないので毎回 1 回目になり、打ち切られない）／要件「子は Bash のコマンドで許可の置き場所を名指しできない」だけに当たった拒否（要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の拒否は別の hook で、もともと数えない。ルールを読み飛ばした子を 1 回で打ち切らないため数えない。同じ子が何度打ち直しても毎回 1 回目として返るが、コマンドは実行されない）。止めすぎる向きでは、SendMessage で再開された子は同じ `agent_id` を持つので回数が再開をまたいで続き、前の工程で 1 回拒否され親が許可を書かなかった子は次の工程の最初の拒否で 2 回目として扱われるが、これは許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

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

子の呼び出し（`agent_id` が空でない文字列）に `deny` を返すたびに、hook は拒否の記録を `<base>/denied/<key>.json` に書かなければならない（MUST）。`<base>` は要件「同じ子への拒否の繰り返しを打ち切る」の回数のファイルと同じ `dev-workflow-git-guard/`（環境変数 `TMPDIR` が空でない文字列ならその下、未設定か空なら `/tmp` の下）。`<key>` は payload の `session_id`・`agent_id`・`cwd`・`tool_input.command` を NUL でつないだ文字列の sha256 の 16 進とする（`session_id` と `cwd` が文字列でなければ空文字として扱う）。記録には `session_id`・`agent_id`・`cwd`・`command`（全文）・当たった種類・時刻を含めなければならない（MUST）。記録を書けなかったときも `deny` は返さなければならない（MUST）。`<base>` が要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の確かめを満たさないときは、この段落と次の段落の手順（記録を書く・許可を探す・回数を数える）を一つも行わずに `deny` を返さなければならない（MUST）。要件「子は Bash のコマンドで許可の置き場所を名指しできない」が当たった呼び出しでは、ほかの種類にも当たるときも含めて、拒否の記録を書かず、許可を探さずに `deny` を返さなければならない（MUST。この段落と次の段落の記録と許可の手順より優先する。回数の扱いは要件「同じ子への拒否の繰り返しを打ち切る」）。

子の呼び出しで破壊的 git 操作を見つけたとき、hook は同じ規則で `<key>` を計算し、`<base>/permits/<key>.json`（許可）を自分だけが使えるように `rename` で取ってから読まなければならない（MUST）。取れた許可の `session_id`・`agent_id`・`cwd`・`command` がすべて payload と一致し、`expires_at` が今より後で、かつ payload の `session_id`・`cwd`・`tool_input.command` が要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」の判定（以下「一時領域の判定」）をその時点のファイルシステムで満たすときに限り、`permissionDecision` を `allow` にし、取った許可を消さなければならない（MUST）。このとき拒否の回数を数えてはならず、拒否の記録も書いてはならない（MUST NOT）。一時領域の判定は、hook と許可を書くスクリプトが `plugins/dev-workflow/scripts/` に置いた同じ 1 つのファイルを読んで行わなければならない（MUST。判定を 2 か所に書き分けない）。許可ファイルが担うのは親の同意だけで、一時領域の外へ通さないことは hook のこの判定が担う。許可が無い・取れない・読めない・どれかの値が一致しない・期限切れのときは、取った許可を消し、今までどおり `deny` を返して回数を数えなければならない（MUST）。許可の 4 つの値は一致し期限内だが一時領域の判定を満たさないときも、取った許可を消して `deny` を返し回数を数え、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含めなければならない（MUST）。判定のファイルを読めないときは `<key>` を出せないので、許可を探さず拒否の記録も書かずに `deny` を返さなければならない（MUST。許可は残り、期限で切れる）。このときは `<base>` を確かめられないので、回数も数えてはならない（MUST NOT。要件「同じ子への拒否の繰り返しを打ち切る」）。

hook と許可を書くスクリプトは、payload の `cwd` を、そのコマンドが実行されるディレクトリとして扱う（実機で確認済み: 子の Bash は呼び出しをまたいで作業ディレクトリを持ち越さず、`cd` だけを打った次の呼び出しの payload の `cwd` は起動ディレクトリのままで、コマンドが実行されるディレクトリと一致した。archive の design.md「cd のあとの payload の cwd」）。主の呼び出し（`agent_id` が無い・空・文字列でない）は許可を見てはならない（MUST NOT。今までどおり `ask` / `deny`）。`allow` の `permissionDecisionReason` には、親が書いた許可に一致したのでこの 1 回だけ通すことを書かなければならない（MUST）。

守備範囲: 受け取る入力は、要件「同じ子への拒否の繰り返しを打ち切る」の入力に payload の `cwd` と、`<base>` の下の `denied/` と `permits/` のファイルを足したものである。拾いたい誤りは、子が自分の scratchpad の検証用 repo を戻すだけの操作でも、親が代わりに打つと主の確認画面が出て、主が画面を押すまで作業が止まることである。次の入力は止めることを許す: 親が許可を書いたあと、子がコマンドを 1 文字でも変えて打ったもの・別の cwd から打ったもの／SendMessage で再開されずに新しい子として起こされ `agent_id` が変わったもの／期限が切れてから打ったもの。次の入力は通すことを許す: 子や他のプロセスが許可を書くスクリプトを経ずに `permits/` に直接書いた許可のうち、一時領域の判定を満たすもの（親の同意は経ないが、通るのは scratchpad の中の repo への操作だけに限られる）。子が書く形のうち、Write / Edit / NotebookEdit で書くものと、Bash のコマンドに置き場所の名前を 2 つとも書くものは、要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」と要件「子は Bash のコマンドで許可の置き場所を名指しできない」が書く前に止める。それ以外の書き方（要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲で通ることを許した形）で置かれた許可は、使う時点で区別できないので通る／hook が一時領域の判定を終えてからコマンドが実行されるまでの間に、scratchpad の中のディレクトリが外への symlink に差し替えられたもの。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

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

### Requirement: 子は許可を書くスクリプトを呼べない

子の呼び出しで、`tool_input.command` の文字列のどこかに `git-guard-permit` が含まれるものに、hook は書き方（直接の呼び出し・シェル経由・`-c` のコマンド文字列の中・`BASH_ENV` / `ENV` の設定・`cat` などで読むだけのもの）を問わず `deny` を返さなければならない（MUST。大文字小文字は区別する）。シェルの書き方を 1 つずつ読み分けて止めると、塞ぐたびに別の書き方が出るため、コマンドの読み方に頼らない。子がこのスクリプトを読む用事は無いので、読むだけのものも止める。拒否理由・回数・拒否の記録は、破壊的 git 操作の拒否と同じに扱う（当たった種類は許可を書くスクリプトの子からの呼び出し）。ただし同じコマンドに要件「子は Bash のコマンドで許可の置き場所を名指しできない」も当たるときは、拒否の記録を書かない（その要件に従う。回数は数える）。この呼び出しには許可を使ってはならない（MUST NOT）。主の呼び出しは止めてはならない（MUST NOT）。

守備範囲: 受け取る入力は、Claude Code が PreToolUse で渡す payload の `tool_input.command`（子が書く値）と `agent_id` である。拾いたい誤りは、拒否された子が親に返らずに、コマンド文字列にスクリプトのパスを書いて自分で許可を書くことである。変数を組み合わせて名前を作る形・別名・グロブ・別のファイルの中から呼ぶ形など、コマンド文字列に名前が出ない書き方は通ることを許す。スクリプトを経ずに許可の置き場所へ直接書く形は、この要件では見ない（分かりやすい 2 つの書き方は要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」と要件「子は Bash のコマンドで許可の置き場所を名指しできない」が止め、残りは要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲で通ることを許す）。通っても、許可が効くのは使う時点の一時領域の判定（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）を満たす scratchpad の中だけである。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 子がスクリプトを呼ぶと拒否する

- **WHEN** `agent_id` が `a1` の payload に `/x/scripts/git-guard-permit.sh /y/denied/k.json ok` と `bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok` をそれぞれ渡す
- **THEN** どちらも `permissionDecision` が `deny` になる

#### Scenario: 書き方を問わず名前があれば拒否する

- **WHEN** `agent_id` が `a1` の payload に `bash -o errexit /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash --rcfile /x/scripts/git-guard-permit.sh -i`・`zsh -O /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash -c '/x/scripts/git-guard-permit.sh /y/denied/k.json ok'`・`BASH_ENV=/x/scripts/git-guard-permit.sh bash -c true`・`BASH_ENV[0]=/x/scripts/git-guard-permit.sh bash /x/y.sh`・`BASH_ENV+=/x/scripts/git-guard-permit.sh bash /x/y.sh`・`declare -x BASH_ENV=/x/scripts/git-guard-permit.sh; bash /x/y.sh`・`typeset -x ENV=/x/scripts/git-guard-permit.sh; sh -i`・`printf -v BASH_ENV %s /x/scripts/git-guard-permit.sh; export BASH_ENV; bash /x/y.sh`・`read BASH_ENV <<< /x/scripts/git-guard-permit.sh; export BASH_ENV; bash /x/y.sh`・`cat /x/scripts/git-guard-permit.sh` をそれぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 主の呼び出しは止めない

- **WHEN** `agent_id` の無い payload に `/x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`BASH_ENV=/x/scripts/git-guard-permit.sh bash -c true`・`cat /x/scripts/git-guard-permit.sh` をそれぞれ渡す
- **THEN** どれも何も出力しない
