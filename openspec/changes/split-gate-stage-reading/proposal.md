# Proposal

## Why

G は段ごとに新しく起動するが、全段で読む gate-runner.md に照合専用の規則が入り、段の手順にも別の場面の本文が混ざっている。#1682 の子 #1687 として、今の main（e10f0a9896d82d0b86c0f7a10becb70c4983bc63）から、動きを保ったまま読む場面と正本の置き場所を揃える。

## What Changes

- 共通の入口・Gate Result の共通欄を残し、三表、順 3、止めない指摘、持ち越し、真正性、文言合わせ、論点なしなどの本文を、条件が成り立ったときだけ読むファイルへ移す。
- 同じ規則の言い換えを正本への参照にし、命令に関係しない経緯だけを除く。従来経路等は呼び出し元不在を証明できなければ残す。
- 場所を固定した文言テストを手順書全体の検査へ変え、読むファイルの合計に段・条件別の予算を置く。宣言・return・Status・停止条件・コマンド・守備範囲は保存する。
- 移動先を名指しする既存の仕様と参照を更新し、段別の字数と移した段落の一覧を PR に残す。減少量やトークン削減目標では合否を決めない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 段の入口と条件付き詳細の配置、正本の所在、保存する契約、読む量の予算。
- `dev-workflow-develop`: G の共通指示と段別読み込み表、移動した本文の参照先、旧 15K トークン目標を字数記録へ置き換える。

2 つの既存 spec に配置の記述が跨るが、独立した機能の追加ではなく、同じゲートの読込配置 1 件を整合させる変更である。単一 change・単一 PR とし、追加の子 issue は作らない。

## Impact

- 主な編集範囲: plugins/dev-workflow/skills/pr-review-gate/ と skills/develop/references/roles/gate-runner.md、関係する bats、tests/ の新しい段別予算、上記 2 capability、changes/1687.md。
- develop/SKILL.md と epic.md 等は #1685 / #1684 の範囲。参照先のパス・節の付け替え以外は行わない。既存 injection-budget の値・description・CLI の動きは変更しない。
- 前提: dev-workflow 導入済み環境、gh と GitHub 読み書き権限、OpenSpec CLI、UTF-8 ロケール、bats。仕様レビュー APPROVE の後に実装へ進む。
- Draft PR は spec 段では作らず、finish で Closes #1687 を含む 1 本を作る。主がマージする。merge / auto-merge を実行しない。
- 同じ stages/ に触る open PR がある。競合一覧と実装前の確認は design.md に記録する。旧 PR #1436 は取り込まない。
