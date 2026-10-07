# cost-ledger-persistence Specification

## Purpose
会話ログが消えたあとも PR のコストを `/cost` で引けるように、事実の行をリポジトリ外の append-only JSONL 台帳（場所は userConfig の `LEDGER_PATH`（環境変数 `CLAUDE_PLUGIN_OPTION_LEDGER_PATH`）と `COST_LEDGER_PATH` の 2 つの入口だけで決め、前者が優先）へ Stop hook で差分追記し、`/cost` は読む前に会話ログの差分を台帳へ同期してから、台帳だけを読む（重複は追記の時点で requestId により排除済み）。
## Requirements
### Requirement: 台帳の場所は環境変数で解決する
システムは台帳ファイルの場所を、環境変数 `CLAUDE_PLUGIN_OPTION_LEDGER_PATH`（plugin.json の `userConfig` の項目 `LEDGER_PATH` の値。プラグインを有効にするときと `/config` で設定できる）と環境変数 `COST_LEDGER_PATH` だけから MUST 解決する。両方が空でないときは `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` を使い、空文字、および `${user_config.` で始まる値（userConfig が未設定のとき、コマンド本文の置換されなかったプレースホルダがそのまま渡ったもの）は未設定と同じに扱う。既定のパスを持ってはならず、台帳のパスをこのリポジトリの文書やスクリプトに固定で書いてはなら MUST NOT ない。`userConfig` の項目は `type: file`、`required: false` で宣言し、`default` を持たない。

Stop の hook（`scripts/ledger-hook.sh`）は、解決した値を `COST_LEDGER_PATH` に写して `cost_ledger.py` に渡 MUST す。どちらの環境変数も空なら、python を起動せずに終了コード 0 で抜け MUST る。

台帳の実パスが `cost_ledger.py` を含むリポジトリ（git 管理外ならプラグインのディレクトリ）の配下を指すとき、システムは台帳に書かずに終了コード 2 で終わ MUST る。

守備範囲: 判定の入力は、利用者が `/config` や `~/.claude/settings.json` の `env` などで設定する値である。この判定が拾いたい誤りは、台帳がプラグインのリポジトリ（開発用 clone や自動更新される marketplace の clone）の配下に置かれ、再 clone で消えたり commit に紛れたりすることである。相対パス・`~`・シンボリックリンクを経由してリポジトリ配下を指す場合も、実パスで比べて拾う。通ることを許す入力は、リポジトリ外であれば、別の git リポジトリの配下や同期フォルダの配下を含むどのパスでもよい（ただし `${user_config.` で始まる値は、パスではなく置換されなかったプレースホルダとして未設定と同じに扱い、台帳のパスとは見ない）（書き込めないパスはこの判定では通し、書き込みの失敗として扱う）。ハードリンクや、判定のあとでパスの途中のシンボリックリンクを差し替える競合は拾わない。新しく見つかった判定の穴を塞ぎ切ることを、この要件の完了条件にしない。`/cost` のコマンド本文の Bash 実行には `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が渡らない（実機で確認済み）ので、`/cost` は本文の `${user_config.LEDGER_PATH}` の置換値を環境変数として `cost_ledger.py` に渡す（規則は `cost-ledger-cost-command`）。

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

#### Scenario: 置換されなかったプレースホルダが渡される
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が文字列 `${user_config.LEDGER_PATH}` のままで `COST_LEDGER_PATH` が設定されている状態で `cost_ledger.py ledger-sync` を実行する
- **THEN** `COST_LEDGER_PATH` のパスに追記され、`${user_config.LEDGER_PATH}` という名前のファイルは作られない

### Requirement: 台帳は事実の append-only JSONL
台帳の 1 行は会話ログの 1 応答から抽出した事実（`cost-ledger-attribution` の事実の段の出力。先頭の行の `uuid` を持つ）1 つ、または同じ応答の 2 行目以降から出した補足の事実（`cost-ledger-attribution` の「同じ応答の 2 行目以降の issue と投稿の印」の出力。出力トークンの差分を持つことがある）1 つ、またはリポジトリ識別子の補正行 1 つで MUST ある。補足の事実は元の会話ログ内の行頭のバイト位置 `source_offset` を持 MUST つ（同じ `timestamp` の後続行を元の順に並べるため）。区間の帰属を書いてはならない。システムは台帳の既存の行を書き換えも削除もしてはなら MUST NOT ない（追記だけを行う）。

**補正行。** 補正行は、台帳で識別子が「不明」の行を持つ（`session_id`, `branch`）の組 1 つについて、その組のリポジトリ識別子を伝える行で MUST ある。事実と同じ欄を持ち、値は次のとおりと SHALL する: `repo_fix` が `true`／`continuation` が `true`／`request_id` が `repo-fix#<session_id>#<branch>#<リポジトリ識別子>`／`session_id` と `branch` が組の値／`repo_id` が決まったリポジトリ識別子／`timestamp` がその組の不明の行のうち最も早い値／入力・出力・キャッシュ書込 2 種・キャッシュ読取のトークンがすべて 0／`issues` が空の配列で、投稿の印を持たない。`uuid` と `source_offset` は持たない。補正行を書くのは `ledger-sync --rescan` だけで MUST ある（「既存の取りこぼしは追記で補う」）。

