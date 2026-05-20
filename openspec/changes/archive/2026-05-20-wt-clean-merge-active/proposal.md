## Why

`wt-clean` は現状、未マージのコミットを持つ worktree を **🔴 Active** として分類し、明示指示（「全て処理する（🔴含む — 危険）」）がなければスキップする。明示指示を選んだ場合の動作は **`git worktree remove --force` + `git branch -D` による破棄**であり、未マージコミットを失う非可逆操作になる。

しかし実運用では、ローカル完結の作業（PR を介さず直接 main にマージする運用）で「未マージコミット = 既に動作確認済みで main に取り込みたい変更」というケースが多い。現状の wt-clean ではこのユーザーは:

1. 一度キャンセル
2. メインリポで手動 `git merge feature/<name>` を実行
3. wt-clean を再実行

という3ステップを毎回踏む必要があった。最頻パス（=安全にマージしてしまいたい）をデフォルト推奨にすることで、この往復を 1 セッションで完結できるようにする。

## What Changes

- `wt-clean` 実行フローに **🔴 Active worktree の main マージ確認フェーズ** を追加する
  - Step 3 のレポート選択肢の **先頭** に「🔴 を main にマージしてから処理 (推奨・安全)」を追加（🔴 が 1 件以上ある場合のみ）
  - 新規 **Step 5a「🔴 個別マージ確認」** を追加し、🔴 worktree ごとに AskUserQuestion で「マージ / スキップ / 破棄削除」の 3 択（Dirty 同時時は「スキップ / 破棄削除」の 2 択）を提示
  - 新規 **Step 5b「マージ実行とエラーハンドリング」** を追加し、`cd $MAIN_REPO && git checkout $MAIN_BRANCH && git merge "$BRANCH_NAME" --no-ff` でマージ実行
  - **Step 6d「チェック対象の範囲」のロジック改修**: 新ルートでマージ昇格した worktree を `MERGED_BRANCHES` 配列で管理し、サニティチェック対象に含める
  - **Step 8 完了レポート** に新ルート用の表示（「🔴 マージ→削除」「🔴 マージ成功・削除保留」「⚠️ マージ競合で中断」など）を追加
- マージで競合が発生した場合は `git merge --abort` を自動実行せず競合状態を保持し、すでにマージ成功した worktree も含めて Step 6 以降を中断（全削除保留）
- Dirty が同時にある 🔴 はマージ選択肢を表示せず、「スキップ / 破棄削除」の 2 択に絞る
- `--keep` 指定時に新ルートを選んだ場合、マージ後の worktree は再利用化せず通常削除する（マージ後はブランチが消えており再利用化＝main切替の意味が薄いため）
- 既存ルート（「🟢🟡のみ処理する」「🟢のみ処理する」「全て処理する（🔴含む — 危険、破棄）」「キャンセル」「`--keep`」「`--no-sync`」）は新ルート追加によって動作変更しない（回帰防止）

## Capabilities

### New Capabilities

- `wt-clean-merge-active`: `wt-clean` の 🔴 Active worktree マージ確認フェーズの仕様。Step 3 選択肢の先頭追加、Step 5a の個別確認、Step 5b のマージ実行と競合中断、`MERGED_BRANCHES` 配列の状態管理、Step 6d のチェック対象拡張、Step 8 完了レポート表示を定義する。

### Modified Capabilities

なし（既存 spec への delta は不要、新規 capability として独立追加）。

## Impact

- **影響ファイル**:
  - `plugins/worktree/commands/wt-clean.md` — Step 3 選択肢追加、Step 5a / 5b 新設、Step 6d 改修、Step 8 完了レポート追記
  - `plugins/worktree/skills/wt-clean/SKILL.md` — commands 版と同内容を反映、frontmatter `version` minor bump
  - `plugins/worktree/.claude-plugin/plugin.json` — `version` を minor bump（既存 1.2.0 系 → 1.3.0 系）。理由: 既存 API 互換を保ちつつ機能追加のため
  - `.claude-plugin/marketplace.json` — `worktree` プラグインの version を同期
- **互換性**: 既存ルートの挙動を変更しないため後方互換。🔴 Active がある時のみ新選択肢が追加される
- **依存関係**: 追加の外部依存なし。`git merge --no-ff` のみ使用（既存 git のみ）
