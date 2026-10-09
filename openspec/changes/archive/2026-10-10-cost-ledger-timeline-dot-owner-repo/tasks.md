## 1. spec

- [x] 1.1 「対象の解決」の、リポジトリを決める順の段落の次に、owner / repo が `.` か `..` の対象を飛ばす文を足す。触る範囲: openspec/specs/cost-ledger-timeline/spec.md:91
- [x] 1.2 同じ要件の守備範囲に、位置引数の URL にはこの定めが掛からないことを足す。触る範囲: openspec/specs/cost-ledger-timeline/spec.md:95
- [x] 1.3 Scenario を 2 つ足す（`.` / `..` の対象は飛ばす・名前の中に `.` を含むだけなら飛ばさない）。触る範囲: openspec/specs/cost-ledger-timeline/spec.md:135-138

## 2. 確認

- [x] 2.1 足した文と Scenario が、`find_triggers()` の実測と `gate-report.bats` の既存のテスト 2 本に合う
- [x] 2.2 `openspec validate --specs --strict` と `tests/openspec-specs-format.bats` が通る
