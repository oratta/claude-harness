## Why

PR #1507（#1012）の独立レビューで、候補探しの手順書（`stages/triage.md`）と spec に食い違いが 5 件残った（#1517）。(1) コマンド形に `--exclude <エピック番号>` が無い。(2) 見出しと本文の「1 回」に打ち切りの再実行の例外が書かれていない。(3) spec の「`--children-only` は付けない」に再実行の例外が無く、同じ要件の MUST と矛盾して読める。(4) 再実行が 1 回目と同じ `--repo` と `--exclude` を保つと書かれておらず、`--exclude` が落ちると記録先の issue が候補に戻る。(5) 再実行だけが失敗すると、1 回目に出た子の候補を使わず新しい子 issue を作り、「再実行でも打ち切られたら出た候補だけで振り分ける」と釣り合わない。

## What Changes

- 1〜4 は文言の補完: コマンド形・見出し・本文・spec の箇条・再実行の項に不足を足す
- 5 は振る舞いの決め直し: 再実行が失敗したら、走らせ直さず、仕分けの PR コメントに失敗と終了コードを書き、打ち切られたパスの指摘を 1 回目に出た候補だけで振り分ける（既存 issue への相乗りも許す）。これまでは相乗りを禁止して段 C の「当たる issue が無い」へ進めていた
- `stages/triage.md`・main の spec・bats の検査を同じ commit でそろえる

## Capabilities

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「候補探しのスクリプトは 1 回だけ走らせ、失敗を候補なしと読まない」（本文と、Scenario「打ち切りの再実行が失敗した」）

## Impact

`plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`（候補探しの段落）、`openspec/specs/dev-workflow-pr-review-gate/spec.md`、`plugins/dev-workflow/tests/pr-review-gate-skill.bats`、`plugins/dev-workflow/changes/1517.md`。スクリプトは変えない。archive 済みの change（`2026-10-31-g-candidate-search-exclude-epic`）は過去の記録なので書き換えない。
