## Why

`subagent-stop-guard.sh` は拒否回数のカウンタファイルを、上限到達で通した経路（`n >= MAX_BLOCKS` の分岐）でしか削除しない。`running` が空で通す経路（151-155 行）と `pending` が空で通す経路（175-177 行）は、理由文に従って正しく待ってから停止したサブエージェントが通る経路だが、ここではカウンタファイルを消さない。そのため、正しく待って一度停止したサブエージェントが次のターンで再び背景タスクを残して停止しようとすると、前回までの拒否回数の続きから数え始め、後詰め（`MAX_BLOCKS` 回までは拒否し続けてよい猶予）を早く使い切ってしまう。spec の要件「停止の拒否は上限回数までの後詰めにする」が意図した「理由文を無視して停止を繰り返すサブエージェントだけを後詰めの対象にする」から外れ、正しく従うサブエージェントほど損をする。

## What Changes

- `subagent-stop-guard.sh` の counter_dir / counter の計算を `running = {...}` の直前に移し、`running` が空で通す分岐と `pending` が空で通す分岐の両方で、`sys.exit(0)` の前にカウンタファイルの削除（`try: os.remove(counter); except OSError: pass`）を行う。`counter_dir` が無い場合は `FileNotFoundError`（`OSError` のサブクラス）として無視する
- 既存の「上限到達で通す」分岐のカウンタ削除はそのまま残す（3 箇所とも「停止を通した時点」で削除する形に揃える）
- `openspec/specs/dev-workflow-subagent-waiting/spec.md` の要件「停止の拒否は上限回数までの後詰めにする」の記述を、「上限に達して通した時点でそのカウンタファイルを削除する」から「停止を通した時点（上限到達・未完了なしのいずれでも）でそのカウンタファイルを削除する」に直す
- `openspec/changes/archive/2026-09-27-subagent-wait-stop-guard/specs/dev-workflow-subagent-waiting/spec.md`（アーカイブ側の同じ記述）も同様に直す
- `plugins/dev-workflow/changes/264.md` の同趣旨の記述を揃える
- `plugins/dev-workflow/tests/subagent-stop-guard.bats` に、先に 1 回拒否させてから正しく待って通した場合にカウンタファイルが消えていることを確かめるケースを追加する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-subagent-waiting`: 「停止の拒否は上限回数までの後詰めにする」要件のうち、カウンタファイルを削除するタイミングを「上限到達で通した時点」から「停止を通した時点（上限到達・未完了なしのいずれでも）」に変える

## Impact

- `plugins/dev-workflow/scripts/subagent-stop-guard.sh`（実装）
- `plugins/dev-workflow/tests/subagent-stop-guard.bats`（回帰テスト追加）
- `openspec/specs/dev-workflow-subagent-waiting/spec.md`、`openspec/changes/archive/2026-09-27-subagent-wait-stop-guard/specs/dev-workflow-subagent-waiting/spec.md`（仕様文言）
- `plugins/dev-workflow/changes/264.md`（変更記録の追記）
- 対象は PR #560（issue #264）のゲートレビューで見つかった non-blocking 指摘の切り出し。挙動を変える範囲はカウンタファイルの削除タイミングのみで、拒否そのものの判定ロジック（未完了背景タスクの検出）には触れない
