## Why

issue #718（PR #704 の仕様レビュー 4 周目の、マージを止めない指摘）。`cost-ledger-pricing` の要件「警告は 1 行目と終了コードを変えず、省くこともできる」のシナリオ「timeline は突き合わせない」の THEN は、`単価表のずれ:` を含む行が無いことだけを定めている。`timeline` が失敗して何も出さない場合にもこの THEN は通り得るので、成功して通常のコスト行を出すことを定める。実装は既にそう動く（`plugins/cost-ledger/tests/drift.bats` の「drift: timeline does not compare」が終了コード 0 と 1 行目の `コスト: ` を確かめている）。

## What Changes

- シナリオ「timeline は突き合わせない」に AND を 1 行足す: 終了コードは 0 で、出力の 1 行目は `コスト: ` で始まる通常のコスト行である
- 既存の MUST・SHALL・Scenario・THEN は 1 文字も変えない。スクリプト・テストも変えない（足した AND に対応する検査は既存のテストにある）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-pricing`: 「警告は 1 行目と終了コードを変えず、省くこともできる」（シナリオ「timeline は突き合わせない」に AND を 1 行足す。要件の本文は変えない）

## Impact

- `openspec/specs/cost-ledger-pricing/spec.md` の 1 行の追加だけ。実行物は変えない
