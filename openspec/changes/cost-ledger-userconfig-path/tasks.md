## 1. plugin.json に userConfig を宣言する

- [ ] 1.1 `userConfig.LEDGER_PATH`（`type: file`、`title`、`description`、`required: false`、`default` なし）を足す。`description`（トップレベル）は変えない。`claude plugin validate plugins/cost-ledger` がエラー 0 であることを確かめる（既存の警告は対象外）。触る範囲: plugins/cost-ledger/.claude-plugin/plugin.json:1-4（トップレベルの鍵の並び）

## 2. hook と python が新しい環境変数を読む

- [ ] 2.1 `ledger-hook.sh` で `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` を優先し、空なら `COST_LEDGER_PATH` を使い、見つけた値を `COST_LEDGER_PATH` に export して python に渡す。どちらも空なら今までどおり抜ける。冒頭のコメントも直す。触る範囲: plugins/cost-ledger/scripts/ledger-hook.sh:1-13
- [ ] 2.2 `cost_ledger.py` の `ledger_path()` を同じ優先順位にする（`LEDGER_ENV` の定数と、エラーメッセージの `%s` の出し分けを壊さない）。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:431-447、plugins/cost-ledger/scripts/cost_ledger.py:1670-1676

## 3. テスト

- [ ] 3.1 新規 bats（例 `plugins/cost-ledger/tests/userconfig.bats`）で、spec のシナリオ（hook の userConfig だけ・従来だけ・両方・空文字・どちらも無し、`/cost` が userConfig だけでも台帳から読む、plugin.json の宣言）を検証する。会話ログは `helper.bash` の合成ログを使い、実環境の台帳に触れない。触る範囲: plugins/cost-ledger/tests/userconfig.bats（新規）、plugins/cost-ledger/tests/helper.bash:11-22（`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` も unset する）
- [ ] 3.2 `scripts/test.sh` が exit 0 であること、`claude plugin validate plugins/cost-ledger` がエラー 0 であることを確かめる

## 4. 文書と変更の記録

- [ ] 4.1 README の「台帳」の節に、有効化時の入力と `/config` で設定できること（`/config` の行は Claude Code v2.1.269 以降が前提。それ未満は有効化時の入力と env 手書きのみ）、`COST_LEDGER_PATH` が後方互換で残ること、優先順位、`/cost` に値が渡らない環境での既知の制限を書く。触る範囲: plugins/cost-ledger/README.md:3-8、plugins/cost-ledger/README.md:145-152
- [ ] 4.2 変更の記録を `plugins/cost-ledger/changes/713.md` に置く（`version` は上げない）。触る範囲: plugins/cost-ledger/changes/713.md（新規）
- [ ] 4.3 archive 後に `openspec/specs/cost-ledger-persistence/spec.md` の Purpose（delta では変えられない）の「場所は `COST_LEDGER_PATH` だけで決める」を、「場所は userConfig の `LEDGER_PATH`（`CLAUDE_PLUGIN_OPTION_LEDGER_PATH`）と `COST_LEDGER_PATH` で決める」に直す。触る範囲: openspec/specs/cost-ledger-persistence/spec.md:3-4