補正行を補足の事実と同じ `continuation: true`・トークン 0 の形にするのは、補正行を知らない版の読み手が同じ台帳を読んでも、金額・メッセージの件数・区間の切れ目が変わらないようにするためで SHALL ある。

#### Scenario: 事実がそのまま書かれる
- **WHEN** 会話ログに応答が 1 行ある状態で `ledger-sync` を実行する
- **THEN** 台帳に 1 行が追記され、その内容は `cost_ledger.py facts` を会話ログ直読みで実行した出力の行と同じ

#### Scenario: 補足の行は位置を持ち、同期の分け方によらず同じ
- **WHEN** 同じ `requestId`・同じ `timestamp` の後続行を持つ会話ログを、1 回で取り込む場合と、投稿の行の直後で 2 回に分けて取り込む場合
- **THEN** 台帳の行（`source_offset` を含む）は同じで、`split_intervals` の区間も直読みと同じになる

#### Scenario: 補足の事実が書かれ、既存の行は変わらない
- **WHEN** 同じ `requestId` の 2 行目にだけ `gh issue view 42` がある会話ログを `ledger-sync` で取り込む
- **THEN** 台帳に先頭の事実 1 行と補足の事実 1 行が追記され、`cost_ledger.py facts` の直読みの出力と同じ内容になる

#### Scenario: 出力の差分が台帳に書かれ、直読みと同じになる
- **WHEN** 同じ `requestId` の 1 行目（出力 8）と確定行（出力 251）がある会話ログを `ledger-sync` で取り込む
- **THEN** 台帳に先頭の事実 1 行（出力 8）と補足の事実 1 行（出力 243）が追記され、`cost_ledger.py facts` の直読みの出力と同じ内容になる。既存の行は変わらない

#### Scenario: 補正行を知らない読み方でも金額と件数が変わらない
- **WHEN** PR のヘッドブランチと同じ `branch` の補正行を 1 行含む台帳で `cost_ledger.py issue <番号> --closing-pr <PR番号>:<そのブランチ> --json` を実行する（ヘッドブランチの行をまとめて読む経路は、補正行を取り除かずに事実として数える）
- **THEN** `closing_prs` のその PR の `usd` と `combined_total_usd` は、補正行の無い同じ台帳で実行した値と同じ

### Requirement: 差分だけを追記し requestId で重複を排除する
システムは `requestId` が台帳に既にある事実を追記してはなら MUST NOT ない。同じファイル内の重複とファイルをまたぐ重複のどちらでも、先に見た 1 行だけを採る。

