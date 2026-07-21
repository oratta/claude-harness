## 1. テスト先行（Red）

- [x] 1.1 `plugins/loops/tests/dev-agent-tripwires.bats` を新設する: テンプレートのトリップワイヤー3本（数値条件）、reserve 上限 + needs-approval、env 前提（LONGRUN_AUTOMATED / FABLE_BUDGET_MODE）、Workflow ツール直接操作の不在、install SKILL の env 記載。実行して Red を確認する

## 2. 実装（Green）

- [x] 2.1 `templates/agent-loop-template.md` の Step 3 末尾にトリップワイヤー節（3本の unmanned 写像 + env 前提 + dev-workflow テンプレ参照）を追加する
- [x] 2.2 `skills/loops-dev-agent-install/SKILL.md` の環境変数解説に LONGRUN_AUTOMATED / FABLE_BUDGET_MODE を追記する
- [x] 2.3 bats を実行して全テスト Green（loops スイート全体の回帰なし含む）を確認する

## 3. リリース

- [x] 3.0 （追加タスク）S48 ガードのセクション単位への縮小、marketplace.json の全プラグインバージョン同期（top-level 2.22.0）、longrun バージョンピンテスト3件の 6.5.0 更新
- [x] 3.1 `plugins/loops/.claude-plugin/plugin.json` のバージョンを上げる
- [x] 3.2 commit / push で Draft PR #29 を更新する
