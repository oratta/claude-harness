## Context

待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md` で、「完了を待つ目的でターンを終えてはならない」を禁止の先頭に置いている。名前付き background サブエージェントは idle になっても自分の背景タスクの完了では再起動されず、完了通知はキューに積まれるだけだからである。この禁止の退行は `tests/subagent-waiting.bats` の grep 検査で見ているが、文言検査は既知の固定文字列しか見ない。意味を保った言い換えも、書いてあるのに従わない振る舞いも素通りする（PR #256 のゲート 1・2 周目で non-blocking として合意済みの限界）。

実害は後者で起きている。#509 の実測では、test.sh を背景で起動したサブエージェントが通知待ちでターンを終えて止まった件が 12 PR で 7 件あり、うち 3 件は主が「止まってる？」と聞くまで誰も気づかなかった。worker.md と gate-runner.md には前景ポーリングの指示が既にあるので、文言を足しても減らない。

判定に要る事実は、サブエージェント自身のトランスクリプトと SubagentStop の payload に分かれてある（Claude Code 2.1.283、2026-09-27 に probe (a)(b)(c)(f)(h) の実セッションで確認した。記録は issue #264 のコメント）。

| 事実 | 置き場と形 |
|---|---|
| 背景起動（所有） | サブエージェントのトランスクリプトの `type:"user"` の tool_result 本文 `Command running in background with ID: <id>. Output is being written to: <path>`。`toolUseResult` はサブエージェント側では null で使えない |
| 生死 | SubagentStop の payload の `background_tasks[]`（`id` / `type` / `status` / `description` / `command`）。停止する本人も `type:"subagent"` で入り、本体の shell も入る（probe (f)）＝親セッション全体の台帳。観測できた `status` は `running` だけで、完了・失敗（probe (h)）・TaskStop 後（probe (c)）はどれも配列から消える |
| 終了の通知（判定には使わない） | `completed` / `failed` はトランスクリプトに `<task-notification>` として記録されるが、TaskStop で停止したタスクの `killed` の通知はどこにも書かれない（probe (c)） |

既存の `scripts/context-tripwire.sh` が、hook の payload（`transcript_path` / `session_id` / `agent_id`）からサブエージェント自身のトランスクリプト `<親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` を導出する規則をすでに持っている。

## Goals / Non-Goals

**Goals:**

- サブエージェントが「自分の背景タスクが終わっていないのにターンを終える」瞬間を、文言ではなく実行時に検出して止める
- 止めたときに、何が未完了で次に何をすべきか（前景の待ちループで待つ・正本の場所）を本人に届ける
- 正本の「総待ちの上限に達したら待ちをやめて return する」と矛盾しない。上限到達後の正当な出口（TaskStop で背景タスクを停止してから return する）を正本と spec に足し、hook はその停止を 1 回目で通す
- 正しく待ったサブエージェント（前景で完了を確認してから return する）の停止は 1 回目で通す
- 規約違反の待ち方をわざと行う再現ケースで、`subagent-waiting.bats` は素通りし新しい仕組みは止める差を示す

**Non-Goals:**

- 正本と食い違う待ち値・完了シグナル（`timeout` の値、固定文字列のマーカー等）の実行時検出。受け入れ条件は「ターンを終える振る舞い」と「待ち値・完了シグナル」のどちらか 1 つを求めており、実害の出ている前者を選ぶ。後者は引き続き文言検査が受け持つ
- `codex-companion.mjs` 経路のジョブ（Claude Code の背景タスクではなく、companion が自前で持つ job）の検出。hook からは見えない。この経路のジョブ同一性をどう検査するかは issue #264 のコメントの宿題（companion 経路の評価）で別に扱う
- 正本の雛形の手順 2・3 の実行時検査、雛形抽出の横展開、`$RANDOM` 版の検出。いずれも issue #264 のコメントの宿題で、この change の範囲外。companion 経路の評価と合わせた 4 件は、この change の実装工程で個別の issue に起票し、番号を `plugins/dev-workflow/changes/264.md` と #264 のコメントに残す（tasks 4 章。この change の PR が #264 を閉じても参照先が消えないようにするため）
- `run_in_background` を使わずに Bash の中で `nohup … &` / `setsid` で起こしたプロセス。トランスクリプトに `Command running in background with ID:` の tool_result が残らないので見えない。検査の完了条件は「`run_in_background` の背景タスクを終わらせずに停止すること」を止めることで、見つかった抜け道を塞ぎ切ることではない（spec の守備範囲の段落が正本）
- メインセッションの停止。メインは背景タスクの完了で再起動されるので、通知待ちで止まってよい

## Decisions

### Decision 1: 方式は SubagentStop hook で停止を拒否する

候補と比較:

| 候補 | 何を止めるか | 採否の理由 |
|---|---|---|
| **A. SubagentStop hook が、未完了の自分の背景タスクがある停止を拒否する** | ターンを終える瞬間そのもの | **採用**。7 件の停止の原因をその場で止め、拒否理由で正しい待ち方に誘導できる。起動方法（`run_in_background`）は正本どおり許したまま、禁止されている待ち方だけを止める |
| B. 待ちループをラッパースクリプト（例 `wait-for.sh`）にし、PreToolUse で自前の待ちループを拒否する | 正本と食い違う待ち値・完了シグナル | 不採用。ラッパーを使わずにターンを終える振る舞いは止まらない（7 件はすべてこの形）。自前ループの判定も結局コマンド文字列の検査になり、言い換えに弱いという元の限界を持ち込む |
| C. サブエージェントの `run_in_background` を PreToolUse で拒否する | 背景起動そのもの | 不採用。Codex レビューは前景 1 回（最大 10 分）で終わらないので、正本は背景起動を許している。止めると正しい使い方が壊れる |
| D. 背景起動の直後に PostToolUse で「前景で待て」を注入する | 何も止めない | 不採用。既に書いてある指示をもう 1 回届けるだけで、文言を足すのと同じ |
| E. 本体（親）側で、idle のサブエージェントに未完了タスクがあるかを見張る | 止まった後の救済 | 不採用。本体もサブエージェントの idle では起こされないので、見張りを起動する契機が無い。止める側（A）で足りる |

### Decision 2: 未完了の判定は、所有をトランスクリプト、生死を payload で行う

未完了 = {自分のトランスクリプトの tool_result 本文 `Command running in background with ID: <id>` の id} ∩ {payload `background_tasks` のうち `status:"running"` の id}。`status` が `running` 以外（未知の値を含む）と、配列に無い id は終了したものとして通す。誤りは通す方向に倒す。

- 代替: payload だけで見る → `background_tasks` は親セッション全体の台帳なので、本体の `ci-watch.sh wait` / `epic-dispatch.sh wait` が動いている間、すべてのサブエージェントの停止を拒否してしまう（probe (f) で本体の shell が入ることを確認）。不採用
- 代替: トランスクリプトだけで見る（起動と task-notification の差）→ TaskStop の `killed` の通知が書かれない（probe (c)）ので、TaskStop の tool_result を第 3 の未文書の形式として読む必要が出る。通知の記録が遅れたときの 1 回分の余計な拒否も残る。不採用
- 代替: プロセスの生死を見る → hook からは PID が分からない。出力ファイル（`tasks/<id>.output`）の更新時刻を見る → 出力を出さない長い処理を完了と誤認する。どちらも不採用
- 所有の判定は `type:"user"` の記録の本文に限って拾う。Read の結果などに同じ文字列が入って余計な ID を拾っても、その ID は payload の `background_tasks` に `running` で入っていない限り積集合に残らないので害は無い（拾い過ぎは通す向きの誤りにしかならない）
- トランスクリプトは全体を読む必要がある（起動はずっと前の行にありうる）。python3 に渡す前に `Command running in background with ID` を含む行だけに絞り、5MB で 200ms 未満を満たす（測り方は `tests/context-tripwire.bats` の性能テストと同じく 3 回測って最良値を見る。CI 機での揺れを避けるため）

### Decision 3: 対象トランスクリプトの解決は context-tripwire.sh と同じ規則にする

payload の `agent_id` が無ければ（メインセッション）何もせず停止を通す。あれば、payload に `agent_transcript_path` があればそれを使う（この分岐は context-tripwire.sh には無く、SubagentStop の payload にだけありうるので、この hook 固有のものとして持つ）。無いときは `transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<親>/<session_id>/subagents/agent-<agent_id>.jsonl` を導出し、worktree 隔離で直接パスに無いときは探索する。この導出と探索の上限（深さ・件数・時間）は context-tripwire.sh と同じにする（根拠: `openspec/changes/archive/2026-09-09-subagent-context-tripwire/design.md` の、`transcript_path` が親セッションを指すという実測）。共通の関数を切り出すかどうかは実装時に決めてよいが、context-tripwire.sh の既存テスト（`tests/context-tripwire.bats`）を 1 件も変えずに通すことを条件にする。

### Decision 4: 上限到達後の正当な出口は「TaskStop で停止してから return」にし、拒否回数の上限は後詰めにする

正本の流れでは、サブエージェントは同一ターン内で前景ループを 3 回（27 分）回してから return する。このとき停止を試みるのは 1 回目なので、拒否回数で上限を数えても正本とは両立しない（上限に達したばかりの本人を「前景で待て」と拒否し、従順な G がもう 27 分待つことになる）。そこで正当な出口を 1 つに決める。

- 待ちをやめて return するとき（上限到達・結果の放棄）は、return する前に背景タスクを TaskStop ツール（旧名 KillShell）で停止する。停止でそのタスクが `background_tasks` から消え、hook は Decision 2 の判定だけでその停止を通す。この規則を正本 `subagent-waiting.md` の「総待ちの上限と超過時の分岐」と、既存要件「待ちは前景の有限ループを上限回数まで呼び直す」に足す
- 代替: 背景起動からの経過時間が総待ちの上限を超えたら通す → 上限の 27 分を hook に持ち込むうえ、起動から待ちに入るまでの時間で食い違う。拒否回数だけで数える → 上に書いたとおり正本と衝突する。どちらも不採用
- 拒否回数の上限は、理由文を無視して停止を繰り返すサブエージェントを無限に止め続けないための後詰めとして残す。回数は `${TMPDIR:-/tmp}/dev-workflow-stop-guard/<session_id>-<agent_id>.count` に数え、正本の総待ちの上限回数（3 回）に達した後の停止は通す。通した時点でカウンタファイルを削除する（削除できなくても通す）
- `stop_hook_active` には頼らない（1 回拒否した後の継続中は常に true になり、2 回目の停止を無条件に通すと「9 分待って、まだ終わっていないのにターンを終える」が再び起きる）
- 上限回数は hook 側の定数 1 か所に持ち、bats で正本の記述と突き合わせて食い違いを落とす。理由文に回数（例 `1/3`）が出るのは、この突き合わせがあるので指示書への再掲には当たらない
- 上限を超えて通すときは理由を stderr に 1 行残す。カウンタのファイルが作れない・読めないときは fail-open（停止を通す）

### Decision 5: 拒否の書式と理由文

stdout に `{"decision":"block","reason":"…"}` を出して exit 0 する。理由文には次を必ず含める: 未完了のタスク ID と出力ファイルのパス（tool_result の本文から取れれば）、「完了を待つ目的でターンを終えてはならない。前景の待ちループ（Bash ツールの timeout を指定した until ループ）で完了を確認せよ」、「上限まで待ち終えた・結果を使わないと決めたなら、TaskStop でそのタスクを停止してから終えよ」、正本 `plugins/dev-workflow/references/subagent-waiting.md` の場所、今回が上限回数の何回目か。待ち値・雛形そのものは理由文に書かない（正本 1 本の原則。再掲すると片方だけ古くなる）。

### Decision 6: fail-open と全解除

この hook は install 先の全サブエージェントの停止で走るので、判定できないとき（python3 が無い、payload が壊れている、トランスクリプトが見つからない、読めない）は何も出力せず exit 0 で停止を通す。`DEV_WORKFLOW_STOP_GUARD=off` で全解除する。

### Decision 7: 再現ケースは合成トランスクリプトと実セッションの 2 本

- bats: 背景起動だけがあって終了通知の無い合成トランスクリプトで block が出ること、同じ起動に `completed` の通知を足すと出ないこと
- 文言検査が素通りすることの示し方: プラグインのディレクトリを `BATS_TEST_TMPDIR` に複製し、複製の `worker.md` に言い換えた違反（禁止語を使わずに「背景で起動したら結果の知らせが届くまでいったん手を止める」のように書く）を差し込み、その複製に対して既存の `subagent-waiting.bats` を実際に走らせて exit 0 になることを見る。禁止語のリストは `subagent-waiting.bats` の `@test` の中に直書きされていて外から呼べないが、リストを新しいスイートに写すと 2 か所になって片方だけ古くなるので写さない。代替の「禁止語リストを共有ヘルパーに出して両方が読む」は既存スイートの書き換えを伴い、受け入れ条件の「既存の検査は素通りする」をそのまま見る形でもないので採らない
- 実セッション: `claude -p --plugin-dir plugins/dev-workflow` で、サブエージェントに `sleep` を `run_in_background` で起動させ「完了を待つ」とだけ書いてターンを終えさせる。hook の拒否理由が届いてサブエージェントが前景で待つことを、実行コマンドと出力で issue に貼る

## Risks / Trade-offs

- [正しく前景で待った停止が拒否される／TaskStop 後の停止が拒否される／SubagentStop が名前付き background サブエージェントのターン終了で発火しない・block が効かない] → 解消: probe (a)(b)(c) で実測した（Claude Code 2.1.283。(a) 1 回目拒否・2 回目通過、(b)(c) 1 回目通過）
- [`background_tasks` が文書化された payload 契約かどうか分からず、将来キーが消える・所有者のフィールドが増えるなどの変更がありうる] → キーが無ければ判定を見送って fail-open（stderr に 1 行）。読むのは `id` と `status` だけにし、`type` / `command` には依存しない。実測した版番号を design と `plugins/dev-workflow/changes/264.md` に残し、tasks 5.1 の実セッション再現が壊れたら気づけるようにする
- [`background_tasks` の契約変更でこの検査が黙って無効になる] → 継続的に検知する仕組みは持たない。検知は tasks 5.1 の実セッション再現を版を上げたときに走らせ直すことと、fixture によるピン留め（形の変化は検知できるが、キーそのものが消える変化は fail-open になるので検知できない）に留まる
- [`background_tasks` に本体や兄弟の shell が入ることを前提にしているが、将来サブエージェント固有の配列に変わる可能性がある] → 積集合は所有側（自分のトランスクリプト）で絞るので、配列の範囲が変わっても判定式は変わらない
- [拒否の上限回数と正本の上限回数が食い違う] → hook の定数を bats で正本の記述と突き合わせる。どちらを直すかは正本が先
- [ハーネスの SubagentStop の payload 形式（`agent_id` / `agent_transcript_path` の有無）が将来変わる] → 取れなければ fail-open で停止を通すので、止まるのは検出だけでサブエージェントの作業は止まらない
- [正本と食い違う待ち値・完了シグナルは実行時に止まらない] → Non-Goals のとおり文言検査が受け持つ。受け入れ条件の「どちらか 1 つ」の範囲で、実害の出ている振る舞いを選んだ結果として受け入れる
