## Why

develop スキルの `SKILL.md`「入口 0」末尾と `openspec/specs/dev-workflow-develop/spec.md` の同文（SHALL）は「仕様化判断・仕様レビュー結果・仕様宣言は、いずれも記録先のコメントに置く」と書いており、記録先が issue のとき仕様宣言を issue コメントに置くと読める。一方、W が実際に読む `references/roles/worker.md`「PR と仕様宣言」と pr-review-gate 手順 3-b / 5 は、`対象 HEAD:` 付きの仕様宣言を **PR コメント**に必須としている（ゲートは `issues/<PR番号>/comments` の 3 見出しを照合する）。worker.md / pr-review-gate 側が正で、SKILL.md / spec の文言が誤り（issue #212。PR #204 の Codex レビュー指摘）。

## What Changes

- `plugins/dev-workflow/skills/develop/SKILL.md`「入口 0」: 仕様化判断・仕様レビュー結果は記録先のコメント、仕様宣言は記録先が issue か Draft PR かにかかわらず常に PR コメント、と分離して書く。節の冒頭文（記録先に置くものの列挙）と「1 ループ」の (3) の記述も同じ向きに揃える
- `openspec/specs/dev-workflow-develop/spec.md` Requirement「入口 0 は記録先を決める」: 上記の SHALL 文を同じ分離に直し、分離が書かれていることを検証する Scenario を追加する（本 change の delta spec で MODIFIED）
- `plugins/dev-workflow/tests/develop-skill.bats`「entry-0: decision, review result and declaration live in record-target comments」: 仕様宣言が「記録先」ではなく「PR コメント」に置かれると書かれていること、記録先のコメントに置くものの列挙に仕様宣言が含まれないことをアサートする
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow バージョンを `2.0.2` に上げる（事前割当。`2.0.1` は並行 PR #211 用）

pr-review-gate 側（`skills/pr-review-gate/SKILL.md`・`tests/pr-review-gate-spec-declaration.bats`）と worker.md は正なので触らない。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: Requirement「入口 0 は記録先を決める」の SHALL 文を「仕様化判断・仕様レビュー結果は記録先のコメント、仕様宣言は常に PR コメント」に修正し、分離を検証する Scenario を追加する

## Impact

- 影響範囲は develop スキルの文書（SKILL.md）・その openspec spec・構造検証テスト（develop-skill.bats）・プラグインのバージョン表記に限る。実行コード・hook・pr-review-gate の照合ロジックは変えない
- 運用上の振る舞いは変わらない（W は既に worker.md に従って PR コメントに投稿しており、ゲートも PR コメントを照合している）。変わるのは本体向け手順書と spec の記述の正しさ
- 並行 PR #211（pr-review-gate の仕様宣言関連）とはファイルが重ならない。version 行の衝突はマージ時に本体が扱う
