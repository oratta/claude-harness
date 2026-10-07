## MODIFIED Requirements

### Requirement: 台帳は事実の append-only JSONL
台帳の 1 行は会話ログの 1 応答から抽出した事実（`cost-ledger-attribution` の事実の段の出力）1 つ、または同じ応答の 2 行目以降から出した補足の事実（`cost-ledger-attribution` の「同じ応答の 2 行目以降の issue と投稿の印」の出力）1 つで MUST ある。区間の帰属を書いてはならない。システムは台帳の既存の行を書き換えも削除もしてはなら MUST NOT ない（追記だけを行う）。

#### Scenario: 事実がそのまま書かれる
- **WHEN** 会話ログに応答が 1 行ある状態で `ledger-sync` を実行する
- **THEN** 台帳に 1 行が追記され、その内容は `cost_ledger.py facts` を会話ログ直読みで実行した出力の行と同じ

#### Scenario: 補足の事実が書かれ、既存の行は変わらない
- **WHEN** 同じ `requestId` の 2 行目にだけ `gh issue view 42` がある会話ログを `ledger-sync` で取り込む
- **THEN** 台帳に先頭の事実 1 行と補足の事実 1 行が追記され、`cost_ledger.py facts` の直読みの出力と同じ内容になる

## ADDED Requirements

### Requirement: 既存の取りこぼしは追記で補う
システムは `ledger-sync --rescan` で、控えの読み終え位置を使わずに、今読む置き場所の会話ログを全部先頭から読み直 MUST せる。読み直しは台帳の索引（既に書いた `requestId`）を使い、索引に無い事実と補足の事実だけを追記 SHALL する。台帳の既存の行を書き換えも削除もしてはなら MUST NOT ない。通常の `ledger-sync` と Stop hook は `--rescan` を暗黙に行ってはなら MUST NOT ない（全履歴の読み直しで hook が 1 秒を超えるため）。

守備範囲: 入力は、補足の事実を足す前に書かれた台帳と、まだ残っている会話ログ。拾いたい誤りは、先頭の行だけを書いた既存の応答について、後続行にあった issue と投稿の印が台帳に無いこと。会話ログが既に消えた期間の応答は読み直せず、補えない。台帳のほかの誤り（書き換えられた会話ログなど）は拾わない。

#### Scenario: 既存の台帳に補足の行が追記される
- **WHEN** 補足の事実を足す前の形の台帳（応答の先頭の行だけが書かれている）に対して、同じ会話ログで `ledger-sync --rescan` を実行する
- **THEN** 既存の行は 1 バイトも変わらず、後続行の分の補足の事実だけが末尾に追記される

#### Scenario: --rescan を 2 回続けて実行する
- **WHEN** `ledger-sync --rescan` を 2 回続けて実行する
- **THEN** 2 回目は 1 行も追記しない

#### Scenario: 通常の ledger-sync は全履歴を読み直さない
- **WHEN** 会話ログが変わらないまま `ledger-sync`（`--rescan` なし）を実行する
- **THEN** 控えの読み終え位置が使われ、既に読み終えたファイルは開かれない（追記は 0 行）

#### Scenario: 会話ログが消えた分は補えない
- **WHEN** 台帳に先頭の行が書かれた応答の会話ログが消えたあとで `ledger-sync --rescan` を実行する
- **THEN** その応答の補足の事実は追記されず、終了コードは 0
