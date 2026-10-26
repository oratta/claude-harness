## Context

#1300（change `add-headroom-calculation`）で余りの計算を `plugins/dev-workflow/scripts/headroom.py` に置いた。`compute(now)` は Claude の各スロットと Codex の `current` account の行（`status`・`used_pct`・`surplus_pct`・`margin` など）と、`best`（全体で `surplus_pct` 最大）・`best_by_provider`（provider ごとの最大）を返す。`.headroom.json` はその結果を usage-probe の直後に書いたもの。

まだ自分で数えている読む側が 2 つある。

| 読む側 | 今の数え方 | 今の候補の外し方 |
|---|---|---|
| `select-account.sh`（`cld`） | margin = clamp(週の経過率) − 週次の使用率、最大を選ぶ | オフ・週次か 5 時間の使用率かリセット時刻が無い（`missing`）・5 時間 90% 以上 |
| `codex-develop.py` の `claude_usage_evidence` | 起動アカウントの margin（経過率は clamp しない） | 週次の使用率かリセット時刻が無い |
| `codex-develop.py` の `usage_margin` | Codex の account ごとの margin | 取得時刻が 1 秒でも未来・週次窓が無い・値が範囲外 |

headroom の行の `margin` は `週の経過率（clamp しない） − used_pct` で、`codex-develop.py` の 2 つと同じ式。`select-account.sh` だけ経過率を 0〜100 に clamp している（リセットが 7 日より先のときだけ違いが出る）。

設計の正本 genetta-inc/flatmate#1711 の設計のコメントで、`cld` は `headroom.compute().best` を選び（今の margin 最大をやめる）、develop の構成選択は規則（margin ≥ 0）を残して margin を headroom から取る、と決めた。

## Goals / Non-Goals

**Goals:**

- `select-account.sh` が、ステータスラインが示す Claude の一番余っているアカウントと同じ計算から選ぶ
- `select-account.sh` と `codex-develop.py` から、経過率と使用率で margin を数える式を消す
- 今の `test_codex_develop.py` の構成選択のテスト（`select_configuration` の表、`build_request` を通る受け入れのケース、Codex の代表 account の選び方、Codex がオフのとき）を変えずに通す

**Non-Goals:**

- headroom の数え方・`best` の規則・`.headroom.json` の書式を変えること（flatmate のバーン genetta-inc/flatmate#1772 が同じ値を読むため）
- 構成選択の規則（margin ≥ 0 の表）を余り（`surplus_pct`）に変えること。正本の設計が規則を残すと決めている
- headroom の `compute` が複数の Codex account を数えること（`current` だけのまま）

## Decisions

### 1. `select-account.sh` は `best` ではなく `best_by_provider.claude` を読む

`cld` が選ぶのは Claude のアカウントなので、Codex が全体で一番余っていると `best` は Codex を指し、`cld` には使えない。`best_by_provider.claude` は `best` と同じ規則（`status` が `ok`・`surplus_pct` が数・5 時間 90% 未満か不明、`surplus_pct` 最大、同点は宣言順）を Claude の行だけに当てたもので、Codex が一番余っていないときは `best` と一致する。正本の「`compute().best` を選ぶ」はこの意味で読む。

- 代わりの案: `best` が Claude のときだけ使い、Codex のときは独自に Claude の最大を探す → `best_by_provider.claude` と同じことを数え直すことになるので採らない

### 2. `.headroom.json` を読まず、`compute(now)` をその場で呼ぶ

`select-account.sh` はこれまでどおり `python3` のヒアドキュメントの中で `headroom.compute(now)` を呼ぶ。`now` は `SELECT_ACCOUNT_NOW`（テスト用）か現在時刻。

- 代わりの案: `.headroom.json` を読む → `cld` は先に usage-probe を走らせるが、probe は取得の間隔内・ロックを取れないときに snapshot も `.headroom.json` も書かない。そのときファイルは前回の計算時刻のままで、その後のセッション記録（statusline が書く）を反映しない。その場で数えれば `usage_view.build_view` がセッション記録まで読む。ステータスラインと同じ時刻の同じ入力なら同じ結果になる

### 3. 候補の外し方を headroom に寄せる（5 時間の使用率が不明なスロットは候補に残す）

