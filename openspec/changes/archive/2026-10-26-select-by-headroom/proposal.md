## Why

#1300 で「どのアカウントが、いつまでに、どれだけ余るか」の計算を `plugins/dev-workflow/scripts/headroom.py` の 1 か所に置いた。ステータスラインはその結果（リセット権込みの余り）で一番余っているアカウントを示すが、`cld` のアカウント選択（`select-account.sh`）はまだ経過率 − 使用率（margin）が最大のスロットを選び、リセット権を見ない。画面で一番余っているアカウントと `cld` が選ぶアカウントが食い違う。develop の構成の自動選択（`codex-develop.py`）も margin を自分で数え直している。設計の正本 genetta-inc/flatmate#1711 で、この 2 つを headroom の値から決めると決めた（記録先 oratta/claude-harness#1301）。

## What Changes

- `select-account.sh` の自動選択は、`headroom.compute(now)` の `best_by_provider.claude`（Claude のスロットの中で余り `surplus_pct` が最大のもの）を選ぶ。経過率と使用率から margin を数える式を消す。候補から外す規則（オフ・欠測・週次の実効値の取得時刻が 60 秒を超えて未来・5 時間の使用率 90% 以上）は headroom の `status` と best の除外規則に寄せる。理由は `max-surplus` に変わる。**BREAKING**（理由行の文言）: `reason=max-weekly-margin` は出なくなる
- 理由行の `margins=` は headroom の行の `margin` を小数点以下 2 桁で残す（選択には使わない）。候補外の印に `stale`（週次の実効値の取得時刻が 60 秒を超えて未来）が加わる
- 5 時間の使用率が分からないスロットは、今は `missing` として外していたが、headroom の best と同じく候補に残す
- `codex-develop.py` の構成の選択規則（両方 margin ≥ 0 なら `claude-write-codex-review`、Codex だけなら `codex-standard`、それ以外は Claude 既定）は残す。その margin は `usage_margin` / `claude_usage_evidence` で数え直さず、headroom が返す行の `margin` から取る（関数の名前と戻り値の形は残し、中身を headroom の呼び出しにする）
- そのため headroom に、行を返す公開関数を 2 つ足す: Claude の各スロットの行を返す `claude_rows(now, snapshot_path=None)` と、読み込み済みの Codex のキャッシュ 1 件から行を返す `codex_row(account, cache, now)`。`compute` はこの 2 つを使う（出力は変えない）
- Codex の取得時刻の未来の扱いを headroom の 60 秒の規則に揃える（今の `usage_margin` は 1 秒でも未来なら欠測）。Claude の起動アカウントも、週次の実効値（`build_view` が選んだ値）の取得時刻が 60 秒を超えて未来なら欠測になる
- headroom の設定（`HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY`）が不正なとき、`select-account.sh` は既定アカウントへ縮退して理由 `default-due-to-invalid-headroom-setting` を出し、`codex-develop.py` の自動選択は設定の名前を挙げてエラーで止まる

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `usage-account-registry`: 要件「起動アカウントを週次余裕から自動選択する」を headroom の余りで選ぶ要件に置き換える（名前も変える）。要件「古い・欠測・短期枠逼迫のスロットを候補から外す」と「値と選択理由を別の出力ストリームで返す」を headroom の `status` と best の除外規則・理由行の新しい印に合わせる
- `codex-role-profiles`: 要件「明示指定が無い工程では provider の週次余裕から構成を選ぶ」で margin の出どころを headroom の行にする。要件「snapshot の鮮度と週次窓を fail-safe に検証する」で未来の取得時刻の扱いを headroom の 60 秒の規則にする
- `dev-workflow-headroom`: 要件「余りの計算を headroom.py の 1 か所に置く」に行を返す公開関数 2 つを足す。要件「Codex はリセット権の失効を期限にする」から「#1301 で揃う」の但し書きを外す

## Impact

- 変更: `plugins/dev-workflow/scripts/select-account.sh`、`plugins/dev-workflow/scripts/codex-develop.py`、`plugins/dev-workflow/scripts/headroom.py`（公開関数 2 つ。数え方は変えない）
- テスト: `plugins/dev-workflow/tests/account-selector.bats`（理由の文言・5 時間の使用率が分からないスロット・余りが 0 で並ぶときの宣言順の期待値が変わる。リセット権込みで選ぶテストを足す）、`plugins/dev-workflow/tests/test_codex_develop.py`（1 秒先の取得時刻のテストを 60 秒の規則に直す。headroom を呼んでいることの検査を足す）、`plugins/dev-workflow/tests/test_headroom.py`（公開関数のテスト）
- 文書: `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の週次余裕の段落（起動アカウントの選択は headroom の余りで決める）。`/develop` 起動時に読むファイルのバイト数予算（#1224）に当たるので、文の長さを増やさない
- 変更の記録: `plugins/dev-workflow/changes/1301.md`。版（version）は上げない
- flatmate のバーン（genetta-inc/flatmate#1772）は `best` を読む。この change で headroom の出力（`.headroom.json`・`compute` の戻り値）は変わらない
