## 1. 着手前の実測（方式が成り立つかの確認）

- [x] 1.1 `claude -p --plugin-dir` の実セッションで、最小の hook（payload とその時点のサブエージェントのトランスクリプトを記録し、未完了があれば 1 回だけ block するもの）を SubagentStop に置き、次を記録した（Claude Code 2.1.283、2026-09-27。実行コマンドと出力は issue #264 のコメント https://github.com/oratta/claude-harness/issues/264#issuecomment-5851334276 と https://github.com/oratta/claude-harness/issues/264#issuecomment-5851384984 ）
  - (a) 名前付き background サブエージェントのターン終了で SubagentStop が発火し、`{"decision":"block","reason":…}` でターン終了が取り消されて理由が本人に届くこと → 成立（積集合の判定で 1 回目拒否・前景で待った 2 回目通過）
  - (b) 正常系: 背景で `sleep 5` を起動し、前景の待ちループで完了まで待ってから終えるサブエージェントの停止が 1 回目に通ること → 成立（停止の時点で `background_tasks` からそのタスクが消えている）
  - (c) 背景で長い `sleep` を起動し、TaskStop（旧名 KillShell）で停止してから終えるサブエージェントの停止の時点で、`background_tasks` からそのタスクが消えていること → 成立（1 回目通過）。なお `killed` の task-notification はトランスクリプトに書かれない（判定には使わない）
  - (d) payload のキー → `agent_id` / `agent_transcript_path` / `agent_type` / `background_tasks` / `cwd` / `hook_event_name` / `last_assistant_message` / `permission_mode` / `prompt_id` / `session_crons` / `session_id` / `stop_hook_active` / `transcript_path`。サブエージェント側のトランスクリプトの背景起動の tool_result では `toolUseResult` が null で、ID は本文 `Command running in background with ID: <id>.` からしか取れない
  - (f) 本体が `sleep 90` を背景起動してから、背景起動をしないサブエージェントを起こす → 本体の shell が `background_tasks` に `running` で入る（配列は親セッション全体の台帳）が、積集合は空で停止は通る
  - (h) `sleep 3; exit 1` を背景起動して前景で 5 秒待ってから終える → 失敗したタスクは `status:"failed"` で残らず配列から消え、停止は通る。観測できた `status` の値は `running` だけ
  - (g) 2 つのサブエージェントの並走は、(f) が成立したので省いた
- [x] 1.2 次のいずれかに当たったら実装に進まず、1.1 の実行コマンドと出力を添えて本体に return する（方式の選び直しや代案は本体が決める）: (a) 発火しない・block が効かない／(b) 正常系の停止が 1 回目に通らない／(c) TaskStop 後に `background_tasks` からそのタスクが消えない／(f) 本体の背景 shell が `background_tasks` に入るのに、積集合で通らない／(h) `status` が `running` 以外で残るタスクを通せない → どれにも当たらなかった

## 2. テストを先に書く（Red）

