## 1. commands/wt-clean.md 更新

- [x] 1.1 「オプション」セクションは変更なし（新ルートは 🔴 がある時の対話で出現するため、CLI フラグは追加しない）
- [x] 1.2 Step 3「レポート表示」の選択肢を 🔴 がある場合に **5 択** に拡張する
  - 1) 🔴 を main にマージしてから処理 (推奨・安全)  ← New
  - 2) 🟢🟡 のみ処理する（既存「🟢🟡を処理する」相当）
  - 3) 🟢 のみ処理する（既存）
  - 4) 全て処理する（🔴含む — 破棄ルート、危険）（既存）
  - 5) キャンセル（既存）
- [x] 1.3 Step 3 で 🔴 が 0 件の場合は既存 4 択をそのまま表示し、新選択肢は出さない
- [x] 1.4 新規 **Step 5a「🔴 個別マージ確認」** を Step 5 直後に挿入
  - 🔴 worktree を 1 つずつ AskUserQuestion で確認
  - 通常: 「1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)」
  - Dirty 同時時: 「1) スキップ / 2) 破棄削除 (force)」（マージ選択肢を除外）
  - 表示には未マージコミット一覧（`git log --oneline $MAIN_BRANCH..$BRANCH_NAME`）と Dirty / LLM 状況を含める
  - [x] 1.4.1 全 🔴 が Dirty の場合、per-worktree ループ前に「マージ可能な 🔴 が 0 件です（全件 Dirty）。先にコミットしてから wt-clean を再実行するか、個別にスキップ/破棄削除を選んでください」と 1 度だけ案内してからループに入る（エラー中断しない）
  - [x] 1.4.2 detached HEAD（`BRANCH_NAME` が空）の 🔴 worktree はマージ選択肢を除外し、Dirty 同時時と同じく「1) スキップ / 2) 破棄削除 (force)」の 2 択を提示。表示文言で「⚠️ detached HEAD のためマージできません」と理由を明示
- [x] 1.5 新規 **Step 5b「マージ実行とエラーハンドリング」** を Step 5a 直後に挿入
  - 事前確認: `git -C "$MAIN_REPO" branch --show-current` が `$MAIN_BRANCH` と一致することを検証。違う場合は新ルート全体を中断し checkout 案内を表示
  - マージ実行: `cd "$MAIN_REPO" && git checkout "$MAIN_BRANCH" && git merge "$BRANCH_NAME" --no-ff -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"`
  - 成功時: `MERGED_BRANCHES+=("$BRANCH_NAME")` で配列に追記し、Step 6 サニティチェック対象に含める
  - 競合時: `git merge --abort` を**自動実行せず**競合状態を保持。すでにマージ成功した worktree（MERGED_BRANCHES に記録）も含め Step 6 以降を中断し全削除保留
  - [x] 1.5.1 事前確認に `.git/MERGE_HEAD` 存在チェックを追加。メインリポで前回のマージが進行中なら新ルート全体を中断し、「`cd $MAIN_REPO` で `git status` を確認し、競合解決→commit、または `git merge --abort` してから wt-clean を再実行してください」と案内
- [x] 1.6 Step 6d「チェック対象の範囲」のロジック改修
  - 既存条件「🟢 Safe かつ今回 wt-clean で新たにマージした worktree」**または**「`MERGED_BRANCHES` に含まれるブランチに対応する worktree」をチェック対象とする
  - 競合発生で中断した場合は Step 6 自体を実行せず、`MERGED_BRANCHES` に記録された worktree も全て削除保留
- [x] 1.7 Step 8 完了レポートに以下の表示行を追加
  - 通常成功時: `🔴 マージ→削除: <branch> (N commits merged)`
  - `--keep` 指定時: `🔴 マージ→削除（--keep 指定だが新ルートのため通常削除）: <branch>` + 理由併記
  - 競合保留時: `🔴 マージ成功・削除保留: <branch> (N commits merged, awaiting conflict resolution)` + `⚠️ マージ競合で中断: <branch>` + `未処理: <branches>`

## 2. skills/wt-clean/SKILL.md 更新

- [x] 2.1 commands/wt-clean.md と同一の変更を反映（内容同期）
- [x] 2.2 frontmatter `version` を minor bump（既存 1.2.0 → 1.3.0）
- [x] 2.3 frontmatter `description` に「🔴 Active worktree のマージ確認に対応」のニュアンスを追記

## 3. プラグインメタデータ更新

- [x] 3.1 `plugins/worktree/.claude-plugin/plugin.json` のバージョンを minor bump（キャッシュ無効化）: 1.7.0 → 1.8.0
- [x] 3.2 `.claude-plugin/marketplace.json` の worktree プラグインバージョンを同期: 1.2.0 → 1.3.0

## 4. ドキュメント整合性

- [x] 4.1 commands 版と skills 版の差分が意図通りか diff で確認（既存 6a コメント差分のみ、新規追加部分は完全同期）
- [x] 4.2 既存 Step 6c「FAIL したマージ以降を保留」と新ルートの「競合中断時に MERGED_BRANCHES 既マージ分も保留」が矛盾しないか確認（同じ「安全側に倒す」思想で整合）
- [x] 4.3 完了レポートの例文が現実的な値になっているか確認

## 5. 動作確認（仕様記述レビュー + 実機シナリオ）

※ 本 Change はドキュメント変更のため、各項目は SKILL.md / wt-clean.md で該当仕様が記述されていることを確認する。実機動作は次回 `wt-clean` 実行時にユーザーがサンドボックス repo でシナリオ S1〜S11 を実行する。

- [x] 5.1 S1: 🔴 1件、Dirty なし、マージ選択 → 成功（main に merge commit、worktree 削除、サニティチェック PASS）
- [x] 5.2 S2: 🔴 1件、Dirty なし、スキップ選択 → 状態維持
- [x] 5.3 S3: 🔴 1件、Dirty なし、破棄選択 → force 削除
- [x] 5.4 S4: 🔴 1件、Dirty あり → マージ選択肢が表示されない（2択）
- [x] 5.5 S5: 🔴 2件、両方マージ選択 → 順次マージ → 両方削除
- [x] 5.6 S6: 🔴 3件、1件目マージ成功 → 2件目で競合 → 1件目も含め全削除保留、3件目未処理、main 履歴に `--abort` 痕跡なし
- [x] 5.7 S7: 🔴 0件 → 新選択肢が出ない（既存4択のみ）
- [x] 5.8 S8: 既存「全て処理する（🔴破棄）」ルートを選択 → 既存通り破棄削除（回帰防止）
- [x] 5.9 S9: `--keep` で新ルート選択 → マージ後の worktree は通常削除、完了レポートに `--keep` 指定だが新ルートのため通常削除`と明示
- [x] 5.10 S10: `--no-sync` で新ルート選択 → Step 0 スキップ＋新ルート動作（フラグ非干渉確認）
- [x] 5.11 S11: メインリポが MAIN_BRANCH 以外をチェックアウト中 → 新ルート中断、checkout 案内表示

## 6. コミット & 反映

- [x] 6.1 変更を commit（Conventional Commits 準拠）: `feat(wt-clean): add 🔴 active worktree merge confirmation route` (39c60ec)
- [ ] 6.2 push 後、プラグイン再インストール or `/reload-plugins` で反映確認（ユーザー実施）
