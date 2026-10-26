## RENAMED Requirements

- FROM: `### Requirement: 起動アカウントを週次余裕から自動選択する`
- TO: `### Requirement: 起動アカウントを headroom の余りから自動選択する`

## MODIFIED Requirements

### Requirement: 起動アカウントを headroom の余りから自動選択する
`plugins/dev-workflow/scripts/select-account.sh` は、引数が無いときに `dev-workflow-headroom` capability の `headroom.compute(now)` を呼び、その `best_by_provider.claude` が指すスロットを選ばなければならない（SHALL）。`now` は環境変数 `SELECT_ACCOUNT_NOW` があればその値、無ければ現在時刻とする。`best`（provider をまたいだ最大）を選択に使ってはならない（MUST NOT。Codex を指すことがあるため）。余り（`surplus_pct`）の数え方・候補の条件・同点の決め方は headroom の要件「一番余っているアカウント（best）を選ぶ」に従い、`select-account.sh` は経過率と使用率から余裕や余りを数え直してはならない（MUST NOT）。`.headroom.json` を読んで選んではならない（MUST NOT。probe が書かなかった実行で古い計算を使わないため）。選択は起動時の 1 回だけであり、起動済みセッションのアカウントを変更してはならない（MUST NOT）。どのスロットを候補に通し、どれを落とすかの守備範囲は、要件「古い・欠測・短期枠逼迫のスロットを候補から外す」の守備範囲の段落に従う。

#### Scenario: リセット権を持つスロットを margin より余りで選ぶ
- **WHEN** 2 スロットのうち `a` は週次 10%・リセット権なし、`b` は週次 40%・次の週次リセットより前に切れるリセット権 1 枚を持ち、margin（週の経過率 − 使用率）では `a` が大きく、`surplus_pct` では `b` が大きい
- **THEN** selector は `b` の `securestorage` を出力し、理由行は `selected=b reason=max-surplus` と、`a` と `b` の margin を小数点以下 2 桁で含む

#### Scenario: Codex が一番余っていても Claude のスロットを選ぶ
- **WHEN** headroom の `best` が Codex の `current` を指し、`best_by_provider.claude` がスロット `a` を指す
- **THEN** selector は `a` の `securestorage` を出力する

#### Scenario: 同点は宣言順で決める
- **WHEN** 利用可能な 2 スロットの `surplus_pct` が等しい（どちらも 0 の場合を含む）
- **THEN** selector は `accounts.json` で先に宣言されたスロットを選ぶ

#### Scenario: 使用量 API を叩かずにセッション記録だけで選ぶ
- **WHEN** usage snapshot が無く、A と B それぞれの鍵のセッション記録だけがあり、`surplus_pct` が `a < b` である
- **THEN** selector は `b` の `securestorage` を出力し、理由行に `a` と `b` の margin を含める

### Requirement: 古い・欠測・短期枠逼迫のスロットを候補から外す
自動選択の候補の外し方は、headroom の行の `status` と best の除外規則（`dev-workflow-headroom` の要件「アカウントごとの項目と status」「一番余っているアカウント（best）を選ぶ」）に従わなければならず（SHALL）、`select-account.sh` で独自の検査を足してはならない（MUST NOT）。したがって、取得からの経過時間でスロットを外さず（古さは実効値の規則で扱う）、`status` が `off`・`missing`・`stale` のスロットと、`five_hour_pct` が 90 以上のスロットを外し、`five_hour_pct` が分からない（null）スロットは候補に残す。理由行では、オフを `off`、週次の値が読めないものを `missing`、週次の実効値の `observed_at`（`build_view` がそのスロットに選んだ値の取得時刻。snapshot の値が採用されれば snapshot の取得時刻、セッション記録が採用されればその記録の時刻）が今より 60 秒を超えて未来のものを `stale`、5 時間枠による除外を `five-hour>=90` と書く。候補が 1 つも無い場合は既定アカウントを表す空の `securestorage` を選ばなければならない（SHALL）。このとき、レジストリに既定スロット（`securestorage` が `null` または空文字）があれば宣言順で最初のスロットの id を `selected` に出し、無ければ登録 id では使用できない `@unregistered-default` を出さなければならない（SHALL）。このときの `selected` の決め方は `enabled` を見ない（縮退先は常に既定アカウントであり、`selected` はその起動先を指すスロットを報告するため）。理由は、オンのスロットが 1 つも無ければ `default-due-to-all-off`、オンのスロットに `missing` か `stale` による除外が 1 つでもあれば `default-due-to-missing-usage`、オンのスロットがすべて `five-hour>=90` だけで除外された場合は `default-due-to-five-hour-limit` としなければならない（SHALL）。headroom の設定（`HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY`）が不正で `compute` が例外を出したときも、同じ決め方で既定アカウントへ縮退し、理由を `default-due-to-invalid-headroom-setting`、`margins` を `-` として exit 0 で終わらなければならない（SHALL）。

