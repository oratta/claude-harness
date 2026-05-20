# Plan: wt-clean に🔴 Active worktree のマージ確認フェーズを追加

## 生成情報
- 作成日: 2026-05-20
- Brain Dump元: セッション内（/longrun:plan 引数）
- 質問回数: 3問

## ゴール
`wt-clean` が🔴 Active worktree（未マージコミットあり）を検出した際、現状の「スキップ／全件破棄」に加えて「main にマージしてからクリーンアップ」する選択肢を**最優先（推奨）**として提示し、ユーザー個別確認のもとでマージ→サニティチェック→削除までを一気通貫で実行できるようにする。

## ビジネスコンテキスト
- 対象ユーザー: oratta（claude-harness マーケットプレイス保守者）。日常的に Superset / Agent / 手動で worktree を量産する開発者
- 提供価値: GitHub に push する前に作業がローカル完結したケース（PR 経由ではなく main 直マージ運用）で、`wt-clean` が「未マージあり → スキップ」と止まるたびに手動で `git merge` → `wt-clean` 再実行する往復が発生していた。最頻パス（=安全にマージしてしまいたい）をデフォルト推奨にすることで往復を一手で済ませる
- 成功指標:
  - 🔴 Active worktree が 1 件以上ある状態で `wt-clean` を実行したとき、main へのマージ→削除までを 1 セッションで完了できるシナリオが PASS する
  - 既存「全件破棄ルート」「スキップ」「`--keep`」のいずれにも回帰がないこと（スナップショット的に既存 Scenarios が全件 PASS のまま）

## 技術要件
- スタック: Bash + Markdown（Claude Code Skill / Command）。新規ランタイム導入なし
- 参照パターン:
  - 既存 `openspec/specs/wt-clean-remote-sync/spec.md`（Step 0 拡張の前例）
  - 既存 `openspec/specs/wt-clean-reuse/spec.md`（`--keep` モード拡張の前例）
  - `plugins/worktree/commands/wt-clean.md` の Step 1〜8 構造
  - longrun-orchestrator の worktree マージ手順（`git merge feature/<name> --no-ff -m "..."` のパターン）
- 制約:
  - 既存ルート（「🟢🟡のみ」「全て処理（🔴破棄）」「キャンセル」「`--keep`」「`--no-sync`」）を**破壊しない**。新ルートは追加のみ
  - マージ実行は必ず `git merge --no-ff`。fast-forward を許してマージコミットを省略してはならない（履歴トレーサビリティ確保）
  - 競合時は `git merge --abort` を**自動で実行しない**。ユーザーが状態を確認して判断できるよう競合状態を保持する
  - dirty（未コミット変更あり）と 🔴 が同時の worktree は**マージ対象から自動除外**する（merge は clean working tree が前提のため）
- テストフレームワーク: 手動シナリオ検証（既存の wt-clean spec 群と同じ運用。OpenSpec spec.md の Scenarios = テスト仕様 = 動作確認手順）
- テスト実行コマンド: 手動シナリオ実行（後述「動作確認方法」参照）。bats 等の自動化は本 change のスコープ外

## スコープ
### 含むもの
- `plugins/worktree/commands/wt-clean.md` の以下の拡張:
  - **Step 3 レポート選択肢の先頭**に「🔴 を main にマージしてから処理（推奨・安全）」を追加
  - **新規 Step 5a「🔴 個別マージ確認」**を Step 5 直後に挿入（per-worktree で「マージ / スキップ / 破棄削除」の3択）
  - **Step 5b「マージ実行とエラーハンドリング」**を新設（`git merge --no-ff` 実行、競合時の中断と案内）
  - **Step 6（サニティチェック）対象範囲の拡張**（マージ成功した 🔴 → 🟢 Safe 相当扱いに格上げしてチェック対象に含める）
  - **Step 8 完了レポート**に新ルート用の表示（マージ件数、競合保留件数）を追加