システムは会話ログごとに読み終えた位置を台帳の隣の控えファイルに記録し、次回はその位置以降だけを読 SHALL む。読み終え位置を差し替えるのは今回読んだ置き場所の配下のファイルだけで、別の置き場所のファイルの読み終え位置は残す。末尾の改行で終わっていない行は読まずに次回へ回す。控えファイルが無い・壊れている・ファイルが縮んだ・inode が変わった場合は、そのファイルを先頭から読み直し、重複排除によって同じ台帳になら MUST なければならない。読み終え位置の控えは置き場所を実パスに直した形で記録し、同じ置き場所をシンボリックリンク経由で指しても同じ読み終え位置を使 MUST う。

守備範囲: 入力は、Claude Code が `CLAUDE_CONFIG_DIR` の配下に追記していく会話ログの JSONL、台帳の隣の控えファイル、既存の台帳の 3 つである。この要件が拾いたい誤りは、同じ応答の二重計上（2 回目の同期、resume による履歴の複製、控えの消失、同じ置き場所を別の表記で指すこと）と、増えた応答の取りこぼし（書きかけの末尾行、別の置き場所からの同期による控えの消失）の 2 つである。通ることを許す入力は、読み終えた部分が同じ長さ・同じ inode のまま書き換えられた会話ログ（読み直さず、書き換え前の内容が台帳に残る）、`requestId` も `uuid` も無い応答（空文字を鍵にして最初の 1 行だけ採る）、JSON として読めない行や期待する形でない行（飛ばす）である。会話ログの中身が正しいかどうかの検証はしない。新しく見つかった重複や取りこぼしの穴を塞ぎ切ることを、この要件の完了条件にしない。

#### Scenario: 2 回続けて実行する
- **WHEN** 会話ログが変わらないまま `ledger-sync` を 2 回実行する
- **THEN** 2 回目は 1 行も追記しない

#### Scenario: 応答が増えた
- **WHEN** 1 回目の `ledger-sync` のあと、会話ログに応答を 1 行追記してから 2 回目を実行する
- **THEN** 2 回目は増えた 1 行だけを追記する

#### Scenario: 控えファイルが消えた
- **WHEN** 控えファイルを消してから `ledger-sync` を実行する
- **THEN** 台帳の行数は変わらない

#### Scenario: 別ファイルに同じ requestId がある
- **WHEN** resume で履歴が複製され、2 つの会話ログに同じ `requestId` の行がある
- **THEN** 台帳にはその `requestId` の行が 1 行だけある

#### Scenario: 書きかけの末尾行
- **WHEN** 会話ログの末尾が改行で終わっていない状態で `ledger-sync` を実行し、その後に行が完成してから再度実行する
- **THEN** 1 回目はその行を書かず、2 回目に 1 行だけ書く

#### Scenario: 同じ置き場所をシンボリックリンク経由で指した
- **WHEN** `ledger-sync` のあと、同じ置き場所を指すシンボリックリンクを `CLAUDE_CONFIG_DIR` にして、会話ログに応答を 1 行追記してから `ledger-sync` を実行する
- **THEN** 2 回目は増えた 1 行だけを読んで追記し、読み終えた部分を読み直さない

#### Scenario: 別の置き場所から同じ台帳へ同期した
- **WHEN** `CLAUDE_CONFIG_DIR` の違う置き場所（会話ログが無くてもよい）から同じ台帳へ `ledger-sync` を実行したあと、元の置き場所の会話ログに応答を 1 行追記して `ledger-sync` を実行する
- **THEN** 元の置き場所の読み終え位置は残っており、2 回目は増えた 1 行だけを読んで追記する

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
- **WHEN** 2 つの hook を同時に実行する（会話ログには、1 行だけの応答と、後続行に `gh issue view` を持つ 2 行の応答が含まれる）
- **THEN** 通常の事実は各 `requestId` が 1 行ずつで、通常の事実の行数は会話ログの応答数と一致する。補足の事実は各 `request_id`（`<requestId>#<uuid>`）が 1 行ずつで、台帳に同じ `request_id` の行は 2 つ無い

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

