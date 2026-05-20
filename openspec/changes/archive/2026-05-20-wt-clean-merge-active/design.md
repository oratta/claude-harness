## Context

現状 `wt-clean` の 🔴 Active worktree 処理は二者択一:

- 明示指示なし → スキップ（worktree が残る）
- 「全て処理する（🔴含む — 危険）」 → `git worktree remove --force` + `git branch -D` で**破棄**

破棄は非可逆操作で、未マージコミットが永久に失われる。一方、ローカル完結作業（PR を介さず main 直マージ）では「未マージコミット = main に取り込みたい変更」のケースが多く、ユーザーは現状 `wt-clean` を一度キャンセル → 手動 `git merge` → `wt-clean` 再実行という 3 ステップを繰り返している。

本 change ではこの最頻パスを **デフォルト推奨（プライオリティファースト）** として組み込み、未マージコミットがある場合の正攻法を「main にマージしてからクリーンアップ」とする。破棄ルートは「危険」明示のまま残す（実験ブランチを意図的に捨てたい etc. のニッチ用途用）。

## Goals / Non-Goals

**Goals:**

- 🔴 Active worktree が 1 件以上ある場合、Step 3 選択肢の先頭に「🔴 を main にマージしてから処理 (推奨・安全)」を出す
- 新ルート選択時、🔴 worktree ごとに AskUserQuestion で「マージ / スキップ / 破棄削除」の 3 択を提示し、選択に応じた処理を実行
- マージ後の worktree は Step 6 サニティチェック対象に含め、PASS なら通常削除する
- マージ競合時は安全側に倒して中断（自動 abort せず、既マージ分も含め全保留）
- 既存ルート全てが新ルート追加で動作変更しない（回帰防止）

**Non-Goals:**

- 自動マージ戦略の高度化（`git rebase` / `cherry-pick`）はしない。`--no-ff merge` で十分にゴールを達成可能
- 競合の自動解決（`-X ours` / `-X theirs`）はしない。安全側に倒すために中断→人手解決を採用
- dirty 同時 🔴 への「force-commit してマージ」ルートはしない。ユーザー意図しないコミット作成のリスクが高い
- `--keep` モードとの統合（マージ後の再利用化）はしない。マージ後はブランチ削除済みで再利用化＝main切替が実質ノーオペ
- bats 等の自動テストハーネス整備は別 change
- GitHub PR 経由のマージ確認（`gh pr merge` 等）はしない。本 change はローカル完結の `git merge` のみ

## Decisions

### Decision 1: 「マージ」を推奨デフォルトとして第一選択肢に置く

**採用**: Step 3 のレポート選択肢の **先頭** に「🔴 を main にマージしてから処理 (推奨・安全)」を出す（🔴 がある場合のみ）。

**代替案と却下理由**:

- per-worktree のみ（Step 3 はそのまま）: 既存 4 択を選んだ後で「あ、マージしたかった」となる UX のままで、入口の改善になっていない
- Step 3 にモード切替のみ（per-worktree なし）: 個別判断ができず、複数 🔴 のうち 1 件だけマージしたいケースに対応不能
- 両方（モード切替＋個別確認）: 採用。Step 3 で大方針を選ばせ、Step 5a で個別判断を取る2段構え

**根拠**: ユーザーの最頻パス「未マージコミットを main に取り込みたい」をデフォルト推奨にしつつ、個別判断の自由度も保つ。

### Decision 2: マージは `git merge --no-ff` でメインリポから実行

**採用**: `cd "$MAIN_REPO" && git checkout "$MAIN_BRANCH" && git merge "$BRANCH_NAME" --no-ff -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"` で実行する。

**代替案と却下理由**:

- fast-forward 許容（`--no-ff` なし）: マージコミットが省略され、main 履歴に「いつ・なぜ feature が取り込まれたか」のトレーサビリティが残らない
- `git merge -X ours/theirs`: 競合自動解決は本 change のスコープ外（安全側に倒す方針と矛盾）
- worktree 内で `git push origin <main>` 相当の操作: メインリポではなく worktree からの操作は既存 wt-clean のルール（worktree 内では `git -C "$WORKTREE_PATH"` を明示する）と整合しない

