## ADDED Requirements

### Requirement: effort を二段階で検証してから実行する
worker は optional effort の非空文字列検証、許可キー、未定義 role、未登録 account の拒否を submit の静的検証で実施しなければならない（MUST）。モデル名と effort の対応は initialize 後・thread/start 前・turn_submitted を立てる前に指定 account の model/list で検証しなければならない（MUST）。固定 enum で対応を推測してはならない（MUST NOT）。

#### Scenario: 静的に不正な request を投入する
- **WHEN** effort が空/非文字列、未定義 role、未登録 account、または未知フィールドがある
- **THEN** job 投入前に拒否し、App Server に turn を送らない

#### Scenario: モデル固有の effort が非対応である
- **WHEN** model/list が luna に ultra を広告していないのに luna/ultra を要求する
- **THEN** failed と非対応 effort の error_kind を保存し、thread/start と turn/start は一度も呼ばず、unknown にしない

#### Scenario: 一覧に無いモデルまたは一覧取得失敗
- **WHEN** includeHidden=true の全ページに model フィールド完全一致の一意なモデルがない、一覧が不正、または model/list の取得に失敗する
- **THEN** 開始前に failed と原因を記録し、既定モデル/実行先への fallback をしない

#### Scenario: 広告された新しい effort または hidden モデル
- **WHEN** 明示指定モデルが一覧にあり、その supportedReasoningEfforts の reasoningEffort に要求値が含まれる
- **THEN** 固定 enum や hidden 属性を理由に拒否せず、指定モデルと effort を使用する

### Requirement: effort は turn start のみに渡す
worker は model を thread/start と turn/start の双方へ渡し、明示された effort を turn/start の effort にのみ渡さなければならない（MUST）。旧 request の effort 省略は送信時も省略し、payload を補完してはならない（MUST NOT）。既存 account identity、read-only、砂場、unknown の所有権契約を維持しなければならない（MUST）。

#### Scenario: 明示 effort を送信する
- **WHEN** sol/high の検証が成功する
- **THEN** 両 RPC の model は gpt-5.6-sol、turn/start.effort は high となり、thread/start の effort や config に effort を追加しない

#### Scenario: 旧 request の effort がない
- **WHEN** model のみ指定した旧 request を初めて実行する
- **THEN** model/list で model を照合し、turn/start に effort を載せず、保存 request/hash を変えない

### Requirement: 要求設定と実効設定を ID と共に公開する
worker は design の execution.version=1 形式で role/requested/effective/evidence を payload と別に保存し、公開 status/result と job_id/thread_id/turn_id に結び付けなければならない（MUST）。develop は同じ記録を run history に保持しなければならない（MUST）。要求値や model/list の default を実効値として補完してはならない（MUST NOT）。

#### Scenario: 実効設定を観測できる
- **WHEN** account 照合が成功し、RPC 応答または通知で model/effort を取得する
- **THEN** executor/account/model/effort の要求値と実効値、観測元を別々に記録し、turn 観測を thread 観測より優先する。差異があれば受け入れ不一致として残し自動再送しない

#### Scenario: 実効値または ID が取得できない
- **WHEN** API が effort を返さない、thread/turn 作成前に失敗する、または旧台帳行である
- **THEN** 不明な実効値/ID は null、観測元は unavailable とし、取得できた role/要求設定/ID は保持する。旧 payload/hash は変更しない
