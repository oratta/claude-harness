## 1. spec

- [x] 1.1 シナリオ「timeline は突き合わせない」に AND「終了コードは 0 で、出力の 1 行目は `コスト: ` で始まる通常のコスト行である」を足す。触る範囲: openspec/specs/cost-ledger-pricing/spec.md の当該シナリオ

## 2. 確認

- [x] 2.1 `openspec validate --specs --strict` と `tests/openspec-specs-format.bats` が通る
- [x] 2.2 `tests/drift.bats` の「drift: timeline does not compare」が `env -u COST_LEDGER_PATH` で両ロケール通る
- [x] 2.3 `git diff origin/main -- openspec/specs` の増減が足した AND の 1 行だけである
