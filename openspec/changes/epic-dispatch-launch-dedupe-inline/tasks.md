## 1. テスト（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/epic-dispatch.bats` に、一覧に既存ワークツリーが無い状態で `launch 420 11 11` を実行し `orca worktree create` が子 11 について 1 回だけ呼ばれ stdout に `launched 11` と `skipped 11` が出ることを確かめるテストを足す
- [ ] 1.2 同ファイルに、一覧チェックによる `skipped`（既存ワークツリーあり）と同じ呼び出し内の重複による `skipped` が同じ呼び出し `launch 420 11 12 11` で共存し、`orca worktree create` が子 11 について 1 回・子 12 について 0 回呼ばれることを確かめるテストを足す

## 2. 実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/epic-dispatch.sh` の `cmd_launch` の `local n prompt failed=0` を `local n prompt failed=0 seen=" "` にする
- [ ] 2.2 `for n in "$@"; do` の直後に `case "$seen" in *" $n "*) echo "skipped $n"; continue ;; esac; seen="$seen$n "` を足す
- [ ] 2.3 `plugins/dev-workflow/tests/epic-dispatch.bats` を実行し、1.1 と 1.2 のテストおよび既存テストが通ることを確認する

## 3. 記録・仕上げ

- [ ] 3.1 `plugins/dev-workflow/changes/434.md` に変更記録を書く（版は上げない）
- [ ] 3.2 `openspec validate epic-dispatch-launch-dedupe-inline --strict` を実行し通ることを確認する
