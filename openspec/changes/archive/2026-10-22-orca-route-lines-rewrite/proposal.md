## Why

`docs/public-private-split.md` の固有記述の一覧に、Orca（エピックの子を別の端末で起動する道具）を前提に書いた dev-workflow の公開版の行が 25 件残っている（担い手は #1177）。#1123 の change 3b で Orca は差し替え可能な起動部品（`epic-launch-<名前>.sh`）の 1 つになったので、Orca を使わない客の環境では、Orca だけを前提にした手順が読み手に無い道具を指している。これが残ると、エピック #1127 の #1129 の受け入れ条件「公開版から、個人版の部品と固有名が無くなっている」を満たせない（issue #1177、#1168 から切り出し）。

あわせて、PR #1178 のレビューで、develop `SKILL.md` の「部品ごとの欄」の表（見出しと Orca の部品の列の行）が一覧にも検査の `DEVWF_ORCA_ROWS` にも載っていないと指摘された。これをどう扱うかを決める必要がある（design D2）。

## What Changes

- 一覧の担い手が #1177 の 25 件を、行ごとに「Orca を使う場合の書き方に直す」か「載せない行の基準に当たるとして理由を書いて一覧から外す」かを選んで片付ける（選び方は design D1）。片付けた行は一覧から消す
- 載せない行の基準に「差し替え可能な起動部品の 1 つとして Orca を並べた行」を足す。「部品ごとの欄」の表の見出しと Orca の部品の列はこれに当たるので、一覧に足さず基準で外す（design D2）
- 一覧に「担い手なし」の行が 1 件も残らないことを、一覧の全体で確かめるテストにする。Orca 経路の行が #1177 であることを確かめていた `DEVWF_ORCA_ROWS` と関連のテストは、行を直した時点で意味を失うので外す
- 既存の要件「Orca 経路の行の担い手は #1177 とする」を外し、要件「担い手なしの行を残さない」と要件「載せない行の基準に起動部品の 1 つとして並べた行を含める」を足す
- `epic-dispatch.sh`・`epic-launch-orca.sh`・`stop-judge.sh` など保留（#1123 の後）の部品は触らない。`cld` の既定値は `epic-dispatch.sh` の中にあるので、この change は文書側の書き方だけを直す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `harness-public-private-split`: 要件「Orca 経路の行の担い手は #1177 とする」を外し、一覧の「担い手なし」を 0 件にする要件と、載せない行の基準に起動部品の 1 つとして並べた行を含める要件を足す

## Impact

- `plugins/dev-workflow/README.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/develop/references/reply-after-idle.md`、`plugins/dev-workflow/scripts/owner-reply-check.sh`（コメントのみ）、`plugins/dev-workflow/skills/pr-review-gate/declarations.md`・`stages/pass.md`（Orca の語を含む行のうち、判定で「直す」になった行だけ）
- `docs/public-private-split.md`（一覧の行の削除、基準の追加、冒頭の説明の更新）、`tests/public-private-split.bats`
- 文面を固定している dev-workflow の bats（例: `plugins/dev-workflow/tests/epic-dispatch.bats` の develop SKILL.md を読むテスト）。直した文に合わせる（期待する挙動は変えない）
- 変更の記録 `plugins/dev-workflow/changes/1177.md`
