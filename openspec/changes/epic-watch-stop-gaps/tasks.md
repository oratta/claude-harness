# Tasks

## 1. 文書（epic-stop.md・epic-multirepo.md）

- [ ] 1.1 手順 8 の `dismiss` の条件、未回答の停止の記録の定義と dismiss しないこと、`owner-away` の掛け直しの文、pending-owner 復元の文を直し、`develop-skill.bats` の grep で確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/epic-stop.md:7、plugins/dev-workflow/skills/develop/references/epic-stop.md:13、plugins/dev-workflow/skills/develop/references/epic-stop.md:17、plugins/dev-workflow/tests/develop-skill.bats:1366、plugins/dev-workflow/tests/develop-skill.bats:1498
- [ ] 1.2 `epic-multirepo.md` の列挙に `dismiss` を足し、`epic-dispatch.bats` の 8032 行の列挙のテストを更新して通す。触る範囲: plugins/dev-workflow/skills/develop/references/epic-multirepo.md:12、plugins/dev-workflow/tests/epic-dispatch.bats:8032

## 2. epic-dispatch.sh

- [ ] 2.1 ヘッダーの出力行数（112・134 行）を 1〜5 行・1〜4 行に直し、`cmd_pending_owner` に `status != done` を足す。`--help`（348-375 付近）と HELP_WORDS のテストへの影響を確かめ、pending-owner の新テストと owner-away の閾値後 `--resolve`・排他取得失敗のテストを足して通す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:112、plugins/dev-workflow/scripts/epic-dispatch.sh:134、plugins/dev-workflow/scripts/epic-dispatch.sh:2454（cmd_pending_owner）、plugins/dev-workflow/tests/epic-dispatch.bats:5707、plugins/dev-workflow/tests/epic-dispatch.bats:9940-10061

## 3. stop-judge.sh

- [ ] 3.1 `判断: 問いではない` のとき未回答の停止の記録を確かめて exit 1 にし（`gh pr list` 失敗も）、`stop-judge.bats` に 3 本（該当・needs-approval 無し・gh 失敗）を足して通す。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh:222-228、plugins/dev-workflow/tests/stop-judge.bats:520-550

## 4. 全体

- [ ] 4.1 dev-workflow の bats 一式と `openspec validate epic-watch-stop-gaps --type change --strict` が通ることを確かめる。触る範囲: plugins/dev-workflow/tests（実行のみ）