**守備範囲（自動選択の候補の判定と、headroom の設定の不正の扱い）**: ①入力の出どころは、`headroom.compute(now)` が返す Claude のスロットの行（中身はレジストリ `accounts.json`、`build_view` が `.usage-snapshot` とステータスラインのセッション記録から作る週次と 5 時間の実効値、`.usage-snapshot` の `reset_grants`）と、`compute` が中で読む環境変数 `HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY` である。各行の `status`（`off`・`missing`・`stale`）を決める判定は `dev-workflow-headroom` の要件「アカウントごとの項目と status」の守備範囲が担い、`select-account.sh` が担うのは、その `status` と `five_hour_pct` を候補・理由行の印・縮退の理由に写すことと、設定の不正による例外を縮退に変えることだけである。Codex の行は選択に使わない。②拾いたい誤りは、使えないスロット（オフ・週次の値が読めない・週次の実効値の `observed_at` が今より 60 秒を超えて未来・5 時間の使用率が 90 以上）を選んでしまうことと、headroom の設定（数でない・0〜100 の外）の誤りで `cld` が Claude を起動できなくなることである。③通してよい入力は、取得から何日もたった値でリセット時刻がまだ先のもの、リセット時刻を過ぎた値（0% として数える）、リセット時刻が 7 日より先の値、`observed_at` が今より 60 秒以内の未来の値、`five_hour_pct` が分からない（null）スロット、`enabled` を書いていないスロット、空文字や未設定の `HEADROOM_*`（既定値で数える）である。値が実際の使用量より低い（取得後の使用を反映していない）ことは検知しない。④この判定は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: 古いがリセット前の値で選ぶ
- **WHEN** 片方のスロットの値が 1 日前に取得され、リセット時刻がまだ来ておらず、もう片方より `surplus_pct` が大きい
- **THEN** selector は古い方のスロットを候補に含め、`surplus_pct` が大きい方として選ぶ

#### Scenario: リセット時刻を過ぎた値は 0% として比べる
- **WHEN** スロット `a` の値が週次 95%・リセット時刻が現在より前で、スロット `b` の値が週次 30%・リセット時刻が現在より後である
- **THEN** selector は `a` の週次を 0% として数え、`a` を候補に含める

#### Scenario: 全スロットが欠測のときは登録済み既定スロットへ縮退する
- **WHEN** id が `a` の既定スロットを含む全スロットで、セッション記録も snapshot の値も無い
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=a reason=default-due-to-missing-usage` と各スロットの `missing` を含める
- **AND** その値で起動したセッションでは環境変数が unset され、statusline の active も `a` になる

#### Scenario: 既定スロットが未登録なら sentinel を表示する
- **WHEN** 全スロットが明示的な非空の `securestorage` を持ち、かつ全スロットが欠測である
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=@unregistered-default reason=default-due-to-missing-usage` を含める
- **AND** `@unregistered-default` は実在する登録 id として扱われない

#### Scenario: 5 時間枠が 90 パーセントなら候補から外す
- **WHEN** `surplus_pct` が最大のスロットの実効値の `five_hour_pct` が 90 で、別のスロットが 90 未満である
- **THEN** selector は `surplus_pct` が最大のスロットを候補から外し、別のスロットを選ぶ

#### Scenario: 全スロットの 5 時間枠が逼迫したときは原因を区別する
- **WHEN** 全スロットの実効値は欠測が無いが、`five_hour_pct` がすべて 90 以上である
- **THEN** selector は空の `securestorage` を出力し、理由行に `reason=default-due-to-five-hour-limit` と各スロットの `five-hour>=90` を含める
- **AND** 理由行に `reason=default-due-to-missing-usage` を含めない

#### Scenario: 週次の値が欠測している
- **WHEN** スロットの実効値の週次の使用率かリセット時刻が欠測である
- **THEN** selector はそのスロットを候補から外し、理由行に `missing` を含める

#### Scenario: 5 時間枠の値が分からないスロットは候補に残す
- **WHEN** スロット `a` の実効値の `five_hour_pct` が欠測で、週次の値は揃っている
- **THEN** selector は `a` を候補に含め、理由行の `a` の欄は margin の値になり `missing` にならない