**根拠**: longrun-orchestrator の worktree マージパターン（`git merge feature/<change-name> --no-ff -m "merge: integrate ..."`）と一貫させる。マージコミットは履歴の意図を保持する重要なメタデータ。

### Decision 3: 競合時は自動 abort せず中断、既マージ分も全削除保留

**採用**: マージで競合が発生した場合、`git merge --abort` を**自動実行せず**競合状態を保持。すでにマージ成功した worktree（`MERGED_BRANCHES` に記録）も含め Step 6 以降を実行せず、全て削除保留する。

**代替案と却下理由**:

- 自動 abort して該当 🔴 をスキップ扱いに戻す: main 履歴は元に戻るが、ユーザーが「abort 不要だった」と気づいて再 merge する負担が増える。何より「自動で main 履歴を巻き戻す」は外部の merge commit を失うリスクが理論上ある
- 既マージ分は予定通り削除し、競合分のみ保留: 中途半端な状態が残り、後続再実行時のトラッキングが複雑化する
- 競合発生時に AskUserQuestion で都度確認: 自律実行中の対話増加。安全側に倒すなら自動で中断する方が一貫する

**根拠**: 「迷ったら安全側」原則。main 履歴は不可逆なので、自動操作の範囲は最小に留め、ユーザーが手動で `git merge --abort` するかを判断できる状態で停止する。既マージ分も巻き込んで保留することで、再実行時の状態管理を単純化（「全部やり直し」に統一）。

### Decision 4: Dirty 同時 🔴 はマージ選択肢を表示しない

**採用**: 🔴 worktree に Dirty（未コミット変更）がある場合、AskUserQuestion の選択肢から「マージ」を除外し、「スキップ / 破棄削除」の 2 択のみ提示する。

**代替案と却下理由**:

- 「マージ」選択時に自動で `git stash` してから merge: stash は git の状態を勝手にいじる隠れた副作用。後でユーザーが「stash した変更を忘れた」事故につながる
- 「マージ」選択時に自動で `git add -A && git commit -m "WIP"` してから merge: ユーザー意図しないコミット作成は重大な副作用
- 「マージ」を選んだら警告メッセージで dirty を伝え、ユーザーがコミット後に再実行: 1 step 増えるが、安全性は高い。ただし AskUserQuestion で選択肢として出すと「選べるのに失敗する」UX になるため除外の方がクリーン

**根拠**: merge は clean working tree が前提。Dirty 状態でマージを選ばせると `git merge` が失敗してエラー処理が複雑化する。最初から選択肢に出さないことで「マージしたければ先にコミットしてくれ」という方針を UI で表明する。

### Decision 5: `--keep` 指定時は新ルートでも通常削除（再利用化しない）

**採用**: `wt-clean --keep` 指定中に新ルートを選択した場合、マージ後の worktree は **通常削除** する（Step 7a 経路）。完了レポートに「`--keep` 指定だが新ルートのため通常削除」と明示する。

**代替案と却下理由**:

- マージ後の worktree も再利用化する（`--keep` を尊重）: マージ後はブランチが削除されており、Step 7b の「main 切替＋元ブランチ削除」が「main 切替のみ」になり実質ノーオペ。再利用するメリットが薄い
- 新ルートと `--keep` を排他にする: ユーザーがコマンドを打ち直す手間が増える。フォールバックで動く方が UX が良い

**根拠**: `--keep` の本来の意図は「マージ済み 🟢 Safe な worktree を捨てずに main 切替で再利用」する。新ルートの 🔴 → マージ昇格はマージ自体は同等だが、再利用化の「ブランチ削除」段階で何も削除するものがない（既に削除済み）。意味のあるアクションが残らないため、通常削除にフォールバックする方が一貫する。

### Decision 6: `MERGED_BRANCHES` 配列でセッション内状態管理

**採用**: 新ルートで実際にマージ成功したブランチ名を `MERGED_BRANCHES=()` 配列に push 順で追記し、Step 6d のチェック対象判定と Step 8 完了レポートの両方で参照する。

**代替案と却下理由**:

