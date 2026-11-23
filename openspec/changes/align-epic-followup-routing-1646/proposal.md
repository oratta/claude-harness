# Proposal

## Why

エピックの子で見つかった問題を、段 C・段 E は完了条件への効果で分ける一方、develop は無条件で子にするよう案内している。この食い違いにより、主が頼んでいない直しがエピックを閉じる条件に加わる（issue #1646、親 #1474）。

## What Changes

- レビュー指摘と実装中の範囲外の問題のどちらも、段 C で完了条件に効くとしたものだけをエピックの子にできるよう、epic.md と SKILL.md（参照案内を含む）をそろえる。親の注意書きでも、この境界を上書きしない。
- `/develop <エピック番号>` の開始時に完了条件の節が無ければ、本文から決めて子の起動前に本文に記す。本文だけでは決められないときだけ主に聞く。
- failed で W に戻す修正対象は、止める指摘と 1 周目の段 A に当たる指摘だけにする。段 A に当たらない止めない指摘を「序でに直してよい」と渡さない。
- 段 C「効かない」→段 E「見合う」の問題が、親の注意書きがあってもエピックの外の issue になるシナリオと、手順書の bats を追加する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 共通の子 issue 追加規則、親の注意書きの適用範囲、完了条件が無いエピックの開始手順を変更する。
- `dev-workflow-pr-review-gate`: failed の修正対象一覧を限定し、段 C・段 E の行き先が注意書きで変わらないことを固定する。

## Impact

- 実装対象は `plugins/dev-workflow/skills/develop/references/epic.md`、`references/epic-loop.md`、`skills/develop/SKILL.md`、`skills/pr-review-gate/stages/triage.md` と、既存の `develop-skill.bats`・`pr-review-gate-skill.bats`。段 C・段 E の本文は既に正しいため、各参照先には不要な変更を加えない。
- 既存の 2 capability の境界にある同じ振り分け規則を一緒に直す。独立して提供する機能の追加ではなく、受け入れ条件 4 つで一貫性を確かめる単一 change とする。
- #1647 の追加済み子の起動前確認・主の承認範囲・状態表は対象外。#1770・#1285 の SKILL.md の段落、#1410 の照合の手順 2 は変更しない。
- 起動スクリプト・GitHub API・ラベル・マージ方法・予算ファイルは変更しない。
