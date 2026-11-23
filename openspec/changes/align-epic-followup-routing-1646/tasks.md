# Tasks

行番号は仕様づくり時点の main `700c4941`。編集前に該当範囲を読み直す。#1647 と並行 PR の対象段落には手を出さない。各グループで手順と対応するテストを一緒にそろえる。

## 1. エピックの子にする境界をそろえる

- [x] 1.1 epic.md の共通規則と SKILL.md の「エピックの注意書き」・参照案内を直す。レビュー由来は G の結果を保ち、範囲外の問題も段 C で完了条件に効くものだけを子にできること、効かないものは注意書きによらず段 D・段 E に進むことをそろえる。epic.md の「すべて従う」にも置き場所の例外を入れ、投稿者の検査と対象外・取得不能の扱い、対象コメントの W・R1・G への引継ぎは維持する。develop-skill.bats に境界・注意書き・外の issue の検査を追加し、起動し直した子でも対象コメントを引き継ぎつつ効かない問題を子にしないシナリオと照合する。`bats plugins/dev-workflow/tests/develop-skill.bats` が終了コード 0。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:43-50（注意書き・両方式に共通）、plugins/dev-workflow/skills/develop/SKILL.md:73-77（範囲外の問題の起票）・251-261（参照案内）、plugins/dev-workflow/tests/develop-skill.bats:535-575・1092-1111

## 2. 完了条件が無いエピックの開始を補う

- [x] 2.1 epic-loop.md の両方式共通の開始手順に、完了条件の節が無ければ本文から決めて子の起動前に本文に記すこと、本文だけで決まらないときだけ主に聞くことを書く。develop-skill.bats で「本文から決まる」「主への問いが必要」「既に節がある」の 3 場合と子の起動より前であることを検査し、`bats plugins/dev-workflow/tests/develop-skill.bats` が終了コード 0。#1768 の待機案内と #1647 の途中追加された子の確認・状態表は触らない。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:1-7（開始時、経路ごとの起動の前）、plugins/dev-workflow/tests/develop-skill.bats:535-575（エピックの検査）

## 3. W に戻すレビュー指摘を限定する

- [x] 3.1 triage.md の 1 周目の failed の説明と仕分け表の順 1 を直し、W の修正対象一覧に載せるのは止める指摘と段 A の指摘だけとする。段 A に当たらない止めない指摘は任意の修正候補としても渡さず、G の振り分けの記録に残し、段 B 以降を当てる時点は維持する。pr-review-gate-skill.bats に混在時の一覧の検査を追加し、`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が終了コード 0。#1410 の照合の手順 2 は触らない。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:17-27（failed の一覧・順 1）、plugins/dev-workflow/tests/pr-review-gate-skill.bats:677-725（段 A の境界の検査）
- [x] 3.2 pr-review-gate-skill.bats に、段 C「効かない」→段 D「候補なし」→段 E「見合う」の行き先が外の issue であることと、develop の注意書き・共通規則がそれを子へ変えないことを検査する回帰テストを追加する。同じ場所の候補があれば参考コメントで受け入れ条件を膨らませない場合と、段 C で効く問題の従来の行き先も保つ。対応する delta spec のシナリオと照合し、`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-skill.bats` が終了コード 0。段 C・段 E の本文は既に正しく、不要な変更はしない。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:811-883、plugins/dev-workflow/skills/pr-review-gate/stages/triage-epic.md:5-18（読み合わせ）、plugins/dev-workflow/skills/pr-review-gate/stages/triage-nonblocking.md:47-51（段 D・段 E の読み合わせ）

## 4. 統合の確認と変更の記録

- [x] 4.1 issue の受け入れ条件 4 つと変更した手順・回帰テストを照合する。完了条件の補完・全周共通の判定・段 D／段 E の 3 要件について、入力元・拾う誤り・許容する具体例・保証の限界と実装が食い違わず、全面的な意味検査を追加していないことを確認する。既存の注意書き引継ぎ要件の MODIFIED と epic.md を照合し、投稿者の検査・引継ぎを維持しつつ置き場所指定の例外を適用し、「すべて従う」だけの規定が同期後に残らないことを確かめる。`openspec validate align-epic-followup-routing-1646 --type change --strict`、`bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/epic-dispatch.bats tests/develop-startup-budget.bats tests/injection-budget.bats tests/develop-epic-scene-budget.bats`、`git diff --check` がすべて終了コード 0。本体の判断に従い、新規段落を短縮しても超える場面だけ `tests/develop-epic-scene-budget.txt` を実測値に合わせる。`tests/injection-budget.txt` は変更しない。触る範囲: openspec/changes/align-epic-followup-routing-1646/specs/dev-workflow-develop/spec.md:1-264、openspec/changes/align-epic-followup-routing-1646/specs/dev-workflow-pr-review-gate/spec.md:1-106（シナリオ・守備範囲との照合。追加編集は必要時のみ）、openspec/specs/dev-workflow-develop/spec.md:2042-2136（既存要件との照合）
- [x] 4.2 plugins/dev-workflow/changes/1646.md に、完了条件による振り分け、開始時の補完、W に渡す指摘の境界と確認したテストを記録する。issue #1646 の範囲だけであることを差分で確かめる。触る範囲: plugins/dev-workflow/changes/1646.md（新規）

4.1 の指定検査は場面別予算を含む 6 ファイルで 1,188 件、exit 0。注意書きの境界本文を共通規則へ集約し、開始時の補完手順も短縮した。本体の判断に従い、なお超過した 11 場面だけ予算を実測値へ更新した（余白 0 バイト）。既存シナリオと守備範囲の境界を保ち、指定外の段落と `tests/injection-budget.txt` は変更していない。

## Workflow follow-up

- 本体が独立した R1 を起こし、issue #1646 に APPROVE が記録されるまで実装しない。
- 後続の実装対象は 5 ファイルを超える見込み。規模超過の扱い・分割は本体が判断する。W が独自に範囲を削ったり子 issue を増やしたりしない。
- 実装と必要なレビュー後、finish 工程で archive し、delta を main spec に同期する。注意書き引継ぎ要件の置き場所指定の例外も同期し、投稿者の検査と引継ぎを保つ。触る範囲: openspec/specs/dev-workflow-develop/spec.md:203-257・2042-2136・2194-2265、openspec/specs/dev-workflow-pr-review-gate/spec.md:414-437・1984-2023・2206-2221、openspec/changes/align-epic-followup-routing-1646/（archive）
- PR・仕様宣言・ゲート・マージの遷移は本体が進める。この spec 工程では実装・archive・merge をしない。
