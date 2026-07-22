## Why

`wt-clean` は `git worktree remove --force` で worktree ディレクトリ・ソース・`node_modules` を削除するが、その worktree 配下で稼働中の dev サーバー等のプロセス（`next dev` / `npm run dev` 等）を止めるステップが存在しない。実際に Uranai(suimei) プロジェクトで、`wt-clean` により片付けた worktree 配下の `next dev`（Turbopack）プロセスツリーが worktree 削除後も2日以上残り続け、参照先ソースが消えた状態で再ビルドを試行し続けるループに陥り、CPU使用率165〜210%が2日間継続、システム全体のswapが98%に達するインシデントに発展した（[issue #39](https://github.com/oratta/claude-harness/issues/39)）。

## What Changes

- `git worktree remove` を呼ぶ全ての分岐（Step B-🟢 自動削除、Step B-🟡 LLM退避後削除、Pass 2 の🔴破棄削除・dirty破棄・マージ後削除）の**直前**に、削除対象 worktree のパス配下で稼働中のプロセスを検出し停止するステップを追加する。
- 検出は `lsof +D "$WT"` で対象パス配下にオープンファイル/cwdを持つプロセスを列挙する（`.claude/rules/dev-server.md` にある「cwdが対象パス配下かどうか」判定の考え方を踏襲）。
- 検出したプロセスへ SIGTERM を送り、数秒待って生存確認し、まだ生きていれば SIGKILL にフォールバックする。
- 停止した PID・コマンド名をログに明示する（無音実行にしない。診断根拠表示と同じ思想）。プロセスが見つからなかった場合もその旨を1行表示する。
- `wt-clean-verification.md` の自己検証チェックリストに「削除対象 worktree 配下のプロセス残留なし」の項目を追加する。
- 誤って**メインリポや他 worktree** のプロセスを止めないよう、検出範囲を実削除対象パス配下に厳密に限定する（`dev-server.md` の「他プロジェクトのプロセスをkillしない」原則と同じ判別ロジック）。

## Capabilities

### New Capabilities
- `wt-clean-devserver-cleanup`: `git worktree remove` 実行前に、削除対象 worktree 配下で稼働中のプロセスを検出し SIGTERM→SIGKILL フォールバックで停止し、結果をログ表示する振る舞い。誤って対象パス外のプロセスを止めないスコープ限定を含む。

### Modified Capabilities
（既存 capability の要件変更なし。新規ステップの追加のみで、既存の診断分類・対話フローの要件は変わらない）

## Impact

- `plugins/worktree/skills/wt-clean/SKILL.md`: Step B-🟢 / Step B-🟡 / Pass 2 の各削除ブロックにプロセス停止ステップを追加。
- `plugins/worktree/references/wt-clean-verification.md`: 自己検証項目を追加。
- `plugins/worktree/tests/`: 新しい bats テストを追加（検出・停止ロジックのドキュメント記載を検証）。
- 実行時の外部コマンド依存が増える: `lsof`（macOS/Linux 標準搭載）。
