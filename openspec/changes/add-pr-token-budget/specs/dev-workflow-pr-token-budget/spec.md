## ADDED Requirements

### Requirement: 記録先とサブエージェントの紐付けは description の番号で行う
develop の本体は、その記録先のために Agent ツールでサブエージェントを spawn するとき、役割を問わず（W / R1 / G / G のレビュアー / 決める役はその例で、これに限らない）`description` に記録先番号を `#N` の形で MUST 含める（記録先が issue なら issue 番号。PR 番号も分かっていれば併記してよい）。`pr-token-budget.sh` は、各サブエージェントの `agent-<id>.meta.json` の `description` に、引数で渡された番号のいずれかが `#N` として現れるものを、その記録先のサブエージェントと SHALL みなす。`#` の直後の数字列の直後が数字であるものは一致と MUST NOT みなさない（`#2880` は `#288` に一致しない）。

守備範囲: 想定する入力の出どころは、develop の本体が spawn 時に書く `description` と、Claude Code が書く `agent-<id>.meta.json` / `agent-<id>.jsonl` である。拾いたい誤りは「その記録先のために起こしたサブエージェントの消費が合計から漏れること」と「別リポジトリ・別番号のサブエージェントが混ざること」の 2 つ。通ることを許す入力は、本体が番号を書き忘れた description（そのサブエージェントは数えられず、合計は少なく出る）、本体以外が偶然 `#N` を含む description で起こしたサブエージェント（同じリポジトリの同じ番号なら数えられる）、Workflow 経由の消費（トランスクリプトの置き場が違うので数えない）である。Codex の消費はこの要件ではなく「Codex の消費を記録から合計する」要件で数える。これらの穴が見つかるたびに照合を強くして塞ぎ切ることを完了条件にしない。上限は「人間が気づくまで消費が続く」状態を終えるための歯止めであり、厳密な会計ではない。

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

守備範囲: 想定する入力の出どころは Claude Code が書く `agent-<id>.jsonl`。拾いたい誤りは、1 つの応答が複数行に分かれて書かれることによる二重計上と、壊れた行で集計が止まって合計が出ないこと。通ることを許す入力は、`requestId` と `message.id` の両方が無く `uuid` だけで区別される行（別リクエストとして数える）、`usage` の各キーが欠けている行（0 として数える）、値が 0 や不自然に大きい行（そのまま数える）。穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: 同じ requestId の行を 1 回だけ数える
- **WHEN** トランスクリプトに同じ `requestId` と同じ `usage` を持つ assistant 行が 2 行ある
- **THEN** そのリクエストのトークンは 1 回だけ合計に含まれる

#### Scenario: 再開で追記された分も数える
- **WHEN** 1 体のトランスクリプトに、最初の起動と SendMessage による再開の両方のリクエストがある
- **THEN** 最後のリクエストだけでなく全リクエストの合計が出る

#### Scenario: 壊れた行が混ざる
- **WHEN** トランスクリプトに JSON として壊れた行と `message.usage` が文字列の行がある
- **THEN** 集計は中断せず、その 2 行は合計から外れ、`skipped_lines` が 2 になる

### Requirement: Codex の消費を記録から合計する
`pr-token-budget.sh` は `--codex-records <file>` を受け取ったとき、そのファイルの各行 `<thread_id> <tokens>`（`<tokens>` は 0 以上の整数か `-`）を、その記録先のために使った Codex の thread と SHALL みなし、その消費を `codex_tokens` に合計する。同じ thread_id は、ファイル内に何行あっても 1 回だけ MUST 数える（トークン数が行ごとに違うときは最大値を使う）。`<tokens>` が `-` の thread は、`--codex-home <dir>`（繰り返し指定可。無ければ `${CODEX_HOME:-$HOME/.codex}`）の `sessions/*/*/*/rollout-*-<thread_id>.jsonl` を探し、`type` が `event_msg` で `payload.type` が `token_count` の行の `payload.info.total_token_usage.total_tokens` の最大値を SHALL 使う（`info` が null の行は読み飛ばす）。トークン数が `-` で rollout も見つからない thread は合計に入れず、件数を出力の `codex_unresolved` に MUST 出す。書式に合わない行で集計を中断してはならず MUST NOT、その行数を `skipped_lines` に含める。スクリプトは GitHub を読んではならない（MUST NOT。記録先のコメントを集めてファイルにするのは本体の手順）。

