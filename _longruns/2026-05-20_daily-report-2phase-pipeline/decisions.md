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