- [x] 2.1 `plugins/dev-workflow/tests/subagent-stop-guard.bats` を作り、合成トランスクリプトを組む補助関数（背景起動の tool_result 本文 `Command running in background with ID: <id>.` を 1 行ずつ足せる形。context-tripwire.bats の組み方に合わせる）と、合成 payload を組む補助関数（`agent_id` / `agent_transcript_path` / `background_tasks` を差し替えられる）を置く
- [x] 2.2 トランスクリプトに起動が 1 件あり、payload の `background_tasks` に同じ ID が `running` で入っていると block が出て、理由にタスク ID・前景の待ちループで待つこと・上限まで待ったなら TaskStop で停止してから終えること・正本のパス・拒否の回数（例 `1/3`）が入ること。待ち値・完了マーカーの雛形が入らないこと
- [x] 2.3 起動したすべての ID が `background_tasks` に無い、または `status` が `running` でない、または起動が無いときは何も出力しないこと
- [x] 2.4 同じ `session_id`+`agent_id` を上限回数まで拒否した後の停止は通り、stderr に 1 行出てカウンタファイルが消えること。別の `agent_id` は独立に数えること。`stop_hook_active: true` でも回数内なら拒否すること
- [x] 2.5 hook の上限回数の定数が正本 `references/subagent-waiting.md` の総待ちの上限回数と一致すること
- [x] 2.6 `agent_id` が無い・python3 が無い・payload が壊れている・トランスクリプトが無い・カウンタのディレクトリが作れない・`DEV_WORKFLOW_STOP_GUARD=off` のとき、何も出力せず exit 0 になること。`background_tasks` キーが無い payload では stdout 無し・exit 0・stderr に 1 行出ること
- [x] 2.7 `agent_transcript_path` があればそれを使うこと。無ければ `<親>/<session_id>/subagents/agent-<agent_id>.jsonl`、それも無ければ context-tripwire.sh と同じ上限の探索で見つけること
- [x] 2.8 5MB の合成トランスクリプトで、3 回測った最良値が 200ms 未満であること（context-tripwire.bats の性能テストと同じ測り方）
- [x] 2.9 hooks.json の `SubagentStop` に登録されており、既存エントリが変わっていないこと
- [x] 2.10 文言検査の素通りと実行時の検査の対: プラグインのディレクトリを `BATS_TEST_TMPDIR` に複製し、複製の `skills/develop/references/roles/worker.md` に禁止語を使わずに言い換えた違反を差し込み、その複製に対して既存の `subagent-waiting.bats` を実際に走らせて exit 0 になることを見る。同じ違反どおりに動いた合成トランスクリプトと payload（背景起動 1 件・同じ ID が `background_tasks` に `running`）では hook が停止を拒否することを並べて検査する。禁止語のリストは新しいスイートに写さない
- [x] 2.11 トランスクリプトに起動が無く、`background_tasks` に他の shell（本体の `ci-watch.sh wait` を模した項目）が `running` で入っているときは何も出力しないこと
- [x] 2.12 実セッションの probe (a) 1 回目の payload（原本は issue #264 のコメント https://github.com/oratta/claude-harness/issues/264#issuecomment-5851393522 ）を fixture として取り込み、実測した形式のまま block になること（形式のピン留め）。payload は原本のまま使い、`agent_transcript_path` と `transcript_path` の 2 つだけを `BATS_TEST_TMPDIR` 配下の合成トランスクリプト（原本の tool_result 本文 1 行を `type:"user"` の記録として持つもの）に差し替える（原本のパスは作業者の機を指すので、そのままだと CI では fail-open で通ってしまう）。ピン留めの対象は `background_tasks` の形と `id` / `status` の読み方

## 3. 実装（Green）

- [x] 3.1 `plugins/dev-workflow/scripts/subagent-stop-guard.sh` を実装する（bash の前段で全解除と `agent_id` の有無を切り、判定は python3。`Command running in background with ID` を含む行だけに絞ってから JSON を読む。fail-open）
- [x] 3.2 対象トランスクリプトの解決を実装する。`agent_transcript_path` の分岐はこの hook 固有、それが無いときの導出と探索の上限は context-tripwire.sh と同じ。共通化する場合は `tests/context-tripwire.bats` を 1 件も変えずに通す
- [x] 3.3 `plugins/dev-workflow/hooks/hooks.json` に `SubagentStop` のエントリを追加する
- [x] 3.4 2 章のテストがすべて通ることを確かめる

## 4. 正本と記録

- [x] 4.1 `plugins/dev-workflow/references/subagent-waiting.md` の「総待ちの上限と超過時の分岐」に、待ちをやめて return する前（上限到達・結果の放棄）に TaskStop で背景タスクを停止する規則を足す
- [x] 4.2 同じ正本に、実行時の検査（SubagentStop hook が何を見て何を止めるか＝自分が背景起動したタスクが、停止時点の payload `background_tasks` で `running` のまま残っていること。`killed` の通知には触れない・守らないもの・拒否の上限回数は総待ちの上限回数と同じ後詰めであること・全解除の環境変数）の 1 節を足す。指示書（W / R1 / G・pr-review-gate の SKILL.md）には再掲しない
- [x] 4.3 issue #264 のコメントの宿題 4 件（正本の手順 2・3 の実行時検査、雛形を抽出して実行する検査の横展開、companion 経路のジョブ同一性の検査が要るかの評価、`$RANDOM` 版を実行時に落とせるかの実測）を個別の issue に起票し、番号を #264 のコメントに書く
- [x] 4.4 `plugins/dev-workflow/changes/264.md` に変更の記録を書き、4.3 で起票した issue の番号も載せる（版は上げない）

## 5. 実セッションでの再現と検査

- [x] 5.1 `claude -p --plugin-dir plugins/dev-workflow` で、サブエージェントに `sleep` を `run_in_background` で起動させ「完了を待つ」とだけ書いてターンを終えさせる。hook の拒否理由が届き、サブエージェントが前景で待ってから終わることを、実行コマンドと出力で issue #264 に添付する
- [x] 5.2 `.github/workflows/` の `pull_request` / `push` の検査コマンドをすべて実行し、`scripts/test.sh` が exit 0 であることを確かめる
