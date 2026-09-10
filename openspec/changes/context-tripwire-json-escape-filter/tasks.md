# tasks — context-tripwire-json-escape-filter

## 1. 退行テスト（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/context-tripwire.bats` に「Unicode エスケープ表記の `agent_id` を持つ PreToolUse / `Bash` payload が deny される」テストを足す（payload は python3 で `chr(92)` からキーを組み立てて生成し、期待は生表記と同じ `permissionDecision: "deny"`）
- [ ] 1.2 同ファイルに「`\u` を含むが `agent_id` を持たないメインスレッド payload は python3 が起動しても無音で exit 0」テストを足す（早期 exit を緩めても fail-open が保たれることの固定）
- [ ] 1.3 既存の「早期 exit: agent_id の無い payload は python3 を起動しない」テストが `\u` を含まない payload であることを確かめ、必要ならコメントで条件を明示する
- [ ] 1.4 1.1 が現状の実装で落ちること（Red）を実行して確認する

## 2. 実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/context-tripwire.sh` の `case` に `*'\u'*` の arm を足し、コメントを「必要条件で切る」根拠（`\uXXXX` 以外のエスケープでは `agent_id` を綴れない）に書き換える
- [ ] 2.2 `bash scripts/test.sh` 相当で `context-tripwire.bats` 全件が通ることを確認する（実行は `env -u CLAUDE_SECURESTORAGE_CONFIG_DIR bash scripts/test.sh`、出力は全件ファイルに落として `grep -n '^not ok'` で拾う）

## 3. 仕上げ

- [ ] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を上げる
- [ ] 3.2 リポジトリ全体のテスト（`env -u CLAUDE_SECURESTORAGE_CONFIG_DIR bash scripts/test.sh`）を実行し、exit code と `not ok` 件数を記録する
- [ ] 3.3 `openspec archive` まで済ませ、PR を作って本文に `Closes #278` を書く
