## Why

要件「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」は、`（adapter 経路・<light|full>・dispatch 記録:` の形を持つファイルを `gate-runner.md` と `pr-review-gate/SKILL.md` としている。実際にこの形を持つのは `pr-review-gate/stages/triage.md`（書き分け）と `stages/review-run.md`（書き分けと PR コメント雛形）で、前二者は形を持たない。bats のテスト名も同じ誤りを引きずっている（issue #1430、PR #1429 のレビュー指摘 F1）。

## What Changes

- `dev-workflow-develop` の上記要件の、形の持ち主を述べる 3 か所を、`stages/triage.md` と `stages/review-run.md` に直す: 段落（spec.md 527 行）、Scenario「G がレビュー実行者を記録する」の THEN（539 行。表現は「`stages/review-run.md` にも説明される」）、Scenario「回帰テスト」の THEN（543 行。`pr-review-gate/SKILL.md` の部分だけ。bats が実際に照合する `gate-runner.md`・`SKILL.md`・`codex-develop.md` はそのまま）
- `plugins/dev-workflow/tests/develop-adapter-review-routing.bats` のテスト名（240 行）と冒頭コメント（8 行）だけを同じ持ち主に合わせる（grep の行は変えない）
- 変更の記録 `plugins/dev-workflow/changes/1430.md` を足す

## Capabilities

### Modified Capabilities
- `dev-workflow-develop`: 上記要件の文言のみ（要件の追加・削除・改名なし）

## Impact

- `openspec/specs/dev-workflow-develop/spec.md`（3 か所）、bats の 2 行（テスト名とコメント）、`changes/1430.md`。stages/・SKILL.md・gate-runner.md は変えない
