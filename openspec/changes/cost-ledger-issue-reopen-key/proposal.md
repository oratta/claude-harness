## Why

issue へのコストの帰属の鍵（`cost_ledger.py` の `ISSUE_RE`）が拾うのは `gh issue view|comment|edit|close|develop <番号>` だけで、`gh issue reopen <番号>` と、`gh api repos/<owner>/<repo>/issues/<番号>...` の直叩きが入っていない。issue を再オープンしただけ、または `gh api` だけで操作した区間は、その issue に寄らず「帰属先なし」か直前に触った別の issue に寄り、issue の累計が実際より小さく出る。このリポジトリは `gh issue view` が GraphQL エラーになり、issue を `gh api` で読み書きすることが多いので起きやすい（issue #698 と、そのコメントに移した PR #795 で見つかった件）。

## What Changes

- `ISSUE_RE` の拾うサブコマンドに `gh issue reopen` を足す
- `ISSUE_RE` 1 本の定義を書き換えて、コマンドの位置にある `gh api` の最初の位置引数（endpoint）が `repos/<owner>/<repo>/issues/<番号>` で始まるコマンドも、その番号を帰属の鍵として拾う
- 過去に台帳へ書いた行は書き換えない（再オープンや `gh api` の番号が入っていない行は、そのまま）と spec に 1 文で書く
- `ISSUE_RE` の定義以外のコード（`scan_tool_calls` など）は変えない
- 走査する場所は今までどおり実行された `Bash` の `command` だけ。実行していない文字列では寄らない

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `cost-ledger-attribution`: 要件「issue による帰属（第 2 の鍵）」の拾うコマンドの集合と、過去の行の扱い

## Impact

- `plugins/cost-ledger/scripts/cost_ledger.py`（`ISSUE_RE` の定義だけ）
- `plugins/cost-ledger/tests/attribution.bats`
- `openspec/specs/cost-ledger-attribution/spec.md`（archive 時に delta が反映される）
- `plugins/cost-ledger/changes/698.md`（変更の記録）。このリポジトリの規則（プラグインを変えたら `plugins/<name>/changes/<番号>.md` に記録する）で必要なファイルで、並行する子 #703・#760 が触るファイルとは重ならない
- 触らない: `gate_report.py`・`backfill.sh`・`backfill.py`・`backfill.bats`（別の子 issue #703・#760 の範囲）
