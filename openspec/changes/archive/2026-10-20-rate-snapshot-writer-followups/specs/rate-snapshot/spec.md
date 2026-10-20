## MODIFIED Requirements

### Requirement: 有効なアカウント ID だけを追加する

writer は固定パス `$HOME/.claude.json` の `oauthAccount.accountUuid` だけを読み、文字列の前後空白を除去した値が非空・改行（CR・LF）なし・256 文字以下なら `account_id` として記録しなければならない（MUST）。非文字列、空、改行（CR・LF）あり、長すぎる値、ファイルの欠損・破損ではキー自体を省き、書込と表示を続けなければならない（MUST）。UUID 書式の追加検証はしてはならない（MUST NOT）。他の個人情報キーや秘密資格情報を取得・出力してはならない（MUST NOT）。この ID を認証の証明と呼んではならない（MUST NOT）。

**守備範囲**: 判定する入力はこのマシンの `$HOME/.claude.json` にある `oauthAccount.accountUuid` だけである。拾いたい誤りは、欠損・破損したファイルや非文字列・空・改行（CR・LF）入り・256 文字超の値を `account_id` として出力することである。UUID 形式でない `acct-a` は通してよい。ID の実在性や認証状態を検証し、未知の穴が見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: アカウント ID を取得できる
- **WHEN** `oauthAccount.accountUuid` に有効な文字列がある
- **THEN** snapshot の `account_id` は空白除去後の値になる

#### Scenario: アカウント ID を取得できない
- **WHEN** `$HOME/.claude.json` が無い・不正か `accountUuid` が無効である
- **THEN** `account_id` キーは無く、他の項目の書込と表示は続く

### Requirement: snapshot を原子的にローカルと任意の共有先へ書く

writer は各出力先と同じディレクトリに一時ファイルを書いて `mv -f` で原子的に置換しなければならない（MUST）。共有ディレクトリが設定されていれば `<共有ディレクトリ>/<host>.json` にローカルと同じ JSON 本文を書かなければならない（MUST）。共有ディレクトリは、定義されていれば空文字も含めて `FLATMATE_RATE_SHARE_DIR` を最優先し、未定義なら `FLATMATE_RATE_SHARE_CONF`（既定 `$HOME/.claude/flatmate-rate-share`）の先頭の非コメント・非空行を使用する。両方なければ共有しない。環境変数・設定ファイル由来のパスは前後空白を除去し、先頭の `~` または `~/` は `$HOME` に展開する。特定の同期サービスのパスを固定してはならない（MUST NOT）。共有先の作成・書込失敗はローカル書込と表示を妨げてはならない（MUST NOT）。

#### Scenario: 環境変数と設定ファイル
- **WHEN** `FLATMATE_RATE_SHARE_DIR` または設定ファイルに共有先がある
- **THEN** 正規化した `host` 名の共有ファイルが作られ、ローカル snapshot と本文が一致する

#### Scenario: 空文字で明示的に共有を無効にする
- **WHEN** 設定ファイルに有効なパスがあっても `FLATMATE_RATE_SHARE_DIR=""` を定義する
- **THEN** 共有ファイルを書かずローカルだけを書く

#### Scenario: 空白だけの環境変数
- **WHEN** `FLATMATE_RATE_SHARE_DIR` が空白だけの値で定義されている
- **THEN** 空文字と同じく共有ファイルを書かず、カレントディレクトリにもディレクトリを作らない

#### Scenario: 共有先へ書けない
- **WHEN** 設定された共有ディレクトリを作れないか書けない
- **THEN** ローカル snapshot と statusline の表示は成功する
