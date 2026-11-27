# Tasks

## 1. 文書（epic-stop.md・epic-multirepo.md）

- [x] 1.1 手順 8 の `dismiss` の条件、未回答の停止の記録の定義と dismiss しないこと、`owner-away` の掛け直しの文、pending-owner 復元の文を直し、`develop-skill.bats` の grep で確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/epic-stop.md:7、plugins/dev-workflow/skills/develop/references/epic-stop.md:13、plugins/dev-workflow/skills/develop/references/epic-stop.md:17、plugins/dev-workflow/tests/develop-skill.bats:1366、plugins/dev-workflow/tests/develop-skill.bats:1498
- [x] 1.2 `epic-multirepo.md` の列挙に `dismiss` を足し、`epic-dispatch.bats` の 8032 行の列挙のテストを更新して通す。触る範囲: plugins/dev-workflow/skills/develop/references/epic-multirepo.md:12、plugins/dev-workflow/tests/epic-dispatch.bats:8032

## 2. epic-dispatch.sh

- [x] 2.1 ヘッダーの出力行数を直し（112 行の `--resolve` なし: 1〜3 → 1〜4 行、134 行の `--resolve` あり: 1〜4 → 1〜5 行。どちらも `owner-away` が増えた分）、`cmd_pending_owner` に `status != done` を足す。`--help`（348-375 付近）と HELP_WORDS のテストへの影響を確かめ、pending-owner の新テストと owner-away の閾値後 `--resolve`・排他取得失敗のテストを足して通す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:112、plugins/dev-workflow/scripts/epic-dispatch.sh:134、plugins/dev-workflow/scripts/epic-dispatch.sh:2454（cmd_pending_owner）、plugins/dev-workflow/tests/epic-dispatch.bats:5707、plugins/dev-workflow/tests/epic-dispatch.bats:9940-10061

## 3. stop-judge.sh

- [x] 3.1 `問いではない` を出す前に未回答の停止の記録を確かめて exit 1 にする。確かめは、モデルの出力の経路（222-228 付近）と、完了見出しでモデルを呼ばず `問いではない` を返す早期 return（131-137 付近）の両方に入れる（`gh pr list` 失敗も exit 1）。`stop-judge.bats` に 4 本（モデル経路で該当・needs-approval 無しで通す・gh 失敗・完了見出しの早期 return で該当しモデルが呼ばれない）を足して通す。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh:131-137、plugins/dev-workflow/scripts/stop-judge.sh:222-228、plugins/dev-workflow/tests/stop-judge.bats:520-550

## 4. wait 経由の回帰テスト

- [x] 4.1 `epic-dispatch.bats` に、実際の `stop-judge.sh`（`EPIC_DISPATCH_JUDGE` に指定）とモデルのスタブを使い、未回答の記録と `needs-approval` 付き PR のある子で `wait --resolve` 後に `stop=stopped-seen` が保たれ、`reply --as owner` が `skipped not-stopped` にならないことを確かめるテストを足して通す（形は同ファイル 7782 付近の実 judge のテストと stop-judge.bats:434 付近を参考にする）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:7782（実 judge のテストの隣）

## 5. 全体

- [x] 5.1 dev-workflow の bats 一式と `openspec validate epic-watch-stop-gaps --type change --strict` が通ることを確かめる。触る範囲: plugins/dev-workflow/tests（実行のみ）
