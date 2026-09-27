## ADDED Requirements

### Requirement: SKILL.md は索引で、手順の本文を持たない

`plugins/dev-workflow/skills/pr-review-gate/SKILL.md` は索引でなければならない（MUST）。索引が持ってよいのは、frontmatter、スキルの目的と通過の必須 4 点・fail-closed・サブエージェントへの委譲の要約、段の表（段ごとに 1 行で、目的・読むファイル・入口の条件・出口の条件）、宣言の書式ファイルの案内、手順番号から段のファイルへの対応表、develop 以外で本体がこのスキルを直接使うときの読み方だけとする（MUST）。索引は手順の本文とコードブロックを持ってはならない（MUST NOT）。SKILL.md は 10,000 バイト以下でなければならない（MUST）。frontmatter の `description` は変えてはならない（MUST NOT。`tests/injection-budget.bats` の対象のため）。

#### Scenario: 索引の大きさ

- **WHEN** `wc -c plugins/dev-workflow/skills/pr-review-gate/SKILL.md` を実行する
- **THEN** 10000 以下である

#### Scenario: 索引に手順の本文が無い

- **WHEN** SKILL.md を読む
- **THEN** コードブロック（```）が 1 つも無く、段の表の各行はちょうど 1 つの段のファイルを指し、そのファイルが実在する

#### Scenario: description が変わらない

- **WHEN** 変更前後の SKILL.md の frontmatter の `description` を比べる
- **THEN** 一致する

### Requirement: 手順の本文は段ごとのファイルと宣言の書式ファイルに置く

手順の本文は `plugins/dev-workflow/skills/pr-review-gate/stages/` の次の 6 つの段のファイルと、宣言の書式ファイル `plugins/dev-workflow/skills/pr-review-gate/declarations.md` に置かなければならない（MUST）。手順番号（1・2-0・2-1・2-2・3・3-b・3-c・4・5・6）は変えてはならない（MUST NOT）。

| 段 | ファイル | 持つ手順 |
|---|---|---|
| 前提確認と重さ判定 | `stages/prepare.md` | 手順 1・手順 2 の冒頭・2-0 |
| レビューの起動 | `stages/review-run.md` | 2-1 のうちレビュー実行者の優先順・Codex 呼び出し規約・Task サブエージェントのモデル・各 PC の確認 |
| レビュー担当向けの指示 | `stages/reviewer-brief.md` | 2-1 のレビュアー向け指示ブロック・共通一覧契約・Codex の読み替え表 |
| 照合と指摘の振り分け | `stages/triage.md` | 2-1 のうちマージを止めるかの判定・仕分け表・収束ルール・2 周目の終わり・決める役・2-2 |
| 合格処理 | `stages/pass.md` | 手順 4・5 |
| 保留 | `stages/hold.md` | 3-c・手順 6・主に承認を求めてよい 4 分類 |

`declarations.md` は手順 3（リスク宣言）と 3-b（仕様宣言）を持つ（MUST）。旧 SKILL.md 冒頭の「前提と理由」の各項目は、それを使う段のファイル（HEAD SHA と仕様宣言は `declarations.md`、stale passed は `stages/prepare.md`、auto-merge の配備状況は `stages/pass.md`、リポ固有の仕組みは `stages/hold.md`）に移さなければならない（MUST）。移すときに規則・閾値・雛形・コマンドの中身を変えてはならない（MUST NOT）。

#### Scenario: 手順番号の対応表

- **WHEN** 索引の手順番号の対応表を読む
- **THEN** 1・2-0・2-1・2-2・3・3-b・3-c・4・5・6 のすべてに行があり（2-1 は段ごとに分けた 3 行）、各行が指すファイルにその手順の見出しがある

#### Scenario: 段のファイルが揃っている

- **WHEN** `ls plugins/dev-workflow/skills/pr-review-gate/stages/` を実行する
- **THEN** `prepare.md`・`review-run.md`・`reviewer-brief.md`・`triage.md`・`pass.md`・`hold.md` がある

### Requirement: 同じ手順を 2 か所に書かない

各手順の見出しは pr-review-gate 配下の 1 ファイルにだけ置かなければならない（MUST）。別の段のファイルがその手順や前提に触れるときは、ファイル名と節名で参照し、中身を言い換えて再掲してはならない（MUST NOT）。各段のファイルは、冒頭に入口の条件を、末尾に出口（次に読むファイル）を書かなければならない（MUST）。

#### Scenario: 見出しの重複が無い

- **WHEN** pr-review-gate 配下の `.md` から手順の見出し（`### 1.`・`#### 2-0.` など）を集める
- **THEN** 各見出しはちょうど 1 ファイルにだけ現れる

### Requirement: 既存要件の「SKILL.md の手順」は段のファイルを指す

`dev-workflow-pr-review-gate`・`dev-workflow-develop`・`dev-workflow-subagent-waiting` の既存要件が「SKILL.md の手順 N」「SKILL.md 手順 2-1 のレビュアー向け指示ブロック」「SKILL.md の〜を読む」「SKILL.md に再掲しない」と書いている箇所は、索引の対応表がその手順を割り当てた段のファイル（宣言は `declarations.md`）を指すものとして読まなければならない（MUST）。「SKILL.md に再掲しない」の類の禁止は、索引・段のファイル・`declarations.md` のすべてに掛かる（MUST）。

#### Scenario: 待ち値の再掲禁止が段のファイルにも掛かる

- **WHEN** `stages/review-run.md` の Codex 呼び出し規約を読む
- **THEN** 具体の待ち値・繰り返し回数・総待ちの上限は書かれておらず、正本 `plugins/dev-workflow/references/subagent-waiting.md` を参照している

### Requirement: develop 以外で本体がスキルを直接使うときは索引から段ごとに読む

develop を通さずに PR を作った本体がこのスキルを読み込んだときは、索引を読んだうえで、段の表の入口の条件に当たる段のファイルを 1 つずつ読んで進まなければならない（MUST）。索引は、この読み方と、最初に読む段（`stages/prepare.md`）を書かなければならない（MUST）。保留中の PR の再開では、索引の表から保留の段（`stages/hold.md`）に入る（MUST）。

#### Scenario: 本体の読み方

- **WHEN** 索引の「develop 以外で本体が直接使うとき」の節を読む
- **THEN** 最初に `stages/prepare.md` を読むこと、各段の出口に書かれた次のファイルへ進むこと、保留の再開は `stages/hold.md` から入ることが書かれている
