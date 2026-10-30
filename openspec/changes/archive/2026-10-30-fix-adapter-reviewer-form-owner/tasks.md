## 1. spec の文言

- [x] 1.1 `openspec/specs/dev-workflow-develop/spec.md` 527 行の段落を、形の持ち主が `stages/triage.md` と `stages/review-run.md` になり、2 ファイル間で食い違わない旨に直す。触る範囲: `openspec/specs/dev-workflow-develop/spec.md:527-527`
- [x] 1.2 同 539 行の Scenario「G がレビュー実行者を記録する」の THEN の `pr-review-gate/SKILL.md` の部分を、「`pr-review-gate/stages/review-run.md` にも説明される」の表現で直す。触る範囲: `openspec/specs/dev-workflow-develop/spec.md:539-539`
- [x] 1.3 同 543 行の Scenario「回帰テスト」の THEN の列挙の `pr-review-gate/SKILL.md` を `pr-review-gate/stages/triage.md`・`pr-review-gate/stages/review-run.md` に直す（`gate-runner.md`・`SKILL.md`・`codex-develop.md` は bats が実際に照合しているので変えない）。触る範囲: `openspec/specs/dev-workflow-develop/spec.md:543-543`

## 2. テスト名

- [x] 2.1 bats 240 行のテスト名を `triage and review-run (#385): both carry the adapter form of the reviewer line` に直す（grep の行は変えない）。触る範囲: `plugins/dev-workflow/tests/develop-adapter-review-routing.bats:240-240`
- [x] 2.2 bats 8 行の冒頭コメント `#   pr-review-gate SKILL.md 「レビュー実行者:」…` を `stages/triage.md`・`stages/review-run.md` に直す。24 行の未使用変数 `PRGATE` は範囲外で触らない。触る範囲: `plugins/dev-workflow/tests/develop-adapter-review-routing.bats:8-8`

## 3. 変更の記録

- [x] 3.1 `plugins/dev-workflow/changes/1430.md` を新規に書く（spec の文言とテスト名の訂正のみ・挙動と版は変えない・戻し方は PR の差分を戻す）。触る範囲: `plugins/dev-workflow/changes/1430.md`（新規）
