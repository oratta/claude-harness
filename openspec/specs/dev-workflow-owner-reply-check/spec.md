# dev-workflow-owner-reply-check Specification

## Purpose
主が会話で返したリスク許容の発言が、そのセッションの会話ログに主の発言として実在するかを確かめるスクリプト `owner-reply-check.sh` の振る舞いを定める。pr-review-gate 手順 5 の「会話で受領」の真正性確認が、この終了コードと出力を使う。develop の本体も、会話で受けたリスク許容を G に渡す前に先に回し、出力の `MATCH:` 行の timestamp を G に渡す日時として使う。

## Requirements

### Requirement: owner-reply-check.sh は会話ログに主の発言が実在するかを終了コードで返す

`plugins/dev-workflow/scripts/owner-reply-check.sh` は、既定の使い方（1 つ目の引数が `--locate` でも `--relayed` でも `--delegated` でもないとき）では `<セッション ID> <原文>` の 2 引数を受け取り、`${OWNER_REPLY_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/<セッション ID>.jsonl` に当たる会話ログだけを読まなければならない（SHALL）。`<セッション ID>/subagents/` の下の会話ログは読んではならない（MUST NOT）。原文と各発言の本文は、連続する空白（改行を含む）を 1 個の空白にまとめ前後の空白を落としてから部分一致で比べなければならない（SHALL）。主の発言のうち原文を含むものが 1 件以上あれば、一致した発言ごとに `MATCH: <その行の timestamp> <空白をまとめた本文の全文>` を出し、最後に `MATCHES=<件数>` を出して exit 0 で終わらなければならない（SHALL）。1 件も無ければ `MATCHES=0` を出して exit 1 で終わらなければならない（SHALL）。既定の使い方で引数の数が 2 でない、セッション ID が UUID の形でない、原文が空白を除いて空（空白のまとめ方で空になる原文を含む。U+0085 だけの原文など）、会話ログが 1 つも見つからない、見つけた会話ログを読めない（権限が無い・探索のあとで消えたなど）、`python3` が無い、のどれかなら exit 2 で終わらなければならない（SHALL）。exit 2 は「確かめられない」であり、呼び出し側は exit 1 と同じく通さない側に倒す。1 つ目の引数が `--locate` か `--relayed` のときの引数の数・出力・終了コードは、要件「owner-reply-check.sh は主の発言の場所を引き、親経由の返事を場所で確かめる」に従わなければならない（SHALL）。1 つ目の引数が `--delegated` のときは、要件「owner-reply-check.sh --delegated は主の委任の確認を親の会話ログの場所で確かめる」に従わなければならない（SHALL）。

守備範囲: ①入力の出どころは、pr-review-gate の G が宣言コメントの `会話で受領` の記録から写したセッション ID と原文、およびゲートが動いている PC の `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects` の下にある Claude Code の会話ログである。G は協力的だが、記録の写し間違い・別セッションの ID の取り違え・原文の切り詰めをする前提で扱う ②拾いたい誤りは、記録したセッションの会話ログに原文を含む主の発言が無いこと、記録したセッションの会話ログをこの PC で読めないのに通すこと、引数の不備を「一致なし」と区別せずに扱うこと ③通ることを許す入力は、改行や字下げだけが違う原文、発言の一部だけを写した原文（「許容しない」の一部の「許容」も一致として返す。許容の意思は呼び出し側が全文で読む）、同じ原文を含む発言が複数あるセッション（すべて `MATCH:` で返す）、Orca の親セッションが決まった頭（`主の返事（親エピック #` / `親エピック #`）を付けずに子のターミナルに打ち込んだ許容の文は `origin.kind: "human"` で残るので主の発言として通りうる（一致した発言の全文を読んでも主が打った文と区別できない限界であり、親が頭の無い文を打ち込まないことは保証されていない。決まった頭を付けた文と子を起動する指示は、要件「主の発言として数える行と数えない行」の⑨で数えない）。ローカルの会話ログ（`.jsonl`）の改変・追記は検知しない ④ここに挙げた以外の偽造の経路を見つけるたびに検査を足し、穴を塞ぎ切ることをこの要件の完了条件にしない（MUST NOT）。

守備範囲①の補足（呼び出し元）: 入力を作ってこのスクリプトを回すのは pr-review-gate の G だけではない。develop の本体も、会話で受けたリスク許容を G に渡す前に、自分のセッション ID（`$CLAUDE_CODE_SESSION_ID`）と会話で受けた発言から写した原文で先に回し、`MATCH:` 行の timestamp を G に渡す日時として使う。真正性確認そのものは、本体から渡された値（セッション ID・日時・原文）で G が宣言コメントに記録を追記し、その記録で回して行う（pr-review-gate 手順 5 の「会話で受領」）。本体が作る入力も、G が作る入力と同じ前提（協力的だが、記録の写し間違い・別セッションの ID の取り違え・原文の切り詰めをする）で、この守備範囲に入る。Orca 経路のエピックでは、親は Orca 経路の手順 8 で `--locate` を回して主の答えの発言の uuid を引き、子の本体と保留の解除の G は `--relayed` で親経由の返事を確かめる（入力の前提は同じ。使い方ごとの規定は要件「owner-reply-check.sh は主の発言の場所を引き、親経由の返事を場所で確かめる」）。スクリプトの振る舞いは呼び出し元で変わらず、この段落は本体に手順を課さない（本体の手順の正本は develop の SKILL.md）。

