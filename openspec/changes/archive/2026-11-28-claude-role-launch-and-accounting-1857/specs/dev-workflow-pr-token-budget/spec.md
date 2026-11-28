# Spec Delta

## 明示登録の守備範囲

守備範囲（明示登録共通）: 入力元は本体と launcher がリポジトリ外に作る `--session-records` の JSONL 登録、その登録が指定する Claude の自身ログと Codex の home / rollout、および呼出し側の git common dir・記録先番号である。拾う誤りは JSONL の破損・不正な登録、ID・repo 帰属・ログの欠損、別 repo / 別番号の混入、ログの読取不能・有効 usage の欠落、Codex 本体の登録忘れ、同一 session / thread / request の二重計上、および既知の欠測を消費 0 とすることである。通してよい具体例は、同じ repo の別 worktree から同じ番号へ同一 session を重複登録する入力（一回だけ数える）、同じ repo / 番号へ別作業のログを誤登録したが登録形式・ID・ログ・usage は有効な入力（そのまま数える）、および登録の帰属値やログの usage を形式が有効なまま書き換えた入力である。帰属は登録値との一致で選別し、作業内容を意味から照合しない。改変が破損・必須情報欠落・読取不能・usage 欠落として現れるものは診断するが、登録・ログの真正性の証明、形式を保つ改変や書込み遅延の検出、登録されなかった Claude session の網羅的な探索は行わない。これらの穴の完全封鎖を完了条件にしない。この段落は明示登録の選別・集計・欠測判定に共通で適用し、従来のコメント記録・projects 探索の守備範囲を置き換えない。

## MODIFIED Requirements

### Requirement: Codex の消費を記録から合計する
`pr-token-budget.sh` は `--codex-records <file>` を受け取ったとき、そのファイルの各行 `<thread_id> <tokens>`（`<tokens>` は 0 以上の整数か `-`）を、その記録先のために使った Codex の thread と SHALL みなし、その消費を `codex_tokens` に合計する。同じ thread_id は、ファイル内に何行あっても 1 回だけ MUST 数える（トークン数が行ごとに違うときは最大値を使う）。`<tokens>` が `-` の thread は、`--codex-home <dir>`（繰り返し指定可。無ければ `${CODEX_HOME:-$HOME/.codex}`）の `sessions/*/*/*/rollout-*-<thread_id>.jsonl` を探し、`type` が `event_msg` で `payload.type` が `token_count` の行の `payload.info.total_token_usage.total_tokens` の最大値を SHALL 使う（`info` が null の行は読み飛ばす）。トークン数が `-` で rollout も見つからない thread は合計に入れず、件数を出力の `codex_unresolved` に MUST 出す。書式に合わない行で集計を中断してはならず MUST NOT、その行数を `skipped_lines` に含める。ファイルが空（または空行だけ）のときはエラーにせず、`codex_threads` を 0 として SHALL 扱う。スクリプトは GitHub を読んではならない（MUST NOT。記録先のコメントを集めてファイルにするのは本体の手順）。

守備範囲: 想定する入力の出どころは、本体が記録先の `Codex 消費:` コメントから作るファイルと、Codex CLI が書く rollout ファイルである。拾いたい誤りは「その記録先のために使った Codex の消費が合計から漏れること」と「同じ thread を複数の記録先に記録したことや、rollout で同じ累計が繰り返し書かれることによる二重計上」の 2 つ。通ることを許す入力は、本体が記録を書き忘れた thread（数えられず合計は少なく出る）、結果 JSON を受け取れずに thread_id が分からない委譲と、G が thread_id を取れなかった Codex の呼び出し（どちらも数えられない）、別の作業で使った thread_id が誤って記録された行（そのまま数える）、トークン数が不自然に大きい行（そのまま数える）、rollout が複数の CODEX_HOME に同じ thread_id で見つかる場合（最大値を使う）である。これらの穴が見つかるたびに照合を強くして塞ぎ切ることを完了条件にしない。


