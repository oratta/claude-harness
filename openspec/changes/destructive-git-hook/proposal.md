## Why

`rules/destructive-git-guard.md` は実際の事故から生まれたルールだが、常時注入している文章だけで、Claude が読み飛ばしたときに止める仕組みが無い。`git reset --hard` や main への push のように取り返しのつかない git 操作は、文章の遵守に頼らず、実行の直前に hook で止めて主に確認を回す（公式 best practices の「補える部分は hook に変える」に沿う）。

## What Changes

- dev-workflow に PreToolUse（matcher: `Bash`）の command hook `scripts/git-destructive-guard.sh` を足す。Bash のコマンド文字列を分解し（`&&` / `;` / `|` の連結、`$()` とバッククォートの中、`bash -c` の引数を含む）、ルールの一覧に当たる git 操作を見つけたら `permissionDecision` に `ask` か `deny` と理由を返す。当たらなければ何も出さない
- `ask` と `deny` の使い分けは payload の `permission_mode` で決める。確認画面が出るモードでだけ `ask`、それ以外（bypassPermissions など）は `deny`。bypassPermissions で `ask` が確認画面を出すかは実装の最初に実機で確かめ、結果で bypassPermissions の扱いを確定する（判定条件は design.md）
- `DEV_WORKFLOW_GIT_GUARD=off` で hook 全体を止められるようにする（既存の `DEV_WORKFLOW_MODEL_GUARD=off` と同じ形の逃げ道）
- `rules/destructive-git-guard.md` に「一覧の操作は hook が実行前に止める（拒否されたら承認後も主が実行する）」ことと「hook が見るのはコマンド文字列だけなので、スクリプト経由・push 済みの `--amend`・`rebase -i`・ブランチ名を書かない `git push` は止まらない」ことを足す。既存の文は外さない。issue 概要 3 の「hook で拾えない項目だけに縮める」は、縮約を削除ではなく移設とする既存要件（`always-on-injection-scope`）と hook の穴（文字列しか見ない）のため採らない（理由は design.md）
- `plugins/worktree/skills/wt-clean/SKILL.md` に、`git branch -D` が hook に拒否されたときの扱い（保留にして完了レポートに主が打つコマンドを載せる）と、無人運用のジョブの環境に `DEV_WORKFLOW_GIT_GUARD=off` を入れることを足す。何もしないと、主の `cld` セッションと cron（どちらも bypassPermissions）で squash 済みブランチの削除が毎回拒否される
- 予算ファイル `tests/injection-budget.txt` を実測に合わせて上げる（増分と理由を PR 本文に書く）

## Capabilities

### New Capabilities

- `destructive-git-hook`: 破壊的 git 操作を Bash の実行前に検出して `ask` / `deny` を返す PreToolUse hook の判定対象・守備範囲・出力・モード別の振る舞い・逃げ道、ルール本文との分担、wt-clean のブランチ削除が拒否されたときの扱い

### Modified Capabilities

（なし。`always-on-injection-scope` の「destructive-git-guard.md を常時注入に残し、操作の一覧と目印を本文に残す」要件はそのまま満たす。要件の変更は無い）

## Impact

- `plugins/dev-workflow/hooks/hooks.json`（PreToolUse に 1 件追加。聖域）
- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（新規）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`（新規）
- `rules/destructive-git-guard.md`（聖域）、`rules/README.md` の該当行
- `tests/injection-budget.txt`（聖域。値を動かす理由を PR 本文に書く）
- `plugins/worktree/skills/wt-clean/SKILL.md`（案内 2 か所）、`plugins/worktree/tests/skill-safety.bats`（文面の検査を足す）
- `plugins/dev-workflow/changes/710.md`、`plugins/worktree/changes/710.md`（変更の記録）
- 範囲外: #629（auto-merge テンプレの deny）、#364（同じ破壊的コマンド一覧。epic #360 保留中）、`scripts/test-auto-merge-workflow.sh` の聖域一覧
- 影響: dev-workflow を有効にした全プロジェクトの Bash 呼び出しで python3 が 1 回起動する（payload に `git` の文字列を含むときだけ。payload に `git` の文字列が無ければシェルだけで抜ける）
