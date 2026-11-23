# Tasks

行番号は仕様づくり時点の main `700c4941`。編集前に該当範囲を読み直す。#1647 と並行 PR の対象段落には手を出さない。各グループで手順と対応するテストを一緒にそろえる。

## 1. エピックの子にする境界をそろえる

- [ ] 1.1 epic.md の共通規則と SKILL.md の「エピックの注意書き」・参照案内を直す。レビュー由来は G の結果を保ち、範囲外の問題も段 C で完了条件に効くものだけを子にできること、効かないものは注意書きによらず段 D・段 E に進むことをそろえる。develop-skill.bats に境界・注意書き・外の issue の検査を追加し、`bats plugins/dev-workflow/tests/develop-skill.bats` が終了コード 0。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:45-50（注意書き・両方式に共通）、plugins/dev-workflow/skills/develop/SKILL.md:73-77（範囲外の問題の起票）・251-261（参照案内）、plugins/dev-workflow/tests/develop-skill.bats:535-575・1092-1111

## 2. 完了条件が無いエピックの開始を補う

- [ ] 2.1 epic-loop.md の両方式共通の開始手順に、完了条件の節が無ければ本文から決めて子の起動前に本文に記すこと、本文だけで決まらないときだけ主に聞くことを書く。develop-skill.bats で「本文から決まる」「主への問いが必要」「既に節がある」の 3 場合と子の起動より前であることを検査し、`bats plugins/dev-workflow/tests/develop-skill.bats` が終了コード 0。#1768 の待機案内と #1647 の途中追加された子の確認・状態表は触らない。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:1-7（開始時、経路ごとの起動の前）、plugins/dev-workflow/tests/develop-skill.bats:535-575（エピックの検査）

## 3. W に戻すレビュー指摘を限定する

- [ ] 3.1 triage.md の 1 周目の failed の説明と仕分け表の順 1 を直し、W の修正対象一覧に載せるのは止める指摘と段 A の指摘だけとする。段 A に当たらない止めない指摘は任意の修正候補としても渡さず、G の振り分けの記録に残し、段 B 以降を当てる時点は維持する。pr-review-gate-skill.bats に混在時の一覧の検査を追加し、`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が終了コード 0。#1410 の照合の手順 2 は触らない。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:17-27（failed の一覧・順 1）、plugins/dev-workflow/tests/pr-review-gate-skill.bats:677-725（段 A の境界の検査）
- [ ] 3.2 pr-review-gate-skill.bats に、段 C「効かない」→段 D「候補なし」→段 E「見合う」の行き先が外の issue であることと、develop の注意書き・共通規則がそれを子へ変えないことを検査する回帰テストを追加する。同じ場所の候補があれば参考コメントで受け入れ条件を膨らませない場合と、段 C で効く問題の従来の行き先も保つ。対応する delta spec のシナリオと照合し、`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-skill.bats` が終了コード 0。段 C・段 E の本文は既に正しく、不要な変更はしない。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:811-883、plugins/dev-workflow/skills/pr-review-gate/stages/triage-epic.md:5-18（読み合わせ）、plugins/dev-workflow/skills/pr-review-gate/stages/triage-nonblocking.md:47-51（段 D・段 E の読み合わせ）

## 4. 統合の確認と変更の記録

- [ ] 4.1 issue の受け入れ条件 4 つと変更した手順・回帰テストを照合し、`openspec validate align-epic-followup-routing-1646 --type change --strict`、`bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats tests/develop-startup-budget.bats tests/injection-budget.bats`、`git diff --check` がすべて終了コード 0。予算値は変更しない。触る範囲: openspec/changes/align-epic-followup-routing-1646/specs/dev-workflow-develop/spec.md:1-161、openspec/changes/align-epic-followup-routing-1646/specs/dev-workflow-pr-review-gate/spec.md:1-102（シナリオとの照合。追加編集は必要時のみ）
- [ ] 4.2 plugins/dev-workflow/changes/1646.md に、完了条件による振り分け、開始時の補完、W に渡す指摘の境界と確認したテストを記録する。issue #1646 の範囲だけであることを差分で確かめる。触る範囲: plugins/dev-workflow/changes/1646.md（新規）

## Workflow follow-up

- 本体が独立した R1 を起こし、issue #1646 に APPROVE が記録されるまで実装しない。
- 後続の実装対象は 5 ファイルを超える見込み。規模超過の扱い・分割は本体が判断する。W が独自に範囲を削ったり子 issue を増やしたりしない。
- 実装と必要なレビュー後、finish 工程で archive し、delta を main spec に同期する。触る範囲: openspec/specs/dev-workflow-develop/spec.md:203-257・2194-2265、openspec/specs/dev-workflow-pr-review-gate/spec.md:414-437・1984-2023・2206-2221、openspec/changes/align-epic-followup-routing-1646/（archive）
- PR・仕様宣言・ゲート・マージの遷移は本体が進める。この spec 工程では実装・archive・merge をしない。
