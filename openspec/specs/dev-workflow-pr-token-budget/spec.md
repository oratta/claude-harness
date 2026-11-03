# dev-workflow-pr-token-budget Specification

## Purpose
TBD - created by archiving change add-pr-token-budget. Update Purpose after archive.

## Requirements

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
`pr-token-budget.sh` は `--codex-records <file>` を受け取ったとき、そのファイルの各行 `<thread_id> <tokens>`（`<tokens>` は 0 以上の整数か `-`）を、その記録先のために使った Codex の thread と SHALL みなし、その消費を `codex_tokens` に合計する。同じ thread_id は、ファイル内に何行あっても 1 回だけ MUST 数える（トークン数が行ごとに違うときは最大値を使う）。`<tokens>` が `-` の thread は、`--codex-home <dir>`（繰り返し指定可。無ければ `${CODEX_HOME:-$HOME/.codex}`）の `sessions/*/*/*/rollout-*-<thread_id>.jsonl` を探し、`type` が `event_msg` で `payload.type` が `token_count` の行の `payload.info.total_token_usage.total_tokens` の最大値を SHALL 使う（`info` が null の行は読み飛ばす）。トークン数が `-` で rollout も見つからない thread は合計に入れず、件数を出力の `codex_unresolved` に MUST 出す。書式に合わない行で集計を中断してはならず MUST NOT、その行数を `skipped_lines` に含める。ファイルが空（または空行だけ）のときはエラーにせず、`codex_threads` を 0 として SHALL 扱う。スクリプトは GitHub を読んではならない（MUST NOT。記録先のコメントを集めてファイルにするのは本体の手順）。

守備範囲: 想定する入力の出どころは、本体が記録先の `Codex 消費:` コメントから作るファイルと、Codex CLI が書く rollout ファイルである。拾いたい誤りは「その記録先のために使った Codex の消費が合計から漏れること」と「同じ thread を複数の記録先に記録したことや、rollout で同じ累計が繰り返し書かれることによる二重計上」の 2 つ。通ることを許す入力は、本体が記録を書き忘れた thread（数えられず合計は少なく出る）、結果 JSON を受け取れずに thread_id が分からない委譲と、G が thread_id を取れなかった Codex の呼び出し（どちらも数えられない）、別の作業で使った thread_id が誤って記録された行（そのまま数える）、トークン数が不自然に大きい行（そのまま数える）、rollout が複数の CODEX_HOME に同じ thread_id で見つかる場合（最大値を使う）である。これらの穴が見つかるたびに照合を強くして塞ぎ切ることを完了条件にしない。

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

#### Scenario: 記録ファイルが空
- **WHEN** `--codex-records` に空のファイルを渡す
- **THEN** `codex_threads` が 0、`codex_tokens` が 0 で、exit code は Claude 分の合計と上限だけで決まる

#### Scenario: 書式に合わない行
- **WHEN** ファイルに `t4 abc` と空白を含まない 1 語だけの行がある
- **THEN** 集計は中断せず、その 2 行は合計から外れ、`skipped_lines` に 2 が加わる

