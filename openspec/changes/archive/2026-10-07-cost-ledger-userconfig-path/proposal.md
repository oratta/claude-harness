## Why

台帳の置き場所は今、利用者が `~/.claude/settings.json` の `env` に `COST_LEDGER_PATH` を手で書く運用で、未設定だと Stop hook は何もせずに抜ける。設定し忘れても気付けない。Claude Code のプラグインは plugin.json の `userConfig` で設定項目を宣言でき、有効化時に値を聞かれ、`/config` から変更できる。台帳パスをここへ移し、手で env を編集する手順をなくす（親 epic #717、issue #713）。

## What Changes

- `plugins/cost-ledger/.claude-plugin/plugin.json` に `userConfig` を足し、台帳パスの項目 `LEDGER_PATH`（`type: file`、`required: false`、`default` なし）を宣言する
- `scripts/ledger-hook.sh` は `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` を優先して読み、空なら従来の `COST_LEDGER_PATH` を使う。どちらも空なら今までどおり python を起動せず抜ける。見つけた値は `COST_LEDGER_PATH` に写して `cost_ledger.py` に渡す
- `cost_ledger.py` の `ledger_path()` も同じ優先順位で 2 つの環境変数を読む（`/cost` など hook 以外の入口で `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が見えた場合に食い違わないため。数行）
- README の「台帳」の節に設定の入口（有効化時の入力と `/config`）を書く
- `/cost` のコマンド本文（`commands/cost.md`）の案内文と、`/cost` の Bash 実行に `CLAUDE_PLUGIN_OPTION_*` が渡るかの実機確認は、この change では扱わない（新しい issue の候補。design 参照）
- **BREAKING なし**: `COST_LEDGER_PATH` は後方互換で残る

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `cost-ledger-persistence`: 「台帳の場所は環境変数 `COST_LEDGER_PATH` だけから解決する」を「userConfig 由来の環境変数を優先し、`COST_LEDGER_PATH` も受ける」に変え、それに連動する「Stop hook で差分を追記する」（両方未設定のときだけ python3 を起動しない）と「/cost は台帳から読む」の要件も改める。Purpose の文言は delta で変えられないので archive 後に直す（tasks 4.3）

## Impact

- 触るファイル: `plugins/cost-ledger/.claude-plugin/plugin.json`、`plugins/cost-ledger/scripts/ledger-hook.sh`、`plugins/cost-ledger/scripts/cost_ledger.py`（`ledger_path()` のみ）、`plugins/cost-ledger/README.md`、新規 bats、`plugins/cost-ledger/changes/713.md`
- plugin.json の `description` は書き換えない。常時注入の予算（`tests/injection-budget.bats`）の集計対象は frontmatter の description だけで plugin.json の description は入っていないが、どのみち触らないので予算ファイルの値は動かない
- 利用者の影響: 既存の `COST_LEDGER_PATH` 設定はそのまま動く。両方あるときは userConfig 側が勝つ
