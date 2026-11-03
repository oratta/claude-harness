## ADDED Requirements

### Requirement: 余りの計算を headroom.py の 1 か所に置く
dev-workflow プラグインは `plugins/dev-workflow/scripts/headroom.py` を配布し、Claude の各スロットと Codex の `current` account について「いつまでに、どれだけ余るか」を数える計算をこのファイルだけに置かなければならない（SHALL）。関数 `compute(now)` は引数 `now`（epoch 秒）だけを取り、`schema`・`computed_at`・`settings`・`best`・`best_by_provider`・`accounts` を持つ辞書を返さなければならない（SHALL）。`compute` はファイルを書かず、Codex の使用量を取得してはならない（MUST NOT）。

入力は次の 3 つに限る（SHALL）: Claude の各スロットの実効値（`usage_view.build_view` と、オン・オフを `usage_view.read_slots`）、Claude のリセット権（`.usage-snapshot` の `accounts.<id>.reset_grants`）、Codex の `current` account の使用量とリセット権（`codex-develop.py` が書く `codex-usage/<hash>.json`）。Codex のオン・オフ（`codex.enabled`）は `usage_view.read_codex_enabled` 経由で読まなければならない（SHALL。レジストリの読み手を増やさない）。`.statusline-codex` を入力にしてはならない（MUST NOT）。

headroom が見る Codex の account は、`codex-develop.py` の自動選択の既定の対応（`CODEX_HOME`、未設定なら `~/.codex` が既存の絶対ディレクトリのときの `current`）だけでなければならない（SHALL）。

#### Scenario: compute は now だけを取る
- **WHEN** `compute` の引数を調べる
- **THEN** `now` 以外の引数（天井・ペース・入力のパス）を持たない

#### Scenario: Codex の既定 home が無い
- **WHEN** `CODEX_HOME` が未設定で `~/.codex` が存在しない
- **THEN** `accounts` に Codex の行を出さず、Claude の行だけを数える

### Requirement: Claude はリセット権 1 枚ごとに使える量を足す
headroom は Claude の各スロットについて、次の週次リセットより前に切れるリセット権（失効が `now` より後かつ週次リセットより前のもの。停止中・残り 0 を除く）を数え、その枚数を `rocket.count` に、最短の失効を `rocket.earliest_expiry` に出さなければならない（SHALL。無ければ `rocket` は null）。`capacity_pct` は `100 + 100 × rocket.count`、`left_pct` は `(100 − used_pct) + 100 × rocket.count` でなければならない（SHALL）。`deadline_at` は週次リセット、`deadline_reason` は `weekly_reset` でなければならない（SHALL）。

`surplus_pct` は flatmate の `account_allocation.py` の `evaluate_accounts` と同じ数え方でなければならない（SHALL）: 最初に切れる数えるリセット権の失効（無ければ週次リセット）までの区間の余り `max(0, to_cap − rate × 区間の時間)` に、数えるリセット権 1 枚ごとに天井の値を足す。`to_cap = (100 − used_pct) − (100 − 天井)`、`rate` は通常の消費ペースの上書きがあればそれ、無ければ `used_pct ÷ max(週の経過時間, 24 時間)`。

枚数は束ごとの `resets_left` の和で数えなければならない（SHALL。`resets_left: 2` の束は 2 枚）。`ends_at` が null の束は `tickets.count` に入れ、失効が分からないので `rocket` には入れない（SHALL）。

`reset_grants` の欄が無い・形が読めないときは、リセット権 0 枚と同じ数を出し、`tickets` を null にしなければならない（SHALL）。

#### Scenario: リセット権の枚数で使える量が変わる
- **WHEN** 週次の使用率 40%・週次リセットまで 24 時間の Claude のスロットに、リセット権が無い／12 時間後に切れる 1 枚／6 時間後と 12 時間後に切れる 2 枚／30 時間後に切れる 1 枚、の snapshot を入れる
- **THEN** `capacity_pct` が順に 100・200・300・100、`rocket.count` が順に null（`rocket` 自体が null）・1・2・null になる

