## MODIFIED Requirements

### Requirement: 主の発言として数える行と数えない行

owner-reply-check.sh は、会話ログの行のうち次のすべてを満たすものだけを主の発言として数えなければならない（SHALL）: ①`type` が `"user"` ②`isSidechain` が true でない ③`isMeta` が true でない（ただし④でチャンネルの行として数える行は、`isMeta` が true でも除かない） ④`origin` のキーがあるなら（値が null でも）`origin.kind` が `"human"`、または `origin.kind` が `"channel"` で要件「チャンネル経由の発言は、許可された送信者のものだけを主の発言として数える」の条件を満たす ⑤`message.content` が文字列、または `type: "text"` の要素だけからなる配列（`tool_result` を含む配列は数えない） ⑥本文が `Another Claude session sent a message` で始まらず、`<teammate-message` を含まない ⑦本文が `<bash-stdout>`・`<bash-stderr>`・`<local-command-stdout>`・`<local-command-stderr>` で始まらない ⑧`isCompactSummary` が true でない（会話の圧縮後にモデルが書いた要約の行。`type` は `"user"` で `isMeta` も `origin` も無い） ⑨本文（先頭の空白を除く）が `主の返事（親エピック #` か `親エピック #` で始まらず、本文の `<command-args>` の中身（先頭の空白を除く）が `#<数字> （エピック #<数字> の子。` か、子の `#<数字>` の前に `<owner>/<repo>` を付けた形（例 `genetta-inc/flatmate#892 （エピック #1810 の子。`）で始まらない（エピックの親が子の端末に打ち込んだ返事と、`epic-dispatch.sh` の `launch` と `reply --relaunch` が打つ起動の指示）。`<command-args>` を含む行（スラッシュコマンドの引数）と `<bash-input>` を含む行（主が `!` で打ったシェルの入力）は、⑨に当たらなければタグを外さずに本文として比べなければならない（SHALL）。④でチャンネルの行として数える行は、⑥・⑦・⑨を開きタグと閉じタグを外した中身に当てなければならない（MUST）。この条件は既定の使い方・`--locate`・`--relayed` のすべてで同じでなければならない（MUST）。各入力は `plugins/dev-workflow/tests/owner-reply-check.bats` で 1 件ずつ固定しなければならない（MUST）。

守備範囲: ①入力の出どころは、Claude Code が書いた会話ログの 1 行 1 イベントの JSON で、形式は 2026-10-07 時点の実物（`origin` の付く行と付かない行が混在する）と、2026-10-15 時点の Orca 経路のエピックの親と子の実物に合わせる（チャンネルの行の形は 2026-10-20 時点の実物に合わせる。チャンネルの行は `isMeta: true` で残るので、③の例外で扱う） ②拾いたい誤りは、アシスタントの発言・サブエージェントの会話・ツールの結果・他のセッションやチームメイトからの転送・`isMeta` の差し込み・`!` のシェルやローカルコマンドの出力・会話の圧縮後の要約・エピックの親が決まった頭を付けて子に打ち込んだ返事・子を起動する指示を主の発言として数えること ③通ることを許す入力は、`origin` の無い古い形式の主の発言、`<bash-input>` の行（主が `!` で打った入力）、`<command-args>` の行（スラッシュコマンドの引数。起動の指示の形を除く）、`type: "text"` の要素だけからなる配列の本文、Orca の親セッションが決まった頭を付けずに子のターミナルに打ち込んだ文は `origin.kind: "human"` で残るので主の発言として通りうる（一致した発言の全文を読んでも主が打った文と区別できない限界であり、親が頭の無い文を打ち込まないことは保証されていない）。ローカルの会話ログ（`.jsonl`）の改変・追記は検知しない。Claude Code が今後足す未知の差し込みの形は、9 条件のどれにも当たらなければ主の発言として通りうる。`isVisibleInTranscriptOnly: true` でも `isCompactSummary` が true でない行は主の発言として通りうる（要約以外にこの属性が付くかを確かめていないため、除く材料にしていない）。主が自分で `親エピック #` と書き始めた発言は数えない（確かめられない側に倒れ、主に聞き直す） ④会話ログの形式が変わるたびに条件を足し続けて網羅することを、この要件の完了条件にしない（MUST NOT）。形式の変化に気づいたら bats の入力を実物から取り直す。

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

- **WHEN** 原文を含むのが `isMeta: true` の `type: "user"` の行で、`origin` が無いか `origin.kind` が `"human"` の行だけ
- **THEN** exit 1 を返す

#### Scenario: origin が null の行

- **WHEN** 原文を含むのが、`type: "user"` で `origin` の値が null の行だけ
- **THEN** 主の発言として数えず exit 1 を返す（`origin` のキーが無い `<bash-input>` の行は従来どおり数える）

#### Scenario: human と channel 以外の origin.kind の行を通さない

- **WHEN** 原文を含むのが、`origin.kind` が `"peer"`・`"task-notification"` の `type: "user"` の行だけ（`OWNER_REPLY_CHANNEL_SENDERS` の設定の有無によらない）
- **THEN** exit 1 を返す

#### Scenario: 圧縮後の要約の行を通さない

- **WHEN** 原文を含むのが、`isCompactSummary: true`・`isVisibleInTranscriptOnly: true` で `isMeta` も `origin` も無い `type: "user"` の行だけ（本文が `This session is being continued from a previous conversation` で始まるもの、および本文が別の文字列で始まるもの）
- **THEN** exit 1 を返す

#### Scenario: isCompactSummary が false の行は通す

- **WHEN** 原文を含むのが、`isCompactSummary: false` で他の条件をすべて満たす `type: "user"` の行
- **THEN** exit 0 を返す

#### Scenario: 親が頭を付けて打ち込んだ返事を通さない

- **WHEN** 原文を含むのが、`origin.kind: "human"` の `type: "user"` の行で、本文が `主の返事（親エピック #1038 経由）: 許容` のもの、および本文が `親エピック #1038 から: 主が会話で『許容』と返した` のものだけ
- **THEN** exit 1 を返す

#### Scenario: 子を起動する指示を通さない

- **WHEN** 原文を含むのが、本文に `<command-args>#1034 （エピック #1038 の子。返事を受けて起動し直し） 主の返事（親エピック #1038 経由）: 許容</command-args>` を含む行だけ
- **THEN** exit 1 を返す

#### Scenario: 別のリポジトリの子を起動する指示を通さない

- **WHEN** 原文が `許容` で、原文を含むのが、本文に `<command-args>genetta-inc/flatmate#892 （エピック #1810 の子。エピックのリポジトリ oratta/claude-harness。返事を受けて起動し直し） 主の返事（親エピック #1810（oratta/claude-harness）経由）: 許容</command-args>` を含む行と、`<command-args>genetta-inc/flatmate#892 （エピック #1810 の子。エピックのリポジトリ oratta/claude-harness。親ワークツリー /p から Orca で起動） 許容</command-args>` を含む行だけ
- **THEN** exit 1 を返す
