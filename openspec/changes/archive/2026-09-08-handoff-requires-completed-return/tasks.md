## 1. spec delta

- [x] 1.1 `dev-workflow-execution-strategy` の「サブエージェントのコンテキスト上限と手渡し」要件に MODIFIED delta（無条件の再開禁止と条件付き手渡し許可の分離、`工程完了:`/`工程中断:` 宣言契約、停止指示〜停止確認、ノンブロッキング待ち、unmanned のサイクル終了）
- [x] 1.2 `dev-workflow-develop` の「本体はオーケストレータ専任でコードもレビューも書かない」要件に MODIFIED delta（同一 worktree の同一役割は常に 1 人）
- [x] 1.3 R1 2 周目の指摘（禁止対象を「作業継続の SendMessage（再開）」に絞る）を spec delta の文言に反映する

## 2. decision-criteria.md 改訂（正本）

- [x] 2.1 「コンテキスト上限（サブエージェントの手渡し）」節に、exit 2 の無条件再開禁止（作業継続の SendMessage のみが対象）と `工程完了:` を条件とする手渡し許可を分けて追記する
- [x] 2.2 `工程完了: <工程名>` / `工程中断: <理由>` の 1 行目宣言契約（正本は worker.md）へのポインタを追記する
- [x] 2.3 前任が動作中に交代させる場合の手順（停止指示 → 停止確認 → spawn。停止確認待ちはノンブロッキング、unmanned は待ち続けずサイクルを終える）を追記する

## 3. worker.md / gate-runner.md 改訂

- [x] 3.1 worker.md「コンテキスト上限と手渡し」節の W 側の義務に、return の 1 行目を `工程完了: <工程名>` / `工程中断: <理由>` に完全一致させる規則（書式は `仕様化判断:` と同型）を追記する
- [x] 3.2 worker.md に、自分が起動したバックグラウンドコマンドが完了していない状態で `工程完了:` を宣言してはならないこと、成果一覧を併記していても未完了なら `工程中断:` にすることを追記する
- [x] 3.3 gate-runner.md に、G の return の 1 行目も同じ宣言契約に従うこと（`## Gate Result` 本文の前に 1 行目として置く）を追記する

## 4. SKILL.md 改訂

- [x] 4.1 1 ループ (3)(4) の「再開前に測り、上限超なら手渡し」の記述に、手渡しは前任の `工程完了:` return が条件であることを示す短いポインタを追加する
- [x] 4.2 「本体の役割」節・複数 change 並列の記述に、並列に起こしてよい役割は別々の worktree を持つものに限ること（同一 worktree に同一役割は常に 1 人）を追記する

## 5. escalation-tripwires.md

- [x] 5.1 トリップワイヤー 4（コンテキスト上限）に、手渡しは前任の `工程完了:` return が条件であること（1〜2 行、詳細は decision-criteria.md へのポインタ）を追記する

## 6. 周辺同期

- [x] 6.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の version bump

## 7. テスト

- [x] 7.1 新規 `plugins/dev-workflow/tests/handoff-declaration.bats` で、宣言契約・無条件再開禁止・条件付き手渡し・同一 worktree 制約の記述を grep で固定する
- [x] 7.2 このリポジトリのテストスイート（`bats` 等。実行方法は `CONTRIBUTING.md` / `AGENTS.md` で確認）を実行し、既存テスト（`plugins/dev-workflow/tests/subagent-context.bats` を含む）と新規テストが通ることを確認する（`bats plugins/dev-workflow/tests/ tests/marketplace-sync.bats` → 431 件全通過）

## 8. デプロイ後（マージ後の運用）

- [ ] 8.1 change を archive し `openspec/specs/` に delta を sync する