#### Scenario: 主の発言に一致する

- **WHEN** テスト用の会話ログに主の発言「許容する。進めて」があり、原文「許容する」で呼ぶ
- **THEN** exit 0 で、`MATCH: <timestamp> 許容する。進めて` と `MATCHES=1` を出す

#### Scenario: 改行や字下げの違いは無視する

- **WHEN** 主の発言が改行を含み、原文はその改行を空白 1 個に置き換えたもの
- **THEN** exit 0 を返す

#### Scenario: 一致が無い

- **WHEN** 会話ログに原文を含む主の発言が無い
- **THEN** `MATCHES=0` を出して exit 1 を返す

#### Scenario: 会話ログが無い

- **WHEN** 形は正しいが、どのプロジェクトの下にもそのセッション ID の会話ログが無い（別の PC で回答を受けた場合を含む）
- **THEN** exit 2 を返す

#### Scenario: 引数の不備

- **WHEN** 引数が 1 個、セッション ID が UUID の形でない、または原文が空白だけ
- **THEN** exit 2 を返す

#### Scenario: 空白のまとめ方で空になる原文

- **WHEN** 原文が U+0085 だけで、会話ログに主の発言がある
- **THEN** exit 2 を返し、`MATCH:` を出さない

#### Scenario: 会話ログを読めない

- **WHEN** 会話ログは見つかったが、権限が無いなどで読めない
- **THEN** exit 1 ではなく exit 2 を返す

#### Scenario: スイート名で回せる

- **WHEN** `scripts/test.sh owner-reply-check` を実行する
- **THEN** `plugins/dev-workflow/tests/owner-reply-check.bats` が回り、exit 0 で終わる

### Requirement: 主の発言として数える行と数えない行

owner-reply-check.sh は、会話ログの行のうち次のすべてを満たすものだけを主の発言として数えなければならない（SHALL）: ①`type` が `"user"` ②`isSidechain` が true でない ③`isMeta` が true でない（ただし④でチャンネルの行として数える行は、`isMeta` が true でも除かない） ④`origin` のキーがあるなら（値が null でも）`origin.kind` が `"human"`、または `origin.kind` が `"channel"` で要件「チャンネル経由の発言は、許可された送信者のものだけを主の発言として数える」の条件を満たす ⑤`message.content` が文字列、または `type: "text"` の要素だけからなる配列（`tool_result` を含む配列は数えない） ⑥本文が `Another Claude session sent a message` で始まらず、`<teammate-message` を含まない ⑦本文が `<bash-stdout>`・`<bash-stderr>`・`<local-command-stdout>`・`<local-command-stderr>` で始まらない ⑧`isCompactSummary` が true でない（会話の圧縮後にモデルが書いた要約の行。`type` は `"user"` で `isMeta` も `origin` も無い） ⑨本文（先頭の空白を除く）が `主の返事（親エピック #` か `親エピック #` で始まらず、本文の `<command-args>` の中身（先頭の空白を除く）が `#<数字> （エピック #<数字> の子。` で始まらない（エピックの親が子の端末に打ち込んだ返事と、`epic-dispatch.sh` の `launch` と `reply --relaunch` が打つ起動の指示）。`<command-args>` を含む行（スラッシュコマンドの引数）と `<bash-input>` を含む行（主が `!` で打ったシェルの入力）は、⑨に当たらなければタグを外さずに本文として比べなければならない（SHALL）。④でチャンネルの行として数える行は、⑥・⑦・⑨を開きタグと閉じタグを外した中身に当てなければならない（MUST）。この条件は既定の使い方・`--locate`・`--relayed` のすべてで同じでなければならない（MUST）。各入力は `plugins/dev-workflow/tests/owner-reply-check.bats` で 1 件ずつ固定しなければならない（MUST）。

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

### Requirement: owner-reply-check.sh は主の発言の場所を引き、親経由の返事を場所で確かめる

`plugins/dev-workflow/scripts/owner-reply-check.sh` は、既定の使い方（`<セッション ID> <原文>`）に加えて、1 つ目の引数が `--locate` か `--relayed` のときの 2 つの使い方を持たなければならない（MUST）。読む会話ログ（`<projects>/*/<セッション ID>.jsonl` だけで、`subagents/` の下は読まない）、主の発言の 9 条件、`python3` が無い・会話ログが無い・読めないときの exit 2 は既定の使い方と同じでなければならない（MUST）。