### Requirement: 出力と exit code
`pr-token-budget.sh <番号>... [--cap <tokens>] [--projects <dir>] [--codex-records <file>] [--codex-home <dir>]...` は、stdout に 1 行 JSON を SHALL 出す。キーは少なくとも `records`（渡した番号の配列）・`claude_tokens`・`codex_tokens`・`total_tokens`（`claude_tokens + codex_tokens`）・`agent_count`・`codex_threads`・`cap`・`over_cap`・`unresolved`・`codex_unresolved`・`skipped_lines`・`agents`（各サブエージェントの `name`・`description`・`model`・`tokens`・`requests`）・`codex`（各 thread の `thread_id`・`tokens`・`source`（`record` か `rollout`））とする。上限は Claude 分と Codex 分を分けず、`total_tokens` に 1 本で MUST 掛ける。上限は `--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 を使う。走査対象は `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/*/subagents/agent-*.meta.json`（`--projects` で差し替え）とする。

exit code は、`total_tokens` が上限以下なら 0、上限を超えたら 2、引数エラー・python3 が無い・カレントディレクトリがリポジトリでないときは 1 と MUST する。紐付くサブエージェントが 0 体のときはエラーにせず、合計 0 で exit 0 と SHALL する。

守備範囲: 想定する入力の出どころは、`--projects`、環境変数 `CLAUDE_PROJECTS_DIR` / `CLAUDE_CONFIG_DIR` / `HOME` で決まる 1 か所の projects ディレクトリと、`--cap` / `DEV_WORKFLOW_PR_TOKEN_CAP` の上限の値である。拾いたい誤りは、Claude Code が会話記録を書いた設定フォルダと違う場所を探して Claude 分を 0 と数え、上限の判定が効かないことである。通ることを許す入力は、1 つの記録先を別々の `CLAUDE_CONFIG_DIR` のセッションで進めたときの別の設定フォルダ側の消費（数えず、合計は少なく出る）と、会話記録の無い場所を指す `CLAUDE_CONFIG_DIR`（紐付く 0 体として合計 0・exit 0）である。これらの穴が見つかるたびに探索先を増やして塞ぎ切ることを完了条件にしない。

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

#### Scenario: CLAUDE_CONFIG_DIR の下の消費を数える
- **GIVEN** `CLAUDE_PROJECTS_DIR` が未設定で、`CLAUDE_CONFIG_DIR` が指す一時ディレクトリの `projects/*/*/subagents/` に記録先 `288` のサブエージェントの会話記録があり、`HOME` の下には無い
- **WHEN** `pr-token-budget.sh 288` を `--projects` なしで実行する
- **THEN** `claude_tokens` はその会話記録の usage の合計（0 でない値）になる

#### Scenario: CLAUDE_PROJECTS_DIR は CLAUDE_CONFIG_DIR より優先される
- **GIVEN** `CLAUDE_PROJECTS_DIR` と `CLAUDE_CONFIG_DIR` がどちらも設定され、それぞれの下に記録先 `288` のサブエージェントの usage の異なる会話記録がある
- **WHEN** `pr-token-budget.sh 288` を `--projects` なしで実行する
- **THEN** `claude_tokens` は `CLAUDE_PROJECTS_DIR` の下の会話記録の合計になる

#### Scenario: どちらも未設定なら ~/.claude の下を数える
- **GIVEN** `CLAUDE_PROJECTS_DIR` と `CLAUDE_CONFIG_DIR` がどちらも未設定で、`$HOME/.claude/projects/*/*/subagents/` に記録先 `288` のサブエージェントの会話記録がある
- **WHEN** `pr-token-budget.sh 288` を `--projects` なしで実行する
- **THEN** `claude_tokens` はその会話記録の usage の合計になる

### Requirement: 本体は spawn と再開の前に測り、上限超なら止まる
develop の本体は、その記録先のためにサブエージェントを spawn する直前、SendMessage で再開する直前、および executor が `codex` の役割へ委譲する直前に、役割と executor を問わず毎回 `scripts/pr-token-budget.sh <記録先番号> [PR 番号] --codex-records <file> --codex-home <dir>...` を MUST 実行する。`<file>` は、本体が計測の直前に `scripts/codex-records.sh --repo <owner>/<repo> --out <file> <記録先番号> [PR 番号]` で作る（渡すすべての記録先番号のコメントを全ページ取得し、1 行目が `^Codex 消費: ` に一致するものだけから `<thread_id> <tokens>` を 1 行ずつ書いたもの）。`codex-records.sh` が exit 0 以外を返したら、本体は `pr-token-budget.sh` を呼んではならず MUST NOT、`pr-token-budget.sh` の exit 1（計測できない）と同じ扱いにする（理由は「Codex 消費コメントを取得できなかった」）。取得に失敗した記録を空の記録や前回のファイルで代えてはならない（MUST NOT）。`--codex-home` には codex-develop の account と CODEX_HOME の対応表にある全パスと、本体の環境の `${CODEX_HOME:-$HOME/.codex}` を渡す。計測の手順は `skills/develop/SKILL.md`（本体手順）に置き、adapter（`references/codex-develop.md`）と `scripts/codex-worker.py` には置いてはならない（MUST NOT）。

本体は、その記録先のために Codex を呼んだら、そのたびに記録先へ 1 行目が `Codex 消費: <thread_id> <tokens>` のコメントを MUST 投稿する。executor が `codex` の役割へ委譲したときは codex-worker の結果 JSON の `thread_id` と `usage.total.totalTokens` を書く（`usage` が null か `usage.total.totalTokens` が読めないときは `<tokens>` を `-` と書く）。G が full レビューで Bash から Codex を呼んだときは、G が return に書いた thread_id（`codex exec` の出力ヘッダの `session id:`、companion の結果の `threadId`）を使い、`<tokens>` を `-` と書く。G は Codex を呼んだら thread_id を return に MUST 書く（`skills/develop/references/roles/gate-runner.md` に書く）。結果 JSON を受け取れず thread_id が分からない委譲と、G が thread_id を取れなかった Codex の呼び出しは記録できず、この上限の外になる。

exit 2 のときは spawn / SendMessage / Codex への委譲をしてはならず MUST NOT、記録先に `needs-approval` を付けて主に「続けるか、範囲外として閉じるか」の 2 択を出して止まる。2 択そのものは PR-A と同じだが、判断材料なしで出してはならず MUST NOT、問いには現在の合計・体数・上限・残工程（次に起こそうとした役割と、そのあと残る工程）・本体の推奨（どちらを選ぶかとその理由）を MUST 含める。unmanned でも同じく止まり、サイクルを終える。この手順は `skills/develop/SKILL.md` に SHALL 書く。

主が「続ける」を選んだら、本体は記録先に 1 行目が `PR トークン上限: <新上限>` のコメントを投稿し、以後その記録先の計測に `--cap <新上限>` を MUST 渡す。新上限は「その時点の合計 ＋ 直前の計測で上限に使った値（`--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 の順で決まった値）」とする。後任の本体は、記録先の最新の `PR トークン上限:` コメントの値を使う。主が「範囲外として閉じる」を選んだら、本体はその記録先について以後サブエージェントを起こさず Codex にも委譲せず、残作業を記録先にコメントしてサイクルを終える。

