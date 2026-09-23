## Context

- `subagent-context.sh` は名前付きサブエージェント 1 体の「最後の assistant レコードの `input + cache_creation + cache_read`」を測る。個体の現在のコンテキスト量で、累計ではない
- `subagent-context-audit.sh` は `<projects>/*/*/subagents/agent-*.jsonl` を走査して母集団の統計を出す観測専用で、止めない
- Claude Code はサブエージェントごとに `agent-<id>.jsonl`（トランスクリプト）と `agent-<id>.meta.json` を並べて置く。meta には `description`・`name`（名前付きのときだけ）・`model`・`worktreePath`（`isolation: "worktree"` のときだけ）が入る。実物の例: `{"agentType":"general-purpose","worktreePath":"…/agent-a1c50…","spawnedWithWorktree":true,"description":"W: spec phase for #288","name":"W-288","model":"opus",…}`
- SendMessage による再開は同じ `agent-<id>.jsonl` に追記される。1 つの応答は複数行に分かれて書かれ、各行に同じ `requestId` と同じ `usage` が載る（cost-ledger が `requestId` で重複排除しているのと同じ事情）
- Codex の消費の残り方（2026-09-23 に実物で確認）:
  - Codex CLI は `$CODEX_HOME/sessions/YYYY/MM/DD/rollout-<時刻>-<thread_id>.jsonl` に会話を書き、`event_msg` の `token_count` イベントに `info.total_token_usage`（thread の累計）と `info.last_token_usage`（直前 1 リクエスト分）を載せる。直近 400 ファイルで、累計は単調に増え、最後の累計は重複を除いた `last_token_usage` の和と全件一致した。同じ累計が続けて 2 回出るファイルが 29 件、`info` が null のイベントがあるファイルが 5 件あった。`total_tokens` は `input_tokens + output_tokens` で、`cached_input_tokens` は `input_tokens` の内数、推論トークンは `output_tokens` の内数
  - develop が Codex executor を使うときの経路 `scripts/codex-worker.py` は、1 回の委譲ごとに一時ディレクトリに runtime CODEX_HOME を作り、終わると消す（`discard_runtime` と `shutil.rmtree`）。したがってこの経路の rollout は残らない。委譲ごとに `thread/start` で新しい thread を作り、再開（resume）はしない。消費は標準出力の 1 行 JSON の `usage` に残り、形は app-server の `ThreadTokenUsage`（`total` と `last` が `TokenUsageBreakdown` = `totalTokens`・`inputTokens`・`cachedInputTokens`・`outputTokens`・`reasoningOutputTokens`）。worker は結果をファイルに保存してはならない（`openspec/specs/codex-worker/spec.md`）
  - G が full レビューを Bash から直接 `codex exec` / codex-companion で呼ぶ経路は、呼び出した環境の CODEX_HOME（未設定なら `~/.codex`）に rollout が残る。thread_id は `codex exec` の出力ヘッダの `session id:`、companion の結果の `threadId` で分かる
  - rollout の `session_meta.cwd` は作業ディレクトリだが、実物には Claude の scratchpad（`/private/tmp/claude-501/...`）を cwd とする `codex_exec` の rollout もあり、リポジトリに結びつかないことがある
- 直近 30 日の実データ（description に `#N` を含むサブエージェントを、親セッションのプロジェクトと `#N` で束ねた 301 組）では、組ごとの合計の中央値 約 700 万、75 パーセンタイル 約 1,330 万、90 パーセンタイル 約 2,780 万トークン。最大は 3 億超

## Goals / Non-Goals

**Goals:**
- 記録先番号を渡すと、その記録先のために起こした全サブエージェントの全リクエストの合計と体数、その記録先のために使った Codex の消費の合計と thread 数が、内訳と合計で出る
- Claude 分と Codex 分の合計が上限を超えたら exit 2 になり、develop の本体が次の spawn / SendMessage / Codex への委譲の前に止まって主に上げる
- ネットワークに出ずに、ローカルのファイルだけで計算できる（bats で固定入力に対して検証できる）

