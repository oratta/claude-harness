# Tasks: workflow-exec

> **実装規律**: タスク 1 完了後の全タスクは `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` を Workflow ツール仕様の一次ソースとする。記憶・推測でシグネチャを書かない。reference に無い挙動が必要になったら、追加の実機検証で reference を更新してから実装する。

## 1. Workflow ツールの実機検証（最初のタスク・他の全タスクの前提）

- [ ] 1.1 最小の hello-world workflow を 1 本起動し、`agent` / `pipeline` / `parallel` の引数、`opts` で渡せるキー（schema / model / agentType 等）、`budget` API、meta ピュアリテラル / Date.now 不可 / ネスト 1 段制約の挙動を観測する
- [ ] 1.2 中断 → `resumeFromRunId` 再開を実機で行い、完了済みステップのスキップ粒度と runId の取得方法を観測する
- [ ] 1.3 観測結果（実行した workflow スクリプトとその出力のエビデンス付き）を `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` に固定する。以降の実装はこのファイルを一次ソースとし、記憶・推測でシグネチャを書かない旨を同ファイル冒頭に明記する

## 2. JSON Schema 外部化

- [ ] 2.1 `plugins/longrun/schemas/builder-report.schema.json` を作成（コミットハッシュ / テスト結果 / 完了タスク）
- [ ] 2.2 `plugins/longrun/schemas/verifier-score.schema.json` を作成（functionality / quality / completeness / UX、各 0-100）
- [ ] 2.3 `plugins/longrun/schemas/reviewer-verdict.schema.json` を作成（status: APPROVE|REQUEST_CHANGES + findings[]）
- [ ] 2.4 `jq . plugins/longrun/schemas/*.schema.json` の構文検証を bats テストとして `plugins/longrun/tests/` に新設する

## 3. Workflow スクリプトテンプレートと exec の全面書き換え

- [ ] 3.1 Workflow スクリプトテンプレートを `plugins/longrun/templates/` 配下に作成する（meta.phases で Review → Build → Verify、`agent(prompt, {schema})` で schema 強制、builder agentType をパラメータ化しデフォルト `longrun:longrun-builder`、Date.now()/Math.random()/argless new Date() 不使用・タイムスタンプ args 注入・ネスト 1 段以内）
- [ ] 3.2 Verify ループを while + 明示上限 3 周 + `budget.remaining()` ガードで実装し、上限到達/budget 枯渇時に状態を構造化して返して停止する形にする
- [ ] 3.3 承認ゲート（Build Contract 承認 / Feedback Tier 確認）で workflow を分割し、メインループに戻って AskUserQuestion → 次 workflow 起動とする制御フローを exec.md に定義する
- [ ] 3.4 `plugins/longrun/commands/exec.md` を全面書き換え: Step 0（権限モード検査: acceptEdits 未満なら切り替え案内、change-1 の縮退モード分岐は維持）→ plan.md 読込 → テンプレートから workflow スクリプト生成 → 起動 → runId を `_longruns/<run>/` 内に記録。orchestrator SKILL.md インライン展開と末尾の「実行中の進捗確認」セクション（/longrun:status / openspec list 案内）を除去する
- [ ] 3.5 exec.md に Workflow 起動の opt-in 整理を明記する（slash command 起動は「ユーザーが起動した slash command の指示で呼ぶ」要件に該当し追加確認不要）
- [ ] 3.6 再開フローを exec.md に実装する: 記録済み runId があれば `resumeFromRunId` を一次手段として再開（完了済み change の builder を再実行しない）。checkpoint.md は人間向け監査ログとして書き続け、機械可読パースのコードパスを残さない
- [ ] 3.7 `plugins/lr/commands/e.md` を新 exec.md への単純委譲として整合させる（orchestrator への言及を除去）
- [ ] 3.8 生成スクリプトの静的検証 bats を追加する（禁止 API 不使用・ネスト段数・schema 参照パスの存在確認）

## 4. 旧コマンド削除と orchestrator 解体

- [ ] 4.1 `plugins/longrun/commands/status.md` `plugins/longrun/commands/decisions.md` `plugins/lr/commands/s.md` `plugins/lr/commands/d.md` を削除する
- [ ] 4.2 `plugins/longrun/skills/longrun-orchestrator/` を削除する（ロジックはタスク 3 で exec + テンプレートへ移管済みであることを確認）
- [ ] 4.3 `plugins/lr/.claude-plugin/plugin.json` の commands[]（s.md / d.md）と description（`/lr:s, /lr:d` 文字列）を更新する
- [ ] 4.4 `plugins/longrun/.claude-plugin/plugin.json` の commands[]（status.md / decisions.md）・skills[]（longrun-orchestrator）を更新し、description から旧記述（`v5.2`・`longrun-orchestrator`・`--mode=mvp`・`SKILL.md インライン実行` への言及）を除去して Workflow 化後の実態に書き換える（orchestrator 言及の残存は legacy-command-removal spec の MUST NOT 違反となる）
- [ ] 4.5 `.claude-plugin/marketplace.json` の lr / longrun エントリの description から `/lr:s, /lr:d` 等の残存文字列を除去する
- [ ] 4.6 `plugins/longrun/README.md` のコマンド表から status / decisions / s / d の行を削除し、進捗確認の代替（`/workflows` ライブビュー、decisions.md の直接 Read）と v6.0.0 移行ノートを記載する
- [ ] 4.7 残存参照ゼロを grep で検証する（`/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` / status.md / decisions.md / orchestrator が plugins/longrun/（`plugins/longrun/.claude-plugin/plugin.json` 含む）・plugins/lr/・.claude-plugin/marketplace.json で 0 件）。この grep を bats テスト化する
- [ ] 4.8 backlog の Skill 命名規則リファクタリングから orchestrator 分を消し込む

## 5. バージョン同期と統合検証

- [ ] 5.1 longrun を着手時点の現行 version を起点に 6.0.0 へ bump する（change-1 マージ済みなら 5.3.0 起点、未マージなら現行値（5.2.0）起点。最終的に 6.0.0 に揃える）。lr は 5.1.1 → 6.0.0。各プラグインは plugin.json と marketplace.json plugins[] の **2 箇所**を同期する（marketplace.json の top-level version はマーケットプレイス全体の version（現 2.5.1）であり個別プラグインのものではない。top-level を上げるか否かは別途判断）。lr の bump 漏れに注意。`jq .` で全 JSON の構文検証
- [ ] 5.2 最小 fixture plan（1 change / 1 タスク）を `plugins/longrun/tests/fixtures/` に作成し、Review → Build → Verify が 1 周完走して runId が記録されることを確認してログに残す（受け入れ条件 8）
- [ ] 5.3 Verify ループを意図的に FAIL させる fixture で、上限 3 周到達で必ず停止し状態が報告されることを検証する（受け入れ条件 9）
- [ ] 5.4 中断 → `resumeFromRunId` 再開で完了済み change の builder agent が再実行されないことを検証する（受け入れ条件 10）
- [ ] 5.5 schema 不適合の成果物 fixture（builder レポート / verifier スコア / reviewer 判定それぞれの不正形式）を与え、Workflow の schema 検証層が拒否して散文による無言の受理が起きないことを bats で検証する（受け入れ条件 8a 対応。spec「不正形式の成果物が機構的に拒否される」Scenario の検証タスク）
- [ ] 5.6 `bats plugins/longrun/tests/` フルスイートが全 PASS することを確認する
