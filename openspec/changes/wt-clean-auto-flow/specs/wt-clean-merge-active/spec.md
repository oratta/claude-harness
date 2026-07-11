## MODIFIED Requirements

### Requirement: 🔴 と診断された worktree の確認は Pass 2 の判断バッチでまとめて行う

`wt-clean` は逐次処理ループ（`wt-clean-target-selection`）で 🔴 Active（未マージのコミットあり）と診断された対象を Pass 1 では操作せず `DEFERRED` に積み、Pass 1 完了後の判断バッチ（Pass 2）で AskUserQuestion により「マージ / スキップ / 破棄削除」のいずれかを選ばせるものとする（SHALL）。表示には未マージコミットの一覧（`git log --oneline $MAIN_BRANCH..$BRANCH_NAME`）、Dirty 状態、LLM ファイル有無を含める。選択肢の出し分けは従来どおり:

- Dirty なし & ブランチ名あり: 「1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)」の 3 択
- Dirty あり: マージ選択肢を除外した 2 択 + 「⚠️ Dirty な変更があるため main にマージできません」の理由明示
- detached HEAD: マージ選択肢を除外した 2 択 + 「⚠️ detached HEAD のためマージできません」の理由明示

複数の 🔴 がある場合は 1 対象 1 問で 1 回の AskUserQuestion に最大 4 問までまとめ、超過分は複数回に分けて提示範囲を明示する。破棄削除・マージの実行は回答を受け取った後の別ターンで行う。

#### Scenario: 複数の 🔴 が 1 回の質問にまとめられる

- **GIVEN** TARGETS の診断で 🔴 が 3 件 DEFERRED に積まれている
- **WHEN** Pass 2 の判断バッチが実行される
- **THEN** 3 件分の選択が 1 回の AskUserQuestion（3 問）でまとめて提示される
- **AND** 各問の表示に当該対象の未マージコミット一覧が含まれる

#### Scenario: Dirty なし 🔴 では 3 択が提示される

- **WHEN** 判断バッチで Dirty を持たない 🔴 worktree の問が提示される
- **THEN** 「1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)」の 3 択が提示される

#### Scenario: Dirty 同時 🔴 ではマージ選択肢が除外される

- **WHEN** 判断バッチで Dirty（未コミット変更）を持つ 🔴 worktree の問が提示される
- **THEN** 「1) スキップ / 2) 破棄削除 (force)」の 2 択のみが提示される
- **AND** 「⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）」と理由が明示される

#### Scenario: detached HEAD の 🔴 worktree はマージ選択肢が除外される

- **GIVEN** 🔴 worktree が detached HEAD 状態（`BRANCH_NAME` が空）にある
- **WHEN** 判断バッチでその worktree の問が提示される
- **THEN** 「1) スキップ / 2) 破棄削除 (force)」の 2 択のみが提示される
- **AND** 「⚠️ detached HEAD のためマージできません」と理由が明示される
