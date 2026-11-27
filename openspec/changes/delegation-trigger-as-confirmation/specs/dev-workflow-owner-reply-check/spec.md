## MODIFIED Requirements

### Requirement: --delegated の守備範囲

`--delegated` の入力の出どころは、エピックの親が `reply --as owner` の文の末尾に添えた親のセッション ID・確認の uuid・委任の記録の URL（子の本体と G が写す）、委任の記録と停止の記録のコメントの作成日時（子の本体と G が `gh api` で読む）、同じ PC の親のセッションの会話ログである。親・子・G は協力的だが、写し間違い・別の記録との取り違えをする前提で扱う。`--delegated` は委任の確認が主の入力で、親が委任の記録を示して問うたあとの答えで、停止の記録の作成日時を渡されたときは停止より前であることだけを確かめなければならない（MUST）。停止の記録の引数が `-` のときは停止との前後を確かめない（MUST。リスク許容の止まりは委任の確認より前の止まりにも効くため）。確認の全文から委任の意思を読むこと、委任の記録の書式・投稿者・最新か・編集の有無・エピックが開いているか・子の所属・停止の記録の推奨、止まりの種類に合わせて `-` を渡すかどうかは、呼び出し側（子の本体と G）が確かめる（MUST）。会話ログの改変・追記の検知と、親が委任の記録を示したあとに主が別の話で打った任せる旨の発言を確認として拾うこと（G が全文から任せる意思を読んで落とす）と、偽造の経路を塞ぎ切ることは、この要件の完了条件としない（MUST NOT）。

#### Scenario: 許容の語は見ない

- **WHEN** `not-found`〜`not-before` の確かめを通った行の全文が「任せない」
- **THEN** exit 0 で `MATCH:` に全文を出す（意思は呼び出し側が全文で読む）

### Requirement: owner-reply-check.sh --delegated は主の委任の確認を、挟まった主の発言で落とさずに確かめる

`owner-reply-check.sh` は `--delegated <セッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時か ->` の使い方を持たなければならない（MUST）。読む会話ログ・主の発言の 9 条件・exit 2 の条件は既存の使い方と同じとする。確かめる順と落ちたときの理由は次の Scenario のとおりで、すべて通れば `MATCH: <timestamp> <空白をまとめた本文の全文>` と `MATCHES=1` を出して exit 0、落ちたら `REASON=<理由>` と `MATCHES=0` を出して exit 1 で終わる（MUST）。GitHub は読まない（MUST NOT）。既定・`--locate`・`--relayed`・`--delegated-trigger` の動きは変えない（MUST）。

#### Scenario: 引数の不備は確かめられない

- **WHEN** `--delegated` の引数が 5 個でない、セッション ID か uuid が UUID の形でない、委任の記録の作成日時を ISO 8601 の日時として読めない、停止の記録の引数が `-` でも ISO 8601 の日時でもない、または委任の記録の URL が `https://` で始まらない
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

#### Scenario: 問いのあとに別の主の発言が挟まっても並び順では落とさない

- **WHEN** 委任の記録の URL を書いた最後の親の発言と指した uuid の行のあいだに、主の発言の 9 条件を満たす別の行がある
- **THEN** `--delegated` は `REASON=not-direct` を出さず、次の `not-before` の確かめに進む（`--relayed` の `not-direct` は変えない）

#### Scenario: 2026-11-09 の flatmate と同じ形の会話ログを受理する

- **WHEN** 会話ログが、委任の記録の作成日時より後に、親の発言（委任の記録の URL を含む）→ 主の別の発言 → uuid `u1` の主の発言「任せる。今回の件も許容する。」の順に並び、停止の記録の作成日時が `u1` より後
- **THEN** `--delegated <ID> u1 <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>` は exit 0 で `MATCH:` に全文を出し、`MATCHES=1` を出す

#### Scenario: 停止の記録より後の確認は委任として通らない

