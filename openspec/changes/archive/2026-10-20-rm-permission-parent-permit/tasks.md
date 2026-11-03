## 1. 判定

- [x] 1.1 `git-guard-scratchpad.py` に rm 用の `check_rm(session_id, cwd, command)` を足す（グロブ・cd の両基準・scratchpad そのものの除外）。`触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py:330-380（check の下に追加。ファイル先頭のコメントにも rm の判定を書く 1-15）`
- [x] 1.2 `git-guard-scratchpad.py` に、コマンドが rm か判定して `check` / `check_rm` に振る `check_command` を足す。`触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py:330-380`
- [x] 1.3 `git-guard-permit.sh` の `C["check"]` の呼び出しを `check_command` に変える。`触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh:70-74`

## 2. hook

- [x] 2.1 `rm-permission-guard.sh` を作る（子かつ rm のコマンドにだけ答える。許可の取得・使う時点の再判定・permit-log・拒否の記録・allow/deny の JSON。記録を作れなかったときは message にパスを書かず「作れなかった」旨とコマンド全文の案内を書く）。`触る範囲: plugins/dev-workflow/scripts/rm-permission-guard.sh（新規。許可の使い方は git-destructive-guard.sh:805-900 を参照）`
- [x] 2.2 `hooks.json` に `PermissionRequest`（matcher Bash）を足す。`触る範囲: plugins/dev-workflow/hooks/hooks.json:58-68（PostToolUse の前）`

## 3. テストと確認

- [x] 3.1 `tests/rm-permission-guard.bats` を作る（spec の各 Scenario。判定ファイル欠如と記録を書けない場合の message も見る。`git-destructive-guard.bats` の scratchpad 用意のヘルパを参照）。`触る範囲: plugins/dev-workflow/tests/rm-permission-guard.bats（新規）`
- [x] 3.2 `tests/injection-budget` などの既存 bats が通ることを確かめ、`hook-python-invocation.bats` に新しい hook を足す必要があるか確認する。`触る範囲: plugins/dev-workflow/tests/hook-python-invocation.bats`
- [x] 3.3 実機確認（`claude -p --plugin-dir <worktree>`）の結果を PR に記録する
- [x] 3.4 `plugins/dev-workflow/changes/1134.md` を書く。`触る範囲: plugins/dev-workflow/changes/1134.md（新規）`
