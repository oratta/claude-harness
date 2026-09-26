## 1. テスト（Red）

- [x] 1.1 `plugins/dev-workflow/tests/epic-dispatch.bats` に、一覧に既存ワークツリーが無い状態で `launch 420 11 11` を実行し `orca worktree create` が子 11 について 1 回だけ呼ばれ stdout に `launched 11` と `skipped 11` が出ることを確かめるテストを足す
- [x] 1.2 同ファイルに、一覧チェックによる `skipped`（既存ワークツリーあり）と同じ呼び出し内の重複による `skipped` が同じ呼び出し `launch 420 11 12 11` で共存し、`orca worktree create` が子 11 について 1 回・子 12 について 0 回呼ばれることを確かめるテストを足す
- [x] 1.3 同ファイルに、`orca worktree create` が子 11 について失敗する環境で `launch 420 11 11` を実行し、stdout が `failed 11` と `skipped 11` の2行、`orca worktree create` が子 11 について 1 回だけ呼ばれ、exit code が 1 になることを確かめるテストを足す

## 2. 実装（Green）

- [x] 2.1 `plugins/dev-workflow/scripts/epic-dispatch.sh` の `cmd_launch` の `local n prompt failed=0` を `local n prompt failed=0 seen=" "` にする
- [x] 2.2 `for n in "$@"; do` の直後に `case "$seen" in *" $n "*) echo "skipped $n"; continue ;; esac; seen="$seen$n "` を足す
- [x] 2.3 `plugins/dev-workflow/tests/epic-dispatch.bats` を実行し、1.1・1.2・1.3 のテストおよび既存テストが通ることを確認する

## 3. 記録・仕上げ

- [x] 3.1 `plugins/dev-workflow/changes/434.md` に変更記録を書く（版は上げない）
- [x] 3.2 `openspec validate epic-dispatch-launch-dedupe-inline --strict` を実行し通ることを確認する
