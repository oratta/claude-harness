## MODIFIED Requirements

### Requirement: 起動アカウントを週次余裕から自動選択する
`plugins/dev-workflow/scripts/select-account.sh` は、引数が無いときにレジストリの宣言順でスロットごとの実効値（`usage-session-records` capability の「記録と snapshot から実効値を求める」。セッション記録と schema 2 usage snapshot の `accounts` から求める）を読み、利用可能な候補のうち週次余裕が最大のスロットを選ばなければならない（SHALL）。週次余裕は、現在時刻と実効値の `weekly_resets_epoch` から既存の共有枠モードと同じ式で求めて 0〜100 に clamp した週経過率から実効値の `weekly_all_pct` を引いた値とする。同点ではレジストリの宣言順で先のスロットを選ばなければならない（SHALL）。選択は起動時の 1 回だけであり、起動済みセッションのアカウントを変更してはならない（MUST NOT）。

#### Scenario: 週次余裕が大きいスロットを選ぶ
- **WHEN** 2 スロットの実効値で週次余裕が `a < b` である
- **THEN** selector は `b` の `securestorage` を出力し、理由行に `a` と `b` の週次余裕を小数点以下 2 桁で含める

#### Scenario: 同点は宣言順で決める
- **WHEN** 利用可能な 2 スロットの週次余裕が等しい
- **THEN** selector は `accounts.json` で先に宣言されたスロットを選ぶ

#### Scenario: 使用量 API を叩かずにセッション記録だけで選ぶ
- **WHEN** usage snapshot が無く、A と B それぞれの鍵のセッション記録だけがあり、週次余裕が `a < b` である
- **THEN** selector は `b` の `securestorage` を出力し、理由行に `a` と `b` の週次余裕を含める

### Requirement: 古い・欠測・短期枠逼迫のスロットを候補から外す
自動選択は、取得からの経過時間でスロットを候補から外してはならない（MUST NOT）。古さの扱いは実効値の規則（リセット時刻を過ぎた窓は 0%、過ぎていなければ下限として使う）に従う。実効値の `weekly_all_pct`、`weekly_resets_epoch`、`five_hour_pct` のいずれかが欠測であるスロット、および実効値の `five_hour_pct >= 90` のスロットを候補から外さなければならない（SHALL）。理由行では欠測を `missing`、5 時間枠による除外を `five-hour>=90` と書く。候補が 1 つも無い場合は既定アカウントを表す空の `securestorage` を選ばなければならない（SHALL）。このとき、レジストリに既定スロット（`securestorage` が `null` または空文字）があれば宣言順で最初のスロットの id を `selected` に出し、無ければ登録 id では使用できない `@unregistered-default` を出さなければならない（SHALL）。`missing` による除外が 1 つでもあれば理由を `default-due-to-missing-usage`、全スロットが `five-hour>=90` だけで除外された場合は `default-due-to-five-hour-limit` としなければならない（SHALL）。

#### Scenario: 古いがリセット前の値で選ぶ
- **WHEN** 片方のスロットの値が 1 日前に取得され、リセット時刻がまだ来ておらず、もう片方より週次余裕が大きい
- **THEN** selector は古い方のスロットを候補に含め、週次余裕が大きい方として選ぶ

#### Scenario: リセット時刻を過ぎた値は 0% として比べる
- **WHEN** スロット `a` の値が週次 95%・リセット時刻が現在より前で、スロット `b` の値が週次 30%・リセット時刻が現在より後である
- **THEN** selector は `a` の週次を 0% として週次余裕を求め、`a` を候補に含める

#### Scenario: 全スロットが欠測のときは登録済み既定スロットへ縮退する
- **WHEN** id が `a` の既定スロットを含む全スロットで、セッション記録も snapshot の値も無い
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=a reason=default-due-to-missing-usage` と各スロットの `missing` を含める
- **AND** その値で起動したセッションでは環境変数が unset され、statusline の active も `a` になる

#### Scenario: 既定スロットが未登録なら sentinel を表示する
- **WHEN** 全スロットが明示的な非空の `securestorage` を持ち、かつ全スロットが欠測である
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=@unregistered-default reason=default-due-to-missing-usage` を含める
- **AND** `@unregistered-default` は実在する登録 id として扱われない

#### Scenario: 5 時間枠が 90 パーセントなら候補から外す
- **WHEN** 週次余裕が最大のスロットの実効値の `five_hour_pct` が 90 で、別のスロットが 90 未満である
- **THEN** selector は週次余裕が最大のスロットを候補から外し、別のスロットを選ぶ

#### Scenario: 全スロットの 5 時間枠が逼迫したときは原因を区別する
- **WHEN** 全スロットの実効値は欠測が無いが、`five_hour_pct` がすべて 90 以上である
- **THEN** selector は空の `securestorage` を出力し、理由行に `reason=default-due-to-five-hour-limit` と各スロットの `five-hour>=90` を含める
- **AND** 理由行に `reason=default-due-to-missing-usage` を含めない

#### Scenario: 選択に必要な値が欠測している
- **WHEN** スロットの実効値のうち選択に必要な 3 項目のいずれかが欠測である
- **THEN** selector はそのスロットを候補から外し、理由行に `missing` を含める

#### Scenario: 使用量 API が 429 を返し続けても記録で選ぶ
- **WHEN** usage-probe が全スロットで 429 を受けて snapshot を更新できず、A と B のセッション記録がある
- **THEN** selector は記録から求めた実効値で選び、理由行に `missing` を含めない
