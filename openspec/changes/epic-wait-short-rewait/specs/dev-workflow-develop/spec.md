## ADDED Requirements

### Requirement: 上限を明示しない wait は親の会話キャッシュの有効期限で上限を決める

`plugins/dev-workflow/scripts/epic-dispatch.sh wait` は、`--timeout` が無く `EPIC_DISPATCH_TIMEOUT` も無いか空のとき、最初のポーリングの前に `cache_ttl_of "$(git rev-parse --show-toplevel)"` を 1 回呼び、`5m` なら上限を 21600 秒、`1h` か exit 1 なら 2700 秒にしなければならない（MUST）。このとき最初のポーリングの前に stderr へ `wait limit <秒> (parent cache <5m|1h|unknown>)` の 1 行を出す（SHALL。`unknown` は exit 1 のとき）。

守備範囲: ①入力は親のワークツリーのトランスクリプト。②拾いたいのは、1 時間で書いている親が 6 時間眠ってキャッシュを切らすことと、5 分で書いている親が 45 分ごとに起きて書き直しを払い続けること。③判定できないときに短い上限になることは通してよい。

#### Scenario: 1 時間で書いている親は短い上限で待つ
- **WHEN** 親のワークツリーの置き場に、最後にキャッシュを書いた assistant の行が `ephemeral_1h_input_tokens` 正・`ephemeral_5m_input_tokens` 0 のトランスクリプトを置き、子 11 が `closed` を返すスタブ環境で、`--timeout` も `EPIC_DISPATCH_TIMEOUT` も無しに `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 2700 (parent cache 1h)` の 1 行が出て、stdout は `closed 11` の 1 行で exit 0

#### Scenario: 5 分だけで書いている親は長い上限で待つ
- **WHEN** 最後にキャッシュを書いた assistant の行が `ephemeral_5m_input_tokens` 正・`ephemeral_1h_input_tokens` 0 のトランスクリプトを置いて、同じく `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 21600 (parent cache 5m)` の 1 行が出る

#### Scenario: 判定できなければ短い上限で待つ
- **WHEN** 親のワークツリーの置き場が無い環境で `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 2700 (parent cache unknown)` の 1 行が出る

### Requirement: 上限を明示した wait は有効期限を読まない

`epic-dispatch.sh wait` は、`--timeout` か空でない `EPIC_DISPATCH_TIMEOUT` があるときはその値（`--timeout` が優先）を上限にし、`cache_ttl_of` を呼んではならず、`wait limit` の行を出してはならない（MUST NOT）。上限の決め方にかかわらず、stdout の 1 行と exit code の契約は変えない（MUST）。

守備範囲: 拾いたいのは、待ちをやめる直前の `--timeout 0` の確認で stderr に行が出て「stderr が空」の条件を壊すこと。

#### Scenario: 上限を明示したら有効期限を読まない
- **WHEN** 5 分だけで書いたトランスクリプトを置いて、`epic-dispatch.sh wait --interval 0 --timeout 0 11` と、`EPIC_DISPATCH_TIMEOUT=0 epic-dispatch.sh wait --interval 0 11` を、子 11 が `open` を返すスタブ環境で実行する
- **THEN** どちらも stdout は `timeout 11` の 1 行、stderr は空で exit 2

### Requirement: cache_ttl_of はワークツリーの会話で最後にキャッシュを書いた行を読む

`epic-dispatch.sh` の関数 `cache_ttl_of <ワークツリーの絶対パス>` が使う行は、`type` が `assistant`・`isSidechain` が true でない・`timestamp` が文字列・`message.usage.cache_creation` の 5m と 1h の書き込み（`ephemeral_5m_input_tokens`・`ephemeral_1h_input_tokens`）の和が正（数でない値は 0）の行のうち、`timestamp` が最も新しい 1 行とする（MUST）。

守備範囲: ①入力は同じ PC の Claude Code が書いた置き場の直下の jsonl（親か、順番 2 では子のもの）。②拾う誤りは、サブエージェント・`isSidechain`・書き込み 0・古い行を最新と読むことと、数でない値や壊れた行で落ちること。③通してよい入力は次の要件に書く。④形の変化の検知とすり抜けを塞ぎ切ることは完了条件にしない。

#### Scenario: 書き込みの無い行と古い行とサブエージェントの行では決めない
- **WHEN** 置き場の 2 つの jsonl に、古い `timestamp` の 5 分だけの行、新しい `timestamp` の 1 時間の行、それより新しい書き込みが 0 の行を置き、`<セッション>/subagents/` の下にさらに新しい 5 分だけの行を置いて `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 2700 (parent cache 1h)` が出る

### Requirement: cache_ttl_of は置き場の直下だけを読み、引数が空なら置き場を読まない

`cache_ttl_of` は、`transcript_dir <引数>` の置き場の直下の `*.jsonl` だけを読まなければならない（MUST。`<セッション>/subagents/*.jsonl` は読まない）。引数が空なら置き場を求めずに、stdout に何も出さず exit 1 で終わらなければならない（MUST）。

守備範囲: 入力・誤り・完了条件にしないものは要件「cache_ttl_of はワークツリーの会話で最後にキャッシュを書いた行を読む」のとおり。加えて拾いたいのは、`toplevel` が失敗して空を返したときに `transcript_dir ""` が置き場の親（projects の直下）を指し、どのワークツリーのものでもない jsonl から有効期限を読むこと。

#### Scenario: ワークツリーのパスが取れなければ置き場の親を読まない
- **WHEN** `git rev-parse --show-toplevel` が空を返すスタブ環境で、`$CLAUDE_PROJECTS_DIR` の直下に 5 分だけで書いた行の jsonl を置き、`epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 2700 (parent cache unknown)` が出る

### Requirement: cache_ttl_of は有効期限と時刻を 1 行で返し、判定できなければ何も出さない

`cache_ttl_of` は、使う行の `ephemeral_1h_input_tokens` が正なら `1h`、0 なら `5m` とし、stdout に `<1h|5m> <その行の timestamp の epoch 秒>` の 1 行を出して exit 0 で終わらなければならない（MUST。epoch 秒は最後にキャッシュを書いた行の時刻で、最後のリクエストの時刻ではない）。置き場に `*.jsonl` が無い・python3 が無い・使う行が無いときは、stdout に何も出さず exit 1 で終わる（MUST）。gh も LLM も呼ばず、stderr にも出さない（MUST NOT）。

守備範囲（通してよい入力）: 同じワークツリーの別のセッションの行が最新になること（同じアカウントなら超過の状態は同じ）／両方の有効期限が正の行を `1h` と読むこと（事実でなく判定の限り。外れると 1 回分の書き直しを払うが、次の行は `5m` と読めて戻る）／該当する行が無く判定できないこと。

#### Scenario: 両方の有効期限で書いた行は 1 時間とみなす
- **WHEN** 最後にキャッシュを書いた行の `ephemeral_5m_input_tokens` と `ephemeral_1h_input_tokens` がどちらも正のトランスクリプトで `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 2700 (parent cache 1h)` が出る

### Requirement: 親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す

develop の `references/epic.md` の別セッション方式の手順 5（`timeout <N>...` で起こされたとき）は、親が子 issue もエピックも読まず、主に報告もせず、直前と同じ引数の `wait` を `run_in_background: true` で再び 1 回起動してターンを終えることと、`--timeout` を足さないことを書かなければならない（MUST）。主への発言は書かないか、書くなら書き分けに従う `主がすること: なし` の 1 行だけとする（SHALL）。主への問いが未回答のあいだは `主がすること: なし` も書かず、何も書かない（SHALL。問いを繰り返しもしない）。親がターンを終えるときの発言の一覧から、手順 5 の `timeout` の報告を外す（MUST）。

守備範囲: 子が印を付けずに `needs-approval` だけで止まったとき、ほかの子が動くか待ちをやめる直前まで親が気づかないことは通してよい。

#### Scenario: 手順 5 は同じ wait を掛け直すだけにする
- **WHEN** `references/epic.md` の手順 5（`timeout <N>...` で起こされたとき）を読む
- **THEN** 子 issue もエピックも読まず主に報告もせずに、直前と同じ引数の `wait` を `run_in_background: true` で再び 1 回起動してターンを終えること、`--timeout` を足さないこと、**待ちをやめてよい条件** を指すことが書かれ、`needs-approval` の文字列は無い

### Requirement: 手順 5 で気づけない子のことは最初に待ちに入る通知で一度だけ主に伝える

`references/epic.md` の手順 5 は、子が記録（`子の停止: 主の返事待ち`）を残さずに自分のタブで質問して止まるとこの手順では検知できないことを注記として書かなければならない（SHALL）。手順 2 は、手順 1 の `launch` のあと、このセッションで最初に待ちに入る通知で一度だけ、子のタブも見るよう主に伝えると書く（SHALL）。手順 5 の掛け直しのたびには伝えない（SHALL）。

守備範囲: 拾いたいのは、手順 5 が主に何も書かなくなったことで、この注意が主に一度も届かなくなること。