守備範囲: 想定する入力の出どころは、本体が記録先の `Codex 消費:` コメントから作るファイルと、Codex CLI が書く rollout ファイルである。拾いたい誤りは「その記録先のために使った Codex の消費が合計から漏れること」と「同じ thread を複数の記録先に記録したことや、rollout で同じ累計が繰り返し書かれることによる二重計上」の 2 つ。通ることを許す入力は、本体が記録を書き忘れた thread（数えられず合計は少なく出る）、結果 JSON を受け取れずに thread_id が分からない委譲（数えられない）、別の作業で使った thread_id が誤って記録された行（そのまま数える）、トークン数が不自然に大きい行（そのまま数える）、rollout が複数の CODEX_HOME に同じ thread_id で見つかる場合（最大値を使う）である。これらの穴が見つかるたびに照合を強くして塞ぎ切ることを完了条件にしない。

#### Scenario: 記録されたトークン数を合計する
- **WHEN** `--codex-records` のファイルに `t1 1000` と `t2 500` の 2 行がある
- **THEN** `codex_tokens` が 1500、`codex_threads` が 2 になる

#### Scenario: 同じ thread を二重に数えない
- **WHEN** ファイルに `t1 1000` と `t1 1000` の 2 行がある（issue と PR の両方に記録した）
- **THEN** `codex_tokens` は 1000、`codex_threads` は 1

#### Scenario: トークン数が無い thread は rollout から読む
- **WHEN** ファイルに `t3 -` があり、`--codex-home` の `sessions/2026/09/23/rollout-2026-09-23T10-00-00-t3.jsonl` に累計 `total_tokens` が 100・250・250 の `token_count` 行と `info` が null の `token_count` 行がある
- **THEN** t3 の消費は 250 として `codex_tokens` に入る

#### Scenario: 別の CODEX_HOME の rollout も探す
- **WHEN** `--codex-home` を 2 つ渡し、`-` の thread の rollout が 2 つ目にだけある
- **THEN** その rollout の値が `codex_tokens` に入る

#### Scenario: どこにも見つからない thread
- **WHEN** ファイルに `t9 -` があり、どの `--codex-home` にも t9 の rollout が無い
- **THEN** 合計には入らず、`codex_unresolved` が 1 になり、exit code は合計と上限だけで決まる

#### Scenario: 書式に合わない行
- **WHEN** ファイルに `t4 abc` と空白を含まない 1 語だけの行がある
- **THEN** 集計は中断せず、その 2 行は合計から外れ、`skipped_lines` に 2 が加わる

