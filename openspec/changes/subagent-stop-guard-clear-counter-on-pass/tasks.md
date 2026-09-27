## 1. テスト（先に書く。R1 の SHOULD_FIX 1 件目）

- [x] 1.1 `plugins/dev-workflow/tests/subagent-stop-guard.bats` に、`running` が空になって通す分岐のケースを追加する: 1 回目は未完了の背景タスクを残して拒否させ（カウンタ 1 になる）、2 回目は自分の背景タスクがすべて終わった payload（`background_tasks` から自分の起動 ID が消えている、または `status` が `running` 以外）で停止を通し、カウンタファイルが削除されていることを確認する。さらに 3 回目に再び未完了の背景タスクを残して停止させ、拒否理由が `1/3` から数え直すことを確認する
- [x] 1.2 同じく `pending` が空になって通す分岐のケース（自分以外＝本体のタスクだけが `running` で残っている payload）を追加する。同様に 1 回拒否→通す→カウンタ削除の確認→もう一度未完了で拒否させて `1/3` から数え直すことまで確認する
- [x] 1.3 追加した 2 ケースが現行実装（削除処理を追加する前）で失敗することを確認する（Red）

## 2. 実装

- [x] 2.1 `plugins/dev-workflow/scripts/subagent-stop-guard.sh` の `counter_dir` / `counter` の算出を `running = {...}` の直前に移す
- [x] 2.2 `running` が空で通す分岐（`sys.exit(0)` の前）にカウンタファイル削除（`try: os.remove(counter)` / `except OSError: pass`）を追加する
- [x] 2.3 `pending` が空で通す分岐（`sys.exit(0)` の前）に同様のカウンタファイル削除を追加する
- [x] 2.4 上限到達で通す分岐の既存の削除処理はそのまま残す（書き換えない）
- [x] 2.5 `scripts/test.sh subagent-stop-guard` を実行し、1.1・1.2 で追加したケースを含め全件 Green にする

## 3. 仕様・記録の同期

- [x] 3.1 `openspec/specs/dev-workflow-subagent-waiting/spec.md` の要件「停止の拒否は上限回数までの後詰めにする」の記述は、本 change を archive（sync）した時点で delta どおりに反映される。(3a) では直接編集しない（(3b) の `openspec archive` に委ねる）
- [x] 3.2 `openspec/changes/archive/2026-09-27-subagent-wait-stop-guard/specs/dev-workflow-subagent-waiting/spec.md`（別の archive 済み change の記録）の同じ記述を、本 change の delta と同内容に手で揃える
- [x] 3.3 `plugins/dev-workflow/changes/264.md` の同趣旨の記述を揃える
- [x] 3.4 R1 の SHOULD_FIX 2 件目: `plugins/dev-workflow/changes/561.md` を新規作成する（264.md の文言を揃える 3.3 とは別に、この change 自体の変更点を記録する）

## 4. 検証

- [x] 4.1 `openspec validate subagent-stop-guard-clear-counter-on-pass --strict` を実行し exit 0 を確認する
- [ ] 4.2 受け入れ条件（issue #561）の 3 点（カウンタ削除・spec/テスト更新・`scripts/test.sh subagent-stop-guard` の exit 0）を満たしていることを確認する
