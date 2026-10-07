## ADDED Requirements

### Requirement: 同じ応答の 2 行目以降の issue と投稿の印
Claude Code は 1 回の API 応答を、中身のブロックごとに別の行として会話ログに書き、どの行も同じ `requestId` を持つ。システムは、既出の `requestId` の行（同じ応答の 2 行目以降）が、触った issue 番号の列か投稿の印を持つとき、その行のぶんの**補足の事実**を 1 つ出 MUST す。補足の事実は、その行から `scan_tool_calls` と同じ規則（実行された `Bash` の `command` だけを見る）で拾った issue 番号と投稿の印、`timestamp`・`sessionId`・`isSidechain`・リポジトリ識別子・`gitBranch`・`message.model` を持ち、トークン 5 種は全部 0 と SHALL する。`request_id` は `<元の requestId>#<その行の uuid>`（`uuid` が無ければ `timestamp`、どちらも無ければ補足の事実を出さない）、`continuation` は真と SHALL する。issue 番号も投稿の印も持たない 2 行目以降の行は、補足の事実を出さず捨てて MUST よい。

1 つの応答のトークンと金額は先頭の行の分だけを数え、後続行のトークンを数えてはなら MUST NOT ない。補足の事実はメッセージ数（`messages`）に数えて MUST NOT ならない。

守備範囲: 入力は、Claude Code が書く会話ログの assistant 行で、同じ `requestId` が複数の行に現れるもの。拾いたい誤りは、後続行にだけある `gh issue view/comment/edit/close/develop <番号>` と投稿（`gh pr comment`・`gh issue comment`・`gh pr create`・`gh pr ready`）が帰属と区間に反映されないこと。通ることを許す入力は、後続行が `requestId` も `uuid` も `timestamp` も持たない行（補足の事実を出さない）と、複製された履歴で後続行の `uuid` が元と異なる場合の補足の事実の重複（トークンも金額も 0 で、区間が 1 つ余分に切れることがある）である。後続行のトークンの取り込みと、会話ログの中身が正しいかの検証はしない。

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
- **WHEN** 2 行目以降の行が、`Edit` の本文や `Agent` の指示文に `gh issue view 999` という文字列を含むだけで、`Bash` で実行していない
- **THEN** 補足の事実は出ず、issue 999 へは帰属しない

#### Scenario: メッセージ数に数えない
- **WHEN** 応答 1 つ（3 行、2 行目に `gh issue view 42`）を集計する
- **THEN** メッセージ数は 1 で、事実の列の件数（補足を含む）とは別に数えられる

#### Scenario: 同じ会話ログを 2 回読んでも補足の事実は 1 つ
- **WHEN** 同じ会話ログの行の列を、同じ `seen` を共有して 2 回読む
- **THEN** 補足の事実は 1 つだけ出る
