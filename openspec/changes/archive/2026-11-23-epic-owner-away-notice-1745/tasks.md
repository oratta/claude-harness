# Tasks

実装開始の前提は issue #1745 の仕様化判断と、この change に対する R1 の APPROVE。行番号は仕様化時点の案内で、編集前に該当範囲を読み直す。

## 1. wait の owner-away の検知と出力

- [x] 1.1 `epic-dispatch.sh` に、有効な owner のターンの `主の返事待ち` が `EPIC_DISPATCH_OWNER_AWAY_SEC`（既定 3600、非負整数でなければ使い方と exit 1）以上たち `owner_away_told` が今回のターンと違う子を、排他つきで `owner_away_told` を書いてから `owner-away <N>...`（exit 0）として返す検知を足す。書く直前の入力更新は書かず返さない。書けなければ失敗したポーリングに数える。`stop`・`stop_uuid`・`--resolve`・声かけ・長い待ちは変えない。ヘッダーコメントと usage の出力語の一覧も更新する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:81-130（ヘッダー）、:322-328（usage の wait 出力）、:1737-1760（WAIT_TURN_DEFS）、:1815-1855（detect_stopped の隣に新関数）、:2020-2035（環境変数の検査）、:2099-2125・:2128-2140（wait の検知と出力）
- [x] 1.2 bats でテストを足す: 既定の 3600 秒を過ぎたら `owner-away`・子への送信なし・`orca terminal close` と `--relaunch` なし・`stop` 不変（150,000 トークン超の会話ログを含む）、3600 秒前は `timeout`、`EPIC_DISPATCH_OWNER_AWAY_SEC` で時間が変わる、主が新しく入力（世代違い）したら出ない、同じターンで 2 回目は出ない、親が送った入力のターンと `作業報告` は対象外、環境変数が不正なら exit 1。`TMPDIR=$(mktemp -d) bats plugins/dev-workflow/tests/epic-dispatch.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:9614-9660（owner のターンの既存テストの隣）

- [x] 1.3 `dev-workflow-develop` の要件「wait は子の状態の記録だけで止まった子を検知する」の delta（MODIFIED）が実装と一致することを確かめる。これは `openspec/changes/` 内の artifact で、実装段の編集ファイル数（上限 5）には数えない。archive 時に現行 spec へ反映される。触る範囲: openspec/changes/epic-owner-away-notice-1745/specs/dev-workflow-develop/spec.md

## 2. 手順書

- [x] 2.1 `epic-stop.md` に、`owner-away <N>...` で起こされたときの手順を足す（主に「子 #N のタブで問いが残っている」と知らせる。子に返事を送らない・端末を閉じない・`--relaunch` しない・`stopped` の判断に回さない。知らせたら同じ引数で `wait` を掛け直す。同じターンでは再び起こされない）。報告の書き方は `epic-loop.md`「主への報告」に従う。触る範囲: plugins/dev-workflow/skills/develop/references/epic-stop.md:5-9（停止の処理の手順 8 の隣）
- [x] 2.2 `epic.md` に、主が子のタブで話している最中は親が何もしないこと・席を離れたら時間で知らせることを 1 項目足す（読むものの表の stop の行にも `owner-away` を足す）。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:26-40（読むもの）、:43-50（共通の項目）。文書テストがあれば更新し、`bats` 全体が exit 0

## 3. 記録と統合検証

- [x] 3.1 `plugins/dev-workflow/changes/1745.md`（新規）に、出力語・時間の起点・一度だけの記録・戻し方（本 PR の revert）を書く。版は上げない。触る範囲: plugins/dev-workflow/changes/1745.md（新規）
- [x] 3.2 `bash -n plugins/dev-workflow/scripts/epic-dispatch.sh`、`scripts/lint.sh epic-dispatch.sh`、`openspec validate epic-owner-away-notice-1745 --type change --strict`、`git diff --check` が exit 0。子側のフック（`epic-child-state.sh`）と archive 済みの change を変えていない
