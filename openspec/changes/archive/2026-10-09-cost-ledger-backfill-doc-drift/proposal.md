## Why

PR #744（#691: 後追い）のレビューで、文書と spec の記述が実装とずれている箇所が見つかった（issue #763）。実害は無い。あわせて、`plugins/cost-ledger/changes/691.md` に台帳の場所の解決（#760）より前の言い回しが残っている（issue #871）。読む人が誤った前提で判断しないよう、実物に合わせて直す。

## What Changes

- `cost-ledger-backfill` の Scenario「壊れた控え」の WHEN に「一覧が 1 件以上を返す」を足す（一覧が 0 件だと控えは書き直されず壊れたまま残るため）。archive 済みの delta spec にも同じ直しを入れる
- `cost-ledger-timeline` の `--backfill` の守備範囲に、手でマージ・クローズした直後の 1〜2 秒に別セッションが始まると 2 行並ぶ場合を 1 つ足す
- archive 済みの `cost-ledger-backfill/design.md` の決定 6 の「最終行が壊れたあとの先頭の行」を、spec と `timeline_has_trigger_near()` が定める 2 つの場合に合わせる
- `plugins/cost-ledger/README.md`: 「上限は 61 回」に 20 件目と同じ秒の候補が続く回は超えると書く。「300 秒以上ずれていると」を「GitHub より 300 秒を超えて遅れていると」に直す
- `plugins/cost-ledger/changes/691.md`: 「`COST_LEDGER_PATH` 未設定」を解決後のパスの言い方に直す（#871）
- `gate_report.py` の `lock()` のロックのファイル名を小文字にそろえる（`repo.lower()`）。大文字小文字を区別する環境で、同じリポジトリが別のロックになりうるのを防ぐ

`cost_ledger.py` と `attribution.bats` は並行する別の子（#698）が触るので変更しない。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-backfill`: Scenario「壊れた控え」の WHEN
- `cost-ledger-timeline`: `--backfill` の守備範囲に 1 つ足す

## Impact

- 文書・spec・archive 済みの文書: 挙動は変わらない
- `plugins/cost-ledger/scripts/gate_report.py` の `lock()` 1 行: ロックのファイル名が小文字になる。`/tmp/cost-ledger-timeline/` に残った旧名のロックは使われなくなるだけで、ロックは毎回作り直される
- hook の処理は増減しない。待ち時間と `gh` の呼び出し回数が変更の前後で同じことを実測して PR に書く（エピック #272 の全体の制約）
