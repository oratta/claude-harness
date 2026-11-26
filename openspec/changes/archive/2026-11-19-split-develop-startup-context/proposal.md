# Proposal

## Why

`/develop` の本体は起動時に約 6.3 万字を読むが、その中にゲート結果への対処や拒否からの復旧など、必要になる場面が限られる手順と同じ規則の再掲がある。#1685（親 #1682）の方針どおり、動きを変えず、常に要る規則と場面限定の詳細を分け、再増加を予算で止める。

## What Changes

- SKILL.md の PR トークン上限、G の結果別分岐、W の空 return／破壊的 git 操作の拒否への対処を、develop 配下の三つの reference へ移す。本体には読む場面と必読の参照を残す。
- provider の役割解決・起動／再開の規則は既存の `plugins/dev-workflow/references/codex-develop.md` に一元化し、SKILL.md と commands/develop.md および同 reference 内の重複を参照へ置き換える。
- 例・経緯・他の正本と同文の説明を削除または参照化する。役割表、本体の禁止事項、工程順、読み直しの指示を SKILL.md の先頭 5,000 トークン以内に置く。
- 文言検査は develop の手順書集合内で規則の存在を確認し、入口の参照と条件付き読込・予算は別の構造検査で守る。起動時の三つの予算を実測まで下げ、切り出したファイルにも予算を付ける。
- 移動元の節を名指ししている既存仕様を新しい配置へ合わせる。判定条件、入出力、権限、工程の順序は変えない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 起動時に残す規則、場面限定の本体手順の配置、役割解決の参照、文言検査・字数予算と証拠の契約を定める。移動元を名指しする要件とシナリオを更新する。
- `dev-workflow-pr-token-budget`: 本体の計測・消費記録の規則を SKILL.md 本文から専用 reference に移し、必読指示から到達させる。
- `dev-workflow-spec-review`: 上限超過時の手順の参照先を専用 reference に更新する。
- `dev-workflow-pr-review-gate`: `条件の確認待ち` の通知を担う本体の分岐の参照先を更新する。ゲート自身の手順は変更しない。

## Impact

主対象は `plugins/dev-workflow/skills/develop/SKILL.md`、`commands/develop.md`、`references/codex-develop.md`、develop 配下の新規 reference 三つ、関連 bats、起動時と切り出し後の予算、および上記四 capability の位置を指定した文。変更記録は `plugins/dev-workflow/changes/1685.md`、測定の記録は後続の PR 本文と親 #1682 のコメントへ置く。

`skills/pr-review-gate/` と `skills/develop/references/roles/gate-runner.md` は本文を変更しない。#1686 のスクリプト化、#1693〜#1695 のエピック手順・テスト・仕様整理も対象外。今回は proposal / design / tasks / spec delta のみを commit・push し、実装とレビュー・archive は後続工程へ渡す。