- 新規 OpenSpec change `wt-clean-merge-active`:
  - `proposal.md` / `tasks.md` / `design.md` / `specs/wt-clean-merge-active/spec.md`（capability spec、WHEN/THEN Scenarios で受け入れ条件を仕様化）
- 既存 spec への delta が必要なら最小限で記述（基本は新 capability として独立させる）

### 含まないもの
- 自動マージ戦略の高度化（`git rebase` / `cherry-pick` 等の代替手段提供）: 理由 = スコープ過大、`--no-ff merge` で十分にゴールを達成可能
- 競合の自動解決（`-X ours` / `-X theirs` 等のオプション露出）: 理由 = 安全側に倒すために中断→人手解決を採用したため
- dirty 同時 🔴 への「force-commit してマージ」ルート: 理由 = ユーザー意図しないコミット作成のリスクが高い。明示的にスキップ／破棄を選ばせる
- `--keep` モードとの統合（マージ後の worktree を再利用化）: 理由 = マージ後はブランチ削除済みで「再利用化＝main切替」が実質ノーオペになるため、別ルートで処理する意味がない。`--keep` 指定時に新ルートを選んだ場合は通常削除フォールバック
- bats 等の自動テストハーネス整備: 理由 = 既存 wt-clean spec 群と同様、手動シナリオで仕様化する方針。自動化は別 change

## Changes分解

### change-A: wt-clean-merge-active
- **スコープ**:
  - `plugins/worktree/commands/wt-clean.md` の Step 3 / 新規 Step 5a / 新規 Step 5b / Step 6 / Step 8 を編集
  - **Step 6d「チェック対象の範囲」のロジック改修**: 新ルートでマージ昇格した 🔴 → 🟢 相当を「今回マージした」枠に含めるための `MERGED_BRANCHES` 配列状態管理を追加（既存の `git branch --merged` 判定の補完）
  - 新規 OpenSpec change `openspec/changes/wt-clean-merge-active/` を作成（proposal / tasks / design / specs/<capability>/spec.md）
  - `plugins/worktree/.claude-plugin/plugin.json` の `version` を **minor bump**（現バージョン X.Y.Z → X.(Y+1).0）。理由: 既存 API 互換を保ちつつ機能追加のため
  - `.claude-plugin/marketplace.json` の worktree エントリ `version` を同期（同じ minor bump）
- **使用スキル**: なし（自力編集）
- **依存関係**: 独立（既存 wt-clean spec への delta は不要、新規 capability として追加するため）
- **config.yaml rules**:
  - "wt-clean.md の Step 構造は既存ナンバリングを破壊せず、新規 Step は 5a / 5b として挿入する"
  - "spec.md は WHEN/THEN 形式の Scenarios を最低 6 件含める（推奨提示・マージ成功・competing選択・競合中断・dirty同時・既存ルート維持の回帰防止 + 競合自動 abort をしない不変条件）"
  - "OpenSpec validate を必ず実行し PASS させる"
  - "competing 既存ルート（全件破棄 / スキップ / `--keep`）が新ルート追加で動作変更しないことを Scenarios で明示する"
  - "merge は必ずメインリポで `MAIN_BRANCH` をチェックアウトした上で実行する（`cd $MAIN_REPO && git checkout $MAIN_BRANCH && git merge ...`）"

## 画面・UI設計

### Step 3 のレポート選択肢（🔴 がある場合のみ第一選択肢を追加）

```
Worktree診断結果 (モード: 削除 / --keep で再利用):

| Worktree | Branch | 状態 | 未マージ | Dirty | LLM | 推奨 |
|----------|--------|------|----------|-------|-----|------|
| /path/a  | feat-x | 🟢 Safe | 0 | No | No | 削除 |
| /path/c  | wip-z  | 🔴 Active | 3 | No | No | main にマージ→削除 (推奨) |

選択肢:
  1) 🔴 を main にマージしてから処理 (推奨・安全)  ← New
  2) 🟢🟡 のみ処理する
  3) 🟢 のみ処理する
  4) 全て処理する（🔴含む — 破棄ルート、危険）
  5) キャンセル
```

