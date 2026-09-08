## 1. spec delta

- [x] 1.1 `dev-workflow-execution-strategy` の「サブエージェントのコンテキスト上限と手渡し」要件に MODIFIED delta（手渡し可否は前任の return が条件・idle ≠ return の区別・見分け方・前任稼働中の停止手順・同一作業ディレクトリの同時実行数は常に 1）

## 2. decision-criteria.md 改訂（正本）

- [x] 2.1 「コンテキスト上限（サブエージェントの手渡し）」節に手渡し可否の前提条件を追記
- [x] 2.2 idle と return の区別・見分け方を追記
- [x] 2.3 前任が動作中に交代させる場合の手順（停止指示 → 停止確認 → spawn）を追記
- [x] 2.4 同一作業ディレクトリでの同時実行数は常に 1 であることを明記（別 worktree の並列とは矛盾しないことも明記）

## 3. SKILL.md 改訂

- [x] 3.1 1 ループ (3)(4) の「再開前に測り、上限超なら手渡し」の記述に、手渡しは前任の return が条件であることを示す短いポインタを追加

## 4. escalation-tripwires.md

- [x] 4.1 トリップワイヤー 4（コンテキスト上限）への追記要否を判断し、判断内容を記録する

## 5. 周辺同期

- [x] 5.1 `plugins/dev-workflow/.claude-plugin/plugin.json` version bump + description 更新（必要なら）

## 6. デプロイ後（マージ後の運用）

- [ ] 6.1 change を archive し `openspec/specs/` に delta を sync する
