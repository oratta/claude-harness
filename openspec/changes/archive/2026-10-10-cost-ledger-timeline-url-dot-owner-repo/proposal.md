## Why

issue #947。cost-ledger の hook（`plugins/cost-ledger/scripts/gate_report.py`）は、対象のリポジトリの owner / repo が `.` または `..` そのもののとき、その対象を飛ばす（`valid_parts()`）。この判定は `-R` / `--repo`・前置きの `GH_REPO=値`・`gh api` の直書きの endpoint の 3 つの経路に掛かっていて、位置引数の URL（`gh pr comment https://github.com/a/../pull/1`）で指した対象には掛かっていなかった。許可の一覧（`cost-ledger-write-allowlist`）に `a/..` のような名前があると、対象の確認の `gh api repos/a/../pulls/1` まで進む。PR #946 は spec を当時の実装に合わせ、この経路を「誤ったまま通ることを許す入力」に書いた。

あわせて issue #951 の指摘のうち、同じ項目にある「許可の一覧」に正本の名前を添える件を、この改定の中で扱う。

## What Changes

- 実装: `trigger_targets()` が位置引数の URL から取り出した owner / repo に `valid_parts()` を掛け、通らなければ対象として解決しない
- `cost-ledger-timeline` の要件「対象の解決」の、owner / repo が `.` か `..` の対象を飛ばす文に、位置引数の URL を 4 つ目の経路として足す。URL が飛ばされたとき、併記した `-R` / `--repo` や前置きの `GH_REPO=値` のリポジトリには落ちないことも同じ文に書く（下の実測）
- 同じ要件の守備範囲から、「位置引数の URL の owner / repo は見ない」の項目を外す。代わりに、この定めが 4 つの経路のどれでも見ないもの（`a/...`・`a/b..` のように `.` を連ねた名前・`.` を含むだけの名前）を、誤ったまま通ることを許す入力として書く。「許可の一覧」には正本の名前（`cost-ledger-write-allowlist`）を添える（issue #951 の指摘）
- Scenario を 2 つ足す（どちらも `plugins/cost-ledger/tests/gate-report.bats` に足すテストが固定する）
- `a/...`・`a/b..`・`%2e%2e`・余分なスラッシュ・`github.com` 以外のホストの URL の扱いは変えない（issue #947 の triage の範囲）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-timeline`: 「対象の解決」（`.` / `..` を飛ばす文の経路を 3 つから 4 つへ・守備範囲の 1 項目の差し替え・Scenario 2 つを足す）

## 実測（`find_triggers()` を直接呼んだ結果。直す前は origin/main の `gate_report.py`、直した後はこの change の実装。Python 3.11 と 3.9 で同じ）

| コマンド | 直す前 | 直した後 |
|---|---|---|
| `gh pr comment https://github.com/a/../pull/1 --body x` | a/.. の #1 | なし |
| `gh pr comment https://github.com/../b/pull/1 --body x` | ../b の #1 | なし |
| `gh pr comment https://github.com/a/./pull/1 --body x` | a/. の #1 | なし |
| `gh pr comment https://github.com/./b/pull/1 --body x` | ./b の #1 | なし |
| `gh issue close https://github.com/../b/issues/2` | ../b の #2 | なし |
| `gh pr merge https://github.com/a/../pull/1` | a/.. の #1 | なし |
| `U=https://github.com/a/../pull/1; gh pr comment $U --body x` | a/.. の #1 | なし |
| `gh pr comment https://github.com/a/../pull/1 -R acme/other --body x` | a/.. の #1 | なし（`-R` の acme/other には落ちない） |
| `GH_REPO=acme/other gh pr comment https://github.com/../b/pull/1 --body x` | ../b の #1 | なし（`GH_REPO` の acme/other には落ちない） |
| `gh pr comment https://github.com/acme/other/pull/301 -R a/.. --body x` | acme/other の #301 | 同じ |
| `gh pr comment https://github.com/acme/.github/pull/3 --body x` | acme/.github の #3 | 同じ |
| `gh pr comment https://github.com/a.b/c/pull/3 --body x` | a.b/c の #3 | 同じ |
| `gh pr comment https://github.com/ACME/Repo-1_x/pull/3 --body x` | ACME/Repo-1_x の #3 | 同じ |
| `gh pr comment https://github.com/a/.../pull/3 --body x` | a/... の #3 | 同じ（この change では扱わない形） |
| `gh pr comment https://github.com/a/b../pull/3 --body x` | a/b.. の #3 | 同じ（同上） |
| `gh pr comment https://github.com/a/%2e%2e/pull/3 --body x` | なし | 同じ |
| `gh pr comment https://github.com/a//b/pull/3 --body x` | なし | 同じ |
| `gh pr comment https://ghe.example/a/../pull/3 --body x` | なし | 同じ |

`a/...`・`a/b..` は、`-R`・前置きの `GH_REPO`・`gh api` の endpoint・位置引数の URL のどれで指しても、許可の一覧に名前があれば対象の確認の `gh` まで進む（hook を通した実測）。

## Impact

- `plugins/cost-ledger/scripts/gate_report.py`（`trigger_targets()`）と `plugins/cost-ledger/tests/gate-report.bats`（テスト 1 本を足す）、`openspec/specs/cost-ledger-timeline/spec.md`、変更記録 `plugins/cost-ledger/changes/947.md`
- 振る舞いの変更: 位置引数の URL の owner / repo が `.` か `..` のとき、対象として解決しなくなる（対象の確認の `gh` を呼ばず、行も積まない）。`.`・`..` は API のパスに入れると別の endpoint を指す名前で、ほかの 3 つの経路では既に飛ばしている。名前の中に `.` を含むだけの URL の扱いは変わらない
- 対応するテスト: `gate-report: a positional URL with an owner or repo of . or .. is an unresolvable target and gh is never called`
