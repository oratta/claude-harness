## REMOVED Requirements

### Requirement: owner-reply-check.sh --delegated は主の委任の確認を親の会話ログの場所で確かめる

**Reason**: 親の問いと確認のあいだに主の別の発言が挟まると `not-direct` で落とすため、2026-11-09 の flatmate #2058 で主が一括で任せたあとの許容がはじかれた（issue #1653）。
**Migration**: 要件「owner-reply-check.sh --delegated は主の委任の確認を、挟まった主の発言で落とさずに確かめる」に置き換える。`not-direct` の判定を外す以外は同じ。

### Requirement: 主の委任の合否を、名指しの許容と混在したログで機械的に固定する

**Reason**: 挟まった主の発言で `not-direct` になることを固定していたが、その判定を外す（issue #1653）。
**Migration**: 要件「主の委任の合否を、名指しの許容と挟まった発言の混在したログで機械的に固定する」に置き換える。

## ADDED Requirements

### Requirement: owner-reply-check.sh --delegated は主の委任の確認を、挟まった主の発言で落とさずに確かめる

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

#### Scenario: 問いのあとに別の主の発言が挟まっても並び順では落とさない

- **WHEN** 委任の記録の URL を書いた最後の親の発言と指した uuid の行のあいだに、主の発言の 9 条件を満たす別の行がある
- **THEN** `--delegated` は `REASON=not-direct` を出さず、次の `not-before` の確かめに進む（`--relayed` の `not-direct` は変えない）

#### Scenario: 2026-11-09 の flatmate と同じ形の会話ログを受理する

- **WHEN** 会話ログが、委任の記録の作成日時より後に、親の発言（委任の記録の URL を含む）→ 主の別の発言 → uuid `u1` の主の発言「任せる。今回の件も許容する。」の順に並び、停止の記録の作成日時が `u1` より後
- **THEN** `--delegated <ID> u1 <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>` は exit 0 で `MATCH:` に全文を出し、`MATCHES=1` を出す

#### Scenario: 停止の記録より後の確認は委任として通らない

- **WHEN** `not-found`〜`not-asked` の確かめを通った行の timestamp が停止の記録の作成日時より前でない
- **THEN** `REASON=not-before` を出して exit 1 を返す

#### Scenario: 委任の確認が通る

- **WHEN** 委任の記録の作成日時より後に、親の発言にその URL があり、その直後（あいだに別の主の発言なし）に uuid `u1` の主の発言「任せる」があり、停止の記録の作成日時がその発言より後
- **THEN** `--delegated <ID> u1 <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>` は exit 0 で `MATCH: <timestamp> 任せる` と `MATCHES=1` を出す

### Requirement: 主の委任の合否を、名指しの許容と挟まった発言の混在したログで機械的に固定する

`plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats` は、1 本のテスト用の親の会話ログ（`OWNER_REPLY_PROJECTS_DIR` で差し替え）に、委任の記録より前の名指しの許容・委任の記録を示した親の問い・主の委任の確認・その後の停止を並べ、`--delegated` と `--relayed` を当てて、次の Scenario を固定しなければならない（MUST）。主の入力・GitHub・端末の部品を使わずに合否が出なければならない（MUST）。

#### Scenario: 停止より前に確認した委任が通る

- **WHEN** 委任の確認の uuid を、確認より後の停止の記録の作成日時で `--delegated` に当てる
- **THEN** exit 0 で `MATCHES=1` になる

#### Scenario: 委任より前に別の子だけを名指しした許容はどちらの経路でも落ちる

- **WHEN** 委任の記録より前の、別の子だけを名指しした主の許容（例 `1034は許容`）の uuid を、`--delegated` と、確認より後の停止の記録での `--relayed` のそれぞれに当てる
- **THEN** どちらも `REASON=not-after` で exit 1 になる

#### Scenario: 停止より後の確認・別の URL では落ちる

- **WHEN** 委任の確認の uuid を確認より前の停止の記録の作成日時で当てる、または親の発言に委任の記録の URL の末尾に数字を続けた別の URL しか無いログで当てる
- **THEN** それぞれ `REASON=not-before`・`REASON=not-asked` で exit 1 になる

#### Scenario: 親の問いと確認のあいだに別の主の発言が挟まっても通る

- **WHEN** 親の問いと確認のあいだに別の主の発言を挟んだログ（2026-11-09 の flatmate #2058 と同じ並び）で、確認の uuid を確認より後の停止の記録の作成日時で `--delegated` に当てる
- **THEN** exit 0 で `MATCHES=1` になる。同じログで、挟まった発言の uuid を確認の uuid として渡した場合も `--delegated` は並び順では落とさない（意思は呼び出し側が全文で読む）

#### Scenario: 親の問いより前の主の発言は通ることを妨げない

- **WHEN** 委任の記録の作成日時より後で、委任の記録の URL を書いた親の発言より前に別の主の発言があり、その親の発言の直後に主の委任の確認がある
- **THEN** 確認の uuid の `--delegated` は exit 0 で `MATCHES=1` になる

## MODIFIED Requirements

### Requirement: --delegated の守備範囲

`--delegated` の入力の出どころは、エピックの親が `reply --as owner` の文の末尾に添えた親のセッション ID・確認の uuid・委任の記録の URL（子の本体と G が写す）、委任の記録と停止の記録のコメントの作成日時（子の本体と G が `gh api` で読む）、同じ PC の親のセッションの会話ログである。親・子・G は協力的だが、写し間違い・別の記録との取り違えをする前提で扱う。`--delegated` は委任の確認が主の入力で、親が委任の記録を示して問うたあとの答えで、停止より前であることだけを確かめなければならない（MUST）。確認の全文から委任の意思を読むこと、委任の記録の書式・投稿者・最新か・編集の有無・エピックが開いているか・子の所属・停止の記録の推奨は、呼び出し側（子の本体と G）が確かめる（MUST）。会話ログの改変・追記の検知と、親が委任の記録を示したあとに主が別の話で打った任せる旨の発言を確認として拾うこと（G が全文から任せる意思を読んで落とす）と、偽造の経路を塞ぎ切ることは、この要件の完了条件としない（MUST NOT）。

#### Scenario: 許容の語は見ない

- **WHEN** `not-found`〜`not-before` の確かめを通った行の全文が「任せない」
- **THEN** exit 0 で `MATCH:` に全文を出す（意思は呼び出し側が全文で読む）
