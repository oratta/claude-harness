## Why

現状の `wt-clean` は「全 worktree を先に診断（🟢🟡🔴）→ 全体に対して一括モードを 1 問で選択 → カテゴリ一律で処理」という流れで、(1) 特定の worktree だけを狙い撃ちで片付ける手段がなく、(2) worktree が多いと全件診断のコストと一括選択の粗さが負担になる。対象を「選んでから」1 個ずつ対話的に処理する方が直感的で、パス／ブランチ名での狙い撃ちもしたい。

## What Changes

- **パス／ブランチ名引数によるスコープ前倒し**: `wt-clean <path>` / `wt-clean <branch>` で対象を絞り、他の worktree を完全に無視する。複数指定可（`wt-clean <p1> <p2>`）。パスは realpath で正規化して `git worktree list` の絶対パスと照合、ブランチ名は list から逆引き。0 件／複数件ヒット時はエラーで候補を提示する。
- **遅延診断（lazy diagnosis）**: 引数なし時、最初は 🟢🟡🔴 の分類をせず worktree を「リストアップするだけ」にする。リストにはブランチ名と最終コミット日（git 軽量コマンドで即取れる情報）のみ表示し、merged 判定（色）は出さない。
- **対象選択 UI**: 引数なし時は「どの worktree に wt-clean を適用するか」を `AskUserQuestion` の multiSelect +「全て」で選ばせる。この段階では一切処理しない。
- **1 個ずつの対話処理**: 選択された対象（TARGETS）を `i/N` の進捗表示付きで 1 件ずつ遅延診断し、診断結果のカテゴリに応じた対話（🟢→削除/再利用、🟡→LLM 退避→削除、🔴→マージ/スキップ/破棄）を行う。
- **統合モデル**: パス指定 = 「選択ステップの前倒し」。引数あり／なしのどちらも「TARGETS を確定 → 1 個ずつ遅延診断＆対話」という共通後段に合流する。
- **BREAKING**: 既存 Step 3 の一括モード選択（「🟢🟡を処理する」「🟢のみ処理する」「全て処理する」等の 4 択／5 択）を**廃止**し、選択ベースフローに統一する。「全部まとめて」は「選択 UI で『全て』を選ぶ」で代替する。
- **🔴 マージの統合**: 🔴 Active のマージ確認（マージ/スキップ/破棄、Dirty・detached 時の選択肢除外）は、独立した「新ルート」ではなく per-target 処理ループの中で 🔴 と診断された時に行う。
- **サニティチェックを都度実行**: マージが発生した直後にそのマージ分のテスト/ビルドを実行する（従来の「全マージ後にバッチ 1 回」から変更）。失敗したマージが即座に特定できる。
- `--keep` / `--no-sync` は維持。`--no-sync` はパス指定時も Step 0 の同期を停止できる。

## Capabilities

### New Capabilities

- `wt-clean-target-selection`: wt-clean の対象選択と遅延診断・逐次処理フロー。パス／ブランチ名引数によるスコープ前倒し、引数なし時の遅延診断リストアップ＋ multiSelect 選択（「全て」含む）、選択対象を `i/N` 進捗で 1 個ずつ診断→カテゴリ別対話処理する共通パイプラインを定義する。

### Modified Capabilities

- `wt-clean-merge-active`: 🔴 Active のマージ確認を「Step 3 の一括選択肢として先頭に提示する独立ルート」から「per-target 逐次処理ループ内で 🔴 と診断された時に行う対話」へ移す。Step 3 の一括 4 択／5 択提示要件は REMOVED。per-🔴 の選択肢内容（マージ/スキップ/破棄、Dirty・detached 時の除外、競合ハンドリング）と `git merge --no-ff` 実行要件は維持。サニティチェックはマージ都度実行に変更。
- `wt-clean-reuse`: `--keep` の振る舞いを新フロー（選択→逐次処理）の上に移す。「オプション未指定時は従来動作」の「従来動作」が選択ベースフローに変わるため、🟢 Safe を逐次処理ループ内で再利用化する形に要件を更新。再利用化対象が 🟢 Safe 限定である点は維持。
- `wt-clean-remote-sync`: 遅延診断化に伴い「Step 1 の診断より前に fetch」という文言を「対象選択／逐次診断より前に fetch」へ調整。fetch する・`--no-sync` でスキップという本質的振る舞いは維持。パス指定時も同期が走る点を明記。

## Impact

- **コード/スキル**: `plugins/worktree/skills/wt-clean/SKILL.md` と `plugins/worktree/commands/wt-clean.md`（本文が既に乖離している 2 ファイルの二重管理。本変更でどちらに刷新フローを入れるか／統合するかを design.md で決定）。
- **spec**: 既存 `wt-clean-merge-active` / `wt-clean-reuse` / `wt-clean-remote-sync` の delta、新規 `wt-clean-target-selection`。
- **ユーザー体験**: 一括モード廃止は BREAKING。「サクッと全部削除」の操作感が「選択 UI で『全て』を選ぶ」に変わる。
- **実装制約**: `AskUserQuestion` は 1 問あたり選択肢最大 4 つ・1 回最大 4 問。worktree が多い場合の選択 UI 分割戦略を design.md で決める必要がある。
- **plugin.json**: バージョン更新が必要（marketplace 配布のため）。