**`--locate <セッション ID> <原文>`** は、既定の使い方と同じ比べ方で一致した主の発言ごとに `MATCH: <timestamp> <uuid> <空白をまとめた本文の全文>` を出し、最後に `MATCHES=<件数>` を出さなければならない（MUST）。`uuid` の無い行は出さず、件数にも数えない（MUST）。終了コードは既定の使い方と同じ（0 = 1 件以上 / 1 = 0 件 / 2 = 確かめられない）。

**`--relayed <セッション ID> <uuid> <停止の記録の作成日時> <停止の記録の URL>`** は、次をこの順で確かめなければならない（MUST）。

| 順 | 確かめること | 落ちたときの出力と終了コード |
|---|---|---|
| 1 | 引数がちょうど 4 個、セッション ID と uuid が UUID の形、作成日時が ISO 8601 の日時として読める、URL が `https://` で始まる | 使い方を stderr に出して exit 2 |
| 2 | 会話ログに `uuid` がその値の行がある | `REASON=not-found`・`MATCHES=0`、exit 1 |
| 3 | その行が主の発言の 9 条件を満たす | `REASON=not-owner`・`MATCHES=0`、exit 1 |
| 4 | その行の timestamp が作成日時より後（時刻として比べる。`Z` と `+00:00` の違いは同じに扱う） | `REASON=not-after`・`MATCHES=0`、exit 1 |
| 5 | 作成日時より後で、その行の timestamp より前の、`type: "assistant"` で `isSidechain` が true でない行のどれかの `type: "text"` の本文に、URL の文字列が、前後を URL の続きでない文字（または本文の先頭・末尾）で区切られた形で含まれる（直前の文字が ASCII の英数字・`_`・`-`・`.`・`~`・`/`・`:`・`%`・`?`・`#`・`&`・`=`・`+`・`@` のどれか、または直後の文字が ASCII の英数字・`_`・`-`・`~`・`/`・`%`・`?`・`#`・`&`・`=`・`+`・`@` のどれかのときは、別の URL の一部なので数えない。直後の `.`・`:`・括弧・句読点は URL を続けない文字として扱う（文末の句点とコロンを URL の続きと見ないため）。`…#issuecomment-123` は `…#issuecomment-1234` に一致しない） | `REASON=not-asked`・`MATCHES=0`、exit 1 |
| 6 | 5 の URL を含む親の発言のうち timestamp がいちばん新しいものより後で、その行の timestamp より前に、主の発言の 9 条件を満たす別の行が無い | `REASON=not-direct`・`MATCHES=0`、exit 1 |

すべて通れば `MATCH: <timestamp> <空白をまとめた本文の全文>` と `MATCHES=1` を出して exit 0 で終わらなければならない（MUST）。行の timestamp を読めないときは exit 2 で終わらなければならない（MUST）。許容の語は確かめない（全文は呼び出し側が読む）。

守備範囲: ①入力の出どころは、エピックの親が `reply --as owner` の文の末尾に添えた親のセッション ID と uuid（子の本体が写す）、子の記録先の最新の `子の停止: 主の返事待ち` のコメントの作成日時と URL（子の本体と G が `gh api` で読む）、同じ PC の親のセッションの会話ログ。親・子・G は協力的だが、写し間違い・別の止まりの記録との取り違えをする前提で扱う ②拾いたい誤りは、主の入力でない行（ツールの結果・親の発言・要約・hook の差し込み（`isMeta: true`）・サブエージェントの会話（`isSidechain: true`）・上の親からの打ち込み）の uuid、止まる前の主の発言の uuid、親がこの止まりを主に報告していないのに別の件の主の答えを送ったもの、親の報告のあとに主が別の件へ返した答えを送ったもの、を主の返事として通すこと ③通ることを許す入力は、親の報告と主の答えのあいだに会話の圧縮が挟まったもの（元の行は jsonl に残る）、2 件の止まりをまとめて報告した親への 1 つの答え（両方で通る。どちらの子への答えかは呼び出し側が全文で読む）、同じ uuid の行が会話を引き継いだ別のセッションのファイルにも写っているもの（指定したセッションのファイルだけを読む）。親の報告のあとに主が聞き返してから答えたもの（あいだに主の発言が挟まる）は通さない（`not-direct`。主に子のタブで打ってもらう従来の動きに戻るだけで、誤って通すことはない）。会話ログの改変・追記は検知しない。親と子が別の PC や別の `CLAUDE_CONFIG_DIR` で動くと会話ログが見つからず exit 2 になる ④ここに挙げた以外の偽造の経路を見つけるたびに検査を足し、穴を塞ぎ切ることをこの要件の完了条件にしない（MUST NOT）。

#### Scenario: 場所を引く

