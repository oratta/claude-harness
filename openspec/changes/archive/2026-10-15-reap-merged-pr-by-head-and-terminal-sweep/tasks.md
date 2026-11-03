## 1. reap の実装

- [x] 1.1 `cmd_reap` のマージ済み PR の照合を 2 段にする（`--head` で一致が無いとき `--search <HEAD>`。HEAD の取得を照合の前に移す）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:447-453（`cmd_reap` の照合）
- [x] 1.2 `orca worktree rm` の stderr を取り、`terminal sweep failed` を含むなら `kept <N> rm-failed-terminal-sweep`、他の失敗は `rm-failed`。`--force`・再試行なし、stderr は親に流す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:455-456
- [x] 1.3 ヘッダーコメントの reap の段落に 2 点を反映する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:61-66

## 2. テスト

- [x] 2.1 gh のスタブを `--head` と `--search` で出力を分ける（`pr_out` と `pr_search_out`、終了コードは `pr_exit` と `pr_search_exit`）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:149-159（gh スタブ）、:234-240（reap_ready）
- [x] 2.2 reap のテストを足す: 別名ブランチの PR の先端が HEAD と一致すれば reaped／空なら no-merged-pr／別の先端なら head-mismatch／検索の失敗は pr-lookup-failed／terminal sweep failed は rm-failed-terminal-sweep／それ以外の rm 失敗は rm-failed／rm は 1 回で `--force` なし。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1302-1320、:1378-1386

## 3. 確認

- [x] 3.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats` と `openspec validate reap-merged-pr-by-head-and-terminal-sweep --type change --strict` を通す
