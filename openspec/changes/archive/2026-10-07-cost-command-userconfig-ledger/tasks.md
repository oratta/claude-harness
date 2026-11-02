行番号は仕様づくりの時点（HEAD d2d15fc0）の値。前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。

## 1. テストを先に書く

- [x] 1.1 `tests/userconfig.bats` に、`ledger_path()` の置換されなかったプレースホルダの扱いを 1 件ずつ足す: `CLAUDE_PLUGIN_OPTION_LEDGER_PATH='${user_config.LEDGER_PATH}'` と `COST_LEDGER_PATH` を設定して `ledger-sync` を実行すると `COST_LEDGER_PATH` のパスに追記され `${user_config.LEDGER_PATH}` という名前のファイルは作られない／プレースホルダだけで `COST_LEDGER_PATH` が未設定なら台帳は作られず終了コード 0（`cost` は会話ログ直読み）。既存テストの書き方（`load helper`、`cl_row`、`$BATS_TEST_TMPDIR`）に合わせ、書く前に `tests/bats-assertion-guard.bats` を読んでアサーションの制約に合わせる。触る範囲: plugins/cost-ledger/tests/userconfig.bats:1-30（先頭と既存テストの書き方）、末尾に追記
- [x] 1.2 `tests/cost-command.bats` に、`commands/cost.md` の集計呼び出しが `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` に `${user_config.LEDGER_PATH}` を渡していること、未設定時の案内で `/config` が `settings` より先に出ること（`grep -n` の行番号の前後比較）を確かめるテストを足す。触る範囲: plugins/cost-ledger/tests/cost-command.bats:125-130（cost.md の存在を見ている既存テストの近く）
- [x] 1.3 `bats plugins/cost-ledger/tests/userconfig.bats plugins/cost-ledger/tests/cost-command.bats` を走らせ、足したテストが落ちることを確かめる。触る範囲: なし（実行のみ）

## 2. `ledger_path()` をプレースホルダに対応させる

- [x] 2.1 `ledger_path()` を、`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` の値が `${user_config.` で始まるときは空文字と同じに扱い、`COST_LEDGER_PATH` に落ちる形に直す。判定の理由を 1〜2 行のコメントで添える（未設定のとき `/cost` の本文が置換されなかった文字列を渡すため）。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:588-592（LEDGER_OPTION_ENV の定義とコメント）、650-651（ledger_path）

## 3. `/cost` の本文を直す

- [x] 3.1 集計呼び出しを `CLAUDE_PLUGIN_OPTION_LEDGER_PATH='${user_config.LEDGER_PATH}' python3 "$CL" cost $ARGUMENTS` に変える。本文中の説明文で `${user_config.LEDGER_PATH}` と書くと置換されるので、説明では「プラグイン設定の台帳ファイルのパス」と書く。触る範囲: plugins/cost-ledger/commands/cost.md:14-26（実行の節のコードブロック）
- [x] 3.2 冒頭の説明文（7 行目）と「台帳」の節を、`COST_LEDGER_PATH` だけを前提にした書き方からプラグイン設定を含む書き方に直す。未設定時の案内は、台帳の置き場所を聞く（既定の場所は決めない・リポジトリ配下は不可・`'` を含まないパス）→ `/config` のプラグイン設定「台帳ファイルのパス」への設定を先に案内 → 従来の `~/.claude/settings.json` の `env` の `COST_LEDGER_PATH` も使えると添える → 初回の取り込みに `ledger-sync` を実行、の順にする。触る範囲: plugins/cost-ledger/commands/cost.md:7、33-41（台帳の節）
- [x] 3.3 `grep -n "settings" plugins/cost-ledger/commands/cost.md` の未設定時の案内が `/config` より後ろにあること、タスク 1 のテストが通ることを確かめる。触る範囲: なし（実行のみ）

## 4. README と変更記録

- [x] 4.1 README の「既知の制限」の 1 行（「`/cost` のコマンド本文の Bash 実行にプラグイン設定の環境変数が渡るかは未確認…」）を、観測結果（環境変数は渡らないので本文の置換値を渡している。パスに `'` を含めない）に置き換える。5 行目の導入文も合わせる。触る範囲: plugins/cost-ledger/README.md:5、205-218（台帳の節）
- [x] 4.2 `plugins/cost-ledger/changes/729.md` を新しく書く（何を変えたか・実機の観測の要約・戻し方・LLM を使わない旨・テストの件数）。`plugins/cost-ledger/changes/713.md` の書式に合わせる。触る範囲: plugins/cost-ledger/changes/729.md（新規）

## 5. 検証

- [x] 5.1 `scripts/test.sh` が exit 0、`claude plugin validate plugins/cost-ledger` がエラー 0 であることを確かめる。触る範囲: なし（実行のみ）
- [x] 5.2 実機の確認: `COST_LEDGER_PATH` を設定せず、一時の settings（`--settings` の `pluginConfigs.cost-ledger.options.LEDGER_PATH`、リポジトリ外のパス）だけで `claude -p --plugin-dir plugins/cost-ledger` を使う。台帳から読んだことを会話ログ直読みと区別するため、(a) 1 回目の `/cost` で台帳が作られ行が入ったことを確かめ、(b) `CLAUDE_CONFIG_DIR` を空の会話ログのディレクトリに向けるなど会話ログを読めない状態にして 2 回目の `/cost` を実行し、それでも金額が出る（台帳から読んでいる）ことを見る。対照として、プラグイン設定なしの同じ条件では金額が 0 か見つからない扱いになることを確かめる。結果を issue #729 にコメントする（ユーザーのグローバル設定は変えない）。触る範囲: なし（実行のみ）
