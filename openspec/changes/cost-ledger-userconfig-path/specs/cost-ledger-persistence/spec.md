## MODIFIED Requirements

### Requirement: 台帳の場所は環境変数で解決する
システムは台帳ファイルの場所を、環境変数 `CLAUDE_PLUGIN_OPTION_LEDGER_PATH`（plugin.json の `userConfig` の項目 `LEDGER_PATH` の値。プラグインを有効にするときと `/config` で設定できる）と環境変数 `COST_LEDGER_PATH` だけから MUST 解決する。両方が空でないときは `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` を使い、空文字は未設定と同じに扱う。既定のパスを持ってはならず、台帳のパスをこのリポジトリの文書やスクリプトに固定で書いてはなら MUST NOT ない。`userConfig` の項目は `type: file`、`required: false` で宣言し、`default` を持たない。

Stop の hook（`scripts/ledger-hook.sh`）は、解決した値を `COST_LEDGER_PATH` に写して `cost_ledger.py` に渡 MUST す。どちらの環境変数も空なら、python を起動せずに終了コード 0 で抜け MUST る。

台帳の実パスが `cost_ledger.py` を含むリポジトリ（git 管理外ならプラグインのディレクトリ）の配下を指すとき、システムは台帳に書かずに終了コード 2 で終わ MUST る。

守備範囲: 判定の入力は、利用者が `/config` や `~/.claude/settings.json` の `env` などで設定する値である。この判定が拾いたい誤りは、台帳がプラグインのリポジトリ（開発用 clone や自動更新される marketplace の clone）の配下に置かれ、再 clone で消えたり commit に紛れたりすることである。相対パス・`~`・シンボリックリンクを経由してリポジトリ配下を指す場合も、実パスで比べて拾う。通ることを許す入力は、リポジトリ外であれば、別の git リポジトリの配下や同期フォルダの配下を含むどのパスでもよい（書き込めないパスはこの判定では通し、書き込みの失敗として扱う）。ハードリンクや、判定のあとでパスの途中のシンボリックリンクを差し替える競合は拾わない。新しく見つかった判定の穴を塞ぎ切ることを、この要件の完了条件にしない。`/cost` のコマンド本文の Bash 実行に `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が渡るかどうかはこの要件では保証しない（渡らない環境では `/cost` は台帳を読まず会話ログ直読みになる。実機確認は別の issue で扱う）。

#### Scenario: 環境変数が未設定
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` と `COST_LEDGER_PATH` の両方が未設定のまま `cost_ledger.py cost` を実行する
- **THEN** 台帳は作られず、会話ログを直接読んだ値が返る

#### Scenario: リポジトリ配下を指している
- **WHEN** `COST_LEDGER_PATH` がプラグインのリポジトリ配下のファイルを指した状態で `cost_ledger.py ledger-sync` を実行する
- **THEN** 終了コードは 2 で、そのファイルは作られない

#### Scenario: userConfig の環境変数だけが設定されている
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` だけを設定し、会話ログに応答が 1 行ある状態で `ledger-hook.sh` を実行する
- **THEN** 終了コードは 0 で、そのパスの台帳に 1 行が追記される

#### Scenario: 従来の環境変数だけが設定されている
- **WHEN** `COST_LEDGER_PATH` だけを設定して `ledger-hook.sh` を実行する
- **THEN** 従来どおりそのパスの台帳に追記される

#### Scenario: 両方が設定されている
- **WHEN** 2 つの環境変数に別々のパスを設定して `ledger-hook.sh` を実行する
- **THEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` のパスにだけ追記され、`COST_LEDGER_PATH` のパスは作られない

#### Scenario: userConfig の値が空文字
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が空文字で `COST_LEDGER_PATH` が設定されている状態で `ledger-hook.sh` を実行する
- **THEN** `COST_LEDGER_PATH` のパスに追記される

#### Scenario: どちらも未設定で hook が動く
- **WHEN** 2 つとも未設定で `ledger-hook.sh` を実行する
- **THEN** 終了コードは 0 で、何も書かれない

#### Scenario: plugin.json が項目を宣言している
- **WHEN** `jq '.userConfig | keys' plugins/cost-ledger/.claude-plugin/plugin.json` を実行する
- **THEN** `LEDGER_PATH` が含まれ、その `type` は `file`、`default` は無い