**Non-Goals:**
- メインセッション（本体）自身の消費の計測。本体はオーケストレータで、1 PR の消費の大半はサブエージェントにある。本体の消費は cost-ledger（ブランチ帰属）の範囲
- Workflow 経由のサブエージェントの計測
- `scripts/codex-worker.py` と adapter（`references/codex-develop.md`）の変更。計測と記録は本体手順に置く（Decision 7）
- 金額換算（cost-ledger の役割）
- 動いているサブエージェントを途中で止めること（途中停止は `context-tripwire.sh` の役割。この仕組みは次を起こす前に止まるだけ）

## Decisions

### 1. 紐付けは spawn 時の `description` に記録先番号 `#N` を入れる規約で行う

issue で挙がっていた候補と比べた:

| 方式 | 採否 | 理由 |
|---|---|---|
| A. 本体が spawn 時に記録先へ「起こした役割: <名前> <model>」をコメントする | 採らない | 名前が無い spawn（R1・G のレビュアー・決める役は名前なしで起こすことがある）を紐付けられない。`isolation: "worktree"` ではトランスクリプトのファイル名に名前が入らず（#243）、名前から探すには結局 meta.json を読む必要がある。スクリプトが GitHub API を呼ぶことになり、bats に gh のスタブが要る。コメントが増えて記録先が読みにくくなる |
| B. worktree のパスで束ねる | 採らない | 本体がいる作業ツリーで起こす R1・G・レビュアー・決める役は W の worktree に入らないので漏れる。本体が対象専用の worktree にいるときは全員が同じパスになるが、そうでないときは束ねられない |
| **C. Agent ツールの `description` に `#N` を入れ、meta.json の `description` から拾う** | **採る** | Claude Code が全サブエージェントの meta.json に `description` を必ず書くので、名前の有無・隔離の有無に関係なく拾える。本体は既に `W: spec phase for #288` のように番号を入れて起こしており、規約化のコストが小さい。ローカルファイルだけで完結し、bats の固定入力で検証できる |

C の弱点は、本体が description に番号を書き忘れるとその 1 体が計測から漏れること（少なく出る側に倒れる）。これは SKILL.md の手順に規約として書き、漏れた場合も上限判定が遅れるだけで誤って止まることはない。

description に複数の `#N` があるとき（例: G を「gate for PR #400 (#288)」と起こす）は、渡された番号のどれかと一致すれば数える。スクリプトは番号を複数受け取れる（`pr-token-budget.sh 288 400`）ので、issue が記録先で PR 番号が別にある場合も両方を渡せば漏れない。同じサブエージェントは複数の番号に一致しても 1 回しか数えない。

番号の照合は `#` の直後に数字が続き、その直後が数字でない位置だけを一致とする（`#2880` は `#288` に一致しない）。

### 2. リポジトリで絞る

issue 番号はリポジトリをまたいで重なる（実データでも flatmate と claude-harness の `#N` が混在した）。スクリプトは実行時のカレントディレクトリのリポジトリ識別子（`git rev-parse --path-format=absolute --git-common-dir`）と、各サブエージェントの作業ディレクトリ（meta の `worktreePath`、無ければトランスクリプトで最初に現れる `cwd`）の識別子が一致するものだけを数える。cost-ledger のリポジトリ識別と同じ方法で、worktree は親リポジトリに畳まれる。

作業ディレクトリが既に消えていて識別子が求まらないサブエージェントは数えず、件数を `unresolved` として出力に出す（黙って落とさない）。計測するのは PR が進行中のときで、その間は worktree が残っているので、通常の使い方では発生しない。

### 3. トークンの数え方

1 リクエストのトークン = `input_tokens + cache_creation_input_tokens + cache_read_input_tokens + output_tokens`。`requestId`（無ければ `message.id`、それも無ければ `uuid`）で重複排除する。#281 の 122,955,450 は usage の合計として手で出された値で、出力も消費に含まれるため output を入れる。キャッシュ読み出しは単価が安いが、枠の消費（トランスクリプトに残る読み込み量）としては数えるのが issue の意図（「全リクエストの usage 合算」）に合う。

壊れた行・辞書でない行・`usage` が辞書でない行は読み飛ばし、読み飛ばした行数を出力に出す。

### 4. 上限の既定値は 30,000,000

実データの 90 パーセンタイル（約 2,780 万）の少し上に置く。普通の PR は止まらず、PR #268 の 1.2 億には 4 分の 1 の時点で止まる。環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP` と `--cap` で変えられる（`--cap` が優先）。

