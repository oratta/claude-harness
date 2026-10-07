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

### Requirement: Stop hook で差分を追記する
システムは `plugins/cost-ledger/hooks/hooks.json` の `Stop` に `plugins/cost-ledger/scripts/ledger-hook.sh` を MUST 登録する。hook は差分追記を行い、どの失敗でも無出力で終了コード 0 を返 MUST す（応答を止めない）。`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` と `COST_LEDGER_PATH` がどちらも未設定（空文字を含む）のときだけ、python3 を起動せずに抜け MUST る。どちらかが設定されていれば、「台帳の場所は環境変数で解決する」の優先順位で台帳を決めて追記する。複数の hook が同時に動いても台帳の行が重複も欠落もしないよう、システムは台帳の隣のロックファイルに排他ロックを取ってから読み書き SHALL する。

#### Scenario: 未設定なら何もしない
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` と `COST_LEDGER_PATH` の両方を未設定（または空文字）にして hook を実行する
- **THEN** python3 は起動されず、出力は空で、終了コードは 0

#### Scenario: hook が追記する
- **WHEN** `COST_LEDGER_PATH` を一時ディレクトリのファイルに向けて hook を実行する
- **THEN** 台帳に会話ログの事実が追記され、出力は空で、終了コードは 0

#### Scenario: userConfig の値だけでも hook が追記する
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` だけを一時ディレクトリのファイルに向けて hook を実行する
- **THEN** 台帳に会話ログの事実が追記され、出力は空で、終了コードは 0

#### Scenario: 失敗しても止めない
- **WHEN** 台帳の場所がリポジトリ配下を指した状態で hook を実行する
- **THEN** 出力は空で、終了コードは 0

#### Scenario: 差分の追記は 1 秒未満で終わる
- **WHEN** 他に負荷の無い状態で、台帳と控えが最新のあと会話ログに応答を 1 行追記してから hook を実行する
- **THEN** hook は 1 秒未満で終わる

#### Scenario: 同時に動く
- **WHEN** 2 つの hook を同時に実行する
- **THEN** 台帳の各 `requestId` は 1 行ずつで、行数は会話ログの応答数と一致する

### Requirement: /cost は台帳から読む
台帳の場所が（「台帳の場所は環境変数で解決する」の優先順位で）解決できているとき、システムは集計系のサブコマンド（`facts` / `branch` / `intervals` / `issue` / `cost` / `report`）で、読む前に差分追記を 1 回行い、そのあと台帳だけから事実を MUST 読む。会話ログが消えたあとも、消える前と同じ値を返さなければならない。

#### Scenario: 会話ログを退避したあと
- **WHEN** `ledger-sync` のあとで会話ログを退避し、`cost_ledger.py cost <PR番号>` を実行する
- **THEN** 1 行目は退避前と同じ

#### Scenario: 最後の追記以降の行も含む
- **WHEN** `ledger-sync` のあとで会話ログに応答が増え、hook を待たずに `cost_ledger.py branch <ブランチ>` を実行する
- **THEN** 増えた応答も合計に含まれる

#### Scenario: userConfig の値だけでも台帳から読む
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` だけを設定して `ledger-sync` のあと会話ログを退避し、`cost_ledger.py cost <PR番号>` を実行する
- **THEN** 1 行目は退避前と同じ
