## ADDED Requirements

### Requirement: 記録先とサブエージェントの紐付けは description の番号で行う
develop の本体は、W / R1 / G / G のレビュアー / 決める役を Agent ツールで spawn するとき、`description` に記録先番号を `#N` の形で MUST 含める（記録先が issue なら issue 番号。PR 番号も分かっていれば併記してよい）。`pr-token-budget.sh` は、各サブエージェントの `agent-<id>.meta.json` の `description` に、引数で渡された番号のいずれかが `#N` として現れるものを、その記録先のサブエージェントと SHALL みなす。`#` の直後の数字列の直後が数字であるものは一致と MUST NOT みなさない（`#2880` は `#288` に一致しない）。

守備範囲: 想定する入力の出どころは、develop の本体が spawn 時に書く `description` と、Claude Code が書く `agent-<id>.meta.json` / `agent-<id>.jsonl` である。拾いたい誤りは「その記録先のために起こしたサブエージェントの消費が合計から漏れること」と「別リポジトリ・別番号のサブエージェントが混ざること」の 2 つ。通ることを許す入力は、本体が番号を書き忘れた description（そのサブエージェントは数えられず、合計は少なく出る）、本体以外が偶然 `#N` を含む description で起こしたサブエージェント（同じリポジトリの同じ番号なら数えられる）、Codex CLI・Workflow 経由の消費（トランスクリプトの置き場が違うので数えない）である。これらの穴が見つかるたびに照合を強くして塞ぎ切ることを完了条件にしない。上限は「人間が気づくまで消費が続く」状態を終えるための歯止めであり、厳密な会計ではない。

#### Scenario: 名前なしで起こした役割も数える
- **WHEN** meta.json に `name` が無く `description` が `R1: spec review for #288` のサブエージェントがある
- **THEN** `pr-token-budget.sh 288` の合計にそのサブエージェントのトークンが含まれる

#### Scenario: worktree 隔離で起こした役割も数える
- **WHEN** meta.json が `spawnedWithWorktree: true` でファイル名にエージェント名が入っていないサブエージェントの `description` が `W: spec phase for #288` である
- **THEN** `pr-token-budget.sh 288` の合計にそのサブエージェントのトークンが含まれる

#### Scenario: 桁の多い番号に誤って一致しない
- **WHEN** `description` が `W: impl for #2880` のサブエージェントだけがある
- **THEN** `pr-token-budget.sh 288` の体数は 0 で、合計は 0

#### Scenario: 複数の番号を渡したとき同じサブエージェントを二重に数えない
- **WHEN** `description` が `G: gate for PR #400 (#288)` のサブエージェントがあり、`pr-token-budget.sh 288 400` を実行する
- **THEN** そのサブエージェントは体数で 1、トークンも 1 回分だけ合計に含まれる

### Requirement: リポジトリで絞り込む
`pr-token-budget.sh` は、実行時のカレントディレクトリのリポジトリ識別子（`git rev-parse --path-format=absolute --git-common-dir`）と、各サブエージェントの作業ディレクトリ（meta の `worktreePath`、無ければトランスクリプトで最初に現れる `cwd`）のリポジトリ識別子が一致するものだけを SHALL 数える。worktree の作業ディレクトリは親リポジトリの識別子に畳 MUST む。作業ディレクトリから識別子が求まらないサブエージェントは数えず、その体数を出力の `unresolved` に MUST 出す。

#### Scenario: 別リポジトリの同じ番号を数えない
- **WHEN** 別リポジトリを作業ディレクトリとする `description` が `W: impl for #288` のサブエージェントがある
- **THEN** 実行したリポジトリの `pr-token-budget.sh 288` の合計に含まれない

#### Scenario: 同じリポジトリの別 worktree で動いたサブエージェントを数える
- **WHEN** 実行したリポジトリの別 worktree を作業ディレクトリとするサブエージェントの `description` が `#288` を含む
- **THEN** 合計に含まれる

#### Scenario: 作業ディレクトリが消えている
- **WHEN** 一致する description のサブエージェントの作業ディレクトリが既に存在しない
- **THEN** 合計には含まれず、出力の `unresolved` が 1 増える

### Requirement: 全リクエストの usage を重複なく合計する
`pr-token-budget.sh` は、紐付いた各サブエージェントのトランスクリプトの全 assistant レコードについて、`input_tokens + cache_creation_input_tokens + cache_read_input_tokens + output_tokens` を SHALL 合計する。同じリクエストが複数行に分かれて書かれるため、`requestId`（無ければ `message.id`、それも無ければ行の `uuid`）で重複を MUST 排除する。有効な JSON でない行・辞書でない行・`message.usage` が辞書でない行で集計を中断してはならず MUST NOT、読み飛ばした行数を出力の `skipped_lines` に MUST 出す。