#### Scenario: 手順 5 に検知できないことが書かれている
- **WHEN** `references/epic.md` の手順 5 を読む
- **THEN** 記録を残さずに子のタブで質問して止まった子は検知できないことが書かれている

#### Scenario: 検知できない子のことは最初に待ちに入る通知で一度伝える
- **WHEN** `references/epic.md` の手順 2 を読む
- **THEN** `launch` のあと最初に待ちに入る通知で、記録を残さずに止まった子には気づけないので子のタブも見るよう主に一度伝えることが書かれている

### Requirement: timeout から外した確認は closed のときと待ちをやめる前に残し、片付け待ちだけの待ちは長い上限を明示する

`references/epic.md` は、`後で別に起動するエピック: #N` の行で子を外す確認を `closed` で起こされたときだけに書き、`needs-approval` の確認を待ちをやめる直前の確認に残さなければならない（MUST）。手順 4 の、片付け待ちの子だけを待つ `wait` には `--timeout 21600` を付けると書く（MUST）。手順 6 の、何もしない子を待つ説明は、最長の時間ではなく親が気づかずに待ち続けることとして書く（SHALL）。

守備範囲: 拾いたいのは、片付け待ちだけの待ちが 45 分でやめてしまうこと。

#### Scenario: 子エピックの行で外す確認は closed のときだけ
- **WHEN** `references/epic.md` の、`後で別に起動するエピック: #N` の行で子を外す確認の段落を読む
- **THEN** その確認を `closed` で起こされたときに行うと書かれ、`timeout` で起こされたときに行うとは書かれていない

#### Scenario: 片付け待ちだけの待ちは長い上限を明示する
- **WHEN** `references/epic.md` の手順 4 の、`kept <N> not-done` の子だけを `--watch-done` に渡して待つ文を読む
- **THEN** その `wait` に `--timeout 21600` を付けることが書かれている

### Requirement: 規則のファイルに親の待ちの費用と使用量の超過中の扱いを書く

`references/reply-after-idle.md` は、閾値の表とそのまま送るか起動し直すかの表とは別の節に、`wait` の上限の既定 2700 秒とその理由（キャッシュの 1 時間と、アイドル時のコンパクトの約 54 分の前に起きる）、上限で起きた親は掛け直すだけであること、使用量の超過中は有効期限が 5 分に縮むので 21600 秒に戻すこと（根拠の URL を添える）、有効期限を固定した人の扱い、PC が寝ている間は効かないことを書かなければならない（MUST）。その節の外の表と文を変えてはならない（MUST NOT）。

守備範囲: #1323 が同じファイルの表を変えるので、この change は節を足すだけにする。

#### Scenario: 規則のファイルに親の待ちの費用と超過中の扱いがある
- **WHEN** `references/reply-after-idle.md` を読む
- **THEN** 親の待ちの費用の節があり、2700 と 21600、使用量の超過中に 5 分に縮むこと、https://code.claude.com/docs/en/prompt-caching 、`CLAUDE_CODE_PROMPT_CACHE_TTL`、PC が寝ている間は効かないことが書かれ、閾値の表とそのまま送るか起動し直すかの表はこの change の前と同じ

## MODIFIED Requirements

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
`skills/develop/references/epic.md` は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。

**回し方（経路の決め方）**: interactive の本体は子の依存グラフを読み、blocked されていない子の番号を `plugins/dev-workflow/scripts/epic-dispatch.sh route` に渡して経路を決める（MUST）。`route` が `orca` か `tmux` を返したとき（Orca 管理のワークツリーにいる、または tmux の中にいる）は、その起動部品で子を別のセッションとして起こす **別セッション方式**、`subagent` を返したときは **サブエージェント方式**で進める（MUST）。別セッション方式とサブエージェント方式は二本立てではなく、子を起こす手段を起動部品として差し替える一本の手順で書く（MUST。共通の手順に、部品ごとに違う点だけを部品ごとの欄に書く）。経路は `/develop <エピック番号>` の最初の開始時に 1 回決め、途中で変えてはならず（MUST NOT）、決めた経路をエピックに `回し方:` で始まる 1 行コメントで残す（MUST）。別セッションで同じエピックを再開したときは、`回し方:` で始まる最新のコメントを読んで経路を引き継ぎ、`route` をやり直してはならない（MUST NOT）。最新の `回し方:` が `Orca` か `tmux` のときは、本体が `epic-dispatch.sh launch` と `adopt` に環境変数 `EPIC_DISPATCH_LAUNCHER=<そのコメントの部品名（小文字の orca か tmux）>` を付けて呼ばなければならない（MUST。付けないと部品を今の環境から選び直し、前のセッションの記録の子と別の部品で新しい子が起動しうる）。その部品が今の環境で使えず `launch`・`adopt` が exit 1 で終わったら、別の部品にもサブエージェント方式にも振り替えず、stderr を添えて主に報告して止まる（MUST。部品の違う子の混在を作らない）。`reply`・`notify-closed`・`reap`・`wait --resolve` は記録の `launcher` で部品が決まるので、再開で環境が変わっても部品名を渡さない。unmanned（`--unmanned`）では `route` を呼ばず、サブエージェント方式で進める（MUST。背景で待って起こされる動きが 1 サイクル 1 仕事と合わないため）。channel でも `route` を呼ばず、サブエージェント方式で進め、エピックに `回し方: サブエージェント（channel モード）` を残す（MUST）。channel で再開したエピックの最新の `回し方:` が別セッション方式（Orca・tmux）なら、`launch` もサブエージェント方式も使わず、その旨をチャンネルで主に報告して止まる（MUST。channel は別セッション方式を引き継がない）。channel の本体は、develop の手順のために別の Claude Code セッション（Orca・tmux など）を起こしてはならない（MUST NOT。別に起こしたセッションには印 `DEV_WORKFLOW_UNATTENDED` が届かず、その画面を誰も見ていないので、子が主の返事待ちで止まっても誰も気づかない）。develop の外で住人が別のセッションを起こすときの印の渡し方は、この要件の範囲に入れない（#1123）。

**回し方（別セッション方式）**: 本体は `epic-dispatch.sh launch` で子ごとに起動部品（Orca か tmux）の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。再開時も、依存が解けた open の子を、最新の `回し方:` の部品名を付けた `launch` に渡し（上の段落のとおり）、起動済みの子は `launch` の `skipped` で見分ける（同じ子を二重に起動しない）。本体は `launch` が `launched` / `skipped` を出した子を動いている子とし、`epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める。`closed` なら閉じた子ごとに `state_reason` を読み、`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントして依存グラフを読み直し、解けた子を件数にかかわらず `launch` する。`completed` 以外ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子を起動してはならず（MUST NOT）、ユーザーに報告する。そのあと残りの動いている子で再び `wait` する。`timeout` なら、子 issue もエピックも読まず、主に報告もせず、直前と同じ引数の `wait` を 1 回掛け直してターンを終える（要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」）。子が記録と印を残さずに自分のタブでユーザーに質問して止まっている場合は、親が気づけないことを書く（SHALL）。`wait` の `error` と `launch` の `failed` はユーザーに報告して止まる。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子セッションのモデルは `epic-dispatch.sh launch` が起動時に `cld --model` で指定し、既定は `opus` で環境変数 `EPIC_DISPATCH_MODEL` で変えられること（Claude Code の既定モデルは子に効かないこと）、コマンド部分（既定 `cld`）は環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ、Orca に設定したコマンドはハーネスから読めないので（tmux の部品はこの環境変数のコマンドをそのまま打ち込む）Orca 側のコマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変えることを書く（SHALL）。子セッションは `cld` が付ける `--dangerously-skip-permissions` で動き許可の確認画面が出ないこと（`epic-dispatch.sh` が足すのは `--model` だけであること）、マージを止めているのは develop と pr-review-gate の規則と hooks であることを書く（SHALL）。本体は子の PR を `gh pr merge` や merge API で直接マージしてはならない（MUST NOT）。子の PR のマージは、子セッションの中の人の承認か自動マージの処理（`.github/workflows/auto-merge.yml`）が行い、`human-merge` の付いた子の PR は、本体が要件「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」の手順で判断の印を付けたときに限って自動マージの処理がマージすることを書く（SHALL）。

**回し方（サブエージェント方式）**: 今までどおり blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと。本体が W を `isolation: "worktree"` で spawn して用意し、W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。

どちらの経路でも、スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった新しい問題は新しい子 issue として追加する。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

この要件の入力は、`/develop <エピック番号>` で渡される記録先の issue、`scripts/epic-dispatch.sh route` の出力（`orca`・`tmux`・`subagent`・`nested`）、エピックの `回し方:` で始まるコメント、`wait` の出力の 1 行（`closed`・`done`・`timeout`・`stopped`・`unrecorded`・`error`）、`launch` の出力（`launched`・`skipped`・`failed`・`deferred`）である。拾いたい誤りは、`route` や最新の `回し方:` を読まずに経路を選び直すこと、`nested` を受けたのにエピックを展開すること、出力の 1 行を取り違えて待ちを終えたり子を起こしたりすること、子が全部マージされただけでエピックを閉じることである。次は通してよく、この要件では止めない: `回し方:` のコメントが無い新しいエピックで `route` から経路を決めること／`timeout` で起こされたとき何もせず再び待つこと／子が記録を残さずに自分のタブで質問して止まったとき、親が検知できないこと（手順書にその旨が書かれている）。手順書の読み方の揺れ（すり抜ける入力）が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: エピックの 4 節が存在する
- **WHEN** `references/epic.md` の「エピックの扱い」節を読む
- **THEN** 条件・作り方・回し方・完了条件の 4 つが揃い、完了条件に「子が全部マージされただけでは閉じない」が書かれている

