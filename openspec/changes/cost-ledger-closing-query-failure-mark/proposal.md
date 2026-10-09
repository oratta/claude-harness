## Why

issue #737（エピック #272 の子。#689 の実装中に見つけた抜け）。`gh issue close` のとき、閉じた PR の問い合わせが失敗しても、閉じた PR が 0 件でも、積まれるのは `issue クローズ` の行だけで、コメントを読んでも見分けが付かない。失敗で合計が抜けたことに気づけず、区間だけの累計を issue の合計と読み違える。hook は出力を出さないので、失敗はどこにも残らない。

## What Changes

- 閉じた PR の問い合わせが失敗したときだけ、節目の行のきっかけの欄の最後に `+PR 照会失敗` を足す（例: `issue クローズ+PR 照会失敗`）。失敗は、`gh` の失敗・JSON でない応答・応答の形の崩れ・100 件超
- 成功した場合（0 件・数える PR が 0 件・1 件以上）は今までと同じ。行も `gh` の呼び出し回数（4 回）も変えない
- `gate_report.py` の `closing_prs()` が、失敗と成功を区別して返す（失敗は `None`、成功は `[]` か一覧）。`stack()` が失敗のときだけ `--trigger` に印を足す
- 失敗した回の合計は後から補わない。後追い（#691）は `issue クローズ` を含む行がある issue を候補から外すので、印の付いた行も外れる。補う手段は `/cost <issue番号>` を手で叩くこと

`cost_ledger.py` は変えない（`--trigger` は自由な文字列で、`timeline_has_trigger_near()` が `+` 区切りの要素で比べるため、印は後追いの判定に影響しない）。`ISSUE_RE` と `attribution.bats` も触らない（#698 が触る）。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-timeline`: 「`issue クローズ` では、閉じた PR を合わせた合計の行を積む」に、失敗の印を足す。守備範囲の「0 件と失敗が見分けられない」を外し、「失敗した回の合計は後から補わない」を許す穴に加える

## Impact

- `plugins/cost-ledger/scripts/gate_report.py`（`closing_prs()`・`stack()`）、`plugins/cost-ledger/tests/gate-report.bats`、`plugins/cost-ledger/README.md`（合計の行が付かない場合の記述）、`plugins/cost-ledger/changes/737.md`（新規）
- 失敗した回の行のきっかけの欄が 7 文字（`+PR 照会失敗`）長くなる。成功した回の行は 1 文字も変わらない。`gh` の呼び出し回数・LLM のトークン・待ち時間は変わらない
