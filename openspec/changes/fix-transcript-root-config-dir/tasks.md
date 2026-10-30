# Tasks

行番号は仕様作成時点（7df3bc57）の案内。編集前に各範囲を読み直す。実装開始には記録先 #1231 の R1 APPROVE が必要。

## 1. subagent-context.sh の探索先

- [ ] 1.1 `tests/subagent-context.bats` に、`CLAUDE_CONFIG_DIR` を一時ディレクトリにした場合に `--projects` なしでその下の会話記録を見つけるテスト、`CLAUDE_PROJECTS_DIR` が優先されるテスト、どちらも未設定なら `$HOME/.claude/projects` を探すテストを足す。`HOME` はどのテストでも一時ディレクトリにし、`CLAUDE_PROJECTS_DIR` / `CLAUDE_CONFIG_DIR` は `env -u` で外して、実行者の環境に左右されないようにする。修正前は `CLAUDE_CONFIG_DIR` のテストが exit 1（`transcript not found`）で落ちることを確認する。触る範囲: plugins/dev-workflow/tests/subagent-context.bats:406（末尾に追加）
- [ ] 1.2 既定の探索先を `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}` にし、ヘッダの「探索:」のコメントを同じ内容に直す。`bats plugins/dev-workflow/tests/subagent-context.bats` が exit 0 であることを確認する。触る範囲: plugins/dev-workflow/scripts/subagent-context.sh:26、plugins/dev-workflow/scripts/subagent-context.sh:37

## 2. pr-token-budget.sh の探索先

- [ ] 2.1 `tests/pr-token-budget.bats` に、`CLAUDE_CONFIG_DIR` を一時ディレクトリにした場合に `--projects` なしで `claude_tokens` が 0 でない期待値になるテスト、`CLAUDE_PROJECTS_DIR` が優先されるテスト、どちらも未設定なら `$HOME/.claude/projects` を数えるテストを足す。環境の扱いは 1.1 と同じ。修正前は `CLAUDE_CONFIG_DIR` のテストが `claude_tokens` 0 で落ちることを確認する。触る範囲: plugins/dev-workflow/tests/pr-token-budget.bats:299（末尾に追加）
- [ ] 2.2 既定の探索先を 1.2 と同じ形にし、ヘッダの紐付けの規約のコメントを同じ内容に直す。`bats plugins/dev-workflow/tests/pr-token-budget.bats` が exit 0 であることを確認する。触る範囲: plugins/dev-workflow/scripts/pr-token-budget.sh:18、plugins/dev-workflow/scripts/pr-token-budget.sh:33

## 3. 記録と統合検証

- [ ] 3.1 変更の記録を書き、`CLAUDE_CONFIG_DIR` を使うセッションで上限超の exit 2 が初めて出ることと戻し方を残す。`git diff` でプラグインの版を上げていないことを確認する。触る範囲: plugins/dev-workflow/changes/1231.md（新規）
- [ ] 3.2 `bats plugins/dev-workflow/tests/subagent-context.bats plugins/dev-workflow/tests/pr-token-budget.bats plugins/dev-workflow/tests/epic-dispatch.bats` が exit 0 であること、`openspec validate fix-transcript-root-config-dir --type change --strict` が exit 0 であることを確認する。触る範囲: なし（検証のみ）

## Workflow follow-up

- archive と PR は (3b) の段で行う