#### Scenario: 子は並列に worktree 分離で起こす
- **WHEN** エピックの回し方を読む
- **THEN** サブエージェント方式として、blocked されていない子から `isolation: "worktree"` で 1 ループを並列に起こすことが書かれ、どちらの経路でも新しい問題は子の中で直さず新しい子 issue にすることが書かれている

#### Scenario: 回し方に経路の振り分け条件が書かれている
- **WHEN** エピックの回し方を読む
- **THEN** `epic-dispatch.sh route` の出力で経路を決めること、`orca` になる条件（`orca` が PATH にある・本体が Orca 管理のワークツリーにいる）、`tmux` になる条件（Orca 管理外で `TMUX` が空でなく `tmux` が PATH にある）、環境変数 `EPIC_DISPATCH_LAUNCHER` で固定できること、どれでもなければサブエージェント方式で進むこと、経路を最初の開始時に 1 回決めて途中で変えないこと、再開時は `回し方:` のコメントから経路を引き継ぐこと、unmanned はサブエージェント方式のままであることが書かれている

#### Scenario: 別セッション方式の本体は wait の出力で次を決める
- **WHEN** 別セッション方式の本体の手順を読む
- **THEN** `launch` で子を起動し、`wait` を `run_in_background: true` で起動して待つこと、`closed` で `state_reason` を読み `completed` なら `子 #N マージ → 残り k 件` をコメントして解けた子を `launch` し、それ以外なら `見送り` とコメントして後続を起動せず報告すること、`timeout` で子を調べ直さず報告もせずに同じ `wait` を掛け直すこと、子のタブでの質問は検知できないこと、本体が子の PR を直接マージせず、`human-merge` の付いた子の PR は本体が判断の印を付けたときに限って自動マージの処理がマージすることが書かれている

#### Scenario: 別セッション方式に子セッションのモデルの決め方が書かれている
- **WHEN** 別セッション方式の説明を読む
- **THEN** 子セッションのモデルは `epic-dispatch.sh launch` が `cld --model` で指定すること、既定が `opus` であること、`EPIC_DISPATCH_MODEL` で変えられること、Claude Code の既定モデルが何であっても子は指定したモデルで起動すること、コマンド部分を `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ Orca 側のコマンドを変えたら合わせて変えること、`--dangerously-skip-permissions` を付けるのは `cld` であることが書かれている

#### Scenario: tmux と記録したエピックを Orca 管理下で再開しても tmux で起動する
- **WHEN** 最新の `回し方:` が `回し方: tmux` のエピックを、Orca 管理のワークツリーかつ `TMUX` が空でない環境で再開し、依存が解けた子 12 を起動する
- **THEN** 本体は `route` を呼ばず、`EPIC_DISPATCH_LAUNCHER=tmux` を付けて `launch` を呼び、子 12 の記録の `launcher` は `tmux` で、`orca worktree create` は呼ばれない

#### Scenario: 記録した部品が今の環境で使えなければ報告して止まる
- **WHEN** 最新の `回し方:` が `回し方: tmux` のエピックを、`TMUX` が空の環境（Orca 管理のワークツリーであってもよい）で再開し、`EPIC_DISPATCH_LAUNCHER=tmux` を付けた `launch` が exit 1 で終わる
- **THEN** 本体はサブエージェント方式にも Orca の部品にも振り替えず、stderr を添えて主に報告して止まる

#### Scenario: Orca と記録したエピックを tmux だけの環境で再開すると止まる
- **WHEN** 最新の `回し方:` が `回し方: Orca` のエピックを、`orca` が PATH に無く `TMUX` が空でない環境で再開する
- **THEN** `EPIC_DISPATCH_LAUNCHER=orca` を付けた `launch` は `orca is not on PATH` で exit 1 になり、本体は tmux の部品で起動せず、報告して止まる

#### Scenario: Orca がある環境の channel の本体がエピックを回す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる channel の本体が `/develop <エピック番号>` を始める
- **THEN** 本体は `route` を呼ばず、エピックに `回し方: サブエージェント（channel モード）` とコメントしてサブエージェント方式で回し、別の Claude Code セッションを起こさない

#### Scenario: epic.md の回し方が起動部品の差し替えとして書かれている
- **WHEN** develop の `references/epic.md`「エピックの扱い」→「回し方」を読む
- **THEN** 起動・待ち・閉じた子・止まった子・片付け・完了の手順は 1 本で書かれ、Orca の部品・tmux の部品・サブエージェント方式のどれで起こすかによって違う点だけが部品ごとの欄に書かれており、「Orca 経路」と「サブエージェント方式」を別々の手順として二重に書いていない。サブエージェント方式は状態の記録を書かない、と書かれている

### Requirement: epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` を持たなければならない（MUST）。どのサブコマンドも LLM を呼んではならない（MUST NOT）。

`route <child>...` は stdout にちょうど 1 行を出して exit 0 で終わらなければならない（MUST）。判定は次の順で、最初に当たったものを出す: (1) エピックの子のセッション（環境変数 `EPIC_DISPATCH_PARENT_EPIC` があるか、今のワークツリーを `worktree` に持つ状態の記録がある）なら `nested`、(2) 引数の子が 0 件なら `subagent`、(3) 環境変数 `EPIC_DISPATCH_LAUNCHER` が `orca` か `tmux` ならその値（部品が使えるかを確かめ、使えなければ stderr に理由を出して `subagent`）、(4) Orca の部品の `here` が exit 0（`orca` が PATH にあり、今いるディレクトリが Orca 管理のワークツリー）なら `orca`、(5) 環境変数 `TMUX` が空でなく `tmux` コマンドが PATH にあれば `tmux`、(6) それ以外は `subagent`。`EPIC_DISPATCH_LAUNCHER` が `orca`・`tmux`・空のどれでもなければ stderr に使い方を出して exit 1 で終わる。子の番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。`launch` と `adopt` は、同じ順の (3)〜(5) で使う起動部品を決め、決められなければ exit 1 で終わる。

