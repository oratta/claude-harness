## MODIFIED Requirements

### Requirement: 主の発言として数える行と数えない行

owner-reply-check.sh は、会話ログの行のうち次のすべてを満たすものだけを主の発言として数えなければならない（SHALL）: ①`type` が `"user"` ②`isSidechain` が true でない ③`isMeta` が true でない ④`origin` のキーがあるなら（値が null でも）`origin.kind` が `"human"` ⑤`message.content` が文字列、または `type: "text"` の要素だけからなる配列（`tool_result` を含む配列は数えない） ⑥本文が `Another Claude session sent a message` で始まらず、`<teammate-message` を含まない ⑦本文が `<bash-stdout>`・`<bash-stderr>`・`<local-command-stdout>`・`<local-command-stderr>` で始まらない ⑧`isCompactSummary` が true でない（会話の圧縮後にモデルが書いた要約の行。`type` は `"user"` で `isMeta` も `origin` も無い） ⑨本文（先頭の空白を除く）が `主の返事（親エピック #` か `親エピック #` で始まらず、本文の `<command-args>` の中身（先頭の空白を除く）が `#<数字> （エピック #<数字> の子。` で始まらない（エピックの親が子の端末に打ち込んだ返事と、`epic-dispatch.sh` の `launch` と `reply --relaunch` が打つ起動の指示）。`<command-args>` を含む行（スラッシュコマンドの引数）と `<bash-input>` を含む行（主が `!` で打ったシェルの入力）は、⑨に当たらなければタグを外さずに本文として比べなければならない（SHALL）。この条件は既定の使い方・`--locate`・`--relayed` のすべてで同じでなければならない（MUST）。各入力は `plugins/dev-workflow/tests/owner-reply-check.bats` で 1 件ずつ固定しなければならない（MUST）。

守備範囲: ①入力の出どころは、Claude Code が書いた会話ログの 1 行 1 イベントの JSON で、形式は 2026-10-07 時点の実物（`origin` の付く行と付かない行が混在する）と、2026-10-15 時点の Orca 経路のエピックの親と子の実物に合わせる ②拾いたい誤りは、アシスタントの発言・サブエージェントの会話・ツールの結果・他のセッションやチームメイトからの転送・`isMeta` の差し込み・`!` のシェルやローカルコマンドの出力・会話の圧縮後の要約・エピックの親が決まった頭を付けて子に打ち込んだ返事・子を起動する指示を主の発言として数えること ③通ることを許す入力は、`origin` の無い古い形式の主の発言、`<bash-input>` の行（主が `!` で打った入力）、`<command-args>` の行（スラッシュコマンドの引数。起動の指示の形を除く）、`type: "text"` の要素だけからなる配列の本文、Orca の親セッションが決まった頭を付けずに子のターミナルに打ち込んだ文は `origin.kind: "human"` で残るので主の発言として通りうる（一致した発言の全文を読んでも主が打った文と区別できない限界であり、親が頭の無い文を打ち込まないことは保証されていない）。ローカルの会話ログ（`.jsonl`）の改変・追記は検知しない。Claude Code が今後足す未知の差し込みの形は、9 条件のどれにも当たらなければ主の発言として通りうる。`isVisibleInTranscriptOnly: true` でも `isCompactSummary` が true でない行は主の発言として通りうる（要約以外にこの属性が付くかを確かめていないため、除く材料にしていない）。主が自分で `親エピック #` と書き始めた発言は数えない（確かめられない側に倒れ、主に聞き直す） ④会話ログの形式が変わるたびに条件を足し続けて網羅することを、この要件の完了条件にしない（MUST NOT）。形式の変化に気づいたら bats の入力を実物から取り直す。

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

#### Scenario: 親が頭を付けて打ち込んだ返事を通さない

- **WHEN** 原文を含むのが、`origin.kind: "human"` の `type: "user"` の行で、本文が `主の返事（親エピック #1038 経由）: 許容` のもの、および本文が `親エピック #1038 から: 主が会話で『許容』と返した` のものだけ
- **THEN** exit 1 を返す

#### Scenario: 子を起動する指示を通さない

- **WHEN** 原文を含むのが、本文に `<command-args>#1034 （エピック #1038 の子。返事を受けて起動し直し） 主の返事（親エピック #1038 経由）: 許容</command-args>` を含む行だけ
- **THEN** exit 1 を返す

## ADDED Requirements

### Requirement: owner-reply-check.sh は主の発言の場所を引き、親経由の返事を場所で確かめる

`plugins/dev-workflow/scripts/owner-reply-check.sh` は、既定の使い方（`<セッション ID> <原文>`）に加えて、1 つ目の引数が `--locate` か `--relayed` のときの 2 つの使い方を持たなければならない（MUST）。この 2 つの使い方では、要件「owner-reply-check.sh は会話ログに主の発言が実在するかを終了コードで返す」の引数の数の規定はこの要件の規定に置き換わる。読む会話ログ（`<projects>/*/<セッション ID>.jsonl` だけで、`subagents/` の下は読まない）、主の発言の 9 条件、`python3` が無い・会話ログが無い・読めないときの exit 2 は既定の使い方と同じでなければならない（MUST）。

