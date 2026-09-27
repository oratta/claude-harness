## 1. 着手前の実測（方式が成り立つかの確認）

- [ ] 1.1 `claude -p --plugin-dir` の実セッションで、最小の hook（payload とその時点のサブエージェントのトランスクリプトの末尾を記録し、block を返すかを切り替えられるだけのもの）を SubagentStop に置き、次の 4 点を記録する（実行コマンドと出力を残す）
  - (a) 名前付き background サブエージェントのターン終了で SubagentStop が発火し、`{"decision":"block","reason":…}` でターン終了が取り消されて理由が本人に届くこと
  - (b) 正常系: 背景で `sleep 5` を起動し、前景の待ちループで完了まで待ってから終えるサブエージェントの停止の時点で、`completed` の task-notification がトランスクリプトに既に書かれていること（＝判定どおりなら停止が 1 回目に通ること）
  - (c) 背景で長い `sleep` を起動し、TaskStop（旧名 KillShell）で停止してから終えるサブエージェントの停止の時点で、`<status>killed</status>` の task-notification がトランスクリプトに書かれていること
  - (d) payload に `agent_id` / `agent_transcript_path` / `session_id` / `transcript_path` / `stop_hook_active` のどれが入るか
- [ ] 1.2 次のいずれかに当たったら実装に進まず、1.1 の実行コマンドと出力を添えて本体に return する（方式の選び直しや、通知が未記録のときは拒否せず注意だけ出す等の代案は本体が決める）: (a) 発火しない・block が効かない／(b) 正常系の停止が 1 回目に通らない／(c) TaskStop 後に `killed` の通知が書かれない

## 2. テストを先に書く（Red）

- [ ] 2.1 `plugins/dev-workflow/tests/subagent-stop-guard.bats` を作り、合成トランスクリプトを組む補助関数を置く（背景起動の tool_result・`<task-notification>` の attachment を 1 行ずつ足せる形。context-tripwire.bats の組み方に合わせる）
- [ ] 2.2 未完了の背景タスクがあると block が出て、理由にタスク ID・前景の待ちループで待つこと・上限まで待ったなら TaskStop で停止してから終えること・正本のパス・拒否の回数（例 `1/3`）が入ること。待ち値・完了マーカーの雛形が入らないこと
- [ ] 2.3 すべての背景タスクに `completed` / `failed` / `killed` の通知がある、または背景起動が無いときは何も出力しないこと。`killed` だけで終わった（上限到達後に停止した）タスクの停止が 1 回目で通ること
- [ ] 2.4 同じ `session_id`+`agent_id` を上限回数まで拒否した後の停止は通り、stderr に 1 行出てカウンタファイルが消えること。別の `agent_id` は独立に数えること。`stop_hook_active: true` でも回数内なら拒否すること
- [ ] 2.5 hook の上限回数の定数が正本 `references/subagent-waiting.md` の総待ちの上限回数と一致すること
- [ ] 2.6 `agent_id` が無い・python3 が無い・payload が壊れている・トランスクリプトが無い・カウンタのディレクトリが作れない・`DEV_WORKFLOW_STOP_GUARD=off` のとき、何も出力せず exit 0 になること
- [ ] 2.7 `agent_transcript_path` があればそれを使うこと。無ければ `<親>/<session_id>/subagents/agent-<agent_id>.jsonl`、それも無ければ context-tripwire.sh と同じ上限の探索で見つけること
- [ ] 2.8 5MB の合成トランスクリプトで、3 回測った最良値が 200ms 未満であること（context-tripwire.bats の性能テストと同じ測り方）
- [ ] 2.9 hooks.json の `SubagentStop` に登録されており、既存エントリが変わっていないこと
- [ ] 2.10 文言検査の素通りと実行時の検査の対: プラグインのディレクトリを `BATS_TEST_TMPDIR` に複製し、複製の `skills/develop/references/roles/worker.md` に禁止語を使わずに言い換えた違反を差し込み、その複製に対して既存の `subagent-waiting.bats` を実際に走らせて exit 0 になることを見る。同じ違反どおりに動いた合成トランスクリプトでは hook が停止を拒否することを並べて検査する。禁止語のリストは新しいスイートに写さない

## 3. 実装（Green）

- [ ] 3.1 `plugins/dev-workflow/scripts/subagent-stop-guard.sh` を実装する（bash の前段で全解除と `agent_id` の有無を切り、判定は python3。対象行を先に絞ってから JSON を読む。fail-open）
- [ ] 3.2 対象トランスクリプトの解決を実装する。`agent_transcript_path` の分岐はこの hook 固有、それが無いときの導出と探索の上限は context-tripwire.sh と同じ。共通化する場合は `tests/context-tripwire.bats` を 1 件も変えずに通す
- [ ] 3.3 `plugins/dev-workflow/hooks/hooks.json` に `SubagentStop` のエントリを追加する
- [ ] 3.4 2 章のテストがすべて通ることを確かめる

## 4. 正本と記録

- [ ] 4.1 `plugins/dev-workflow/references/subagent-waiting.md` の「総待ちの上限と超過時の分岐」に、待ちをやめて return する前（上限到達・結果の放棄）に TaskStop で背景タスクを停止する規則を足す
- [ ] 4.2 同じ正本に、実行時の検査（SubagentStop hook が何を見て何を止めるか・守らないもの・拒否の上限回数は総待ちの上限回数と同じ後詰めであること・全解除の環境変数）の 1 節を足す。指示書（W / R1 / G・pr-review-gate の SKILL.md）には再掲しない
- [ ] 4.3 issue #264 のコメントの宿題 4 件（正本の手順 2・3 の実行時検査、雛形を抽出して実行する検査の横展開、companion 経路のジョブ同一性の検査が要るかの評価、`$RANDOM` 版を実行時に落とせるかの実測）を個別の issue に起票し、番号を #264 のコメントに書く
- [ ] 4.4 `plugins/dev-workflow/changes/264.md` に変更の記録を書き、4.3 で起票した issue の番号も載せる（版は上げない）

## 5. 実セッションでの再現と検査

- [ ] 5.1 `claude -p --plugin-dir plugins/dev-workflow` で、サブエージェントに `sleep` を `run_in_background` で起動させ「完了を待つ」とだけ書いてターンを終えさせる。hook の拒否理由が届き、サブエージェントが前景で待ってから終わることを、実行コマンドと出力で issue #264 に添付する
- [ ] 5.2 `.github/workflows/` の `pull_request` / `push` の検査コマンドをすべて実行し、`scripts/test.sh` が exit 0 であることを確かめる
