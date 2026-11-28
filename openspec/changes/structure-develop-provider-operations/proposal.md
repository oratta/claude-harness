# Proposal
## Why
#1856 の共有手順に本体固有の操作が散在し、Codex 本体では実行できない。主の返事に従い、12 本の既存分割案を採らず、規約の構造化を実測比較してから移行を設計する。
## What Changes
- 操作台帳と Claude/Codex の対応 2 ファイルを設け、共有本文は操作名で参照する（案 Y）。工程順・独立レビュー・承認・消費上限を維持する。
- 全対象の固定台帳、本文・実際の出力・操作集合の検査と負例検査を設ける。
- `$develop` と `/develop` の共通入口を一つにし、Codex のエピック番号は #1855 導入まで理由付き停止とする。
- Claude 本体の実機 1 件で Draft PR 作成とゲート通過を確認し、既存 bats/Python 回帰と変更記録を揃える。
## Capabilities
### New Capabilities
- `develop-provider-operations`: 本体別操作の一元化、対象一覧と本文・生成出力のずれ防止、移行完了の証拠。
### Modified Capabilities
- `dev-workflow-issue-entry`: 共通入口の置き場と Codex の呼出し、既存 5 分岐・alias・issueify 解決を維持。
- `manual-codex-develop`: adapter の参照先を本体別操作まで含め、host と role executor を区別する。
## Impact
対象は design.md の固定 HEAD の 87 パスと新設契約・入口・検査。聖域の変更は別 group にする。この工程の編集は本 change 内だけ。#1850 の Orca 検証、#1855 のエピック実行、#1857 の起動 transport は実装しない。子 issue は本体がレビュー後に判断し、この工程では作らない。
