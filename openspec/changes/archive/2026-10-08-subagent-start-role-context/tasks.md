## 1. テストを先に書く

- [x] 1.1 新規 bats を作り、spec の Scenario（worker に返す・Explore に返さない・decider と casting-arbiter に返さない・reviewer に残量モードを渡さない・明示 env が届く・閾値の env 上書きと既定値・壊れた入力で無出力 exit 0・hooks.json の SubagentStart エントリ）を書く。環境の隔離は `tripwire-hook.bats` の setup（`CLAUDE_ACCOUNTS_FILE` / `USAGE_SESSIONS_DIR` / `USAGE_SNAPSHOT` などを一時ディレクトリへ向ける）に揃え、実 API と実環境の `~/.claude` を読まない。既定値の照合は `context-tripwire.sh` の `env_int(...)` の既定と突き合わせる。触る範囲: plugins/dev-workflow/tests/subagent-start-context.bats（新規）、plugins/dev-workflow/tests/tripwire-hook.bats:7-26（setup の参照）、plugins/dev-workflow/scripts/context-tripwire.sh:176-177（既定値）
- [x] 1.2 `TRIPWIRES_SCOPE=subagent-budget` で `session-tripwires.sh` が残量ブロックだけを本文テキストで出し、テンプレートが無くても出し、probe を呼ばないこと（`USAGE_PROBE_RESPONSE_FILE` 等で probe の実行痕が残らないこと）を同じ bats に書く。未設定時の出力が従来どおりであることは既存の `tripwire-hook.bats` が担保する。触る範囲: plugins/dev-workflow/tests/subagent-start-context.bats（新規）
- [x] 1.3 hooks.json のイベント集合を完全一致で検査している既存テストに `SubagentStart` を足す。触る範囲: plugins/dev-workflow/tests/subagent-stop-guard.bats:453-470（「hooks.json: SubagentStop runs subagent-stop-guard.sh」のイベント集合 assert）
- [x] 1.4 casting の bats に `grep -c '^omitClaudeMd: true'` が 1 を確かめるテストを足す。触る範囲: plugins/casting/tests/casting-consultation.bats:79-82（「arbiter: tools frontmatter grants Read only」の直後）

## 2. session-tripwires.sh に出力範囲の切り替えを足す

- [x] 2.1 `TRIPWIRES_SCOPE=subagent-budget` のとき、usage-probe・メモリ索引の検知・テンプレートの存在確認と節の抽出を飛ばし、残量モードのブロック（`## Fable 残量モード（自動導出）` から共有枠モードの効果の行まで。親向けの「W を SendMessage で再開する前に測る」行は含めない）を本文テキストで stdout に出す。未設定時の経路と出力は 1 文字も変えない。導出式（明示 env > データ無し > 90% 超 > 週経過との比較）は既存のコードをそのまま使い、複製しない。触る範囲: plugins/dev-workflow/scripts/session-tripwires.sh:1-20（冒頭コメント・テンプレート確認・probe・メモリ検知）、plugins/dev-workflow/scripts/session-tripwires.sh:27-36（節の抽出）、plugins/dev-workflow/scripts/session-tripwires.sh:117-144（lines の組み立てと出力）

## 3. SubagentStart のスクリプトと hook

- [x] 3.1 `scripts/subagent-start-context.sh` を新規作成する。stdin の JSON から `agent_type` を読み、`^dev-workflow:(worker|reviewer|gate-runner)$` に当たらなければ無出力 exit 0。worker / gate-runner は `TRIPWIRES_SCOPE=subagent-budget` で呼んだ `session-tripwires.sh` の出力＋途中計測の行、reviewer は途中計測の行だけを本文にし、`{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":...}}` で出す。途中計測の行は `DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP` の実効値（既定は `context-tripwire.sh` と同じ）・`DEV_WORKFLOW_CONTEXT_TRIPWIRE` の状態と、decision-criteria「コンテキスト上限（サブエージェントの手渡し）」への案内だけを書き、規則の言い換えを書かない。payload は環境変数や引数に載せず stdin で渡す（`context-tripwire.sh` の fd 3 ヒアドキュメントの形）。全経路 fail-open。実行権限を付ける。触る範囲: plugins/dev-workflow/scripts/subagent-start-context.sh（新規）、plugins/dev-workflow/scripts/context-tripwire.sh:44-53（payload の渡し方の前例）
- [x] 3.2 hooks.json に SubagentStart エントリを足す（matcher `^dev-workflow:(worker|reviewer|gate-runner)$`、command `"${CLAUDE_PLUGIN_ROOT}/scripts/subagent-start-context.sh"`）。自己統治物件なので PR 本文で主の承認を求める。触る範囲: plugins/dev-workflow/hooks/hooks.json:72-82（SubagentStop の後ろ）

## 4. casting-arbiter

- [x] 4.1 frontmatter に `omitClaudeMd: true` を 1 行足す。本文は変えない。触る範囲: plugins/casting/agents/casting-arbiter.md:1-6（frontmatter）

## 5. 記録と検証

- [x] 5.1 変更記録を書く（dev-workflow と casting の両方）。触る範囲: plugins/dev-workflow/changes/715.md（新規）、plugins/casting/changes/715.md（新規）
- [x] 5.2 `tests/injection-budget.bats` を走らせ、`omitClaudeMd: true` が frontmatter の許可リスト書式検査を通ること・測定値が予算内であることを確かめる（落ちたら予算ファイルではなく原因を直す。予算値を動かす必要が出たら PR 本文に理由を書く）。`claude plugin validate`（lint-plugin-validate）も通す。触る範囲: tests/injection-budget.bats（読むだけ）
- [x] 5.3 `scripts/test.sh` が exit 0
- [x] 5.4 実機確認: `claude -p --plugin-dir plugins/dev-workflow` で worker を 1 回起動し、サブエージェントの transcript（`agent_transcript_path`、または `<親 transcript のディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl`）を注入行で grep した結果を控え、PR に貼る。`agent_type` が `dev-workflow:worker` の形で来ない場合は matcher とスクリプトの照合を実際の形に合わせ、その事実を PR に書く
