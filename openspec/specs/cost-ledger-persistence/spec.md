# cost-ledger-persistence Specification

## Purpose
会話ログが消えたあとも PR のコストを `/cost` で引けるように、事実の行をリポジトリ外の append-only JSONL 台帳（場所は `COST_LEDGER_PATH` だけで決める）へ Stop hook で差分追記し、`/cost` は台帳と会話ログを requestId で重複排除して読む。
## Requirements
### Requirement: 台帳の場所は環境変数で解決する
システムは台帳ファイルの場所を環境変数 `COST_LEDGER_PATH` だけから MUST 解決する。既定のパスを持ってはならず、台帳のパスをこのリポジトリの文書やスクリプトに固定で書いてはなら MUST NOT ない。

台帳の実パスが `cost_ledger.py` を含むリポジトリ（git 管理外ならプラグインのディレクトリ）の配下を指すとき、システムは台帳に書かずに終了コード 2 で終わ MUST る。

#### Scenario: 環境変数が未設定
- **WHEN** `COST_LEDGER_PATH` が未設定のまま `cost_ledger.py cost` を実行する
- **THEN** 台帳は作られず、会話ログを直接読んだ値が返る

#### Scenario: リポジトリ配下を指している
- **WHEN** `COST_LEDGER_PATH` がプラグインのリポジトリ配下のファイルを指した状態で `cost_ledger.py ledger-sync` を実行する
- **THEN** 終了コードは 2 で、そのファイルは作られない

### Requirement: 台帳は事実の append-only JSONL
台帳の 1 行は会話ログの 1 応答から抽出した事実（`cost-ledger-attribution` の事実の段の出力）1 つで MUST ある。区間の帰属を書いてはならない。システムは台帳の既存の行を書き換えも削除もしてはなら MUST NOT ない（追記だけを行う）。

#### Scenario: 事実がそのまま書かれる
- **WHEN** 会話ログに応答が 1 行ある状態で `ledger-sync` を実行する
- **THEN** 台帳に 1 行が追記され、その内容は `cost_ledger.py facts` を会話ログ直読みで実行した出力の行と同じ

### Requirement: 差分だけを追記し requestId で重複を排除する
システムは `requestId` が台帳に既にある事実を追記してはなら MUST NOT ない。同じファイル内の重複とファイルをまたぐ重複のどちらでも、先に見た 1 行だけを採る。

システムは会話ログごとに読み終えた位置を台帳の隣の控えファイルに記録し、次回はその位置以降だけを読 SHALL む。読み終え位置を差し替えるのは今回読んだ置き場所の配下のファイルだけで、別の置き場所のファイルの読み終え位置は残す。末尾の改行で終わっていない行は読まずに次回へ回す。控えファイルが無い・壊れている・ファイルが縮んだ・inode が変わった場合は、そのファイルを先頭から読み直し、重複排除によって同じ台帳になら MUST なければならない。

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

#### Scenario: 別の置き場所から同じ台帳へ同期した
- **WHEN** `CLAUDE_CONFIG_DIR` の違う置き場所（会話ログが無くてもよい）から同じ台帳へ `ledger-sync` を実行したあと、元の置き場所の会話ログに応答を 1 行追記して `ledger-sync` を実行する
- **THEN** 元の置き場所の読み終え位置は残っており、2 回目は増えた 1 行だけを読んで追記する

### Requirement: Stop hook で差分を追記する
システムは `plugins/cost-ledger/hooks/hooks.json` の `Stop` に `plugins/cost-ledger/scripts/ledger-hook.sh` を MUST 登録する。hook は差分追記を行い、どの失敗でも無出力で終了コード 0 を返 MUST す（応答を止めない）。`COST_LEDGER_PATH` が未設定なら python3 を起動せずに抜ける。複数の hook が同時に動いても台帳の行が重複も欠落もしないよう、システムは台帳の隣のロックファイルに排他ロックを取ってから読み書き SHALL する。

#### Scenario: 未設定なら何もしない
- **WHEN** `COST_LEDGER_PATH` を未設定にして hook を実行する
- **THEN** python3 は起動されず、出力は空で、終了コードは 0

#### Scenario: hook が追記する
- **WHEN** `COST_LEDGER_PATH` を一時ディレクトリのファイルに向けて hook を実行する
- **THEN** 台帳に会話ログの事実が追記され、出力は空で、終了コードは 0

#### Scenario: 失敗しても止めない
- **WHEN** `COST_LEDGER_PATH` がリポジトリ配下を指した状態で hook を実行する
- **THEN** 出力は空で、終了コードは 0

#### Scenario: 同時に動く
- **WHEN** 2 つの hook を同時に実行する
- **THEN** 台帳の各 `requestId` は 1 行ずつで、行数は会話ログの応答数と一致する

### Requirement: /cost は台帳から読む
`COST_LEDGER_PATH` が設定されているとき、システムは集計系のサブコマンド（`facts` / `branch` / `intervals` / `issue` / `cost` / `report`）で、読む前に差分追記を 1 回行い、そのあと台帳だけから事実を MUST 読む。会話ログが消えたあとも、消える前と同じ値を返さなければならない。

#### Scenario: 会話ログを退避したあと
- **WHEN** `ledger-sync` のあとで会話ログを退避し、`cost_ledger.py cost <PR番号>` を実行する
- **THEN** 1 行目は退避前と同じ

#### Scenario: 最後の追記以降の行も含む
- **WHEN** `ledger-sync` のあとで会話ログに応答が増え、hook を待たずに `cost_ledger.py branch <ブランチ>` を実行する
- **THEN** 増えた応答も合計に含まれる

