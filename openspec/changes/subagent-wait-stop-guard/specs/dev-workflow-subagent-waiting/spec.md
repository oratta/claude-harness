## MODIFIED Requirements

### Requirement: サブエージェントは完了を待つためにターンを終えない
dev-workflow のサブエージェント（W / R1 / G）は、長時間処理（Codex レビュー・フルテスト・ビルド）の完了通知を待つ目的でターンを終えてはならない（MUST NOT）。名前付き background サブエージェントは idle になっても自分の背景タスクの完了では再起動されず、完了通知はキューに積まれるだけで新しいターンを起こさないためである。待ちは同一ターン内の前景ポーリングで行わなければならない（MUST）。Monitor ツールや `run_in_background` の「完了したら続きが動く」挙動に依存してはならない（MUST NOT）。ただし禁止されるのは待ち方であって起動方法ではなく、10 分を超えうる処理を `run_in_background` で起動すること自体は許可される（SHALL）。この禁止はサブエージェントに限られ、背景タスクの完了で再起動されるメインセッションには適用されない（SHALL）。この禁止は手順書の記述だけでなく、要件「未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する」の hook で実行時に守らせる（SHALL）。

#### Scenario: Codex レビューの完了を待つ
- **WHEN** サブエージェントが `run_in_background` で Codex レビューを起動した
- **THEN** そのターンを終えずに、同一ターン内で前景の待ちループを呼んで完了を確認する

#### Scenario: 通知待ちでターンを終えようとする
- **WHEN** サブエージェントが「完了通知を待つ」旨のテキストだけを出してターンを終えようとする
- **THEN** 手順書がそれを禁止しており、自分の背景タスクが未完了なら SubagentStop hook が停止を拒否して前景の待ちループで待つよう理由を返す

## ADDED Requirements

### Requirement: 未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する
dev-workflow プラグインは `scripts/subagent-stop-guard.sh` を `hooks/hooks.json` の `SubagentStop` に登録しなければならない（MUST）。hook は停止しようとしているサブエージェント自身のトランスクリプトを読み、そのサブエージェントが `run_in_background` で起動した背景タスクのうち終了の記録が無いものを未完了として数えなければならない（MUST）。起動は tool_result の `toolUseResult.backgroundTaskId` で、終了は `<task-notification>` の `<task-id>` と `<status>`（`completed` / `failed` / `killed`）で判定する（SHALL）。出力ファイルの更新時刻やプロセスの有無で完了を推定してはならない（MUST NOT）。

未完了が 1 件以上あれば、hook は stdout に `{"decision":"block","reason":"…"}` を出して停止を拒否しなければならない（MUST）。理由文には、未完了のタスク ID（取れれば出力ファイルのパスも）、完了を待つ目的でターンを終えてはならず前景の待ちループで完了を確認すること、正本 `plugins/dev-workflow/references/subagent-waiting.md` の場所、今回が拒否の上限回数の何回目かを含めなければならない（MUST）。待ち値・完了マーカーの雛形を理由文に再掲してはならない（MUST NOT）。

対象トランスクリプトは、payload の `agent_transcript_path` があればそれを使い、無ければ `transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<親>/<session_id>/subagents/agent-<agent_id>.jsonl` を導出する（SHALL）。導出と探索の規則は `scripts/context-tripwire.sh` と同じにする（SHALL）。

#### Scenario: 背景でテストを起動したままターンを終えようとする
- **WHEN** サブエージェントが `run_in_background` で test.sh を起動し、終了の通知が記録される前にターンを終えようとする
- **THEN** hook が停止を拒否し、未完了のタスク ID・前景の待ちループで待つこと・正本の場所を理由として返す

#### Scenario: 背景タスクがすべて終わっている
- **WHEN** サブエージェントが起動した背景タスクすべてに `completed` / `failed` / `killed` の終了通知が記録されている
- **THEN** hook は何も出力せず停止を通す

#### Scenario: 背景タスクを起動していない
- **WHEN** トランスクリプトに `backgroundTaskId` が 1 件も無い
- **THEN** hook は何も出力せず停止を通す

