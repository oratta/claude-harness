# Decisions Log

本ランで採用した重要な意思決定。各エントリにはエビデンス（実行コマンド・参照ファイル）を含める。

---

## D1: change-4 と change-5 を統合せず 5 change のまま維持（plan Round 1 指摘7への反論）

- **背景**: longrun-reviewer Round 1 で「change-4 と change-5 を統合した方がシンプル」という嗜好レベルの指摘
- **判断**: 反論して 5 change のまま維持
- **理由**:
  - change-4 単体マージで「voice.md / dailyLLM.md / Step 4 ログまでは生成される」中間マイルストーンを作りたい
  - change-5 で diary 生成側の旧経路を削除する順序を明示することで、Build フェーズで仕様レビューが独立して可能
  - 統合すると change-4 の負担が過大になり、Verify フェーズの責任範囲が広がる
- **エビデンス**:
  - plan.md change-5 rules の「備考（嗜好レベル指摘への反論）」セクション参照
  - longrun-reviewer Round 2 で反論の妥当性は確認済み（「ユーザーがマイルストーン重視を選ぶのは合理的判断。反論を採用してよい」）

---

## D3: Build Contract Round 1 指摘 BLOCKER 1 + SHOULD_FIX 4 + NOTE 2 すべて採用

- **背景**: Build Contract Round 1 で longrun-reviewer から指摘 7 件
- **判断**: 全採用（バイアス緩和ガード適用後も嗜好レベルの指摘無し）
- **採用内容**:
  - 指摘1 (BLOCKER): plugin.json `agents` 空配列初期化を change-0 に追加、change-2/3 で各 Agent を ASCII ソート順で追記
  - 指摘2 (SHOULD_FIX): worktree append コンフリクト対策として ASCII ソート順厳守 + change-4 で最終確認
  - 指摘3 (SHOULD_FIX): change-4 中間状態で新経路 diary 動作（旧経路は `# DEPRECATED` コメント付き残置）、change-5 で完全削除
  - 指摘4 (SHOULD_FIX): bats テストを各 Change のスコープに明示分配（change-2 / change-3 / change-4）
  - 指摘5 (NOTE): spike Agent 削除を change-4 完了時に変更（change-2/3 実装中のリファレンス温存）
  - 指摘6 (NOTE): change-5 完了条件に grep 3パターン明示
- **エビデンス**: plan.md change-0 / change-2 / change-3 / change-4 / change-5 の rules セクション参照（commit 1b4d292 以降の編集差分）

## D2: MCP ツール使用 Agent の frontmatter スタイルは wildcard 指定（`mcp__claude_ai_Notion__*`）

- **背景**: change-0 spike で「Agent から MCP ツールを呼ぶ方式」を検証するが、Explore 調査で前例が見つかった
- **判断**: spike では `longrun-browser-verifier.md` の wildcard パターンを最初に試す
- **理由**:
  - `plugins/longrun/agents/longrun-browser-verifier.md` の `tools: ... mcp__playwright__*, mcp__claude-in-chrome__*` 形式が既存実装
  - これが動かない場合のみ `ToolSearch` フォールバックを試す
- **エビデンス**:
  - Explore 調査レポート（2026-05-20 Setup フェーズ）
  - `plugins/longrun/agents/longrun-browser-verifier.md` Read 結果（フェーズ間のサブエージェントで確認予定）

---
