## Why

`/longrun:plan` のフルモードは Build Contract レビュー / TDD 強制 / Verifier 自動起動を含む重装備で、短時間で人間が手で MVP を実装するシナリオには過剰である。change-A で MVP モード用の subagent 3 種（`longrun-mvp-research` / `longrun-mvp-plan-reviewer` / `longrun-mvp-bestpractice-reviewer`）を新規追加した。本 change は、`plugins/longrun/skills/longrun-plan/SKILL.md` 側に `--mode=mvp` フラグの分岐ロジックと MVP モード専用フローを追加し、これらの subagent を実際に呼び出せる状態にする。

最重要制約は **フルモードの既存挙動に regression を入れないこと**。既存 Step 1〜8 の本文の文言には一切手を加えず、フラグ判定と MVP 専用セクションを **追加のみ** で構成することで、既存ユーザーへの影響をゼロに保つ。

## What Changes

- `plugins/longrun/skills/longrun-plan/SKILL.md` の冒頭（フロントマター直後 / 既存本文より前）に `## モード分岐（フルモード / MVP モード）` セクションを追加し、`--mode=mvp` フラグを判定して分岐するロジックを記述する
- フルモード（引数なし or `--mode=full`）は既存 Step 1〜8 をそのまま実行する旨を明記する
- SKILL.md 末尾に `## MVP モード（--mode=mvp）` セクションを新規追加し、Step 1〜8 を MVP 用に再利用 / 差し替え / スキップした軽量フローを定義する
- 新規 Step 4.5（並列リサーチ）を MVP モード内に追加し、`longrun-mvp-research` subagent を `Agent` ツール経由で起動する手順を記述する
- 既存 Step 7 の差し替え版として、`longrun-mvp-plan-reviewer` と `longrun-mvp-bestpractice-reviewer` を **単一メッセージ内の複数 tool_use として並列起動** する手順を記述する
- MVP モード Step 5（Synthesis）の差し替え版で、生成する plan.md の先頭に `<!-- mvp-mode -->` マーカーを必ず埋め込む旨を明記する（archive 側判定に使われる）
- MVP モード Step 6（Validation）の差し替え版で、軽量テンプレ用の必須セクション（ゴール / 技術要件 / スコープ / 受け入れ条件 / 動作確認方法 / 調査結果サマリ / レビュー結果サマリ）に対するチェックリストを定義する
- MVP モード Step 8（確定）の差し替え版で、backlog 消込みなし / OpenSpec change 生成スキップ / 人間ハンドオフ案内のみ、と明記する

## Capabilities

### New Capabilities
（なし。既存 capability への追加で十分）

### Modified Capabilities
- `longrun-plan-skill`: SKILL.md に `--mode=mvp` フラグ分岐と MVP モード専用フローを追加する。既存 Skill 命名規則 / 起動プロトコル / orchestrator バイアスガード / バージョンバンプ要件には触れず、新たな要件「モード分岐ロジック」「MVP モード Step 4.5 並列リサーチ」「MVP モード並列レビュー」「MVP モードマーカー埋め込み」を追加する。

## Impact

- **変更ファイル**: `plugins/longrun/skills/longrun-plan/SKILL.md`（追記のみ）
- **新規ファイル**: なし（OpenSpec ドキュメント以外）
- **依存**:
  - change-A（`longrun-mvp-research` / `longrun-mvp-plan-reviewer` / `longrun-mvp-bestpractice-reviewer` agent ファイル）が完了済みであること
  - change-C で作成予定の `plugins/longrun/templates/plan-template-mvp.md` を SKILL.md からはパスとして参照する（本 change のスコープではテンプレ自体は未作成でよい）
- **regression リスク**: 既存 Step 1〜8 の本文に文言変更を入れない方針により、フルモード挙動への影響は **構造上ゼロ** に保つ。受け入れ条件 #12（git diff 検証）で担保する
- **plugin.json / SKILL.md frontmatter のバージョンバンプ**: 本 change では行わない（change-C で `4.2.0` → `4.3.0` に bump する）
