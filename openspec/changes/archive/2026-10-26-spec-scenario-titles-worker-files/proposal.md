## Why

指示書 `worker.md` の本文を `references/roles/worker/<段>.md`（common / spec / implement / finish）へ移した（#1331）あとも、3 つの spec のシナリオ題名 10 件が「worker.md に…」「worker.md が…」のまま残っている。題名を見て手順書を探した人が索引の `worker.md` を開いても、該当の内容が見つからない。

## What Changes

- `dev-workflow-develop` の spec の題名 5 件（125・354・379・1029・1230 行）、`dev-workflow-pr-review-gate` の spec の題名 3 件（755・760・765 行）、`dev-workflow-spec-review` の spec の題名 2 件（11・32 行）の「worker.md」を、WHEN/THEN が指す移し先のファイル名に直す（archive 後の spec を直接直す。本文の WHEN/THEN は変えない）。
- この change は delta spec を持たない（題名だけの変更は MODIFIED で書けない。design.md の Decisions）。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

なし（要件の規範は変わらない。表記だけを直す）

## Impact

3 つの spec の題名行 10 件。実行時の動きは変わらない。
