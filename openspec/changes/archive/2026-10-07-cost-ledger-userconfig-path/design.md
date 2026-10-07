## Context

hook のプロセスには userConfig の値が環境変数 `CLAUDE_PLUGIN_OPTION_<KEY>` で渡る（出典 https://code.claude.com/docs/en/plugins-reference の userConfig）。シェル形式の hook コマンドには `${user_config.*}` を書けない（書くとエラーで動かない）ので使わない。`COST_LEDGER_PATH` は `ledger-hook.sh`、`cost_ledger.py`（`LEDGER_ENV` / `ledger_path()`）、`commands/cost.md`（案内文）で読まれている。

## Decisions

1. **キー名は大文字の `LEDGER_PATH`**。環境変数名が `CLAUDE_PLUGIN_OPTION_` + キーなので、キーを大文字にしておけば、実装が名前を大文字化する・しないのどちらでも `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` になる。`claude plugin validate` は大文字小文字どちらのキーも通すことを確認済み。
2. **型は `file`**。`/config` に userConfig の行が出て値を変えられるのは Claude Code v2.1.269 以降（出典 https://code.claude.com/docs/en/plugins-reference の userConfig の節に「The `/config` rows require Claude Code v2.1.269 or later」とあるのを確かめた）。それより古い版ではプラグインを有効にするときの入力だけが入口で、`COST_LEDGER_PATH` の手書きも引き続き使える。台帳は 1 ファイルのため。`claude plugin validate`（claude 2.1.292）で `type` に使える値は `string` / `number` / `boolean` / `directory` / `file`、他の値は `Invalid option` で失敗することを確認済み。項目は `type` `title` `description` `required: false`。`default` は書かない（既定の台帳パスを持たない既存要件を守る）。`sensitive` は書かない（パスは秘密ではない）。
3. **優先順位は `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` → `COST_LEDGER_PATH`**。issue の指定どおり。空文字は未設定と同じに扱う。意図は、`/config` で設定した値を、昔 env に書いた値より優先すること。
4. **hook は解決した値を `COST_LEDGER_PATH` に写して python に渡す**。python 側の入口を 1 つに保つため。加えて `ledger_path()` 自体も同じ優先順位で読む（Decision 5 の理由）。写しは hook のプロセス内だけで、利用者の env は書き換えない。
5. **`/cost` 側の扱い（範囲の線引き）**。`/cost` は `commands/cost.md` の本文にある Bash 実行から `cost_ledger.py` を呼ぶ。この Bash 実行に `CLAUDE_PLUGIN_OPTION_*` が渡るかは、公式ドキュメントの記述の確認と実機（`claude -p --plugin-dir`）が要り、受け入れ条件（hook の bats、validate、test.sh）の範囲を超える。そこでこの change では、(a) `ledger_path()` を hook と同じ優先順位にする（渡る環境なら `/cost` も同じ台帳を読む。数行で、既存の台帳なしの動きは変わらない）、(b) `cost.md` の案内文（「未設定なら settings の env に書くよう案内」）の書き換えと、渡らない場合の対処は**新しい issue の候補**として return に残す。`/config` だけで設定し `/cost` に渡らない環境では、Stop hook の追記は動き、`/cost` は台帳を読まず会話ログ直読みに落ちる（案内文が env を促す。壊れはしないが食い違う）。この食い違いを仕様の既知の制限として README に 1 行書く。
6. **plugin.json の `description` は触らない**。`COST_LEDGER_PATH` を設定すれば…という既存の文をそのまま残す（意味は後方互換として正しい）。予算ファイルを動かさずに済む。

## Risks / Trade-offs

- 両方設定されたとき userConfig が勝つので、古い env の値の台帳には追記されなくなる。移行時の意図せぬ切り替えになりうるが、README に優先順位を書く。
- `/cost` と hook の食い違い（Decision 5）は、実機確認を別 issue に切り出すことで残る。