#### Scenario: flatmate と同じ余りを出す
- **WHEN** flatmate の `test_account_allocation.py` の `Surplus` と `TicketSurplus` の Claude のケースと同じ使用率・週次リセット・リセット権・天井・ペースを入れる
- **THEN** `surplus_pct` が同じ値になる（例: 使用率 40%・残り 24 時間・リセット権なしで 43.3、12 時間後に切れる 1 枚で 136.7、6 時間後と 12 時間後で 228.3）

### Requirement: Codex はリセット権の失効を期限にする
headroom は Codex の `current` account について、リセット権で使える量を足してはならない（MUST NOT。`capacity_pct` は 100、`left_pct` は `100 − used_pct`）。次の週次リセットより前に切れるリセット権があれば、`deadline_at` をその最短の失効、`deadline_reason` を `ticket_expiry` にし、`elapsed_pct` を週の始まり（週次リセットの 7 日前）から期限までに対する経過率にしなければならない（SHALL）。無ければ `deadline_at` は週次リセット、`deadline_reason` は `weekly_reset` でなければならない（SHALL）。`surplus_pct` は `max(0, to_cap − rate × (deadline_at − now) / 3600)` でなければならない（SHALL）。キャッシュに `resets` が無いときは、リセット権 0 枚と同じ数を出し、`tickets` を null にしなければならない（SHALL）。Codex の `tickets.count` は `resets.available_count` から、`resets.expires_at` のうち整数で `now` 以前のもの（取得後に失効したリセット権）の数を引いた値（0 未満にしない）、`tickets.earliest_expiry` と `rocket` は `resets.expires_at` のうち整数で `now` より後のものから数えなければならない（SHALL。null の失効は `rocket` に入れない）。

Codex の週次の使用率は `codex-develop.py` の `usage_margin` と同じ規則で読まなければならない（SHALL）: 7 日窓（`minutes` が 10080）を使い、リセットを過ぎた値は 0% として読んでリセットを週単位で先へ送り、取得時刻の古さでは外さない。ただし未来の取得時刻の扱いは要件「アカウントごとの項目と status」の 60 秒の規則を正とし、`usage_margin` の「1 秒でも未来なら使わない」判定は写さない（#1301 で `usage_margin` を headroom に寄せるときに揃う）。

#### Scenario: リセット権が週次リセットより前に切れる
- **WHEN** 週次の使用率 40%・週次リセットまで 24 時間の Codex の account のキャッシュに、6 時間後に切れるリセット権 1 枚がある
- **THEN** `capacity_pct` が 100、`deadline_reason` が `ticket_expiry`、`deadline_at` がそのリセット権の失効時刻、`surplus_pct` が flatmate と同じ 48.3 になる

#### Scenario: 週次リセットより後に切れるリセット権は期限を変えない
- **WHEN** Codex の account のリセット権が週次リセットより後に切れる
- **THEN** `deadline_reason` が `weekly_reset`、`rocket` が null、`surplus_pct` がリセット権の無いときと同じになる

### Requirement: 設定は headroom の中で 1 か所から解決する
headroom は天井 `HEADROOM_7D_CAP_PCT`（既定 90、0 以上 100 以下）と通常の消費ペースの上書き `HEADROOM_NORMAL_RATE_PCT_PER_DAY`（既定なし、0 以上 100 以下。%/日）を `compute` の中で環境変数から読み、解決した値を出力の `settings`（`cap_7d_pct`・`normal_rate_pct_per_day`）に載せなければならない（SHALL）。呼び手が天井やペースを渡す引数・CLI オプションを持ってはならない（MUST NOT）。値が数でない・範囲外のときは既定値に倒さず、`compute` は例外を出し、CLI は終了コード 2 で何も書かず、標準出力に何も出さない（SHALL。理由は標準エラーに出す）。

#### Scenario: 天井を変えると余りと best が変わる
- **WHEN** 2 つの Claude のスロットのうち、`HEADROOM_7D_CAP_PCT` が既定のときは一方が、下げたときは他方が `surplus_pct` 最大になる snapshot を入れて、天井を変えて 2 回数える
- **THEN** `surplus_pct` と `best` が天井に応じて変わり、`settings.cap_7d_pct` が使った値になる

