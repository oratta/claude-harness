# Verification Guide

## 環境
- 検証対象: `plugins/worktree/commands/wt-clean.md` + `plugins/worktree/skills/wt-clean/SKILL.md`
- サンドボックス: `/tmp/wt-clean-merge-active-sandbox-$$`（手動シナリオごとに新規 git init repo を作って実行）
- テスト戦略: 手動シナリオ実行（spec.md の WHEN/THEN を実機再現）
- 開発サーバー / 起動コマンド: N/A（CLI スキル）
- 自動テスト: N/A（本リポは Markdown / Bash / JSON ベースで自動テストランナー未整備）

## change-A: wt-clean-merge-active

### S1: Dirty なし 🔴 1件 → 「マージ」選択 → 成功

- **GIVEN** サンドボックス repo に 🔴 worktree が 1 件（Dirty なし、未マージ 3 commits）ある
- **WHEN** `wt-clean` を実行 → Step 3 で「🔴 を main にマージしてから処理 (推奨・安全)」を選択 → Step 5a で「main にマージ」を選択
- **THEN**
  - main HEAD に merge commit が積まれる（`git log --oneline -1` で確認）
  - サニティチェック PASS（テストランナー未整備のためスキップ判定）
  - worktree が削除される（`test -d <path> && fail`）
  - 完了レポートに「🔴 マージ→削除: <branch> (3 commits merged)」が表示される
- [x] テスト実装完了（spec.md「Dirty なし 🔴 では 3 択が提示される」「マージ実行...」「マージ成功 → サニティ PASS → 通常削除」「通常成功時のレポート表示」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: Dirty なし 🔴 1件 → 「スキップ」選択 → 状態維持

- **GIVEN** S1 と同じ状態
- **WHEN** Step 5a で「スキップ」を選択
- **THEN**
  - main HEAD は変化なし（merge commit なし）
  - worktree も削除されない
  - 完了レポートに「スキップ: <branch> (🔴)」相当が表示される（既存仕様）
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: Dirty なし 🔴 1件 → 「破棄削除」選択 → force 削除

- **GIVEN** S1 と同じ状態
- **WHEN** Step 5a で「破棄削除 (force)」を選択
- **THEN**
  - `git worktree remove --force` + `git branch -D` が実行される
  - main HEAD は変化なし（merge commit なし）
  - worktree が削除される（未マージコミットが永久に失われる）
  - 完了レポートに「破棄削除: <branch>」相当が表示される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: Dirty 同時 🔴 → マージ選択肢が除外

- **GIVEN** 🔴 worktree が 1 件あり、worktree 内に未コミット変更（dirty: 2 files）が存在する
- **WHEN** `wt-clean` を実行 → 新ルート選択 → Step 5a の AskUserQuestion が表示される
- **THEN**
  - 選択肢が「1) スキップ / 2) 破棄削除 (force)」の 2 択のみ
  - 表示文言に「⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）」が含まれる
- [x] テスト実装完了（spec.md「Dirty 同時 🔴 ではマージ選択肢が除外される」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: Dirty なし 🔴 2件 → 両方「マージ」選択 → 順次マージ → 両方削除

- **GIVEN** 🔴 worktree が 2 件（feat-a, feat-b）ある
- **WHEN** 新ルート選択 → Step 5a で両方「マージ」を選択
- **THEN**
  - 順次マージ実行（feat-a → feat-b の順、`MERGED_BRANCHES=("feat-a" "feat-b")`）
  - main HEAD に 2 つの merge commit が積まれる
  - 両 worktree が削除される
  - 完了レポートに「🔴 マージ→削除: feat-a」「🔴 マージ→削除: feat-b」が表示される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: Dirty なし 🔴 3件 → 1件目マージ成功 → 2件目で競合 → 1件目も含め全削除保留、3件目未処理

- **GIVEN** 🔴 worktree が 3 件（feat-a / feat-b / feat-c）あり、feat-b が main と競合する変更を持つ
- **WHEN** 新ルート選択 → 全件「マージ」を選択
- **THEN**
  - feat-a のマージは成功し `MERGED_BRANCHES=("feat-a")` になる
  - feat-b のマージで競合発生 → `git merge --abort` は**自動実行されない**
  - main HEAD は merge 進行中状態（`.git/MERGE_HEAD` 存在）のまま保持
  - feat-a も含めて Step 6 サニティチェック以降を実行せず、全 worktree を削除しない（保留）
  - feat-c は未処理のまま
  - 完了レポートに「🔴 マージ成功・削除保留: feat-a (N commits merged, awaiting conflict resolution)」「⚠️ マージ競合で中断: feat-b」「未処理: feat-c」が区別表示される
- [x] テスト実装完了（spec.md「競合発生で `git merge --abort` は自動実行されない（不変条件）」「複数 🔴 順次処理中の競合発生で既マージ分も全保留」「競合保留時のレポート表示」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: 🔴 0件 → 新選択肢が出ない

- **GIVEN** 🔴 worktree が 0 件、🟢 / 🟡 のみ存在
- **WHEN** `wt-clean` を実行 → Step 3 のレポート表示
- **THEN**
  - 選択肢が既存 4 択（🟢🟡を処理する / 🟢のみ処理する / 全て処理する / キャンセル）のみ
  - 新選択肢「🔴 を main にマージしてから処理 (推奨・安全)」は表示されない
