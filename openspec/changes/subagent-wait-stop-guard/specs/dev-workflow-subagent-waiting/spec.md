## MODIFIED Requirements

### Requirement: サブエージェントは完了を待つためにターンを終えない
dev-workflow のサブエージェント（W / R1 / G）は、長時間処理（Codex レビュー・フルテスト・ビルド）の完了通知を待つ目的でターンを終えてはならない（MUST NOT）。名前付き background サブエージェントは idle になっても自分の背景タスクの完了では再起動されず、完了通知はキューに積まれるだけで新しいターンを起こさないためである。待ちは同一ターン内の前景ポーリングで行わなければならない（MUST）。Monitor ツールや `run_in_background` の「完了したら続きが動く」挙動に依存してはならない（MUST NOT）。ただし禁止されるのは待ち方であって起動方法ではなく、10 分を超えうる処理を `run_in_background` で起動すること自体は許可される（SHALL）。この禁止はサブエージェントに限られ、背景タスクの完了で再起動されるメインセッションには適用されない（SHALL）。この禁止は手順書の記述だけでなく、要件「未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する」の hook で実行時に守らせる（SHALL）。

#### Scenario: Codex レビューの完了を待つ
- **WHEN** サブエージェントが `run_in_background` で Codex レビューを起動した
- **THEN** そのターンを終えずに、同一ターン内で前景の待ちループを呼んで完了を確認する

#### Scenario: 通知待ちでターンを終えようとする
- **WHEN** サブエージェントが「完了通知を待つ」旨のテキストだけを出してターンを終えようとする
- **THEN** 手順書がそれを禁止しており、自分の背景タスクが未完了なら SubagentStop hook が停止を拒否して前景の待ちループで待つよう理由を返す

### Requirement: 待ちは前景の有限ループを上限回数まで呼び直す
待ちループは Bash ツール呼び出しの `timeout` パラメータを明示した前景実行の中で、終了条件を持つ有限ループ（例: `until <完了シグナル>; do sleep <間隔>; done`）として書かなければならない（MUST）。1 回の呼び出しで完了しなければ、同じ呼び出しをもう一度発行して待ちを継続する（SHALL。1 回の Bash 呼び出しはターンの終わりではない）。行頭の裸の長時間 `sleep` は使わない（MUST NOT）が、ループ内の `sleep` は許可対象である。

**総待ちには上限を設けなければならない（MUST）。** 既定は前景ループ 3 回（540000 ms × 3 = 27 分）とする。上限に達しても完了しない場合は待ちをやめ、経路ごとの分岐に入らなければならない（MUST）。G は `needs-reviewer` を return し、根拠に「Codex タイムアウト（27 分）」と書く。これは `skills/pr-review-gate/SKILL.md` のフォールバック条件「未導入・サブスク切れ・タイムアウト」の「タイムアウト」の定義であり、この上限がフォールバックの発火点になる（SHALL）。W / R1 は待ちをやめて本体に return する。上限なしに待ち続けてはならない（MUST NOT。ジョブが死んで出力が来ない場合と、単に時間がかかっている場合を区別できなくなるため）。

**待ちをやめて return するとき（上限到達のほか、背景タスクの結果を使わないと決めて放棄するときも含む）は、return する前にその背景タスクを TaskStop ツール（旧名 KillShell）で停止しなければならない（MUST）。** 停止するとそのタスクは SubagentStop の payload `background_tasks` から消えるので、要件「未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する」の hook がその停止を通す。これが上限到達後の正当な出口であり、停止せずに return しようとすると hook に拒否される。return には停止したタスクと、どこまで待ったかを書く（SHALL）。

#### Scenario: 1 回の待ちで完了しない
- **WHEN** 前景の待ちループがタイムアウトしても対象の処理が終わっていない
- **THEN** 同じ待ちループをもう一度呼び出し、ターンは継続したままである