- **WHEN** 会話ログに uuid `u1` の主の発言「1034は許容」があり、`--locate <ID> 1034は許容` で呼ぶ
- **THEN** exit 0 で `MATCH: <timestamp> u1 1034は許容` と `MATCHES=1` を出す

#### Scenario: 親経由の返事が通る

- **WHEN** 停止の記録の作成日時より後に、親の発言にその URL があり、そのあとに uuid `u1` の主の発言「許容」がある
- **THEN** `--relayed <ID> u1 <作成日時> <URL>` は exit 0 で `MATCH: <timestamp> 許容` と `MATCHES=1` を出す

#### Scenario: 主の入力でない行の uuid では通らない

- **WHEN** 指した uuid の行が、ツールの結果・親の発言・圧縮後の要約・`isMeta: true` の行（hook の差し込み）・`isSidechain: true` の行（サブエージェントの会話）・`主の返事（親エピック #` で始まる打ち込み・`親エピック #` で始まる打ち込み・起動の指示のどれか
- **THEN** `REASON=not-owner` を出して exit 1 を返す

#### Scenario: 無い uuid では通らない

- **WHEN** 会話ログに指した uuid の行が無い
- **THEN** `REASON=not-found` を出して exit 1 を返す

#### Scenario: 止まる前の発言では通らない

- **WHEN** 指した uuid の主の発言の timestamp が停止の記録の作成日時より前
- **THEN** `REASON=not-after` を出して exit 1 を返す

#### Scenario: 親がその止まりを報告していなければ通らない

- **WHEN** 停止の記録の作成日時と主の発言のあいだの親の発言のどれにも停止の記録の URL が無い（URL を書いた親の発言が停止より前にしか無いとき、親の発言にあるのが停止の記録の URL を頭に持つ別のコメントの URL だけのときを含む）
- **THEN** `REASON=not-asked` を出して exit 1 を返す

#### Scenario: 停止の記録の URL を頭に持つ別のコメントの URL では通らない

- **WHEN** 停止の記録の作成日時と主の発言のあいだの親の発言にあるのが、停止の記録の URL の末尾に数字を続けた別のコメントの URL（`…#issuecomment-123` に対する `…#issuecomment-1234`）だけ
- **THEN** `REASON=not-asked` を出して exit 1 を返す（URL の直後が `）`・`。` などの URL を続けない文字なら一致として数える）

#### Scenario: 報告のあとに別の主の発言が挟まると通らない

- **WHEN** 停止の記録の URL を書いた最後の親の発言と、指した uuid の主の発言のあいだに、主の発言の 9 条件を満たす別の行がある
- **THEN** `REASON=not-direct` を出して exit 1 を返す（別の主の発言が URL を書いた最後の親の発言より前にあるだけなら通る）

#### Scenario: 引数の不備は確かめられない

- **WHEN** `--relayed` の引数が 3 個、uuid が UUID の形でない、または作成日時を日時として読めない
- **THEN** exit 2 を返す

### Requirement: 親経由の返事の合否を、偽 2 件・本物 1 件の混在ログで機械的に固定する

`plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats` は、1 本の親の会話ログ（`OWNER_REPLY_PROJECTS_DIR` で差し替えたテスト用のもの）に、偽の文 2 種と本物の文 1 件を同居させ、同じ停止の記録の作成日時と URL で `owner-reply-check.sh --relayed` を当てて、次を固定しなければならない（MUST）。`scripts/test.sh owner-reply-relayed-scenario` の 1 コマンドで、主の入力・GitHub・Orca を使わずに合否が出なければならない（MUST）。

| 入力 | 期待 |
|---|---|
| 偽 1: uuid が親の発言の行、またはツールの結果の行 | `REASON=not-owner`・`MATCHES=0`、exit 1（2 つの行それぞれ） |
| 偽 2: 停止の記録の作成日時より前の主の発言の行 | `REASON=not-after`・`MATCHES=0`、exit 1 |
| 本物: 停止の記録の URL を書いた親の報告のあとの、主の「許容」の行 | exit 0、`MATCH:` 行に「許容」、`MATCHES=1` |

偽 1 の 2 行を親の報告と本物のあいだに置き、さらに本物のあとにも置いたログで、本物は exit 0・`MATCHES=1` のままでなければならず、本物の行を含むそのログで偽 1・偽 2 は上の表どおり落ちなければならない（MUST）。

このテストの範囲（検査の守備範囲は既存要件「owner-reply-check.sh は主の発言の場所を引き、親経由の返事を場所で確かめる」のものに従う）: ①固定するのは `--relayed` の出力と終了コードまで。宣言コメントへの追記と `needs-approval` の付け外しはゲートの動作で、このテストでは守らない（ゲートが `REASON` を見て通さない側に倒す文言は pr-review-gate と develop の bats が固定する）。実機の Orca を使う確認は、親・子・ゲートの継ぎ目を変えたときに残す ②実 GitHub に試しのエピック・子 issue・PR を作る方式は採らない（外部状態が残るため）。

