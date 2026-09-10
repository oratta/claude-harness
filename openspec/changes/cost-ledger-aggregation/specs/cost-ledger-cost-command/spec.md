## ADDED Requirements

### Requirement: `/cost <番号>` の入力解釈
システムは `/cost <番号>` を受け取り、その番号が PR か issue かを GitHub に問い合わせて判別 SHALL する。PR ならその PR のブランチのコストを、issue ならその issue 番号を触った区間のコスト合計を返 MUST す。

#### Scenario: PR 番号を渡す
- **WHEN** 利用者が既存の PR の番号を `/cost` に渡す
- **THEN** その PR のヘッドブランチに帰属するコストが返る

#### Scenario: issue 番号を渡す
- **WHEN** 利用者が既存の issue の番号を `/cost` に渡す
- **THEN** その issue 番号を触った区間のコスト合計が返る

#### Scenario: 存在しない番号を渡す
- **WHEN** 渡された番号の PR も issue も存在しない
- **THEN** コストを 0 と表示せず、番号が見つからないことを利用者に伝える

### Requirement: 出力の形式
`/cost` の出力は API 換算コストを USD と円の両方で SHALL 示す。数字が推定であることを利用者が読み取れるよう、帰属の内訳（ブランチ単位か区間単位か）も示 MUST す。

#### Scenario: USD と円が両方出る
- **WHEN** `/cost` が値を返す
- **THEN** 出力には USD の金額と円の金額が両方含まれる

#### Scenario: issue 単位は推定であることが分かる
- **WHEN** issue 番号を渡してコストが返る
- **THEN** 出力には区間ごとの内訳が含まれ、その数字が区間分割による推定であることが分かる

### Requirement: プラグインの登録
`cost-ledger` は独立したプラグインとして `plugins/cost-ledger/.claude-plugin/plugin.json` を持ち、リポジトリルートの `.claude-plugin/marketplace.json` にも登録 MUST される。

#### Scenario: 両方に登録されている
- **WHEN** `bash scripts/test.sh` を実行する
- **THEN** plugin.json と marketplace.json の整合を検査する S131（`tests/marketplace-sync.bats`）を含めて全件 green（exit 0）になる
