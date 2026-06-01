## REMOVED Requirements

### Requirement: wt-clean は 🔴 Active worktree がある場合に main マージ確認ルートを最優先選択肢として提示する

**Reason**: 全件先診断 → Step 3 一括モード選択というフロー自体が `wt-clean-target-selection` の「選択 → 逐次遅延診断」フローに置き換わる。対象選択は色（🟢🟡🔴）を見ずに行うため、「🔴 があるかどうかで Step 3 の一括選択肢を増減する」という仕組みが不要になる。

**Migration**: 🔴 のマージ確認は、逐次処理ループで当該 worktree が 🔴 と診断された時にその場で行う（本 delta の MODIFIED「🔴 と診断された worktree ごとの個別確認を行う」を参照）。

### Requirement: 既存ルートは新ルート追加で動作変更しない（回帰防止）

**Reason**: 本要件が回帰防止対象としていた既存ルート（「🟢🟡 のみ処理する」「🟢 のみ処理する」「全て処理する（🔴破棄）」の一括 4 択）が `wt-clean-target-selection` への刷新で廃止されるため、これらの不変性を保証する要件自体が意味を失う。

**Migration**: 一括処理は `wt-clean-target-selection` の対象選択 UI で「全て」を選ぶことに統合される。`--keep`（再利用化）・`--no-sync`（Step 0 スキップ）の挙動は各々 `wt-clean-reuse` / `wt-clean-remote-sync` の delta で逐次フロー上に再定義される。

## MODIFIED Requirements

### Requirement: 🔴 と診断された worktree ごとの個別確認を行う

`wt-clean` は逐次処理ループ（`wt-clean-target-selection`）で対象 worktree が 🔴 Active（未マージのコミットあり）と診断された時、その場で AskUserQuestion により「マージ / スキップ / 破棄削除」のいずれかを選ばせるものとする（SHALL）。表示には未マージコミットの一覧（`git log --oneline $MAIN_BRANCH..$BRANCH_NAME`）、Dirty 状態、LLM ファイル有無を含める。独立した「Step 3 先頭の一括選択肢」や「新ルート」を経由しない。

#### Scenario: Dirty なし 🔴 では 3 択が提示される

- **WHEN** 逐次処理ループで Dirty を持たない 🔴 worktree を処理する番になる
- **THEN** AskUserQuestion で「1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)」の 3 択が提示される
- **AND** 表示に未マージコミット一覧が含まれる

#### Scenario: Dirty 同時 🔴 ではマージ選択肢が除外される

- **WHEN** 逐次処理ループで Dirty（未コミット変更）を持つ 🔴 worktree を処理する番になる
- **THEN** AskUserQuestion で「1) スキップ / 2) 破棄削除 (force)」の 2 択のみが提示される
- **AND** 表示文言に「⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）」と理由が明示される

#### Scenario: detached HEAD の 🔴 worktree はマージ選択肢が除外される

- **GIVEN** 🔴 worktree が detached HEAD 状態（`BRANCH_NAME` が空）にある
- **WHEN** 逐次処理ループでその worktree を処理する番になる
- **THEN** AskUserQuestion で「1) スキップ / 2) 破棄削除 (force)」の 2 択のみが提示される
- **AND** 表示文言に「⚠️ detached HEAD のためマージできません」と理由が明示される

### Requirement: マージ実行はメインリポの MAIN_BRANCH チェックアウト下で `git merge --no-ff` により行う

`wt-clean` は逐次処理ループで 🔴 worktree の「マージ」が選択された場合、メインリポで `MAIN_BRANCH` をチェックアウトした状態で `git merge "$BRANCH_NAME" --no-ff -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"` を実行するものとする（SHALL）。`BRANCH_NAME` は `git worktree list` から抽出した worktree のチェックアウト中ブランチ名そのもの（`feature/` 等のプレフィックスは含まない）。

#### Scenario: 「マージ」選択時に正しいコマンドで実行される

- **GIVEN** メインリポが `$MAIN_BRANCH` をチェックアウト中であり、worktree のブランチ `feat-x` に未マージのコミットがある
- **WHEN** ユーザーが逐次処理ループで `feat-x` の「マージ」を選択する
- **THEN** メインリポで `git checkout $MAIN_BRANCH` 確認後、`git merge feat-x --no-ff -m "merge: integrate feat-x (wt-clean active merge)"` が実行される
- **AND** `MAIN_BRANCH` の HEAD に新しい merge commit が積まれる

#### Scenario: メインリポが MAIN_BRANCH 以外をチェックアウト中ならマージ処理を中断

- **GIVEN** メインリポが `$MAIN_BRANCH` ではない別ブランチをチェックアウト中
- **WHEN** 逐次処理ループで「マージ」が選択される
- **THEN** マージ実行前の検証で失敗し、マージ処理を中断する
- **AND** 「`cd $MAIN_REPO && git checkout $MAIN_BRANCH` してから wt-clean を再実行してください」と案内が表示される

#### Scenario: メインリポで merge in progress 中ならマージ処理を中断

