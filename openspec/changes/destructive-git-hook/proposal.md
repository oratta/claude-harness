## Why

`rules/destructive-git-guard.md` は実際の事故から生まれたルールだが、常時注入している文章だけで、Claude が読み飛ばしたときに止める仕組みが無い。`git reset --hard` や main への push のように取り返しのつかない git 操作は、文章の遵守に頼らず、実行の直前に hook で止めて主に確認を回す（公式 best practices の「補える部分は hook に変える」に沿う）。

## What Changes

- dev-workflow に PreToolUse（matcher: `Bash`）の command hook `scripts/git-destructive-guard.sh` を足す。Bash のコマンド文字列を分解し（`&&` / `;` / `|` の連結、`$()` とバッククォートの中、`bash -c` の引数を含む）、ルールの一覧に当たる git 操作を見つけたら `permissionDecision` に `ask` か `deny` と理由を返す。当たらなければ何も出さない
- `ask` と `deny` の使い分けは payload の `permission_mode` で決める。確認画面が出るモードでだけ `ask`、それ以外（bypassPermissions など）は `deny`。bypassPermissions で `ask` が確認画面を出すかは実装の最初に実機で確かめ、結果で bypassPermissions の扱いを確定する（判定条件は design.md）
- `DEV_WORKFLOW_GIT_GUARD=off` で hook 全体を止められるようにする（既存の `DEV_WORKFLOW_MODEL_GUARD=off` と同じ形の逃げ道）
- `rules/destructive-git-guard.md` に「一覧の操作は hook が実行前に止める」ことと「hook が見るのはコマンド文字列だけなので、スクリプト経由・push 済みの `--amend`・`rebase -i`・ブランチ名を書かない `git push` は止まらない」ことを足し、一覧は短い形で残す。issue 概要 3 の「hook で拾えない項目だけに縮める」は、一覧を本文に残すことを求める既存要件（`always-on-injection-scope`）と hook の穴（文字列しか見ない）のため採らない（理由は design.md）
- 予算ファイル `tests/injection-budget.txt` を実測に合わせて動かす（上下どちらに動いても PR 本文に理由を書く）

## Capabilities

### New Capabilities

- `destructive-git-hook`: 破壊的 git 操作を Bash の実行前に検出して `ask` / `deny` を返す PreToolUse hook の判定対象・出力・モード別の振る舞い・逃げ道、およびルール本文との分担

### Modified Capabilities

（なし。`always-on-injection-scope` の「destructive-git-guard.md を常時注入に残し、操作の一覧と目印を本文に残す」要件はそのまま満たす。要件の変更は無い）

## Impact

- `plugins/dev-workflow/hooks/hooks.json`（PreToolUse に 1 件追加。聖域）
- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（新規）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`（新規）
- `rules/destructive-git-guard.md`（聖域）、`rules/README.md` の該当行
- `tests/injection-budget.txt`（聖域。値を動かす理由を PR 本文に書く）
- `plugins/dev-workflow/changes/710.md`（変更の記録）
- 範囲外: #629（auto-merge テンプレの deny）、#364（同じ破壊的コマンド一覧。epic #360 保留中）、`scripts/test-auto-merge-workflow.sh` の聖域一覧
- 影響: dev-workflow を有効にした全プロジェクトの Bash 呼び出しで python3 が 1 回起動する（コマンドに `git` の文字列を含むときだけ。含まなければシェルだけで抜ける）