### Requirement: 既存の取りこぼしは追記で補う
システムは `ledger-sync --rescan` で、控えの読み終え位置を使わずに、今読む置き場所の会話ログを全部先頭から読み直 MUST せる。読み直しは台帳の索引（既に書いた `requestId`）を使い、索引に無い事実と補足の事実（issue・印・出力トークンの差分を持つもの）と、リポジトリ識別子の補正行だけを追記 SHALL する。台帳の既存の行を書き換えも削除もしてはなら MUST NOT ない。通常の `ledger-sync` と Stop hook は `--rescan` を暗黙に行ってはなら MUST NOT ない（全履歴の読み直しで hook が 1 秒を超えるため）。

台帳の索引を作り直すとき（控えが無い・壊れている・古い形）も、台帳の行の `uuid`（先頭の行の `uuid`）と、応答ごとに数えた出力トークン（先頭の事実の出力と、補足の事実の出力の合計）を台帳から読んで、補足の事実の判定に使 MUST う。控えを消しても、同じ台帳に同じ補足の事実が重複して追記されてはなら MUST NOT ない。

**補正行の追記。** `ledger-sync --rescan` は、台帳で識別子が「不明」の行（補正行を除く）を持つ（`session_id`, `branch`）の組ごとに、読み直した会話ログの応答の行（`type` が `assistant` の行）のうち、その組（`sessionId`。無ければ事実と同じくファイルのパス, `gitBranch`）に当たる行の `cwd` を集め MUST る。集めた `cwd` が 1 つ以上あり、そのすべてが spec `cost-ledger-attribution` の「リポジトリ識別子と worktree の畳み込み」の求め方（`git rev-parse`、または削除済みの `cwd` からの推定）で同じ 1 つのリポジトリ識別子に決まるときだけ、その組の補正行（「台帳は事実の append-only JSONL」の形）を 1 行追記 SHALL する。`cwd` が 1 つも集まらない組、1 つでも「不明」の `cwd` がある組、2 つ以上のリポジトリに分かれる組には、補正行を書いてはなら MUST NOT ない。その組に当たる応答の行のうち、`cwd` の欄が無いか空の行が 1 つでもあれば、「不明」の `cwd` が 1 つある組として扱い、補正行を書いてはなら MUST NOT ない（`cwd` を持たない行の事実は「不明」になり、補正は組ごとに効くので、書けばその行まで補正されたリポジトリの行として読まれるため）。同じ `request_id` の補正行が既に台帳にあれば追記してはなら MUST NOT ない（控えを消したあとも同じ）。補正行のために会話ログのファイルを開く回数を増やしてはなら MUST NOT ない。

補正行の追記は、主が手で実行する `ledger-sync --rescan` だけが行う操作で MUST ある。通常の `ledger-sync` と Stop hook は補正行を書いてはなら MUST NOT ない。

守備範囲: 入力は、補足の事実を足す前に書かれた台帳（`uuid` の欄が無い、または先頭の行の途中の出力トークンのまま）と、まだ残っている会話ログ。拾いたい誤りは、先頭の行だけを書いた既存の応答について、後続行にあった issue と投稿の印、確定行の出力トークンの差分が台帳に無いこと。会話ログが既に消えた期間の応答、確定行が会話ログに無い応答は読み直しても補えない。台帳のほかの誤り（書き換えられた会話ログなど）は拾わない。新しく見つかった取りこぼしの穴を塞ぎ切ることを、この要件の完了条件にしない。

守備範囲（補正行）: 入力は、台帳の「不明」の行と、まだ残っている会話ログの `cwd`。拾いたい誤りは、台帳へ追記した時点で `cwd` が既に消えていた行が、どのリポジトリの行か分からないまま残ること。次のものは直らないまま通す: 会話ログが既に消えた組／推定の条件を満たさない `cwd` を 1 つでも含む組／`cwd` を持たない応答の行を含む組／2 つのリポジトリにまたがる組。書いた補正行は消せない（取り消しは「台帳を読むときに補正行を当てる」の、同じ組に別のリポジトリの補正行を足す方法で行う）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 既存の台帳に補足の行が追記される
- **WHEN** 補足の事実を足す前の形の台帳（応答の先頭の行だけが書かれている）に対して、同じ会話ログで `ledger-sync --rescan` を実行する
- **THEN** 既存の行は 1 バイトも変わらず、後続行の分の補足の事実だけが末尾に追記される