- **GIVEN** メインリポの `.git/MERGE_HEAD` が存在する（前回のマージが未解決）
- **WHEN** 逐次処理ループで「マージ」が選択される
- **THEN** 事前確認で `.git/MERGE_HEAD` の存在を検出してマージ処理を中断する
- **AND** 「`cd $MAIN_REPO` で `git status` を確認し、競合解決→commit、または `git merge --abort` してから wt-clean を再実行してください」と案内が表示される

### Requirement: マージ成功直後に都度サニティチェックを行い PASS なら削除する

`wt-clean` は逐次処理ループでマージが成功した worktree について、その直後にメインリポでサニティチェック（テスト/ビルドの自動検出と実行）を行うものとする（SHALL）。チェック PASS ならその worktree を通常削除（`git worktree remove` + `git branch -d`）する。テストコマンドが検出できない場合はチェックをスキップして削除に進む。従来の「全マージ後にバッチ 1 回」「`MERGED_BRANCHES` 配列で Step 6d 判定」方式は用いない。

#### Scenario: マージ成功 → 都度サニティ PASS → 通常削除

- **GIVEN** 逐次処理で `feat-x` の「マージ」が選択され `git merge feat-x --no-ff` が成功する
- **WHEN** マージ直後のサニティチェックが実行され PASS する
- **THEN** `git worktree remove <path>` + `git branch -d feat-x` が実行される

#### Scenario: マージ成功 → 都度サニティ FAIL → 当該を保留

- **GIVEN** 逐次処理で `feat-x` のマージが成功する
- **WHEN** マージ直後のサニティチェックが FAIL する
- **THEN** `feat-x` 対応の worktree は削除されず保留される
- **AND** 失敗コマンドとエラー出力の抜粋、および「このマージが原因の可能性」が表示される

#### Scenario: `--keep` 指定でもマージ後は通常削除になる

- **GIVEN** ユーザーが `wt-clean --keep` を実行し、逐次処理で `feat-x` の「マージ」を選択
- **WHEN** マージ後の都度サニティチェックが PASS する
- **THEN** 再利用化ではなく通常削除（`git worktree remove` + `git branch -d`）が実行される
- **AND** 完了レポートに「🔴 マージ→削除（--keep 指定だがマージ後のため通常削除）: feat-x」と理由併記で表示される

### Requirement: マージ競合時は自動 abort せず中断し、先行処理済みは確定済みとして扱う

逐次処理ループのマージで競合が発生した場合、`wt-clean` は `git merge --abort` を **自動実行しないものとする**（SHALL NOT）。競合状態（`.git/MERGE_HEAD` 存在状態）を保持したまま当該 worktree の処理を中断する。逐次＋都度サニティのため、競合より前に処理（マージ→PASS→削除）が完了した先行 TARGETS は確定済みとして扱い（巻き戻さない）、競合した worktree 以降の未処理 TARGETS は処理しない。

#### Scenario: 競合発生で `git merge --abort` は自動実行されない（不変条件）

- **GIVEN** 逐次処理で `feat-y` のマージ実行中に競合が発生する
- **WHEN** 競合検出後の処理が走る
- **THEN** `git merge --abort` は自動実行されず、`MAIN_BRANCH` は merge 進行中状態（`.git/MERGE_HEAD` が存在）のまま保持される
- **AND** ユーザーが手動で `git merge --abort` を実行するかは個別判断に委ねられる旨が案内される

#### Scenario: 競合発生時は先行処理済みを確定、以降を未処理とする

- **GIVEN** TARGETS が 3 件あり、1 件目（`feat-a`）がマージ→PASS→削除で確定、2 件目（`feat-b`）のマージで競合発生
- **WHEN** 競合検出後の処理が走る
- **THEN** `feat-a` の削除は巻き戻されず確定済みとして扱われる
- **AND** `feat-b` は競合状態を保持したまま中断され、3 件目（`feat-c`）は未処理のまま残る
- **AND** 完了レポートに「⚠️ マージ競合で中断: feat-b」「未処理: feat-c」が区別表示される

### Requirement: 完了レポートにマージ結果を区別して表示する

`wt-clean` の完了レポートは、逐次処理ループでマージが行われた場合に状況に応じて以下のいずれかを表示するものとする（SHALL）:

- 通常成功時: `🔴 マージ→削除: <branch> (N commits merged)`
- `--keep` 指定時: `🔴 マージ→削除（--keep 指定だがマージ後のため通常削除）: <branch>` + 理由併記
- サニティ FAIL 保留時: `⚠️ チェック失敗で保留: <branch> — <command> FAIL`
- 競合中断時: `⚠️ マージ競合で中断: <branch>` および `未処理: <branches>`

#### Scenario: 通常成功時のレポート表示

- **WHEN** 逐次処理で 1 件マージ成功 + 都度サニティ PASS + 通常削除が完了する
- **THEN** 完了レポートに「🔴 マージ→削除: <branch> (N commits merged)」が表示される
- **AND** 「サニティチェック: ✅ PASS」など既存項目も従来通り表示される

#### Scenario: 競合中断時のレポート表示

- **WHEN** 逐次処理で 1 件マージ成功・削除確定 → 別の 1 件で競合 → 1 件未処理
- **THEN** 完了レポートに「⚠️ マージ競合で中断: <branch2>」「未処理: <branch3>」が区別表示される
