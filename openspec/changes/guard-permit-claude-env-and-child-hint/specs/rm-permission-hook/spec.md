## MODIFIED Requirements
### Requirement: 子の rm の確認画面に、親の許可に従って答える

`plugins/dev-workflow/hooks/hooks.json` は `PermissionRequest`（matcher `Bash`）に `plugins/dev-workflow/scripts/rm-permission-guard.sh` を登録しなければならない（MUST）。hook は payload の `agent_id` が空でない文字列（サブエージェントの呼び出し）で、かつ `tool_input.command` が要件「rm の一時領域の判定」の入口の形（単純コマンドのどれかの先頭の語が `rm`）に当たるときだけ答えなければならない（MUST）。それ以外は何も出力せず exit 0 で終わらなければならない（MUST。主の呼び出し・`agent_id` が無い・空・文字列でない呼び出し・`rm` を含まない Bash の確認・読めない payload・`python3` が無い場合を含む。確認画面または今までの拒否に任せる）。

答え方は次のとおり。hook は `session_id`・`agent_id`・`cwd`・`tool_input.command` から、要件「子への拒否を記録し、親が 1 回だけ通せるようにする」（spec destructive-git-hook）と同じ規則で key を計算し、同じ `<base>/permits/<key>.json` を自分だけが使えるように `rename` で取って読む（`<base>` は `${TMPDIR:-/tmp}/dev-workflow-git-guard`）。許可の 4 つの値が payload と一致し、期限内で、使う時点の rm の一時領域の判定をその時点のファイルシステムで満たすときに限り、`hookSpecificOutput.decision.behavior` を `allow` にして、取った許可を消し、`permit-log.jsonl` に `event` が `use` の行を足さなければならない（MUST）。許可が無い・一致しない・期限切れ・判定を満たさない・判定のファイルを読めないときは `behavior` を `deny` にし、`message` に次を含めなければならない（MUST）: このコマンドは親の許可が無いので実行しなかったこと／何を（コマンド）・なぜ消したかったかを報告に書いて親に返すこと／同じコマンドを打ち直さないこと／親の許可を受けられるのは、変数・`;`・`&&` を使わず実パスで単独のコマンドとして打った拒否だけで、それ以外の形の拒否は親が許可を書けず主に上がること（1 文で書く。文字列「実パスで単独のコマンド」を含む）／拒否の記録を作れたときはそのパス（作れなかったとき、つまり判定のファイルを読めない・記録を書けないときは、パスの代わりに「拒否の記録を作れなかった」ことと、親に報告するときはコマンドの全文を書くこと）。許可があるが判定を満たさなかったときは「許可はあるが行き先を確かめられない」も含める。判定のファイルを読めたときは key を出せるので、deny のたびに拒否の記録を `<base>/denied/<key>.json` に（`kinds` を `["rm"]` として）書く。判定のファイルを読めないときは key を出せないので許可を探さず記録も書かず、記録を書けなかったときも、deny は返す（どちらも message はパスを示さない）。回数を数えての打ち切りはしない。

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

#### Scenario: 子への deny の message に許可を受けられる打ち方が 1 文で書かれている

- **WHEN** `agent_id` が `a1` で許可の無い payload に `rm -rf <scratchpad>/tbl/*` を渡す
- **THEN** `message` に「実パスで単独のコマンド」と「変数」が含まれる