記録先がエピックの子のときは、主の返事を待つ前に、エピックの親が持つ「子 1 件あたりの PR トークンの権限」（エピックの 1 行目 `子の PR トークン権限: <値>` のコメント。既定 60000000）の内かが照らされる（MUST）。別セッション方式の子は今までどおり止まって最後の発言に見込みを書き、起こされた親が照らす。サブエージェント方式では親を兼ねる本体が、主に聞く前に自分で照らす（MUST。権限の置き場・照らす担い手・通す条件の正本は `dev-workflow-develop` の要件「エピックの親は子 1 件あたりの PR トークンの権限をエピックのコメントに置く」「親は権限のコメントが無ければ既定値で投稿して主に伝える」「親は PR トークン上限の止まりを権限に照らして続けさせる」「権限の内でない止まりは主に上げ、主が権限を広げたら照らし直す」「親の権限で続けた上限は子の本体が記録先に書く」「サブエージェント方式では親を兼ねる本体が権限に照らす」）。権限との照合の守備範囲（入力・拾いたい誤り・止めないもの）は `dev-workflow-develop` の要件「親は PR トークン上限の止まりを権限に照らして続けさせる」に置き、この要件には置かない。止まる上限そのもの（既定 30000000）は変えない（MUST NOT 変える）。親の権限の内として続けるときの新上限は、上の「合計 ＋ 直前の上限」ではなく権限の値とする（MUST）。本体は記録先に、1 行目が `PR トークン上限: <権限>` で、2 行目以降に `決めた人:`（親の判断か、サブエージェント方式で親を兼ねる本体か）・`権限:`（権限のコメントの URL）・`停止の記録:`（子の停止の記録の URL か `なし`。記録を残さない止まりは `なし`）を書いたコメントを投稿し、以後 `--cap <権限>` を渡す（MUST）。権限の内でなければ、上の手順どおり主に問う。エピックの子でない記録先の扱いは変えない。

