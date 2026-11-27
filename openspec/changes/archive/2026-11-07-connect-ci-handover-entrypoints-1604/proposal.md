# Proposal

## Why

通常経路の CI 見張りには担当引き継ぎと起動前の無効化規則があるが、開始・ゲート failed 後の再開・無関係返却の入口から辿れない箇所が残る。#1604 の F1/F3/F4 を直し、情報不足による停止と古い許可による二人目の W の起動を防ぐ。

## What Changes

- ci-watch.md の開始手順から 7 冒頭の CI 用引き継ぎへ参照を追加する。
- develop/SKILL.md の failed 後の W 起動／再開と handover.md を読む場面から、「起動／再開前の無効化と再許可」へ接続する。最新が可なら不可の投稿成功後だけ指示する。
- handover.md の「修正後の待ちへ戻る前」に、今回の W が無関係と判断して push せず工程完了を返した後の `next --unrelated` 前を含める。今回の完了／停止確認を可の根拠にする規則を維持する。
- 関係 Bats で入口と正本の接続を検査し、変更記録を追加する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 通常経路の CI 担当引き継ぎの開始参照、failed 後の無効化参照、無関係返却後の再許可時点を明示する。

## Impact

対象は plugins/dev-workflow/references/ci-watch.md、plugins/dev-workflow/skills/develop/SKILL.md、同 references/handover.md、関係 Bats、既存 develop 仕様と plugins/dev-workflow/changes/1604.md。
起動時予算を超える場合は tests/develop-startup-budget.txt の該当行を追記の増加バイト数だけ上げ、PR 本文に理由と https://github.com/oratta/claude-harness/issues/1586 を書く。近くの既存文の圧縮や重複整理はしない。PR 本文には `Closes #1604` を書く。
#1596 / #1602 の軽い経路の関係確認・複数チェック無関係判定、#1549 の新たな停止確認許可経路は対象外。実エージェントの起動は検証に不要。

分割判定: 単一 change。受け入れ条件の三つの接続は同じ CI 担当引き継ぎの機能領域に閉じ、独立した新設計を要さず、一つの PR で完結する。
