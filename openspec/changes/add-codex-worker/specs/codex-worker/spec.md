## ADDED Requirements

### Requirement: 手動依頼は永続化後に独立workerで実行する
手動submitは明示account/cwd/model/roleを検証し、受付をSQLiteへ永続化してから親と独立したworkerを開始しなければならない（MUST）。同一request IDと入力は同じjobを返し、入力違いは拒否する（MUST）。

#### Scenario: submitプロセスが終了する
- **WHEN** submitがjob IDを返して終了する
- **THEN** workerは処理を続け、別プロセスからstatus/resultを取得できる

### Requirement: アカウントと作業ディレクトリを排他的に所有する
登録profileの帰属、実server account、fresh quota、linked feature worktree、role sandboxを確認しなければならない（MUST）。同じaccount/cwdは別台帳からも重複実行を拒否する（MUST）。認証不明とquota不明でturnを開始してはならない（MUST NOT）。

#### Scenario: 別台帳が同じaccountを使う
- **WHEN** 未ackのjobが共通所有台帳にある
- **THEN** 新規依頼を拒否する

### Requirement: 不明な実行を再投入しない
turn開始要求後の切断またはworker喪失はunknownとして保持し、ackと自動再投入を拒否する（MUST）。cancel応答のみを停止証明にせずterminalを確認する（MUST）。

#### Scenario: turn受付後に切断する
- **WHEN** terminalを観測できない
- **THEN** unknownとし所有を保持する

### Requirement: 未対応の機能を明示する
初版でsend/steer、burn、自動復旧を未対応と明示しなければならない（MUST）。手動差戻しは完了結果を回収しack後、新IDのfresh担当へ指示を渡す（MUST）。

#### Scenario: 実行中の追加指示を送る
- **WHEN** sendを指定する
- **THEN** unsupportedを返し別turnを暗黙に開始しない