🔴 が 0 件の場合: 選択肢 1 を出さず、従来通り「🟢🟡を処理する」「🟢のみ処理する」「全て処理する」「キャンセル」の 4 択を提示する（既存挙動を完全に保持）。

🔴 がある場合に「🟢 のみ処理する」を 5 択中の 1 つとして含める理由: 既存 wt-clean.md Step 3 の 4 択を破壊せず、新選択肢 1 を**先頭に挿入するだけ**にすることで、既存ルート全てが動作変更なく利用可能であることを保証する（回帰防止優先）。

### Step 5a: 🔴 個別マージ確認（新ルート選択時のみ）

🔴 worktree を 1 つずつ AskUserQuestion で確認:

```
🔴 wip-z の処理:
  Branch: feat-wip
  未マージコミット: 3件
    abc1234 feat: ユーザー登録フォームの追加
    def5678 fix: バリデーションエラー
    ghi9012 chore: テスト整備
  Dirty: なし
  LLM: なし

選択肢:
  1) main にマージ (推奨)
  2) スキップ
  3) 破棄削除 (force)
```

dirty が同時にある場合は「1) main にマージ」を**選択肢から除外**し、表示文言で理由を明示:

```
🔴 wip-z の処理:
  Branch: feat-wip
  未マージコミット: 3件
  Dirty: 2 files (uncommitted changes)
  LLM: なし

⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）。

選択肢:
  1) スキップ
  2) 破棄削除 (force)
```

### Step 5b: マージ実行とエラーハンドリング（新ルート選択時のみ）

マージ実行は**必ずメインリポで `MAIN_BRANCH` をチェックアウトした状態で行う**（既存 wt-clean.md の `git -C "$WORKTREE_PATH"` 規約と整合）:

```bash
cd "$MAIN_REPO"

# 事前確認: メインリポが MAIN_BRANCH をチェックアウト中か（Step 1 と同じ MAIN_BRANCH 検出ロジック）
CURRENT_BRANCH=$(git -C "$MAIN_REPO" branch --show-current)
if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
  # メインリポが別ブランチをチェックアウト中（レアケース）→ 新ルート全体を中断
  echo "⚠️ メインリポが $MAIN_BRANCH 以外をチェックアウト中（$CURRENT_BRANCH）。新ルートを中断します。"
  echo "  対応: cd $MAIN_REPO && git checkout $MAIN_BRANCH してから wt-clean を再実行してください。"
  exit 1
fi

# マージ実行（成功時のメッセージ）
git -C "$MAIN_REPO" merge "$BRANCH_NAME" --no-ff -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"
# → 成功した BRANCH_NAME を MERGED_BRANCHES 配列に push（Step 6d で使用）
MERGED_BRANCHES+=("$BRANCH_NAME")
```

成功時表示:
```
🔴 wip-z を main にマージ中:
  cd <main-repo> && git checkout main && git merge feat-wip --no-ff -m "merge: integrate feat-wip (wt-clean active merge)"
  ✅ マージ成功（3 commits, 5 files changed）

→ Step 6 サニティチェック対象に追加（MERGED_BRANCHES に記録）
```

競合時:

```
⚠️ マージで競合が発生しました:
  Branch: feat-wip → main
  Conflict files:
    src/foo.ts
    src/bar.ts

対応手順:
  1. cd <main-repo>
  2. 競合を解決して `git add` + `git commit`
  3. wt-clean を再実行

※ feat-wip worktree は削除されていません（競合状態を保持しています）。
※ 他の 🔴 worktree の処理も中断しました（順序依存を避けるため）。
※ **すでに今回 wt-clean でマージ成功した 🔴 worktree（MERGED_BRANCHES に記録されたもの）も Step 6 サニティチェック以降を実行せず、削除を全て保留します**（中途半端な状態を避けるため安全側に倒す）。
※ `git merge --abort` で main を元に戻したい場合は手動で実行してください（自動 abort はしません）。
```

