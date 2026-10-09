# dev-workflow-owner-reply-check Specification

## Purpose
主が会話で返したリスク許容の発言が、そのセッションの会話ログに主の発言として実在するかを確かめるスクリプト `owner-reply-check.sh` の振る舞いを定める。pr-review-gate 手順 5 の「会話で受領」の真正性確認が、この終了コードと出力を使う。develop の本体も、会話で受けたリスク許容を G に渡す前に先に回し、出力の `MATCH:` 行の timestamp を G に渡す日時として使う。
## Requirements
### Requirement: owner-reply-check.sh は会話ログに主の発言が実在するかを終了コードで返す

`plugins/dev-workflow/scripts/owner-reply-check.sh` は `<セッション ID> <原文>` の 2 引数を受け取り、`${OWNER_REPLY_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/<セッション ID>.jsonl` に当たる会話ログだけを読まなければならない（SHALL）。`<セッション ID>/subagents/` の下の会話ログは読んではならない（MUST NOT）。原文と各発言の本文は、連続する空白（改行を含む）を 1 個の空白にまとめ前後の空白を落としてから部分一致で比べなければならない（SHALL）。主の発言のうち原文を含むものが 1 件以上あれば、一致した発言ごとに `MATCH: <その行の timestamp> <空白をまとめた本文の全文>` を出し、最後に `MATCHES=<件数>` を出して exit 0 で終わらなければならない（SHALL）。1 件も無ければ `MATCHES=0` を出して exit 1 で終わらなければならない（SHALL）。引数の数が 2 でない、セッション ID が UUID の形でない、原文が空白を除いて空（空白のまとめ方で空になる原文を含む。U+0085 だけの原文など）、会話ログが 1 つも見つからない、見つけた会話ログを読めない（権限が無い・探索のあとで消えたなど）、`python3` が無い、のどれかなら exit 2 で終わらなければならない（SHALL）。exit 2 は「確かめられない」であり、呼び出し側は exit 1 と同じく通さない側に倒す。

守備範囲: ①入力の出どころは、pr-review-gate の G が宣言コメントの `会話で受領` の記録から写したセッション ID と原文、およびゲートが動いている PC の `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects` の下にある Claude Code の会話ログである。G は協力的だが、記録の写し間違い・別セッションの ID の取り違え・原文の切り詰めをする前提で扱う ②拾いたい誤りは、記録したセッションの会話ログに原文を含む主の発言が無いこと、記録したセッションの会話ログをこの PC で読めないのに通すこと、引数の不備を「一致なし」と区別せずに扱うこと ③通ることを許す入力は、改行や字下げだけが違う原文、発言の一部だけを写した原文（「許容しない」の一部の「許容」も一致として返す。許容の意思は呼び出し側が全文で読む）、同じ原文を含む発言が複数あるセッション（すべて `MATCH:` で返す）、Orca の親セッションが子のターミナルに打ち込んだ許容の文は `origin.kind: "human"` で残るので主の発言として通りうる（一致した発言の全文を読んでも主が打った文と区別できない限界であり、親が許容を打ち込まないことは保証されていない）。ローカルの会話ログ（`.jsonl`）の改変・追記は検知しない ④ここに挙げた以外の偽造の経路を見つけるたびに検査を足し、穴を塞ぎ切ることをこの要件の完了条件にしない（MUST NOT）。

守備範囲①の補足（呼び出し元）: 入力を作ってこのスクリプトを回すのは pr-review-gate の G だけではない。develop の本体も、会話で受けたリスク許容を G に渡す前に、自分のセッション ID（`$CLAUDE_CODE_SESSION_ID`）と会話で受けた発言から写した原文で先に回し、`MATCH:` 行の timestamp を G に渡す日時として使う。真正性確認そのものは、渡された記録で G が回して行う（pr-review-gate 手順 5 の「会話で受領」）。本体が作る入力も、G が作る入力と同じ前提（協力的だが、記録の写し間違い・別セッションの ID の取り違え・原文の切り詰めをする）で、この守備範囲に入る。スクリプトの振る舞いは呼び出し元で変わらず、この段落は本体に手順を課さない（本体の手順の正本は develop の SKILL.md）。

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

owner-reply-check.sh は、会話ログの行のうち次のすべてを満たすものだけを主の発言として数えなければならない（SHALL）: ①`type` が `"user"` ②`isSidechain` が true でない ③`isMeta` が true でない ④`origin` のキーがあるなら（値が null でも）`origin.kind` が `"human"` ⑤`message.content` が文字列、または `type: "text"` の要素だけからなる配列（`tool_result` を含む配列は数えない） ⑥本文が `Another Claude session sent a message` で始まらず、`<teammate-message` を含まない ⑦本文が `<bash-stdout>`・`<bash-stderr>`・`<local-command-stdout>`・`<local-command-stderr>` で始まらない ⑧`isCompactSummary` が true でない（会話の圧縮後にモデルが書いた要約の行。`type` は `"user"` で `isMeta` も `origin` も無い）。`<command-args>` を含む行（スラッシュコマンドの引数）と `<bash-input>` を含む行（主が `!` で打ったシェルの入力）は、タグを外さずに本文として比べなければならない（SHALL）。各入力は `plugins/dev-workflow/tests/owner-reply-check.bats` で 1 件ずつ固定しなければならない（MUST）。

守備範囲: ①入力の出どころは、Claude Code が書いた会話ログの 1 行 1 イベントの JSON で、形式は 2026-10-07 時点の実物（`origin` の付く行と付かない行が混在する）に合わせる ②拾いたい誤りは、アシスタントの発言・サブエージェントの会話・ツールの結果・他のセッションやチームメイトからの転送・`isMeta` の差し込み・`!` のシェルやローカルコマンドの出力・会話の圧縮後の要約を主の発言として数えること ③通ることを許す入力は、`origin` の無い古い形式の主の発言、`<bash-input>` の行（主が `!` で打った入力）、`<command-args>` の行（スラッシュコマンドの引数）、`type: "text"` の要素だけからなる配列の本文、Orca の親セッションが子のターミナルに打ち込んだ許容の文は `origin.kind: "human"` で残るので主の発言として通りうる（一致した発言の全文を読んでも主が打った文と区別できない限界であり、親が許容を打ち込まないことは保証されていない）。ローカルの会話ログ（`.jsonl`）の改変・追記は検知しない。Claude Code が今後足す未知の差し込みの形は、8 条件のどれにも当たらなければ主の発言として通りうる。`isVisibleInTranscriptOnly: true` でも `isCompactSummary` が true でない行は主の発言として通りうる（要約以外にこの属性が付くかを確かめていないため、除く材料にしていない） ④会話ログの形式が変わるたびに条件を足し続けて網羅することを、この要件の完了条件にしない（MUST NOT）。形式の変化に気づいたら bats の入力を実物から取り直す。

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

