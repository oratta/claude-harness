## Why

エピックの親が `epic-dispatch.sh reap` で子のワークツリーを片付けるとき、次の 2 つで片付けが止まり、手作業が残る（#1037、エピック #1038）。

- 子が別名のブランチの PR（squash マージ）で main に入ると、`gh pr list --head <子のブランチ>` に出ず `kept <N> no-merged-pr` になる（flatmate #1480・#1481）
- Orca が端末の片付けを確かめられず `orca worktree rm` が `terminal sweep failed` で落ちると、他の失敗と同じ `kept <N> rm-failed` になり、親がエピックに書く案内を変えられない

## What Changes

- `reap` のマージ済み PR の照合を、`--head <ブランチ>` で一致しないとき、`--state merged --search <HEAD>` でブランチ名を問わず探すように広げる。一致は `headRefOid == HEAD` の完全一致のまま
- `orca worktree rm` が失敗し stderr に `terminal sweep failed` を含むときは `kept <N> rm-failed-terminal-sweep` を返す。`--force` は付けず、再試行しない

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh` の `cmd_reap` とヘッダーコメントの reap の段落
- `plugins/dev-workflow/tests/epic-dispatch.bats` の reap のテスト
- 仕様: `dev-workflow-develop`「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」
- 範囲外: launch / wait / mark / route、develop の SKILL.md（`kept <N> <理由>` はエピックにそのまま書く既存の手順で足りる）、印のない子を片付けること
