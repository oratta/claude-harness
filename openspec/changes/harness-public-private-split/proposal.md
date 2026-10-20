## Why

エピック #1127 で Claude Harness を公開版（今の `oratta/claude-harness`）と個人版（新しい private リポジトリ）に分けると決めた（2026-10-20 オーナーの決定）。切り出し（#1129）・配る規則からの固有記述の除去（#1098）・capability-registry の索引の二重案内の整理（#1105）は、どの部品がどちらに行くかが決まっていないと着手できない。flatmate #1615 側でも、版固定で写す前提の子（flatmate #1618・#1637・#1633 ほか）が保留のまま残っている。

## What Changes

- Harness の部品（`rules/*.md`・`output-styles/*.md`・`.claude-plugin/marketplace.json` に載る各プラグイン・リポジトリ直下の `scripts/` の各項目、プラグインの hooks はそのプラグインの行に含める）を「公開版／個人版／保留（#1123 の後）」に仕分け、理由つきの表を `docs/public-private-split.md`（新規）に置く
- 1 つのプラグインの中で行き先が分かれる部品（capability-registry、エピック実行まわりを含む dev-workflow など）は、プラグインの行の下に部品ごとの行を足して分ける
- capability-registry の扱いを決め、選ばなかった案と理由を表の文書に残す
- 公開版に残る部品の中の、固有名（オーナーのプロジェクト名・アカウント名・保管庫名など）とオーナーの環境に依存する記述（固定パス・オーナーだけが持つ道具への参照など）の一覧を同じ文書に置く。#1098・#1105 と、capability-registry の公開版から fmtoken の参照を外す #1164（既存の issue の範囲に収まらないため本体が起票した）の作業範囲になる
- 表と一覧の網羅を確かめる bats テスト `tests/public-private-split.bats`（新規）を足す
- 仕分けの結果に合わせて、flatmate #1615 の 2026-10-20 のコメントの表にある保留の子（flatmate #1618・#1637・#1633・#1631・#1616・#1628・#1629・#1634・#1630・#1636、claude-harness #1098・#1105）それぞれの「閉じる・作り直す・そのまま進める」を #1615 にコメントする
- コードは動かさない（部品の移動・書き換えは #1129・#1098・#1105・#1164 で行い、既存仕様 `capability-registry-browser-guard`・`capability-registry-skill` の要件の更新も #1164 の change で行う）

## Capabilities

### New Capabilities
- `harness-public-private-split`: Harness の部品ごとの公開版／個人版／保留の仕分けの表と、公開版に残る部品の固有記述の一覧が、どの部品も漏らさず理由つきで文書にあること

### Modified Capabilities
（なし）

## Impact

- 新規: `docs/public-private-split.md`、`tests/public-private-split.bats`
- 既存の部品・hooks・スクリプトの動作は変わらない
- 後続: #1098（一覧が作業範囲）、#1105（capability-registry の置き場が前提）、#1129（表どおりに移す）、#1130
- 外部: flatmate #1615（genetta-inc/flatmate）への判断コメント 1 件
