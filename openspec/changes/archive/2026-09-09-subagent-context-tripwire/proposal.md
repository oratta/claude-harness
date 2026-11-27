## Why

サブエージェントのコンテキスト量は、本体が SendMessage で再開する直前にしか測られない。1 回の起動の中でどれだけ膨らんでも誰も止めないため、実測で W が 366 リクエスト・497,552 トークン、G が 295 リクエスト・336,423 トークンに達した（過去 14 日の集計で上限 150,000 超が W 65%・G 63%）。膨張した 1 体が中央値の W 9 体分を消費するので、総消費を一番動かすのは「1 起動の途中で測って止める」ことになる（エピック #257 の判断）。

あわせて、測定コマンド `subagent-context.sh` が `isolation: "worktree"` で起こした名前付きサブエージェントを見つけられない件（#243）を、名前 glob の改良ではなく hook が受け取る識別子から解決する。

## What Changes

- dev-workflow プラグインに hook スクリプトを 1 本追加し、`hooks/hooks.json` に **PostToolUse（全ツール）** と **PreToolUse（編集系と Bash）** の 2 経路で登録する。
- **通知**: PostToolUse で、hook 実行中のサブエージェント自身のトランスクリプト末尾から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、`DEV_WORKFLOW_CONTEXT_CAP`（既定 150,000）超なら「今の工程を締めて成果を列挙して return せよ」を Claude に届ける。届け方は `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}` を stdout に出す形に固定する（**素の stdout + exit 0 はトランスクリプト表示（ctrl+o）にしか出ず、モデルには届かない**）。役割の識別はせず全サブエージェント一律。
- 通知と強制停止の本文には、**return の 1 行目に何を書くか**（強制停止で止まったときは `工程中断:`、通知を受けて締めるときは工程の tasks が全部済んでいれば `工程完了:`・1 つでも残っていれば `工程中断:`）を含める。#253 の申告規約で `工程完了:` が手渡しの条件になっており、手渡し先が未コミット差分と残作業を先に見るべきなのは中断のときだけであるため。
- **強制停止**: PreToolUse で `DEV_WORKFLOW_CONTEXT_HARD_CAP`（既定 220,000）超なら、`Edit` / `Write` / `NotebookEdit` と、許可した git サブコマンド以外の `Bash` を deny する。許可判定は「先頭トークンが `git` で、`-C <path>` / `-c <k=v>` を読み飛ばした次のトークンが `status` / `diff` / `add` / `commit` / `push`」とする（worktree 作業では `git -C <path> commit` を常用するため）。通知と強制停止の間の 70,000 は、編集の途中で切られて壊れた状態を次の担当に渡さないための余裕。
- **計測対象の解決**: 着手前実験（下記「判明した事実」）により、hook の stdin `transcript_path` はサブエージェント自身ではなく**親セッションのトランスクリプト**を指すことが分かった。そのため計測対象は `transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<projects>/<slug>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出する。`agent_id` が無い（メインスレッド）呼び出しでは何もしない。この判定は python3 を起動する前に bash 側で行う（この hook は install 先の全ユーザーの全ツール呼び出しで走るため）。
- `scripts/subagent-context.sh` に `--file <path>` を追加する（#243 の統合）。**計測ロジックの共有ファイルは作らない** — 計測の式を spec の要件として 1 つに定め、`subagent-context.sh` と `context-tripwire.sh` はそれぞれ自前で実装する。`subagent-context.sh` への変更は引数処理と、ヘッダコメント 1 行・`--help` の行範囲に限る（同じファイルを PR #253 が触るため）。
- develop の手順書に、途中計測の存在と 2 段の閾値・通知/強制停止時の振る舞い・`工程中断:` を追記する。ただし**規則の本文は `references/decision-criteria.md`「コンテキスト上限」1 箇所に置き**、`SKILL.md` / `references/roles/worker.md` / `references/roles/gate-runner.md` / `templates/escalation-tripwires.md` / `README.md` はその節へのポインタと役割固有の動作だけを書き、既にある閾値の再掲は参照に置き換える（#253 で 3 周続けて言い換え漏れが出た教訓）。**この手順書への追記だけは PR #253 のマージ後に最後の commit で載せる**（同じファイルを #253 が書き換えているため）。
- `plugins/dev-workflow/.claude-plugin/plugin.json` の version を **2.7.0** にする（#253 が 2.6.1 を取るための事前割当）。

破壊的変更なし。上限内では hook は何も出力せず、既存の挙動は変わらない。

## Capabilities

### New Capabilities

なし（既存 capability の要件変更のみ）。

### Modified Capabilities

- `dev-workflow-execution-strategy`: サブエージェントのコンテキスト計測が「本体が再開前に名前で測る」だけでなく「起動の途中で hook が自分自身を測る」を含むようになる。hook の登録先・計測対象の導出規則・2 段の閾値・通知の伝達経路（`additionalContext`）・拒否するツールの範囲・fail-open の条件・`subagent-context.sh --file` を要件として足す。
- `dev-workflow-develop`: 本体の再開前チェックに加えて途中計測が存在することと、規則の本文を `decision-criteria.md` 1 箇所に置いて他の 5 面（`SKILL.md` / `worker.md` / `gate-runner.md` / `escalation-tripwires.md` / `README.md`）はポインタにすること、手渡しで起こされた W / G は前任が途中停止した可能性を前提に未コミット差分を先に確認することを、手順書の要件として足す。

## Impact

- `plugins/dev-workflow/hooks/hooks.json`（PostToolUse 追加・PreToolUse に 1 エントリ追加。**聖域パスかつ層間契約**）
- `plugins/dev-workflow/scripts/context-tripwire.sh`（新規）
- `plugins/dev-workflow/scripts/subagent-context.sh`（`--file` 対応。引数処理・ヘッダ 1 行・`--help` の行範囲のみ）
- `plugins/dev-workflow/tests/context-tripwire.bats`（新規。hooks.json の登録内容の検査もここに置き、#253 が編集中の `tripwire-hook.bats` には足さない）・`plugins/dev-workflow/tests/subagent-context.bats`（`--file` の追補）
- `plugins/dev-workflow/skills/develop/` 配下の手順書と `templates/escalation-tripwires.md` / `README.md` の計 6 本（#253 マージ後）。本文は `references/decision-criteria.md` 1 箇所、残る 5 本はポインタ
- `plugins/dev-workflow/.claude-plugin/plugin.json`（2.5.0 → 2.7.0）・`CHANGELOG.md`（2.7.0 の見出し）
- 全ツール呼び出しごとに hook が 1 回走るため、実行時間が体感に影響しうる（トランスクリプト 5MB でも 100ms 未満を要件にし、メインスレッドでは python3 を起動しない）
