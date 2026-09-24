## 1. テスト（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/epic-dispatch.bats` の `orca` スタブに `worktree create` の JSON 出力（ハンドルの有無を切り替えられる）、`terminal wait`（exit を切り替えられる）、`terminal send`（exit と `stages` を切り替えられる）を足し、呼び出しの記録に残す
- [ ] 1.2 既存シナリオ「launch は fetch してから path: で親を渡して子を作る」を、create に `--prompt` が無く、子ごとに create → `terminal wait --for tui-idle` → `terminal send --text "/develop #<N> ..." --enter --wait-submit 30 --json` の順になる形に書き換える
- [ ] 1.3 delta spec の追加シナリオ（startupTerminal へのフォールバック、ハンドル無しで failed、送信失敗で failed と送り直しコマンド、`turn_started` 無しで failed、起動完了待ちの失敗で failed、環境変数で時間を変える）を bats に足し、今の実装で落ちることを確かめる

## 2. 実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/epic-dispatch.sh` の `cmd_launch` で create から `--prompt` を外し、JSON 出力を stderr に流しつつ変数に取り、ハンドルを取り出す
- [ ] 2.2 `orca terminal wait` → `orca terminal send` を呼び、`stages` に `turn_started` があるときだけ `launched`、それ以外は `failed` と送り直しコマンドを stderr に出す。`EPIC_DISPATCH_READY_TIMEOUT_MS`（既定 60000）と `EPIC_DISPATCH_SUBMIT_WAIT`（既定 30）を読む
- [ ] 2.3 `bats plugins/dev-workflow/tests/epic-dispatch.bats` が全件通る

## 3. 文書と記録

- [ ] 3.1 `plugins/dev-workflow/skills/develop/SKILL.md` の Orca 経路の `launch` の説明で、`launched` が「最初の指示を送りターンの開始まで確かめた」こと、`failed` のときは stderr の送り直しコマンドをユーザーに示すことを最小限書き足す（関係ない箇所は触らない）
- [ ] 3.2 SKILL.md の検査 bats（`develop-skill.bats` など）が通ることを確かめる
- [ ] 3.3 `plugins/dev-workflow/changes/458.md` に変更の記録を書く（版は上げない）

## 4. 検証

- [ ] 4.1 `scripts/test.sh` を全件流し、exit code を記録する
- [ ] 4.2 実機: Orca 管理のワークツリーから、本体と決めたダミーの子 2 件以上で `launch` し、`orca terminal read` で両方の子の入力欄に `/develop #<子>` が入り作業が始まっていること、指示が 2 回届いていないことを確かめる。あわせて `orca terminal send --json` の実際の出力の形を記録し、スタブと食い違えば bats を直す
- [ ] 4.3 `openspec validate epic-launch-send-prompt --strict` が通る
