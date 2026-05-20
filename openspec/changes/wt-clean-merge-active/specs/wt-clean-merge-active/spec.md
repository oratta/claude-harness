# wt-clean-merge-active Specification

## ADDED Requirements

### Requirement: wt-clean は 🔴 Active worktree がある場合に main マージ確認ルートを最優先選択肢として提示する

`wt-clean` コマンドおよびスキルは、Step 1 / 2 の診断で 🔴 Active（未マージのコミットあり）worktree が 1 件以上検出された場合、Step 3 のレポート表示の選択肢の **先頭** に「🔴 を main にマージしてから処理 (推奨・安全)」を追加するものとする（SHALL）。🔴 が 0 件の場合は新選択肢を出さず、既存 4 択（🟢🟡を処理する / 🟢のみ処理する / 全て処理する / キャンセル）のみを表示する。

#### Scenario: 🔴 が存在する場合に新選択肢が先頭に出る

- **WHEN** ユーザーが `wt-clean` を実行し、診断結果に 🔴 Active worktree が 1 件以上含まれる
- **THEN** Step 3 の AskUserQuestion の選択肢の先頭に「🔴 を main にマージしてから処理 (推奨・安全)」が表示される
- **AND** 残りの選択肢として「🟢🟡 のみ処理する」「🟢 のみ処理する」「全て処理する（🔴含む — 破棄ルート、危険）」「キャンセル」が続き、計 5 択となる

#### Scenario: 🔴 が 0 件なら新選択肢は出ない

- **WHEN** ユーザーが `wt-clean` を実行し、診断結果に 🔴 Active worktree が 1 件もない
- **THEN** Step 3 の選択肢は既存 4 択（🟢🟡を処理する / 🟢のみ処理する / 全て処理する / キャンセル）のみで、新選択肢は表示されない

### Requirement: 新ルート選択時に 🔴 worktree ごとの個別確認を行う

新ルートが選択された場合、`wt-clean` は 🔴 worktree を 1 つずつ AskUserQuestion で確認し、ユーザーに「マージ / スキップ / 破棄削除」のいずれかを選ばせるものとする（SHALL）。表示には未マージコミットの一覧（`git log --oneline $MAIN_BRANCH..$BRANCH_NAME`）、Dirty 状態、LLM ファイル有無を含める。

#### Scenario: Dirty なし 🔴 では 3 択が提示される

- **WHEN** 新ルート選択後、Dirty を持たない 🔴 worktree を処理する番になる
- **THEN** AskUserQuestion で「1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)」の 3 択が提示される
- **AND** 表示に未マージコミット一覧が含まれる

#### Scenario: Dirty 同時 🔴 ではマージ選択肢が除外される

- **WHEN** 新ルート選択後、Dirty（未コミット変更）を持つ 🔴 worktree を処理する番になる
- **THEN** AskUserQuestion で「1) スキップ / 2) 破棄削除 (force)」の 2 択のみが提示される
- **AND** 表示文言に「⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）」と理由が明示される

#### Scenario: 全 🔴 が Dirty の場合は案内を出してから per-worktree ループに入る

- **GIVEN** 新ルートが選択され、🔴 worktree が複数あるが全件 Dirty を持つ
- **WHEN** Step 5a の個別確認ループ開始時
- **THEN** AskUserQuestion 前に「マージ可能な 🔴 が 0 件です（全件 Dirty）。先にコミットしてから wt-clean を再実行するか、個別にスキップ/破棄削除を選んでください」と案内が表示される
- **AND** その後、各 🔴 worktree に対し Dirty 2 択（スキップ / 破棄削除）の AskUserQuestion が提示される

#### Scenario: detached HEAD の 🔴 worktree はマージ選択肢が除外される

- **GIVEN** 🔴 worktree が detached HEAD 状態（`BRANCH_NAME` が空）にある
- **WHEN** 新ルート選択後、Step 5a でその worktree を処理する番になる
- **THEN** AskUserQuestion で「1) スキップ / 2) 破棄削除 (force)」の 2 択のみが提示される
- **AND** 表示文言に「⚠️ detached HEAD のためマージできません」と理由が明示される

### Requirement: マージ実行はメインリポの MAIN_BRANCH チェックアウト下で `git merge --no-ff` により行う