### Step 8 完了レポート

新ルート選択時の完了レポートに以下を追記:

```
wt-clean 完了:
  Remote 同期: ✅ pulled 0 commits (already up-to-date)
  処理: 2 worktrees
  🔴 マージ→削除: wip-z (3 commits merged)
  削除: feat-x (🟢)
  サニティチェック: ✅ PASS (npm test, npm run build)
  スキップ: なし
  残存worktrees: 0
```

`--keep` 指定時に新ルートを選んだ場合（マージ後は通常削除）:

```
wt-clean --keep 完了:
  Remote 同期: ✅ already up-to-date
  処理: 1 worktree
  🔴 マージ→削除（--keep 指定だが新ルートのため通常削除）: wip-z (3 commits merged)
    理由: マージ後はブランチが削除済みで「再利用化＝main切替」が実質ノーオペのため
  サニティチェック: ✅ PASS
  残存worktrees: 0
```

競合保留時（複数 🔴 を順次処理中に競合発生 → 既マージ成功分も全保留）:

```
wt-clean 中断:
  Remote 同期: ✅ already up-to-date
  処理: 3 worktrees (中断)
  🔴 マージ成功・削除保留: wip-z (3 commits merged, awaiting conflict resolution)
      → 競合解決後の wt-clean 再実行時に Step 6 サニティチェック以降を実行します
  ⚠️ マージ競合で中断: wip-y (src/foo.ts, src/bar.ts)
      → 競合解決後に wt-clean を再実行してください
  未処理: wip-x (🔴)
  残存worktrees: 3
```

## データモデル
永続データ無し、git の状態のみを操作。ただしセッション内変数として以下を管理する:

### セッション内状態管理（新ルート使用時のみ）

```bash
# 新ルートで実際にマージ成功したブランチ名を順次蓄積する配列
# - push 順 = マージ順を保持（Step 6 FAIL 時の「FAIL したマージ以降を保留」既存仕様と整合）
# - Step 5b の git merge 成功直後に append: MERGED_BRANCHES+=("$BRANCH_NAME")
# - Step 6d のサニティチェック対象判定で参照（既存の `git branch --merged` 判定の補完）
# - Step 5b で競合発生時、本配列は変更しない（既マージ分は記録済み）が、Step 6 以降は実行せず全て削除保留
MERGED_BRANCHES=()
```

Step 6d 「チェック対象の範囲」の改修（既存ロジックの補完）:
- 既存: 「🟢 Safe かつ今回の wt-clean で新たにマージした worktree」をチェック対象とする
- 改修後: 「🟢 Safe かつ今回の wt-clean で新たにマージした worktree」**または**「`MERGED_BRANCHES` に含まれるブランチに対応する worktree」をチェック対象とする
- 競合発生で中断した場合: Step 6 自体を実行せず、`MERGED_BRANCHES` に記録された worktree も全て削除保留

worktree 状態の遷移:

```
🔴 Active (未マージあり、Dirty なし)
  ──(マージ選択)──→ git merge --no-ff → 🟢 Safe 相当 → Step 6 → 削除
  ──(スキップ選択)──→ 状態維持
  ──(破棄選択)──→ git worktree remove --force + git branch -D

🔴 Active (未マージあり、Dirty あり)
  ──(スキップ選択)──→ 状態維持
  ──(破棄選択)──→ git worktree remove --force + git branch -D
  (「マージ」選択肢は表示しない)
```

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み（`openspec validate` PASS）
2. [ ] 全changeのテスト（=spec の Scenarios の手動シナリオ実行）が作成され全てPASSしている
3. [ ] ビルドエラーなし（このプロジェクトでは Markdown 主体のためビルドステップは N/A だが、`plugin.json` の構文検証 = `python -m json.tool` で PASS）
4. [ ] 統合テスト PASS（plugin reload 後に `/wt-clean` 起動 → 既存ルート＋新ルートが期待通り動く手動確認）

