## MODIFIED Requirements

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker.md`（W）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）・仕様レビュー結果の記録書式・「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。事前分類表の「1 周目」列は**実行役（W）の上限を `opus` とし、`fable` 行を持ってはならない**（MUST NOT。4 分類のいずれに当たっても W は `opus` 止まりで、聖域パスの `opus` は据え置き）。表には、読んで判断する役（R1・G が要求するレビュアー）が `fable` 相当の分類に当たるときは `subagent_type: dev-workflow:decider` で spawn し、`general-purpose` に `model: fable` を付けないことを明記しなければならない（MUST）。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担うことを書く（SHALL）。`worker.md` の return には「指示のどこまでやって、どこで何が起きたか」を含める義務を書かなければならない（MUST。決める役の入力契約になるため）。

`spec-reviewer.md` は 5 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合）と 2 周キャップを含む（MUST）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

#### Scenario: worker.md に記録書式と事前分類表がある
- **WHEN** `references/roles/worker.md` を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式、`gh` で記録先にコメントする手順、4 分類の事前分類表（「1 周目」列がすべて `opus` で `fable` 行が無い）、レビュアーの fable は `dev-workflow:decider` 経由であること、return に「指示のどこまでやって、どこで何が起きたか」を書く義務が書かれている

#### Scenario: spec-reviewer.md に 5 観点と 2 周キャップがある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 5 観点がすべて列挙され、2 周で確定し 3 周目の例外を設けないことが書かれている

#### Scenario: gate-runner.md は pr-review-gate を手順書として参照する
- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** pr-review-gate スキルを読んで手順 1〜5 を実行すること、Codex は `codex exec` / `codex-companion.mjs` を Bash で呼ぶこと、Codex が使えないときは `needs-reviewer`（判定・HEAD SHA・推奨モデル・受け入れ条件の所在を含む）を return して本体にレビュアーの spawn を委ねること、failed の return に原因分類を含めることが書かれている

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとのモデルを次のとおり規定しなければならない（MUST）: W は既定 `sonnet`、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか、実行側が原因の失敗ループでの昇格か、事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たれば `opus`。**W を `fable` で spawn してはならない**（MUST NOT。実行役の上限は `opus` で、強制層は `scripts/agent-model-guard.sh`）。R1 は既定 `opus`、仕様がマージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する（聖域パスだけでは上げない）。G は既定 `sonnet` で上げない（G の仕事は照合・ラベル操作で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う）。G が要求するレビュアーは既定 `opus`、対象がマージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。残量モード（`FABLE_BUDGET_MODE`）は `references/decision-criteria.md` の表に従い、`abundant` はどの役割の既定も上げず、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限とする（MUST）。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が役割の既定モデルの下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定とし、Fable 残量モードと食い違えば共有枠モードが勝つ（MUST）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）は、失敗の原因が判断側か実行側かで決める役と実行役のどちらか一方だけを上げるラダー（正本は `templates/escalation-tripwires.md`）として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測り、`DEV_WORKFLOW_CONTEXT_CAP`（既定 150000 tokens）を超えていたら再開せず、前回の return を渡して新しい W / G を spawn しなければならない（MUST。手渡し。モデルは変えない）。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が `sonnet` で上限が `opus`、R1 の既定が `opus`、G の既定が `sonnet`、事前分類（聖域パス・マージ権限・層間契約・課金/法務）で W は `opus` 止まり、R1 とレビュアーの fable は `dev-workflow:decider` 経由、`abundant` はどの役割も上げない、`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限、`SHARED_BUDGET_MODE` の `throttled` / `depleted` で `sonnet` 起点、と書かれている

#### Scenario: 失敗ループでは片方だけ上げる
- **WHEN** SKILL.md の失敗ループの記述を読む
- **THEN** 決める役と実行役のどちらを上げるかを失敗の原因分類で決め、両方同時に上げないこと、実行役の上限が `opus` であることが書かれている

#### Scenario: 再開前にコンテキスト量を測る
- **WHEN** SKILL.md の「1 ループ」節を読む
- **THEN** W / G を SendMessage で再開する前に `subagent-context.sh` で測り、上限超なら再開せず手渡し（新しい W / G を spawn）すること、G の再開も同じであることが書かれている
