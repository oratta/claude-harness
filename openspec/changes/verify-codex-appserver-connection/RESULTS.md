# #705 接続PoC結果（2026-09-17）

## 判定
**基本接続・結果回収・非競合中断を確認。総合Goは保留、issueは未完了。** 障害試験表の残項目と現行停止ログの対応付けが残る。本番worker・品質工程は実装していない。

## 実測
- codex-cli 0.153.4、既存configのgpt-6-astra、直接stdio、read-only、toolsを使わない固定入力。
- 現在のauth profileのID token email claimとaccount/readのfingerprint一致をローカルで確認。認証切替なし。これはprofile帰属の照合であり署名検証やworkspace/account ID一意性保証ではない。秘密値・emailは記録しない。
- complete 1件: 受付成功、進捗28イベント、usage観測、completed。保存threadをthread/readで読み、結果READY一致を確認した。
- interrupt初回1件: 受付直後のinterrupt RPCが失敗しunknown。停止済み・中断成功とは数えなかった。RPCの詳細は初版clientが保持しておらず原因を断定できない。
- clientをturnの実活動を待って中断する形に修正し追加1件: 受付成功、進捗4イベント、**interrupted**を確認。usage欠落は0扱いしない。自然completedとの競合ではなく、必須中断条件を満たした。
- モデル依頼は合計3件。各試験終了後にPoC所有serverだけを終了した。本番resident・共有brokerは操作していない。

## 自動検証
`python3 -m unittest discover -s scripts/poc/codex-appserver -v`: 5 tests PASS。interrupted合格、completed競合不合格、failed不合格、アカウント不一致でturn受付前に拒否、terminal通知のitems欠落時のthread/read回収を確認。completeの成功終了にはREADY一致を必須とし、completedだけでは成功扱いしない。
`openspec validate verify-codex-appserver-connection --strict --no-interactive`、`git diff --check`: PASS。

## 残る検証
- 現在Claudeが解決するcompanionの版と、今回報告された停止生ログの同定。
- exec/companion/direct App Serverの同条件比較。今回モデル消費を抑えてdirectだけ実測した。
- timeout、transport切断、親poller終了、quota/authエラー、未対応server requestの障害fixture試験。
- 実際のbroker再利用・account分離・寿命保証の実測。ローカル1.0.6ソースにはbroker/direct経路が存在するが、採用可能と断定していない。

## #706/#707への引継ぎ
- 最小App Server接続は成立。既存companionも内部App Serverであり、置換だけを改善根拠にしない。
- 今回clientは終了時に所有serverも閉じる。親終了後の継続、排他、再起動復旧は#706で必要。先にbrokerの実用上の契約を評価する。
- 中断受付応答とterminalを分ける。turn受付直後の失敗を実測しており、interruptのタイミング・失敗時状態確認が必要。
- read-only無害fixtureの結果なので、書込み・レビュー独立性・hooks代替など#707の品質保証は未検証。