exit 1 のとき（`codex-records.sh` が失敗して集計を呼ばなかったときを含む）は止まらずに進み、計測できなかったことと理由を記録先にコメントする。コメントは同じ記録先・同じ理由について 1 サイクルに 1 回までと SHALL する（spawn のたびに同じコメントを増やさない）。1 サイクルは、interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクルを指す。

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
- **THEN** 「`pr-token-budget.sh` が exit 2 なら spawn / SendMessage / Codex への委譲をせず主に上げる」手順、description に記録先番号 `#N` を入れる規約、Codex を呼んだら `Codex 消費:` コメントを投稿する手順、計測の前に `codex-records.sh` で `Codex 消費:` コメントを集めて `--codex-records` で渡す手順、`codex-records.sh` が失敗したら集計を呼ばず exit 1 と同じ扱いにする手順が書かれている

#### Scenario: コメントの取得に失敗したら計測できない扱いにする
- **WHEN** 計測の直前に `codex-records.sh` が exit 1 を返す（例: 記録先に `Codex 消費: t1 30000001` があり上限 30000000 だが、`gh api` が認証エラーで失敗した）
- **THEN** 本体は `pr-token-budget.sh` を呼ばず、上限以内として扱わない。止まらずに進み、「Codex 消費コメントを取得できなかった」ことを記録先にコメントする（同じサイクルで 2 回目以降は投稿しない）

#### Scenario: 続けたあとの計測は引き上げた上限を使う
- **WHEN** 上限 30000000 で止まり、その時点の合計が 30500000 で、主が「続ける」を選ぶ
- **THEN** 本体は記録先に `PR トークン上限: 60500000` をコメントし、次の spawn の前の計測に `--cap 60500000` を付ける

#### Scenario: エピックの子が親の権限で続けたあとの計測は権限を上限に使う
- **WHEN** エピックの子の記録先が上限 30000000 で止まり（合計 31000000）、親の権限が 60000000 で、子の合計の見込みが 45000000 のため親が続けさせる
- **THEN** 子の本体は記録先に 1 行目 `PR トークン上限: 60000000`、2 行目以降に `決めた人:`・`権限:`・`停止の記録:` のコメントを投稿し、次の spawn の前の計測に `--cap 60000000` を付ける。既定の上限 30000000 は変わらない

#### Scenario: SKILL.md の exit 2 にエピックの子の分岐が書かれている
- **WHEN** `skills/develop/SKILL.md` の「PR トークン上限」の exit 2 を読む
- **THEN** 記録先がエピックの子なら主に聞く前に親の権限の内かを照らすこと、権限の内なら新上限は権限で、`PR トークン上限: <権限>` に `決めた人:`・`権限:`・`停止の記録:` を添えて投稿すること、照らし方の正本が `references/epic.md` にあることが書かれている

#### Scenario: 計測できないコメントを重ねない
- **WHEN** 同じサイクルで 2 回続けて `pr-token-budget.sh` が同じ理由で exit 1 を返す
- **THEN** 本体が記録先に投稿する「計測できなかった」コメントは 1 件だけ

