## MODIFIED Requirements

### Requirement: 余りの計算を headroom.py の 1 か所に置く
dev-workflow プラグインは `plugins/dev-workflow/scripts/headroom.py` を配布し、Claude の各スロットと Codex の account について「いつまでに、どれだけ余るか」を数える計算をこのファイルだけに置かなければならない（SHALL）。関数 `compute(now)` は引数 `now`（epoch 秒）だけを取り、`schema`・`computed_at`・`settings`・`best`・`best_by_provider`・`accounts` を持つ辞書を返さなければならない（SHALL）。`compute` はファイルを書かず、Codex の使用量を取得してはならない（MUST NOT）。

`compute` が読み込む入力は次の 3 つに限る（SHALL）: Claude の各スロットの実効値（`usage_view.build_view` と、オン・オフを `usage_view.read_slots`）、Claude のリセット権（`.usage-snapshot` の `accounts.<id>.reset_grants`）、Codex の `current` account の使用量とリセット権（`codex-develop.py` が書く `codex-usage/<hash>.json`）。Codex のオン・オフ（`codex.enabled`）は `usage_view.read_codex_enabled` 経由で読まなければならない（SHALL。レジストリの読み手を増やさない）。`.statusline-codex` を入力にしてはならない（MUST NOT）。

`compute` が列挙し、キャッシュのファイルを読む Codex の account は、`codex-develop.py` の自動選択の既定の対応（`CODEX_HOME`、未設定なら `~/.codex` が既存の絶対ディレクトリのときの `current`）だけでなければならない（SHALL）。`compute` がその cache を行に使うのは、Codex がオン（`codex.enabled` が `false` でない）で、cache の認証の主体（`identity`）がその home の主体と一致したときだけで、それ以外は `current` の行を `off` か `missing` にする。この `current` だけの限定は `compute` の列挙とファイルの読み込みにかかるもので、下の公開関数 `codex_row` にはかからない（`codex_row` は呼び手が主体を照合済みの任意の account の cache を受ける）。

headroom は、`compute` 以外の読む側（`codex-develop.py` の構成選択）が同じ数え方の行を得るために、行を返す公開関数を 2 つ持たなければならない（SHALL）。`compute` の行もこの 2 つから作り、同じ入力なら `compute` の `accounts` の行と一致しなければならない（SHALL）。

- `claude_rows(now, snapshot_path=None)`: Claude の各スロットの行をレジストリの宣言順に返す。`snapshot_path` を渡したときは、実効値（`build_view`）とリセット権の読み出しにそのファイルを使い、渡さないときは `compute` と同じ既定（`usage_view.default_paths`）を使う
- `codex_row(account, cache, now)`: 読み込み済みの Codex の cache 1 件（`read_codex_usages` の戻り値の値。`None` や形の合わない値も受ける）から、`provider` が `codex`・`account` が引数の名前の行を返す。`account` は `current` に限らず、呼び手が渡した任意の名前を受ける。認証の主体の照合と Codex のオン・オフの判定はしない（呼び手が済ませる。`codex-develop.py` では `read_codex_usages` が主体の食い違う cache を `None` にし、オフのときは呼ばない）。週次の値が読めないときは `status: missing` の行を返す

どちらの関数も天井とペースを引数で受けてはならず（MUST NOT）、要件「設定は headroom の中で 1 か所から解決する」の設定を中で読む（設定が不正なら `compute` と同じ例外を出す）。

**守備範囲（公開関数 `claude_rows`・`codex_row` が行の `status` を決める判定）**: ①入力の出どころは、`claude_rows` では `snapshot_path`（無ければ既定の `.usage-snapshot`）・レジストリ・ステータスラインのセッション記録から `build_view` が作る Claude の実効値とリセット権、`codex_row` では呼び手が渡す cache 1 件（`codex-develop.py` の `read_codex_usages` の値。cache ファイルの破損や手書きで形が崩れていることがある）、両方に共通して環境変数 `HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY` である。認証の主体の食い違いとオン・オフは呼び手の責任で、ここでは拾わない。②拾いたい誤りは、`None`・辞書でない cache・`fetched_at` やリセット時刻が整数でない・週次の使用率が有限の 0〜100 でない・週次窓（`minutes` が 10080）が無い値（`status: missing`）、週次の実効値の `observed_at`（Codex は `fetched_at`）が今より 60 秒を超えて未来の値（`status: stale`）、数でない・0〜100 の外の設定値（`compute` と同じ例外）である。③通してよい入力は、取得から何日もたった値でリセット時刻がまだ先のもの（下限として数える）、リセット時刻を過ぎた値（0% に読み替える）、リセット時刻が 7 日より先の値（`margin` が負になるだけ）、今より 60 秒以内の未来の取得時刻、5 時間窓が無い cache（`five_hour_pct` が null）、`resets` の無い cache、入力の中の未知のキー、`current` 以外の account 名である。④この判定は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: compute は now だけを取る
- **WHEN** `compute` の引数を調べる
- **THEN** `now` 以外の引数（天井・ペース・入力のパス）を持たない

