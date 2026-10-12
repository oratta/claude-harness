## 1. コマンド本文

- [x] 1.1 台帳パスの置換値を `IFS= read -r` と引用した here-document で読み、`CLAUDE_PLUGIN_OPTION_LEDGER_PATH="$LEDGER_OPTION"` で渡す
- [x] 1.2 プラグインのルートの置換値を同じ形で読み、置換されないとき（`$` で始まる）は空にする
- [x] 1.3 `'` を禁じる注意書き（cost.md・README・changes/729.md）を外す

## 2. テスト

- [x] 2.1 `tests/cost-command.bats` に、cost.md の bash ブロックを置換して実行するテストを足す
- [x] 2.2 `tests/command-plugin-root.bats` のループ抽出を here-document の形に対応させる

## 3. 文書

- [x] 3.1 `plugins/cost-ledger/changes/780.md`