#### Scenario: 偽の文は落ち、本物の文は通る
- **WHEN** 偽 1・偽 2・本物の行を含む 1 本のテスト用会話ログに `--relayed` を行ごとに当てる
- **THEN** 偽 1 は `REASON=not-owner`、偽 2 は `REASON=not-after`（どちらも exit 1）、本物は exit 0 になる

#### Scenario: 偽が本物の前後にあっても判定が変わらない
- **WHEN** 偽 1 の 2 行を親の報告と本物のあいだに置き、さらに本物のあとにも置いたログに `--relayed` を当てる
- **THEN** 本物は exit 0・`MATCHES=1`、偽 1 の各行は `REASON=not-owner`、偽 2 は `REASON=not-after` のまま

### Requirement: チャンネル経由の発言は、許可された送信者のものだけを主の発言として数える

owner-reply-check.sh は、`origin.kind` が `"channel"` の行を、`isMeta` の値によらず（実物のチャンネルの行は `isMeta: true` で残る）、要件「主の発言として数える行と数えない行」の③以外の条件と次のすべてを満たすときだけ主の発言として数えなければならない（SHALL）。どれか 1 つでも満たさない行は数えてはならない（MUST NOT）。

1. `origin.server` が空でない文字列である
2. 本文（`message.content` が文字列ならそのまま、`type: "text"` の要素だけからなる配列なら各要素の `text` を改行でつないだもの）が、先頭の空白なしに開きタグで始まる。開きタグは `<channel` のあとに 0 個以上の ` <名前>="<値>"`（名前は英字か `_` で始まり英数字と `_` だけからなる。値は `"` と改行を含まない）が続き、`>` と改行で終わる 1 行目である
3. 開きタグの属性名に重複が無い
4. 開きタグの `source` 属性が `origin.server` と同じ文字列である
5. 開きタグの `user_id` 属性が空でない
6. 本文の末尾（後ろの空白を除く）が、改行のあとの `</channel>` で終わる
7. `origin.server` と `user_id` 属性の組が、環境変数 `OWNER_REPLY_CHANNEL_SENDERS` に並べた `<server>=<ID>` の組のどれかと完全に一致する
8. 1 行にチャンネルの塊がちょうど 1 つである。`message.content` が文字列か、`type: "text"` の要素がちょうど 1 つの配列であり（2 つ以上の要素の配列は数えない）、開きタグと閉じタグを外した中身に `<channel` か `</channel` のあとに空白か `>` が続く形のタグが無い（送信者は先頭の開きタグからしか読まないので、続きの塊の送信者を確かめられないため）。あわせて、中身に `user_id="` が無く、中身のどの行も `">` で終わらない（`user_id` より前に並ぶ `meta` の値に送信者が `"` と改行を入れると、開きタグが 1 行目で早く閉じて偽の `user_id` が先頭の開きタグに入り、本物の `user_id="…"` と開きタグの終わりの `">` が中身へ押し出されるため）

送信者の照合に `user` 属性（ユーザー名）を使ってはならない（MUST NOT）。数える行は、開きタグの次の行から末尾の改行と `</channel>` の前までの中身を本文として原文と比べ、`MATCH:` の行の全文にもその中身を出さなければならない（SHALL）。この判定は既定の使い方・`--locate`・`--relayed` のすべてで同じでなければならない（MUST）。

`OWNER_REPLY_CHANNEL_SENDERS` の値は、空白（改行を含む）かカンマで区切った項目の並びとする。区切ったあとの空の項目（連続した区切りや前後の区切りで生まれるもの）は数えず、残った各項目は `<空白・カンマ・= を含まない 1 文字以上>=<空白・カンマ・= を含まない 1 文字以上>` でなければならない（MUST）。未設定、または区切ったあとに項目が 1 つも無い値のときは、チャンネルの行を 1 件も数えてはならない（MUST NOT）。形に合わない項目が 1 つでもあれば、どの使い方でも会話ログの中身によらず stderr に理由を出して exit 2 で終わらなければならない（MUST）。各入力は `plugins/dev-workflow/tests/owner-reply-check.bats` で 1 件ずつ固定しなければならない（MUST）。