#### Scenario: Codex の既定 home が無い
- **WHEN** `CODEX_HOME` が未設定で `~/.codex` が存在しない
- **THEN** `accounts` に Codex の行を出さず、Claude の行だけを数える

#### Scenario: 公開関数の行は compute の行と一致する
- **WHEN** Codex がオンで、既定の home（`CODEX_HOME`）が実在する絶対ディレクトリであり、その `current` の cache の認証の主体が home の主体と一致する（`compute` がその cache を行に使う）状態で、同じ snapshot・レジストリ・cache について `compute(now)` と、`claude_rows(now)` と `codex_row('current', <その cache>, now)` を呼ぶ
- **THEN** Claude の行と Codex の行がそれぞれ `compute` の `accounts` の行と一致する

#### Scenario: codex_row は current 以外の account も数える
- **WHEN** `codex_row('work', <週次窓の揃った cache>, now)` を呼ぶ
- **THEN** `provider` が `codex`・`account` が `work` の `status: ok` の行を返し、`margin` と `surplus_pct` は同じ cache を `current` として数えた行と同じ値になる

#### Scenario: codex_row は形の崩れた cache を missing にする
- **WHEN** `codex_row` に `None`、辞書でない値、週次窓の無い cache を順に渡す
- **THEN** どれも例外を出さず `status: missing` の行を返す

#### Scenario: codex_row は 60 秒を超えて未来の取得時刻を stale にする
- **WHEN** `fetched_at` が現在より 60 秒後・61 秒後の cache を `codex_row` に渡す
- **THEN** 60 秒後は `status: ok`、61 秒後は `status: stale` の行になる

#### Scenario: 公開関数は天井を受けない
- **WHEN** `claude_rows` と `codex_row` の引数を調べる
- **THEN** 天井・ペースの引数を持たない

### Requirement: Codex はリセット権の失効を期限にする
headroom は Codex の account（`compute` では `current`、`codex_row` では呼び手が渡した account）について、リセット権で使える量を足してはならない（MUST NOT。`capacity_pct` は 100、`left_pct` は `100 − used_pct`）。次の週次リセットより前に切れるリセット権があれば、`deadline_at` をその最短の失効、`deadline_reason` を `ticket_expiry` にし、`elapsed_pct` を週の始まり（週次リセットの 7 日前）から期限までに対する経過率にしなければならない（SHALL）。無ければ `deadline_at` は週次リセット、`deadline_reason` は `weekly_reset` でなければならない（SHALL）。`surplus_pct` は `max(0, to_cap − rate × (deadline_at − now) / 3600)` でなければならない（SHALL）。キャッシュに `resets` が無いときは、リセット権 0 枚と同じ数を出し、`tickets` を null にしなければならない（SHALL）。Codex の `tickets.count` は `resets.available_count` から、`resets.expires_at` のうち整数で `now` 以前のもの（取得後に失効したリセット権）の数を引いた値（0 未満にしない）、`tickets.earliest_expiry` と `rocket` は `resets.expires_at` のうち整数で `now` より後のものから数えなければならない（SHALL。null の失効は `rocket` に入れない）。

Codex の週次の使用率は次の規則で読まなければならない（SHALL）: 7 日窓（`minutes` が 10080）を使い、リセットを過ぎた値は 0% として読んでリセットを週単位で先へ送り、取得時刻の古さでは外さない。未来の取得時刻の扱いは要件「アカウントごとの項目と status」の 60 秒の規則に従う。`codex-develop.py` の構成選択はこの規則で数えた行の `margin` を使う（`codex-role-profiles` capability）。

#### Scenario: リセット権が週次リセットより前に切れる
- **WHEN** 週次の使用率 40%・週次リセットまで 24 時間の Codex の account のキャッシュに、6 時間後に切れるリセット権 1 枚がある
- **THEN** `capacity_pct` が 100、`deadline_reason` が `ticket_expiry`、`deadline_at` がそのリセット権の失効時刻、`surplus_pct` が flatmate と同じ 48.3 になる

#### Scenario: 週次リセットより後に切れるリセット権は期限を変えない
- **WHEN** Codex の account のリセット権が週次リセットより後に切れる
- **THEN** `deadline_reason` が `weekly_reset`、`rocket` が null、`surplus_pct` がリセット権の無いときと同じになる
