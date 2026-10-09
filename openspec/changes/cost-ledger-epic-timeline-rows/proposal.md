## Why

cost-ledger の hook（`gate_report.py`）がエピックのコメントに積む行は、エピックの番号そのものを触った区間だけの累計で、実際の作業が起きる子 issue と子 PR の分を含まない。エピックの履歴の額がほぼ 0 に見え、`/cost <エピック番号>`（子 issue 込み。#690）の合計と食い違う。issue #745（エピック #272 の子）。

## What Changes

- hook が、対象の issue が子 issue を持つとき（対象の確認で既に取っている応答の `sub_issues_summary.total` が 1 以上）だけ、子孫の issue と、エピックと子孫を閉じた PR を GitHub から取り、`cost_ledger.py timeline` に渡す。`timeline` は `gh` を呼ばない決まりのまま
- 子を持つ issue に積む行は、毎回（節目の行・合計の行とも）、`/cost <番号>` の 1 行目と同じ「子 issue 込み」の累計になる。閉じたときの合計の行も同じ額に子の分を含む
- 子を持たない issue と PR は、積む行も `gh` の回数も変わらない
- `timeline` に `--child-issue <番号>`（子孫の issue。複数）と `--child-pr <PR番号>:<ヘッドブランチ>`（エピックと子孫を閉じた PR。複数）を足す
- 子の問い合わせが失敗したときは、従来どおりの区間だけの行を積み、節目の行のきっかけの欄に `子 issue 照会失敗` を足す（`PR 照会失敗` と同じ扱い）
- 設計判断（毎回の行に入れるか、閉じたときの合計の行だけに入れるか）の根拠は `design.md`。`gh` の回数と待ち時間は変更の前後で実測して PR に書く

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `cost-ledger-timeline`: 「数字と書式は `timeline` サブコマンドから取る」（子 issue を持つ issue に積む行は区間だけ、という記述を、子孫込みに変える。`--child-issue`・`--child-pr` を足す）、「`gh` の呼び出し回数」（子を持つ issue の回数を足す）。子 issue 込みの行を積む新しい要件を足す

## Impact

- `plugins/cost-ledger/scripts/gate_report.py`（`stack()` と、子の問い合わせの関数の追加。`resolve()` が応答の `sub_issues_summary.total` を返す）
- `plugins/cost-ledger/scripts/cost_ledger.py`（`cmd_timeline` と `build_parser` の引数、`issue_combined_total` の拡張。`ISSUE_RE` は触らない）
- `openspec/specs/cost-ledger-timeline/spec.md`、`plugins/cost-ledger/README.md`（hook の説明があれば）
- `plugins/cost-ledger/tests/`（新しい bats `epic-timeline.bats`。`attribution.bats` は触らない）
- `plugins/cost-ledger/changes/745.md`
- 常時注入（`rules/`・`CLAUDE.md`・`description`）は増やさない。LLM のトークンは使わない