`--session-records` で明示登録された進行中の Codex 本体 thread は、コメントの数値があっても登録された home / rollout の最新の有効な累計を毎回 MUST 読む。同じ thread のコメント・複数登録・複数 home の累計は加算せず、得られた累計の最大値を 1 回だけ使う（MUST）。明示登録の thread が読めない場合の欠測は「明示 session の欠測を 0 消費にしない」に従う。明示登録入力の守備範囲は「明示登録の守備範囲」節を適用し、上記のコメント・rollout 入力の守備範囲とは区別する。従来の記録ファイルだけを使う経路の空ファイル・未解決件数の扱いは維持する。

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

#### Scenario: 本体の進行中 rollout をコメントより新しく測る
- **WHEN** 同じ thread がコメントで 1000、明示登録の進行中 rollout で累計 1000・1600・1600 と記録され、同じ登録が issue / PR 用に重複する
- **THEN** 本体の消費は 1600 で thread 数は 1 となり、次の計測で 1900 が追記されれば 1900 になる


### Requirement: 出力と exit code
`pr-token-budget.sh <番号>... [--cap <tokens>] [--projects <dir>] [--codex-records <file>] [--codex-home <dir>]... [--session-records <file>]` は、stdout に 1 行 JSON を SHALL 出す。キーは少なくとも `records`（渡した番号の配列）・`claude_tokens`・`codex_tokens`・`total_tokens`（`claude_tokens + codex_tokens`）・`agent_count`・`codex_threads`・`cap`・`over_cap`・`unresolved`・`codex_unresolved`・`skipped_lines`・`agents`（各サブエージェントの `name`・`description`・`model`・`tokens`・`requests`）・`codex`（各 thread の `thread_id`・`tokens`・`source`（`record` か `rollout`））とする。上限は Claude 分と Codex 分を分けず、`total_tokens` に 1 本で MUST 掛ける。上限は `--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ数えたリクエストのモデルで共通の解決処理が返す `pr_token_cap`（モデルの集め方・値が分かれたときの採り方・診断の正本は `dev-workflow-token-thresholds` の累計計測の要件）を使い、出力の `cap` は採用した上限とする（MUST）。走査対象は `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/*/subagents/agent-*.meta.json`（`--projects` で差し替え）とする。

exit code は、`total_tokens` が上限以下なら 0、上限を超えたら 2、引数エラー・python3 が無い・カレントディレクトリがリポジトリでない・上限を解決できない（表や上書きの不正、共通の解決処理を読めない）ときは 1 と MUST する。紐付くサブエージェントが 0 体であること自体はエラーにせず、合計 0 で exit 0 と SHALL する（上限を解決できなければ 0 体でも exit 1）。

守備範囲: 想定する入力の出どころは、`--projects`、環境変数 `CLAUDE_PROJECTS_DIR` / `CLAUDE_CONFIG_DIR` / `HOME` で決まる 1 か所の projects ディレクトリと、`--cap` / `DEV_WORKFLOW_PR_TOKEN_CAP` の上限の値である。拾いたい誤りは、Claude Code が会話記録を書いた設定フォルダと違う場所を探して Claude 分を 0 と数え、上限の判定が効かないことである。通ることを許す入力は、1 つの記録先を別々の `CLAUDE_CONFIG_DIR` のセッションで進めたときの別の設定フォルダ側の消費（数えず、合計は少なく出る）と、会話記録の無い場所を指す `CLAUDE_CONFIG_DIR`（紐付く 0 体として合計 0・exit 0）である。これらの穴が見つかるたびに探索先を増やして塞ぎ切ることを完了条件にしない。


追加の `--session-records <file>` は「独立 session の明示登録を集計する」と「明示登録の守備範囲」節に従う。同節を明示登録入力の選別・欠測判定にも適用し、上記の projects 探索の守備範囲だけでは扱わない。`claude_tokens` に独立 Claude 役を、`codex_tokens` に Codex 本体を加え、`total_tokens` はその合計とする（MUST）。既存キーを維持し、独立 Claude 役は別の `claude_sessions` 配列（session ID・ログパス・tokens・requests）へ、明示登録の欠測は `session_unresolved` と診断へ MUST 出す。`agent_count` は従来の subagent 数である。既知の合計が上限超過なら欠測があっても exit 2、それ以外で明示登録の欠測があれば exit 1、欠測なしで上限以内なら exit 0 とする（MUST）。明示登録なしの従来経路は既存の規則を維持する。

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

#### Scenario: 上書きの無い既定はモデル別の表の値
- **WHEN** `--cap` も `DEV_WORKFLOW_PR_TOKEN_CAP` も無く、数えたリクエストのモデルが `claude-opus-5-5` だけである
- **THEN** 出力の `cap` は表の `claude-opus-5-5` 行の `pr_token_cap`（30000000）で、stderr に診断は出ない

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

#### Scenario: 三つの経路を一つの上限で測る
- **WHEN** 既存 Claude subagent が 100、独立 Claude 役が 200、Codex 本体が 400 で、cap が 600 である
- **THEN** claude_tokens=300、codex_tokens=400、total_tokens=700、agent_count=1、独立 Claude session 数=1、codex_threads=1、over_cap=true となり exit 2 を返す

#### Scenario: 欠測があっても既知の合計が既に上限を超える
- **WHEN** 独立 Claude 役の登録ログが欠け、既知の Codex 本体だけで cap を超える
- **THEN** session_unresolved と理由を示し、exit 2 を返して超過を隠さない


### Requirement: 計測は 1 コマンドのラッパーで呼ぶ
`plugins/dev-workflow/scripts/pr-token-measure.sh --repo <owner>/<repo> [--cap <tokens>] [--codex-home <dir>]... [--session-records <file>] <記録先番号>...` を持たなければならない（MUST）。`codex-records.sh` を呼び、exit 0 のときだけ `pr-token-budget.sh <番号>... --codex-records <file>` を呼ぶ。`--codex-home` には渡されたものに加えて `${CODEX_HOME:-$HOME/.codex}` を渡し、`--cap` は渡されたときだけ渡す。`pr-token-budget.sh` の stdout と exit code（0 / 2 / 1）をそのまま返す。

`--session-records` が渡されたときは、その同じファイルを `pr-token-budget.sh` へ MUST 渡す。登録入力の守備範囲は「明示登録の守備範囲」節に従う。Codex 本体による G002 の起動・再開前の呼出しでは、自身の進行中 thread とそれまでの Claude 役を登録したファイルを MUST 指定する。本体の thread ID / home を取得できないときはその欠損を明示し、履歴なしを 0 消費とみなしてはならない（MUST NOT）。新しい本体共通手順や provider 選択機構は導入しない。

#### Scenario: 記録の取得と集計を 1 回の呼び出しでつなぐ
- **WHEN** `pr-token-measure.sh --repo o/r 288` を呼び、`codex-records.sh` が exit 0 で記録を書く
- **THEN** `pr-token-budget.sh 288 --codex-records <その記録>` が呼ばれ、その stdout と exit code がそのまま返る

#### Scenario: 上限超過は exit 2 のまま返す
- **WHEN** `pr-token-budget.sh` が exit 2 を返す
- **THEN** ラッパーも exit 2 で終わり、stdout は `pr-token-budget.sh` の 1 行 JSON と同じである

#### Scenario: --cap は渡されたときだけ渡す
- **WHEN** `--cap 60000000` を付けて呼ぶ場合と、付けずに呼ぶ場合
- **THEN** 前者は `pr-token-budget.sh` に `--cap 60000000` が渡り、後者は `--cap` が渡らない

#### Scenario: 本体の環境の CODEX_HOME を渡す
- **WHEN** `--codex-home /x` を付けて呼ぶ
- **THEN** `pr-token-budget.sh` には `--codex-home /x` と `--codex-home ${CODEX_HOME:-$HOME/.codex}` の両方が渡る

#### Scenario: 明示登録と既存コメントを一回で測る
- **WHEN** 本体 thread と Claude 役の登録ファイルを指定してラッパーを実行し、コメント取得が成功する
- **THEN** 同じ登録ファイルと取得したコメントファイルの両方を集計へ渡し、stdout と exit 0 / 1 / 2 をそのまま返す


## ADDED Requirements

### Requirement: 独立 session の明示登録を集計する
`pr-token-budget.sh` は `--session-records <file>` の JSONL 登録から、記録先番号と git common dir が一致する独立 Claude 役 session および Codex 本体 thread を MUST 数える。Claude 役は自身のログの全有効 assistant usage 四項を合計し、既存と同じ request ID の重複排除を MUST 行う。再開・issue / PR 併記・同じログの複数登録でも同じ provider/session を二重計上してはならない（MUST NOT）。入力の選別・集計には「明示登録の守備範囲」節を適用する。

#### Scenario: 役の再開と複数番号でも session を一回だけ数える
- **WHEN** 同じ repo の Claude session s1 が #1857 と PR 番号に登録され、再開後のログに r1 の重複行と r2 がある
- **THEN** 両番号を指定しても s1 は一体で、r1 と r2 の四項合計を一回ずつ数える

#### Scenario: 別 repo と桁の異なる記録先を混ぜない
- **WHEN** 同じ番号で別 repo の登録、同じ repo の #18570 の登録、同じ repo の別 worktree の #1857 の登録がある
- **THEN** #1857 の集計には最後の登録だけが入り、worktree は共通の repo に畳まれる

#### Scenario: 既存探索と明示登録が同じログを指す
- **WHEN** 既存 meta の探索結果と明示登録が同じ実体の Claude ログを指す
- **THEN** 同じログの request を一回だけ加算し、二経路の合計を足さない

### Requirement: 明示 session の欠測を 0 消費にしない
登録済みの実行に ID・repo 帰属・ログがない、ログが読めない、または有効な usage がない場合、集計は理由と件数を MUST 明示し、計測成功の 0 に置き換えてはならない（MUST NOT）。明示登録モードで Codex 本体の登録がない場合も欠測とする。既存の exit 1 の本体方針（理由の記録と続行）は維持し、0 / exit 0 を成功根拠にしない。JSONL の破損や不正な登録も診断対象とする。入力元・拾う誤り・通してよい入力と検出限界は「明示登録の守備範囲」節を適用する。

#### Scenario: 起動を登録したが履歴がない
- **WHEN** Claude 役 session を登録済みで、ログがない、空、または全行が usage なしの各場合
- **THEN** session_unresolved が増え、既知の合計が cap 以下なら exit 1 となり、消費 0 の確定記録を作らない

#### Scenario: Codex 本体に有効な累計がない
- **WHEN** 登録した進行中 thread の rollout がないか、token_count の info が null の行しかない
- **THEN** コメントが空でも欠測を返し、履歴なしを fresh context や消費 0 の根拠にしない

#### Scenario: 明示登録モードで本体を登録し忘れる
- **WHEN** 渡した登録ファイルが空、または対象番号に一致する Claude 役だけを含む
- **THEN** Codex 本体の登録欠損を診断し、既知の合計が cap 以下なら exit 1 になる

#### Scenario: 従来の未起動と既知の欠測を区別する
- **WHEN** 明示登録オプションなしで紐付く subagent が 0 体の従来の呼出しをする
- **THEN** 従来どおり合計 0 と exit 0 を返し、その結果を明示登録済みの本体や役の消費 0 の証拠に転用しない
