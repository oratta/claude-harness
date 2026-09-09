## 1. 計測ロジック（テスト先行）

- [ ] 1.1 `plugins/dev-workflow/tests/context-tripwire.bats` に、末尾読みで最後の assistant usage を合算する計測のテストを書く（合算値・usage が無い・壊れた行が混ざる・ファイルが無い、の 4 ケース）。Red を確認する
- [ ] 1.1b `subagent-context.sh --file` と `context-tripwire.sh` が同じ値を返すことのテストを足す。**末尾 256KB に最後の assistant usage が含まれる**短いトランスクリプトで比較する（末尾 256KB の外にある場合は hook 側が fail-open で無音になり、一致しないのが正しい挙動）。hook は上限内だと無音なので、`DEV_WORKFLOW_CONTEXT_CAP` を小さくして `additionalContext` に含まれる計測値を読み取り、`--file` の `context_tokens` と突き合わせる
- [ ] 1.2 `plugins/dev-workflow/scripts/subagent-context.sh` に `--file <path>` を追加する（名前 glob を使わずそのファイルを測る。`agent` はファイル名から導く）。**変更は引数処理の `case` 分岐に限る**（計測本体の python ブロックは触らない。#253 が同じファイルを編集中）
- [ ] 1.3 `tests/subagent-context.bats` に `--file` のケース（exit 0 / exit 2 / 読めないときの exit 1）と、名前指定の既存挙動が変わらないことのケースを足す
- [ ] 1.4 `subagent-context.sh` のヘッダコメントに `--file` の説明を **1 行だけ**足す（「`--file <path>` はそのファイルを直接測る。worktree 隔離ではファイル名に名前が入らず名前 glob では見つからないため」を 1 行に収める）。既存の `--help` 出力の行は書き換えない
- [ ] 1.5 ヘッダに 1 行足したぶん、`--help` 実装の `sed -n '2,22p' "$0"`（35 行目付近）の範囲を 1 行分ずらして `sed -n '2,23p'` にする。ずらさないとヘルプ末尾に `set -uo pipefail` が出る。**#253 が触るヘッダ（17〜18 行目）と同じブロックなので、rebase 時にここを再確認する**

## 2. hook スクリプト（テスト先行）

