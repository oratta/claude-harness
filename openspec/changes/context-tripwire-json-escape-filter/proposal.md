# context-tripwire-json-escape-filter

## Why

途中計測 hook `plugins/dev-workflow/scripts/context-tripwire.sh` は、python3 を起動する前に「payload の生文字列に `"agent_id"` が含まれるか」だけを見て、含まなければ無音で exit 0 する（メインスレッドの大多数の呼び出しに python3 起動コストを課さないための最適化）。この判定は JSON をパースしないため、JSON としては同値でも表記が違うキー（`"\u0061gent_id"` のように先頭の `a` を Unicode エスケープで書いた表記。`json.loads` すると `agent_id` になる）を拾えず、そのまま fail-open する。強制停止の閾値 `DEV_WORKFLOW_CONTEXT_HARD_CAP` を超えたサブエージェントの `Bash` 呼び出しでも、この表記の payload なら deny されない（issue #278。PR #269 の 3 周目レビューで Codex CLI が発見した非 blocking の should_fix）。

現時点で Claude Code のハーネスがこの表記の payload を生成する証拠はなく、実運用の攻撃経路は未確認である。それでも塞ぐのは、到達不能を保証しているのがこのリポジトリの外（ハーネスの JSON シリアライズ実装）にあり、そこが `ensure_ascii` 相当の出力に変わるだけで穴が開くためである。

## What Changes

- 早期 exit の判定条件を「生文字列 `"agent_id"` を含まない」から「生文字列 `"agent_id"` を含まず、かつ JSON のエスケープ表記の起点（`\u`）も含まない」に変える。`\u` を含む payload は安く判定できないので python3 に渡し、パース後の `agent_id` フィールドの有無で決める（既存の fail-open 経路がそのまま効く）
- 早期 exit の目的は変えない。メインスレッドの通常の payload（`\u` を含まない）は従来どおり python3 を起動せずに exit 0 する
- `plugins/dev-workflow/tests/context-tripwire.bats` に、`"\u0061gent_id"` 表記の payload で強制停止が効くこと・`\u` を含まないメインスレッド payload では python3 が起動しないことの退行テストを足す

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-execution-strategy`: Requirement「起動の途中でコンテキストを測る hook」の早期 exit 条件（現在は「読み込んだ stdin が文字列 `"agent_id"` を含まない」）を、JSON 意味論的に同値な表記でも早期 exit しない条件に書き換える

## Impact

- `plugins/dev-workflow/scripts/context-tripwire.sh`（bash 側の `case` 判定 3 行とコメント。python 本体は変更なし）
- `plugins/dev-workflow/tests/context-tripwire.bats`（退行テスト 2 件）
- `plugins/dev-workflow/.claude-plugin/plugin.json`（version bump）
- 挙動の変更は「今まで無音で抜けていた表記の payload で hook が動く」方向のみ。通知・拒否のメッセージ、計測の式、閾値、hooks.json の登録は変わらない