守備範囲: ①入力の出どころは、Claude Code が書いた会話ログのチャンネルの行（2026-10-20 時点の実物。`origin` は `{"kind":"channel","server":"plugin:discord:discord"}`、本文は Discord プラグインの通知の `meta` から Claude Code が組み立てた開きタグ・送信者が書いた中身・閉じタグの 3 つからなる）と、ゲートを回すプロセスの環境変数 `OWNER_REPLY_CHANNEL_SENDERS` である。呼び出し側（G・develop の本体・エピックの親と子）は協力的だが、設定の書き間違いをする前提で扱う ②拾いたい誤りは、主以外の送信者がチャンネルに書いた文（gene の設定ではギルドのチャンネルの送信者を絞っておらず、bot に言及すれば誰の発言でも届く）を主の発言として数えること、送信者を読めない行を数えること、送信者が中身に書いた偽の開きタグの `user_id` で照合すること、別のチャンネルの同じ文字列の ID と取り違えること、設定の誤りを「一致なし」と区別せずに扱うこと。`type: "queue-operation"` の行にも同じ本文が写るが、要件「主の発言として数える行と数えない行」の①で数えない。`isMeta: true` の行のうち③の例外で扱うのは `origin.kind` が `"channel"` の行だけで、hook などの差し込みの行（`origin` が無いか `origin.kind` が channel でない）は本文が `<channel …>` の形でも数えない ③通ることを許す入力は、許可された送信者が書いたリアクションの行（中身が `(reaction) +👍` のような文）と添付ファイルのある行、呼び出し側が `OWNER_REPLY_CHANNEL_SENDERS` を偽って渡すこと、許可された送信者のチャンネルのアカウントが乗っ取られて書かれた文。ローカルの会話ログ（`.jsonl`）とチャンネルプラグインの改変は検知しない。`meta` の値に `"` が入って開きタグの形が崩れた行、`meta` の値の `"` と改行で開きタグが早く閉じた行（中身に `user_id="` があるか、中身のどこかの行が `">` で終わる行）、中身にチャンネルのタグ（`</channel>` や `<channel …>`）を書いた行は、主の発言でも数えない。主が中身に `user_id="` と書いた発言や、行末が `">` になる発言も数えない（確かめられない側に倒れ、主に聞き直す）。Claude Code が複数のチャンネルの通知を 1 つの行にまとめた場合も、主の通知だけでも数えない ④チャンネルプラグインごとの形の違いを先回りして網羅することを、この要件の完了条件にしない（MUST NOT）。新しいチャンネルを許可された送信者に足す前に、その実物の行がこの形に合うかを確かめる。

住人の環境でこの確かめ方を使うための設定の決まり（`OWNER_REPLY_CHANNEL_SENDERS` をどこに置き、主の ID をどこで確かめるか）は、後続の #1126 が `openspec/changes/archive/2026-10-20-owner-reply-check-channel-sender/design.md`の「#1126 への引き継ぎ」を読んで決める。

#### Scenario: 許可された送信者のチャンネルの発言を通す

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが `origin` が `{"kind":"channel","server":"plugin:discord:discord"}`、本文が `<channel source="plugin:discord:discord" chat_id="1" message_id="2" user="owner" user_id="531" ts="2026-10-20T01:00:00.000Z">`・改行・`<@999> 許容する`・改行・`</channel>` の行で、原文が `許容する`
- **THEN** exit 0 を返し、`MATCH:` の行の全文は `<@999> 許容する`（開きタグと閉じタグを含まない）

#### Scenario: isMeta が true のチャンネルの行を通す

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが、Scenario「許可された送信者のチャンネルの発言を通す」の行に実物と同じ `isMeta: true`・`promptSource: "system"`・`turnOrigin: "peer"`・`userType: "external"` を付けた行
- **THEN** exit 0 を返す

#### Scenario: origin の無い isMeta の行はチャンネルの形の本文でも通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが、`isMeta: true` で `origin` の無い `type: "user"` の行で、本文が許可された送信者の開きタグ・`許容する`・閉じタグの形のものだけ
- **THEN** exit 1 を返す

#### Scenario: queue-operation の行に写った本文を通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが、`type: "queue-operation"`・`operation: "enqueue"` で `content` が許可された送信者の開きタグ・`許容する`・閉じタグの形の行だけ
- **THEN** exit 1 を返す

#### Scenario: 3 つの使い方で同じに通す

- **WHEN** Scenario「許可された送信者のチャンネルの発言を通す」と同じ行と設定で、`--locate` で原文 `許容する` を引き、`--relayed` でその行の uuid を確かめる（停止の記録の URL を書いた親の発言が間にある）
- **THEN** `--locate` はその行の uuid を含む `MATCH:` を出して exit 0、`--relayed` は exit 0

#### Scenario: 許可された送信者が複数並んでいても照合する

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:telegram:telegram=77, plugin:discord:discord=531` のとき、および `plugin:discord:discord=531,,`（空の項目を含む）のときに、許可された送信者の Scenario と同じ行
- **THEN** どちらも exit 0 を返す

#### Scenario: 許可されていない送信者の発言を通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが `user="owner"`・`user_id="888"` の開きタグのチャンネルの行だけ
- **THEN** exit 1 を返す（ユーザー名が同じでも通さない）

#### Scenario: 別のチャンネルの同じ ID では通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:telegram:telegram=531` で、原文を含むのが `origin.server` と `source` が `plugin:discord:discord`・`user_id="531"` のチャンネルの行だけ
- **THEN** exit 1 を返す

