## Why

サブエージェントのコンテキスト量は、本体が SendMessage で再開する直前にしか測られない。1 回の起動の中でどれだけ膨らんでも誰も止めないため、実測で W が 366 リクエスト・497,552 トークン、G が 295 リクエスト・336,423 トークンに達した（過去 14 日の集計で上限 150,000 超が W 65%・G 63%）。膨張した 1 体が中央値の W 9 体分を消費するので、総消費を一番動かすのは「1 起動の途中で測って止める」ことになる（エピック #257 の判断）。

あわせて、測定コマンド `subagent-context.sh` が `isolation: "worktree"` で起こした名前付きサブエージェントを見つけられない件（#243）を、名前 glob の改良ではなく hook が受け取る識別子から解決する。

## What Changes

- dev-workflow プラグインに hook スクリプトを 1 本追加し、`hooks/hooks.json` に **PostToolUse（全ツール）** と **PreToolUse（編集系と Bash）** の 2 経路で登録する。
- **通知**: PostToolUse で、hook 実行中のサブエージェント自身のトランスクリプト末尾から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、`DEV_WORKFLOW_CONTEXT_CAP`（既定 150,000）超なら「今の工程を締めて成果を列挙して return せよ」を出力する。役割の識別はせず全サブエージェント一律。
- **強制停止**: PreToolUse で `DEV_WORKFLOW_CONTEXT_HARD_CAP`（既定 220,000）超なら、`Edit` / `Write` / `NotebookEdit` と、`git status` / `git diff` / `git add` / `git commit` / `git push` 以外の `Bash` を deny する。通知と強制停止の間の 70,000 は、編集の途中で切られて壊れた状態を次の担当に渡さないための余裕。
- **計測対象の解決**: 着手前実験（下記「判明した事実」）により、hook の stdin `transcript_path` はサブエージェント自身ではなく**親セッションのトランスクリプト**を指すことが分かった。そのため計測対象は `transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<projects>/<slug>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出する。`agent_id` が無い（メインスレッド）呼び出しでは何もしない。
- `scripts/subagent-context.sh` に `--file <path>` を追加し、共通の計測ロジックを hook と共有する。名前 glob は fallback に格下げする（#243 の統合）。
- develop の手順書（SKILL.md / `references/roles/worker.md` / `references/roles/gate-runner.md` / `references/decision-criteria.md` / `templates/escalation-tripwires.md`）に、途中計測の存在と「前任は途中停止で return した可能性がある（未コミット差分を先に確認）」を追記する。**この手順書への追記だけは PR #253 のマージ後に最後の commit で載せる**（同じファイルを #253 が書き換えているため）。
- `plugins/dev-workflow/.claude-plugin/plugin.json` の version bump。

破壊的変更なし。上限内では hook は何も出力せず、既存の挙動は変わらない。

## Capabilities

### New Capabilities

なし（既存 capability の要件変更のみ）。

### Modified Capabilities

- `dev-workflow-execution-strategy`: サブエージェントのコンテキスト計測が「本体が再開前に名前で測る」だけでなく「起動の途中で hook が自分自身を測る」を含むようになる。hook の登録先・計測対象の導出規則・2 段の閾値・拒否するツールの範囲・fail-open の条件・`subagent-context.sh --file` を要件として足す。
- `dev-workflow-develop`: 本体の再開前チェックに加えて途中計測が存在することと、手渡しで起こされた W / G は前任が途中停止した可能性を前提に未コミット差分を先に確認することを、手順書の要件として足す。

## Impact

- `plugins/dev-workflow/hooks/hooks.json`（PostToolUse 追加・PreToolUse に 1 エントリ追加。**聖域パスかつ層間契約**）
- `plugins/dev-workflow/scripts/context-tripwire.sh`（新規）
- `plugins/dev-workflow/scripts/subagent-context.sh`（`--file` 対応）
- `plugins/dev-workflow/tests/`（新規テストと既存 `subagent-context.bats` の追補）
- `plugins/dev-workflow/skills/develop/` 配下の手順書 5 本（#253 マージ後）
- `plugins/dev-workflow/.claude-plugin/plugin.json`・`CHANGELOG.md`
- 全ツール呼び出しごとに hook が 1 回走るため、実行時間が体感に影響しうる（トランスクリプト 5MB でも 100ms 未満を要件にする）
