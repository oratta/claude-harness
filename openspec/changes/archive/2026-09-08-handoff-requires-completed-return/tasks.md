## 1. spec delta

- [x] 1.1 `dev-workflow-execution-strategy` の「サブエージェントのコンテキスト上限と手渡し」要件に MODIFIED delta（無条件の再開禁止と条件付き手渡し許可の分離、`工程完了:`/`工程中断:` 宣言契約、停止指示〜停止確認、ノンブロッキング待ち、unmanned のサイクル終了）
- [x] 1.2 `dev-workflow-develop` の「本体はオーケストレータ専任でコードもレビューも書かない」要件に MODIFIED delta（同一 worktree の同一役割は常に 1 人）
- [x] 1.3 R1 2 周目の指摘（禁止対象を「作業継続の SendMessage（再開）」に絞る）を spec delta の文言に反映する
- [x] 1.4 `dev-workflow-develop` の「役割のモデルは事前分類と残量モードで決める」要件に重複していた無条件の手渡し記述を MODIFIED delta で条件付きに揃える（ゲート指摘: live spec と archive delta の両方）

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
- [x] 6.2 同じ規則を要約している重複記述を全部揃える（ゲート指摘）: `README.md`・`scripts/session-tripwires.sh` の注入文・`scripts/subagent-context.sh` のヘッダコメント・`plugin.json` の description・SKILL.md 1 ループ (3)(4)・`worker.md` の節冒頭

## 7. テスト

- [x] 7.1 新規 `plugins/dev-workflow/tests/handoff-declaration.bats` で、宣言契約・無条件再開禁止・条件付き手渡し・同一 worktree 制約の記述を grep で固定する
- [x] 7.3 同ファイルに否定アサーションを足す（ゲート指摘）: 手渡しの規則を述べる現行面（正本・live spec・この change の archive delta・README・スクリプト・plugin.json）を列挙し、旧文言（`再開せず／再開しない` に続けて手渡し・新しいエージェントを述べる形）が残っていたら落とす。手渡しに触れる面には必ず `工程完了:` の条件が書かれていることも固定する。CHANGELOG と過去の change の archive は歴史記録なので対象外
- [x] 7.2 このリポジトリのテストスイート（`bats` 等。実行方法は `CONTRIBUTING.md` / `AGENTS.md` で確認）を実行し、既存テスト（`plugins/dev-workflow/tests/subagent-context.bats` を含む）と新規テストが通ることを確認する（`bats plugins/dev-workflow/tests/ tests/marketplace-sync.bats` → 431 件全通過）

## 8. デプロイ後（マージ後の運用）

- [x] 8.1 change を archive し `openspec/specs/` に delta を sync する

## 9. 手渡し規則を 1 箇所に畳む（2026-09-09 の設計変更。spec 済み・apply 未）

- [x] 9.1 `dev-workflow-execution-strategy` の「サブエージェントのコンテキスト上限と手渡し」要件を、正本の位置・参照だけにする面の一覧・テストの形を規定する形に組み替える（live spec と archive delta の両方）
- [x] 9.2 `dev-workflow-develop` の「役割のモデルは事前分類と残量モードで決める」要件と、旧一経路のままだった Scenario「再開前にコンテキスト量を測る」「同一 worktree に同一役割を二重に spawn しない」を参照だけの形に揃える（Requirement と Scenario の内部矛盾の解消。live spec と archive delta の両方）
- [ ] 9.3 正本（`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」）に本文を集約する（①送ってよい／送ってはならない SendMessage ②手渡しを行ってよい条件 ③return の 1 行目の宣言書式と選び方の義務 ④前任が動作中のまま交代させる手順と待ち方）
- [ ] 9.4 `README.md`・`SKILL.md`・`worker.md`・`gate-runner.md`・`templates/escalation-tripwires.md`・`scripts/session-tripwires.sh` の常駐ルール文・`scripts/subagent-context.sh` のヘッダコメントを、正本への参照だけに置き換える（独自の言い換えを消す）
- [ ] 9.5 `plugins/dev-workflow/tests/handoff-declaration.bats` をホワイトリスト型に作り替える（「正本以外の面が手渡しに言及するなら、その箇所は正本への参照を含む」。面は `git ls-files` から機械的に列挙し、除外は歴史記録と change の `proposal.md` / `tasks.md` だけ）。既存の「特定の言い回しを探す」アサーション（旧文言の否定走査・文単位の 2 件・worker.md / gate-runner.md の書式 grep）は、正本に本文が集まる前提で組み直す
- [ ] 9.6 `plugins/dev-workflow/CHANGELOG.md` の 2.5.1 を、追随ではなく統合（本文 1 箇所＋参照）に合わせて書き直す
- [ ] 9.7 `bats plugins/dev-workflow/tests/ tests/marketplace-sync.bats` と `openspec validate --specs --strict` を通す