**機能固有の条件:**
5. [ ] 🔴 Active worktree が 1 件以上ある状態で `wt-clean` を実行すると、Step 3 の選択肢の**先頭**に「🔴 を main にマージしてから処理 (推奨・安全)」が表示される
6. [ ] 🔴 が 0 件の場合、新選択肢は表示されない（既存4択のみ）
7. [ ] 新ルートを選択すると、🔴 worktree 1 個ごとに AskUserQuestion で「マージ / スキップ / 破棄削除」の3択（Dirty 同時時は「スキップ / 破棄削除」の2択）が提示される
8. [ ] 「マージ」を選択した worktree は `git merge "$BRANCH_NAME" --no-ff -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"` でメインブランチにマージされる（`BRANCH_NAME` は既存 wt-clean.md Step 1 と同じく `git worktree list` から抽出した worktree のチェックアウト中ブランチ名そのもの。`feature/` 等のプレフィックスは含まない）
9. [ ] マージ成功した worktree は Step 6 サニティチェックの対象に含まれ、PASS なら Step 7a で `git worktree remove` + `git branch -d` される
10. [ ] マージで競合が発生した場合、`git merge --abort` を自動実行**せず**、競合状態を保持したまま中断する。中断時点で**すでにマージ成功した worktree（`MERGED_BRANCHES` に記録されたもの）も含め、Step 6 サニティチェック以降は実行しない**（全て削除保留）。完了レポートに「🔴 マージ成功・削除保留」「⚠️ マージ競合で中断」「未処理」を区別して表示する
11. [ ] Dirty が同時にある 🔴 にはマージ選択肢が**表示されない**（merge は clean working tree が前提のため）。「スキップ / 破棄削除」の 2 択のみ提示される
12. [ ] 既存の「🟢🟡のみ処理する」「🟢 のみ処理する」「全て処理する（🔴破棄、危険）」「キャンセル」「`--keep`」「`--no-sync`」の全ルートが、新ルート追加によって動作変更しない（回帰防止）
13. [ ] `--keep` 指定時に新ルートを選んだ場合、マージ後の worktree は再利用化せず通常削除する（マージ後はブランチが消えており再利用化＝main切替の意味が薄いため）。**完了レポートに「`--keep` 指定だが新ルートのため通常削除」である旨を明示**する（観測可能性）
14. [ ] Step 8 完了レポートに状況に応じて以下が表示される: 通常完了時「🔴 マージ→削除: <branch> (N commits merged)」 / `--keep` 時「🔴 マージ→削除（--keep 指定だが新ルートのため通常削除）: <branch>」 / 競合保留時「🔴 マージ成功・削除保留: <branch> (N commits merged, awaiting conflict resolution)」「⚠️ マージ競合で中断: <branch>」
15. [ ] メインリポが `MAIN_BRANCH` 以外をチェックアウト中の場合、新ルート実行を中断し、`cd $MAIN_REPO && git checkout $MAIN_BRANCH` してから再実行するよう案内する（merge 実行コンテキストの一貫性確保）
16. [ ] spec.md に「マージで競合が発生しても `git merge --abort` を自動実行しない」不変条件の Scenario を 1 件含める（main 履歴の意図せぬ巻き戻しを防ぐため）

## 意思決定ガイドライン
- 優先順位: 安全性 > 既存仕様との後方互換 > シンプルさ > 拡張性
- リスク許容度: 保守的（git 履歴に直接書き込むため、競合時 abort や force-merge は禁止）
- 不明点の扱い:
  - 「マージ」と「破棄」が両方理屈上ありえるケースでは**マージを推奨**として明示し、ユーザーの能動的選択で破棄させる
  - 既存ルートの動作変更可能性が出てきたら**変更しない**側を選ぶ（回帰防止優先）
  - dirty / detached HEAD / merge in progress 等のレアケースに遭遇したら、新ルートを**選択肢から外す**または「スキップ」フォールバックを選び、エラーで止めない

