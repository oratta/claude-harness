## ADDED Requirements

### Requirement: 接続PoCは実行経路を区別する
検証はexec直叩き、companionのCLI入口と内部transport、直接App Serverを区別し、実使用バージョンと設定を記録しなければならない（MUST）。原因不明を常駐化で解消したと表明してはならない（MUST NOT）。

#### Scenario: companionの内部がApp Serverである
- **WHEN** CLI入口の下でApp Server接続が確認される
- **THEN** 外側CLIであることをexec方式の根拠にせず、既存brokerの再利用と待機境界を比較する

### Requirement: 受付と完了と待機終了を分離する
PoCはrequest/thread/turnを相関し、進捗、terminal status、結果を独立に記録しなければならない（MUST）。待ち期限や切断で状態不明ならunknownまたはattention_requiredとし、再送してはならない（MUST NOT）。

#### Scenario: turn受付後に待ち期限を超える
- **WHEN** turn/startが応答した後にclientの待ち期限になる
- **THEN** 成功・失敗・入力要求と決めつけず、同じturnを追跡し、重複実行しない

### Requirement: 明示中断の終了を確認する
PoCは所有するturnだけを中断し、応答と終了確認を分けなければならない（MUST）。認証やquota障害で別アカウントまたはexecへ暗黙fallbackしてはならない（MUST NOT）。

#### Scenario: 中断応答後に接続を失う
- **WHEN** turn/interrupt応答後、terminalを確認できない
- **THEN** 停止済みとは報告せずunknownを記録し、再実行しない

### Requirement: 実測を後続の判断に渡す
仕様レビューとモデル実測を区別し、検証表の結果・未確定点・既存機能再利用可否を#706へ渡さなければならない（MUST）。

#### Scenario: 仕様だけが完成する
- **WHEN** 仕様レビュー用Draft PRを作成する
- **THEN** issueを閉じず、実装未着手・実測未実施・仕様レビュー待ちを明記する
