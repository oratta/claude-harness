## Why

エピックの子の状態（起動済み・主の返事待ち・用が済んだ）は、今は Orca のワークツリーの印（ボードの列 `workspaceStatus` とコメント欄 `comment`）だけに置かれている。そのため Orca の無い環境（flatmate の住人の tmux など）では親が子を見張れず、Orca 環境でも親と別のリポジトリにある子（例: flatmate のエピックに積んだ claude-harness の子 #1098）は親の `orca worktree list` の絞り込み（同じ `repoId`）から漏れて誰にも見張られずに止まった（エピック #1122・issue #1123）。

この change は #1123 を 3 つに割った 1 つ目で、状態の正本を環境に依存しないローカルのファイルに移し、親の見張りをそのファイルだけで動くようにする。別リポジトリの子の起動（2 つ目）と、起動部品の差し替え（tmux・サブエージェント。3 つ目）はこの記録の上に載せる。別リポジトリの子の挙動 7 項目と起動部品の境目は、実装より先にこの change の design.md で決め、2 つ目・3 つ目の change はそれに従う。

## What Changes

- 状態の記録を `~/.claude/epic-state/<エピックの owner>.<エピックの repo>-<エピック番号>/<子の owner>.<子の repo>-<子の番号>.json` に子ごと 1 ファイルで置く（置き場の根は `EPIC_STATE_ROOT` で変えられる）。書き込みは同じディレクトリの一時ファイルに書いてから `mv` で置き換え、親と子が同じファイルを読み書きするので `mkdir` の排他を取る
- 子を `<owner>/<repo>#<N>` で識別する。記録とファイル名は常にこの形で持ち、`epic-dispatch.sh` の引数と出力は、エピックと同じリポジトリの子は今までどおり番号だけ（`#N` / `N`）で書く
- `mark`（子の側）は、今いるワークツリーのパスで自分の記録を探して書き換える。`wait`・`pending-owner`・`reap`・`notify-closed`（親の側）は記録だけを読み、Orca の一覧を状態の判定に使わない。子 issue の state は、エピックと同じリポジトリの子は今のまま `repos/{owner}/{repo}` で、記録の `repo` が違う子は `repos/<repo>` で読む（親の側は origin を読まない）
- `route` は、環境変数 `EPIC_DISPATCH_PARENT_EPIC` か、今いるワークツリーのパスを持つ記録があれば `nested` を返す（Orca の親子関係を見ない）
- `launch`（Orca の起動）は、子のワークツリーを作る前に記録を書き、作ったあとにパスと結果を書き足す。Orca の画面の印は Orca の部品が記録から写す（正本は記録の側）
- 新しいサブコマンド `adopt`: 記録の無い、この変更より前に Orca で起動した子を、Orca の一覧から記録に写す（実行中のエピックをこの変更のあとに再開するため）
- 新しいサブコマンド `clear`: エピックの完了時に状態のディレクトリを消す。`reap` は片付けた子の記録を消す
- 親のセッションが起動し直したら、エピックの状態のディレクトリから「launch に渡したことのある子」と各子の状態を組み立て直して再開する
- #1106（PR #1120）の同時に動かす子の上限は、枠を使っている子を Orca の一覧ではなく記録から数える（上限の値の決め方・`deferred` の出し方は変えない）
- **BREAKING**（内部の契約のみ）: 止まった印・完了の印を Orca のコメント欄・ボードの列から読む既存要件を、記録の項目を読むものに読み替える

## Capabilities

### New Capabilities

- `dev-workflow-epic-state`: エピックの状態の記録（置き場・子 1 ファイルの項目・書き込みの排他・消し方）と、別リポジトリにまたがるエピックの子の識別、記録を正本にした親の見張り

### Modified Capabilities

- `dev-workflow-develop`: `epic-dispatch.sh` の印（`workspaceStatus` / `comment`）を正本にしている既存要件を、状態の記録の項目を読むものに読み替える。親の再開手順と完了時の片付けに記録を使う

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（mark / wait / pending-owner / reap / notify-closed / route / launch の状態の読み書き、adopt・clear の追加）
- `plugins/dev-workflow/scripts/epic-state.sh`（新規。状態の記録の読み書きの関数を置き、epic-dispatch.sh が source する）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（Orca の印を見ていたテストを記録を見る形に直す。記録の書式・排他・adopt・clear のテストを足す）
- `plugins/dev-workflow/skills/develop/SKILL.md`（回し方の手順 3・4・7・完了条件、「エピックの子が主の返事を待って止まるとき」の印の置き場）
- `plugins/dev-workflow/skills/develop/references/reply-after-idle.md`（主の返事待ちの子の見分け方が Orca の印を指している箇所）
- `plugins/dev-workflow/changes/1123.md`（変更の記録）
- 依存: #1120（同じ `epic-dispatch.sh` を変更中）が先にマージされたら origin/main に rebase してから実装する