## 動作確認方法

### 環境準備
本プラグインは Markdown 主体で実行ランタイムを持たないため、サンドボックス git repo を作成して手動シナリオを実行する。

```bash
# サンドボックス作成（ホストの作業 repo を汚さないため /tmp 配下を推奨）
SANDBOX=/tmp/wt-clean-merge-confirm-sandbox-$$
mkdir -p "$SANDBOX" && cd "$SANDBOX"
git init -q && git commit --allow-empty -m "init" -q
```

### テスト実行コマンド
```bash
# シナリオ 1: 🔴 Active 1件 + マージ成功
git worktree add wt-a -b feat-a
cd wt-a && echo "hello" > a.txt && git add a.txt && git commit -m "feat: a" && cd ..

# Claude Code セッションで /wt-clean を実行（手動）
# 期待: 選択肢 1) に「🔴 を main にマージしてから処理 (推奨・安全)」が出る
# → 選択 → wt-a に対し「マージ」を選択 → main に merge commit が積まれ wt-a が削除される
git log --oneline   # merge commit を確認
test -d wt-a && echo "FAIL: worktree not removed" || echo "PASS"
```

シナリオ一覧（全件手動で実行 / それぞれが spec.md の Scenarios に対応）:
- S1: 🔴 1件、Dirty なし、マージ選択 → 成功
- S2: 🔴 1件、Dirty なし、スキップ選択 → 状態維持
- S3: 🔴 1件、Dirty なし、破棄選択 → force 削除
- S4: 🔴 1件、Dirty あり → マージ選択肢が表示されない（2択になる）
- S5: 🔴 2件、両方マージ選択 → 順次マージ → 両方削除
- S6: 🔴 が複数（3 件）、1 件目マージ成功 → 2 件目で競合発生 → 1 件目も含め全削除保留、3 件目未処理。完了レポートで「マージ成功・削除保留」「マージ競合で中断」「未処理」が区別表示される。main 履歴に `git merge --abort` の痕跡がない（merge 進行中状態のまま保持）
- S7: 🔴 0件 → 新選択肢が出ない（既存4択のみ）
- S8: 既存「全て処理する（🔴破棄）」ルートを選択 → 既存通り破棄削除（回帰防止）
- S9: `--keep` で新ルート選択 → マージ後の worktree は通常削除（再利用化しない）。完了レポートに「`--keep` 指定だが新ルートのため通常削除」と明示される
- S10: `--no-sync` で新ルート選択 → Step 0 スキップ＋新ルート動作（フラグ非干渉確認）
- S11: メインリポが MAIN_BRANCH 以外をチェックアウト中 → 新ルート実行を中断し、checkout 案内が表示される（merge コンテキスト一貫性）

### 確認手順
1. plugin を再読み込み（または cache 経由なら version bump 後に `/reload-plugins`）
2. 上記サンドボックスで S1〜S11 を順番に実行
3. 各シナリオで spec.md 該当 Scenario の THEN 条件を満たすことを目視確認
4. 完了レポート（Step 8）の出力が「機能固有条件 14」と一致することを確認
5. 既存テスト用シナリオ（wt-clean-remote-sync / wt-clean-reuse の spec.md にあるもの）も 1 件ずつ再実行して回帰がないことを確認

## Brain Dumpからの原文メモ
> wt-cleanの拡張をしたい。wt-cleanを実行するときに対象のワークツリーに未マージのコミットがあったら作業を止めてるけど、その時のオプションとしてユーザに確認してmainへのマージ実行することをプライオリティファーストにしてほしい。
