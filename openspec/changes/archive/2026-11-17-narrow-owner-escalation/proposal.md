# Proposal: 主への判断依頼を論点のあるものに絞り、エピックの親が論点のない止まりを引き取る

## Why

「論点」の決まり（#1209）は主への聞き方を変えただけで、主に聞くかどうかの判定は変えていない。ゲートのリスク宣言は分類に当たれば論点なしでも主の OK を必須にし、親が通す基準は「迷ったら主に上げる」「通してよい止まりを主に上げることは許す」と定めている。その結果、2026-11-10 以降の判断依頼 22 件のうち 9 件で主が「論点は？」と聞き返し、主が一括で任せたあとでも親の送った許容を子のゲートが 2 回はじいた（flatmate #2058、11/9。1 回目は `--relayed` の `not-asked`、2 回目は `--delegated` の `not-direct`）。記録先は issue #1653。

## What Changes

- ゲート: リスク宣言が「論点なし」のとき、主ではなく、エピックの子かどうかによらず決める役（`dev-workflow:decider`）の確認で合格処理に進む経路を足す。develop では G が新しい Status で本体に返し、本体が決める役を起こす。PR に「誰が通したか・論点なしの根拠」の記録を残す。論点ありは今までどおり主に上げる
- 親が通す基準: 「迷ったら成り立つ側に倒す」と「通してよい止まりを主に上げることを許す」を消し、「主に上げるのは 3 つの理由のどれかを根拠つきで示せたときだけ」にする。委任の無いセッションでは聖域・破壊的操作・マージを通さない条件を残す
- 誤判定の防止: 「主の側にしか答えが無い」とする前の 3 つの確かめ（調べれば分かる事実でないか・主の手が要る操作か手順書で確かめたか・推奨と根拠がそろっていないか）と、通らない例 3 件（11/16・11/12・11/13）を親の基準と子の止まりの手順に置く
- 委任（旧 #1550 を統合）: 主の決定（線は論点の有無で引き、種類による例外は置かない https://github.com/genetta-inc/flatmate/issues/1796#issuecomment-6551902839 ）に沿い、委任の記録があるときは論点なしのリスク許容・聖域の変更・破壊的な git 操作・マージ待ちの止まりを親が進める（マージ待ちは既存の `parent-merge-approved` の経路に乗せ、同じ HEAD の論点なしの確認を条件にする。委任が無いときは論点なしの確認だけでマージに回さない）。委任があっても論点ありの止まりは主に上げる
- `owner-reply-check.sh --delegated`: 11/9 の形（親が委任の記録の URL を見せたあと、主が別の発言を挟んでから任せる旨を述べた）を受理する。**安全側の確かめを緩める変更**（設計の D4）
- 論点の定義: 「運用の形・構造の分け方・将来の拡張に効く設計の分かれ目」を主の観点として足し、扱いは主を止めずに決めた内容と他の案を報告に載せる
- 判例と報告: 主に上げた件・主の聞き返しを受けた件を判例台帳に記録する契機を親の手順に書き、親の報告に「親の判断で通した PR・止まり」の一覧を載せる

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 論点なしのリスク宣言を決める役の確認で通す経路と記録
- `dev-workflow-develop`: 親が通す基準の原則・迷ったとき・誤判定の防止、委任の範囲を論点の有無で引き直す、子の止まりの確かめ、判例の記録の契機、親の報告の一覧
- `dev-workflow-owner-reply-check`: `--delegated` の並び順の判定
- `owner-question-style`: 論点の定義に主の観点（運用の形・構造の分け方・将来の拡張）と、止めずに報告する扱いを足す

## Impact

- 文書: `plugins/dev-workflow/skills/pr-review-gate/declarations.md`・`stages/hold.md`・`stages/pass.md`、`plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md`・`epic.md`・`epic-child-stop.md`、`output-styles/readable.md` 節 3、`rules/communication-style.md`、`plugins/casting/skills/casting/SKILL.md`（判例の契機を casting 側に置く場合のみ）
- スクリプト: `plugins/dev-workflow/scripts/owner-reply-check.sh`
- テスト: `tests/owner-question-style.bats`、`plugins/dev-workflow/tests/owner-reply-check.bats`・`owner-reply-delegated-scenario.bats`・`owner-reply-relayed-scenario.bats`、ゲートの経路を確かめる bats（既存の `pr-review-gate-skill.bats` に足す）
- 聖域: `rules/`・`output-styles/`・ゲートの規則・常時注入の予算に触れるので、PR は主のレビューとマージを通す。`rules/communication-style.md` は常時注入なので `tests/injection-budget.bats` の予算に収める
- 変更の記録: `plugins/dev-workflow/changes/1653.md`（版は上げない）
- `.github/workflows/auto-merge.yml` は変えない（聖域に触れた PR のマージは既存の `parent-merge-approved` の印の経路に乗せる）