#### Scenario: 同じ requestId の行を 1 回だけ数える
- **WHEN** トランスクリプトに同じ `requestId` と同じ `usage` を持つ assistant 行が 2 行ある
- **THEN** そのリクエストのトークンは 1 回だけ合計に含まれる

#### Scenario: 再開で追記された分も数える
- **WHEN** 1 体のトランスクリプトに、最初の起動と SendMessage による再開の両方のリクエストがある
- **THEN** 最後のリクエストだけでなく全リクエストの合計が出る

#### Scenario: 壊れた行が混ざる
- **WHEN** トランスクリプトに JSON として壊れた行と `message.usage` が文字列の行がある
- **THEN** 集計は中断せず、その 2 行は合計から外れ、`skipped_lines` が 2 になる

### Requirement: 出力と exit code
`pr-token-budget.sh <番号>... [--cap <tokens>] [--projects <dir>]` は、stdout に 1 行 JSON を SHALL 出す。キーは少なくとも `records`（渡した番号の配列）・`total_tokens`・`agent_count`・`cap`・`over_cap`・`unresolved`・`skipped_lines`・`agents`（各サブエージェントの `name`・`description`・`model`・`tokens`・`requests`）とする。上限は `--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 を使う。走査対象は `${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}/*/*/subagents/agent-*.meta.json`（`--projects` で差し替え）とする。

exit code は、`total_tokens` が上限以下なら 0、上限を超えたら 2、引数エラー・python3 が無い・カレントディレクトリがリポジトリでないときは 1 と MUST する。紐付くサブエージェントが 0 体のときはエラーにせず、合計 0 で exit 0 と SHALL する。

#### Scenario: 固定のトランスクリプトで期待値と一致する
- **WHEN** bats が用意した固定のトランスクリプト群（紐付く 2 体、別番号 1 体、別リポジトリ 1 体、重複行・壊れた行を含む）に対して `pr-token-budget.sh 288` を実行する
- **THEN** `total_tokens` と `agent_count` が手計算の期待値と一致し、exit 0

#### Scenario: 上限を超えると exit 2
- **WHEN** 同じ固定入力に対して、合計より小さい値を `--cap` に渡す
- **THEN** `over_cap` が true で exit 2

#### Scenario: まだ誰も起こしていない
- **WHEN** 紐付くサブエージェントが 0 体の番号を渡す
- **THEN** `total_tokens` が 0、`agent_count` が 0 で exit 0

#### Scenario: 上限の指定が不正
- **WHEN** `--cap` に数字でない値を渡す
- **THEN** exit 1

### Requirement: 本体は spawn と再開の前に測り、上限超なら止まる
develop の本体は、W / R1 / G / G のレビュアー / 決める役のいずれかを spawn する直前、および SendMessage で再開する直前に、毎回 `scripts/pr-token-budget.sh <記録先番号> [PR 番号]` を MUST 実行する。exit 2 のときは spawn / SendMessage をしてはならず MUST NOT、記録先に `needs-approval` を付け、現在の合計・体数・上限を添えて主に「続けるか、範囲外として閉じるか」の 1 択を出して止まる（PR-A の問いと同じ形）。unmanned でも同じく止まり、サイクルを終える。この手順は `skills/develop/SKILL.md` に SHALL 書く。

主が「続ける」を選んだら、本体は記録先に 1 行目が `PR トークン上限: <新上限>`（新上限はその時点の合計＋既定の上限）のコメントを投稿し、以後その記録先の計測に `--cap <新上限>` を MUST 渡す。後任の本体は、記録先の最新の `PR トークン上限:` コメントの値を使う。主が「範囲外として閉じる」を選んだら、本体はその記録先について以後サブエージェントを起こさず、残作業を記録先にコメントしてサイクルを終える。

exit 1 のときは止まらずに進み、計測できなかったことを記録先にコメントする。

#### Scenario: 上限超で次の役割を起こさない
- **WHEN** 本体が G を spawn しようとして `pr-token-budget.sh` が exit 2 を返す
- **THEN** 本体は G を spawn せず、`needs-approval` を付けて主に「続けるか、範囲外として閉じるか」を出す

#### Scenario: SKILL.md に手順が書かれている
- **WHEN** `skills/develop/SKILL.md` を読む
- **THEN** 「`pr-token-budget.sh` が exit 2 なら spawn / SendMessage せず主に上げる」手順と、description に記録先番号 `#N` を入れる規約が書かれている

#### Scenario: 続けたあとの計測は引き上げた上限を使う
- **WHEN** 主が「続ける」を選び、本体が記録先に `PR トークン上限: 60000000` をコメントしたあとで次の spawn をする
- **THEN** 本体は `--cap 60000000` を付けて計測する