### Requirement: Codex 消費コメントの収集は全番号で成功したときだけ記録ファイルを作る
`scripts/codex-records.sh --repo <owner>/<repo> --out <file> <番号>...` は、渡されたすべての番号について記録先のコメントを全ページ取得し（`gh api --paginate --slurp repos/<owner>/<repo>/issues/<番号>/comments`）、1 行目が `^Codex 消費: ` に一致するコメントだけから、その接頭辞を除いた `<thread_id> <tokens>` を 1 行ずつ抜き出す。番号ごとに取得（`gh api`）と抽出（`jq`）の終了コードを MUST 検査する。すべての番号で取得と抽出に成功したときだけ、抜き出した行を `<file>` に書いて exit 0 を SHALL 返す（該当コメントが 1 件も無ければ空のファイルを作る）。取得・抽出・一時ファイルの作成や書き込みのどれかが 1 つでも失敗したら exit 1 を MUST 返し、`<file>` を残してはならない（MUST NOT。途中まで取れた記録も、前回の計測で作った同名のファイルも残さない）。引数が足りない・不正なとき、`gh` か `jq` が無いときも exit 1 を返し、`<file>` を残してはならない（MUST NOT）。

守備範囲: 想定する入力の出どころは `gh api --paginate --slurp` が返す記録先コメントの JSON とその終了コードである。拾いたい誤りは「GitHub からの取得が失敗したのに、空または途中までの記録が成功した記録として集計に渡ること」だけである。通ることを許す入力は、取得には成功したがコメントの書式が崩れている行（そのまま書き出し、`pr-token-budget.sh` の `skipped_lines` で扱う）と、`gh` が失敗を exit 0 で返す場合（検出できない）である。`gh` の失敗の返し方が変わるたびに検出を足して塞ぎ切ることを完了条件にしない。

#### Scenario: 全番号の取得に成功する
- **WHEN** 番号 419 と 450 を渡し、`gh api` がどちらも成功して、419 に `Codex 消費: t1 1000` と無関係なコメント、450 に `Codex 消費: t2 -` のコメントを返す
- **THEN** exit 0 で、`<file>` の中身は `t1 1000` と `t2 -` の 2 行になる

#### Scenario: 最初の番号の取得に失敗する
- **WHEN** 最初の番号で `gh api` が非 0 で終わる
- **THEN** exit 1 で、`<file>` は存在しない

#### Scenario: 途中のページで失敗する
- **WHEN** `gh api` が 1 ページ目の JSON を出力したあと非 0 で終わる
- **THEN** exit 1 で、`<file>` は存在しない

#### Scenario: 次の番号の取得に失敗する
- **WHEN** 最初の番号の取得に成功し、2 つ目の番号で `gh api` が非 0 で終わる
- **THEN** exit 1 で、`<file>` は存在しない（最初の番号の記録だけのファイルも残らない）

#### Scenario: 取得結果が JSON として読めない
- **WHEN** `gh api` が exit 0 で JSON でない出力を返す
- **THEN** exit 1 で、`<file>` は存在しない

#### Scenario: 前回のファイルを残さない
- **WHEN** `<file>` に前回の記録が残っている状態で、取得に失敗する
- **THEN** exit 1 で、`<file>` は存在しない

#### Scenario: 引数が足りない
- **WHEN** `--repo` か番号を渡さずに実行する（`--out` の `<file>` には前回の記録が残っている）
- **THEN** exit 1 で、`<file>` は存在しない

#### Scenario: gh が無い
- **WHEN** PATH に `gh` が無い状態で実行する
- **THEN** exit 1 で、`<file>` は存在しない

