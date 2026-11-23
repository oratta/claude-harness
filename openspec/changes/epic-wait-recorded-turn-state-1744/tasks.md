# Tasks

行番号は仕様化時点（486fbaa）の案内。実装前に該当箇所を読む。実装対象は下記の 4 ファイルのみ。epic-stop.md / reply-after-idle.md は #1760 の範囲。

## 1. 状態記録による検知と受領

- [x] 1.1 親の fixture に有効な turn_input / turn_state の組を明示できる補助を用意し、parent / startup の主の返事待ちの検知、owner の主の返事待ち・作業報告、親側の作業報告・完了、記録なし・null・型不正・世代不一致・セッション不一致をテストする。古い停止印やログ中の問いが対象判定を覆さないこと、ログなしでも有効状態を検知することを含める。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1-450（setup / put_record）、plugins/dev-workflow/tests/epic-dispatch.bats:7250-7545（wait log の既存検知ケース）
- [x] 1.2 スクリプト内に既存の有効な終了状態の契約を満たす判定を設け、detect_stopped と resume_moved を状態記録に切り替える。同じ世代・セッションの二重受領を防ぎ、受領の排他更新時にも読んだ組を比較する。入力更新による再開を記録し、uuid・アイドル時間・印だけによる検知や再開判定を除く。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1664-1764（record_log_json / resume_moved / detect_stopped / write_stop_json）、plugins/dev-workflow/scripts/epic-dispatch.sh:1965-2015（wait の検知ループ）

## 2. 自動判断と送信の入口

- [x] 2.1 resolve の入口、長い待ちの再判断、自動返事を届ける直前、wait の声かけで対象条件と世代・セッションを再確認する。判断中に owner の入力や状態の無効化があれば送信・端末終了・再起動・通した記録を行わない。明示的な reply と起動操作の契約は維持する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1008-1068（deliver_reply の wait 経由の確認）、plugins/dev-workflow/scripts/epic-dispatch.sh:1413-1493（resolve_stopped）、plugins/dev-workflow/scripts/epic-dispatch.sh:1495-1649（keepalive）、plugins/dev-workflow/scripts/epic-dispatch.sh:1831-1862（rejudge_changed）
- [x] 2.2 150,001 トークン以上と長い経過時間を含む owner の 2 状態で、judge・terminal send・terminal close・起動がすべて 0 回であることを固定する。通常の親の返事待ちでは stopped または親の返事を確認する。通す以外（主に上げる・問いではない・失敗・不正出力・空の返事）は送信も再起動もしない。判断中の主の入力、長い待ちの再判断、声かけの迂回も確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:4777-4965（resolve）、plugins/dev-workflow/tests/epic-dispatch.bats:5350-5488（再起動）、plugins/dev-workflow/tests/epic-dispatch.bats:6837-6925（量の境界）、plugins/dev-workflow/tests/epic-dispatch.bats:7980-8348（声かけ）、plugins/dev-workflow/tests/epic-dispatch.bats:8490-8783（長い待ち）


- [x] 2.3 長い待ちの既存テスト（8573 行・8582 行）を、ログ追加だけの fixture から、新世代の parent の有効な主の返事待ちで stopped、owner の新入力と turn_state null で resumed と通常上限後の timeout になる fixture に更新する。入力の世代・セッションと状態が同じまま問いの uuid または主の発言だけがログに増える負例も追加し、stopped / resumed にせず長い待ちを続け、他の変化が無ければ expired になることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:8490-8520（told_ready / chat_on_poll）、plugins/dev-workflow/tests/epic-dispatch.bats:8573-8589（長い待ちの停止・再開）

## 3. 旧期待値の整合と検証

- [ ] 3.1 ログだけの停止を検知する旧期待値を状態記録の契約に合わせる。ログだけでは判断役に渡らない負例と、有効な親の主の返事待ちから判断へ進み uuid のみを公開する正例を残す。依存待ちマーカーの構文テストは維持し、記録なし・owner・作業報告をマーカーだけで格上げしない。子側のフック・予約文・排他更新の既存テストも維持する。触る範囲: plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats:1-95、plugins/dev-workflow/tests/epic-child-state.bats:171-209（親 fixture の旧期待）、plugins/dev-workflow/tests/epic-child-state.bats:420-440（末尾マーカーの全文）、plugins/dev-workflow/tests/epic-dispatch.bats:7327-7545（ログ検知）、plugins/dev-workflow/tests/epic-dispatch.bats:8784-8919（依存待ち）
- [ ] 3.2 `bash -n plugins/dev-workflow/scripts/epic-dispatch.sh`、`scripts/test.sh epic-dispatch epic-stop-from-log-scenario epic-child-state`、`openspec validate epic-wait-recorded-turn-state-1744 --type change --strict` を実行し、いずれも exit 0 を確かめる。失敗を直したら当該テストと必要な回帰を再実行し、結果を記録する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1008-1068、plugins/dev-workflow/scripts/epic-dispatch.sh:1413-2015、plugins/dev-workflow/tests/epic-dispatch.bats:1-8997、plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats:1-95、plugins/dev-workflow/tests/epic-child-state.bats:171-440