`launch [--note <text>] [--base <branch>] <epic> <child>...` は、起動部品が Orca のとき、次の順で呼び出さなければならない（MUST。tmux の部品のときの呼び出しは capability `dev-workflow-epic-state` の要件「tmux の部品は…」が決める。部品の選び方は要件「記録の launcher ごとに起動部品を選ぶ」）: `orca worktree current --json`（今の repo の `repoId` を得る）→ `git rev-parse --show-toplevel` → `git fetch origin <base>` → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` → 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --json` → 子の端末を用意する（`orca terminal list --worktree path:<子> --json` で端末を数え、0 個のときだけ `orca terminal create --worktree path:<子> --command <cmd> --json` で作る。ちょうど 1 つのときは作らずにその端末を使う。詳細は要件「launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ」）→ `orca terminal wait --terminal <handle> --for tui-idle --timeout-ms <ready> --json` → `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json`。worktree create に `--agent` と `--prompt` を渡してはならない（MUST NOT。`--agent` で起動すると子セッションのモデルを指定できず Claude Code の既定モデルで動くため。`--prompt` は Orca 1.4.209 では指示が子の入力欄に届かず、送信と併用すると指示が 2 回届くおそれがあるため）。`<子>` は worktree create の JSON 出力の `result.worktree.path` とする（MUST）。`<cmd>` は `<claude-cmd> --model <model>` で（`--dangerously-skip-permissions` などの許可に関わる引数は付けてはならない（MUST NOT）。付けるのは `<claude-cmd>` 側に任せる）、`<claude-cmd>` の既定は `cld` で環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で変えられ、クォートせずそのまま置く（MUST。`--command` の文字列は Orca が開いたログインシェルに打ち込まれるのでシェル関数も解決され、`cld-account b` のような引数付きも書けるため）。`<model>` はシェルに打ち込まれても 1 語のまま渡るよう単一引用符で囲む（MUST。`opus[1m]` のような値がグロブとして解釈されないため）。`<model>` の既定は `opus` で、環境変数 `EPIC_DISPATCH_MODEL` で変えられる（MUST）。`<handle>` は、端末を作ったときは terminal create の JSON 出力の `result.terminal.handle`、使い回したときはその端末のハンドルとする（MUST）。`<ready>` の既定は 60000（ミリ秒）で環境変数 `EPIC_DISPATCH_READY_TIMEOUT_MS` で、`<submit>` の既定は 30（秒）で環境変数 `EPIC_DISPATCH_SUBMIT_WAIT` で変えられる（SHALL）。`<親>` は `git rev-parse --show-toplevel` で求めた親ワークツリーの絶対パスで、親の指定は create と set の両方で `path:` を使わなければならない（MUST。`worktree:<id>` は set で `selector_not_found` になるため）。`<base>` の既定は `main` で、環境変数 `EPIC_DISPATCH_BASE` で既定を変えられ、`--base` が環境変数より優先する（MUST）。`<prompt>` は `/develop #<N>` で始まり、エピック番号を含み、`--note` があればその文を含む（SHALL）。子を `launched <N>` とするのは、worktree create が exit 0 で終わり、子のワークツリーのパスが取れ、端末を用意でき（terminal create が exit 0 で終わりハンドルが取れた、または使い回した端末が Claude Code になった）、`terminal wait` が exit 0 で終わり、`terminal send` が exit 0 で終わってその JSON 出力のどこかの `stages` 配列に `turn_started` が含まれるときだけでなければならない（MUST）。どれか 1 つでも満たさなければ `failed <N>` とし（MUST）、子のワークツリーのパスが取れていて、端末を作る経路でハンドルが取れていなければ（terminal create の失敗を含む）、端末を手で起動し直すための `orca terminal create --worktree path:<子> --command <cmd> --json` を stderr に出すに続けて、最初の指示を送るための `orca terminal send --terminal <作り直した端末のハンドル> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出す（SHALL。ワークツリーは残るので、再実行ではその子は `skipped <N>` になり端末が作られないため）。端末を用意できたあと（`terminal wait` か `terminal send` の段）で失敗し、ハンドルが取れていれば、指示を手で送り直すための `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出し、あわせて「送る前に `orca terminal read --terminal <handle>` で入力欄とターンの状態を確かめる」旨の案内を出す（SHALL。送信が非 0 やターン未観測で終わっても指示が届いていることがあり、確かめずに送ると 2 回届くため）。`terminal send` の JSON 出力に送り直し用の ID（キー `retryRequestId` または `retryRequest` の文字列値）があれば、送り直しのコマンドに `--retry-request <id>` を付ける（SHALL）。ワークツリーは残すので、再実行ではその子は `skipped <N>` になり、指示を送り直さない（SHALL）。一覧に、同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出さなければならない（MUST。再開時や取り違えで同じ子を二重に起動しないため）。`orca` が PATH に無いときは何も呼ばずに exit 1 で終わり、`orca worktree current`・`git fetch`・`orca worktree set`・`orca worktree list` のどれかが失敗したとき（`jq` が無くて一覧を読めないときを含む）は子を 1 件も作らずに exit 1 で終わらなければならない（MUST）。stdout には子ごとに `launched <N>`・`skipped <N>`・`failed <N>` のどれか 1 行だけを出し、`orca` 自身の出力は stderr に流す（SHALL）。1 件の失敗で残りの子の起動を止めず、`failed` が 0 件なら exit 0、1 件でもあれば exit 1 で終わる（MUST）。

`wait [--interval <sec>] [--timeout <sec>] <child>...` は、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` で state を確かめるポーリングを繰り返し、stdout にちょうど 1 行を出して終わらなければならない（MUST）。子ごとの結果は、出力が `closed` なら閉じている、`open` なら開いている、`gh` が非 0 で終わったか出力がそれ以外（空文字を含む）なら失敗とする（MUST）。1 件以上の子が閉じていれば `closed <N>...`（閉じていた子の番号）で exit 0、上限時間に達したら `timeout <N>...`（閉じていない子の番号）で exit 2、失敗したポーリングが 3 回続いたら `error gh <N>...`（3 回目で失敗した子の番号）で exit 1 で終わる（MUST）。失敗したポーリングとは、1 件以上の子が失敗し、かつ閉じた子が 1 件も無いポーリングを言い、一部の子だけが失敗してほかの子が `open` の場合も含む（MUST）。失敗の無いポーリングがあれば数え直す（SHALL）。閉じた子がいるポーリングでは、ほかの子の失敗より `closed` を優先する（SHALL）。間隔と上限は秒で、間隔の既定は 300、上限の既定は要件「上限を明示しない wait は親の会話キャッシュの有効期限で上限を決める」が決める（2700 か 21600）。環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する（MUST）。ポーリングのあとで経過時間が上限に達しているか、経過時間と間隔の和が上限を超えるなら、眠らずに `timeout` で終わる（MUST。`--timeout 0` は間隔によらず 1 回だけ確かめて終わる）。子が 0 件、番号が数字でない、間隔・上限が非負整数でないときは stderr に使い方を出して exit 1 で終わる（SHALL）。

この要件の守備範囲で入力として扱うのは、本体（LLM）が依存グラフから求めた子の番号と、`references/epic.md` の手順どおりに付けるフラグである。人が手で打つことは想定しない。引数の検査で拾う誤りは、番号の取り違えで引数が空になること、`#12` のように番号に記号が付くこと、フラグ値の打ち間違いである。数字でさえあれば、存在しない issue 番号・重複した番号・blocked されている子の番号は通してよく（`route` は依存を検証しない。存在しない番号は `wait` の失敗したポーリングとして数えられ `error` で表に出る）、非常に大きい `--timeout` も通してよい。検査をすり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。`EPIC_DISPATCH_READY_TIMEOUT_MS` と `EPIC_DISPATCH_SUBMIT_WAIT` は非負の整数でなければ stderr に使い方を出し、子を 1 件も作らずに exit 1 で終わる（SHALL。`--interval` と同じ扱いで、上限は設けない）。`EPIC_DISPATCH_MODEL` か `EPIC_DISPATCH_CLAUDE_CMD` が設定されていて空文字のときも stderr に使い方を出し、子を 1 件も作らずに exit 1 で終わる（SHALL。空でない値はそのまま使い、モデル名やコマンドとしての正しさは検査しない）。worktree create の JSON 出力の `result.worktree.path` と terminal create の JSON 出力の `result.terminal.handle` は 2026-09-25 の実機での出力の形のとおりと信じ、`terminal send` の JSON 出力の `stages` 配列と `turn_started` の語は、2026-09-24 の実機での出力の形のとおりと信じ、読めないときは `failed` として表に出すだけで、形の変化そのものの検知は範囲外とする。`orca worktree list --json` の出力は確かめた形（`.result.worktrees[]` の `repoId`・`linkedIssue`・`isArchived`）のとおりと信じ、形が変わったときの検知は範囲外とする。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、呼び出しの引数と順序、stdout の 1 行と exit code を確かめなければならない（MUST）。テストの途中に素の `[[ ]]` を置いてはならない（MUST NOT。bash 3.2 では偽でも素通りする）。

#### Scenario: orca が無く tmux の中でもない環境ではサブエージェント方式になる
- **WHEN** `orca` が PATH に無く、環境変数 `TMUX` が空の環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: orca はあるが Orca 管理外のワークツリーで tmux の中でもなければサブエージェント方式になる
- **WHEN** `orca` が PATH にあり `orca worktree current` が exit 1 を返し、環境変数 `TMUX` が空の環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: 並列にできる子が 2 件でも Orca 管理下なら Orca 経路になる
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: launch は fetch してから path: で親を渡して子を作る
- **WHEN** 一覧に子のワークツリーが無く、子のワークツリーの端末が 0 個のスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 呼び出しの記録は `orca worktree current --json`、`git rev-parse --show-toplevel`、`git fetch origin main`、`orca worktree set --worktree path:<親> --issue 400`、`orca worktree list --json`、子ごとに `orca worktree create`（`--name issue-<N> --issue <N> --base-branch origin/main --parent-worktree path:<親> --json`。`--agent` も `--prompt` も含まない）、`orca terminal list --worktree path:<子> --json`、`orca terminal create --worktree path:<子> --command "cld --model 'opus'" --json`、`orca terminal wait --terminal <handle> --for tui-idle`、`orca terminal send --terminal <handle> --text "/develop #<N> ..." --enter --wait-submit 30 --json` を子 11・子 12 の順に繰り返し、stdout は `launched 11` と `launched 12`、exit 0

#### Scenario: 子セッションのモデルを環境変数で変えられる
- **WHEN** `EPIC_DISPATCH_MODEL='opus[1m]'` のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `cld --model 'opus[1m]'`、stdout は `launched 11`、exit 0

#### Scenario: モデルの環境変数が空なら子を作らない
- **WHEN** `EPIC_DISPATCH_MODEL=` （空文字）のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca worktree create` は呼ばれず、exit 1

#### Scenario: 起動コマンドを環境変数でそのまま差し替えられる
- **WHEN** `EPIC_DISPATCH_CLAUDE_CMD='cld-account b'` のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `cld-account b --model 'opus'`、stdout は `launched 11`、exit 0

#### Scenario: 起動コマンドの環境変数が空なら子を作らない
- **WHEN** `EPIC_DISPATCH_CLAUDE_CMD=` （空文字）のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca worktree create` は呼ばれず、exit 1

#### Scenario: 端末を作れなければ送らずに failed で端末の作り直しのコマンドを出す
- **WHEN** 子 11 の `orca terminal create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 子 11 には `orca terminal wait` も `orca terminal send` も呼ばれず、stderr には子 11 のワークツリーのパスと `cld --model` を含む `orca terminal create` のコマンドと、`/develop #11` を含む `orca terminal send` のコマンドが出て、stdout は `failed 11` と `launched 12`、exit 1