### Requirement: 消費の記録に工程・試行・アカウントの印を書く
develop の本体は、記録先の消費の記録に、1 行の印 `[消費記録 工程=<工程> 試行=<n> アカウント=<provider>:<登録名> 引継ぎ=<k>]` を MUST 書く。キーの順は問わない。`引継ぎ=` は、同じ工程と試行で手渡しにより起こし直した k 番目の担当のときだけ書き、最初の担当には書かない。読み取り側（flatmate の `burn_consumption.py`）の契約に合わせ、この印以外の書き方（自由文）で工程・試行・アカウントを表してはならない（MUST NOT）。
- 置き場は次の 3 か所とする: (1) `Codex 消費:` コメントの 2 行目以降（1 行目の `Codex 消費: <thread_id> <tokens>` の形は変えない）、(2) サブエージェントの `description`（`#N` と同じ文字列の中）、(3) `develop 開始` コメント（本体の起動アカウント。`工程=` と `試行=` は省いてよい）

#### Scenario: Codex 消費コメントの 2 行目に印を書く
- **WHEN** 本体が executor `codex` の W の implement 工程の 2 回目の試行の結果を記録する（thread_id `t1`・totalTokens 1200000・Codex の登録名 `current`）
- **THEN** 本体は 1 行目が `Codex 消費: t1 1200000` で、2 行目が `[消費記録 工程=implement 試行=2 アカウント=codex:current]` のコメントを投稿する

#### Scenario: 1 つの工程・試行にしか使わないサブエージェントの description に印を入れる
- **GIVEN** Claude の登録名が `a` と取れていて、記録先 #288 の implement 工程のレビュアー（`impl-review`）の初回（試行 1・手渡しなし）を、再開しない 1 体として起こす
- **WHEN** 本体が spawn する
- **THEN** `description` は `#288` と `[消費記録 工程=impl-review 試行=1 アカウント=claude:a]` を同じ文字列の中に含む

#### Scenario: SKILL.md に規約が書かれている
- **WHEN** `skills/develop/SKILL.md` を読む
- **THEN** 「PR トークン上限」節の紐付けの規約と Codex の消費の記録、「Role profile の選択」節の develop 開始コメントの記述に、印の形・置き場・工程名の語彙・試行と引継ぎの数え方・再開される W の扱い・G とレビュアーの工程の決め方が書かれている

#### Scenario: 手渡しで起こし直した W に引継ぎを書く
- **GIVEN** 登録名 `a` が取れていて、implement 工程の 2 回目の試行を、前任から手渡しで起こし直した 1 番目の担当の W に担わせる（再開しない）
- **WHEN** 本体が記録先 #288 のために spawn する
- **THEN** `description` の印は `工程=implement 試行=2 アカウント=claude:a 引継ぎ=1` を含む

#### Scenario: develop 開始コメントに起動アカウントを書く
- **GIVEN** Claude の起動アカウントの登録名 `a` が取れている
- **WHEN** 本体が `develop 開始` コメントを投稿する
- **THEN** コメントに `[消費記録 アカウント=claude:a]` の行がある（`工程=` と `試行=` は無くてよい）

### Requirement: 消費の記録の印の工程と試行を決める
develop の本体は、印の工程と試行を次のとおり MUST 決める。
- 工程の値は `spec`・`spec-review`・`implement`・`impl-review`・`finish`・`gate-prepare`・`gate-triage`・`gate-pass`・`gate-hold`・`decide`・`screen-check` のどれかとする
- 試行は、工程ごとに 1 から数え、差戻しの修正で同じ工程をやり直すたびに増やす
- G 自身の工程は、本体が起こした段（G の名前 `G-<PR>-<prepare|triage|pass|hold>-<n>`）から `gate-<段>` と決める。Gate Result の `段:` の値は使わない。G が要求した Codex や Claude のレビュアーの工程は `impl-review` とする

#### Scenario: G と G が要求したレビュアーの工程
- **GIVEN** 登録名 `a` が取得済みで、名前が `G-1700-triage-1` の G（triage 段の初回・手渡しなし）が、full レビューで Codex を呼んだ（Gate Result の `段:` は日本語名）
- **WHEN** 本体が G とその Codex 消費を記録する
- **THEN** G の description の印は `工程=gate-triage 試行=1 アカウント=claude:a`、Codex の `Codex 消費:` コメントの印は `工程=impl-review`（試行は impl-review の回数）である

