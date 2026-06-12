# Verification Guide

## 環境
- 対象: CLI（Claude Code セッション内）。Web UI なし
- テスト（claude-harness）: bats plugins/longrun/tests/
- テスト（marketing-harness）: bats plugins/harvest/tests/*.bats
- 構文検証: jq . plugins/longrun/schemas/*.schema.json / jq . .claude-plugin/marketplace.json 等

## change-1: openspec-degradation

### S1: [longrun-openspec-preflight] 前提条件を満たす repo では従来どおり起動する
- WHEN: npx openspec 解決可・openspec/ ありの repo で /lr:e を実行し、Step 0 の動作モード確認で通常モードを選択する
- THEN: 従来どおり通常モードで Setup フェーズが開始され、checkpoint.md に前提条件チェックの実行結果（コマンド出力）が記録される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [longrun-openspec-preflight] npx openspec が解決できない環境で縮退モードを提案する
- WHEN: npx openspec が解決できない環境で /lr:e を実行する
- THEN: AskUserQuestion で「縮退モードで実行」か「中断して OpenSpec をセットアップ」かの選択肢が提示される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [longrun-openspec-preflight] openspec 未 init の repo で縮退モードを提案する
- WHEN: npx openspec は解決できるが openspec/ ディレクトリが無い repo で /lr:e を実行する
- THEN: AskUserQuestion で「openspec init して通常続行」「縮退モードで実行」「中断」の選択肢が提示される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [longrun-openspec-preflight] 縮退モードを承諾すると縮退 run が開始される
- WHEN: 縮退モード提案に対してユーザーが「縮退モードで実行する」を選択する
- THEN: `_longruns/<run>/.degraded-mode` マーカーが作成され、OpenSpec CLI を一切呼び出さない縮退モードで Setup フェーズが開始される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [longrun-openspec-preflight] 中断を選択するとセットアップ案内が表示される
- WHEN: 縮退モード提案に対してユーザーが「中断する」を選択する
- THEN: run は開始されず、OpenSpec のインストール / init 手順の案内が表示されて exec が終了する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [longrun-openspec-preflight] ユーザーが OpenSpec 不要と明示して縮退モードで実行する
- WHEN: preflight 結果 OK の repo で /lr:e を実行し、Step 0 の動作モード確認で「縮退モード（OpenSpec を使わない）」を選択する
- THEN: 縮退マーカーが作成され、縮退モードで run が開始される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [longrun-openspec-preflight] 通常モードの run は従来と同一の成果物を生成する
- WHEN: openspec init 済みの repo で /lr:e を実行し、Step 0 で通常モードを選択して run を完走させる
- THEN: OpenSpec change・checkpoint.md・verification-guide.md が従来バージョン（5.2.0）と同一のパス・形式で生成され、縮退マーカーは作成されない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [longrun-degraded-run-artifacts] 縮退 run で proposal / tasks 相当が run ディレクトリに生成される
- WHEN: 縮退モードで run を開始し、Setup フェーズの change 分解が完了する
- THEN: 各 change の proposal.md / tasks.md 相当が `_longruns/<run>/specs/<change-name>/` 配下に生成され、tasks はチェックボックス形式で Build フェーズから参照できる
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [longrun-degraded-run-artifacts] 縮退 run は openspec ディレクトリに書き込まない
- WHEN: openspec 未 init の repo で縮退 run を完走させる
- THEN: repo 内に openspec/ ディレクトリは作成されず、生成物はすべて `_longruns/<run>/` 配下に収まる
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [longrun-degraded-run-artifacts] 縮退 run で verification-guide が生成される
- WHEN: 縮退モードの run が Verify フェーズを完了して Feedback フェーズに入る
- THEN: `_longruns/<run>/verification-guide.md` が通常モードと同等の WHEN/THEN チェックリスト形式で生成され、動作確認手順として提示される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [longrun-degraded-run-artifacts] コマンド不在環境で縮退 run が全フェーズ完走する
- WHEN: npx openspec が解決できない環境で縮退モードを承諾して run を実行し、Archive フェーズまで進める
- THEN: OpenSpec CLI 起因のエラーなしで全フェーズが完了し、ランディレクトリのみ `_longruns/` のアーカイブ先に移動される（openspec/changes/archive/ への移動は発生しない）
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [longrun-feedback-backlog-fallback] 縮退 run のフィードバックで Tier 3 が run 内 backlog に記録される
- WHEN: 縮退 run の動作確認後、ユーザーが /lr:f でスコープ外の新規要件を含むフィードバックを伝える
- THEN: Tier 3 に分類され `_longruns/<run>/backlog.md` に追記され、記録先が明示される。openspec/backlog.md は作成・変更されない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [longrun-feedback-backlog-fallback] 通常 run のフィードバックで Tier 3 が openspec backlog に記録される
- WHEN: 通常モード（openspec あり）の run でユーザーが /lr:f でスコープ外の新規要件を含むフィードバックを伝える
- THEN: Tier 3 に分類され、従来どおり openspec/backlog.md に追記される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-2: workflow-exec

### S1: [workflow-tool-reference] 実機検証結果がエビデンス付きで記録されている
- WHEN: 実装タスクの着手前に `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` を確認する
- THEN: 実際に起動した hello-world workflow のスクリプトと実行出力が記録され、agent/pipeline/parallel のシグネチャ・opts キー・resumeFromRunId・meta ピュアリテラル / Date.now 不可 / ネスト 1 段の各制約が確定事項として記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [workflow-tool-reference] 実装が reference に基づいて行われる
- WHEN: workflow スクリプト生成ロジックを実装・レビューする
- THEN: 使用している API シグネチャ・opts キー・制約が全て workflow-tool-reference.md に記載済みのものである
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [workflow-tool-reference] 未記載の挙動は再検証してから使う
- WHEN: 実装中に reference に記載のない Workflow ツールの挙動が必要になる
- THEN: 先に実機検証を行い、エビデンス付きで reference を更新してから実装に使用する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [workflow-exec] 最小 fixture plan で Review → Build → Verify が 1 周完走する
- WHEN: 最小 fixture plan（1 change / 1 タスク）を対象に /longrun:exec を実行する
- THEN: 生成 workflow スクリプトが構文検証と schema 検証を通り、Review → Build → Verify が 1 周完走して runId が `_longruns/<run>/` 内に記録され、builder が完走エビデンスをログに残す
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [workflow-exec] 生成スクリプトが Workflow ツールの制約を遵守する
- WHEN: 生成された workflow スクリプトを静的に検査する
- THEN: Date.now() / Math.random() / 引数なし new Date() が含まれず（タイムスタンプは args 注入）、workflow のネストは 1 段までに収まっている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [workflow-exec] schema 群が外部ファイルとして存在し構文検証を通る
- WHEN: `jq . plugins/longrun/schemas/*.schema.json` を実行する
- THEN: builder 完了レポート / verifier 4 軸スコア / reviewer 判定の schema が存在し、全て jq の構文検証を通る
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [workflow-exec] 不正形式の成果物が機構的に拒否される
- WHEN: サブエージェントが schema に適合しない成果物を返す
- THEN: Workflow ツールの schema 検証層がこれを検出し、散文パースによる無言の受理は発生しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [workflow-exec] acceptEdits 未満で起動した場合に切り替え案内が出る
- WHEN: 権限モードが acceptEdits 未満（default 等）の状態で /longrun:exec を実行する
- THEN: exec は workflow を起動する前に権限モードの切り替えをユーザーに案内する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [workflow-exec] acceptEdits 以上では検査を通過して起動に進む
- WHEN: 権限モードが acceptEdits 以上の状態で /longrun:exec を実行する
- THEN: 権限検査を通過し、追加の案内なしに後続ステップへ進む
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [workflow-exec] Build Contract 承認ゲートでメインループに戻る
- WHEN: Review フェーズの reviewer 判定が完了し Build Contract の承認が必要になる
- THEN: 実行中の workflow はそこで完了し、メインループが AskUserQuestion で承認を取得した後に Build 以降の workflow を起動する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [workflow-exec] Feedback Tier 確認でメインループに戻る
- WHEN: Verify 完了後にユーザーフィードバックの Tier 確認が必要になる
- THEN: workflow はメインループに制御を戻し、AskUserQuestion で確認を取得してから後続処理を行う
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [workflow-exec] 未指定時はデフォルト builder が使われる
- WHEN: agentType の指定なしで exec が workflow スクリプトを生成する
- THEN: Build フェーズの agent 呼び出しは `agentType: 'longrun:longrun-builder'` で生成される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [workflow-exec] exec.md に opt-in 整理が明記されている
- WHEN: 書き換え後の `plugins/longrun/commands/exec.md` を確認する
- THEN: slash command 起動では Workflow 起動の追加確認が不要である旨が明記されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [workflow-exec] /lr:e 経由で新 exec が動く
- WHEN: /lr:e を実行する
- THEN: e.md は exec.md を読み込んでインライン実行し、exec.md の手順（権限検査 → plan.md 読込 → workflow 生成・起動）がそのまま動く。両ファイルに longrun-orchestrator への参照が残っていない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [workflow-run-control] 上限 3 周到達で必ず停止し状態が報告される
- WHEN: verifier の FAIL が続き Verify → Build 修正のループが 3 周に到達する
- THEN: ループは必ず停止し（4 周目は実行されない）、到達時点の検証状態と残課題がユーザーに報告される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [workflow-run-control] budget 枯渇でループが早期停止する
- WHEN: Verify ループの周回前チェックで budget.remaining() が不足している
- THEN: 上限 3 周未満でもループを停止し、budget 枯渇による停止であることをユーザーに報告する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [workflow-run-control] 再開時に完了済み change の builder が再実行されない
- WHEN: 実行を中断した後、記録済み runId を使って resumeFromRunId で再開する
- THEN: 完了済み change の builder agent は再実行されず、未完了のステップから実行が継続される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [workflow-run-control] runId がランディレクトリに記録される
- WHEN: exec が workflow を起動する
- THEN: その workflow の runId が `_longruns/<run>/` 内のファイルに記録され、後続の再開で参照できる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [workflow-run-control] 実行中も監査ログとして更新され続ける
- WHEN: workflow の各フェーズが進行する
- THEN: checkpoint.md にフェーズの進捗が人間が読める形式で追記される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [workflow-run-control] 機械可読パースのコードパスが存在しない
- WHEN: 書き換え後の exec.md・スクリプトテンプレート・同梱スクリプトを検査する
- THEN: checkpoint.md を grep/sed/正規表現で解析して制御フローを決めるロジックが存在しない（旧形式の互換読み取りも提供しない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [legacy-command-removal] コマンドファイル 4 本が存在しない
- WHEN: 書き換え後のリポジトリを検査する
- THEN: plugins/longrun/commands/status.md、decisions.md、plugins/lr/commands/s.md、d.md が存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [legacy-command-removal] grep で残存参照が 0 件である
- WHEN: plugins/longrun/・plugins/lr/ 配下の全 plugin.json / README / commands/*.md と .claude-plugin/marketplace.json に対して /longrun:status /longrun:decisions /lr:s /lr:d（およびパス参照）を grep する
- THEN: ヒットが 0 件である（lr plugin.json の commands[] / description、marketplace.json の description、longrun README のコマンド表、exec.md 末尾の進捗確認セクションが全て除去されている）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [legacy-command-removal] orchestrator スキルが存在せずロジックが移管されている
- WHEN: 書き換え後のリポジトリを検査する
- THEN: plugins/longrun/skills/longrun-orchestrator/ が存在せず plugin.json skills[] からも除去され、Review → Build → Verify のオーケストレーションは exec.md とスクリプトテンプレートで完結している
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [legacy-command-removal] 命名規則リファクタが backlog から消化される
- WHEN: 解体完了後に backlog（Skill 命名規則リファクタリング）を確認する
- THEN: orchestrator 分の項目が消し込まれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S25: [legacy-command-removal] longrun と lr の version 同期が取れている
- WHEN: plugins/longrun/.claude-plugin/plugin.json、plugins/lr/.claude-plugin/plugin.json、.claude-plugin/marketplace.json の plugins[]（longrun / lr エントリ）を比較する
- THEN: longrun・lr とも全箇所 6.0.0 で一致し（lr の bump 漏れなし）、全 JSON が jq の構文検証を通る
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-3: mvp-plan-split

### S1: [longrun-mvp-plan-skill] Skill directory and frontmatter
- WHEN: `plugins/longrun/skills/longrun-mvp-plan/SKILL.md` を開く
- THEN: `name: longrun-mvp-plan`・非空 description・version・allowed-tools（Read / Write / Grep / AskUserQuestion / Agent dispatch 能力を最低限含む）を持つ有効な YAML frontmatter でファイルが存在する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [longrun-mvp-plan-skill] plugin.json registration
- WHEN: `plugins/longrun/.claude-plugin/plugin.json` の skills 配列を読む
- THEN: 既存エントリに加えて `./skills/longrun-mvp-plan` が含まれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [longrun-mvp-plan-skill] Noun-form naming is respected
- WHEN: スキル名を longrun 命名規則と照合する
- THEN: `longrun-mvp-plan` は -er / -or で終わらず、`longrun-mvp-planner` という名前のファイルは skills/ 配下に存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [longrun-mvp-plan-skill] Command file content
- WHEN: `plugins/longrun/commands/mvp.md` を開く
- THEN: Skill ツールで `longrun:longrun-mvp-plan` を $ARGUMENTS 付きで起動する旨と、Agent ツールを使わない旨が明記されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [longrun-mvp-plan-skill] Command registration
- WHEN: `plugins/longrun/.claude-plugin/plugin.json` の commands 配列を読む
- THEN: `./commands/mvp.md` が含まれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [longrun-mvp-plan-skill] No Agent-tool misfire
- WHEN: ユーザーが `/longrun:mvp <任意の引数>` を実行する
- THEN: Skill ツール経由で longrun-mvp-plan スキルが開始され、`Agent type 'longrun:longrun-mvp-plan' not found` エラーが発生しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [longrun-mvp-plan-skill] Shortcut file content
- WHEN: `plugins/lr/commands/m.md` を開く
- THEN: Skill ツールで `longrun:longrun-mvp-plan` に $ARGUMENTS を転送して委譲する旨と、Agent ツールを使わない旨が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [longrun-mvp-plan-skill] Shortcut registration
- WHEN: `plugins/lr/.claude-plugin/plugin.json` の commands 配列を読む
- THEN: `./commands/m.md` が含まれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [longrun-mvp-plan-skill] Flow completion produces an MVP plan
- WHEN: `/longrun:mvp <brain dump>`（または /lr:m）を実行し、インタビューとレビューのステップを完了する
- THEN: `templates/plan-template-mvp.md` に従う `_longruns/YYYY-MM-DD_slug/plan.md` が生成され、旧 `--mode=mvp` フローの成果物と同一形式である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [longrun-mvp-plan-skill] Full-mode-only steps are absent
- WHEN: `plugins/longrun/skills/longrun-mvp-plan/SKILL.md` を走査する
- THEN: openspec/backlog.md の読み込み・既存 OpenSpec changes の照合・longrun-reviewer Agent の起動・フルテンプレート plan-template.md の読み込み指示が本文に存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [longrun-mvp-plan-skill] Orchestration stays Agent-parallel
- WHEN: スキル本文のオーケストレーション指示を走査する
- THEN: サブエージェント起動は Agent ツール（並列は単一メッセージ内複数 tool_use）で指定され、Workflow ツール使用の指示は現れない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [longrun-mvp-plan-skill] Research step names the agent
- WHEN: SKILL.md のリサーチステップを読む
- THEN: リテラル文字列 `longrun-mvp-research` が Agent ツール起動のターゲットとして現れる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [longrun-mvp-plan-skill] Prompt template demands dual sections and Search Audit
- WHEN: リサーチステップ内のプロンプトテンプレートを読む
- THEN: 1 レポートに `## 類似サービス事例` と `## 実装パターン` の両方を含め、末尾に `## Search Audit`（クエリ数付き）を付ける指示がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [longrun-mvp-plan-skill] Both reviewers named
- WHEN: レビューステップを読む
- THEN: `longrun-mvp-plan-reviewer` と `longrun-mvp-bestpractice-reviewer` の両リテラルが、それぞれ Agent ツール起動のターゲットとして現れる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [longrun-mvp-plan-skill] Parallel invocation is explicit
- WHEN: レビューステップの周辺文章を読む
- THEN: 2 つの Agent ツール呼び出しを 1 つの assistant メッセージ内（複数 tool_use）で発行することが必須とされ、片方を待ってから他方を呼ぶ指示が無い
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [longrun-mvp-plan-skill] Marker is the first content
- WHEN: スキルが `_longruns/<dir>/plan.md` を生成する
- THEN: ファイル先頭（最初の見出しより前）にリテラル HTML コメント `<!-- mvp-mode -->` が含まれる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [longrun-mvp-plan-skill] Archive compatibility is preserved
- WHEN: longrun-mvp-plan が生成した plan.md を持つディレクトリに /longrun:archive を実行する
- THEN: 既存のマーカー検出が MVP 分岐（OpenSpec change アーカイブをスキップしランディレクトリのみアーカイブ）を発動し、archive 側の改修は不要のまま動作する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [longrun-mvp-plan-skill] Checklist is explicit
- WHEN: Validation ステップを読む
- THEN: 7 必須セクション名（ゴール / 技術要件 / スコープ / 受け入れ条件 / 動作確認方法 / 調査結果サマリ / レビュー結果サマリ）が 1 項目ずつのチェックリストとして現れ、マーカー存在チェックも含まれる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [longrun-mvp-plan-skill] Missing section blocks save
- WHEN: Validation で 7 セクションのいずれかの欠落が見つかる
- THEN: 保存前に plan.md を修復する指示（GATE セマンティクス）が適用され、欠落したままの保存は行われない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [longrun-mvp-plan-skill] No backlog or change writes
- WHEN: ハンドオフステップを読む
- THEN: openspec/backlog.md の編集や OpenSpec change 作成ツールの起動を指示する記述が本文に存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [longrun-mvp-plan-skill] Handoff message present
- WHEN: ユーザー確認後にフローがハンドオフステップに到達する
- THEN: 保存済み plan.md のパスを名指しし、人間実装パスを案内するハンドオフメッセージが出力される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [longrun-mvp-plan-skill] Agent prose references the new owner
- WHEN: 3 つの MVP agent .md ファイルを `--mode=mvp` で grep する
- THEN: ヒットが 0 件で、各 agent の呼び出し元記述が longrun-mvp-plan スキル / /longrun:mvp コマンドを参照している
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [longrun-mvp-plan-skill] Template structure is intact
- WHEN: `plugins/longrun/templates/plan-template-mvp.md` を開く
- THEN: 先頭 `<!-- mvp-mode -->`・divergence 防止コメント（plan-template.md 参照）・8 つの H2 セクションが維持され、生成情報の mode 表記のみ `/longrun:mvp` に変わっている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [longrun-mvp-plan-skill] Agent contracts are unchanged
- WHEN: 3 つの MVP agent .md を変更前後で diff する
- THEN: 呼び出し元帰属の文章（description / 呼び出し元）のみが差分で、出力契約（レポートセクション・Search Audit・APPROVE/REQUEST_CHANGES 形式・検索上限）はテキストとして不変である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S25: [longrun-mvp-plan-skill] No cross-skill SKILL.md read
- WHEN: `plugins/longrun/skills/longrun-mvp-plan/SKILL.md` の Read 指示を走査する
- THEN: `skills/longrun-plan/SKILL.md` を読む指示が存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S26: [longrun-mvp-plan-skill] Shared reference or guarded duplication
- WHEN: Gap Analysis / Interview 方法論の提供方法を実装で検査する
- THEN: 両スキルが Read する plugins/longrun/ 配下の共有リファレンスが存在するか、またはインラインコピーそれぞれに対応ファイルを名指しした divergence 防止コメントが含まれる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S27: [longrun-mvp-plan-skill] longrun version sync
- WHEN: `plugins/longrun/.claude-plugin/plugin.json` と marketplace.json plugins[] の longrun エントリを比較する
- THEN: 両者が 6.1.0 で、longrun-plan / longrun-mvp-plan の SKILL.md frontmatter version も 6.1.0 である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S28: [longrun-mvp-plan-skill] lr version sync
- WHEN: `plugins/lr/.claude-plugin/plugin.json` と marketplace.json plugins[] の lr エントリを比較する
- THEN: 両者が 6.1.0 で一致している
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S29: [longrun-mvp-plan-skill] Marketplace top-level bump
- WHEN: `.claude-plugin/marketplace.json` の top-level version を読む
- THEN: 本 change 適用前の値より厳密に大きい
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S30: [longrun-mvp-research] Standard research invocation produces unified report
- WHEN: longrun-mvp-plan SKILL がトピック（例: 1時間で作る料理レシピ提案ツール）で agent を起動する
- THEN: 同一の検索セッションから抽出した内容で `## 類似サービス事例` と `## 実装パターン` の両見出しを含む単一レポートが出力される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S31: [longrun-mvp-research] Section is missing
- WHEN: 2 つの観点のいずれかで有用な結果が見つからない
- THEN: 該当セクションは省略されず、「該当なし」等を明示した上でレポートに必ず存在する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S32: [longrun-mvp-plan-reviewer] Plan with vague acceptance criteria
- WHEN: v0 plan の受け入れ条件が「良い感じに動く」のような計測不能な記述を含む
- THEN: 検証不能な条件を 1 件以上具体的に指摘し、具体的な書き換え案付きの REQUEST_CHANGES を出力する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S33: [longrun-mvp-plan-reviewer] Plan that explicitly mentions "1 hour" budget
- WHEN: 入力 plan が 1 時間の実装予算に言及している
- THEN: 「1 時間」をハードコード閾値として扱わず、列挙された項目（Changes / ファイル / 受け入れ条件数）に基づいてスコープを評価する（他の時間予算でも再利用可能）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S34: [longrun-mvp-plan-reviewer] Plan with internal contradiction
- WHEN: 同じ機能が「含むもの」「含まないもの」の両方に現れる、または受け入れ条件が除外スコープを参照している
- THEN: その矛盾が出力で明示的に指摘される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S35: [longrun-plan-skill] Old flag shows migration notice
- WHEN: ユーザーが `/longrun:plan --mode=mvp <args>` を実行する
- THEN: /longrun:mvp（と /lr:m）を新エントリポイントとして名指しした移行案内が出力され、Step 1〜8 は実行されず plan.md も生成されない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S36: [longrun-plan-skill] Old flag via shortcut shows the same notice
- WHEN: ユーザーが `/lr:p --mode=mvp <args>` を実行する（引数はスキルに透過転送）
- THEN: 同じ移行案内が表示され、plan.md を生成せずにフローが終了する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S37: [longrun-plan-skill] Full mode is unaffected
- WHEN: ユーザーが `/longrun:plan` を --mode フラグなし、または --mode=full で実行する
- THEN: 既存のフルモード Step 1〜8（plan-template.md 読み込み・Step 7 の longrun-reviewer Agent 起動を含む）が従来どおり実行される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S38: [longrun-plan-skill] MVP-mode section is removed from the skill body
- WHEN: `plugins/longrun/skills/longrun-plan/SKILL.md` を MVP モードのステップ定義（MVP Step 4.5 / longrun-mvp-plan-reviewer 等）で grep する
- THEN: ヒットが 0 件で、移行案内の処理のみが MVP に言及してよい
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S39: [longrun-plan-skill] MVP section is present
- WHEN: `plugins/longrun/README.md` を走査する
- THEN: MVP plan スキルを名指しし、リテラル `/longrun:mvp` を含むセクションが存在する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S40: [longrun-plan-skill] Differences from full mode are described
- WHEN: README の MVP セクションを読む
- THEN: Build Contract レビュー / TDD 強制 / Verifier 自動起動のスキップ、archive 時の OpenSpec change アーカイブのスキップという差分が最低限記述されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S41: [longrun-plan-skill] Deprecation of the old flag is documented
- WHEN: README の MVP セクションを読む
- THEN: --mode=mvp が deprecated であり、`/longrun:plan --mode=mvp` が MVP フローではなく /longrun:mvp への移行案内を出すことが記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S42: [longrun-plan-skill] Use-case guidance is generic
- WHEN: README の MVP セクションを読む
- THEN: MVP plan スキルが短時間・人間実装の MVP シナリオ向けの汎用機能であり、特定プロジェクトに紐づかないことが記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-4: model-allocation

### S1: [longrun-model-allocation] テンプレートにモデル割り当て表が存在する
- WHEN: `plugins/longrun/templates/plan-template.md` を開く
- THEN: 「モデル割り当て」セクションが存在し、`| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |` のヘッダ行を持つ Markdown 表が含まれる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [longrun-model-allocation] ユーザー編集可能である旨の案内がある
- WHEN: 「モデル割り当て」セクションの説明文を読む
- THEN: plan 確認時に表を直接編集して上書きできること、`上書き` 欄がティア欄より優先されることが記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [longrun-model-allocation] テンプレートにモデル ID がハードコードされていない
- WHEN: plan-template.md 内で `claude-` で始まるモデル ID 文字列を grep する
- THEN: 該当行は 0 件（ティア名 haiku / sonnet / inherit のみが現れる）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [longrun-model-allocation] リファレンスドキュメントが対応を定義している
- WHEN: `plugins/longrun/references/model-tiers.md` を開く
- THEN: haiku / sonnet 各ティアの `opts.model` 渡し値の対応表と、inherit が「opts.model を渡さない」ことを意味する説明が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [longrun-model-allocation] モデル ID の散在が無い
- WHEN: plugins/longrun/ 配下で references/model-tiers.md を除外して `claude-` 始まりのモデル ID を grep する
- THEN: plan-template.md・longrun-plan SKILL.md・exec.md・workflow スクリプト生成テンプレートのいずれにもヒットしない（0 件）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [longrun-model-allocation] sonnet ティアが opts.model に反映される
- WHEN: ロール verifier にティア sonnet（上書き欄空）を指定した plan.md に対して /longrun:exec を実行する
- THEN: 生成 workflow スクリプトの該当 verifier agent 呼び出しに、リファレンスで解決された sonnet ティアの値が `opts.model` として設定されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [longrun-model-allocation] inherit ティアでは opts.model を出力しない
- WHEN: ロール builder にティア inherit を指定した plan.md に対して /longrun:exec を実行する
- THEN: 生成 workflow スクリプトの該当 builder agent 呼び出しには `opts.model` キーが存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [longrun-model-allocation] 上書き欄がティア欄より優先される
- WHEN: ティア欄 haiku の行の `上書き` 欄に sonnet を記入してから /longrun:exec を実行する
- THEN: 該当 agent 呼び出しには haiku ではなく sonnet ティアの解決値が `opts.model` として設定されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [longrun-model-allocation] 未知のティア値は inherit として扱い警告する
- WHEN: ティア欄に `opus-max` のような未知の値を含む plan.md に対して /longrun:exec を実行する
- THEN: 該当行は inherit として扱われ（opts.model 無し）、「未知のティア値のため inherit として扱った」旨の警告が表示され、workflow 起動は中断されない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [longrun-model-allocation] セクション無し plan.md で exec が完走する
- WHEN: 「モデル割り当て」セクションを持たない旧形式の plan.md に対して /longrun:exec を実行する
- THEN: エラーや追加質問（AskUserQuestion）なしで workflow スクリプトが生成・起動され、全 agent 呼び出しに `opts.model` キーが存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [longrun-plan-skill] 生成された plan.md にモデル割り当て表が含まれる
- WHEN: /longrun:plan で plan.md を作成し Step 5（Synthesis）が完了する
- THEN: 「モデル割り当て」セクションが存在し、Changes分解の各 change × agent ロールごとの行にティア（haiku / sonnet / inherit）と理由が記入されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [longrun-plan-skill] SKILL.md にヒューリスティクスが明記されている
- WHEN: `plugins/longrun/skills/longrun-plan/SKILL.md` の推奨生成ステップを読む
- THEN: 「アーキレビュー・複雑 TDD → inherit」「定型検証・要約 → haiku」「リサーチ・ブラウザ・中規模実装 → sonnet」の 3 ルールと「迷ったら inherit」の保守的デフォルトが記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [longrun-plan-skill] 確信度の低いタスクは inherit に倒される
- WHEN: Synthesis 中にあるタスクがどのヒューリスティクス分類にも明確に該当しない
- THEN: 該当行のティアに inherit が記入され、理由欄に確信度が低いため保守的デフォルトを適用した旨が記載される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [longrun-plan-skill] ユーザーが plan 確認時に表を上書きできる
- WHEN: Step 8（ユーザー確認）で plan.md のモデル割り当て表の `上書き` 欄またはティア欄を直接編集する
- THEN: スキルは編集後の値をそのまま確定し、推奨値への巻き戻しや再生成を行わない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [longrun-plan-skill] Validation チェックリストにモデル割り当てが含まれる
- WHEN: SKILL.md の Step 6（Validation）のセクション存在チェックリストを読む
- THEN: 「モデル割り当て」セクションの存在確認項目がチェックリストに含まれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [longrun-plan-skill] セクション欠落時は保存前に修復される
- WHEN: Step 6 の Validation で生成済み plan.md に「モデル割り当て」セクションが無いことが検出される
- THEN: plan.md を修正してセクションを追加してから保存し、欠落したままファイルを保存しない（GATE セマンティクス）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-5: harvest-structured-output

### S1: [harvest-structured-output-conventions] StructuredOutput 規約セクションが存在する
- WHEN: `grep -cE '^##.*StructuredOutput' docs/PLUGIN-CONVENTIONS.md` を実行する
- THEN: 出力が 1 以上である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [harvest-structured-output-conventions] 4 つの規約要素が読み取れる
- WHEN: docs/PLUGIN-CONVENTIONS.md の StructuredOutput セクションを grep で検査する
- THEN: schemas/ 配置・validate-contract・リトライ/retry・形式/手続き（責務分担）の 4 要素がそれぞれ 1 件以上ヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [harvest-structured-output-conventions] sns-strategy 配下に変更がない
- WHEN: 本 change の実装 diff を `git diff --name-only` で検査する
- THEN: plugins/sns-strategy/ と plugins/vlog-album/ 配下のファイルが 1 件も含まれない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [harvest-subagent-schemas] schema 4 本が存在する
- WHEN: property / plan / researcher / evaluator の 4 schema ファイルの存在を `test -f` で確認する
- THEN: `plugins/harvest/schemas/{property,plan,researcher,evaluator}.schema.json` がすべて存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [harvest-subagent-schemas] 各 schema が jq 構文検証を通る
- WHEN: `jq empty plugins/harvest/schemas/*.schema.json`（4 本）を実行する
- THEN: exit 0 で終了する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [harvest-subagent-schemas] 各 schema が required キーを宣言している
- WHEN: `grep -l '"required"' plugins/harvest/schemas/*.schema.json | wc -l` を実行する
- THEN: 出力が 4 である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [harvest-subagent-schemas] evaluator.schema.json の status が 2 値 enum である
- WHEN: `jq -r '.. | .enum? // empty | @json' plugins/harvest/schemas/evaluator.schema.json` を実行する
- THEN: APPROVE と REQUEST_CHANGES の両方を含む enum 定義が 1 件以上出力される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [harvest-subagent-schemas] researcher.schema.json は WebSearch 回数を定義しない
- WHEN: researcher.schema.json を WebSearch で grep し、agent 定義側を検索回数規定（3 カテゴリ / 3-5 回）で grep する
- THEN: schema 側のヒットは 0 件、agent 定義側（harvest-bestprac-researcher.md）に手続き契約が 1 件以上残る
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [harvest-subagent-schemas] property.schema.json は形式のみを定義し合成手順は SKILL.md に残る
- WHEN: property.schema.json を `"final_prompts"` で、knowledge SKILL.md を「合成」で grep する
- THEN: schema 側に final_prompts キー定義が 1 件以上、SKILL.md 側に合成手順が 1 件以上残る
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [harvest-contract-validation] 正常 payload で exit 0
- WHEN: 各 contract type の正例 fixture に対して `bash plugins/harvest/scripts/validate-contract.sh <type> <fixture>` を実行する
- THEN: 4 type すべてで exit 0 で終了する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [harvest-contract-validation] 必須キー欠落 payload で非 0 終了 + stderr 理由
- WHEN: 必須キーを 1 つ欠いた不正 fixture に対して validate-contract.sh を実行する
- THEN: exit code が 0 以外で、stderr に欠落キー名を含む理由が出力される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [harvest-contract-validation] 不正 JSON（パース不能）で非 0 終了
- WHEN: JSON としてパースできないファイルに対して `validate-contract.sh property <file>` を実行する
- THEN: exit code が 0 以外である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [harvest-contract-validation] 不明 contract type で exit 2
- WHEN: `validate-contract.sh unknown-type some.json` を実行する
- THEN: exit code が 2 で、stderr または stdout に usage が表示される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [harvest-contract-validation] validate-contract.sh の単体 bats が通る（受け入れ条件 15）
- WHEN: `bats plugins/harvest/tests/validate_contract.bats` を実行する
- THEN: 全 @test が PASS する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [harvest-contract-validation] 不正形式 fixture でリトライ → フォールバックが発動する（受け入れ条件 16）
- WHEN: schema 違反 payload の fixture を validate-contract.sh に通し、SKILL.md 記載のフロー（検証 → 1 回リトライ → フォールバック）を bats で検証する
- THEN: validate-contract.sh が非 0 で失敗を検出し、knowledge / bestprac-refresh 両 SKILL.md にリトライ上限 1 回とフォールバック先（メイン逐次実行 / exit 1）が明記されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [harvest-contract-validation] knowledge のフォールバック成果物形式が現行同等
- WHEN: /harvest:knowledge のフォールバック（メイン逐次実行）パスで property.md / retrospect.md / plan.md を生成する
- THEN: property.md は YAML frontmatter（slug / date / session / git_log / final_files / mcp_servers / tools_used / final_prompts 全キー）+ markdown 本文の現行スキーマと同一形式である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [harvest-masking-atomicity] SKILL.md に tmp → mv の原子的書き出し手順が明記されている
- WHEN: knowledge SKILL.md を `.property.md.tmp` と `mv ` で grep する
- THEN: 両方とも 1 件以上ヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [harvest-masking-atomicity] redact 失敗時に property.md が生成されない
- WHEN: redact-secrets.sh が non-zero で失敗するケース（不正な raw JSON fixture）をシミュレートする
- THEN: `<session_dir>/knowledge/property.md` が存在せず、SKILL.md のエラーハンドリングに「redact 失敗時は property.md を書かない」旨が読み取れる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [harvest-masking-atomicity] 起動時クリーンアップ手順が SKILL.md に明記されている
- WHEN: knowledge SKILL.md を「クリーンアップ|cleanup」で grep する
- THEN: 出力が 1 以上で、.property.raw.json の残骸削除が Step 0 の文脈で読み取れる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [harvest-masking-atomicity] いかなる失敗パスでも翌回起動時に .property.raw.json が残らない（受け入れ条件 18）
- WHEN: 前回 run が sub agent tool error / 契約検証失敗 / redact 失敗のいずれかで中断した状態（.property.raw.json 残存）から /harvest:knowledge を再実行する
- THEN: Step 0 のクリーンアップ完了時点で .property.raw.json が存在せず、クリーンアップした旨がユーザーに通知される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [harvest-masking-atomicity] .gitignore が中間ファイルをカバーし続ける
- WHEN: `grep -E '\.property\.raw\.json|\*\.raw\.json|\.property\.raw' .gitignore` を実行する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [cooking-knowledge-unification] SKILL.md が schema 参照契約を含む
- WHEN: knowledge SKILL.md を `schemas/property.schema.json` と `schemas/plan.schema.json` で grep する
- THEN: 両マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [cooking-knowledge-unification] SKILL.md に散文契約（STATUS line / フェンス）が残存しない
- WHEN: knowledge SKILL.md を `BEGIN_RAW_JSON|END_RAW_JSON|BEGIN_PLAN_MD|END_PLAN_MD|STATUS: (property_extracted|longrun_found)` で grep -c する
- THEN: 出力が 0 である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [cooking-knowledge-unification] SKILL.md に validate-contract.sh による検証とリトライ → フォールバックが記述されている
- WHEN: knowledge SKILL.md を validate-contract.sh / リトライ / 逐次・フォールバックで grep する
- THEN: validate-contract.sh が 1 件以上、リトライ上限 1 回とメイン逐次フォールバックの記述がそれぞれ 1 件以上読み取れる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S25: [cooking-knowledge-unification] SKILL.md にフォールバック 3 ケースが grep 検出可能
- WHEN: knowledge SKILL.md を grep で検査する
- THEN: tool error・契約検証失敗（validate-contract 非 0 文脈）・空出力/empty の 3 概念がそれぞれ 1 回以上出現する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S26: [cooking-knowledge-unification] E2E で現行と同等の成果物 3 ファイルが生成される（受け入れ条件 17）
- WHEN: `/harvest:knowledge <slug>` を E2E 実行（または fixture セッションで同等手順をシミュレート）する
- THEN: knowledge/{property.md, retrospect.md, plan.md} の 3 ファイルが生成され、property.md の frontmatter が現行と同一キー集合、retrospect.md が 3 セクション（成果物 / 詰まったポイント / 次回への教訓）を持つ
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S27: [cooking-knowledge-unification] SKILL.md が main 集約方式の secret マスクを記述している
- WHEN: knowledge SKILL.md を redact-secrets.sh / .property.raw.json で grep する
- THEN: 両方 1 件以上ヒットし、.property.raw.json の文脈で「raw を削除」（rm / 削除）の文が見つかる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S28: [cooking-knowledge-unification] SKILL.md が transcript への raw 直接出力を禁止している
- WHEN: SKILL.md の property sub agent 指示テンプレを grep で検査する
- THEN: raw JSON 全文を transcript に含めない旨（envelope / 最小限の返却）の記述が 1 件以上見つかる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S29: [cooking-knowledge-unification] .gitignore が .property.raw.json をカバーする
- WHEN: `grep -E '\.property\.raw\.json|\*\.raw\.json|\.property\.raw' .gitignore` を実行する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S30: [harvest-bestprac-researcher] agent 定義が researcher.schema.json を参照している
- WHEN: `grep -cE 'researcher\.schema\.json' plugins/harvest/agents/harvest-bestprac-researcher.md` を実行する
- THEN: 出力が 1 以上である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S31: [harvest-bestprac-researcher] payload フィールドが agent 定義に列挙されている
- WHEN: agent 定義を claims / operational_cadence / goals_draft / tos_excerpts / search_audit で grep する
- THEN: 5 種類のフィールド名すべてが少なくとも 1 回ずつヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S32: [harvest-bestprac-researcher] claim あたり最低 1 source / source に url・date・grade 必須が維持されている
- WHEN: agent 定義を url / date / grade と primary / secondary / tertiary で grep する
- THEN: 前者でマッチが 3 件以上、後者は 3 語すべてが少なくとも 1 回ずつヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S33: [harvest-bestprac-researcher] tos_excerpts が 3 キーで 5 件上限であることが維持されている
- WHEN: agent 定義を section_title / quote / risk_comment / 最大 5 件 / maxItems で grep する
- THEN: マッチが 2 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S34: [harvest-bestprac-researcher] 5 セクション固定順序の散文契約が agent 定義に残存しない
- WHEN: `grep -cE '5 セクション固定|セクション固定の順序|fenced code block を.*1 つだけ' plugins/harvest/agents/harvest-bestprac-researcher.md` を実行する
- THEN: 出力が 0 である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S35: [harvest-bestprac-evaluator] agent 定義が evaluator.schema.json を参照している
- WHEN: `grep -cE 'evaluator\.schema\.json' plugins/harvest/agents/harvest-bestprac-evaluator.md` を実行する
- THEN: 出力が 1 以上である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S36: [harvest-bestprac-evaluator] status の 2 値 enum が agent 定義に明記されている
- WHEN: agent 定義を `"status"` / APPROVE / REQUEST_CHANGES で grep する
- THEN: APPROVE と REQUEST_CHANGES の両方がヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S37: [harvest-bestprac-evaluator] JSON worked example が APPROVE / REQUEST_CHANGES 両ケースで含まれる
- WHEN: agent 定義を fact_check_findings / tos_risk_findings で grep する
- THEN: 両フィールド名がそれぞれ 2 件以上ヒットする（worked example 2 つ + 契約記述）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S38: [harvest-bestprac-evaluator] 末尾 Status: リテラル行の散文契約が agent 定義に残存しない
- WHEN: `grep -cE '^Status: (APPROVE|REQUEST_CHANGES)|最後の非空行|last non-empty line' plugins/harvest/agents/harvest-bestprac-evaluator.md` を実行する
- THEN: 出力が 0 である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S39: [harvest-bestprac-evaluator] claim 単位の fact-check 粒度が definition に明記されている
- WHEN: agent 定義を「claim 単位|per-claim|claim_id|claims[]」で grep する
- THEN: マッチが 2 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S40: [harvest-bestprac-evaluator] verdict が fact_check_findings 配列の entry として返ることが明記されている
- WHEN: agent 定義を fact_check_findings と pass / fail / partial で grep する
- THEN: fact_check_findings が 1 件以上、verdict 3 値すべてがヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S41: [harvest-bestprac-evaluator] source URL の取得方法 (cache or WebSearch) が明記されている
- WHEN: agent 定義を「WebSearch|cached|researcher 出力」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S42: [harvest-bestprac-evaluator] TOS 主入力が researcher payload の tos_excerpts であることが明記されている
- WHEN: agent 定義を「tos_excerpts.*主入力|primary input.*tos_excerpts|tos_excerpts を」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S43: [harvest-bestprac-evaluator] tos_url fallback の条件と fallback_used フラグが明記されている
- WHEN: agent 定義を「tos_url.*fallback|fallback.*tos_url|不在|insufficient」と fallback_used で grep する
- THEN: 前者でマッチが 1 件以上、fallback_used も 1 件以上ヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S44: [harvest-bestprac-evaluator] TOS 全文 fetch を禁止する記述がある
- WHEN: agent 定義を「TOS 全文.*しない|MUST NOT fetch|full content|数万字」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S45: [harvest-bestprac-evaluator] REQUEST_CHANGES の 3 フィールド要件が definition に明記されている
- WHEN: agent 定義を claim_id / target_line / suggested_fix で grep する
- THEN: 3 フィールド名すべてが少なくとも 1 回ずつヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S46: [harvest-bestprac-evaluator] REQUEST_CHANGES の worked example が definition に含まれている
- WHEN: `grep -c 'REQUEST_CHANGES' plugins/harvest/agents/harvest-bestprac-evaluator.md` を実行する
- THEN: REQUEST_CHANGES への参照が 2 件以上ある（契約記述 + worked example）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S47: [harvest-bestprac-evaluator] validate-contract.sh が REQUEST_CHANGES 時の 3 フィールドを機構検証する
- WHEN: status が REQUEST_CHANGES で suggested_fix を欠いた finding を含む不正 fixture に対して `validate-contract.sh evaluator <fixture>` を実行する
- THEN: exit code が 0 以外である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S48: [harvest-bestprac-refresh] Step 2 が researcher subagent 起動として書かれている
- WHEN: refresh SKILL.md を「researcher subagent|harvest-bestprac-researcher|subagent_type.*researcher」で grep する
- THEN: マッチが 2 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S49: [harvest-bestprac-refresh] Step 2 で WebSearch を skill 本体が直接呼ばない旨が書かれている
- WHEN: refresh SKILL.md を「WebSearch.*直接.*呼.*ない|WebSearch.*廃止|researcher.*WebSearch」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S50: [harvest-bestprac-refresh] Step 2 セクション見出しが存在する
- WHEN: `grep -nE '^### Step 2' plugins/harvest/skills/bestprac/refresh/SKILL.md` を実行する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S51: [harvest-bestprac-refresh] researcher payload の validate-contract.sh 検証が記述されている
- WHEN: refresh SKILL.md を `validate-contract.sh researcher` と `researcher.schema.json` で grep する
- THEN: 両方とも 1 件以上ヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S52: [harvest-bestprac-refresh] 5 セクション位置パースへの依存が SKILL.md に残存しない
- WHEN: `grep -cE '5 セクション|5 artifact|セクション固定' plugins/harvest/skills/bestprac/refresh/SKILL.md` を実行する
- THEN: 出力が 0 である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S53: [harvest-bestprac-refresh] Step 3 セクション見出しが存在する
- WHEN: `grep -nE '^### Step 3' plugins/harvest/skills/bestprac/refresh/SKILL.md` を実行する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S54: [harvest-bestprac-refresh] Step 3 が Edit ツールでの本文書き換えを明示している
- WHEN: refresh SKILL.md を「Edit ツール|Edit tool」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S55: [harvest-bestprac-refresh] Step 3 が claims YAML を丸ごと置換する手順を記述している
- WHEN: refresh SKILL.md を claims 丸ごと置換パターンと「payload の claims フィールドが置換ソース」の記述で grep する
- THEN: 丸ごと置換手順が 1 件以上、claims フィールド参照が 1 件以上ヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S56: [harvest-bestprac-refresh] Step 3 が claim id unique 検証 grep を記述している
- WHEN: refresh SKILL.md を `grep -c "  - id:"` / claim id unique 検証で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S57: [harvest-bestprac-refresh] Step 3 で Operational Cadence が書き換え対象に含まれている
- WHEN: `grep -nE 'Operational Cadence' plugins/harvest/skills/bestprac/refresh/SKILL.md` を実行する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S58: [harvest-bestprac-refresh] Tone Defaults セクションは touch しない旨が書かれている
- WHEN: refresh SKILL.md を「Tone Defaults.*触らない|touch.*ない|変更しない」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S59: [harvest-bestprac-refresh] Step 3.5 セクション見出しが存在する
- WHEN: `grep -nE '^### Step 3\.5' plugins/harvest/skills/bestprac/refresh/SKILL.md` を実行する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S60: [harvest-bestprac-refresh] Step 3.5 が evaluator subagent 起動として書かれている
- WHEN: refresh SKILL.md を「evaluator subagent|harvest-bestprac-evaluator|subagent_type.*evaluator」で grep する
- THEN: マッチが 2 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S61: [harvest-bestprac-refresh] 判定は status フィールドで読み文字列マッチは残存しない
- WHEN: refresh SKILL.md を `validate-contract.sh evaluator` / `.status` / `jq -r` と `Status: APPROVE` 文字列マッチ擬似コードで grep する
- THEN: 前者は 1 件以上ヒットし、`Status: APPROVE` 文字列マッチの残存は 0 件である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S62: [harvest-bestprac-refresh] 修正主体が skill 本体 LLM であることが明示されている
- WHEN: refresh SKILL.md を「修正主体.*skill 本体|skill 本体 LLM|researcher.*再起動しない」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S63: [harvest-bestprac-refresh] 最大 2 ラウンドの上限が明示されている
- WHEN: refresh SKILL.md を「最大 2 ラウンド|maximum 2 round|2 ラウンド上限」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S64: [harvest-bestprac-refresh] 未解決 finding は maintainer_note 末尾追記である
- WHEN: refresh SKILL.md を「maintainer_note 末尾追記|未解決.*maintainer_note」で grep する
- THEN: マッチが 1 件以上ある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S65: [harvest-bestprac-refresh] body H2 として Unresolved Findings は存在しない
- WHEN: `awk '/^---$/{n++; next} n>=2' plugins/harvest/bestprac/x.md | grep -cE '^## Unresolved Findings'` を実行する
- THEN: 出力が 0 である（frontmatter 以降の body 部に H2 見出しとして存在しない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S66: [harvest-bestprac-refresh] E2E で現行と同等の成果物が生成される（受け入れ条件 17）
- WHEN: `/harvest:bestprac-refresh <platform>` を E2E 実行（live モード、または researcher / evaluator payload を fixture で代替）する
- THEN: bestprac/<platform>.md が現行スキーマ（frontmatter 5 キー + body 5 セクション）を維持したまま更新され、`bats plugins/harvest/tests/bestprac_schema.bats` が全 PASS する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了