#### Scenario: ハンドルが取れなければ送らずに failed
- **WHEN** 子 11 の terminal create の JSON 出力に `result.terminal.handle` が無いスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 子 11 には `orca terminal wait` も `orca terminal send` も呼ばれず、stdout は `failed 11` と `launched 12`、exit 1

#### Scenario: 子のワークツリーのパスが取れなければ端末を作らずに failed
- **WHEN** 子 11 の worktree create の JSON 出力に `result.worktree.path` が無いスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** 子 11 には `orca terminal create` が呼ばれず、stdout は `failed 11`、exit 1

#### Scenario: 送信が失敗したら failed で送り直しのコマンドを出す
- **WHEN** 子 11 の `orca terminal send` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** stdout は `failed 11` と `launched 12`、stderr には子 11 のハンドルと `/develop #11` を含む `orca terminal send` のコマンドが出て、exit 1

#### Scenario: 送り直し用の ID があれば送り直しのコマンドに付ける
- **WHEN** 子 11 の `orca terminal send` が非 0 で終わり、JSON 出力に `retryRequestId` の値 `rq-1` があるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stdout は `failed 11`、stderr の送り直しのコマンドに `--retry-request rq-1` が付き、`orca terminal read` で確かめる案内が出て、exit 1

#### Scenario: 時間の環境変数が整数でなければ子を作らない
- **WHEN** `EPIC_DISPATCH_SUBMIT_WAIT=abc` のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca worktree create` は呼ばれず、exit 1

#### Scenario: ターンの開始を確かめられなければ failed
- **WHEN** 子 11 の `orca terminal send` が exit 0 で終わるが、JSON 出力の `stages` に `turn_started` が無い（`input_accepted` だけ）スタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stdout は `failed 11`、exit 1

#### Scenario: 起動完了待ちが失敗したら送らずに failed
- **WHEN** 子 11 の `orca terminal wait` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** 子 11 に `orca terminal send` は呼ばれず、stdout は `failed 11`、exit 1

#### Scenario: 起動完了待ちと送信の観測時間を環境変数で変えられる
- **WHEN** `EPIC_DISPATCH_READY_TIMEOUT_MS=5000`・`EPIC_DISPATCH_SUBMIT_WAIT=7` のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal wait` は `--timeout-ms 5000`、`orca terminal send` は `--wait-submit 7` で呼ばれる

#### Scenario: 起点のブランチを変えられる
- **WHEN** `EPIC_DISPATCH_BASE=develop` のスタブ環境で `epic-dispatch.sh launch --base trunk 400 11` を実行する
- **THEN** `git fetch origin trunk` と `--base-branch origin/trunk` で呼ばれる

#### Scenario: 起動済みの子は作らない
- **WHEN** 一覧に同じ `repoId` で `linkedIssue` が 11 の archive されていないワークツリーがあるスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 子 11 の `orca worktree create` は呼ばれず、stdout は `skipped 11` と `launched 12`、exit 0

#### Scenario: fetch に失敗したら子を作らない
- **WHEN** `git fetch` が失敗するスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `orca worktree create` は 1 回も呼ばれず、exit 1

#### Scenario: orca が無く tmux の中でもない環境では launch は何も呼ばない
- **WHEN** `orca` が PATH に無く、環境変数 `TMUX` が空で、`EPIC_DISPATCH_LAUNCHER` が空の環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `git` も `gh` も呼ばれず、exit 1

#### Scenario: 子が閉じたら closed で終わる
- **WHEN** 子 12 が 2 回目のポーリングから `closed` を返すスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11 12` を実行する
- **THEN** stdout は `closed 12` の 1 行で exit 0

#### Scenario: 上限時間に達したら timeout で終わる
- **WHEN** どの子も `open` を返すスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 0 11 12` を実行する
- **THEN** stdout は `timeout 11 12` の 1 行で exit 2

#### Scenario: 間隔は sleep に渡される
- **WHEN** 3 回目のポーリングで子が閉じるスタブ環境で `epic-dispatch.sh wait --interval 7 --timeout 100 11` を実行する
- **THEN** `sleep 7` が 2 回呼ばれ、stdout は `closed 11` で exit 0

#### Scenario: gh が失敗し続けたら error で終わる
- **WHEN** `gh` が常に失敗するスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11` を実行する
- **THEN** 3 回のポーリングのあと stdout は `error gh 11` の 1 行で exit 1

#### Scenario: 一部の子だけが失敗し続けても error で終わる
- **WHEN** 子 11 の `gh` が常に失敗し、子 12 は常に `open` を返すスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11 12` を実行する
- **THEN** 3 回のポーリングのあと stdout は `error gh 11` の 1 行で exit 1

### Requirement: エピックの並列起動は 1 段で止める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子セッションを起動する端末のコマンドの先頭に `EPIC_DISPATCH_PARENT_EPIC=<epic>` を置かなければならない（MUST。`<epic>` は `launch` に渡したエピック番号）。そのうしろ、`<cmd>` の前には `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` を置く（MUST。`<値>` の既定と上書きは要件「時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める」が定める）。コマンド全体は `EPIC_DISPATCH_PARENT_EPIC=<epic> CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値> <cmd> --model <model>` の形になり、端末を作れなかった子について stderr に出す `orca terminal create --command ...` の作り直しのコマンドにも同じ前置きが入る（SHALL）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の出力の規定、`<cmd>` の形の規定、および Scenario「EPIC_DISPATCH_MODEL…」「EPIC_DISPATCH_CLAUDE_CMD…」の `--command` の値に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

環境変数 `EPIC_DISPATCH_PARENT_EPIC` が空でない環境では:

- `route <child>...` は、子の番号の検査（数字でなければ使い方を出して exit 1）のあと、子の件数・`orca` の有無・`orca worktree current` の結果によらず stdout に `nested` の 1 行を出して exit 0 で終わらなければならない（MUST）。`orca` を呼んではならない（MUST NOT）
- `launch` は、引数の検査（既存の使い方の誤り）のあと、`orca` と `git` を 1 つも呼ばず、stderr に親エピックの番号と展開しない旨を出して exit 1 で終わらなければならない（MUST。子ワークツリーを作らない）。stdout には何も出さない（SHALL）
- `wait` の振る舞いは変えない（SHALL）

develop の `references/epic.md`「エピックの扱い」は次を規定しなければならない（MUST）。

- **エピックの子を外す**: 本体は依存グラフから求めた blocked されていない子のうち、sub-issue を持つ子（`gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` が 1 以上。`null` や空は 0 とみなす）をエピックとして外し、`route`・`launch`・サブエージェント方式のどれにも渡してはならない（MUST NOT）。経路が `nested` でないと確定したら（`route` が `nested` 以外を返したとき。`route` を呼ばない unmanned と、`回し方:` のコメントから経路を引き継いだ再開を含む）、外した子ごとにエピックへ `後で別に起動するエピック: #N` と 1 行コメントする（MUST）。再開時に `回し方:` のコメントから経路を引き継いだ場合も、`launch` に渡す前に同じ確認で外す（MUST）
- **`nested` を受けたセッション**: `route` が `nested` を返したら、そのセッションはエピックを展開してはならない（MUST NOT。Orca 経路もサブエージェント方式も使わない）。親エピック（`EPIC_DISPATCH_PARENT_EPIC` の番号）と自分の issue に `後で別に起動するエピック: #<自分の issue>` とコメントし、ユーザーに後で `/develop #<自分の issue>` を別に起動して回すと伝えて止まる（MUST）。自分の issue を閉じてはならない（MUST NOT）。`launch` が stderr に展開しない旨を出して exit 1 で終わったときも同じに扱い、「親ワークツリーで開き直す」とは報告しない（MUST NOT）
- **親の待ち受け**: Orca 経路の本体は、`closed` で起こされたときの確認で、エピックに `後で別に起動するエピック: #N` の行がある子を動いている子から外す（MUST）。`timeout` で起こされたときはこの確認をしない（SHALL。手順 5 は同じ `wait` を掛け直すだけで、子エピックは手順 2 の前に `launch` に渡す前に外している。要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」）
- **親の完了報告**: 動いている子が無くなったときの本体の報告（エピックへのコメントとユーザーへの報告）に、エピックに記録した `後で別に起動するエピック:` の番号をすべて載せる（MUST）。子エピックが閉じるまで親エピックの完了条件は満たされないので、親エピックを閉じてはならない（MUST NOT）

