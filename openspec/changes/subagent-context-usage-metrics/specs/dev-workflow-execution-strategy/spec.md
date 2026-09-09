## ADDED Requirements

### Requirement: サブエージェントのコンテキスト量の母集団集計

`plugins/dev-workflow/scripts/subagent-context-audit.sh` は、直近 N 日（`--days`、既定 14）のサブエージェントのトランスクリプトを走査し、母集団の統計を 1 行 JSON で標準出力に出さなければならない（SHALL）。JSON は次のキーを含む（SHALL）: `count`（対象件数）/ `first_median` / `first_max`（初回コンテキストの中央値・最大）/ `last_median` / `last_max`（最終コンテキストの中央値・最大）/ `over_cap_pct`（最終コンテキストが上限を超えた件数の割合、0〜100）/ `cap` / `days` / `sources`（`named` と `worktree` の内訳件数）/ `generated_at`。

1 体のコンテキスト量の定義は `subagent-context.sh` と同一で、assistant レコードの `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` でなければならない（MUST）。初回はファイル先頭から最初に現れた `usage` 付き assistant レコード、最終は末尾から遡って最初に見つかる同レコードとする（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）を用いる（SHALL）。中央値は偶数件のとき中央 2 値の平均を四捨五入した整数とする（SHALL）。

走査対象は 2 系統で、両方を含めなければならない（MUST）: ① 名前付きサブエージェント `${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*.jsonl`、② `isolation: "worktree"` で起こしたサブエージェント（project ディレクトリ名が `*--claude-worktrees-agent-*` に一致するディレクトリ直下の `*.jsonl`。名前も agentId もレコードに残らないため、Agent ツールの worktree パス規約に依る）。②はその worktree で人間が起動した対話セッションを含みうるため過大計上に倒れることを許容し、内訳を `sources` で示さなければならない（SHALL）。対象期間の判定はファイルの mtime で行う（SHALL。レコード内のタイムスタンプは見ない）。

トランスクリプトの全文を読んではならない（MUST NOT）。初回は最初の `usage` 付きレコードで読み取りを打ち切り、最終は末尾から固定サイズの窓（既定 256 KiB）を読んで見つからなければ上限（4 MiB）まで窓を倍加し、それでも見つからない 1 件は最終側の集計から除く（SHALL）。

この集計は観測専用であり、閾値に基づいてセッション・ツール・エージェントの実行を止めてはならない（MUST NOT。強制停止は別の仕組みが担う）。引数エラー以外はすべて exit 0 とし、トランスクリプトが 1 件も無い・projects ディレクトリが無い・`python3` が無い・JSON が壊れている場合は `count` が 0 の結果を出して exit 0 で終わらなければならない（MUST。fail-open）。

#### Scenario: 直近 14 日の集計が 1 行 JSON で出る

- **WHEN** 対象期間内に名前付きサブエージェントのトランスクリプトが複数存在する状態で `subagent-context-audit.sh` を実行する
- **THEN** `count` / `first_median` / `first_max` / `last_median` / `last_max` / `over_cap_pct` / `cap` / `days` / `sources` / `generated_at` を含む 1 行 JSON が出力され、exit 0 になる

#### Scenario: worktree 隔離のエージェントが集計に含まれる

- **WHEN** project ディレクトリ名が `--claude-worktrees-agent-<hash>` で終わるディレクトリの直下にトランスクリプトがある
- **THEN** そのファイルも集計対象に含まれ、`sources.worktree` に件数として現れる

#### Scenario: トランスクリプトが 1 件も無い環境

- **WHEN** projects ディレクトリが空、または存在しない状態で実行する
- **THEN** `count` が 0 の結果を出力して exit 0 で終わる（エラー終了しない）

#### Scenario: 上限超の割合が出る

- **WHEN** 対象のうち最終コンテキストが `cap` を超えるものがある
- **THEN** `over_cap_pct` がその割合（0〜100）として出力される

### Requirement: 実測値の usage 監査への注入

`scripts/session-tripwires.sh` は SessionStart のたびに `subagent-context-audit.sh` を best-effort で実行し、その結果を既存の残量モード・コンテキスト上限のブロックと同じ `additionalContext` に注入しなければならない（SHALL）。注入する本文は既存の「サブエージェントのコンテキスト上限」の行に続く **2 行以内**とし、件数・初回中央値・最終中央値・上限超の割合と集計窓の日数を含める（SHALL。この仕組み自体が固定分を増やす側に回らないため行数を縛る）。

集計結果は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}` に 1 行 JSON で保存し、キャッシュの mtime が `SUBAGENT_CONTEXT_AUDIT_TTL`（秒、既定 21600）以内なら再走査せずその内容を返さなければならない（SHALL）。`--refresh` は TTL を無視して再走査する（SHALL）。

集計が失敗した・`count` が 0・スクリプトが存在しないいずれの場合も、注入は無出力とし、既存の残量モードブロックと昇格トリップワイヤーの注入を妨げてはならない（MUST NOT。fail-open）。この注入は既存の `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` の導出を変えてはならない（MUST NOT）。

#### Scenario: 実測が注入される

- **WHEN** 集計が `count` 1 以上を返した状態で SessionStart hook が走る
- **THEN** 残量モードのブロックに続けて、件数・初回中央値・最終中央値・上限超の割合を含む 2 行以内の実測行が `additionalContext` に載る

#### Scenario: 集計が空でも hook は壊れない

- **WHEN** 集計が `count` 0 を返す、または集計スクリプトが存在しない
- **THEN** 実測行は注入されず、残量モードブロックと昇格トリップワイヤーの注入は従来どおり行われ、hook は exit 0 で終わる

#### Scenario: TTL 内はキャッシュを返す

- **WHEN** キャッシュファイルの mtime が TTL 以内の状態で集計を実行する
- **THEN** トランスクリプトを走査せずキャッシュの内容をそのまま出力する