**`--locate <セッション ID> <原文>`** は、既定の使い方と同じ比べ方で一致した主の発言ごとに `MATCH: <timestamp> <uuid> <空白をまとめた本文の全文>` を出し、最後に `MATCHES=<件数>` を出さなければならない（MUST）。`uuid` の無い行は出さず、件数にも数えない（MUST）。終了コードは既定の使い方と同じ（0 = 1 件以上 / 1 = 0 件 / 2 = 確かめられない）。

**`--relayed <セッション ID> <uuid> <停止の記録の作成日時> <停止の記録の URL>`** は、次をこの順で確かめなければならない（MUST）。

| 順 | 確かめること | 落ちたときの出力と終了コード |
|---|---|---|
| 1 | 引数がちょうど 4 個、セッション ID と uuid が UUID の形、作成日時が ISO 8601 の日時として読める、URL が `https://` で始まる | 使い方を stderr に出して exit 2 |
| 2 | 会話ログに `uuid` がその値の行がある | `REASON=not-found`・`MATCHES=0`、exit 1 |
| 3 | その行が主の発言の 9 条件を満たす | `REASON=not-owner`・`MATCHES=0`、exit 1 |
| 4 | その行の timestamp が作成日時より後（時刻として比べる。`Z` と `+00:00` の違いは同じに扱う） | `REASON=not-after`・`MATCHES=0`、exit 1 |
| 5 | 作成日時より後で、その行の timestamp より前の、`type: "assistant"` で `isSidechain` が true でない行のどれかの `type: "text"` の本文に、URL が文字列として含まれる | `REASON=not-asked`・`MATCHES=0`、exit 1 |

すべて通れば `MATCH: <timestamp> <空白をまとめた本文の全文>` と `MATCHES=1` を出して exit 0 で終わらなければならない（MUST）。行の timestamp を読めないときは exit 2 で終わらなければならない（MUST）。許容の語は確かめない（全文は呼び出し側が読む）。

守備範囲: ①入力の出どころは、エピックの親が `reply --as owner` の文の末尾に添えた親のセッション ID と uuid（子の本体が写す）、子の記録先の最新の `子の停止: 主の返事待ち` のコメントの作成日時と URL（子の本体と G が `gh api` で読む）、同じ PC の親のセッションの会話ログ。親・子・G は協力的だが、写し間違い・別の止まりの記録との取り違えをする前提で扱う ②拾いたい誤りは、主の入力でない行（ツールの結果・親の発言・要約・hook の差し込み・上の親からの打ち込み）の uuid、止まる前の主の発言の uuid、親がこの止まりを主に報告していないのに別の件の主の答えを送ったもの、を主の返事として通すこと ③通ることを許す入力は、親の報告と主の答えのあいだに会話の圧縮が挟まったもの（元の行は jsonl に残る）、2 件の止まりをまとめて報告した親への 1 つの答え（両方で通る。どちらの子への答えかは呼び出し側が全文で読む）、同じ uuid の行が会話を引き継いだ別のセッションのファイルにも写っているもの（指定したセッションのファイルだけを読む）。会話ログの改変・追記は検知しない。親と子が別の PC や別の `CLAUDE_CONFIG_DIR` で動くと会話ログが見つからず exit 2 になる ④ここに挙げた以外の偽造の経路を見つけるたびに検査を足し、穴を塞ぎ切ることをこの要件の完了条件にしない（MUST NOT）。

#### Scenario: 場所を引く

- **WHEN** 会話ログに uuid `u1` の主の発言「1034は許容」があり、`--locate <ID> 1034は許容` で呼ぶ
- **THEN** exit 0 で `MATCH: <timestamp> u1 1034は許容` と `MATCHES=1` を出す

#### Scenario: 親経由の返事が通る

- **WHEN** 停止の記録の作成日時より後に、親の発言にその URL があり、そのあとに uuid `u1` の主の発言「許容」がある
- **THEN** `--relayed <ID> u1 <作成日時> <URL>` は exit 0 で `MATCH: <timestamp> 許容` と `MATCHES=1` を出す

#### Scenario: 主の入力でない行の uuid では通らない

- **WHEN** 指した uuid の行が、ツールの結果・親の発言・圧縮後の要約・`主の返事（親エピック #` で始まる打ち込み・起動の指示のどれか
- **THEN** `REASON=not-owner` を出して exit 1 を返す

#### Scenario: 無い uuid では通らない

- **WHEN** 会話ログに指した uuid の行が無い
- **THEN** `REASON=not-found` を出して exit 1 を返す

#### Scenario: 止まる前の発言では通らない

- **WHEN** 指した uuid の主の発言の timestamp が停止の記録の作成日時より前
- **THEN** `REASON=not-after` を出して exit 1 を返す

#### Scenario: 親がその止まりを報告していなければ通らない

- **WHEN** 停止の記録の作成日時と主の発言のあいだの親の発言のどれにも停止の記録の URL が無い（URL を書いた親の発言が停止より前にしか無いときを含む）
- **THEN** `REASON=not-asked` を出して exit 1 を返す

#### Scenario: 引数の不備は確かめられない

- **WHEN** `--relayed` の引数が 3 個、uuid が UUID の形でない、または作成日時を日時として読めない
- **THEN** exit 2 を返す