#### Scenario: --rescan で追記した補足の行も位置を持つ
- **WHEN** 先頭の行だけが書かれた台帳に対して、同じ時刻の後続行を持つ会話ログで `ledger-sync --rescan` を実行する
- **THEN** 追記された補足の行は `source_offset` を持ち、区間は直読みと同じ。既存の行は 1 バイトも変わらず、再実行と控えを消した再走査は追記しない

#### Scenario: --rescan を 2 回続けて実行する
- **WHEN** `ledger-sync --rescan` を 2 回続けて実行する
- **THEN** 2 回目は 1 行も追記しない

#### Scenario: 通常の ledger-sync は全履歴を読み直さない
- **WHEN** 会話ログが変わらないまま `ledger-sync`（`--rescan` なし）を実行する
- **THEN** 控えの読み終え位置が使われ、既に読み終えたファイルは開かれない（追記は 0 行）。同じ inode・同じバイト長のまま内容が書き換えられても、新しい事実は追記されない（読み直されないことの検出）

#### Scenario: 控えを消しても補足の行は重複しない
- **WHEN** 補足の行を追記したあと、控えファイルを消してから `ledger-sync --rescan` を実行する
- **THEN** 台帳の行数は変わらない

#### Scenario: 複製されたログの先頭の行は補足の行にならない
- **WHEN** 先頭の行に投稿の印がある応答を持つ会話ログを取り込み、同じ内容の複製（同じ `uuid`）を別のファイルに置いて `ledger-sync --rescan` を実行する
- **THEN** 台帳に補足の行は追記されない

#### Scenario: 会話ログが消えた分は補えない
- **WHEN** 台帳に先頭の行が書かれた応答の会話ログが消えたあとで `ledger-sync --rescan` を実行する
- **THEN** その応答の補足の事実は追記されず、終了コードは 0

#### Scenario: 途中の出力で書かれた既存の台帳に差分が追記される
- **WHEN** 先頭の行（出力 8）だけが書かれた台帳に対して、確定行（出力 251）を含む同じ会話ログで `ledger-sync --rescan` を実行する
- **THEN** 既存の行は 1 バイトも変わらず、出力 243 の補足の事実が末尾に追記される。2 回目の `--rescan` と、控えを消してからの `--rescan` は 0 行を追記する

#### Scenario: 古い形の控えは台帳から作り直される
- **WHEN** 応答ごとの出力トークンの索引を持たない古い形の控えがある状態で、確定行を持つ応答を `ledger-sync` で取り込む
- **THEN** 控えは台帳から作り直され、既に台帳にある応答に対して差分が二重に足されない

#### Scenario: 追記の前に cwd が消えていた行に補正行が書かれる
- **WHEN** リポジトリ A（ディレクトリ名 `repo-a`）のメインの作業ツリーは別の場所にあり、git リポジトリでないディレクトリ `<親>/repo-a`（これが置き場）の直下に A の作業ツリー `<親>/repo-a/wt1` が残っていて、削除済みの `<親>/repo-a/wt2` を `cwd` に持つ会話ログから「不明」の行が書かれた台帳に対して `ledger-sync --rescan` を実行する
- **THEN** 既存の行は 1 バイトも変わらず、その（`session_id`, `branch`）の組について `repo_id` が A の識別子の補正行が 1 行だけ末尾に追記される

#### Scenario: 補正行は 2 回目に増えない
- **WHEN** 補正行を追記したあと、`ledger-sync --rescan` をもう 1 回、さらに控えファイルを消してからもう 1 回実行する
- **THEN** どちらも 1 行も追記しない

