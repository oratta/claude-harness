## MODIFIED Requirements

### Requirement: 主の発言として数える行と数えない行

owner-reply-check.sh は、会話ログの行のうち次のすべてを満たすものだけを主の発言として数えなければならない（SHALL）: ①`type` が `"user"` ②`isSidechain` が true でない ③`isMeta` が true でない ④`origin` のキーがあるなら（値が null でも）`origin.kind` が `"human"` ⑤`message.content` が文字列、または `type: "text"` の要素だけからなる配列（`tool_result` を含む配列は数えない） ⑥本文が `Another Claude session sent a message` で始まらず、`<teammate-message` を含まない ⑦本文が `<bash-stdout>`・`<bash-stderr>`・`<local-command-stdout>`・`<local-command-stderr>` で始まらない ⑧`isCompactSummary` が true でない（会話の圧縮後にモデルが書いた要約の行。`type` は `"user"` で `isMeta` も `origin` も無い）。`<command-args>` を含む行（スラッシュコマンドの引数）と `<bash-input>` を含む行（主が `!` で打ったシェルの入力）は、タグを外さずに本文として比べなければならない（SHALL）。各入力は `plugins/dev-workflow/tests/owner-reply-check.bats` で 1 件ずつ固定しなければならない（MUST）。

守備範囲: ①入力の出どころは、Claude Code が書いた会話ログの 1 行 1 イベントの JSON で、形式は 2026-10-07 時点の実物（`origin` の付く行と付かない行が混在する）に合わせる ②拾いたい誤りは、アシスタントの発言・サブエージェントの会話・ツールの結果・他のセッションやチームメイトからの転送・`isMeta` の差し込み・`!` のシェルやローカルコマンドの出力・会話の圧縮後の要約を主の発言として数えること ③通ることを許す入力は、`origin` の無い古い形式の主の発言、`<bash-input>` の行（主が `!` で打った入力）、`<command-args>` の行（スラッシュコマンドの引数）、`type: "text"` の要素だけからなる配列の本文、Orca の親セッションが子のターミナルに打ち込んだ許容の文は `origin.kind: "human"` で残るので主の発言として通りうる（一致した発言の全文を読んでも主が打った文と区別できない限界であり、親が許容を打ち込まないことは保証されていない）。ローカルの会話ログ（`.jsonl`）の改変・追記は検知しない。Claude Code が今後足す未知の差し込みの形は、8 条件のどれにも当たらなければ主の発言として通りうる ④会話ログの形式が変わるたびに条件を足し続けて網羅することを、この要件の完了条件にしない（MUST NOT）。形式の変化に気づいたら bats の入力を実物から取り直す。

#### Scenario: 通常の発言を通す

- **WHEN** `type: "user"`・`origin.kind: "human"`・文字列の本文の行に原文が含まれる
- **THEN** exit 0 を返す

#### Scenario: /develop の引数を通す

- **WHEN** 本文が `<command-name>/dev-workflow:develop</command-name>` と `<command-args>721 許容する</command-args>` を含む行で、原文が `721 許容する`
- **THEN** exit 0 を返す

#### Scenario: ! で打った gh pr comment の入力を通す

- **WHEN** `origin` の無い `type: "user"` の行の本文が `<bash-input> gh pr comment 868 --body "許容する"</bash-input>` で、原文が `許容する`
- **THEN** exit 0 を返す

#### Scenario: アシスタントの発言を通さない

- **WHEN** 原文を含むのが `type: "assistant"` の行だけ
- **THEN** exit 1 を返す

#### Scenario: サブエージェントの会話を通さない

- **WHEN** 原文を含むのが `isSidechain: true` の `type: "user"` の行だけ
- **THEN** exit 1 を返す

#### Scenario: ツールの結果を通さない

- **WHEN** 原文を含むのが `message.content` に `tool_result` の要素を持つ `type: "user"` の行だけ
- **THEN** exit 1 を返す

#### Scenario: 他のセッションからの転送を通さない

- **WHEN** 原文を含むのが、`origin` も `isMeta` も無く本文が `Another Claude session sent a message` で始まる行だけ
- **THEN** exit 1 を返す

#### Scenario: チームメイトからの転送を通さない

- **WHEN** 原文を含むのが、本文に `<teammate-message` を含む行だけ
- **THEN** exit 1 を返す

#### Scenario: isMeta の行を通さない

- **WHEN** 原文を含むのが `isMeta: true` の `type: "user"` の行だけ
- **THEN** exit 1 を返す

#### Scenario: origin が null の行

- **WHEN** 原文を含むのが、`type: "user"` で `origin` の値が null の行だけ
- **THEN** 主の発言として数えず exit 1 を返す（`origin` のキーが無い `<bash-input>` の行は従来どおり数える）

#### Scenario: 圧縮後の要約の行を通さない

- **WHEN** 原文を含むのが、`isCompactSummary: true`・`isVisibleInTranscriptOnly: true` で `isMeta` も `origin` も無い `type: "user"` の行だけ（本文が `This session is being continued from a previous conversation` で始まるもの、および本文が別の文字列で始まるもの）
- **THEN** exit 1 を返す

#### Scenario: isCompactSummary が false の行は通す

- **WHEN** 原文を含むのが、`isCompactSummary: false` で他の条件をすべて満たす `type: "user"` の行
- **THEN** exit 0 を返す