`wt-clean` は新ルートで「マージ」が選択された worktree について、メインリポで `MAIN_BRANCH` をチェックアウトした状態で `git merge "$BRANCH_NAME" --no-ff -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"` を実行するものとする（SHALL）。`BRANCH_NAME` は既存 Step 1 と同じく `git worktree list` から抽出した worktree のチェックアウト中ブランチ名そのもの（`feature/` 等のプレフィックスは含まない）。

#### Scenario: 「マージ」選択時に正しいコマンドで実行される

- **GIVEN** メインリポが `$MAIN_BRANCH` をチェックアウト中であり、worktree のブランチ `feat-x` に未マージのコミットがある
- **WHEN** ユーザーが新ルートで `feat-x` の「マージ」を選択する
- **THEN** メインリポで `git checkout $MAIN_BRANCH` 確認後、`git merge feat-x --no-ff -m "merge: integrate feat-x (wt-clean active merge)"` が実行される
- **AND** `MAIN_BRANCH` の HEAD に新しい merge commit が積まれる

#### Scenario: メインリポが MAIN_BRANCH 以外をチェックアウト中なら新ルート中断

- **GIVEN** メインリポが `$MAIN_BRANCH` ではない別ブランチをチェックアウト中
- **WHEN** ユーザーが新ルートを選択する
- **THEN** Step 5b 開始時に検証で失敗し、新ルート全体を中断する
- **AND** 「`cd $MAIN_REPO && git checkout $MAIN_BRANCH` してから wt-clean を再実行してください」と案内が表示される

#### Scenario: メインリポで merge in progress 中なら新ルート中断

- **GIVEN** メインリポの `.git/MERGE_HEAD` が存在する（前回のマージが未解決）
- **WHEN** ユーザーが新ルートを選択し Step 5b に入る
- **THEN** Step 5b の事前確認で `.git/MERGE_HEAD` の存在を検出する
- **AND** 新ルート全体を中断する
- **AND** 「`cd $MAIN_REPO` で `git status` を確認し、競合解決→commit、または `git merge --abort` してから wt-clean を再実行してください」と案内が表示される

### Requirement: マージ成功した worktree はサニティチェック対象に含め、PASS なら通常削除する

新ルートでマージ成功した worktree について、`wt-clean` はそのブランチ名を `MERGED_BRANCHES` 配列（push 順）に追記し、Step 6d のチェック対象判定でこの配列を参照することで、新ルートでマージ昇格した worktree もサニティチェック対象に含めるものとする（SHALL）。チェック PASS なら Step 7a の通常削除（`git worktree remove` + `git branch -d`）を実行する。

#### Scenario: マージ成功 → サニティ PASS → 通常削除

- **GIVEN** 新ルートで `feat-x` の「マージ」が選択され、`git merge feat-x --no-ff` が成功し、`MERGED_BRANCHES=("feat-x")` となっている
- **WHEN** Step 6d のチェック対象判定が実行される
- **THEN** `feat-x` 対応の worktree がチェック対象に含まれる
- **AND** チェック PASS なら Step 7a で `git worktree remove <path>` + `git branch -d feat-x` が実行される

#### Scenario: `--keep` 指定でも新ルートのマージ後は通常削除になる

- **GIVEN** ユーザーが `wt-clean --keep` を実行し、新ルートで `feat-x` の「マージ」を選択
- **WHEN** Step 6d チェック PASS 後、Step 7 ルーティングが実行される
- **THEN** Step 7b（再利用化）ではなく Step 7a（通常削除）に流れる
- **AND** 完了レポートに「🔴 マージ→削除（--keep 指定だが新ルートのため通常削除）: feat-x」と理由併記で表示される

### Requirement: マージ競合時は自動 abort せず、既マージ分も含め全削除保留する

`git merge` で競合が発生した場合、`wt-clean` は `git merge --abort` を **自動実行しないものとする** （SHALL NOT）。競合状態（`MERGE_HEAD` 存在状態）を保持したまま中断し、すでにマージ成功した worktree（`MERGED_BRANCHES` に記録されたもの）も含めて Step 6 サニティチェック以降を実行せず、全て削除保留する。

#### Scenario: 競合発生で `git merge --abort` は自動実行されない（不変条件）

