# Decisions Log

自律実行中の意思決定を記録する（エビデンス必須）。

## 2026-05-20 Setup

### D1: 単一 change-A 構成、worktree 分割なし
- **判断**: change-A: wt-clean-merge-active を単独 change として実装。orchestrator の「並列実行（独立 change）」フローによる worktree 作成はスキップし、本 worktree（wt-clean-merge-confirm）内で直接実装する
- **根拠**: plan.md の Changes 分解で change-A 1 件のみ。worktree を切ってマージし直す手間に対するメリットがない。`git worktree list` で確認した結果、本 worktree は既にこの作業専用のため重複作成は無意味
- **エビデンス**:
  ```
  $ git worktree list
  /Users/oratta/.claude/plugins/marketplaces/oratta-claude-harness  ... [main]
  /Users/oratta/.superset/worktrees/.../wt-clean-merge-confirm      ... [wt-clean-merge-confirm]
  ```

### D2: 自動テストランナー未整備のためベースラインなし
- **判断**: ベースラインテスト記録をスキップ。spec.md の Scenarios 手動実行で品質担保
- **根拠**: 本リポはプラグインマーケットプレイス（Markdown / Bash / JSON）。`package.json` / `Cargo.toml` 等のテストランナー設定がない
- **エビデンス**:
  ```
  $ ls package.json Cargo.toml pyproject.toml go.mod 2>/dev/null
  (no output — all absent)
  ```

### D3: 自律コミット方針
- **判断**: longrun-orchestrator が定義する自律コミット（Setup / Build / merge / Archive）を本セッションに限り許可
- **根拠**: ユーザーが AskUserQuestion で「longrun は例外として自動コミットを許可する（推奨）」を明示選択。global rule `git-commit-policy.md` との衝突を明示承認で解消
- **制約**: 動作中に予期しない金識型コミット（refactor / cleanup 等）はしない。完了後にコミットサマリを Step 8 完了レポートで提示する