#### Scenario: 上限回数まで待っても完了しない
- **WHEN** 前景ループを 3 回（合計 27 分）呼んでも完了シグナルが現れない
- **THEN** 待ちをやめ、背景タスクを TaskStop で停止してから、G は `needs-reviewer`（根拠に「Codex タイムアウト（27 分）」）を return し、W / R1 は本体に return する。停止の hook はこの return を 1 回目で通す

#### Scenario: 待ちに入る前の告知
- **WHEN** サブエージェントが長い待ちループに入る
- **THEN** これから最大何分待つか（1 回あたり 9 分・上限 27 分）を出力してからループに入る

## ADDED Requirements

### Requirement: 未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する
dev-workflow プラグインは `scripts/subagent-stop-guard.sh` を `hooks/hooks.json` の `SubagentStop` に登録しなければならない（MUST）。hook は、停止しようとしているサブエージェント自身のトランスクリプトから自分が `run_in_background` で起動した背景タスクの ID を集め（所有の判定）、SubagentStop の payload `background_tasks` にその ID が `status:"running"` で残っているものを未完了として数えなければならない（MUST）。起動の ID は Bash ツールの tool_result 本文 `Command running in background with ID: <id>.` から取る（SHALL。サブエージェント側のトランスクリプトでは `toolUseResult` が null で使えない、2026-09-27 の実測）。自分のトランスクリプトに起動の記録が無い ID は、`background_tasks` に `running` で残っていても数えない（MUST NOT。配列は親セッション全体の台帳で、本体や他のサブエージェントの背景タスクも入る）。`status` が `running` 以外の値、および配列に無い ID は終了したものとして通す（SHALL）。出力ファイルの更新時刻やプロセスの有無で完了を推定してはならない（MUST NOT）。

**守備範囲。** この検査は次の範囲だけを受け持つ（SHALL）。
- 入力の出どころ: 停止しようとしているサブエージェント自身のトランスクリプト（Claude Code が書く JSONL）と、SubagentStop の payload（`background_tasks` の `id` と `status` だけを読む）
- 拾う誤り: Bash ツールの `run_in_background` で起動した背景タスクが `background_tasks` に `running` で残ったまま停止すること、の 1 つだけ。本体や兄弟のサブエージェントの背景タスクは所有の判定で外れるので、この誤りに含まれない
- 通す入力の例: 背景起動が無い停止／起動したすべてのタスクが `background_tasks` から消えている、または `status` が `running` でない停止（上限到達後に TaskStop で停止してから return する停止を含む）／メインセッション（`agent_id` が無い）／python3 が無い・payload が壊れている・payload に `background_tasks` が無い・トランスクリプトが見つからない／`DEV_WORKFLOW_STOP_GUARD=off`
- 守らないもの: `run_in_background` を使わず Bash の中で `nohup … &` や `setsid` で起こしたプロセス（tool_result に `Command running in background with ID:` が記録されない）／`codex-companion.mjs` の job／正本と食い違う待ち値・完了シグナル（文言検査が受け持つ）／拒否の上限回数まで理由を無視して停止を繰り返したサブエージェント／payload に `background_tasks` を持たない版の Claude Code（この版では判定を見送る）

新しい抜け道が見つかっても、この要件の完了条件は「拾う誤り」に挙げた 1 つを止めることであり、抜け道を塞ぎ切ることではない（SHALL）。守らないものに当たる指摘は、この要件の範囲外として扱う。

未完了が 1 件以上あれば、hook は stdout に `{"decision":"block","reason":"…"}` を出して停止を拒否しなければならない（MUST）。理由文には、未完了のタスク ID（取れれば出力ファイルのパスも）、完了を待つ目的でターンを終えてはならず前景の待ちループで完了を確認すること、**上限まで待ち終えた・結果を使わないと決めたなら TaskStop でそのタスクを停止してから終えること**、正本 `plugins/dev-workflow/references/subagent-waiting.md` の場所、今回が拒否の上限回数の何回目か（例 `1/3`）を含めなければならない（MUST）。待ち値・完了マーカーの雛形を理由文に再掲してはならない（MUST NOT）。拒否の回数表記は、hook の定数を正本とテストで突き合わせているので、指示書への再掲には当たらない（SHALL）。

