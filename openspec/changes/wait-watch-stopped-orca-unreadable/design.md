## Context

`epic-dispatch.sh wait` は `--watch-done` か、子 1 件以上を伴う `--watch-stopped` を付けると `orca worktree current` を呼び、失敗すると stderr に理由を出して stdout 空・exit 1 で終わる（`launch` の exit 1 と同じ型）。

## Decisions

- 文言を広げるだけで、スクリプトの挙動は変えない。理由: 挙動は既に 2 つの付け方で同じで、手順書だけが片方しか書いていない。
- 報告の中身は「親ワークツリーで開き直す」のまま。別の対処を作る理由が無い。

## Risks / Trade-offs

なし。文言のみの変更。

## Test

手順 6 の文言は bats の検査で守る。既存の検査は `--watch-done` を含む行だけを見るため、`--watch-stopped` を落としても通る。`stdout に何も出さず exit 1` を含む行に、`--watch-done` と `--watch-stopped` の両方と「親ワークツリーで開き直す」があることを確かめる検査を、同じテストの末尾に足す。
