## MODIFIED Requirements

### Requirement: snapshot を原子的にローカルと任意の共有先へ書く

writer は各出力先と同じディレクトリに一時ファイルを書いて `mv -f` で原子的に置換しなければならない（MUST）。共有ディレクトリが設定されていれば `<共有ディレクトリ>/<host>.json` にローカルと同じ JSON 本文を書かなければならない（MUST）。共有ディレクトリは、次の順で最初に定まったものを使う。(1) `CLAUDE_RATE_SHARE_DIR` が定義されていればその値（空文字も含む）、(2) 旧名の `FLATMATE_RATE_SHARE_DIR` が定義されていればその値（互換。空文字も含む）、(3) `CLAUDE_RATE_SHARE_CONF`（既定 `$HOME/.claude/rate-share`）の先頭の非コメント・非空行、(4) 旧名の `FLATMATE_RATE_SHARE_CONF`（既定 `$HOME/.claude/flatmate-rate-share`）の先頭の非コメント・非空行。(3) の設定ファイルが無いか有効な行が無いときだけ (4) を読む。すべてなければ共有しない。環境変数・設定ファイル由来のパスは前後空白を除去し、先頭の `~` または `~/` は `$HOME` に展開する。特定の同期サービスのパスを固定してはならない（MUST NOT）。共有先の作成・書込失敗はローカル書込と表示を妨げてはならない（MUST NOT）。

#### Scenario: 環境変数と設定ファイル
- **WHEN** `CLAUDE_RATE_SHARE_DIR` または設定ファイルに共有先がある
- **THEN** 正規化した `host` 名の共有ファイルが作られ、ローカル snapshot と本文が一致する

#### Scenario: 旧名の環境変数と設定ファイルも読む
- **WHEN** `CLAUDE_RATE_SHARE_DIR` が未定義で、`FLATMATE_RATE_SHARE_DIR` または旧名の設定ファイルに共有先がある
- **THEN** その共有先に共有ファイルが作られ、ローカル snapshot と本文が一致する

#### Scenario: 新名が旧名より優先される
- **WHEN** `CLAUDE_RATE_SHARE_DIR` と `FLATMATE_RATE_SHARE_DIR` が別の値で定義されている
- **THEN** `CLAUDE_RATE_SHARE_DIR` の先にだけ共有ファイルが作られる

#### Scenario: 空文字で明示的に共有を無効にする
- **WHEN** 設定ファイルに有効なパスがあっても `CLAUDE_RATE_SHARE_DIR=""`（または新名が未定義のとき `FLATMATE_RATE_SHARE_DIR=""`）を定義する
- **THEN** 共有ファイルを書かずローカルだけを書く

#### Scenario: 空白だけの環境変数
- **WHEN** `CLAUDE_RATE_SHARE_DIR`（または新名が未定義のとき `FLATMATE_RATE_SHARE_DIR`）が空白だけの値で定義されている
- **THEN** 空文字と同じく共有ファイルを書かず、カレントディレクトリにもディレクトリを作らない

#### Scenario: 共有先へ書けない
- **WHEN** 設定された共有ディレクトリを作れないか書けない
- **THEN** ローカル snapshot と statusline の表示は成功する