#### Scenario: 天井を呼び手から渡せない
- **WHEN** `headroom.py --json --cap 80` のように天井を引数で渡す
- **THEN** 終了コード 2 で拒否し、標準出力に何も出さない（理由は標準エラーに出す）

#### Scenario: 不正な設定値
- **WHEN** `HEADROOM_7D_CAP_PCT` が `abc` か `120`
- **THEN** `headroom.py write` は終了コード 2 で `.headroom.json` を書かない

### Requirement: アカウントごとの項目と status
`accounts` の各行は `provider`・`account`・`label`・`status`・`observed_at`・`five_hour_pct`・`used_pct`・`elapsed_pct`・`weekly_reset_at`・`rocket`・`tickets`・`capacity_pct`・`left_pct`・`deadline_at`・`deadline_reason`・`forecast`・`surplus_pct`・`margin` のキーを必ず持たなければならない（SHALL。値が分からないときは null）。並びは Claude（レジストリの宣言順）→ Codex でなければならない（SHALL）。数は丸めずに出す（SHALL）。

`status` は次の 4 つのどれかでなければならない（SHALL）:
- `ok`: 週次の実効値（使用率とリセット時刻）が読める。取得の古さと、リセットを過ぎて 0% に読み替えたことでは `ok` から外さない
- `stale`: 週次の値はあるが、取得時刻が今より 60 秒を超えて未来。`observed_at`・`five_hour_pct`・`used_pct`・`elapsed_pct`・`weekly_reset_at` は出し、余りの項目（`rocket` から `margin` まで）は null
- `missing`: 週次の値が読めない。数の項目は null
- `off`: レジストリでオフ（Claude はスロットの `enabled: false`、Codex はレジストリの `codex.enabled: false`）。数の項目は null で、Codex の取得もしない

`tickets` は持っているリセット権（停止中・残り 0・失効済みを除く）の `{count, earliest_expiry}`、`margin` は `週次の経過率 − used_pct`（期限ではなく週次で測る）、`forecast` は期限までに通常のペースで使った見込み `left_pct − rate × 期限までの時間` が 0 以上なら `{kind: "spare", pct}`、負なら `{kind: "exhaust", at}`（尽きる見込みの epoch 秒）でなければならない（SHALL）。

`observed_at` は、Claude では `usage_view.build_view` の `observed_at`、Codex ではキャッシュの `fetched_at` でなければならない（SHALL）。`five_hour_pct` は、Claude では `build_view` の `five_hour_pct`（実効値。リセット後は 0、無ければ null）、Codex ではキャッシュの `minutes` が 300 の窓の `used_percent`（`reset_at` を過ぎていれば 0、窓が無ければ null）でなければならない（SHALL）。`used_pct`・`elapsed_pct`・`weekly_reset_at`・`capacity_pct`・`left_pct`・`deadline_at`・`deadline_reason` の定義は、この要件と上の Claude・Codex の要件に書いたもののほか、design.md の決定 3 の表を正本とする。

**守備範囲**: 入力は、レジストリ `accounts.json`、`.usage-snapshot`（`reset_grants` を含む）、ステータスラインのセッション記録（`build_view` 経由）、Codex のキャッシュ `codex-usage/<hash>.json`、環境変数 `HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY` だけである。拾いたい誤りは、数でない・0〜100 の外の設定値（例外。CLI は終了コード 2）、形が読めない `reset_grants`・`resets`（リセット権 0 枚として数え `tickets` を null）、週次の値が読めない行（`missing`）、今より 60 秒を超えて未来の取得時刻（`stale`）である。通してよい入力は、取得から何日もたった値、週次リセットを過ぎて 0% に読み替えた値、`ends_at` が null の束、入力の中の未知のキー、今より 60 秒以内の未来の取得時刻（時計の小さなずれ）である。この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: 古い取得値も ok で数える
- **WHEN** 非 active の Claude のスロットの snapshot の値が 2 日前の取得で、週次リセットはまだ先
- **THEN** そのスロットは `status: ok` で、前回の使用率を下限として数える

#### Scenario: オフのスロット
- **WHEN** レジストリでスロット b が `enabled: false`
- **THEN** b の行は `status: off` で数の項目が null になり、`best` の候補にならない