- [ ] 2.1 `tests/context-tripwire.bats` に stdin → stdout / exit code の単体テストを Red で書く: agent_id 無しは無音 / 上限内は無音 / トランスクリプトが無ければ無音 / `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` で無音 / 閾値の env が不正なら無音
- [ ] 2.2 `plugins/dev-workflow/scripts/context-tripwire.sh` を作る。stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読み、`<transcript_path の親>/<session_id>/subagents/agent-<agent_id>.jsonl` を計測対象として導出する（payload は環境変数や引数に載せず stdin から読む。`agent-model-guard.sh` と同じ理由）
- [ ] 2.3 **早期脱出を bash 側に置く**: `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` / `command -v python3` が無い / 読んだ stdin が文字列 `"agent_id"` を含まない、のいずれかなら **python3 を起動せずに** exit 0 する。この hook は install 先の全ユーザーの全ツール呼び出しで走り、大多数がメインスレッド（`agent_id` 無し）であるため。`agent-model-guard.sh` の同じ形に合わせる。対応するテスト（メインスレッド payload で python3 を呼ばないこと）を足し、**誤検知が無害である理由をテストのコメントに 1 行残す**（`agent_id` という文字列を含む Bash コマンドを打つとメインスレッドでも python3 が起動するが、その先で `agent_id` フィールドが無いと判定されて fail-open するだけ。逆方向＝サブエージェントなのに素通りは JSON キーとして必ず入るので起きない）
- [ ] 2.4 直接パスが無いときに `<session_id>/subagents/` 以下を **深さ 3 段まで**（`subagents/` 直下を 1 段目と数える）`agent-<agent_id>.jsonl` で探す fallback を足す（入れ子のサブエージェント）。走査の上限（ディレクトリエントリ 200 件、または探索 20ms）を設け、上限に達したら打ち切って無音で exit 0 する。深さ 2 段・3 段に置いたケースと、上限に当たるケースのテストを足す
- [ ] 2.5 末尾 256KB だけを `seek` して読む実装にし、fail-open の全経路（python3 無し・JSON でない・usage 無し・閾値不正）を通す。256KB は環境変数化しない（design Decision 5）
- [ ] 2.6 PostToolUse の通知を実装する。**`{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}` を stdout に出して exit 0**（素の stdout + exit 0 は ctrl+o のトランスクリプト表示にしか出ずモデルには届かない）。`additionalContext` に締めの指示・計測値・上限に加えて、**return の 1 行目の書き分け**（そのとき進めていた tasks グループの項目がすべて済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:`。**tasks.md が無い場合は本体から渡された作業項目、G は pr-review-gate の手順 1〜5 を 1 グループとみなす**）を含める。役割で出し分けない。テストは stdout を JSON として解析し `hookSpecificOutput.hookEventName == "PostToolUse"` と `additionalContext` の中身を検査する
- [ ] 2.7 PreToolUse の強制停止を実装する（`DEV_WORKFLOW_CONTEXT_HARD_CAP` 超で `Edit` / `Write` / `NotebookEdit` を deny、閾値の大小が逆なら fail-open）。拒否理由には計測値・強制停止の閾値・「commit して return せよ」・**return の 1 行目は `工程中断:` にすること**を含める
- [ ] 2.8 Bash の許可判定を実装する: **先頭トークンが `git` で、`-C <path>` / `-c <k=v>` を読み飛ばした次のトークンが `status` / `diff` / `add` / `commit` / `push`** なら許可、それ以外は deny。パイプ・`&&`・`;`・サブシェル・コマンド置換 `$(…)` を含むものは deny。**deny の理由に回避手段「commit メッセージは `-m` を複数回に分けて 1 行ずつ渡せ（`$(…)` は拒否される）」を含める**。テストは `git -C /path/to/wt commit -m x` が通ること、`git commit -m "$(printf x)"` が拒否され理由に回避手段が含まれること、`git status && rm -rf build` が拒否されることを検査する
- [ ] 2.9 5MB のトランスクリプトを生成して hook 1 回が 100ms 未満であることをテストで確認する

## 3. hook の登録（聖域パス・層間契約）

- [ ] 3.1 `plugins/dev-workflow/hooks/hooks.json` に PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）の 2 エントリを足す。既存の `PreToolUse: Agent`（`agent-model-guard.sh`）は変えない
- [ ] 3.2 hooks.json の登録内容の検査（新 2 エントリの matcher とスクリプトパス、既存 3 エントリが残っていること）を **新規の `tests/context-tripwire.bats`** に書く。既存 `tests/tripwire-hook.bats` には足さない（#253 が編集中のため）。PreToolUse の matcher が `Edit|Write|NotebookEdit|Bash` であることが「読み取り系（Read / Grep / Glob）を拒否しない」を構造的に保証している旨をテストのコメントに残す
- [ ] 3.3 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を 2.5.0 → **2.7.0** にする（#253 が 2.6.1 を取るための事前割当。#253 マージ後の rebase で 1 行衝突を解く）。`CHANGELOG.md` に **2.7.0 の見出し**で追記する

## 4. worktree 隔離での実地確認（証拠を PR 本文に貼る）

**4.2〜4.4 は worktree 隔離されていないセッションから実行する。** 隔離エージェントからは `claude` の起動そのものがガードに拒否されるため、この change を実装している W 本人には実行できない（design Decision 9）。W は 4.1 までを行い、4.2〜4.4 は本体（または隔離なしのセッション）に依頼して証拠を受け取る。

- [ ] 4.1 `agent-a<16 桁 hex>.jsonl`（名前を含まないファイル名）を対象にしたテストケースを足し、隔離の有無で挙動が変わらないことを固定する
- [ ] 4.2 **実地確認の依頼文を作る**（W の成果物）。渡すもの: 与える環境変数（`DEV_WORKFLOW_CONTEXT_CAP=20000` 等）とその与え方（`claude` 起動前に export する／`settings.json` の `env` に置く）、起こすサブエージェントの形（名前付き・`isolation: "worktree"` の 2 通り）、確認するトランスクリプトの場所（`~/.claude/projects/<slug>/<親セッション ID>/subagents/agent-<agent_id>.jsonl`）、証拠として取るもの（hook の出力が現れた行と、その直後に return しているか）
- [ ] 4.3 名前付きサブエージェント（隔離なし）で、PostToolUse の `additionalContext` に締めの指示が現れ、同じターン内で return することをトランスクリプトで確認する
- [ ] 4.4 `isolation: "worktree"` で起こした名前付きサブエージェントでも 4.3 と同じことを確認する（#243 の再現条件）。あわせて強制停止の閾値を小さく設定して `Edit` が拒否され `git -C <worktree> commit` は通ることを確認する
- [ ] 4.5 着手前実験（`transcript_path` の実値・`CLAUDE_CODE_SESSION_ID` の実値・トランスクリプトの実配置）と 4.3〜4.4 の証拠を PR 本文に貼る。**観測した `agent_id` の実値と実ファイル名の対を必ず含める**（payload の `agent_id` は着手前実験では観測できておらず、ファイル名からの逆算のみ。ここで対を残せば後続が同じ検証をやり直さずに済む）

## 5. 全体テストと push

- [ ] 5.1 `scripts/test.sh` を全件実行し、exit code と要約を出す（push 前の規約）
- [ ] 5.2 commit → push し、PR を作る（記録先は issue #261。本文に `Closes #261`）

