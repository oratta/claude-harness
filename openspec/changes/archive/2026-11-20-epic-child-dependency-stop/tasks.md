# Tasks

行番号は仕様化時点の HEAD `7d964dc001936a9ae8e9c9ee34fddd8a44ff400f` に対する案内。編集前に範囲を読み直す。実装開始には #1717 の R1 APPROVE が必要。

## 1. 子の依存待ちの終了と親の判断を定める

- [x] 1.1 子が途中で見つけた待ちを blocked_by に登録・確認し、`子の停止: 依存待ち` の再開記録と最後の発言の末尾マーカーを残して終了する手順を書く。PR の対応 issue が不明、登録・記録に失敗した場合は成功扱いせず親へ返す。主の返事待ちの記録とは区別し、既存の mark 不要の規則を維持する。同じ作業で文書の bats を追加し、依存登録・再開記録・終了・失敗時の記述を確認する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:1-38、plugins/dev-workflow/tests/epic-dispatch.bats:3855-3890
- [x] 1.2 親の返事に、依存登録・再開記録・終了を含める規則と main の CI 修正待ちの例を追加する。「あとで親から連絡するので待機」の推奨を認めない。同じ作業で親の基準の文書検査を追加し、主の承認待ち・human-merge・CI やり直し上限の条件を維持したまま依存待ちの返し方を検証する。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:7-39、plugins/dev-workflow/tests/epic-dispatch.bats:4125-4300

## 2. 既存の wait と reply で終了から再起動までつなぐ

- [x] 2.1 まず既存の停止・再起動の bats とコードを確認する。`launch` の skipped、`reply --relaunch` の stopped / stopped-seen 条件、`wait --resolve` の no-question による resumed を押さえ、依存待ちの会話ログ fixture で停止保持の回帰を追加する。通常の wait が終了報告を resumed に戻す箇所に限り、末尾マーカーを持つ今回の停止を自動判断なしで stopped として親へ返す最小分岐を入れる。新しい状態値・サブコマンド・起動部品は作らない。通常の no-question は従来どおりであることも bats で確認する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1294-1342、plugins/dev-workflow/tests/epic-dispatch.bats:7400-7535
- [x] 2.2 親の通常進行と手順 4・7 に、依存待ちを主の返事待ちより先に照合して動いている子から外し、依存先を既存 wait で見張り、解消後は既存 worktree の子を `reply --relaunch --as parent`、未起動の子を launch に渡す手順を接続する。親の復元時も pending を一律に主の返事待ちとせず、停止記録と途中経過を保持する。同じ作業で bats を追加し、登録・保存コメント・実形式の会話ログから wait による停止保持、open の間の送信ゼロ、closed 通知、依存の再読み取り、同じ記録から relaunched と `/develop #<子>`・続行指示の送信まで確認する。文書検査で分岐と failed / not-stopped / not_planned の扱いも確認する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:43-65、plugins/dev-workflow/tests/epic-dispatch.bats:36-115、plugins/dev-workflow/tests/epic-dispatch.bats:4385-4605、plugins/dev-workflow/tests/epic-dispatch.bats:7400-7535

## 3. 受け入れ条件をまとめて検証する

- [x] 3.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats plugins/dev-workflow/tests/epic-child-no-ask-tool.bats` を実行し、依存待ちの再現と既存のログ停止検知・承認待ち・no-question の回帰が通ることを確認する。`bats tests/develop-epic-scene-budget.bats` と `./scripts/lint.sh` も exit 0、`openspec validate epic-child-dependency-stop --type change --strict` と `git diff --check` も exit 0 とする。実行できない検証は理由を明示し、合格を宣言しない。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1-8726、plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats:1-95、plugins/dev-workflow/tests/epic-child-no-ask-tool.bats:1-55、tests/develop-epic-scene-budget.bats:1-358、scripts/lint.sh:1-147（このタスクは検証のみ）

## Workflow follow-up

- R1 のレビューは coordinator が別スレッドで起こす。この仕様工程では実装しない。
- 実装・verify 後の変更記録（plugins/dev-workflow/changes/1717.md）、archive、PR、仕様宣言は finish の担当工程で行う。実装対象が増える場合は common.md の規模超過トリップワイヤーに従う。
- 本 worker は merge / auto-merge を行わない。
