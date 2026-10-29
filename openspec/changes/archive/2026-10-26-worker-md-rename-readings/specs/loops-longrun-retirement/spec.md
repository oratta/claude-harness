## MODIFIED Requirements

### Requirement: 解散プラグインへの参照を掃除する
`plugins/`・`rules/`・`docs/`・`README.md`・`.claude-plugin/`・`.github/`・`scripts/` 配下のファイルは、`loops:`（スラッシュコマンド・スキル参照）・`/lr:`・`longrun`・`plugins/loops/`・`plugins/longrun/` の文字列を含んではならない（MUST NOT）。例外は次の 5 種に限る: (a) `plugins/dev-workflow/CHANGELOG.md` の解散記録と新旧パス対応表、(b) `plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md` の「旧 longrun の Build Contract レビューを置き直した」という由来説明、(c) `plugins/product-handover/CHANGELOG.md` の「loops の解散は #205」という説明文、(d) ルートの過去実行アーカイブ `_longruns/` を指すパス・除外指定（`scripts/test.sh`・`scripts/lint.sh`・`tests/shell-multibyte-expansion.bats`・`plugins/product-handover/tests/plugin-structure.bats`・`plugins/worktree/tests/helper.bash`）、(e) この掃除と解散を検査する bats ファイル自身（`plugins/dev-workflow/tests/*.bats`・`tests/marketplace-sync.bats`。検査対象の文字列を必然的に含むため。先例: `plugins/product-handover/tests/plugin-structure.bats` が自分を除外している）。

#### Scenario: 許容リスト外のヒットが 0 件
- **WHEN** リポジトリルートで `grep -rn "loops:\|/lr:\|longrun" plugins rules docs README.md .claude-plugin .github scripts` を実行し、上の 5 種の例外行を除く
- **THEN** 残るヒットは 0 件である

#### Scenario: 旧 reference パスの参照が残っていない
- **WHEN** `grep -rn "loops/references/\|longrun/references/" plugins rules docs README.md .github` を実行し、例外 (a) の CHANGELOG（新旧パス対応表が旧パスを必然的に含む）と例外 (e) の bats ファイル自身を除く
- **THEN** ヒットは 0 件である（自己検証・PR 本文の型・モデルティアの参照、`.github/PULL_REQUEST_TEMPLATE.md` の書式の正本、`roles/worker/finish.md` の PR 本文の型は、すべて `plugins/dev-workflow/references/` を指す）