`select-account.sh` は独自の検査を持たず、headroom の行の `status` と best の除外規則をそのまま使う。理由行の `margins=` には、スロットごとに次の印を出す。

| headroom の行 | 印 |
|---|---|
| `status: off` | `off` |
| `status: missing` | `missing` |
| `status: stale`（取得時刻が今より 60 秒を超えて未来） | `stale` |
| `status: ok` で `five_hour_pct` が 90 以上 | `five-hour>=90` |
| `status: ok` でそれ以外 | 行の `margin` を小数点以下 2 桁 |

候補が無いときの縮退の理由は今の規則を保つ: オンのスロットが無ければ `default-due-to-all-off`、オンのスロットに `missing` か `stale` が 1 つでもあれば `default-due-to-missing-usage`、それ以外（全部 `five-hour>=90`）は `default-due-to-five-hour-limit`。`stale` を `missing` と同じ理由にまとめるのは、どちらも「使用量が読めないので選べない」で、利用者がすること（probe を待つ・時計を見る）が理由行の印で分かれば足りるため。

今は 5 時間の使用率が分からないスロットを `missing` として外していた。headroom の best は不明を候補に残すので、それに揃える。`cld` は起動時に 1 回選ぶだけで、5 時間の枠が詰まっていれば次の起動で外れる。

- 代わりの案: `select-account.sh` だけ 5 時間の不明を外し続ける → `cld` とステータスラインの一番余っているアカウントが、5 時間の使用率が分からないときだけ食い違う。食い違いを無くすのがこの change の目的なので採らない

### 4. 理由を `max-surplus` にする

選ぶ基準が margin から余りに変わるので、`reason=max-weekly-margin` を `reason=max-surplus` にする。理由行を機械で読んでいるのはテスト（`account-selector.bats`）だけで、README の `cld` 関数は stdout だけを使う。

### 5. headroom に行を返す公開関数を 2 つ足し、`codex-develop.py` はそこから margin を取る

`codex-develop.py` の構成選択は、Claude の起動アカウント 1 つと、`--account-home` で渡された複数の Codex account を見る。`compute(now)` はこのどちらにも合わない（Claude は全スロット、Codex は `current` だけ）。また `codex-develop.py` は snapshot の既定のパスを `${CLAUDE_CONFIG_DIR}/.usage-snapshot` とし、headroom（`usage_view.default_paths`）は `~/.claude/.usage-snapshot` とするので、`compute` を呼ぶと別のファイルを読むことがある。

そこで headroom に次の 2 つを足し、`compute` もこれを使う形にする（`compute` の出力は変えない）。

- `claude_rows(now, snapshot_path=None)`: Claude の各スロットの行を宣言順に返す。`snapshot_path` を渡すと `build_view` とリセット権の読み出しにそのファイルを使い、渡さなければ今の `compute` と同じ既定を使う
- `codex_row(account, cache, now)`: 読み込み済みの Codex のキャッシュ（`read_codex_usages` の戻り値の 1 件。`None` も受ける）から 1 行を返す。認証の主体の照合はしない（`read_codex_usages` が済ませている）。`compute` の Codex の行は、今どおりファイルを読んで主体を照合してから `codex_row('current', cache, now)` を呼ぶ

天井とペースはどちらの関数も中で `settings()` から読み、引数で受けない（要件「設定は headroom の中で 1 か所から解決する」を保つ）。

`codex-develop.py` の 2 つの関数は、名前と戻り値の形を残して中身を置き換える。

- `claude_usage_evidence(snapshot_path, now)`: 起動アカウントの id は今どおり `usage_view.build_view(snapshot_path=…)` の `active` で決め、`headroom.claude_rows(now, snapshot_path)` のその id の行が `status: ok` なら `margin`、そうでなければ `None`。`fetched_at` は行の `observed_at`
- `usage_margin(snapshot, now)`: `headroom.codex_row('codex', snapshot, now)` が `status: ok` なら `margin`、そうでなければ `None`

`automatic_selection`・`select_configuration`・代表 Codex account の選び方（margin 最大・同点は宣言順）は変えない。名前を残すのは、テストと記録が使う語（Claude margin・Codex margin・`usage_margin`）を変えずに、構成選択のテストをそのまま通すため。

