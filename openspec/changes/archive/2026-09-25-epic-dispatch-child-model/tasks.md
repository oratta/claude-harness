## 1. テストを先に書く（Red）

- [x] 1.1 `plugins/dev-workflow/tests/epic-dispatch.bats` の orca スタブに `terminal create` を足し（`result.terminal.handle` を返す。子ごとに失敗・ハンドル無しを切り替えられる）、worktree create のスタブが `result.worktree.path` を返すようにする
- [x] 1.2 「launch は fetch してから path: で親を渡して子を作る」のテストを、worktree create に `--agent` が無いこと・`terminal create --worktree path:<子> --command "claude --model 'opus' --dangerously-skip-permissions" --json` が wait の前に呼ばれることを確かめる形に直す
- [x] 1.3 「agentTerminalHandle が無ければ startupTerminal のハンドルに送る」のテストを消し、「ハンドルが取れなければ送らずに failed」を terminal create の JSON にハンドルが無い形に直す
- [x] 1.4 新しいシナリオのテストを足す: `EPIC_DISPATCH_MODEL='opus[1m]'` で `--command` が変わる／`EPIC_DISPATCH_MODEL=` 空で create を呼ばず exit 1／terminal create 失敗で wait・send を呼ばず stderr に端末の作り直しと `/develop #11` の送信のコマンドを出して `failed`／worktree create の JSON にパスが無いと terminal create を呼ばず `failed`
- [x] 1.5 `bats plugins/dev-workflow/tests/epic-dispatch.bats` で新しいテストが落ちることを確かめる

## 2. 実装（Green）

- [x] 2.1 `plugins/dev-workflow/scripts/epic-dispatch.sh` の `cmd_launch` で `EPIC_DISPATCH_MODEL`（既定 `opus`、`${EPIC_DISPATCH_MODEL-opus}` で読み、空なら使い方を出して exit 1）を読み、worktree create から `--agent claude` を外し、`result.worktree.path` を取って `orca terminal create` で `claude --model <shq した model> --dangerously-skip-permissions` を起動し、`result.terminal.handle` を wait / send に使う。端末を作れなかった子はパスがあれば作り直しのコマンドを stderr に出して `failed`
- [x] 2.2 同ファイル先頭コメントの launch の説明を新しい呼び出し順と `EPIC_DISPATCH_MODEL` に合わせる
- [x] 2.3 `bats plugins/dev-workflow/tests/epic-dispatch.bats` が全件通ることを確かめる

## 3. 文書と記録

- [x] 3.1 `plugins/dev-workflow/skills/develop/SKILL.md` の Orca 経路に、子セッションのモデルの決め方（`launch` が `claude --model` で指定・既定 `opus`・`EPIC_DISPATCH_MODEL` で変更・Claude Code の既定モデルや Orca の agent 設定は子に効かない）を書き、`--dangerously-skip-permissions` は `epic-dispatch.sh` が付けると書き直す
- [x] 3.2 `plugins/dev-workflow/changes/475.md` に変更記録を書く（既存の changes/ の書式）
- [x] 3.3 `scripts/test.sh` を全件フォアグラウンドで流して通ることを確かめる

## 4. 実機確認

- [x] 4.1 使い捨ての子（またはエピックの実際の子）を `epic-dispatch.sh launch` で起動し、子セッションの transcript の `message.model` が指定したモデル（既定では Opus）であることを確かめる。Claude Code の既定モデルが Sonnet のときでも同じになることは、`EPIC_DISPATCH_MODEL` に既定と異なるモデルを渡して transcript で確かめることで代える（design.md の実機確認と同じ手順）。作ったワークツリーは確かめてから片付ける

実機確認の記録（2026-09-25）: `~/.claude/settings.json` の `model` が `opus[1m]` の環境で、既定と違うモデルを渡して確かめた（「既定モデルが Sonnet のときでも指定モデルで起動」の代替）。`epic-dispatch.sh` が組み立てるのと同じ呼び出し（`orca worktree create --json`（`--agent` なし）→ `result.worktree.path` に `orca terminal create --command "claude --model 'sonnet' --dangerously-skip-permissions" --json` → `result.terminal.handle` に `orca terminal wait --for tui-idle` → `orca terminal send --enter --wait-submit 30`）を使い捨てのワークツリー `w475-verify` で実行した。wait は満たされ、send の stages は `["input_accepted","turn_started"]`、子の transcript の `message.model` は `claude-sonnet-5` だった。`launch` 本体は親ワークツリーの linkedIssue を書き換えるため実機では流さず、呼び出しの引数と順序は `epic-dispatch.bats` で確かめた。確認後に端末を閉じ、`orca worktree rm` でワークツリーとブランチを消した。
