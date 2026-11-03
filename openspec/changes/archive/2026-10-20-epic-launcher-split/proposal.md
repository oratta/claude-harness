## Why

issue #1123 は `scripts/epic-dispatch.sh` を、状態の記録・親の見張り・起動部品の 3 層に分ける。change 1（epic-state-files、PR #1148）で状態の記録と見張りを、change 2（cross-repo-children、PR #1160）で別のリポジトリの子を入れた。残る change 3「起動部品の差し替え」は、tmux で子を起動できるようにし、develop の SKILL.md「エピックの扱い」を起動部品の差し替えとして書き直すことである。

ところが今の `epic-dispatch.sh` は、`orca` の呼び出しが `launch`・`reply`（`notify-closed`・`wait --resolve` も同じ関数を使う）・`reap`・`adopt`・`mark`・`wait`・`route` に散らばっていて、起動部品を差し替える境目が無い。tmux の部品を書く前に、Orca の呼び出しを 1 本の起動部品のスクリプトに切り出し、どの部品も同じサブコマンドで呼べる境目を決める必要がある。change 3 はこの切り出し（3a、この change）と、tmux の部品・SKILL.md の書き直し（3b、この change のマージ後に仕様化する `epic-launcher-tmux`）の 2 つに割った（判断の記録は https://github.com/oratta/claude-harness/issues/1123#issuecomment-6301834436 ）。

## What Changes

- `plugins/dev-workflow/scripts/epic-launch-orca.sh` を新しく作り、`epic-dispatch.sh` が呼んでいた `orca` のコマンドをすべてここへ移す。サブコマンドは `available`・`here`・`prepare`・`list`・`repos`・`unregistered`・`create`・`start`・`deliver`・`close`・`remove`・`mirror` の 12 個（境目の決め方は design.md の Decision 1〜3）
- `epic-dispatch.sh` は `orca` のコマンドを直接呼ばず、起動部品のスクリプトを呼ぶ。記録・見張り・上限・`reap` の安全確認は `epic-dispatch.sh` に残す
- `epic-dispatch.sh` の stdout・exit code・stderr の文言と、`orca`・`git`・`gh` の呼び出しの順と回数は変えない。既存の `tests/epic-dispatch.bats` は、orca を呼ぶスクリプトの照合 1 件を除いて書き換えずに通す
- 既存要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」の「1 本」を `epic-dispatch.sh` から `epic-launch-orca.sh` に変え、照合を `orca` の語ではなく `orca` のコマンドの書き方で行う
- 既存要件「Orca の部品は記録を書いたあとに Orca の印へ写す」を、`epic-dispatch.sh` が起動部品の `mirror` を呼ぶ形に書き直す（写す印と失敗の扱いは変えない）
- `route` が返す値（`orca`・`subagent`・`nested`）、記録の書式（`launcher` は `orca` だけ）、develop の SKILL.md は変えない（3b で変える）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-epic-state`: 起動部品のスクリプトの境目（サブコマンドと出力の契約）を足し、Orca の印への写しを起動部品の `mirror` に移す
- `dev-workflow-develop`: orca を呼ぶスクリプトを `epic-launch-orca.sh` の 1 本にし、その照合の書き方を変える

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`orca` の呼び出しをすべて起動部品の呼び出しに置き換える。`orca` のコマンドを書いたコメントと stderr の文言は起動部品へ移すか書き直す）
- `plugins/dev-workflow/scripts/epic-launch-orca.sh`（新規）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（orca を呼ぶスクリプトの照合 1 件を変え、起動部品の境目のテストを足す）
- `plugins/dev-workflow/changes/1123.md`（変更の記録）
- 実行中のエピックへの影響は無い（記録の書式・stdout・`orca` の呼び出しが変わらないので、マージの前に起動した子も、マージの後の親から今までどおり見張れる）
