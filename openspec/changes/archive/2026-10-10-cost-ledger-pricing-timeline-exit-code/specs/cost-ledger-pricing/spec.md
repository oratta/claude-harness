## MODIFIED Requirements

### Requirement: 警告は 1 行目と終了コードを変えず、省くこともできる
ずれの警告は、出力の 1 行目（帰属先ごとの固定書式の行）を変えてはなら MUST NOT ない。警告の有無で終了コードを変えてはなら MUST NOT ない。

`issue` の経路を JSON で出すとき、システムは突き合わせの結果を `price_drift` という鍵に入 SHALL れる。警告が無ければ値は `null` とする。

`cost` サブコマンドは、突き合わせそのものを行わない引数 `--no-drift-check` を受け付け SHALL る。PR / issue へ「ここまでのコスト」を積む hook（spec `cost-ledger-timeline`）が呼ぶ `timeline` サブコマンドは、突き合わせを行ってはなら MUST NOT ない（積む行は警告を使わず、突き合わせのための読み直しは所要時間を増やすだけなので）。hook は `cost_ledger.py` を `timeline` でだけ呼 MUST ぶ。

#### Scenario: 警告があっても 1 行目は同じ
- **WHEN** 「ずれあり」のセッションがある状態と、同じ会話ログで記録を消した状態でコストを求める
- **THEN** 両方の出力の 1 行目は同じで、終了コードはどちらも 0 である

#### Scenario: 突き合わせを省く
- **WHEN** 「ずれあり」のセッションがある状態で、`cost` を `--no-drift-check` 付きで実行する
- **THEN** `単価表のずれ:` を含む行は出ず、1 行目は引数を付けないときと同じである

#### Scenario: コストを積む hook は突き合わせの無い経路で呼ぶ
- **WHEN** 合格ラベルの付与を捕まえた hook が `cost_ledger.py` を呼ぶ
- **THEN** その呼び出しのサブコマンドは `timeline` だけである

#### Scenario: timeline は突き合わせない
- **WHEN** 「ずれあり」のセッションがある状態で、`timeline` を `--pr` と `--issue` のそれぞれで実行する
- **THEN** 出力に `単価表のずれ:` を含む行は無い
- **AND** 終了コードは 0 で、出力の 1 行目は `コスト: ` で始まる通常のコスト行である

#### Scenario: JSON の出力に結果が入る
- **WHEN** 「ずれあり」のセッションがある状態で、`issue` の経路を JSON で出す
- **THEN** 出力は有効な JSON で、`price_drift` に突き合わせたセッションの数と「ずれあり」のセッションの数が入っている
