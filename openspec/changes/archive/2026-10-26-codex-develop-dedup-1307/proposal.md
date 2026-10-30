## Why

`commands/develop.md` と `references/codex-develop.md` に、同じ決まりが二度書かれている。account 名と CODEX_HOME の対応表の渡し方と、ゲート担当（G）の起動指示に書く `レビュー経路: adapter` の義務である。片方だけ直し忘れる原因になるため、正本を 1 か所にする（#1307、#1239 から分割、エピック #1225）。

## What Changes

- C12: 対応表の規則の本文を `references/codex-develop.md` の 1 か所に置き、`commands/develop.md` は参照にする
- C5: `references/codex-develop.md` の needs-reviewer の行にある `レビュー経路: adapter` を書く義務の文を、SKILL.md「Role profile の選択」節と `gate-runner.md`「レビュー経路の判別」を指す参照にする。「行が無い G は従来経路」の executor ごとの説明は残す
- `commands/develop.md` の「手順の正は SKILL.md の 1 箇所にのみ存在する」の文を、エピックの扱いが `skills/develop/references/epic.md` にある現状に合わせる

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「G の再開を前提にした既存要件の読み替え」の Scenario「adapter 経路の保持規則が無い」で、`codex-develop.md` に義務の本文が残る読み方をやめ、参照が残る読み方にする

## Impact

- `plugins/dev-workflow/commands/develop.md`、`plugins/dev-workflow/references/codex-develop.md` の文章のみ。コード・スクリプトは変えない
- bats（`develop-adapter-review-routing.bats` の needs-reviewer の行の assertion など）は文言を保つので変更しない