### Requirement: 一番余っているアカウント（best）を選ぶ
`best` は、`status` が `ok` で `surplus_pct` が数で、5 時間の使用率が 90% 未満（分からないときは候補に残す）のアカウントのうち、`surplus_pct` が最大のものの `{provider, account}` でなければならない（SHALL。候補が無ければ null）。同点は Claude を Codex より先に、同じ provider の中は宣言順で先のものを選ばなければならない（SHALL）。`best_by_provider` は `claude`・`codex` のキーを持ち、それぞれ同じ規則をその provider の中だけで当てた結果でなければならない（SHALL）。

#### Scenario: 5 時間の使用率が高いアカウントは外す
- **WHEN** `surplus_pct` 最大の Claude のスロットの 5 時間の使用率が 92%
- **THEN** `best` はそのスロットではなく、次に `surplus_pct` が大きい候補になる

#### Scenario: Codex が一番余るときも Claude の最大を出す
- **WHEN** Codex の `current` の `surplus_pct` が全 Claude のスロットより大きい
- **THEN** `best` は Codex の `current`、`best_by_provider.claude` は Claude のスロットの中の最大になる

### Requirement: .headroom.json を schema 1 で書く
`headroom.py write` は `compute(now)` の結果を `${CLAUDE_CONFIG_DIR:-~/.claude}/.headroom.json` に、同じディレクトリの一時ファイルへ書いてから rename で置き換えなければならない（SHALL）。トップレベルは `schema`（整数 1）・`computed_at`（epoch 秒）・`settings`・`best`・`best_by_provider`・`accounts` でなければならない（SHALL）。キーを消す・意味を変えるときは `schema` を上げなければならない（MUST。キーを足すだけなら上げない）。`--refresh-codex` を付けたときは、書く前に `codex-develop.py` の `read_codex_usages` で Codex の使用量を取り直さなければならない（SHALL。Codex がオフ・既定の home が無いときは取り直さない）。`headroom.py --json` は書かずに同じ内容を標準出力に 1 行で出す（SHALL）。

#### Scenario: 書き込みは原子的
- **WHEN** `headroom.py write` を走らせる
- **THEN** `.headroom.json` は前の内容か新しい内容のどちらかで、途中まで書かれた状態にならない

### Requirement: usage-probe が snapshot を書いた直後に headroom を書く
`usage-probe.sh` は `.usage-snapshot` の置き換えに成功した直後に、同じディレクトリの `headroom.py write --refresh-codex` を呼ばなければならない（SHALL）。headroom の出力と終了コードを probe の結果に伝えてはならない（MUST NOT。probe は今までどおり終了コード 0 で終わる）。呼ぶかどうかは snapshot を書いたかどうかだけで決め（SHALL。全スロットが失敗しても `reset_grants` を除くために snapshot を書き直す既存の経路では呼ぶ）、テスト経路（`USAGE_PROBE_RESPONSE_FILE` か `USAGE_PROBE_RESPONSE_FILE_<ID>` を設定した実行）ではそれに加えて `USAGE_PROBE_HEADROOM` が空でないときだけ呼び（SHALL。それを設定しないテストが本物の `~/.claude/.headroom.json` と `~/.codex` の cache に触れないため）、snapshot を書かなかった実行（全スロットの失敗で書き直す欄も無かったとき・取得の間隔内・ロックを取れない）では headroom を呼んではならない（MUST NOT）。

#### Scenario: probe のあとに .headroom.json ができる
- **WHEN** テスト用の応答ファイルで `usage-probe.sh` を走らせ、snapshot が書かれる（Codex はオフか既定の home が無い）
- **THEN** `${CLAUDE_CONFIG_DIR}/.headroom.json` が `schema: 1` で書かれ、Claude のスロットの行が `status: ok` で並ぶ

#### Scenario: headroom が失敗しても probe は成功する
- **WHEN** `HEADROOM_7D_CAP_PCT` が不正な値で `usage-probe.sh` を走らせる
- **THEN** snapshot は書かれ、probe は終了コード 0 で終わり、`.headroom.json` は書かれない