- [x] テスト実装完了（spec.md「🔴 が 0 件なら新選択肢は出ない」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: 既存「全て処理する（🔴破棄）」ルート選択 → 既存通り破棄削除（回帰防止）

- **GIVEN** 🔴 worktree が 1 件
- **WHEN** Step 3 で新選択肢ではなく既存「全て処理する（🔴含む — 破棄ルート、危険）」を選択
- **THEN**
  - `git worktree remove --force` + `git branch -D` で破棄削除される（既存仕様通り）
  - main HEAD は変化なし（merge commit なし）
  - `MERGED_BRANCHES` 配列は使われない
- [x] テスト実装完了（spec.md「既存「全て処理する（🔴破棄）」ルートが既存通り動作する」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: `--keep` で新ルート選択 → マージ後の worktree は通常削除

- **GIVEN** `wt-clean --keep` を実行、🔴 worktree が 1 件
- **WHEN** 新ルート選択 → Step 5a で「マージ」を選択
- **THEN**
  - マージ成功
  - Step 7b（再利用化）ではなく Step 7a（通常削除）に流れる
  - 完了レポートに「🔴 マージ→削除（--keep 指定だが新ルートのため通常削除）: <branch>」と理由併記で表示される
- [x] テスト実装完了（spec.md「`--keep` 指定でも新ルートのマージ後は通常削除になる」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: `--no-sync` で新ルート選択 → Step 0 スキップ + 新ルート動作

- **GIVEN** `wt-clean --no-sync` を実行、🔴 worktree が 1 件
- **WHEN** Step 3 で新ルート選択 → Step 5a で「マージ」を選択
- **THEN**
  - Step 0 の Remote 同期はスキップされ、完了レポートに「Remote 同期: -- skipped (--no-sync)」が既存通り表示される
  - 新ルートのマージ処理は通常通り動作する（フラグ間の干渉なし）
- [x] テスト実装完了（spec.md「`--no-sync` 指定が新ルート追加で影響を受けない」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: メインリポが MAIN_BRANCH 以外をチェックアウト中 → 新ルート中断

- **GIVEN** メインリポが `MAIN_BRANCH` ではない別ブランチ（例: `dev-experiment`）をチェックアウト中、🔴 worktree が 1 件
- **WHEN** 新ルート選択 → Step 5a で「マージ」を選択
- **THEN**
  - Step 5b 開始時の事前確認で `git branch --show-current` ≠ `MAIN_BRANCH` を検出
  - 新ルート全体を中断
  - 「`cd $MAIN_REPO && git checkout $MAIN_BRANCH` してから wt-clean を再実行してください」と案内が表示される
- [x] テスト実装完了（spec.md「メインリポが MAIN_BRANCH 以外をチェックアウト中なら新ルート中断」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: 全 🔴 が Dirty の場合は案内を出してから per-worktree ループに入る

- **GIVEN** 🔴 worktree が複数（例: 2 件）あり、全件が Dirty（未コミット変更）を持つ
- **WHEN** Step 3 で新ルート選択 → Step 5a の per-worktree ループ開始時
- **THEN**
  - AskUserQuestion 前に「マージ可能な 🔴 が 0 件です（全件 Dirty）。先にコミットしてから wt-clean を再実行するか、個別にスキップ/破棄削除を選んでください」と 1 度だけ案内が表示される
  - エラー中断はせず、その後各 🔴 worktree に対し Dirty 2 択（1) スキップ / 2) 破棄削除 (force)）の AskUserQuestion が提示される
- [x] テスト実装完了（spec.md「全 🔴 が Dirty の場合は案内を出してから per-worktree ループに入る」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: detached HEAD の 🔴 worktree はマージ選択肢が除外される

- **GIVEN** 🔴 worktree が 1 件あり、detached HEAD 状態（`BRANCH_NAME` が空）で未マージのコミットを持つ
- **WHEN** 新ルート選択後、Step 5a でその worktree を処理する番になる
- **THEN**
  - AskUserQuestion で「1) スキップ / 2) 破棄削除 (force)」の 2 択のみが提示される
  - 表示文言に「⚠️ detached HEAD のためマージできません」と理由が明示される
- [x] テスト実装完了（spec.md「detached HEAD の 🔴 worktree はマージ選択肢が除外される」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: メインリポで merge in progress 中なら新ルート中断

- **GIVEN** メインリポの `.git/MERGE_HEAD` が存在する（前回のマージが未解決）、🔴 worktree が 1 件
- **WHEN** Step 3 で新ルート選択 → Step 5a で「マージ」を選択 → Step 5b に入る
- **THEN**
  - Step 5b の事前確認（5b-2）で `.git/MERGE_HEAD` の存在を検出
  - 新ルート全体を中断
  - 「`cd $MAIN_REPO` で `git status` を確認し、競合解決→commit、または `git merge --abort` してから wt-clean を再実行してください」と案内が表示される
- [x] テスト実装完了（spec.md「メインリポで merge in progress 中なら新ルート中断」に対応）
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了
