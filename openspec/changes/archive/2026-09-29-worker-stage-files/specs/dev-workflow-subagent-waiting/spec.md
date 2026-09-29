## ADDED Requirements

### Requirement: 待ちの規約を検査する W の指示書の読み替え

この capability の既存要件が W の指示書として `skills/develop/references/roles/worker.md`（複製の worker.md を含む）と書いた箇所は、長時間処理の待ちの規約が移った `skills/develop/references/roles/worker/implement.md` と読まなければならない（MUST。対応表の正本は `dev-workflow-develop`「既存要件が worker.md に置いた内容は移し先のファイルを指す」）。「実行時の検査が文言検査の素通りする違反を止めることを再現ケースで示す」の対の検査は、複製の `worker/implement.md` に違反を差し込まなければならない（MUST）。

#### Scenario: 対の検査の差し込み先

- **WHEN** `tests/subagent-stop-guard.bats` の対の検査を読む
- **THEN** 複製の `skills/develop/references/roles/worker/implement.md` に言い換えた違反を差し込んでいる

#### Scenario: 待ちの規約の所在

- **WHEN** `worker/implement.md` の全経路共通の大原則を読む
- **THEN** 長時間処理の完了を待つ目的でターンを終えないことと、正本が `plugins/dev-workflow/references/subagent-waiting.md` であることが書かれている
