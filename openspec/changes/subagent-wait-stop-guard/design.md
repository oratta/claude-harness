## Context

待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md` で、「完了を待つ目的でターンを終えてはならない」を禁止の先頭に置いている。名前付き background サブエージェントは idle になっても自分の背景タスクの完了では再起動されず、完了通知はキューに積まれるだけだからである。この禁止の退行は `tests/subagent-waiting.bats` の grep 検査で見ているが、文言検査は既知の固定文字列しか見ない。意味を保った言い換えも、書いてあるのに従わない振る舞いも素通りする（PR #256 のゲート 1・2 周目で non-blocking として合意済みの限界）。

実害は後者で起きている。#509 の実測では、test.sh を背景で起動したサブエージェントが通知待ちでターンを終えて止まった件が 12 PR で 7 件あり、うち 3 件は主が「止まってる？」と聞くまで誰も気づかなかった。worker.md と gate-runner.md には前景ポーリングの指示が既にあるので、文言を足しても減らない。

トランスクリプトには判定に要る事実がそろっている（2026-09-27 に既存のサブエージェントのトランスクリプトで確認した）。

| 事実 | トランスクリプト上の形 |
|---|---|
| 背景起動 | `type:"user"` の tool_result の `toolUseResult.backgroundTaskId`（例 `b79x2e2ts`）。本文は `Command running in background with ID: <id>. Output is being written to: <path>` |
| 終了 | `type:"attachment"`（または `user`）の本文に `<task-notification>` … `<task-id><id></task-id>` … `<status>completed|failed|killed</status>` |

既存の `scripts/context-tripwire.sh` が、hook の payload（`transcript_path` / `session_id` / `agent_id`）からサブエージェント自身のトランスクリプト `<親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` を導出する規則をすでに持っている。

## Goals / Non-Goals

**Goals:**

- サブエージェントが「自分の背景タスクが終わっていないのにターンを終える」瞬間を、文言ではなく実行時に検出して止める
- 止めたときに、何が未完了で次に何をすべきか（前景の待ちループで待つ・正本の場所）を本人に届ける
- 正本の「総待ちの上限に達したら待ちをやめて return する」と矛盾しない（無限に止め続けない）
- 規約違反の待ち方をわざと行う再現ケースで、`subagent-waiting.bats` は素通りし新しい仕組みは止める差を示す

**Non-Goals:**

- 正本と食い違う待ち値・完了シグナル（`timeout` の値、固定文字列のマーカー等）の実行時検出。受け入れ条件は「ターンを終える振る舞い」と「待ち値・完了シグナル」のどちらか 1 つを求めており、実害の出ている前者を選ぶ。後者は引き続き文言検査が受け持つ
- `codex-companion.mjs` 経路のジョブ（Claude Code の背景タスクではなく、companion が自前で持つ job）の検出。hook からは見えない。この経路のジョブ同一性をどう検査するかは issue #264 のコメントの宿題（companion 経路の評価）で別に扱う
- 正本の雛形の手順 2・3 の実行時検査、雛形抽出の横展開、`$RANDOM` 版の検出。いずれも issue #264 のコメントの宿題で、この change の範囲外
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

### Decision 2: 未完了の判定はトランスクリプトの記録で行う

「起動した背景タスクの ID の集合」から「終了通知の記録がある ID の集合」を引き、残りを未完了とする。起動の ID は tool_result の `toolUseResult.backgroundTaskId`、終了は `<task-notification>` の `<task-id>` と `<status>`（`completed` / `failed` / `killed` のいずれか）で取る。

- 代替: プロセスの生死を見る → hook からは PID が分からない。出力ファイル（`tasks/<id>.output`）の更新時刻を見る → 出力を出さない長い処理（`sleep` や無言のテスト）を完了と誤認する。どちらも不採用
- 終了通知がキューに積まれたままトランスクリプトに書かれていない場合、実際には完了済みのタスクを未完了と判定することがある。この場合も拒否理由に従って前景で待てば、待ちループはすぐに成立するので害は 1 ターン分で済む（落ちずに間違う方向ではなく、余計に 1 回確かめる方向の誤り）
- トランスクリプトは全体を読む必要がある（起動はずっと前の行にありうる）。python3 に渡す前に `backgroundTaskId` か `task-notification` を含む行だけに絞り、5MB で 200ms 未満を満たす

### Decision 3: 対象トランスクリプトの解決は context-tripwire.sh と同じ規則にする

payload の `agent_id` が無ければ（メインセッション）何もせず停止を通す。あれば、payload に `agent_transcript_path` があればそれを使い、無ければ `transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<親>/<session_id>/subagents/agent-<agent_id>.jsonl` を導出する。worktree 隔離で直接パスに無いときの探索（深さ・件数・時間の上限つき）も context-tripwire.sh と同じ条件にする。共通の関数を切り出すかどうかは実装時に決めてよいが、context-tripwire.sh の既存テスト（`tests/context-tripwire.bats`）を 1 件も変えずに通すことを条件にする。

### Decision 4: 拒否は同じサブエージェントにつき上限回数まで

`stop_hook_active` には頼らない（1 回拒否した後の継続中は常に true になり、2 回目の停止を無条件に通すと「9 分待って、まだ終わっていないのにターンを終える」が再び起きる）。代わりに、拒否した回数を `${TMPDIR:-/tmp}/dev-workflow-stop-guard/<session_id>-<agent_id>.count` に数え、正本の総待ちの上限回数（前景ループ 3 回）に達した後の停止は通す。

- 上限回数は正本の「上限は前景ループ 3 回」と一致させる。hook 側は定数 1 か所に持ち、bats で正本の記述と突き合わせて食い違いを落とす
- 上限を超えて通した停止は、正本どおり「待ちをやめて本体に return する」ことに当たる。ただし通すときも理由を stderr に 1 行残す（hook のログで後から追える）
- カウンタのファイルが作れない・読めないときは fail-open（停止を通す）

### Decision 5: 拒否の書式と理由文

stdout に `{"decision":"block","reason":"…"}` を出して exit 0 する。理由文には次を必ず含める: 未完了のタスク ID と出力ファイルのパス（tool_result の本文から取れれば）、「完了を待つ目的でターンを終えてはならない。前景の待ちループ（Bash ツールの timeout を指定した until ループ）で完了を確認せよ」、正本 `plugins/dev-workflow/references/subagent-waiting.md` の場所、今回が上限回数の何回目か。待ち値・雛形そのものは理由文に書かない（正本 1 本の原則。再掲すると片方だけ古くなる）。

### Decision 6: fail-open と全解除

この hook は install 先の全サブエージェントの停止で走るので、判定できないとき（python3 が無い、payload が壊れている、トランスクリプトが見つからない、読めない）は何も出力せず exit 0 で停止を通す。`DEV_WORKFLOW_STOP_GUARD=off` で全解除する。

### Decision 7: 再現ケースは合成トランスクリプトと実セッションの 2 本

- bats: 背景起動だけがあって終了通知の無い合成トランスクリプトで block が出ること、同じ起動に `completed` の通知を足すと出ないこと。あわせて、同じ規約違反を指示書に書いた形（言い換え）で `subagent-waiting.bats` の検査が落ちないことを並べて示す
- 実セッション: `claude -p --plugin-dir plugins/dev-workflow` で、サブエージェントに `sleep` を `run_in_background` で起動させ「完了を待つ」とだけ書いてターンを終えさせる。hook の拒否理由が届いてサブエージェントが前景で待つことを、実行コマンドと出力で issue に貼る

## Risks / Trade-offs

- [SubagentStop が、名前付き background サブエージェントの idle 化（ターン終了）で発火しない、または block がこの種別で効かない可能性がある。公式の記述は「サブエージェントが応答を終えたとき」で、名前付き・SendMessage 再開型での挙動を確かめた記録がまだ無い] → tasks の最初に実セッションでの発火と block の効きを確かめる。効かなければ実装に進まず、実測を添えて本体に return する（方式の選び直しは本体が決める）
- [完了済みのタスクを通知の未記録で未完了と判定する] → Decision 2 のとおり、害は前景の待ちが即座に成立する 1 回分で止まる
- [拒否の上限回数と正本の上限回数が食い違う] → hook の定数を bats で正本の記述と突き合わせる。どちらを直すかは正本が先
- [ハーネスの SubagentStop の payload 形式（`agent_id` / `agent_transcript_path` の有無）が将来変わる] → 取れなければ fail-open で停止を通すので、止まるのは検出だけでサブエージェントの作業は止まらない
- [正本と食い違う待ち値・完了シグナルは実行時に止まらない] → Non-Goals のとおり文言検査が受け持つ。受け入れ条件の「どちらか 1 つ」の範囲で、実害の出ている振る舞いを選んだ結果として受け入れる
