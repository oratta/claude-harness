# workflow-exec — exec コマンドによる Workflow スクリプト生成・起動

## ADDED Requirements

### Requirement: exec は plan.md から Workflow スクリプトを生成・起動する
`/longrun:exec`（および `/lr:e` 経由の委譲）は、ランディレクトリの plan.md を読んだ後、Workflow スクリプトを生成して起動しなければならない（MUST）。スクリプトは `meta.phases` で Review → Build → Verify のフェーズを表現し、既存 agent 定義は `agentType: 'longrun:longrun-builder'` 等の参照で再利用しなければならない（MUST）。`plugins/longrun/agents/*.md` の 7 agent 定義を書き直してはならない（MUST NOT）。

#### Scenario: 最小 fixture plan で Review → Build → Verify が 1 周完走する
- **WHEN** 最小 fixture plan（1 change / 1 タスク）を対象に `/longrun:exec` を実行する
- **THEN** 生成された workflow スクリプトが構文検証と schema 検証を通る
- **THEN** Review → Build → Verify が 1 周完走し、runId が `_longruns/<run>/` 内に記録される
- **THEN** builder がこの完走をログ（エビデンス）として残す

#### Scenario: 生成スクリプトが Workflow ツールの制約を遵守する
- **WHEN** 生成された workflow スクリプトを静的に検査する
- **THEN** `Date.now()` / `Math.random()` / 引数なし `new Date()` が含まれない（タイムスタンプは args 注入）
- **THEN** workflow のネストは 1 段までに収まっている

### Requirement: サブエージェント成果物を JSON Schema で強制する
exec が生成する Workflow スクリプトは、サブエージェント呼び出しを `agent(prompt, {schema})` 形式で行い、builder 完了レポート（コミットハッシュ / テスト結果 / 完了タスク）・verifier 4 軸スコア（functionality / quality / completeness / UX、各 0-100）・reviewer 判定（status: APPROVE|REQUEST_CHANGES + findings[]）を JSON Schema で強制しなければならない（MUST）。schema は `plugins/longrun/schemas/*.schema.json` に外部化し、スクリプトやプロンプトにインライン重複させてはならない（MUST NOT）。

#### Scenario: schema 群が外部ファイルとして存在し構文検証を通る
- **WHEN** `jq . plugins/longrun/schemas/*.schema.json` を実行する
- **THEN** builder 完了レポート / verifier 4 軸スコア / reviewer 判定の schema が存在し、全て jq の構文検証を通る

#### Scenario: 不正形式の成果物が機構的に拒否される
- **WHEN** サブエージェントが schema に適合しない成果物を返す
- **THEN** Workflow ツールの schema 検証層がこれを検出し、散文パースによる無言の受理は発生しない

### Requirement: exec Step 0 で権限モードを検査する
exec は workflow 起動前の Step 0 で現在の権限モードを検査し、`acceptEdits` 未満の場合はユーザーに切り替えを案内してから起動しなければならない（MUST）。

#### Scenario: acceptEdits 未満で起動した場合に切り替え案内が出る
- **WHEN** 権限モードが `acceptEdits` 未満（default 等）の状態で `/longrun:exec` を実行する
- **THEN** exec は workflow を起動する前に権限モードの切り替えをユーザーに案内する

#### Scenario: acceptEdits 以上では検査を通過して起動に進む
- **WHEN** 権限モードが `acceptEdits` 以上の状態で `/longrun:exec` を実行する
- **THEN** 権限検査を通過し、追加の案内なしに後続ステップへ進む

### Requirement: ユーザー対話境界で workflow を分割する
Build Contract 承認と Feedback Tier 確認のようにユーザー対話が必要な境界では、workflow を分割してメインループに戻り、AskUserQuestion を実行してから次の workflow を起動しなければならない（MUST）。workflow 内の agent から AskUserQuestion を行ってはならない（MUST NOT）。

#### Scenario: Build Contract 承認ゲートでメインループに戻る
- **WHEN** Review フェーズの reviewer 判定が完了し Build Contract の承認が必要になる
- **THEN** 実行中の workflow はそこで完了し、メインループが AskUserQuestion で承認を取得した後に Build 以降の workflow を起動する

#### Scenario: Feedback Tier 確認でメインループに戻る
- **WHEN** Verify 完了後にユーザーフィードバックの Tier 確認が必要になる
- **THEN** workflow はメインループに制御を戻し、AskUserQuestion で確認を取得してから後続処理を行う

### Requirement: builder の agentType をパラメータ化する
Workflow スクリプト生成時、Build フェーズで使用する builder の agentType はパラメータとして扱い、未指定時はデフォルト `longrun:longrun-builder` に固定しなければならない（MUST）。本 change ではデフォルト以外の値の提供は行わない（Codex Builder Phase 2 の受け皿のみ用意する）。

#### Scenario: 未指定時はデフォルト builder が使われる
- **WHEN** agentType の指定なしで exec が workflow スクリプトを生成する
- **THEN** Build フェーズの agent 呼び出しは `agentType: 'longrun:longrun-builder'` で生成される

### Requirement: slash command 起動は Workflow 起動の追加確認を不要とする
exec のドキュメント内に、`/lr:e` / `/longrun:exec` の slash command 起動は Workflow ツールの「ユーザーが起動した slash command の指示で呼ぶ」要件に該当するため追加確認は不要である、と明記しなければならない（MUST）。

#### Scenario: exec.md に opt-in 整理が明記されている
- **WHEN** 書き換え後の `plugins/longrun/commands/exec.md` を確認する
- **THEN** slash command 起動では Workflow 起動の追加確認が不要である旨が明記されている

### Requirement: /lr:e は exec.md への単純委譲とする
`/lr:e` は `plugins/longrun/commands/exec.md` を Read してインライン実行する単純委譲でなければならない（MUST）。委譲先の exec.md からは orchestrator SKILL.md のインライン展開構造を廃止し、Workflow スクリプト生成・起動の手順に置き換える（orchestrator への言及を残してはならない（MUST NOT））。

#### Scenario: /lr:e 経由で新 exec が動く
- **WHEN** `/lr:e` を実行する
- **THEN** e.md は exec.md を読み込んでインライン実行し、exec.md の手順（権限検査 → plan.md 読込 → workflow 生成・起動）がそのまま動く
- **THEN** e.md / exec.md のいずれにも longrun-orchestrator への参照が残っていない