- 代わりの案 A: `compute(now)` を呼んで `best_by_provider` を使う → Codex の対応表の account を数えられず、構成の規則（margin ≥ 0）とも合わないので採らない
- 代わりの案 B: headroom に `weekly_margin(used, reset, now)` のような式だけの関数を足す → 入力（実効値・キャッシュの読み方・不正な値の扱い）の判定が `codex-develop.py` に残り、headroom と違う行を数える余地が残るので採らない

### 6. 未来の取得時刻は headroom の 60 秒の規則にする

`usage_margin` は取得時刻が 1 秒でも未来なら欠測にしていた。headroom は 60 秒以内の未来を時計のずれとして `ok`、それを超えると `stale` にする。決定 5 で margin を headroom の行から取るので、Codex もこの規則になる。Claude の起動アカウントも、今は未来の取得時刻を見ていなかったが、60 秒を超えて未来なら欠測になる（`select-account.sh` と同じ）。`dev-workflow-headroom` の要件にあった「#1301 で揃う」の但し書きはここで果たすので外す。

### 7. headroom の設定が不正なとき

`HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY` が数でない・範囲外のとき、headroom は既定値に倒さず例外（`ConfigError`）を出す。margin は天井によらないが、行を数える関数がまとめて設定を読むので、読む側でもこの例外を受ける。

- `select-account.sh`: 既定アカウントへ縮退し（`selected` の決め方は今の縮退と同じ）、理由 `default-due-to-invalid-headroom-setting`・`margins=-` を出して exit 0 で終わる。`cld` はシェルの起動のたびに使うので、使用量の計算の設定の誤りで Claude を起動できなくしない。理由行に印が出るので気づける
- `codex-develop.py`: 自動選択を止め、今のエラーの経路（`{"status": "blocked", "error": …}` を出して終了コード 2）で設定の名前を返す。構成を誤って選ぶより、develop の開始時に止めて直させるほうが安い。明示の profile・旧形式は自動選択をしないので影響を受けない

- 代わりの案: どちらも欠測として扱う → `codex-develop.py` では両方欠測で Claude 既定を選び、設定の誤りが「余りが無い」に見えて気づけないので採らない

### 8. 式が残っていないことの確かめ方

受け入れ条件の「margin を数える式が残っていない（headroom を呼んでいる）」は 2 つで確かめる。

- 振る舞い: `headroom.claude_rows` と `headroom.codex_row` を、式からは出ない margin（例: 12.345）を持つ行を返すものに差し替えて `automatic_selection` を呼び、証跡の margin がその値になることを確かめる（`test_codex_develop.py`）。`select-account.sh` は、margin の順と余りの順が逆になる snapshot（リセット権を持つスロット）で余りの側を選ぶことを確かめる（`account-selector.bats`）
- コードの検査: 2 つのスクリプトのソースに週の秒数（`604800`・`WEEK_SECONDS`）が現れないことを確かめる（`test_codex_develop.py` の `DocumentationContracts` と `account-selector.bats`）

## Risks / Trade-offs

- [どのスロットも余りが 0（天井に届く見込み）のとき、margin では差が付いていたのに宣言順で先のスロットを選ぶ] → headroom の best の規則（同点は宣言順）どおりで、ステータスラインの一番余っているアカウントとも一致する。差を付けたいなら headroom の best の規則を変える別の issue にする（flatmate のバーンも同じ値を読むため、ここだけで変えない）
- [起動アカウントがオフのスロットだと、Claude margin が欠測になる] → headroom はオフの行の数を出さない。オフは「このスロットを使わない」という利用者の設定なので、そのスロットで動く develop が Claude に余りが無いとして扱うことは受け入れる
- [5 時間の使用率が不明なスロットを `cld` が選び、起動直後に 5 時間の枠で止まる] → 不明は直近 5 時間に使っていないことが多い（使用量 API が 5 時間枠を返さない）。次の起動で値が入れば外れる
- [select-account.sh の起動が少し遅くなる] → `compute` は Codex の行のために `codex-develop.py` を読み込み、キャッシュのファイルを 1 つ読む。Codex の取得（app-server の起動）はしない

## Migration Plan

ファイルの書式は変わらないので移行は無い。マージ後に marketplace の自動更新で新しい `select-account.sh` が使われる。戻すときは PR を revert する。

## Open Questions

なし