#### Scenario: G を手渡しで起こし直しても試行は増えない
- **GIVEN** 登録名 `a` が取得済みで、`G-1700-triage-1` が `工程中断:` で止まり、triage 段の初回の試行のまま手渡しで新しい G を起こす
- **WHEN** 本体が `G-1700-triage-2` を spawn する
- **THEN** description の印は `工程=gate-triage 試行=1 アカウント=claude:a 引継ぎ=1` である（名前の `<n>` は起動回数で、試行ではない）

#### Scenario: 差戻しのあとの G の試行は増える
- **GIVEN** 登録名 `a` が取得済みで、triage 段の 1 回目の試行が差戻しで終わり、手渡しは無い
- **WHEN** 本体が `G-1700-triage-2` を spawn する
- **THEN** description の印は `工程=gate-triage 試行=2 アカウント=claude:a` で、`引継ぎ=` を含まない

### Requirement: 消費の記録の印のアカウントと時刻の扱いを決める
develop の本体は、印のアカウントと時刻を次のとおり MUST 扱う。
- アカウントは `claude:<登録名>` か `codex:<CODEX_HOME 対応表の登録名>` とする。登録名が分からないときは `アカウント=` のキーごと省き、推測で埋めてはならない（MUST NOT）
- 印に時刻（`開始=` `終了=`）を書いてはならない（MUST NOT。読み取り側の契約に無いキーのため）

守備範囲: この段落は消費の記録の印の 4 要件すべてに掛かる。想定する入力の出どころは、本体が書く記録先のコメントとサブエージェントの `description` である。拾いたい誤りは、別の工程・試行・アカウントの印を書くことと、印の形を読み取り側の契約から外すこと。通ることを許す入力は、印を書き忘れた記録（読み取り側が欠測にする）、`G-<PR>-<段>-<n>` / `V-<記録先番号>-<n>` の名前で工程が決まる G と画面確認のサブエージェントに印が無いこと。印の書き忘れを塞ぎ切ることは完了条件にしない。

#### Scenario: 登録名が分からないときは推測しない
- **WHEN** Claude の起動アカウントの登録名が取れない
- **THEN** description・開始コメントの印は `アカウント=` のキーを含まない

### Requirement: 再開されるサブエージェントの印を再開の指示文に書く
- 同じサブエージェントを SendMessage で別の工程・試行へ再開しうるとき（既定の W）は、`description` の印に `工程=` と `試行=` を書いてはならない（MUST NOT。読み取り側は 1 体を 1 行にして description の印から 1 つだけ読むため、再開後の消費が起動時の工程・試行へ誤帰属する）。`アカウント=`（と該当すれば `引継ぎ=`）だけを書く。本体は再開のたびに、再開の指示文の先頭にその再開が担う工程・試行の印を 1 行置く MUST

#### Scenario: 再開される W は spec から implement へ
- **GIVEN** 登録名 `a` が取得済みで、同じ W が spec 工程のあと、implement の初回（試行 1・手渡しなし）として SendMessage で再開される
- **WHEN** 本体が W を spawn し、のちに再開する
- **THEN** spawn 時の `description` の印は `工程=` と `試行=` を含まず（`アカウント=` だけ）、implement への再開の指示文の先頭に `[消費記録 工程=implement 試行=1 アカウント=claude:a]` の行がある

#### Scenario: 差戻しの修正で implement を試行 1 から 2 へ再開する
- **GIVEN** 登録名 `a` が取得済みで、同じ W が implement 試行 1 のあと、差戻しの修正（試行 2・手渡しなし）のために SendMessage で再開される
- **WHEN** 本体が再開する
- **THEN** 再開の指示文の先頭に `[消費記録 工程=implement 試行=2 アカウント=claude:a]` の行があり、spawn 時の `description` の印は `工程=` と `試行=` を含まない
