# Proposal

## Why

担当別監査では手渡し番号付きの接頭辞が unknown になり、別プロジェクトの同じ記録先番号が読み直し率に混ざる。issue #564 の受け入れ条件に合わせ、観測値の分類と仕様の説明を揃える。

## What Changes

- description の担当名に続く手渡し番号を許容し、担当名を正規表現のグループから取り出す。
- 読み直し率をプロジェクト識別子と記録先番号の組で集計する。
- python3 不在時の fail-open と既定呼び出しの数値を回帰テストで固定する。
- 全文走査を使う担当別呼び出しと、部分読みの既定呼び出しの差を明記する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-execution-strategy`: 母集団集計・担当別出力・担当分類・読み直し率の既存要件を明確化する。

## Impact

対象は `plugins/dev-workflow/scripts/subagent-context-audit.sh`、同プラグインの tests と変更記録、および本 change の仕様差分。観測専用のままとし、起動フック・強制停止・version は変更しない。現行 spec への反映は archive で行う。
