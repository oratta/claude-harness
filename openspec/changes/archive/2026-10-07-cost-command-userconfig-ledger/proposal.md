## Why

#713 で台帳の置き場所を userConfig の `LEDGER_PATH`（`/config` で設定）にできるようにしたが、`/cost` のコマンド本文の Bash 実行にその値が届くかは未確認だった。実機（Claude Code 2.1.292、`claude -p --plugin-dir`）で確かめた結果、**Bash 実行には `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が渡らない**（`CLAUDE_PLUGIN_ROOT` も渡らない）。一方、コマンド本文の中の `${user_config.LEDGER_PATH}` は読み込み時に設定値へ置換され、未設定のときは置換されず文字列のまま残る（観測は issue #729 のコメントに記録済み）。

このため `/config` だけで設定した人は、Stop hook は台帳に追記するのに `/cost` は台帳を読まず会話ログを直接読む。`commands/cost.md` の未設定時の案内も、settings.json の `env` に手で書く手順のままである。

## What Changes

- `commands/cost.md` の集計呼び出しで、本文の `${user_config.LEDGER_PATH}` の置換値を環境変数 `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` として `cost_ledger.py` に渡す
- `cost_ledger.py` の `ledger_path()` は、未設定時に置換されず残った文字列（`${user_config.` で始まる値）を未設定として扱う
- `commands/cost.md` の未設定時の案内を、`/config` での設定を先に、従来の `COST_LEDGER_PATH`（settings.json の `env`）を次に案内する形に書き換える
- `README.md` の「既知の制限」の 1 行を、観測結果と対処に合わせて直す
- `cost-ledger-persistence` の要件にある「`/cost` に渡るかは保証しない」の一文を、渡し方の保証に置き換える

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-cost-command`: `/cost` は userConfig の `LEDGER_PATH` だけが設定されていても台帳から読む。未設定時の案内は `/config` を先に示す
- `cost-ledger-persistence`: `ledger_path()` が置換されず残ったプレースホルダを未設定として扱う。`/cost` に値が渡ることの保証を足す

## Impact

- 触るファイル: `plugins/cost-ledger/commands/cost.md`、`plugins/cost-ledger/scripts/cost_ledger.py`、`plugins/cost-ledger/README.md`、`plugins/cost-ledger/tests/cost-command.bats`、`plugins/cost-ledger/tests/userconfig.bats`、`plugins/cost-ledger/changes/729.md`（新規）
- `COST_LEDGER_PATH` だけの利用者の動きは変わらない
- plugin.json の `description` は変えない（常時注入の予算は動かない）。`version` は上げない