この要件の守備範囲で入力として扱うのは、`launch` が子の端末のコマンドに前置きした `EPIC_DISPATCH_PARENT_EPIC`（子セッションの Claude Code とその Bash・サブエージェントに引き継がれる）、本体が依存グラフから求めた子の番号ごとの `sub_issues_summary.total`、エピックのコメントの `後で別に起動するエピック:` で始まる行である。拾いたい誤りは、並列起動された子のセッションが自分の issue をエピックとして孫のワークツリーとセッションを作ることである。次は通してよく、この要件では止めない: `EPIC_DISPATCH_PARENT_EPIC` の値は空でなければ数字かどうかを検査しない／人が手で `EPIC_DISPATCH_PARENT_EPIC` を付けて起動したセッションも `nested` になる／sub-issue を持たず本文で子を列挙しているだけのエピックは事前確認を通り、Orca 経路で起動された子なら子のセッションの `route` で止まり、サブエージェント方式で起こされた子（変数が無い）は止まらない／`回し方:` のコメントからサブエージェント方式を引き継いだ子エピックのセッションはスクリプトでは止まらない／この変更の前に起動された子セッションには変数が無く従来どおり展開しうる／`EPIC_DISPATCH_CLAUDE_CMD` が前置きの代入を受け付けない形（`exec` で始まる文字列など）のときは値が渡らない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`EPIC_DISPATCH_PARENT_EPIC` の前置き、`route` の `nested`、`launch` の拒否、`references/epic.md` の上の記述を確かめなければならない（MUST）。

#### Scenario: launch は子の端末のコマンドに親エピックの番号を前置きする
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` の無い環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=420 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'` である

#### Scenario: 端末の作り直しのコマンドにも前置きが入る
- **WHEN** `orca terminal create` が失敗する環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** stderr の作り直しのコマンドは `--command 'EPIC_DISPATCH_PARENT_EPIC=420 ` を含む（値全体が単一引用符で囲まれる）

#### Scenario: 並列起動された子のセッションでは route が nested を返す
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` で、`orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `nested` の 1 行で exit 0、`orca` は呼ばれない

#### Scenario: 並列起動された子のセッションでは launch が子ワークツリーを作らない
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `epic-dispatch.sh launch 460 11 12` を実行する
- **THEN** exit 1、stdout は空、`orca` と `git` は 1 回も呼ばれず、stderr に `420` を含む理由が出る

#### Scenario: 並列起動された子のセッションでも引数の誤りは使い方を出す
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `epic-dispatch.sh route '#11'` を実行する
- **THEN** stderr に使い方が出て exit 1

#### Scenario: epic.md に子エピックの扱いと完了報告が書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** sub-issue を持つ子を外して `後で別に起動するエピック: #N` とコメントすること、`route` の `nested` を受けたら展開せず親エピックと自分の issue にコメントして止まること、`nested` と同じく `launch` の拒否でも止まり「親ワークツリーで開き直す」と報告しないこと、`closed` で起こされたときの確認でその行がある子を待つ対象から外すこと（`timeout` で起こされたときの確認とは書かれていない）、完了報告に `後で別に起動するエピック:` の番号を載せることが書かれている

### Requirement: エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する
develop の `references/epic-child-stop.md` は、エピックの子のセッションが主の返事を待って止まるときの手順を、`references/epic.md` は、Orca 経路の親が `stopped` を受けたときの手順を規定しなければならない（MUST）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」のうち、子が自分のタブでユーザーに質問して止まっている場合は親が気づけないと書く規定に優先する（記録を残さずに止まった子に限って気づけないと書く）。

**子の側**:

