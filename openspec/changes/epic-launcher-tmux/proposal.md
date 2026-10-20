## Why

issue #1123 の最後の change（3b）。3a（PR #1174、`epic-launcher-split`）で Orca の呼び出しを `scripts/epic-launch-orca.sh` に切り出し、起動部品のサブコマンド 12 個の契約を決めた。残るのは、tmux で子を独立した Claude Code のセッションとして起動できる部品を足し、`route` と記録の `launcher` で部品を選び、develop の SKILL.md「エピックの扱い」を「Orca 経路とサブエージェント方式の二本立て」から「起動部品の差し替え」に書き直すこと。flatmate の住人は tmux で常駐しているので、Orca が無くても別セッションで子を並列に回せるようにする。判断の記録は https://github.com/oratta/claude-harness/issues/1123#issuecomment-6304326783 。

## What Changes

- `plugins/dev-workflow/scripts/epic-launch-tmux.sh`（新規）: 12 個のサブコマンドを `tmux` と `git` だけで実装する。起動コマンドは `EPIC_DISPATCH_CLAUDE_CMD`（今と同じ）
- `route` の結果に `tmux` を足す。判定順は 記録か `EPIC_DISPATCH_PARENT_EPIC` があれば `nested` → 環境変数 `EPIC_DISPATCH_LAUNCHER`（新規。`orca`／`tmux` で固定）→ Orca 管理なら `orca` → `TMUX` が空でなく `tmux` が PATH にあれば `tmux` → それ以外 `subagent`
- `launch`・`adopt` は同じ順で部品を選んで記録の `launcher` に書き、`reply`・`notify-closed`・`wait --resolve`・`reap` は子の記録の `launcher` の部品を呼ぶ
- 登録の仕組みを持たない部品の扱い: `unregistered` が `ok` を返したら登録は要らないとして、空の `repo_id` のまま `create` に進む。`create` の `clone` が空なら親のワークツリーのリポジトリに作る。`here` の `repo_id` が空でも tmux では止めない（Orca の部品のときだけ `has no repoId` で止める）
- サブエージェント方式には状態の記録を書かせない（2026-10-20-epic-state-files の design.md Decision 12 の「サブエージェント方式も記録を書く」を取り消す）
- SKILL.md「エピックの扱い」→「回し方」を、共通の手順 1 本と部品ごとの欄に書き直す。用語は「Orca 経路」をやめて「別セッション方式（Orca の部品か tmux の部品）」と「サブエージェント方式」にする
- 実機で 1 回、tmux の部品の子の起動・止まった子の拾い上げ・終わった子の片付けを確かめる

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-epic-state`: 起動部品の要件を 2 本の部品に広げ、記録の `launcher` ごとの部品選び、tmux の部品の動き、サブエージェント方式が記録を書かないことを足す
- `dev-workflow-develop`: `route` の判定順に `tmux` と `EPIC_DISPATCH_LAUNCHER` を足し、「Orca 経路」の要件を別セッション方式に読み替え、SKILL.md の回し方を起動部品の差し替えとして書かせる

## Impact

- `plugins/dev-workflow/scripts/epic-launch-tmux.sh`（新規）、`scripts/epic-dispatch.sh`（部品の選び方、`here` の空の `repo_id`、`unregistered` の `ok`、`route`）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（部品を tmux にしたときのテスト）、新規の `tests/epic-launch-tmux.bats`、`tests/develop-skill.bats`（SKILL.md の照合）
- `plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/changes/1123.md`
- 既存の Orca の動き（stdout・exit code・stderr・`orca` の呼び出しの順と回数）は変えない。素の tmux で interactive を使っている人は、Orca 管理外なら `route` が `tmux` を返すように変わる（`EPIC_DISPATCH_LAUNCHER` で固定できる。または既存の `回し方:` コメントが引き継がれる）
