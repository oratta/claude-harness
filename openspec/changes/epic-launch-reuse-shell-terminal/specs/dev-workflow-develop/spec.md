## ADDED Requirements

### Requirement: launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子ごとに `orca worktree create` が終わったあと、`orca terminal list --worktree path:<子> --json` で端末を数えなければならない（MUST。Orca は worktree create で空のシェルの端末を 1 つ作り、`orca terminal create` で 2 つ目を作ると子の端末が 2 つになって、`reply` が `ambiguous-terminal` で止まるため）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の launch の呼び出し順のうち、`orca terminal create` の段だけを次のとおり置き換える。それ以外の規定（起動コマンドの形・環境変数・`terminal wait`・`terminal send`・`launched`/`failed` の判定）は変えない。

- 端末がちょうど 1 つなら、`orca terminal create` を呼ばず、その端末のハンドルに `orca terminal send --terminal <handle> --text <cmd> --enter --json` で起動コマンド `<cmd>`（従来 `--command` に渡していた文字列と同じ）を打ち込む（MUST）。続けて `orca terminal list --worktree path:<子> --json` を引き直し、その端末が Claude Code（`agentIdentity` が `claude`、無ければタイトルに `Claude Code` を含む）になるのを待つ（MUST。シェルは起動コマンドを打つ前から idle で、すぐ `terminal wait` を呼ぶと最初の指示がシェルに入るため）。待つ上限は `EPIC_DISPATCH_READY_TIMEOUT_MS` を秒にした値（最低 1 回）とする。Claude Code になったら、その端末のハンドルで `terminal wait --for tui-idle` と指示の `terminal send` へ進む（MUST）
- 端末が 0 個なら、従来どおり `orca terminal create` で作る（MUST。worktree create が端末を作らない版の後方互換）
- 一覧を読めない・端末が 2 個以上・起動コマンドを打ち込めない・待っても Claude Code にならない、のいずれかなら、その子を `failed <N>` とし、`orca terminal create` を呼ばない（MUST。端末を増やすと二重起動の原因になるため）。stderr に理由と、確認または続きを手で行うコマンド（`orca terminal list --worktree path:<子> --json`、`orca terminal read --terminal <handle>`、打ち込めなかった起動コマンド）を出す（SHALL）

#### Scenario: worktree create が作ったシェルの端末で子のセッションが起動し、端末は 1 つのまま
- **WHEN** 子 11 のワークツリーに空のシェルの端末（`term-11`、`agentIdentity` なし）が 1 つあり、起動コマンドが届いたあとは同じ端末が `agentIdentity: claude` になるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` は呼ばれず、`orca terminal send --terminal term-11` が 2 回（1 回目は `EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'` を含む `--enter --json`、2 回目は `/develop #11` を含む指示）、`orca terminal wait --terminal term-11 --for tui-idle` が 1 回呼ばれ、stdout は `launched 11`、exit 0

#### Scenario: 端末が 0 個なら従来どおり terminal create で作る
- **WHEN** 子 11 のワークツリーの端末が 0 個のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create --worktree path:<子 11> --command ... --json` が呼ばれ、stdout は `launched 11`、exit 0

#### Scenario: シェルの端末が Claude Code にならなければ端末を作らずに failed
- **WHEN** 起動コマンドを打ち込んだあとも端末が Claude Code にならないスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` も `orca terminal wait` も呼ばれず、stderr に `did not become Claude Code` を含む行が出て、stdout は `failed 11`、exit 1

#### Scenario: 端末が 2 個以上・一覧が読めないときは端末を作らずに failed
- **WHEN** 子 11 のワークツリーの端末が 2 個ある、または `orca terminal list` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` は呼ばれず、stdout は `failed 11`、exit 1