対象トランスクリプトは、payload に `agent_transcript_path` があればそれを使う（SHALL）。無いときは `transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<親>/<session_id>/subagents/agent-<agent_id>.jsonl` を導出し、そこに無ければ worktree 隔離のための探索を行う。この導出と探索の上限（深さ・件数・時間）は `scripts/context-tripwire.sh` と同じにする（SHALL）。

#### Scenario: 背景でテストを起動したままターンを終えようとする
- **WHEN** サブエージェントが `run_in_background` で test.sh を起動し、そのタスクが `background_tasks` に `running` で残ったままターンを終えようとする
- **THEN** hook が停止を拒否し、未完了のタスク ID・前景の待ちループで待つこと・上限まで待ったなら TaskStop で停止してから終えること・正本の場所・拒否の回数を理由として返す

#### Scenario: 背景タスクがすべて終わっている
- **WHEN** サブエージェントが起動した背景タスクがすべて `background_tasks` に無い、または `status` が `running` でない
- **THEN** hook は何も出力せず停止を通す

#### Scenario: 上限まで待ってから停止して return する
- **WHEN** 前景ループを上限回数まで回しても完了せず、サブエージェントが背景タスクを TaskStop で停止してから return する
- **THEN** TaskStop で停止したタスクは `background_tasks` から消えているので、hook は 1 回目の停止で通す

#### Scenario: 背景タスクを起動していない
- **WHEN** トランスクリプトに `Command running in background with ID:` を含む tool_result が 1 件も無い
- **THEN** hook は何も出力せず停止を通す

#### Scenario: 本体の背景タスクが動いている
- **WHEN** 本体が `ci-watch.sh wait` を `run_in_background` で起動しており、背景起動をしていないサブエージェントが停止する（`background_tasks` に本体の shell が `running` で入っている）
- **THEN** 自分の起動記録が無いので hook は何も出力せず停止を通す

#### Scenario: 範囲外の抜け道を指摘された
- **WHEN** Bash の中で `nohup … &` で起こしたプロセスを残したまま停止すると hook を通る、と指摘される
- **THEN** 守備範囲の「守らないもの」に当たるので、この要件の範囲外として扱い、塞ぐことを完了条件にしない

### Requirement: 停止の拒否は上限回数までの後詰めにする
正当な出口は「前景で完了まで待つ」か「TaskStop で停止してから終える」であり、hook の拒否回数の上限は、理由文を無視して停止を繰り返すサブエージェントを無限に止め続けないための後詰めである（SHALL）。hook は同じサブエージェント（`session_id` と `agent_id` の組）への拒否回数を `${TMPDIR:-/tmp}/dev-workflow-stop-guard/<session_id>-<agent_id>.count` に数え、正本 `subagent-waiting.md` の総待ちの上限回数（前景ループの回数）に達した後の停止は通さなければならない（MUST）。上限に達して通した時点でそのカウンタファイルを削除する（SHALL。削除できなくても停止は通す）。拒否の判定に `stop_hook_active` を使ってはならない（MUST NOT）— 1 回拒否した後の継続中は常に真になり、2 回目以降の停止を無条件に通してしまうため。hook が持つ上限回数は 1 か所の定数にし、テストで正本の記述と一致することを検査しなければならない（MUST）。上限を超えて通すときは、その旨を stderr に 1 行出す（SHALL）。

#### Scenario: 上限回数まで拒否した後にもう一度止まる
- **WHEN** 同じサブエージェントをすでに上限回数まで拒否しており、未完了の背景タスクを残したままもう一度ターンを終えようとする
- **THEN** hook は停止を通し、上限を超えて通したことを stderr に 1 行出し、カウンタファイルを削除する

