## Why

issue #941（PR #937 のレビューで残った「止めない指摘」）。cost-ledger の hook（`plugins/cost-ledger/scripts/gate_report.py`）は、対象のリポジトリの owner / repo が `.` または `..` のとき、その対象を飛ばす（`valid_parts()`。PR #873 で `-R` / `--repo` / `GH_REPO` に、PR #937 で `gh api` の直書きの endpoint に掛けた）。この拒否は実装とテストにだけあり、`openspec/` に文が無い。

## What Changes

- `cost-ledger-timeline` の要件「対象の解決」に、`-R` / `--repo`・前置きの `GH_REPO=値`・`gh api` の直書きの endpoint のどれで指しても、owner / repo が `.` か `..` そのものの対象は解決できなかった対象として飛ばす、という文を足す（既にある「解決できないものは積まずに飛ばす」の具体化。実装がいましていることだけを書く）
- 同じ要件の守備範囲に、この定めが見ない経路（位置引数の URL）を「誤ったまま通ることを許す入力」として足す
- Scenario を 2 つ足す（どちらも既存のテストが固定している振る舞い）
- 実装（`gate_report.py`）とテストは変えない。`a/b..`・`a/...`・`.../b`・`a/-` のような形は、GitHub 上で作れるかが未確認なので、この change では扱わない（issue #941 の triage の範囲）。`cost-ledger-gate-report` の spec も変えない（同上）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-timeline`: 「対象の解決」（文 1 段落・守備範囲の 1 項目・Scenario 2 つを足す。挙動は変えない）

## 実測（origin/main の `gate_report.py` の `find_triggers()` を直接呼んだ結果）

| コマンド | 取り出された対象 |
|---|---|
| `gh pr comment 1 -R a/.. --body x` | なし |
| `gh pr comment 1 -R ./b --body x` | なし |
| `GH_REPO=../b gh pr comment 1 --body x` | なし |
| `GH_REPO=a/. gh api -X POST repos/{owner}/{repo}/issues/1/comments -f body=x` | なし |
| `gh api -X POST repos/a/../issues/1/comments -f body=x` | なし |
| `gh api -X POST repos/./b/issues/1/comments -f body=x` | なし |
| `R=a/..; gh pr comment 1 -R $R --body x` | なし |
| `gh pr comment 1 -R acme/.github --body x` | acme/.github の #1 |
| `gh api -X POST repos/a.b/c/issues/1/comments -f body=x` | a.b/c の #1 |
| `gh api -X POST repos/a/.../issues/1/comments -f body=x` | a/... の #1（この change では扱わない形） |
| `gh pr comment https://github.com/a/../pull/1 --body x` | a/.. の #1（位置引数の URL には掛からない。守備範囲に書く） |

## Impact

- `openspec/specs/cost-ledger-timeline/spec.md` だけ。`plugins/` は変えないので変更記録（`plugins/<name>/changes/`）は書かない
- 対応するテスト（変えない）: `plugins/cost-ledger/tests/gate-report.bats` の `gate-report: an owner or repo of . or .. is an unresolvable target and gh is never called` と `gate-report: a literal gh api endpoint with an owner or repo of . or .. is an unresolvable target and gh is never called`
