# Proposal

## Why

マージ待ちの子について親が決める役に渡す入力文は、`plugins/dev-workflow/scripts/parent-merge-inputs.sh` の `section()` が組み立てる。`section()` は各節を `## <見出し>` と本文をそのまま並べて出す。PR の作成者が差分や PR 本文に `## 委任の記録の候補` のような行を書くと、決める役からは、後ろにある信頼できる節（委任の記録・注意書き）と見分けがつかない。決める役の判断を誘導できる穴になる（#1753。自動セキュリティ検査の指摘で、深刻度 medium）。

## What Changes

- 入力文の 2 行目に、実行ごとに作る乱数を `区切り: <乱数>` で宣言する
- 各節の本文を `<<<本文 <乱数>` と `本文 <乱数>>>>` の行で囲む。見出しは区切りの外にだけ出す
- 集めた値が乱数を含んでいたら、stdout を空にして exit 1 にする
- 決める役の基準 `parent-merge-criteria.md` に、区切りの外の見出しだけを節として読むことを書く

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「parent-merge-inputs.sh はマージ待ちの子の前提を確かめ、決める役への入力文を組み立てる」に、区切りの形と Scenario を足す

## Impact

- `plugins/dev-workflow/scripts/parent-merge-inputs.sh`
- `plugins/dev-workflow/tests/parent-merge-inputs.bats`
- `plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md`
- 1 行目の `HEAD:`、節の見出しの名前、`（なし）` の書き方、exit code の意味は変えない
