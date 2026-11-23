## 1. 手順書の書き換え

- [x] 1.1 `epic-stop.md` 手順 8 の冒頭（`stopped <N>...` で起こされたらの直後）に、止まりが状態の記録だけで決まる 3 点（design の Decisions ①〜③）と、`child-log --last` が止まりの説明を組み立てる用途であることを書く。会話ログから止まりを推し量る記述が止まりの判断に関わる行に無いことを確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/epic-stop.md:7（手順 8 の冒頭）
- [x] 1.2 `epic-stop.md` 手順 8 の「主の答えを受けたら…」の段落と、「委任で送る」の段落から、親が `reply-after-idle.md` の表で分類して `--relaunch` を足す指示を外し、`reply` が自動判定する・明示の `--relaunch` は起動し直させたいときだけと書く。触る範囲: plugins/dev-workflow/skills/develop/references/epic-stop.md:7（主の答えを受けたら…の段落）、plugins/dev-workflow/skills/develop/references/epic-stop.md:23（委任で送る）
- [x] 1.3 `reply-after-idle.md` の「そのまま送るか、起動し直すか（子）」の前置き（表の直前の段落）に、表の対象が止まりとして決まった子だけで主が子のタブで始めたターンの子には何もしないこと、表は上から順に読み最初に当たった行で決めることを足す。表の行は変えない。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:40-49

## 2. 仕様・テスト・記録

- [x] 2.1 `plugins/dev-workflow/tests/develop-skill.bats` に、手順 8 の 3 点・手分類の指示が無いこと・表の前置きの「上から順」を検査するテストを足し、`reply-after-idle` の表の既存の検査（`develop-skill.bats` の 1341・1393・1403・1414 付近）が通ることを確かめる。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:1341-1420
- [x] 2.2 変更の記録 `plugins/dev-workflow/changes/1760.md` を書く（版は上げない）。触る範囲: plugins/dev-workflow/changes/1760.md（新規）
- [x] 2.3 検証: `bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/epic-dispatch.bats tests/owner-question-style.bats tests/develop-epic-scene-budget.bats tests/injection-budget.bats`、`grep -n "会話ログ" plugins/dev-workflow/skills/develop/references/epic-stop.md plugins/dev-workflow/skills/develop/references/reply-after-idle.md`（止まりの判断に関わる行が出ない）、`openspec validate epic-stop-docs-recorded-state-1760 --type change --strict`

## Workflow follow-up

- 実装＋verify のあと、archive で `epic-stop-docs-recorded-state-1760` を現行 `dev-workflow-develop` へ反映する。