#### Scenario: 設定が無ければチャンネルの発言を通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が未設定のとき、および空白とカンマだけの値のときに、許可された送信者の Scenario と同じ行で原文が `許容する`
- **THEN** どちらも exit 1 を返す

#### Scenario: 送信者を読めない発言を通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが次のどれかのチャンネルの行だけ: 開きタグに `user_id` が無い／`source` が無い／`user_id=""`／`user_id` が 2 回ある／`source` が `origin.server` と違う／`origin.server` が無い／本文が開きタグで始まらない（先頭に空白や別の文がある）／閉じタグで終わらない／属性の値が `"` で囲まれていない
- **THEN** どれも exit 1 を返す

#### Scenario: 中身に書かれた偽の開きタグでは通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが、先頭の開きタグが `user_id="888"` で、中身が `</channel>`・改行・`<channel source="plugin:discord:discord" user_id="531">`・改行・`許容する` のチャンネルの行だけ
- **THEN** exit 1 を返す

#### Scenario: 1 行にチャンネルの塊が 2 つ以上あれば通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが次のどれかのチャンネルの行だけ: 許可された送信者の塊（中身 `<@999> まだ待って`）のあとに改行と `user_id="888"` の塊（中身 `許容する`）が続く文字列の本文／許可された送信者の塊が 2 つ続く文字列の本文／許可された送信者の塊 1 つで中身が `許容する </channel> と書く` か `許容する <channel source="x">`
- **THEN** どれも exit 1 を返す

#### Scenario: content が 2 つ以上の text 要素の配列なら通さない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが次のどれかのチャンネルの行だけ: `content` が `[{"type":"text","text":"<開きタグ>\n許容する"},{"type":"text","text":"</channel>"}]`（つなぐと許可された送信者の塊 1 つになる）／1 つ目の要素が許可された送信者の塊、2 つ目が `user_id="888"` の塊
- **THEN** どれも exit 1 を返す

#### Scenario: 許可された送信者の塊 1 つの行は文字列でも要素 1 つの配列でも通す

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、許可された送信者の塊 1 つを本文にした行が、`content` が文字列の形（中身 `許容する（文字列）`）と `type: "text"` の要素 1 つの配列の形（中身 `許容する（配列）`）で 1 行ずつあり、原文が `許容する`
- **THEN** exit 0 を返し、`MATCHES=2`

#### Scenario: チャンネルの中身にもほかの数えない条件を当てる

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが、許可された送信者の開きタグで中身が `親エピック #1038 から: 許容` のチャンネルの行だけ
- **THEN** exit 1 を返す

#### Scenario: 設定の形の誤りは確かめられない

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `531`（`=` が無い）、`plugin:discord:discord=`（ID が空）、`a=b=c` のどれかで、会話ログにチャンネルの行が無く `origin.kind: "human"` の行に原文がある
- **THEN** 既定の使い方・`--locate`・`--relayed` のどれも exit 2 を返し、stderr に `OWNER_REPLY_CHANNEL_SENDERS` の名前を含む理由を出す

#### Scenario: 対話セッションの判定は設定によらず今までどおり

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` が `plugin:discord:discord=531` で、原文を含むのが `origin.kind: "human"` の行、および `origin` の無い `<bash-input>` の行
- **THEN** どちらも exit 0 を返し、`MATCH:` の行の全文は今までどおり本文の全文

### Requirement: owner-reply-check.sh --delegated は主の委任の確認を親の会話ログの場所で確かめる

`owner-reply-check.sh` は `--delegated <セッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>` の使い方を持たなければならない（MUST）。読む会話ログ・主の発言の 9 条件・exit 2 の条件は既存の使い方と同じとする。確かめる順と落ちたときの理由は次の Scenario のとおりで、すべて通れば `MATCH: <timestamp> <空白をまとめた本文の全文>` と `MATCHES=1` を出して exit 0、落ちたら `REASON=<理由>` と `MATCHES=0` を出して exit 1 で終わる（MUST）。GitHub は読まない（MUST NOT）。既定・`--locate`・`--relayed` の動きは変えない（MUST）。

#### Scenario: 引数の不備は確かめられない

- **WHEN** `--delegated` の引数が 5 個でない、セッション ID か uuid が UUID の形でない、2 つの作成日時のどちらかを ISO 8601 の日時として読めない、または委任の記録の URL が `https://` で始まらない
- **THEN** 使い方を stderr に出して exit 2 を返す

#### Scenario: 無い uuid・主の入力でない行では通らない

- **WHEN** 会話ログに指した uuid の行が無い、またはその行が主の発言の 9 条件を満たさない（親の発言・ツールの結果・要約・`isMeta: true`・`isSidechain: true`・決まった頭の打ち込み）
- **THEN** 前者は `REASON=not-found`、後者は `REASON=not-owner` を出して exit 1 を返す