- 対象は `scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッションに限る（MUST）。それ以外のセッションでは記録も印も付けない（MUST NOT）
- 主の返事を待って止まるときは、待ち方で順序を分ける（MUST）。どちらでも印を記録より先に付けてはならない（MUST NOT）
  - **本文で質問してターンを終えるとき**（`needs-approval` を付けた保留で、質問ツールを使わずにターンを終えるときを含む）: ターンを終える前に記録先の issue へ記録を 1 件投稿し、続けてそのターンの最後のツール呼び出しとして `scripts/epic-dispatch.sh mark stopped <記録先の issue 番号>` を呼ぶ。主の返事は次のターンで届くので、そのターンの最初のツール呼び出しとして `scripts/epic-dispatch.sh mark resumed <記録先の issue 番号>` を呼ぶ
  - **質問ツール（AskUserQuestion）の中で待つとき**: 質問ツールを呼ぶ前に記録を投稿し、続けて `mark stopped` を呼んでから質問ツールを呼ぶ。質問ツールは回答が来るまで同じターンの中で待つので、`mark stopped` は最後のツール呼び出しにならない。回答を受けたら、次のツール呼び出しとして `mark resumed` を呼ぶ
- 背景のタスクの終わりを待ってターンを終えるときは記録も印も付けない（MUST NOT）
- 記録は、1 行目を識別用の `^子の停止: 主の返事待ち$` に完全一致させ、2 行目以降は要件「エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く」の項目名と並びで書く（MUST）。止まるたびに新しいコメントを投稿し、最新の 1 件を正とする（SHALL）
- 「保留で止まるときの引き継ぎ」を書く場面では、引き継ぎを先に投稿し、そのあとに記録を投稿して、再開に要る途中経過として引き継ぎのコメントの URL を書く（MUST）。引き継ぎの書式（1 行目 `引き継ぎ: 主の返事待ち`）は変えない
- `mark stopped` の出力が `marked` なら何もせず、`skipped` で始まる（`skipped <N> no-workspace`・`skipped <N> not-linked`）か `failed` なら、親が見張る記録に印が付いていないので主への質問に「親に止まったことが伝わっていない」と 1 行添える（SHALL）。`skipped` を何もしない側に置いてはならない（MUST NOT。子の状態の記録が無い・別の子の記録のときも親の `wait --watch-stopped` は止まりを読めず、主が子のタブを見るまで気づかないため）。`mark resumed` は出力によらず止まらない（SHALL）

**親の側（Orca 経路）**:

- 動いている子を待つ `wait` には `--watch-stopped` を付ける（MUST）
- `stopped <N>...` で起こされたら、止まった子ごとに子 issue の最新の `子の停止: 主の返事待ち` のコメントを読み、子の番号・止まった理由・推奨・コメントの URL をユーザーに報告し、残りの動いている子（止まった子を含む）で再び `wait` する（MUST）。止まった子を動いている子から外してはならない（MUST NOT。閉じたことを検知できなくなるため）。止まった子への返事の仕方は #1034 で決める
- `wait` の出力の説明を、`closed`・`done`・`stopped` の 1〜3 行とする（MUST）
- 記録を残さずに子のタブで質問して止まった子は、手順 5（`timeout` で起こされたとき）でも検知できないことを手順 5 に注記として残す（SHALL）。ユーザーに子のタブも見るよう伝えるのは、手順 1 の `launch` のあと最初に手順 2 で待ちに入る通知で一度だけとし、手順 5 の掛け直しのたびには伝えない（SHALL。手順 5 は主に発言を書かないため。要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」）
- 端末の入力待ちが続いたことで子の止まりを推定する手順を書いてはならない（MUST NOT。誤検知が多いため。根拠は change `epic-child-stop-signal` の design.md）

develop の手順書（`skills/develop` 配下）に `orca` のサブコマンドを書いてはならない（MUST NOT。既存の規定どおり、`orca` を呼ぶのは Orca の起動部品 `epic-launch-orca.sh` だけ）。

この要件の守備範囲で入力として扱うのは、子のセッションでは `epic-dispatch.sh route`（子の番号なし）の出力と `mark` の出力、主の返事を待つかどうかの子自身の判断（本文で質問するか、質問ツールを使うか、背景のタスクを待つだけか）、記録先の issue 番号で、親のセッションでは `wait` の出力と子 issue のコメント（1 行目が `子の停止: 主の返事待ち` の最新の 1 件）である。拾いたい誤りは、エピックの子が主の返事を待っているのに記録も印も残さずに止まること、印が記録より先に付いて親が記録の無い止まりを読むこと、質問ツールで待つ子が回答を受けたあとも止まった印を残すこと、エピックの子でないセッションが読む者のいない記録を残すこと、親が止まった子を動いている子から外して閉じたことを検知できなくなること、`mark stopped` が印を付けられなかった（`skipped` か `failed`）のに子が主に伝えずに止まることの 6 つである。次は通ってよく、この要件では止めない: 記録の項目の値の長さと改行の違い（値が複数行に続くこと）／止まるたびに記録が増えること（最新の 1 件を正とする）／保留の場面で引き継ぎと記録の 2 件のコメントが並ぶこと／主が子のタブで先に答えて、親が既に再開した子の `stopped` を受けること（親は記録を読んで報告するだけで、返事の仕方は #1034 で決める）／子が記録を書かずに止まり、親が気づかないこと（入力待ちからの推定は入れない。`timeout` で起こされても気づかない）。記録の中身（理由・推奨・リスクの正しさ）を確かめることと、手順を守らない子を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 子が止まるときの記録と印の手順が書かれている
- **WHEN** `references/epic-child-stop.md` のエピックの子が止まるときの手順を読む
- **THEN** `route` が `nested` を返すセッションに限ること、1 行目 `子の停止: 主の返事待ち` の記録を投稿してから `mark stopped` を呼ぶこと、本文で質問してターンを終えるときは `mark stopped` をそのターンの最後のツール呼び出しにすること、質問ツールで待つときは記録・`mark stopped`・質問ツールの順に呼んで回答のあとに `mark resumed` を呼ぶこと、本文で質問したときは返事を受けたターンの最初に `mark resumed` を呼ぶこと、引き継ぎを書く場面では引き継ぎを先に投稿することが書かれている。記録の 2 行目以降の項目名と並びは要件「エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く」のシナリオで確かめる

#### Scenario: 印が付かなかった出力では主に 1 行添えることが書かれている
- **WHEN** SKILL.md が指すエピックの子の停止の手順（`references/epic-child-stop.md`）で `mark stopped` の出力の扱いを読む
- **THEN** `marked` なら何もしないこと、`skipped` で始まる出力（`skipped <N> no-workspace`・`skipped <N> not-linked`）と `failed` では主への質問に「親に止まったことが伝わっていない」と 1 行添えることが書かれ、`skipped` を何もしない側に置く文が無い

#### Scenario: 親が stopped を受けたときの手順が書かれている
- **WHEN** `references/epic.md` の Orca 経路の手順を読む
- **THEN** `wait` に `--watch-stopped` を付けること、出力が `closed`・`done`・`stopped` の 1〜3 行であること、`stopped` で起こされたら最新の `子の停止:` の記録を読んでユーザーに報告し、止まった子を外さずに再び `wait` することが書かれている

#### Scenario: 記録を残さずに止まった子は検知できないことが書かれている
- **WHEN** `references/epic.md` の Orca 経路の手順 5（`timeout` の手順）と手順 2 を読む
- **THEN** 手順 5 に、記録を残さずに子のタブで質問して止まった子は検知できないことが書かれ、手順 2 に、`launch` のあと最初に待ちに入る通知でユーザーに子のタブも見るよう一度伝えることが書かれている

### Requirement: 別のリポジトリの子を含むエピックの回し方を epic.md に書く

develop の `references/epic.md`「エピックの扱い」は、エピックの子がエピックと別のリポジトリにあるときの挙動を、既存の要件（子エピックの外し方・マージ待ちの子・子の側の手順・コメントの書式）の読み替えとして書かなければならない（MUST）。読み替えは次の表のとおりで、同じリポジトリの子の呼び出しの形・書式・判定は表の外では変えない（MUST）。既存の要件の本文は書き直さず、この要件が読み替えを持つ。

| 既存の書き方 | 別のリポジトリの子での読み替え |
|---|---|
| 子の依存を `gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by` で読む | 子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/dependencies/blocked_by`）で読む。前提の issue のリポジトリは応答の `repository_url` から取り、前提の state もそのリポジトリで読む。前提が別リポジトリにあっても閉じていれば解けている。前提の issue を `gh` が読めないときは、解けていないものとして待つ（この change で新しく決めた扱い） |
| 子エピックの判定 `gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` | 子のリポジトリで読む（`repos/<子の owner>/<子の repo>/issues/<N>`）。別リポジトリというだけでは外さず、sub-issue を持つ子だけを外す |
| エピックの子の一覧 | エピックのリポジトリの sub-issue（`gh api repos/{owner}/{repo}/issues/<E>/sub_issues`。各要素の `repository_url` から子のリポジトリを取る）と、エピック本文の子の表（`<owner>/<repo>#<N>` か `#<N>`）を合わせて組み立てる。同じ子は小文字にそろえた `<owner>/<repo>#<N>` で 1 件に数える |
| エピックへのコメント `後で別に起動するエピック: #N` | 別のリポジトリの子は `後で別に起動するエピック: <owner>/<repo>#N` |
| エピックへのコメント `子 #N マージ → 残り k 件`・`子 #N 見送り（<state_reason>）→ 残り k 件`・`子 #N のワークツリーを残した`・`親の判断: 子 #N 通した — ...` | 別のリポジトリの子は `子 <owner>/<repo>#N` の同じ形（`親の判断: 子 <owner>/<repo>#N 通した — ...`）。完了報告も同じ呼び方 |
| 子の側が親エピックに残すコメント `gh issue comment <E> --body '後で別に起動するエピック: #<自分>'` | エピックが別のリポジトリにあるときは `gh issue comment <E> -R <エピックのリポジトリ> --body '後で別に起動するエピック: <自分の owner>/<自分の repo>#<自分>'`。`<E>` とエピックのリポジトリは `route` の stderr の `parent epic: <owner>/<repo>#<E>` から取る |
| マージ待ちの子の前提の `auto-merge.yml` の取得（`repos/<owner>/<repo>/contents/...`）、`親のマージ判断:` のコメント、`parent-merge-approved` のラベル、PR 本文の `Closes #N` の確認 | すべて子のリポジトリの PR に対して行う（`contents` は `repos/<子の owner>/<子の repo>/...`、コメントは `gh pr comment <PR> -R <子の repo>`、ラベルは `gh api repos/<子の repo>/issues/<PR番号>/labels`）。印が数えられるのは `gh` の認証アカウントが子のリポジトリの OWNER・MEMBER・COLLABORATOR のときだけで、そうでなければ決める役を起こさず手順 8 の形で主に上げる |
| 親から届く返事の頭 `親エピック #<E> の判断（主の承認ではない）: ` / `主の返事（親エピック #<E> 経由）: ` を受ける子の側の手順（`references/ci-watch.md` の 1 箇所を含む） | 番号のあとに `（<owner>/<repo>）` が付く形（要件「別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す」）でも同じ手順で受ける。先頭の `親エピック #` / `主の返事（親エピック #` で判定する |
| 手順 4 の `gh api repos/{owner}/{repo}/issues/<N> --jq .state_reason` | 別のリポジトリの子は `gh api repos/<子の owner>/<子の repo>/issues/<N> --jq .state_reason`（親のリポジトリの同じ番号を読んで `completed` と `not_planned` を取り違えない） |
| 手順 8 とマージ待ちの子の、子 issue の `子の停止: 主の返事待ち` と `親の判断:` のコメントの読み先（`author_association` を含む） | 別のリポジトリの子は子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/comments`）から読む |
| 手順 3 (b) の起点ブランチ | その子の記録の `base`（別のリポジトリの子は子のリポジトリの既定ブランチか `--base` の値）。親のリポジトリの `main` ではない |
| `後で別に起動するエピック:` の行で子を外す照合（手順 2・`closed` の確認） | 別のリポジトリの子は `<owner>/<repo>#N` の形の行で照合する（同じリポジトリの子は `#N`） |
| 子を `route`・`launch`・`wait`（位置引数と `--watch-done`）・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt` に渡す | 別のリポジトリの子は `<owner>/<repo>#N` の形で渡す（同じリポジトリの子は番号だけ） |
| `references/epic.md` の注意書き `親エピックからの注意書き: #<エピック番号>`、手順 1 の「起点は `origin/main`」 | 別のリポジトリの子は注意書きが `親エピックからの注意書き: <エピックの owner>/<repo>#<E>`（子のリポジトリの issue に残る）。起点は `--base` / `EPIC_DISPATCH_BASE`、無ければ子のリポジトリの既定ブランチ |
| `stop-judge.sh <epic> <child>` の `<child>` は番号 | 番号か `<owner>/<repo>#<N>`。後者は子の本文・コメントを `repos/<o>/<r>/issues/<N>` から読み、エピックのコメントの過去の判断を `親の判断: 子 <o>/<r>#<N> ` で始まる行から探す。同じリポジトリの子は今までどおり。入力文の見出しも同じ呼び方にする |

サブエージェント方式（unmanned・channel、または Orca 管理下でも tmux の中でもないときに選ばれる）では、別のリポジトリの子を W に渡してはならない（MUST。W は親のリポジトリに worktree を作るので、別のリポジトリの issue を親のリポジトリの PR として実装してしまう）。本体はエピックに `子 <owner>/<repo>#N は別のリポジトリなので別セッション方式でだけ起動する` と 1 行コメントし、その子と、その子を前提にする子を起こさずに、主に報告する（1 行目と最後の行は、`~/.claude/output-styles/readable.md` の節 3 の書き分けに従う）。

`references/epic.md` の手順 1 には、`--base` と `EPIC_DISPATCH_BASE` が 1 回の `launch` の全部の子に掛かること、リポジトリごとに既定ブランチが違う子を混ぜるときは `--base` を付けないか `launch` をリポジトリごとに分けることを書かなければならない（MUST）。手順 6 の `failed` の報告には、`failed <child> no-clone`（`EPIC_DISPATCH_CLONES` の設定か clone を主に頼む）・`ambiguous-clone`（候補のパス）・`not-in-orca`（`orca repo add` を主に頼む）・`no-push`・`permission-lookup-failed`・`base-lookup-failed`（stderr の `gh` の認証アカウントと子のリポジトリを添える）を足し、どれも主に報告して止まると書かなければならない（MUST。サブエージェント方式に自動で振り替えない）。

この要件の守備範囲で入力として扱うのは、`references/epic.md` の手順書の文面と `stop-judge.sh` の引数である。拾いたい誤りは、別のリポジトリの子の依存や子エピックの判定を親のリポジトリに対して読み、解けていない子を起動したり、子エピックを展開したりすることである。次は通してよく、この要件では止めない: 前提の issue を `gh` が読めないとき（読めない前提は解けていないとして待つ。この change で決めた扱い）／エピック本文の子の表の書式の揺れ。表を手で直した結果の細かい食い違いを見つけるたびに検査を足すことは、この要件の完了条件としない。

