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

## 2026-05-20 Build (change-A 実装中)

### D4: 完了レポートの最終表現（design.md Open Questions）
- **判断**: plan.md の「Step 8 完了レポート」セクションで提示された 3 パターン（通常成功時 / `--keep` 時 / 競合保留時）の例文をそのまま wt-clean.md / SKILL.md に転記
- **根拠**: plan.md と spec.md の機能固有条件 14 で明文化済み。設計裁量ではなく仕様
- **エビデンス**: plan.md L182-220、spec.md Requirement「Step 8 完了レポートに新ルートの結果を区別して表示する」

### D5: per-worktree 個別確認の表示順序（design.md Open Questions）
- **判断**: `git worktree list` の順（= 作成順）で Step 5a を表示する旨を Step 5a 冒頭に明示
- **根拠**: design.md Open Questions で推奨されている順序。git の自然な並びを踏襲することで予測可能性を保つ
- **エビデンス**: 編集後 wt-clean.md / SKILL.md の Step 5a 冒頭「🔴 worktree を `git worktree list` の順（作成順）に 1 つずつ AskUserQuestion で確認する。」

### D6: 競合発生時の不変条件を Step 5b-4 と Step 6d の両方に明記
- **判断**: 「`git merge --abort` を自動実行しない」「既マージ分も含め全保留」を Step 5b-4（イベント時）と Step 6d（チェック対象判定の特例）の両方に redundant に記述
- **根拠**: 安全側ルールは複数箇所で表明する方が将来の意図せぬ削除事故を防げる。spec.md の不変条件 Scenario との整合も担保しやすい
- **エビデンス**: 編集後 wt-clean.md / SKILL.md の Step 5b-4 と Step 6d 両方に同趣旨の記述あり

### D7: AskUserQuestion ラベル文言を既存 Step 3 スタイルに統一
- **判断**: Step 5a の選択肢ラベルを `1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)` 形式（既存 Step 3 と同じ番号付き＋推奨/force マーキング）で記述
- **根拠**: 既存 wt-clean.md Step 3 / Step 5 と整合させ、ユーザーの学習コストを生まない
- **エビデンス**: 編集後 wt-clean.md Step 5a の選択肢ブロック