- **WHEN** 停止の記録の作成日時を渡し、`not-found`〜`not-asked` の確かめを通った行の timestamp が停止の記録の作成日時より前でない
- **THEN** `REASON=not-before` を出して exit 1 を返す

#### Scenario: 停止の記録の引数が - なら停止との前後を見ない

- **WHEN** 停止の記録の引数に `-` を渡し、`not-found`〜`not-asked` の確かめを通った行がある（停止の記録はその行より前に作られている）
- **THEN** `not-before` を確かめず、exit 0 で `MATCH:` に全文を出し、`MATCHES=1` を出す

#### Scenario: 委任の確認が通る

- **WHEN** 委任の記録の作成日時より後に、親の発言にその URL があり、その直後（あいだに別の主の発言なし）に uuid `u1` の主の発言「任せる」があり、停止の記録の作成日時がその発言より後
- **THEN** `--delegated <ID> u1 <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>` は exit 0 で `MATCH: <timestamp> 任せる` と `MATCHES=1` を出す

## ADDED Requirements

### Requirement: owner-reply-check.sh --delegated-trigger は、きっかけの発言を委任の確認として確かめる

`owner-reply-check.sh` は `--delegated-trigger <セッション ID> <uuid> <委任の記録の作成日時> <きっかけの全文>` の使い方を持たなければならない（MUST）。読む会話ログ・主の発言の 9 条件・exit 2 の条件（会話ログなし・python3 なし・指した行の timestamp を読めないなど）は既存の使い方と同じとする。確かめる順と落ちたときの理由は次の Scenario のとおりで、すべて通れば `MATCH: <timestamp> <空白をまとめた本文の全文>` と `MATCHES=1` を出して exit 0、落ちたら `REASON=<理由>` と `MATCHES=0` を出して exit 1 で終わる（MUST）。GitHub は読まない（MUST NOT）。既定・`--locate`・`--relayed`・`--delegated` の動きは変えない（MUST）。

#### Scenario: 引数の不備は確かめられない

- **WHEN** `--delegated-trigger` の引数が 4 個でない、セッション ID か uuid が UUID の形でない、委任の記録の作成日時を ISO 8601 の日時として読めない、またはきっかけの全文が空白をまとめると空
- **THEN** 使い方か理由を stderr に出して exit 2 を返す

#### Scenario: 無い uuid・主の入力でない行では通らない

- **WHEN** 会話ログに指した uuid の行が無い、またはその行が主の発言の 9 条件を満たさない
- **THEN** 前者は `REASON=not-found`、後者は `REASON=not-owner` を出して exit 1 を返す

#### Scenario: 委任の記録より後の発言はきっかけにならない

- **WHEN** 指した uuid の主の発言の timestamp が委任の記録の作成日時より前でない（時刻として比べ、`Z` と `+00:00` の違いは同じに扱う）
- **THEN** `REASON=not-before-record` を出して exit 1 を返す

#### Scenario: きっかけの全文が発言と違えば通らない

- **WHEN** 指した行の本文と渡したきっかけの全文を、それぞれ連続する空白（改行を含む）を 1 個にまとめて前後の空白を落として比べ、同じでない（片方がもう片方の一部であるときも同じでないとする）
- **THEN** `REASON=not-same` を出して exit 1 を返す

#### Scenario: きっかけから記録までに主が次の発言をしていれば通らない

- **WHEN** 指した行の timestamp より後で委任の記録の作成日時より前に、主の発言の 9 条件を満たす別の行がある
- **THEN** `REASON=not-adjacent` を出して exit 1 を返す

#### Scenario: きっかけの発言が確認として通る

- **WHEN** uuid `t1` の主の発言「このエピックでは子の止まりは親が許可を出して続けさせて」のあと、主の別の発言が無いまま委任の記録が作られ、記録の `きっかけ:` の値がその全文（改行の位置だけ違う）
- **THEN** `--delegated-trigger <ID> t1 <委任の記録の作成日時> <きっかけの全文>` は exit 0 で `MATCH:` に全文を出し、`MATCHES=1` を出す

