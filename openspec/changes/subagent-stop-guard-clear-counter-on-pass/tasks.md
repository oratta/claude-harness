## 1. テスト（先に書く）

- [ ] 1.1 `plugins/dev-workflow/tests/subagent-stop-guard.bats` に、先に 1 回拒否させてから正しく待って（未完了背景タスク無しで）停止を通す場合にカウンタファイルが削除されていることを確認するケースを追加する
- [ ] 1.2 追加したケースが現行実装（削除処理を追加する前）で失敗することを確認する（Red）

## 2. 実装

- [ ] 2.1 `plugins/dev-workflow/scripts/subagent-stop-guard.sh` の `counter_dir` / `counter` の算出を `running = {...}` の直前に移す
- [ ] 2.2 `running` が空で通す分岐（`sys.exit(0)` の前）にカウンタファイル削除（`try: os.remove(counter)` / `except OSError: pass`）を追加する
- [ ] 2.3 `pending` が空で通す分岐（`sys.exit(0)` の前）に同様のカウンタファイル削除を追加する
- [ ] 2.4 上限到達で通す分岐の既存の削除処理はそのまま残す（書き換えない）
- [ ] 2.5 `scripts/test.sh subagent-stop-guard` を実行し、1.1 で追加したケースを含め全件 Green にする

## 3. 仕様・記録の同期

- [ ] 3.1 `openspec/specs/dev-workflow-subagent-waiting/spec.md` の要件「停止の拒否は上限回数までの後詰めにする」の記述を、本 change の delta 仕様どおりに直す（sync 時に反映されることを確認する）
- [ ] 3.2 `openspec/changes/archive/2026-09-27-subagent-wait-stop-guard/specs/dev-workflow-subagent-waiting/spec.md` の同じ記述を揃える
- [ ] 3.3 `plugins/dev-workflow/changes/264.md` の同趣旨の記述を揃える

## 4. 検証

- [ ] 4.1 `openspec validate subagent-stop-guard-clear-counter-on-pass --strict` を実行し exit 0 を確認する
- [ ] 4.2 受け入れ条件（issue #561）の 3 点（カウンタ削除・spec/テスト更新・`scripts/test.sh subagent-stop-guard` の exit 0）を満たしていることを確認する
