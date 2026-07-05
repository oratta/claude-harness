# wt-clean 自己検証の詳細手順

`wt-clean` スキルの `## 自己検証` 節から参照される検証詳細。共通原則は `plugins/loops/references/self-verification.md`。

wt-clean は worktree を診断（🟢🟡🔴）して 1 個ずつ処理する破壊的操作を含むため、完了宣言の前に「削除・退避が意図どおりに行われた evidence」を必ず確認する。

## 診断・処理後に確認する evidence

- **削除された worktree が登録から消えている**: `git worktree list` の出力に、削除対象として選んだパスが現れないことを確認する。
- **🟡（未コミット変更あり）の LLM 退避が完了している**: 退避を選んだ worktree について、退避先ファイル（LLM 退避物）が実在し空でないことを確認してから worktree を削除したことを確認する。silent な破棄をしていないこと。
- **🔴（未マージ）の選択が evidence と一致している**: マージ / スキップ / 破棄のいずれを選んだかと、その結果（マージ commit の有無・ブランチの残存）が一致することを確認する。
- **孤児の整理**: パスが既に存在しない worktree は `git worktree prune` で整理し、`git worktree list` がクリーンになったことを確認する。
- **Step 0 の同期**: `origin/<main>` の同期を行った場合、`--no-sync` でない限り同期が成功した exit code を確認する。

## PASS 条件

上記の各確認が期待どおり（対象パスが消えている / 退避物が実在する / 選択と結果が一致する）であることを evidence として提示できたときのみ、クリーンアップ完了を宣言する。
