## 1. 計測ロジック（テスト先行）

- [ ] 1.1 `plugins/dev-workflow/tests/` に、末尾読みで最後の assistant usage を合算する計測のテストを書く（合算値・usage が無い・壊れた行が混ざる・ファイルが無い、の 4 ケース）。Red を確認する
- [ ] 1.2 `plugins/dev-workflow/scripts/subagent-context.sh` に `--file <path>` を追加する（名前 glob を使わずそのファイルを測る。`agent` はファイル名から導く）
- [ ] 1.3 `tests/subagent-context.bats` に `--file` のケース（exit 0 / exit 2 / 読めないときの exit 1）と、名前指定の既存挙動が変わらないことのケースを足す
- [ ] 1.4 名前 glob を fallback と位置づけるコメント・`--help` の文言を更新する（worktree 隔離ではファイル名に名前が入らないため見つからないことがある、と明記）

## 2. hook スクリプト（テスト先行）

- [ ] 2.1 `tests/context-tripwire.bats` を作り、stdin → stdout / exit code の単体テストを Red で書く: agent_id 無しは無音 / 上限内は無音 / トランスクリプトが無ければ無音 / `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` で無音 / 閾値の env が不正なら無音
- [ ] 2.2 `plugins/dev-workflow/scripts/context-tripwire.sh` を作る。stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読み、`<transcript_path の親>/<session_id>/subagents/agent-<agent_id>.jsonl` を計測対象として導出する（payload は環境変数や引数に載せず stdin から読む。`agent-model-guard.sh` と同じ理由）
- [ ] 2.3 直接パスが無いときに `<session_id>/subagents/` 以下を再帰的に 1 段だけ探す fallback を足す（入れ子のサブエージェント）
- [ ] 2.4 末尾 256KB だけを `seek` して読む実装にし、fail-open の全経路（python3 無し・JSON でない・usage 無し・閾値不正）を通す
- [ ] 2.5 PostToolUse の通知を実装する（`DEV_WORKFLOW_CONTEXT_CAP` 超で締めの指示と計測値・上限を出力。役割で出し分けない）。対応するテストを足して Green にする
- [ ] 2.6 PreToolUse の強制停止を実装する（`DEV_WORKFLOW_CONTEXT_HARD_CAP` 超で Edit / Write / NotebookEdit を deny、Bash は先頭コマンドが git status / diff / add / commit / push のときだけ許可、判定できない複合コマンドは deny、閾値の大小が逆なら fail-open）。対応するテストを足して Green にする
- [ ] 2.7 5MB のトランスクリプトを生成して hook 1 回が 100ms 未満であることをテストで確認する

## 3. hook の登録（聖域パス・層間契約）

- [ ] 3.1 `plugins/dev-workflow/hooks/hooks.json` に PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）の 2 エントリを足す。既存の `PreToolUse: Agent`（`agent-model-guard.sh`）は変えない
- [ ] 3.2 `tests/` に hooks.json の登録内容の検査（2 エントリの matcher とスクリプトパス、既存エントリが残っていること）を足す
- [ ] 3.3 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を bump し、`CHANGELOG.md` に追記する

## 4. worktree 隔離での実地確認（証拠を PR 本文に貼る）

- [ ] 4.1 `agent-a<16 桁 hex>.jsonl`（名前を含まないファイル名）を対象にしたテストケースを足し、隔離の有無で挙動が変わらないことを固定する
- [ ] 4.2 `DEV_WORKFLOW_CONTEXT_CAP` を小さく（20000 等）設定して名前付きサブエージェントを起こし、PostToolUse の出力に締めの指示が現れて同じターン内で return することをトランスクリプトで確認する
- [ ] 4.3 `isolation: "worktree"` で起こした名前付きサブエージェントでも 4.2 と同じことを確認する（#243 の再現条件）
- [ ] 4.4 強制停止の閾値を小さく設定して Edit が拒否され `git commit` は通ることを確認する
- [ ] 4.5 着手前実験（`transcript_path` の実値・`CLAUDE_CODE_SESSION_ID` の実値・トランスクリプトの実配置）と 4.2〜4.4 の証拠を PR 本文に貼る

## 5. 全体テストと push

- [ ] 5.1 `scripts/test.sh` を全件実行し、exit code と要約を出す（push 前の規約）
- [ ] 5.2 commit → push し、PR を作る（記録先は issue #261。本文に `Closes #261`）

## 6. 手順書への追記（**PR #253 のマージ後に最後の commit で載せる**）

- [ ] 6.1 PR #253 がマージ済みであることを確認し、main を取り込む
- [ ] 6.2 `skills/develop/SKILL.md` と `references/roles/worker.md` / `references/roles/gate-runner.md` に、途中計測の存在・通知を受けたらその起動を締めて return すること・強制停止で残せるのは commit と return だけであることを追記する
- [ ] 6.3 `references/roles/worker.md` の手渡しの節に「前任は途中停止で return した可能性がある（`git status` / `git diff` で未コミット差分を先に確認）」を足す
- [ ] 6.4 `references/decision-criteria.md` のコンテキスト上限の節に `DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP` / `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` を足し、`templates/escalation-tripwires.md` の【コンテキスト上限 → 手渡し】に途中停止の経路を足す
- [ ] 6.5 `scripts/test.sh` を全件実行してから最後の commit として push する
