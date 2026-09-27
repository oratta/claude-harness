## 1. 着手前の実測（方式が成り立つかの確認）

- [ ] 1.1 `claude -p --plugin-dir` の実セッションで、名前付き background サブエージェントのターン終了で SubagentStop が発火することと、`{"decision":"block","reason":…}` でターン終了が取り消されて理由が本人に届くことを、最小の hook（payload を記録して block を返すだけ）で確かめる。payload に `agent_id` / `agent_transcript_path` / `session_id` / `transcript_path` / `stop_hook_active` のどれが入るかも記録する
- [ ] 1.2 1.1 で発火しない・block が効かない場合は実装に進まず、実行コマンドと出力を添えて本体に return する（方式の選び直しは本体が決める）

## 2. テストを先に書く（Red）

- [ ] 2.1 `plugins/dev-workflow/tests/subagent-stop-guard.bats` を作り、合成トランスクリプトを組む補助関数を置く（背景起動の tool_result・`<task-notification>` の attachment を 1 行ずつ足せる形。context-tripwire.bats の組み方に合わせる）
- [ ] 2.2 未完了の背景タスクがあると block が出て、理由にタスク ID・前景の待ちループ・正本のパス・上限回数の何回目かが入ること
- [ ] 2.3 すべての背景タスクに `completed` / `failed` / `killed` の通知がある、または背景起動が無いときは何も出力しないこと
- [ ] 2.4 同じ `session_id`+`agent_id` を上限回数まで拒否した後の停止は通り、stderr に 1 行出ること。別の `agent_id` は独立に数えること。`stop_hook_active: true` でも回数内なら拒否すること
- [ ] 2.5 hook の上限回数の定数が正本 `references/subagent-waiting.md` の総待ちの上限回数と一致すること
- [ ] 2.6 `agent_id` が無い・python3 が無い・payload が壊れている・トランスクリプトが無い・カウンタのディレクトリが作れない・`DEV_WORKFLOW_STOP_GUARD=off` のとき、何も出力せず exit 0 になること
- [ ] 2.7 `agent_transcript_path` があればそれを使い、無ければ `<親>/<session_id>/subagents/agent-<agent_id>.jsonl`、それも無ければ worktree 隔離の探索で見つけること
- [ ] 2.8 5MB の合成トランスクリプトで 200ms 未満に終わること
- [ ] 2.9 hooks.json の `SubagentStop` に登録されており、既存エントリが変わっていないこと
- [ ] 2.10 言い換えた違反の文書は `subagent-waiting.bats` の禁止語検査で検出されず、その指示どおりのトランスクリプトは hook が拒否すること（対にして示す）

## 3. 実装（Green）

- [ ] 3.1 `plugins/dev-workflow/scripts/subagent-stop-guard.sh` を実装する（bash の前段で全解除と `agent_id` の有無を切り、判定は python3。対象行を先に絞ってから JSON を読む。fail-open）
- [ ] 3.2 対象トランスクリプトの導出を context-tripwire.sh と同じ規則にする。共通化する場合は `tests/context-tripwire.bats` を 1 件も変えずに通す
- [ ] 3.3 `plugins/dev-workflow/hooks/hooks.json` に `SubagentStop` のエントリを追加する
- [ ] 3.4 2 章のテストがすべて通ることを確かめる

## 4. 正本と記録

- [ ] 4.1 `plugins/dev-workflow/references/subagent-waiting.md` に、実行時の検査（SubagentStop hook が何を見て何を止めるか・拒否の上限回数は総待ちの上限回数と同じ・全解除の環境変数）の 1 節を足す。指示書（W / R1 / G・pr-review-gate の SKILL.md）には再掲しない
- [ ] 4.2 `plugins/dev-workflow/changes/264.md` に変更の記録を書く（版は上げない）

## 5. 実セッションでの再現と検査

- [ ] 5.1 `claude -p --plugin-dir plugins/dev-workflow` で、サブエージェントに `sleep` を `run_in_background` で起動させ「完了を待つ」とだけ書いてターンを終えさせる。hook の拒否理由が届き、サブエージェントが前景で待ってから終わることを、実行コマンドと出力で issue #264 に添付する
- [ ] 5.2 `.github/workflows/` の `pull_request` / `push` の検査コマンドをすべて実行し、`scripts/test.sh` が exit 0 であることを確かめる