### Requirement: 出力と exit code
`pr-token-budget.sh <番号>... [--cap <tokens>] [--projects <dir>] [--codex-records <file>] [--codex-home <dir>]...` は、stdout に 1 行 JSON を SHALL 出す。キーは少なくとも `records`（渡した番号の配列）・`claude_tokens`・`codex_tokens`・`total_tokens`（`claude_tokens + codex_tokens`）・`agent_count`・`codex_threads`・`cap`・`over_cap`・`unresolved`・`codex_unresolved`・`skipped_lines`・`agents`（各サブエージェントの `name`・`description`・`model`・`tokens`・`requests`）・`codex`（各 thread の `thread_id`・`tokens`・`source`（`record` か `rollout`））とする。上限は Claude 分と Codex 分を分けず、`total_tokens` に 1 本で MUST 掛ける。上限は `--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 を使う。走査対象は `${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}/*/*/subagents/agent-*.meta.json`（`--projects` で差し替え）とする。

exit code は、`total_tokens` が上限以下なら 0、上限を超えたら 2、引数エラー・python3 が無い・カレントディレクトリがリポジトリでないときは 1 と MUST する。紐付くサブエージェントが 0 体のときはエラーにせず、合計 0 で exit 0 と SHALL する。

#### Scenario: 固定のトランスクリプトで期待値と一致する
- **WHEN** bats が用意した固定のトランスクリプト群（紐付く 2 体、別番号 1 体、別リポジトリ 1 体、重複行・壊れた行を含む）と、Codex の記録ファイル（トークン数付き 1 件・`-` で rollout から読む 1 件）・固定の rollout に対して `pr-token-budget.sh 288 --codex-records <file> --codex-home <dir>` を実行する
- **THEN** `claude_tokens`・`codex_tokens`・`total_tokens`・`agent_count`・`codex_threads` が手計算の期待値と一致し、exit 0

#### Scenario: Codex 分を足すと上限を超える
- **WHEN** Claude 分だけでは上限以下で、Codex 分を足すと上限を超える `--cap` を渡す
- **THEN** `over_cap` が true で exit 2

#### Scenario: 上限を超えると exit 2
- **WHEN** 同じ固定入力に対して、合計より小さい値を `--cap` に渡す
- **THEN** `over_cap` が true で exit 2

#### Scenario: まだ誰も起こしていない
- **WHEN** 紐付くサブエージェントが 0 体の番号を渡し、`--codex-records` を渡さない
- **THEN** `total_tokens` が 0、`agent_count` が 0、`codex_threads` が 0 で exit 0

#### Scenario: 環境変数の上限が使われる
- **WHEN** `--cap` を付けず、環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP` に固定入力の合計より小さい値を設定して実行する
- **THEN** 出力の `cap` がその値になり、`over_cap` が true で exit 2

#### Scenario: --cap が環境変数より優先される
- **WHEN** `DEV_WORKFLOW_PR_TOKEN_CAP` に合計より小さい値、`--cap` に合計より大きい値を渡す
- **THEN** 出力の `cap` は `--cap` の値で、exit 0

#### Scenario: 上限の指定が不正
- **WHEN** `--cap` に数字でない値を渡す
- **THEN** exit 1

### Requirement: 本体は spawn と再開の前に測り、上限超なら止まる
develop の本体は、その記録先のためにサブエージェントを spawn する直前、SendMessage で再開する直前、および executor が `codex` の役割へ委譲する直前に、役割と executor を問わず毎回 `scripts/pr-token-budget.sh <記録先番号> [PR 番号] --codex-records <file> --codex-home <dir>...` を MUST 実行する。`<file>` は、渡すすべての記録先番号のコメントのうち 1 行目が `Codex 消費: <thread_id> <tokens>` のものから `<thread_id> <tokens>` を 1 行ずつ書いたもので、本体が計測の直前に作る。`--codex-home` には codex-develop の account と CODEX_HOME の対応表にある全パスと、本体の環境の `${CODEX_HOME:-$HOME/.codex}` を渡す。計測の手順は `skills/develop/SKILL.md`（本体手順）に置き、adapter（`references/codex-develop.md`）と `scripts/codex-worker.py` には置いてはならない（MUST NOT）。

本体は、その記録先のために Codex を呼んだら、そのたびに記録先へ 1 行目が `Codex 消費: <thread_id> <tokens>` のコメントを MUST 投稿する。executor が `codex` の役割へ委譲したときは codex-worker の結果 JSON の `thread_id` と `usage.total.totalTokens` を書く。G が full レビューで Bash から Codex を呼んだときは、G が return に書いた thread_id（`codex exec` の出力ヘッダの `session id:`、companion の結果の `threadId`）を使い、`<tokens>` を `-` と書く。G は Codex を呼んだら thread_id を return に MUST 書く（`skills/develop/references/roles/gate-runner.md` に書く）。結果 JSON を受け取れず thread_id が分からない委譲は記録できず、この上限の外になる。