#### Scenario: 委任の記録より前の発言では通らない

- **WHEN** 指した uuid の主の発言の timestamp が委任の記録の作成日時より後でない（時刻として比べ、`Z` と `+00:00` の違いは同じに扱う）
- **THEN** `REASON=not-after` を出して exit 1 を返す

#### Scenario: 親が委任の記録を示して問うていなければ通らない

- **WHEN** 委任の記録の作成日時より後でその行より前の親の発言（`type: "assistant"` で `isSidechain` が true でない行の `type: "text"` の本文）のどれにも、委任の記録の URL が `--relayed` と同じ境界の判定で含まれない
- **THEN** `REASON=not-asked` を出して exit 1 を返す

#### Scenario: 問いのあとに別の主の発言が挟まると通らない

- **WHEN** 委任の記録の URL を書いた最後の親の発言と指した uuid の行のあいだに、主の発言の 9 条件を満たす別の行がある
- **THEN** `REASON=not-direct` を出して exit 1 を返す

#### Scenario: 停止の記録より後の確認は委任として通らない

- **WHEN** `not-found`〜`not-direct` の確かめを通った行の timestamp が停止の記録の作成日時より前でない
- **THEN** `REASON=not-before` を出して exit 1 を返す

#### Scenario: 委任の確認が通る

- **WHEN** 委任の記録の作成日時より後に、親の発言にその URL があり、その直後（あいだに別の主の発言なし）に uuid `u1` の主の発言「任せる」があり、停止の記録の作成日時がその発言より後
- **THEN** `--delegated <ID> u1 <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>` は exit 0 で `MATCH: <timestamp> 任せる` と `MATCHES=1` を出す

### Requirement: --delegated の守備範囲

`--delegated` の入力の出どころは、エピックの親が `reply --as owner` の文の末尾に添えた親のセッション ID・確認の uuid・委任の記録の URL（子の本体と G が写す）、委任の記録と停止の記録のコメントの作成日時（子の本体と G が `gh api` で読む）、同じ PC の親のセッションの会話ログである。親・子・G は協力的だが、写し間違い・別の記録との取り違えをする前提で扱う。`--delegated` は委任の確認が主の入力で、親が委任の記録を示して問うた直後の答えで、停止より前であることだけを確かめなければならない（MUST）。確認の全文から委任の意思を読むこと、委任の記録の書式・投稿者・最新か・編集の有無・エピックが開いているか・子の所属・停止の記録の推奨は、呼び出し側（子の本体と G）が確かめる（MUST）。会話ログの改変・追記の検知と、偽造の経路を塞ぎ切ることは、この要件の完了条件としない（MUST NOT）。

#### Scenario: 許容の語は見ない

- **WHEN** `not-found`〜`not-before` の確かめを通った行の全文が「任せない」
- **THEN** exit 0 で `MATCH:` に全文を出す（意思は呼び出し側が全文で読む）

### Requirement: 主の委任の合否を、名指しの許容と混在したログで機械的に固定する

`plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats` は、1 本のテスト用の親の会話ログ（`OWNER_REPLY_PROJECTS_DIR` で差し替え）に、委任の記録より前の名指しの許容・委任の記録を示した親の問い・主の委任の確認・その後の停止を並べ、`--delegated` と `--relayed` を当てて、次の Scenario を固定しなければならない（MUST）。主の入力・GitHub・端末の部品を使わずに合否が出なければならない（MUST）。

#### Scenario: 停止より前に確認した委任が通る

- **WHEN** 委任の確認の uuid を、確認より後の停止の記録の作成日時で `--delegated` に当てる
- **THEN** exit 0 で `MATCHES=1` になる

#### Scenario: 委任より前に別の子だけを名指しした許容はどちらの経路でも落ちる

- **WHEN** 委任の記録より前の、別の子だけを名指しした主の許容（例 `1034は許容`）の uuid を、`--delegated` と、確認より後の停止の記録での `--relayed` のそれぞれに当てる
- **THEN** どちらも `REASON=not-after` で exit 1 になる

#### Scenario: 停止より後の確認・挟まった発言・別の URL では落ちる

- **WHEN** 委任の確認の uuid を確認より前の停止の記録の作成日時で当てる、親の問いと確認のあいだに別の主の発言を挟んだログで当てる、または親の発言に委任の記録の URL の末尾に数字を続けた別の URL しか無いログで当てる
- **THEN** それぞれ `REASON=not-before`・`REASON=not-direct`・`REASON=not-asked` で exit 1 になる

#### Scenario: 親の問いより前の主の発言は通ることを妨げない

- **WHEN** 委任の記録の作成日時より後で、委任の記録の URL を書いた親の発言より前に別の主の発言があり、その親の発言の直後に主の委任の確認がある
- **THEN** 確認の uuid の `--delegated` は exit 0 で `MATCHES=1` になる