- **GIVEN** 新ルートで `feat-y` のマージ実行中に競合が発生する
- **WHEN** 競合検出後の処理が走る
- **THEN** `git merge --abort` は自動実行されず、`MAIN_BRANCH` は merge 進行中状態（`.git/MERGE_HEAD` が存在）のまま保持される
- **AND** ユーザーが手動で `git merge --abort` を実行するかは個別判断に委ねられる旨が案内される

#### Scenario: 複数 🔴 順次処理中の競合発生で既マージ分も全保留

- **GIVEN** 🔴 worktree が 3 件あり、ユーザーが全てに「マージ」を選択。1 件目（`feat-a`）のマージ成功で `MERGED_BRANCHES=("feat-a")`、2 件目（`feat-b`）のマージで競合発生
- **WHEN** 競合検出後の処理が走る
- **THEN** `feat-a` を含む既マージ分の Step 6 サニティチェックは実行されない
- **AND** `feat-a` 対応の worktree も削除されない（保留）
- **AND** 3 件目（`feat-c`）は未処理のまま残る
- **AND** 完了レポートに「🔴 マージ成功・削除保留: feat-a (N commits merged, awaiting conflict resolution)」「⚠️ マージ競合で中断: feat-b」「未処理: feat-c」が区別表示される

### Requirement: Step 8 完了レポートに新ルートの結果を区別して表示する

新ルートが選択された場合、`wt-clean` の Step 8 完了レポートは状況に応じて以下のいずれかを表示するものとする（SHALL）:

- 通常成功時: `🔴 マージ→削除: <branch> (N commits merged)`
- `--keep` 指定時: `🔴 マージ→削除（--keep 指定だが新ルートのため通常削除）: <branch>` + 理由併記
- 競合保留時: `🔴 マージ成功・削除保留: <branch> (N commits merged, awaiting conflict resolution)` および `⚠️ マージ競合で中断: <branch>` および `未処理: <branches>`

#### Scenario: 通常成功時のレポート表示

- **WHEN** 新ルートで 1 件マージ成功 + サニティ PASS + 通常削除が完了する
- **THEN** 完了レポートに「🔴 マージ→削除: <branch> (N commits merged)」が表示される
- **AND** 「サニティチェック: ✅ PASS」など既存項目も従来通り表示される

#### Scenario: 競合保留時のレポート表示

- **WHEN** 新ルートで 1 件マージ成功 → 別の 1 件で競合 → 1 件未処理
- **THEN** 完了レポートに「🔴 マージ成功・削除保留: <branch1>」「⚠️ マージ競合で中断: <branch2>」「未処理: <branch3>」がそれぞれ区別表示される

### Requirement: 既存ルートは新ルート追加で動作変更しない（回帰防止）

既存の以下のルートは新ルート（🔴 マージ確認）追加によって動作変更しないものとする（SHALL）:

- 「🟢🟡 のみ処理する」「🟢 のみ処理する」「全て処理する（🔴含む — 破棄ルート、危険）」「キャンセル」
- `--keep` モード（🟢 Safe の再利用化）
- `--no-sync` オプション（Step 0 スキップ）

#### Scenario: 既存「全て処理する（🔴破棄）」ルートが既存通り動作する

- **WHEN** ユーザーが新ルートではなく既存「全て処理する（🔴含む — 破棄ルート、危険）」を選択する
- **THEN** 既存仕様通り、🔴 worktree は `git worktree remove --force` + `git branch -D` で破棄削除される
- **AND** 新ルートの `MERGED_BRANCHES` 配列は使用されず、Step 6d のチェック対象判定も既存ロジックのみで動く

#### Scenario: `--keep` 単独実行が既存通り動作する

- **WHEN** ユーザーが `wt-clean --keep` を実行し、Step 3 で 🔴 がなく既存 4 択から「🟢のみ処理する」を選択する
- **THEN** Step 7b（再利用化）が既存仕様通り実行され、🟢 Safe worktree は main 切替＋元ブランチ削除で再利用可能化される
- **AND** 新ルート関連の処理は走らない

#### Scenario: `--no-sync` 指定が新ルート追加で影響を受けない

- **WHEN** ユーザーが `wt-clean --no-sync` を実行する
- **THEN** Step 0 の Remote 同期は既存仕様通りスキップされる
- **AND** 完了レポートに「Remote 同期: -- skipped (--no-sync)」が既存通り表示される
- **AND** 🔴 がある場合の新ルート選択肢は Step 3 で表示され、選んだ場合は新ルートが動作する（フラグ間の干渉なし）
