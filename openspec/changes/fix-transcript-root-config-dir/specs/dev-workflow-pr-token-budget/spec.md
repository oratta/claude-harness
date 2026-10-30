## MODIFIED Requirements

### Requirement: 出力と exit code
`pr-token-budget.sh <番号>... [--cap <tokens>] [--projects <dir>] [--codex-records <file>] [--codex-home <dir>]...` は、stdout に 1 行 JSON を SHALL 出す。キーは少なくとも `records`（渡した番号の配列）・`claude_tokens`・`codex_tokens`・`total_tokens`（`claude_tokens + codex_tokens`）・`agent_count`・`codex_threads`・`cap`・`over_cap`・`unresolved`・`codex_unresolved`・`skipped_lines`・`agents`（各サブエージェントの `name`・`description`・`model`・`tokens`・`requests`）・`codex`（各 thread の `thread_id`・`tokens`・`source`（`record` か `rollout`））とする。上限は Claude 分と Codex 分を分けず、`total_tokens` に 1 本で MUST 掛ける。上限は `--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 を使う。走査対象は `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/*/subagents/agent-*.meta.json`（`--projects` で差し替え）とする。

exit code は、`total_tokens` が上限以下なら 0、上限を超えたら 2、引数エラー・python3 が無い・カレントディレクトリがリポジトリでないときは 1 と MUST する。紐付くサブエージェントが 0 体のときはエラーにせず、合計 0 で exit 0 と SHALL する。

#### Scenario: 固定のトランスクリプトで期待値と一致する
- **WHEN** bats が用意した固定のトランスクリプト群（紐付く 2 体、別番号 1 体、別リポジトリ 1 体、重複行・壊れた行を含む）と、Codex の記録ファイル（トークン数付き 1 件・`-` で rollout から読む 1 件）・固定の rollout に対して `pr-token-budget.sh 288 --codex-records <file> --codex-home <dir>` を実行する
- **THEN** `claude_tokens`・`codex_tokens`・`total_tokens`・`agent_count`・`codex_threads` が手計算の期待値と一致し、exit 0

#### Scenario: Codex 分を足すと上限を超える
- **WHEN** Claude 分だけでは上限以下で、Codex 分を足すと上限を超える `--cap` を渡す
- **THEN** `over_cap` が true で exit 2

#### Scenario: 上限を超えると exit 2
- **WHEN** 同じ固定入力に対して、合計より小さい値を `--cap` に渡す
- **THEN** `over_cap` が true で exit 2

#### Scenario: まだ誰も起こしていない
- **WHEN** 紐付くサブエージェントが 0 体の番号を渡し、`--codex-records` を渡さない
- **THEN** `total_tokens` が 0、`agent_count` が 0、`codex_threads` が 0 で exit 0

#### Scenario: 環境変数の上限が使われる
- **WHEN** `--cap` を付けず、環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP` に固定入力の合計より小さい値を設定して実行する
- **THEN** 出力の `cap` がその値になり、`over_cap` が true で exit 2

#### Scenario: --cap が環境変数より優先される
- **WHEN** `DEV_WORKFLOW_PR_TOKEN_CAP` に合計より小さい値、`--cap` に合計より大きい値を渡す
- **THEN** 出力の `cap` は `--cap` の値で、exit 0

#### Scenario: 上限の指定が不正
- **WHEN** `--cap` に数字でない値を渡す
- **THEN** exit 1

#### Scenario: CLAUDE_CONFIG_DIR の下の消費を数える
- **GIVEN** `CLAUDE_PROJECTS_DIR` が未設定で、`CLAUDE_CONFIG_DIR` が指す一時ディレクトリの `projects/*/*/subagents/` に記録先 `288` のサブエージェントの会話記録があり、`HOME` の下には無い
- **WHEN** `pr-token-budget.sh 288` を `--projects` なしで実行する
- **THEN** `claude_tokens` はその会話記録の usage の合計（0 でない値）になる

#### Scenario: CLAUDE_PROJECTS_DIR は CLAUDE_CONFIG_DIR より優先される
- **GIVEN** `CLAUDE_PROJECTS_DIR` と `CLAUDE_CONFIG_DIR` がどちらも設定され、それぞれの下に記録先 `288` のサブエージェントの usage の異なる会話記録がある
- **WHEN** `pr-token-budget.sh 288` を `--projects` なしで実行する
- **THEN** `claude_tokens` は `CLAUDE_PROJECTS_DIR` の下の会話記録の合計になる

#### Scenario: どちらも未設定なら ~/.claude の下を数える
- **GIVEN** `CLAUDE_PROJECTS_DIR` と `CLAUDE_CONFIG_DIR` がどちらも未設定で、`$HOME/.claude/projects/*/*/subagents/` に記録先 `288` のサブエージェントの会話記録がある
- **WHEN** `pr-token-budget.sh 288` を `--projects` なしで実行する
- **THEN** `claude_tokens` はその会話記録の usage の合計になる