- 一時ファイル（`/tmp/wt-clean-merged-$$`）: ファイル管理の責任とクリーンアップが増える
- `git branch --merged` の再実行: 新ルートマージ後は `git branch --merged` で取得できるが、「今回 wt-clean でマージしたもの」と「既にマージ済みのもの」を区別できない
- 配列なしで都度判定: Step 6d / Step 8 の双方で重複ロジックになる

**根拠**: bash の配列は標準機能で追加コストゼロ。push 順 = マージ順を保持するため、競合発生時の「FAIL したマージ以降を保留」既存仕様と自然に整合する。

### Decision 7: メインリポが MAIN_BRANCH 以外をチェックアウト中の場合は新ルート中断

**採用**: Step 5b 開始時に `git -C "$MAIN_REPO" branch --show-current` が `$MAIN_BRANCH` と一致するか検証。違う場合は新ルート全体を中断し、`cd $MAIN_REPO && git checkout $MAIN_BRANCH` してから再実行するよう案内する。

**代替案と却下理由**:

- 自動で `git checkout $MAIN_BRANCH` を実行: メインリポで作業中のユーザーが意図せず別ブランチに切り替わる。事故リスク
- スキップして 🔴 を未処理扱いに: 「マージ」を選んだのに何も起きないのは UX が悪い

**根拠**: メインリポが別ブランチをチェックアウト中というのはレアケース（通常は main を持っている）。自動切替は副作用が大きすぎるため、明示的に中断＋案内する方が安全。

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| `git merge` で main 履歴に意図しないコミットが積まれる | `--no-ff` 強制でマージコミットを明示。`-m` で「wt-clean active merge」を含むメッセージを付与し、後から `git log --grep` で検索可能 |
| 競合発生時に中断状態のまま放置されると次回実行に混乱 | エラーメッセージで「対応手順 1. cd <main-repo> 2. 競合解決 3. wt-clean 再実行」を明示。中断中の `git status` で `MERGE_HEAD` 存在が確認できる |
| 複数 🔴 を順次マージ中に競合 → 既マージ分が「中途半端」に残る | 「既マージ分も含め全保留」方針で統一。再実行時は「すでにマージ済み」のブランチが `git branch --merged` で 🟢 Safe 判定されるため自然に処理が継続する |
| Dirty 同時 🔴 でユーザーが「マージしたい」と思って 2 択しか出ないことに混乱 | 表示文言で「⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）」と理由を明示 |
| `--keep` でも通常削除になることに気付かない | 完了レポートに「`--keep` 指定だが新ルートのため通常削除」と理由併記 |
| 既存ルートの動作変更（リグレッション） | spec.md に既存ルート維持の Scenarios を含め、回帰防止条件を仕様で担保 |
| プラグインキャッシュにより新挙動が反映されない | `plugin.json` の version を minor bump（既存 wt-clean-remote-sync / wt-clean-reuse change と同じ手法） |
| commands 版 / skills 版が乖離する | 既存 wt-clean-keep-option / wt-clean-remote-sync change と同様、両ファイルを同じ commit で更新する |

## Migration Plan

1. `openspec/changes/wt-clean-merge-active/` 一式を作成し `openspec validate` PASS
2. `plugins/worktree/commands/wt-clean.md` を編集（Step 3 / 5a / 5b / 6d / 8）
3. `plugins/worktree/skills/wt-clean/SKILL.md` に同じ変更を同期、frontmatter `version` minor bump、`description` 更新
4. `plugin.json` / `marketplace.json` を minor bump
5. commit & push → `/reload-plugins` で反映確認
6. ユーザーがサンドボックス repo で S1〜S11 シナリオを実行して動作確認

ロールバック: Step 5a / 5b の記述を削除し、Step 3 選択肢を 4 択に戻し、Step 6d の `MERGED_BRANCHES` 参照を削除すれば従来挙動に戻る。

## Open Questions

なし。実装時に判断で良い論点:

- 完了レポートの表示文言の細部（「マージ→削除」「マージ成功・削除保留」等の最終表現）
- per-worktree 個別確認時の表示順序（推奨は `git worktree list` の順、すなわち作成順）