## 6. 手順書への追記（**PR #253 のマージ後に最後の commit で載せる**）

**書き方の制約**: 規則の本文（閾値・2 経路・通知/強制停止時の振る舞い・`工程中断:` の使い分け）は `references/decision-criteria.md`「コンテキスト上限」の節 1 箇所に置く。他の 5 本（`skills/develop/SKILL.md` / `references/roles/worker.md` / `references/roles/gate-runner.md` / `templates/escalation-tripwires.md` / `README.md`）はその節へのポインタと役割固有の動作だけを書き、閾値や振る舞いを言い換えて再掲しない（#253 で 3 周続けて言い換え漏れが出た教訓）。

**既存の再掲は「足す」のではなく「置き換える」**: 着手時点で閾値の再掲が次の 4 箇所に実在する。参照を足すだけでは 6.7 のテストが最初から Red になるので、6.3 / 6.6 は既存の再掲を参照に**置き換える**。

| ファイル | 着手時点の行 | 再掲されている内容 |
|---|---|---|
| `skills/develop/references/roles/worker.md` | 164 | 「上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150000 tokens）」 |
| `skills/develop/SKILL.md` | 94 | 同じ文言 |
| `templates/escalation-tripwires.md` | 80 | 「`DEV_WORKFLOW_CONTEXT_CAP`（既定 150000 tokens）を超えていた（exit 2）」 |
| `README.md` | 14 | 「`scripts/subagent-context.sh` で測り、150K tokens 超なら再開せず…」 |

（`references/roles/gate-runner.md:72` は既にポインタだけなので置き換え不要。）**行番号は #253 が同じ行を触るため、6.1 の rebase 後に必ず取り直す**（`grep -n 'DEV_WORKFLOW_CONTEXT_CAP\|150000\|150K' <ファイル>`）。

- [ ] 6.1 PR #253 がマージ済みであることを確認し、main を取り込む（plugin.json の version は 2.7.0 のまま解決する）。取り込み後に上の表の行番号を grep で取り直す
- [ ] 6.2 `references/decision-criteria.md`「コンテキスト上限」の節に**規則の本文を書く**: 2 経路（本体の再開前チェックと途中計測 hook）、`DEV_WORKFLOW_CONTEXT_CAP`（通知）／`DEV_WORKFLOW_CONTEXT_HARD_CAP`（強制停止）／`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`（全解除）、通知を受けたら次のツールを呼ばずに締めて return すること、強制停止で残せるのは commit と return だけであること、return の 1 行目の書き分け（強制停止は必ず `工程中断:`／通知は tasks グループが全部済んでいれば `工程完了:`・1 つでも残っていれば `工程中断:`。tasks.md が無い場合は本体から渡された作業項目、G は pr-review-gate の手順 1〜5 を 1 グループとみなす）
- [ ] 6.3 `skills/develop/SKILL.md` / `references/roles/worker.md` / `README.md` の**既存の再掲（上の表の行）を `decision-criteria.md`「コンテキスト上限」への参照に置き換える**。`references/roles/gate-runner.md` は既にポインタだけなので、参照先が「コンテキスト上限」の節であることを確認するに留める。どのファイルにも閾値・振る舞いの本文を書かない
- [ ] 6.4 `references/roles/worker.md` の手渡しの節に役割固有の動作を足す: 前任が途中停止で return した可能性があるので、再出発の前に `git status` / `git diff` で未コミット差分を確認する
- [ ] 6.5 `references/roles/gate-runner.md` に役割固有の動作を足す: G が強制停止に当たると `gh pr comment` も拒否されるので、レビュー結果を return に含めて `工程中断:` で返し、**本体が代理投稿する**（R1 の仕様レビューを本体が代理投稿しているのと同じ形）。`SKILL.md` の本体側にも代理投稿する側の手順を足す
- [ ] 6.6 `templates/escalation-tripwires.md` の【コンテキスト上限 → 手渡し】で、**既存の再掲（上の表の行）を `decision-criteria.md` への参照に置き換え**、途中停止の経路があることを 1 行足す
- [ ] 6.7 `tests/develop-roles.bats` 等で、**5 本**（`SKILL.md` / `worker.md` / `gate-runner.md` / `escalation-tripwires.md` / `README.md`）が `decision-criteria.md` を参照していること・閾値の数値（`150000` / `220000` / `150K` 表記）と環境変数名（`DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP` / `DEV_WORKFLOW_CONTEXT_TRIPWIRE`）を再掲していないことを検査する
- [ ] 6.8 `scripts/test.sh` を全件実行してから最後の commit として push する
