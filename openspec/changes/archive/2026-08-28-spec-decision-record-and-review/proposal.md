## Why

dev-workflow の `github-issue` スキルは仕様化要否（Step B）を判定するが結果を記録せず、`/opsx:ff` で書いた仕様を実装前にレビューする工程も無い。その結果、flatmate の週次ミーティング実装（flatmate#380）では規範を変える 6 PR が openspec を更新せずにマージされ、仕様レベルの穴（既存規約との整合・config に出すべき固有値・導入先の前提）が実装レビューに流れ込んで往復を増やした（claude-harness#191、flatmate#444）。longrun には Build Contract レビュー（実装前の設計審査）があったが、dev-workflow を別プラグインとして新設した際に議論されないまま抜け落ちている。

## What Changes

- Step B の判定結果を**固定書式で issue コメントに記録**する（`仕様化判断: する|しない` ＋理由）。interactive / unmanned の両モード共通。後続の pr-review-gate（別 change）はこのコメントを出口で照合する
- `/opsx:ff` と `/opsx:apply` の間に**仕様レビュー工程**を新設する。実装と別コンテキストのサブエージェントが change の artifact（proposal / specs / design / tasks）を既存 `openspec/specs/` と issue の受け入れ条件に照らして審査し、APPROVE まで実装に入らない。往復上限 2 周（pr-review-gate の 2 周キャップに揃える。pr-review-gate が持つ「新規の高深刻度 blocking のみ 3 周目可」の例外は設けない — 仕様段階の残課題は needs-approval で人に返す方が安い）
- レビュー観点・出力書式・レビュアーのモデル選択を `references/spec-review.md` に置き、SKILL.md からはそこを参照する
- openspec CLI だけの縮退経路でも同じ記録・レビューを通す

## Capabilities

### New Capabilities
- `dev-workflow-spec-review`: 仕様化要否の判断記録と、書いた仕様の実装前レビュー（担い手・観点・往復上限・記録先）

### Modified Capabilities
（なし。`dev-workflow-issue-entry` は `/work-issue` コマンド定義の入口分岐を扱う capability で、github-issue SKILL.md のパイプライン要件は持たないため、規範は新 capability に一本化する）

## Impact

- `plugins/dev-workflow/skills/github-issue/SKILL.md`（Step B / Step D）
- `plugins/dev-workflow/skills/github-issue/references/spec-review.md`（新規）
- `plugins/dev-workflow/skills/github-issue/references/decision-criteria.md`（記録書式への参照）
- `plugins/dev-workflow/tests/spec-decision-and-review.bats`（新規）
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の version
- 後続 change（pr-review-gate の仕様宣言照合）はこの記録書式に依存する