### Requirement: 停止の拒否は正本の総待ちの上限回数までにする
hook は同じサブエージェント（`session_id` と `agent_id` の組）への拒否回数を数え、正本 `subagent-waiting.md` の総待ちの上限回数（前景ループの回数）に達した後の停止は通さなければならない（MUST）。正本の「上限に達したら待ちをやめて本体に return する」と両立させるためである。拒否の判定に `stop_hook_active` を使ってはならない（MUST NOT）— 1 回拒否した後の継続中は常に真になり、2 回目以降の停止を無条件に通してしまうため。hook が持つ上限回数は 1 か所の定数にし、テストで正本の記述と一致することを検査しなければならない（MUST）。上限を超えて通すときは、その旨を stderr に 1 行出す（SHALL）。

#### Scenario: 上限回数まで拒否した後にもう一度止まる
- **WHEN** 同じサブエージェントをすでに上限回数まで拒否しており、未完了の背景タスクを残したままもう一度ターンを終えようとする
- **THEN** hook は停止を通し、上限を超えて通したことを stderr に 1 行出す

#### Scenario: 正本の上限回数を変えた
- **WHEN** 正本の総待ちの上限回数を変えたが、hook の定数を直していない
- **THEN** `scripts/test.sh` が失敗し、hook の定数を正本に合わせるよう示す

### Requirement: 停止の拒否はサブエージェントに限り、判定できなければ通す
hook は payload に `agent_id` が無い停止（メインセッション）に対して何も出力してはならない（MUST NOT）。python3 が無い・payload が壊れている・対象トランスクリプトが見つからないか読めない・拒否回数のファイルが作れないか読めないときは、何も出力せず exit 0 で停止を通さなければならない（MUST）。環境変数 `DEV_WORKFLOW_STOP_GUARD=off` のときは判定をせずに停止を通す（SHALL）。この hook は install 先の全サブエージェントの停止で走るため、5MB のトランスクリプトでも 200ms 未満で終えなければならない（MUST）。

#### Scenario: メインセッションが通知待ちで止まる
- **WHEN** `agent_id` の無い payload で hook が呼ばれる
- **THEN** hook は何も出力せず exit 0 で終わる

#### Scenario: トランスクリプトが見つからない
- **WHEN** 導出したパスにも探索範囲にも対象トランスクリプトが無い
- **THEN** hook は何も出力せず exit 0 で停止を通す

#### Scenario: 全解除
- **WHEN** `DEV_WORKFLOW_STOP_GUARD=off` が設定されている
- **THEN** 未完了の背景タスクがあっても hook は停止を通す

### Requirement: 実行時の検査が文言検査の素通りする違反を止めることを再現ケースで示す
`tests/subagent-stop-guard.bats` は、規約違反の待ち方（背景起動の後に終了通知を待たずにターンを終える）を表す合成トランスクリプトで hook が停止を拒否することを検査しなければならない（MUST）。あわせて、同じ違反を言い換えて指示書に書いた形を `subagent-waiting.bats` の文言検査が検出しないことを、同じスイートで対にして示さなければならない（MUST）。実セッションでの再現（`claude -p --plugin-dir` で背景 `sleep` を起動してターンを終えるサブエージェントに拒否理由が届くこと）は、実行コマンドと出力を記録先に添付する（SHALL）。

#### Scenario: 文言検査は素通りし、実行時の検査は止める
- **WHEN** 待ちでターンを終える指示を、禁止語を使わずに言い換えて書いた文書と、その指示どおりに動いたトランスクリプトを用意する
- **THEN** `subagent-waiting.bats` の禁止語検査はその文書を検出せず、`subagent-stop-guard.sh` はそのトランスクリプトでの停止を拒否する

#### Scenario: hooks.json の登録
- **WHEN** `hooks/hooks.json` を読む
- **THEN** `SubagentStop` に `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-stop-guard.sh` が登録されており、既存の SessionStart / UserPromptSubmit / PreToolUse / PostToolUse のエントリは変わっていない