#### Scenario: 正本の上限回数を変えた
- **WHEN** 正本の総待ちの上限回数を変えたが、hook の定数を直していない
- **THEN** `scripts/test.sh` が失敗し、hook の定数を正本に合わせるよう示す

### Requirement: 停止の拒否はサブエージェントに限り、判定できなければ通す
hook は payload に `agent_id` が無い停止（メインセッション）に対して何も出力してはならない（MUST NOT）。python3 が無い・payload が壊れている・payload に `background_tasks` が無い・対象トランスクリプトが見つからないか読めない・拒否回数のファイルが作れないか読めないときは、stdout に何も出力せず exit 0 で停止を通さなければならない（MUST）。その場合は stderr に判定を見送った旨を 1 行出してよい（SHALL）。環境変数 `DEV_WORKFLOW_STOP_GUARD=off` のときは判定をせずに停止を通す（SHALL）。この hook は install 先の全サブエージェントの停止で走るため、5MB のトランスクリプトで 200ms 未満で終えなければならない（MUST）。測り方は `tests/context-tripwire.bats` の性能テストと同じく複数回（3 回）測って最良値を見る（SHALL）。

#### Scenario: メインセッションが通知待ちで止まる
- **WHEN** `agent_id` の無い payload で hook が呼ばれる
- **THEN** hook は何も出力せず exit 0 で終わる

#### Scenario: トランスクリプトが見つからない
- **WHEN** 導出したパスにも探索範囲にも対象トランスクリプトが無い
- **THEN** hook は何も出力せず exit 0 で停止を通す

#### Scenario: payload に background_tasks が無い
- **WHEN** 旧い・異なる版の Claude Code で payload に `background_tasks` キーが無い
- **THEN** hook は判定を見送り、stdout に何も出さず exit 0 で通す。stderr に見送った旨を 1 行出す

#### Scenario: 全解除
- **WHEN** `DEV_WORKFLOW_STOP_GUARD=off` が設定されている
- **THEN** 未完了の背景タスクがあっても hook は停止を通す

### Requirement: 実行時の検査が文言検査の素通りする違反を止めることを再現ケースで示す
`tests/subagent-stop-guard.bats` は、規約違反の待ち方（背景起動の後に終了通知を待たずにターンを終える）を表す合成トランスクリプトで hook が停止を拒否することを検査しなければならない（MUST）。あわせて、同じ違反を言い換えて指示書に書いた形を `subagent-waiting.bats` の文言検査が検出しないことを、同じスイートで対にして示さなければならない（MUST）。後者は、プラグインのディレクトリを `BATS_TEST_TMPDIR` に複製し、複製の `skills/develop/references/roles/worker.md` に言い換えた違反を差し込み、その複製に対して既存の `subagent-waiting.bats` を実際に実行して exit 0 になることで示す（SHALL）。禁止語のリストを新しいスイートに写してはならない（MUST NOT。2 か所になると片方だけ古くなる）。実セッションでの再現（`claude -p --plugin-dir` で背景 `sleep` を起動してターンを終えるサブエージェントに拒否理由が届くこと）は、実行コマンドと出力を記録先に添付する（SHALL）。

#### Scenario: 文言検査は素通りし、実行時の検査は止める
- **WHEN** 待ちでターンを終える指示を禁止語を使わずに言い換えて複製の worker.md に差し込み、その指示どおりに動いたトランスクリプトを用意する
- **THEN** 複製に対して走らせた `subagent-waiting.bats` は exit 0 で、`subagent-stop-guard.sh` はそのトランスクリプトでの停止を拒否する

#### Scenario: hooks.json の登録
- **WHEN** `hooks/hooks.json` を読む
- **THEN** `SubagentStop` に `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-stop-guard.sh` が登録されており、既存の SessionStart / UserPromptSubmit / PreToolUse / PostToolUse のエントリは変わっていない