#### Scenario: 推定できない cwd が混ざる組には書かない
- **WHEN** 「不明」の行を持つ組の会話ログに、推定で決まる `cwd` と、推定の条件を満たさない削除済みの `cwd` の両方がある状態で `ledger-sync --rescan` を実行する
- **THEN** その組の補正行は追記されない

#### Scenario: cwd を持たない行が混ざる組には書かない
- **WHEN** 「不明」の行を持つ組の会話ログに、推定で決まる `cwd` の応答の行と、`cwd` の欄が無い応答の行の両方がある状態で `ledger-sync --rescan` を実行する
- **THEN** その組の補正行は追記されない

#### Scenario: 通常の ledger-sync は補正行を書かない
- **WHEN** 「不明」の行を持つ台帳に対して `ledger-sync`（`--rescan` なし）と Stop hook を実行する
- **THEN** 補正行は 1 行も追記されない

### Requirement: 台帳を読むときに補正行を当てる
集計のために台帳から事実を読むとき（`load_facts` の台帳の経路）、システムは補正行（`repo_fix` が `true` の行）を事実の列から取り除 MUST く。補正行は、どの集計の金額・メッセージの件数・区間・`cost_ledger.py facts` の出力にも現れてはなら MUST NOT ない。

識別子が「不明」の事実は、同じ（`session_id`, `branch`）の組の補正行の `repo_id` が**ちょうど 1 種類**のとき、`repo_id` をその値に、`repo_inferred` を `true` にした事実として読 MUST む。同じ組に `repo_id` の違う補正行が 2 種類以上あるときは、「不明」のまま読 MUST む（誤った補正を、補正行を 1 行足すことで取り消せるようにするため）。識別子が「不明」でない事実は、補正行があっても変えてはなら MUST NOT ない。台帳のファイルは書き換えない。

補正行を集めるために台帳を読み通す回数は、台帳から事実を読む 1 回につき 1 回までと SHALL し、issue の数にも PR の数にも比例してはなら MUST NOT ない。台帳が未設定で会話ログを直接読む経路では、補正行を扱わない（全行が事実の段を通り、削除済みの `cwd` からの推定がその場で効く）。

守備範囲: 入力は台帳の行だけ。拾いたい誤りは、補正行が金額や件数に数えられること・「不明」でない行の識別子が書き換わること・取り消したはずの補正が効き続けることの 3 つ。次のものは通す: ブランチ名だけで数える経路（PR のヘッドブランチの行をまとめて読む経路）に混ざる補正行は取り除かなくてよい（トークン 0 の補足の事実なので、金額にも件数にも出ない）／補正は組ごとに効くので、1 つの組の中の一部の行だけを別のリポジトリにすることはできない。補正は組ごとに効くので、補正行を書いたあとで同じ組へ追記された「不明」の行にも当たる。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 不明の行が補正されたリポジトリの行として数えられる
- **WHEN** issue #42 を触った「不明」の行と、その組の補正行（`repo_id` はリポジトリ A）がある台帳で、A の作業ディレクトリから `cost_ledger.py issue 42` を実行する
- **THEN** その行は合計に入り、「リポジトリ不明」の件数に数えられない

#### Scenario: 別のリポジトリに補正された行は数えない
- **WHEN** issue #42 を触った「不明」の行の組の補正行が、リポジトリ B を指している台帳で、リポジトリ A の作業ディレクトリから `cost_ledger.py issue 42` を実行する
- **THEN** その行は合計にも「リポジトリ不明」にも入らない

#### Scenario: 2 つのリポジトリの補正行があれば不明のまま
- **WHEN** 同じ組に `repo_id` の違う補正行が 2 行ある台帳で `cost_ledger.py issue 42` を実行する
- **THEN** その組の「不明」の行は合計に入らず、「リポジトリ不明」の件数と金額に数えられる

#### Scenario: 補正行は事実の出力に出ない
- **WHEN** 補正行を含む台帳で `cost_ledger.py facts` を実行する
- **THEN** 出力に `repo_fix` を持つ行は無く、補正された行は `repo_inferred` が `true` で出る