#### Scenario: 許容の語は見ない

- **WHEN** `not-found`〜`not-adjacent` の確かめを通った行の全文が「任せない」
- **THEN** exit 0 で `MATCH:` に全文を出す（意思は呼び出し側が全文で読む）

### Requirement: --delegated-trigger の守備範囲

入力の出どころは、委任の確認の場所の行・`reply --as owner` の添え書きのセッション ID と uuid、委任の記録の作成日時と `きっかけ:` の値（`gh api` で読む）、同じ PC の親の会話ログで、呼び出し側（親・子の本体・G）は写し間違い・取り違えをする前提で扱う。`--delegated-trigger` は、きっかけの発言が主の入力で、記録より前で、記録の全文と同じで、記録までに主の次の発言が無いことだけを確かめる（MUST）。ほかは呼び出し側が確かめる（MUST）。ログの改変の検知と偽造を塞ぎ切ることは完了条件としない（MUST NOT）。

#### Scenario: 親は確認の場所を残す前に呼ぶ

- **WHEN** 親がきっかけの形の記録を投稿した
- **THEN** 親は自分のセッション ID と `--locate` で引いた uuid で `--delegated-trigger` を呼び、子の本体と G は添え書きの値を写して呼ぶ

#### Scenario: 呼び出し側が確かめること

- **WHEN** `--delegated-trigger` が exit 0 を返す
- **THEN** `MATCH:` の全文だけから子の止まりを親に任せる意思が読めること（対象を書かない「任せる」だけの発言や親の問いへの答えを落とすことを含む）、この子・この止まりを除く条件や定型と違う期限を付けていないこと、記録の書式（きっかけの形の定型）・投稿者・最新か・編集の有無・エピックが開いているか・子の所属・止まりの種類と停止の記録の推奨は、呼び出し側（親・子の本体・G）が確かめる

#### Scenario: 停止の記録は見ない

- **WHEN** 停止の記録がきっかけの発言より前に作られている
- **THEN** `--delegated-trigger` は停止との前後を確かめない（停止の記録を引数に取らない）

### Requirement: きっかけの形の委任の合否を、会話ログで機械的に固定する

`plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats` は、テスト用の親の会話ログ（`OWNER_REPLY_PROJECTS_DIR` で差し替え）に、主のきっかけの発言・委任の記録の作成日時・その前後の主の発言を並べ、`--delegated-trigger` と停止の記録の引数 `-` の `--delegated` を当てて、次の Scenario を固定しなければならない（MUST）。主の入力・GitHub・端末の部品を使わずに合否が出なければならない（MUST）。

#### Scenario: きっかけの発言が通る

- **WHEN** きっかけの発言の uuid と、改行の位置だけ違う全文を、そのあと主の発言の無いうちに作られた委任の記録の作成日時で `--delegated-trigger` に当てる
- **THEN** exit 0 で `MATCHES=1` になる

#### Scenario: 記録より後の発言・全文違い・あいだの主の発言で落ちる

- **WHEN** 委任の記録より後の主の発言の uuid を当てる、全文の一部だけを渡す、またはきっかけの発言と記録のあいだに別の主の発言があるログで当てる
- **THEN** それぞれ `REASON=not-before-record`・`REASON=not-same`・`REASON=not-adjacent` で exit 1 になる

#### Scenario: 2026-11-09 の flatmate #2058 の止まりに当たる

- **WHEN** 停止の記録が委任の確認より前に作られたログで、問いの形の確認の uuid を停止の記録の引数 `-` で `--delegated` に当てる
- **THEN** exit 0 で `MATCHES=1` になる。同じ uuid を停止の記録の作成日時で当てると `REASON=not-before` で exit 1 になる
