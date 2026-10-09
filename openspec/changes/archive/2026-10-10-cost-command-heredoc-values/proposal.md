## Why

issue #780・#796（#729 / PR #774 のレビュー指摘）。`/cost` のコマンド本文は、置換された台帳パスを `'...'` で包み、置換されたプラグインのルートを二重引用符の中に直接置いている。`'` を含むパスで別の台帳ができ、`$(...)` を含むルートで探索先が変わる。

## What Changes

- 置換値を引用した here-document でシェル変数に読み込んでから使う（`commands/cost.md`）
- spec の「`/cost` はプラグイン設定の台帳パスを使う」に、「改行を含まない置換値をシェルの構文として解釈しない」（改行を含む値と区切り語と同じ行を含む値は対象外）を加え、「コマンド本文が値を渡している」シナリオの THEN を新しい渡し方に合わせ、特殊文字を含む台帳パスとルートのシナリオを足す
- 「値を環境変数として渡す」「探索の先頭は置換された絶対パス」の規範の意味は変えない。コマンドの外から見た挙動（どの台帳を読むか・出力）も変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-cost-command`: 「`/cost` はプラグイン設定の台帳パスを使う」

## Impact

- `plugins/cost-ledger/commands/cost.md`・`README.md`・`tests/cost-command.bats`・`changes/729.md`・`changes/780.md`、`tests/command-plugin-root.bats`（ループ抽出）
