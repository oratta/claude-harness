## MODIFIED Requirements

### Requirement: 行から抽出する事実
システムは会話ログの各行から、帰属を導く前の**事実だけ**を抽出する段を持 MUST つ。区間の帰属は投稿が来るまで確定しないため、1 行ずつ追記する経路（後続の台帳）が書けるのは導いた帰属ではなく事実に限られる。抽出する事実は次のとおりと SHALL する。

- `requestId`（無ければ `uuid`）— 重複排除の鍵
- `uuid` — その行の `uuid`（無ければ空文字）。同じ応答の複製された先頭の行と後続行を区別する鍵（次の節の Requirement）
- `timestamp` — 区間を並べる鍵
- `sessionId` — 区間を切る単位
- `isSidechain` — サブエージェントの行かどうか
- リポジトリ識別子 — `cwd` から導く（次の Requirement）
- `gitBranch`
- `message.model`
- トークン 5 種 — 入力 `usage.input_tokens`、出力 `usage.output_tokens`、キャッシュ書込 5m `usage.cache_creation.ephemeral_5m_input_tokens`、キャッシュ書込 1h `usage.cache_creation.ephemeral_1h_input_tokens`、キャッシュ読出 `usage.cache_read_input_tokens`
- 触った issue 番号の列 — その行のツール呼び出しから拾う（次の Requirement）
- 投稿の印 — その行が区間の境界かどうか（次の Requirement）

キャッシュ書込の 5m と 1h がどちらも無い、または両方 0 のとき、システムは `usage.cache_creation_input_tokens` を 5m 扱いで読 MUST む。

#### Scenario: 事実の抽出が帰属を含まない
- **WHEN** 1 行を読んで事実を抽出する
- **THEN** その行だけで確定する事実のみが得られ、区間の帰属先 issue は含まれない

#### Scenario: キャッシュ書込の内訳が無い古い行
- **WHEN** 行の `usage` に `cache_creation` が無く `cache_creation_input_tokens` だけがある
- **THEN** その値はキャッシュ書込 5m として読まれる

## ADDED Requirements

### Requirement: 同じ応答の 2 行目以降の issue と投稿の印
Claude Code は 1 回の API 応答を、中身のブロックごとに別の行として会話ログに書き、どの行も同じ `requestId` を持つ。システムは、各会話ログのファイルの中で同じ `requestId` が最初に現れる行を**先頭の行**とし、先頭の行から通常の事実を 1 つ出 MUST す（今までどおり。事実は先頭の行の `uuid` を `uuid` の欄に持つ）。同じファイルでそれより後に現れる行を**後続行**と呼ぶ。

後続行が、触った issue 番号の列か投稿の印を持つとき、システムはその行のぶんの**補足の事実**を 1 つ出 MUST す。補足の事実は、その行から `scan_tool_calls` と同じ規則（実行された `Bash` の `command` だけを見る）で拾った issue 番号と投稿の印、`timestamp`・`sessionId`・`isSidechain`・リポジトリ識別子・`gitBranch`・`message.model` を持ち、トークン 5 種は全部 0 と SHALL する。`request_id` は `<元の requestId>#<その行の uuid>`、`continuation` は真と SHALL する。issue 番号も投稿の印も持たない後続行や、`uuid` を持たない後続行は、補足の事実を出さず捨てて MUST よい。

別のファイルに複製された（resume・fork による）会話ログでは、複製された先頭の行も、そのファイルの中では先頭の行である。複製された先頭の行から補足の事実を出してはなら MUST NOT ない。この区別のため、システムは通常の事実の `uuid`（先頭の行の `uuid`）を台帳の行に持 MUST つ。既に台帳にある応答の先頭の行を、別のファイルや後の同期で読んだときは、その行の `uuid` が台帳の先頭の行の `uuid` と同じなら先頭の行として捨て、違えば後続行として扱う。台帳に `uuid` の無い古い行は、読み直し（`ledger-sync --rescan`）の中で、そのファイルで最初に現れる行を先頭の行として扱う。

1 つの応答のトークンと金額は先頭の行の分だけを数え、後続行のトークンを数えてはなら MUST NOT ない。補足の事実はメッセージ数（`messages`）に数えて MUST NOT ならない。補足の事実の鍵に `uuid` を使うのは、同じ応答の別の後続行が同じ `timestamp` を持つことがあるため（実ログの計測は design の決定 2）。

