## Why

`git-destructive-guard.sh` は、対話セッションならサブエージェント（子）から呼ばれたときも `ask` を返して主の確認画面を出す。親は子の確認画面に応答できず、子が止まっていることも分からないので、主が画面を見て押すまでワークフロー全体が止まる（issue #1108。reviewer が scratchpad に作った検証用 clone を `git -C $S/h checkout -- plugins/x/a.sh` で戻そうとして止まった）。子は確認画面で待たせず、その場で拒否して親に返すほうがよい。

## What Changes

- payload に空でない文字列の `agent_id` がある呼び出し（子から呼ばれたもの）には、`permission_mode` にも上書きの環境変数 `DEV_WORKFLOW_GIT_GUARD_FORCE` にもよらず `deny` を返す。`agent_id` が無い呼び出しの振る舞いは変えない
- 子に返す拒否理由を、子向けの文面にする（実行されない／打ち直さず別の書き方も試さない／scratchpad の検証用 repo なら git で戻さず作り直す／それ以外は作業を止め、何を・なぜ実行したかったかを報告に書いて親に返す）
- 同じ子が拒否を繰り返さないよう、`agent_id` ごとに拒否した回数を一時ディレクトリのファイルに数える。2 回目以降の拒否では「直ちに作業を終えて親に返す」を理由文に足し、`continue: false` を返して子を打ち切る。子の中で `continue: false` を返すと親まで止まると実機で分かった場合（または確かめられなかった場合）は、`continue: false` を返さず強い理由文だけにする
- reviewer / worker / gate-runner のエージェント定義に「scratchpad の検証用 repo は git の破壊的操作で戻さず、作り直す」を足す
- `rules/destructive-git-guard.md` の「hook との分担」節と `rules/README.md` の該当行に、子から呼ばれたときは確認画面を出さずに拒否され、子は親に返ることを足す
- 採らない案: 「scratchpad 内の repo なら許可する」。コマンドの中で `S=...` と変数を作ってから使う形が普通にあり、hook は変数を展開できないので行き先を判定できない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: 「確認画面が出るモードでだけ ask を返す」（子は常に deny）、「拒否理由は承認の取り方を案内する」（子向けの理由文）、「ルール本文と hook の分担」（子の扱いを足す）を変え、「同じ子への拒否の繰り返しを打ち切る」と「子の定義に検証用 repo の戻し方を書く」を足す

## Impact

- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（decision の決定部と理由文、回数のファイル）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`
- `plugins/dev-workflow/agents/reviewer.md` / `worker.md` / `gate-runner.md`
- `rules/destructive-git-guard.md`・`rules/README.md`（常時注入の量が増えるので `tests/injection-budget.bats` を通す。予算ファイルの値を動かす場合は PR 本文に理由を書く）
- hooks と rules は聖域なので、マージには主の承認が要る
