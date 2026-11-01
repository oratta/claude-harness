# Proposal

## Why

Claude のアカウントで、サーバーの返すリミット情報から 5 時間枠が無くなった（2026-11-01 に実測。`rate_limit_event` の `unifiedWindows` は `seven_day` だけ、usage API の `five_hour` は null）。`statusline.sh` は 5 時間の値があることを前提にしているため、週次の値があっても Claude の 5h・7d の行が丸ごと消え、`.rate-limit-snapshot` とセッション記録の更新も止まる。使用量の表示と、それを読む残量判定・アカウント選択・連携先の読み手の入力が古いまま止まるので、いま直す。

5 時間枠の廃止が恒久か一時的かは不明なので、値がまた返るようになっても今までどおり動くことを保つ。

## What Changes

- 書く条件を「5 時間枠の使用率がある」から「5 時間枠か週次の使用率のどちらかがある」に変える（`.rate-limit-snapshot`・共有 snapshot・セッション記録・前回値の署名）
- 週次だけの観測では `five_hour_pct` と 5 時間枠のリセット時刻を `null` で書く。キーは省かず、0 も作らない。**BREAKING**（読み手から見た契約）: 書き手の出力の `five_hour_pct` が null になりうる。リポジトリ内の読み手は null に耐えることを確かめ済みで、コードは変えない
- 週次の値があれば、5 時間の値が無くても `7d All` の行（`Fable` の区画・残り時間を含む）を描く。5h の行は出さない
- `.headroom.json` の値を使える判定から 5 時間の値の要否を外す（ロケットモード・リセット権の表示を週次だけのときも出す）
- 複数アカウント時の `取得待ち` を「5 時間も週次も無い」ときだけにする
- 5 時間枠と週次の両方があるときの出力と書き出す内容は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `rate-snapshot`: 書く条件・欠ける値の扱い・`obs_sig` の作り方を、5 時間枠が無い観測に対応させる
- `usage-session-records`: 記録を書く条件を同様に変え、5 時間枠が null の記録を読み手がどう扱うかの要件を足す
- `statusline-multi-account-usage`: 行の出し方を 5 時間の値から切り離し、週次だけのスロットの描き方と `取得待ち` の条件を定める

## Impact

- コード: `plugins/statusline/scripts/statusline.sh` のみ。読み手（`plugins/dev-workflow/scripts/` の `usage_view.py`・`headroom.py`・`usage-probe.sh`・`select-account.sh` など）は変えない
- テスト: `plugins/statusline/tests/` の 4 ファイルに追加。読み手を固定するテストは既存で覆われていない分だけ `plugins/dev-workflow/tests/` に足す
- 文書: `plugins/statusline/README.md`、`plugins/statusline/changes/1547.md`（新規）
- 層間の契約: `.rate-limit-snapshot` と共有 snapshot の `five_hour_pct` が null になりうる。連携先の読み手の修正はこの change に含めない（`design.md` の Risks）