守備範囲: 入力は、Claude Code が書く会話ログの assistant 行で、同じ `requestId` が複数の行に現れるもの。拾いたい誤りは、後続行にだけある `gh issue view/comment/edit/close/develop <番号>` と投稿（`gh pr comment`・`gh issue comment`・`gh pr create`・`gh pr ready`）が帰属と区間に反映されないことと、複製された会話ログの先頭の行から補足の事実が増えて区間が余分に切れること。通ることを許す入力は、複製された履歴で行の `uuid` が元と異なるもの（実ログで 207 件中 3 件。補足の事実が重複し、区間が 1 つ余分に切れることがある。トークンも金額も 0）、同じ応答の行が別のファイルに分かれて書かれたもの、`uuid` が台帳に無い古い行を `--rescan` を使わずに読んだ場合の後続行の取りこぼし、後続行が `uuid` を持たない行（補足の事実を出さない）である。後続行のトークンの取り込みと、会話ログの中身が正しいかの検証はしない。新しく見つかった複製や取りこぼしの穴を塞ぎ切ることを、この要件の完了条件にしない。

#### Scenario: 2 行目以降にだけ gh issue view がある
- **WHEN** 同じ `requestId` の 1 行目（考えた内容）に issue の記述が無く、2 行目に `gh issue view 42` を実行する `Bash` がある
- **THEN** 事実の列に、`issues` が `["42"]` の補足の事実が 1 つ入る

#### Scenario: トークンと金額は 1 回分のまま
- **WHEN** 同じ `requestId` の 3 行が全部同じ `usage` を持ち、2 行目に `gh issue view 42` がある
- **THEN** 事実の列のトークンの合計と金額は 1 行だけの場合と同じで、補足の事実のトークンは 5 種とも 0

#### Scenario: 2 行目以降にだけ投稿の印がある
- **WHEN** 同じ `requestId` の 2 行目にだけ `gh pr comment 300` を実行する `Bash` がある
- **THEN** 区間はその行で閉じる

#### Scenario: 実行していない文字列は拾わない
- **WHEN** 後続行が、`Edit` の本文や `Agent` の指示文に `gh issue view 999` という文字列を含むだけで、`Bash` で実行していない
- **THEN** 補足の事実は出ず、issue 999 へは帰属しない

#### Scenario: メッセージ数に数えない
- **WHEN** 応答 1 つ（3 行、2 行目に `gh issue view 42`）を集計する
- **THEN** メッセージ数は 1 で、事実の列の件数（補足を含む）とは別に数えられる

#### Scenario: 同じ会話ログを 2 回読んでも補足の事実は 1 つ
- **WHEN** 同じ会話ログの行の列を、同じ `seen` を共有して 2 回読む
- **THEN** 補足の事実は 1 つだけ出る

#### Scenario: 複製されたログの先頭の行は後続行ではない
- **WHEN** 会話ログ A に応答の 1 行目（`gh pr comment 300` を実行する `Bash` を持つ）と 2 行目があり、会話ログ B に A と同じ `uuid` の同じ 2 行が複製されている
- **THEN** 事実の列は、1 行目の通常の事実 1 つだけ（2 行目に印が無ければ補足の事実は 0）で、区間は印の位置で 1 回だけ閉じる

#### Scenario: 複製されたログの後続行は 1 つだけ
- **WHEN** 会話ログ A と B に同じ `uuid` の後続行（`gh issue view 42`）が複製されている
- **THEN** 補足の事実は 1 つだけ出る

#### Scenario: 同じ時刻の別の後続行がどちらも残る
- **WHEN** 同じ応答の 2 つの後続行が同じ `timestamp` を持ち、それぞれ `gh issue view 42` と `gh issue view 43` を実行する
- **THEN** 補足の事実は 2 つ出る（`uuid` が違うので鍵が衝突しない）

#### Scenario: 同期が分かれても先頭の行は後続行にならない
- **WHEN** 1 回目の取り込みで応答の 1 行目だけを読み、2 回目の取り込みでその 2 行目を読む
- **THEN** 2 行目だけが補足の事実になり、1 行目は 2 回目では事実を出さない