#### Scenario: 取得時刻が 60 秒を超えて未来のスロットは外す
- **WHEN** スロット `b` の週次の実効値（`build_view` が選んだ値）の `observed_at` が現在より 61 秒先で、スロット `a` の値は現在の取得である
- **THEN** selector は `b` を候補から外し、理由行の `b` の欄を `stale` にする。`observed_at` が現在より 60 秒先なら外さない

#### Scenario: セッション記録が採用されたスロットは記録の時刻で未来を判定する
- **WHEN** スロット `b` の snapshot の取得時刻は現在より 120 秒先だが、`build_view` が `b` の週次の実効値に現在の時刻のセッション記録を採用する
- **THEN** selector は `b` を `stale` にせず候補に含める

#### Scenario: 使用量 API が 429 を返し続けても記録で選ぶ
- **WHEN** usage-probe が全スロットで 429 を受けて snapshot を更新できず、A と B のセッション記録がある
- **THEN** selector は記録から求めた実効値で選び、理由行に `missing` を含めない

#### Scenario: オフのスロットは余りが最大でも選ばない
- **WHEN** スロット `a` がオンで margin が 10、スロット `b` が `enabled: false` で実効値からは `a` より余る
- **THEN** selector は `a` の `securestorage` を出力し、理由行は `selected=a reason=max-surplus` と `margins=a:10.00,b:off` を含む

#### Scenario: enabled を書いていない登録簿では選択が変わらない
- **WHEN** どのスロットにも `enabled` が無い登録簿と、全スロットに `"enabled": true` を書いた同じ内容の登録簿を、同じセッション記録・snapshot で順に与える
- **THEN** 2 つの登録簿で stdout と理由行が一致する

#### Scenario: 全スロットがオフなら既定アカウントへ縮退する
- **WHEN** id が `a` の既定スロットを含む全スロットが `enabled: false` である
- **THEN** selector は空の `securestorage` を出力して exit 0 で終わり、理由行は `selected=a reason=default-due-to-all-off` と各スロットの `off` を含む

#### Scenario: オンのスロットが欠測でオフのスロットに値があるとき
- **WHEN** 既定スロット `a` がオンで欠測、スロット `b` が `enabled: false` で実効値が揃っている
- **THEN** selector は `b` を選ばず、空の `securestorage` を出力し、理由行は `selected=a reason=default-due-to-missing-usage` と `margins=a:missing,b:off` を含む

#### Scenario: headroom の設定が不正なら既定アカウントで起動させる
- **WHEN** `HEADROOM_7D_CAP_PCT` が `abc` で、id が `a` の既定スロットがある
- **THEN** selector は空の `securestorage` を出力して exit 0 で終わり、理由行は `selected=a reason=default-due-to-invalid-headroom-setting margins=-` になる

### Requirement: 値と選択理由を別の出力ストリームで返す
成功時の selector は stdout に選んだ `securestorage` の実値だけを改行付きで出さなければならない（SHALL）。既定アカウントの stdout は空行とする。stderr には `selected=<id-or-sentinel> reason=<reason> margins=<entries>` の 1 行だけを出さなければならない（SHALL）。`selected` は選んだ登録スロットの実 id とし、登録されていない既定アカウントへの縮退だけは `@unregistered-default` とする。自動選択の `margins` は全登録スロットを宣言順に含み、候補は headroom の行の `margin`（週の経過率 − 使用率。選択には使わない）を小数点以下 2 桁、候補外は `missing`、`stale`、`five-hour>=90`、`off` のいずれかで示さなければならない（SHALL）。オフのスロットも `margins` から省いてはならない（MUST NOT）。省くと、登録したはずのスロットが選ばれない理由を理由行から読めなくなる。

#### Scenario: shell は stdout だけを値として取り込める
- **WHEN** 自動選択の stdout を command substitution で取得し、stderr を端末へ残す
- **THEN** 変数には `securestorage` の実値だけが入り、選択 id・理由・全スロットの比較は stderr の 1 行で確認できる

#### Scenario: 明示選択の理由を示す
- **WHEN** 登録済み id を明示して選ぶ
- **THEN** stderr は `reason=explicit` と `margins=-` を含む

#### Scenario: オフのスロットも margins に並ぶ
- **WHEN** 2 番目のスロットが `enabled: false` の登録簿で自動選択する
- **THEN** stderr の `margins` は宣言順に 2 スロットを含み、2 番目は `<id>:off` である

#### Scenario: margins は headroom の margin を出す
- **WHEN** 週次リセットが 7 日より先のスロットを含めて自動選択する
- **THEN** そのスロットの `margins` の値は headroom の行の `margin`（経過率を 0〜100 に切り詰めない値）と小数点以下 2 桁で一致する
