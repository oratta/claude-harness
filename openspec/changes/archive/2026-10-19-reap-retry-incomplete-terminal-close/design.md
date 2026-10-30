## 決めたこと

- 閉じ直しは 1 回まで。待ち時間は環境変数 `EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT`（秒、既定 10）。理由: 子がターンを終えて端末が閉じられるようになるまでは短時間と見込める一方、長く待つと親の reap が止まる。足りなければ主の操作に回す。値の根拠になる実測は無いので、テストでは 0 にして待たない。
- 原因の確認は `orca terminal list --worktree path:<子> --json` の出力を stderr に流すだけ（best-effort）。Orca の `terminal_close_incomplete` の細部に依存した分岐を作らない（失敗の種類を問わず同じ扱い）。
- 閉じ直し後も失敗なら rm は呼ばない（従来どおり）。`--force` も付けない。
- 主がする操作は stderr に出す。エピックへの 1 行は SKILL.md の手順 3 に従い親が投稿する（スクリプトは gh でコメントしない。既存の責務分担を保つ）。