#### Scenario: 依存と子エピックの判定を子のリポジトリで読むと書いてある
- **WHEN** `references/epic.md` の「回し方」の経路の決め方と「エピックである子を外す」を読む
- **THEN** 別のリポジトリの子の `blocked_by` と `sub_issues_summary.total` を子のリポジトリで読むこと、前提の issue のリポジトリを `repository_url` から取ることが書いてある

#### Scenario: 子の一覧の組み立てが書いてある
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** sub-issue の `repository_url` とエピック本文の子の表から子の一覧を組み立て、同じ子を 1 件に数えることが書いてある

#### Scenario: 読み先が子のリポジトリだと書いてある
- **WHEN** `references/epic.md` の手順 3 (b)・手順 4・手順 8・マージ待ちの子・`後で別に起動するエピック:` の照合を読む
- **THEN** 手順 4 は別のリポジトリの子の `state_reason` を `repos/<子の owner>/<子の repo>/issues/<N>` で読むと書いてあり、手順 8 とマージ待ちの子は子 issue のコメントを子のリポジトリから読むと書いてあり、手順 3 (b) は起点を記録の `base` と書いてあり、`後で別に起動するエピック:` の照合は `<owner>/<repo>#N` の形と書いてある

#### Scenario: 各サブコマンドへの渡し方が書いてある
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** 別のリポジトリの子を `route`・`launch`・`wait`・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt` に `<owner>/<repo>#N` で渡すと書いてある

#### Scenario: サブエージェント方式では別のリポジトリの子を起こさない
- **WHEN** `references/epic.md` の「回し方」の「サブエージェント方式」を読む
- **THEN** 別のリポジトリの子を W に渡さず、エピックに 1 行残して、その子とそれを前提にする子を起こさずに主に報告すると書いてある

#### Scenario: コメントの書式が書いてある
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** 別のリポジトリの子は `子 <owner>/<repo>#N`・`後で別に起動するエピック: <owner>/<repo>#N`・`親の判断: 子 <owner>/<repo>#N 通した` と書くことが書いてあり、同じリポジトリの子は今のままの書式で残っている

#### Scenario: マージ待ちの子を子のリポジトリで扱うと書いてある
- **WHEN** `references/epic.md` の「回し方」の「マージ待ちの子」を読む
- **THEN** `auto-merge.yml` の取得・`親のマージ判断:` のコメント・`parent-merge-approved` のラベルを子のリポジトリの PR に付けること、認証アカウントが子のリポジトリで権限を持たないときは主に上げることが書いてある

#### Scenario: 子の側が親エピックのリポジトリにコメントする
- **WHEN** `references/epic.md` の「回し方」の「`nested` を受けたセッション」を読む
- **THEN** エピックが別のリポジトリにあるときは `gh issue comment <E> -R <エピックのリポジトリ>` で `後で別に起動するエピック: <owner>/<repo>#<自分>` を残すと書いてあり、`<E>` とリポジトリを `route` の stderr の `parent epic: <owner>/<repo>#<E>` から取ると書いてある

#### Scenario: 親から届く返事の頭の新しい形を受ける
- **WHEN** `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」と `references/ci-watch.md` の親から届く返事の頭の照合を読む
- **THEN** どちらも `親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）: ` と `主の返事（親エピック #<E>（<owner>/<repo>）経由）: ` を受けると書いてある

#### Scenario: failed の新しい理由の報告が書いてある
- **WHEN** `references/epic.md` の手順 6 を読む
- **THEN** `no-clone`・`ambiguous-clone`・`not-in-orca`・`no-push`・`permission-lookup-failed`・`base-lookup-failed` を主に報告して止まると書いてある

#### Scenario: stop-judge.sh は owner/repo#番号 の子を受ける
- **WHEN** 子 `genetta-inc/flatmate#1615` を指定して `stop-judge.sh 1122 genetta-inc/flatmate#1615` を実行する（`gh` はスタブ）
- **THEN** 子の本文は `repos/genetta-inc/flatmate/issues/1615` から読まれ、エピックのコメントの過去の判断は `親の判断: 子 genetta-inc/flatmate#1615 ` で始まる行から探される

#### Scenario: 同じリポジトリの子の stop-judge.sh は今と同じ
- **WHEN** 子 `11` を指定して `stop-judge.sh 1122 11` を実行する
- **THEN** 子の本文は今までと同じ `repos/{owner}/{repo}/issues/11` から読まれ、過去の判断は `親の判断: 子 #11 ` で探される

### Requirement: エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う
develop の `references/epic.md`「エピックの扱い」→「回し方」の別セッション方式（Orca・tmux。以下 Orca 経路）は、親が主に出す発言について、次を規定しなければならない（MUST）。対象は、Orca 経路で親がターンを終えるときに主に出す発言すべてで、次を含む。手順 2 で `wait` を背景で起動して待ちに入るときの通知、手順 3・4・8 を処理して手順 2 に戻るたびの発言、手順 4 の見送りの報告、手順 6 の `error`・`failed` の報告、手順 7 と完了条件で待ちを終えるときの報告、**マージ待ちの子** の `reply` の `failed` の報告、手順 8 の止まった子の報告。手順 5 の `timeout` で起こされたときは主に発言を書かない（要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」）。書くなら `主がすること: なし` の 1 行だけで、この書き分けに従う。主への問いが未回答のあいだは、その 1 行も書かない。

- 1 行目と最後の行は、`~/.claude/output-styles/readable.md` の節 3 が定める書き分けに従う（MUST）。判断・確認・操作を求める発言は 1 行目を質問にし、区切りより上の本文の最後の行を答え方にする。主の操作も判断も要らない報告は 1 行目を `主がすること: なし` にする（主の質問への答えは正本のとおり 1 行目に答えを書く）（手順 2 で待ちに入るときは普通こちら）。`references/epic.md` は書き分けを写さず、正本を参照する（MUST）
- 同じターンで主に問いを出したあとに手順 2 で待ちに入るときは、待ちに入る通知を `主がすること: なし` で始めない（MUST）。通知の 1 行目に問いの質問を、最後の行に答え方を繰り返す（直前の問いを `なし` で上書きしない）
- 規定は Orca 経路の導入部に 1 か所で書き、各手順は参照する（MUST。手順ごとに書式を複写しない）
- 子の記録の推奨を主に OK してもらう報告（手順 8 で、止まった子の停止の記録の URL を添えて主の答えを求めるもの。正本の型で書き、1 行目は OK すると何が起きるかを中身で書いた質問にし、論点の有無を書く）の答え方の行には、打つ場所が親のタブであることと、報告の直後に別の発言を挟まないことを書く（MUST）
- 手順 8 の中でも返事の場所が親のタブでない発言は、答え方の行にその場所を書く（MUST）。`owner-reply-check.sh --locate` で主の発言を引けなかったときの「子のタブで『許容する』と打ってほしい」の連絡は、答え方の行に子のタブを出す。`reply` の出力が `failed <N> <段>` のときの報告は、主の操作が要れば問いの形にし、要らなければ 1 行目を `主がすること: なし` にする
- 子の完了報告の 1 行目（`主がこのセッションで次にすること:`）は変えない（MUST。要件「エピックの子の完了報告は、主がこのセッションで次にすることを 1 行目に書く」に従う）
- `主がすること: <どこで> <何を>` の形を使わない（MUST NOT）

この要件の守備範囲で入力として扱うのは、`references/epic.md` の Orca 経路の文面である。拾いたい誤りは 2 つある。主が親の発言から、答えが要るかどうかと、どこで何を打つかを読み取れないこと。子の記録の推奨を主に OK してもらう報告で、返事の場所と条件が発言から読めないこと。次は通ってよく、この要件では止めない: 2 行目以降の説明の文の良し悪し／答え方の中身の正しさ。穴が見つかるたびに決まりを足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: Orca 経路が正本の書き分けを参照する
- **WHEN** `references/epic.md` の「回し方」の Orca 経路の導入部を読む
- **THEN** 親が主に出す発言の 1 行目と最後の行を `~/.claude/output-styles/readable.md` の節 3 の書き分けに従わせると書かれ、`主がすること: なし` の場合が書かれ、`主がすること: <どの画面・入力欄で>` の形が無い

#### Scenario: 待ちに入る通知が直前の問いを上書きしない
- **WHEN** `references/epic.md` の Orca 経路の導入部と手順 2 を読む
- **THEN** 同じターンで主に問いを出したときは、待ちに入る通知を `主がすること: なし` で始めず、問いの質問と答え方を繰り返すと書かれている

#### Scenario: 子の記録の推奨を主に OK してもらう報告の答え方に場所と条件が入る
- **WHEN** `references/epic.md` の手順 8 を読む
- **THEN** 子の記録の推奨を主に OK してもらう報告の答え方の行に、親のタブで打つことと、報告の直後に別の発言を挟まないことを書くと書かれ、主の発言を引けなかったときの連絡の答え方の行には子のタブを出すと書かれている