exit 2 のときは spawn / SendMessage / Codex への委譲をしてはならず MUST NOT、記録先に `needs-approval` を付けて主に「続けるか、範囲外として閉じるか」の 2 択を出して止まる。2 択そのものは PR-A と同じだが、判断材料なしで出してはならず MUST NOT、問いには現在の合計・体数・上限・残工程（次に起こそうとした役割と、そのあと残る工程）・本体の推奨（どちらを選ぶかとその理由）を MUST 含める。unmanned でも同じく止まり、サイクルを終える。この手順は `skills/develop/SKILL.md` に SHALL 書く。

主が「続ける」を選んだら、本体は記録先に 1 行目が `PR トークン上限: <新上限>` のコメントを投稿し、以後その記録先の計測に `--cap <新上限>` を MUST 渡す。新上限は「その時点の合計 ＋ 直前の計測で上限に使った値（`--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 の順で決まった値）」とする。後任の本体は、記録先の最新の `PR トークン上限:` コメントの値を使う。主が「範囲外として閉じる」を選んだら、本体はその記録先について以後サブエージェントを起こさず Codex にも委譲せず、残作業を記録先にコメントしてサイクルを終える。

exit 1 のときは止まらずに進み、計測できなかったことを記録先にコメントする。コメントは同じ記録先・同じ理由について 1 サイクルに 1 回までと SHALL する（spawn のたびに同じコメントを増やさない）。1 サイクルは、interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクルを指す。

#### Scenario: 上限超で次の役割を起こさない
- **WHEN** 本体が G を spawn しようとして `pr-token-budget.sh` が exit 2 を返す
- **THEN** 本体は G を spawn せず、`needs-approval` を付け、合計（Claude 分と Codex 分の内訳を含む）・体数・上限・残工程・推奨を添えて主に「続けるか、範囲外として閉じるか」を出す

#### Scenario: Codex への委譲の前にも測る
- **WHEN** executor が `codex` の W へ次の工程を委譲しようとして、それまでの Codex 委譲の `Codex 消費:` 記録を含めた合計が上限を超えており `pr-token-budget.sh` が exit 2 を返す
- **THEN** 本体は委譲せずに止まり、主に上げる

#### Scenario: Codex に委譲したら消費を記録する
- **WHEN** 本体が executor `codex` の W に委譲し、codex-worker が `thread_id` が `t1`・`usage.total.totalTokens` が 1200000 の結果 JSON を返す
- **THEN** 本体は記録先に 1 行目が `Codex 消費: t1 1200000` のコメントを投稿し、次の計測の `--codex-records` にその行が入る

#### Scenario: SKILL.md に手順が書かれている
- **WHEN** `skills/develop/SKILL.md` を読む
- **THEN** 「`pr-token-budget.sh` が exit 2 なら spawn / SendMessage / Codex への委譲をせず主に上げる」手順、description に記録先番号 `#N` を入れる規約、Codex を呼んだら `Codex 消費:` コメントを投稿する手順、計測の前に `Codex 消費:` コメントを集めて `--codex-records` で渡す手順が書かれている

#### Scenario: 続けたあとの計測は引き上げた上限を使う
- **WHEN** 上限 30000000 で止まり、その時点の合計が 30500000 で、主が「続ける」を選ぶ
- **THEN** 本体は記録先に `PR トークン上限: 60500000` をコメントし、次の spawn の前の計測に `--cap 60500000` を付ける

#### Scenario: 計測できないコメントを重ねない
- **WHEN** 同じサイクルで 2 回続けて `pr-token-budget.sh` が同じ理由で exit 1 を返す
- **THEN** 本体が記録先に投稿する「計測できなかった」コメントは 1 件だけ
