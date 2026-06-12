# Proposal: openspec-degradation — OpenSpec CLI 不可環境向け縮退モードの追加

## Why

longrun の自律実行は OpenSpec CLI（`npx openspec`）が解決可能であることを暗黙の前提にしており、CLI が解決できない環境（未インストール / npx 解決不可 / openspec 未 init の repo）では Setup フェーズのツール検証で `npm install -g openspec` の試行に流れ、失敗するとユーザー報告で止まるだけで run を進める正規の道がない。また、ユーザーが「このプロジェクトに OpenSpec は不要」と判断した場合の opt-out 手段も存在しない。OpenSpec が使えない・使わない環境でも longrun の Review → Build → Verify → Feedback サイクル自体は価値があるため、縮退モードを「エラー時の例外処理」ではなく**一級の動作モード**として定義する。change-2（exec の Workflow 化）が Step 0 の縮退分岐を前提に設計されるため、直列チェーンの先頭として今行う。

## What Changes

- **exec の Step 0 前提条件チェックを昇格**: 「`npx openspec` 解決可能 + openspec init 済み」のチェックを exec 起動直後（Step 0）に行い、失敗時は AskUserQuestion で縮退モードを提案する（継続 / 中断をユーザーが選択）。preflight OK 時も Step 0 の AskUserQuestion（動作モード確認）に縮退選択肢を常時含めることで「OpenSpec 不要」の明示的 opt-out を可能にする（専用引数は追加しない）
- **縮退モードの自己完結 artifacts**: 縮退時は spec 類（proposal / tasks / verification-guide 相当）を `openspec/changes/` ではなく `_longruns/<run>/` 内に自己完結生成する。`openspec/` 配下には一切書き込まない
- **feedback の Tier 3 記録先フォールバック**: 縮退 run では Tier 3（new change）の記録先を `openspec/backlog.md` から `_longruns/<run>/backlog.md` にフォールバックする
- **実機検証とバージョン乖離の解消**: 素の repo での `openspec init --tools claude` → `openspec apply` を実機検証し、カスタムスキーマ（longrun-tdd）の出所と、volta グローバル（1.2.0）/ npx ローカル（0.23.0）のどちらを正とするかを確定して docs に記録する
- **bats テスト基盤の新設**: `plugins/longrun/tests/` を新設し、コマンド不在シミュレートで縮退分岐を検証する
- **やらないこと**: `/longrun:status` への縮退分岐は実装しない（change-2 で status コマンド自体が廃止されるため）。既存の openspec/ あり repo の従来挙動は一切変えない（回帰なし）

破壊的変更なし（追加的変更。longrun 5.2.0 → 5.3.0）。

## Capabilities

### New Capabilities
- `longrun-openspec-preflight`: exec Step 0 での OpenSpec 前提条件チェック（`npx openspec` 解決可能 + init 済み）と、失敗時の AskUserQuestion による縮退モード提案・モード決定
- `longrun-degraded-run-artifacts`: 縮退モード時に spec 類（proposal / tasks / verification-guide 相当）を `_longruns/<run>/` 内に自己完結生成し、縮退 run を Archive まで完走させる動作
- `longrun-feedback-backlog-fallback`: 縮退 run における feedback Tier 3 記録先の `_longruns/<run>/backlog.md` へのフォールバック

### Modified Capabilities

（なし。既存 spec — `longrun-plan-skill` / `longrun-mvp-*` 等 — の Requirements は変更しない。orchestrator / feedback の既存挙動への変更は「OpenSpec 利用可能時は従来どおり」を維持する追加分岐のみで、既存 capability の spec-level 挙動は不変）

## Impact

- **`plugins/longrun/commands/exec.md`**: Step 0（前提条件チェック + 縮退提案）の追加
- **`plugins/longrun/skills/longrun-orchestrator/SKILL.md`**: Setup フェーズのツール検証を Step 0 の判定結果消費に整理。OpenSpec フェーズ（change 作成 / apply / verification-guide 生成 / archive）に縮退分岐を追加
- **`plugins/longrun/skills/longrun-feedback/SKILL.md`**: Tier 3 記録先の縮退フォールバック分岐を追加
- **`plugins/longrun/commands/archive.md`**: `_longruns/<run>/.degraded-mode` マーカー判定による縮退分岐（ランディレクトリのみアーカイブ）の追加。既存の MVP 分岐（plan.md 先頭の `<!-- mvp-mode -->` マーカー判定、archive.md L15-19）とは**判定ソースが別**であり、両者の優先順位も定義する
- **`plugins/longrun/scripts/`**: preflight 判定スクリプトの新設（bats でテスト可能にするため bash に切り出し）
- **`plugins/longrun/tests/`**: bats テスト新設（このリポジトリの longrun プラグイン初のテストディレクトリ）
- **`plugins/longrun/README.md` / docs**: 縮退モードの説明と実機検証結果の記録
- **バージョン同期 3 箇所**: `plugins/longrun/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` top-level / 同 plugins[]（5.2.0 → 5.3.0）
- **触らないもの**: `plugins/longrun/commands/status.md`・`plugins/lr/commands/s.md`（change-2 で廃止予定）、既存 agent 定義 7 種