### 5. 止まったあとの問いと、続けるときの上限の引き上げ

「続けるか、範囲外として閉じるか」の 2 択そのものは PR-A（#351）と同じにする。ただし #354 で pr-review-gate は判断材料なしの 1 択を禁じた（`openspec/specs/dev-workflow-pr-review-gate/spec.md`「引用できる指摘が残ったら 3 周目に入らず主に上げる」）ので、それに揃えて、本体は `needs-approval` を付け、現在の合計・体数・上限・残工程（次に起こそうとした役割と、そのあと残る工程）・本体の推奨を添えて問う。

- 「続ける」: 本体は記録先に 1 行目が `PR トークン上限: <新上限>` のコメントを投稿し、以後この記録先の計測に `--cap <新上限>` を渡す。新上限は「その時点の合計 ＋ 直前の計測で上限に使った値（`--cap`、無ければ `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 の順で決まった値）」とする（同じ幅の予算をもう 1 回分与える。環境変数を設定していればその幅になる）。後任の本体（手渡し・別セッション）は記録先の最新の `PR トークン上限:` コメントを読んで同じ値を使う。スクリプト自身は GitHub を読まない
- 「範囲外として閉じる」: 本体はこの記録先について以後サブエージェントを起こさず、Codex にも委譲せず、残作業を記録先にコメントしてサイクルを終える

unmanned（loop-dev-agent）でも同じく止まる。問いは記録先への `needs-approval` とコメントで出し、サイクルを終える。

### 6. 計測を置く位置

本体がその記録先のためにサブエージェントを spawn する直前（W / R1 / G / G のレビュアー / 決める役はその例で、役割を問わない）、SendMessage で再開する直前、および executor が `codex` の役割へ委譲する直前。executor を問わず毎回測り、測る位置を executor で分けない（手順を 1 通りにする）。計測は `skills/develop/SKILL.md`（本体手順）に置き、adapter（`references/codex-develop.md`）には置かない（`openspec/specs/manual-codex-develop/spec.md` が adapter に独自の品質ゲートを置くことを禁じている）。`subagent-context.sh` を再開前に呼ぶのと同じ位置に並べる（こちらは spawn と委譲の前にも呼ぶ）。最初の spawn の前はサブエージェントが 0 体なので合計 0 で exit 0 になる。

exit 1（引数エラー・python3 が無い・カレントディレクトリがリポジトリでない）のときは止まらずに進み、記録先に計測できなかった旨をコメントする（観測の失敗で作業を止めない。止めるのは上限超を確認できたときだけ）。コメントは同じ記録先・同じ理由について 1 サイクルに 1 回までにする（spawn のたびに同じコメントが増えるのを防ぐ）。1 サイクルは、interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクルを指す。

### 7. Codex の消費は、本体が記録先に残す `Codex 消費:` コメントで紐付ける

Codex の消費は Claude の meta.json / トランスクリプトに残らないので、別の紐付けが要る。比べた案:

| 方式 | 採否 | 理由 |
|---|---|---|
| A. `$CODEX_HOME/sessions` の rollout を `session_meta.cwd`（worktree のパス）で束ねる | 採らない | develop の Codex executor 経路（codex-worker）は runtime CODEX_HOME をジョブ後に消すので、束ねる対象の rollout がそもそも残らない。残る経路でも cwd が scratchpad のことがあり、cwd には記録先番号が無いので、同じ worktree で別の記録先を扱った消費と区別できない（Decision 1 で worktree のパスを採らなかったのと同じ理由） |
| B. codex-worker に rollout や usage を保存させる | 採らない | worker は結果をファイルや永続 store に保存してはならない（`openspec/specs/codex-worker/spec.md`）。adapter に計測を足すのも `manual-codex-develop` の禁止に当たる |
| C. 本体がローカルの台帳ファイルに thread_id とトークン数を書く | 採らない | 手渡しで本体が替わったとき・別セッションで再開したときに台帳の場所を別途伝える必要がある。`PR トークン上限:` を記録先のコメントに置いたのと同じ理由で、後任が必ず読む場所（記録先）に置く |
| **D. 本体が Codex を呼ぶたびに記録先へ `Codex 消費: <thread_id> <トークン数または ->` を 1 行コメントし、計測前に集めて `--codex-records` で渡す** | **採る** | codex-worker の結果 JSON（`thread_id` と `usage.total.totalTokens`）をそのまま書けるので worker も adapter も変えずに済む。後任の本体も同じコメントから集められる。スクリプトは渡されたファイルを読むだけで GitHub を読まない方針を保てる |

D の書式と扱い:

- 1 行目を `Codex 消費: <thread_id> <tokens>` とする。`<tokens>` は codex-worker の結果 JSON の `usage.total.totalTokens`（委譲ごとに新しい thread なので、その thread の累計がその委譲の消費）。G が Bash から直接呼んだ Codex のようにトークン数が手元に無いときは `-` と書く
- G が full レビューで Codex を呼んだときは、G が return に thread_id を書き、本体が `Codex 消費: <thread_id> -` を記録する（G の Claude トランスクリプトには Codex の消費が入らないため）
- 本体は計測の直前に、渡すすべての記録先番号のコメントから 1 行目がこの書式のものを集め、`<thread_id> <tokens>` を 1 行ずつ書いたファイルを `--codex-records <file>` で渡す。コメントを集める具体的な手順は SKILL.md に書く
- スクリプトは同じ thread_id を 1 回だけ数える（複数の記録先に同じ thread を記録しても二重に数えない。トークン数が食い違うときは大きい方）。`-` の thread は `--codex-home <dir>`（複数可。無ければ `${CODEX_HOME:-$HOME/.codex}`）の `sessions/*/*/*/rollout-*-<thread_id>.jsonl` を探し、`token_count` イベントの `info.total_token_usage.total_tokens` の最大値を使う（累計なので最大値が thread の合計。同じ累計が続く行と `info` が null の行はこれで自然に無視される）。account ごとに CODEX_HOME が違うので、本体は codex-develop の `--account-home` の対応表にある全パスを `--codex-home` に渡す
- トークン数も rollout も見つからない thread は数えず、件数を `codex_unresolved` に出す（`unresolved` と同じく黙って落とさない）

トークンの定義は Claude 分と揃える。Codex の `totalTokens` は `inputTokens + outputTokens` で、キャッシュから読んだ入力（`cachedInputTokens`）は `inputTokens` の内数、推論は `outputTokens` の内数なので、Claude 側の `input + cache_creation + cache_read + output` と同じく「読み込んだ量と出した量の全部」になる。

上限は Claude 分と Codex 分の合計に 1 本で掛ける（主の判断: Codex でも開発するので、Codex 分を外すと上限の意味が薄い）。出力には `claude_tokens` と `codex_tokens` の内訳を出し、止まったときの問いにも内訳を添える。provider ごとに別の上限を設けないのは、主が決めたいのは「この PR にどれだけ使ったか」で、どちらの provider で使ったかは内訳で見れば足りるため。

## Risks / Trade-offs

- [本体が description に番号を書き忘れる] → その 1 体が漏れ、合計が少なく出る。SKILL.md に規約として書き、出力の `agents` 一覧（名前・description・model・トークン）で本体と主が確認できるようにする
- [上限判定は次を起こす前だけなので、動いている 1 体の消費は止められない] → 1 体の暴走は `context-tripwire.sh` のコンテキスト上限が別に止める。この仕組みは累計の歯止め
- [全 meta.json を毎回走査する] → 実測 2,300 件程度で、読むのは meta（小さい JSON）と一致したトランスクリプトだけ。spawn の頻度に対して十分軽い
- [本体が `Codex 消費:` コメントを書き忘れる] → その thread が漏れ、合計が少なく出る。description の書き忘れと同じく少なく出る側に倒れ、誤って止まることはない。SKILL.md に規約として書き、出力の `codex_threads` で確認できるようにする
- [codex-worker の結果 JSON を受け取れずに終わった委譲] → thread_id が分からず数えられない。途中で切れた委譲は工程の最初からやり直す運用（`references/codex-develop.md`）で、やり直した分は数えられる
- [Codex の記録コメントが委譲のたびに増える] → 1 行のコメントに留める。記録先を読むときの妨げより、後任の本体が同じ値を再現できることを優先する
- [30,000,000 が合わない] → 環境変数で変えられる。運用で分布が変わったら既定値を見直す
