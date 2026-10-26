## MODIFIED Requirements

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker.md`（W）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）・仕様レビュー結果の記録書式・「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。事前分類表の「1 周目」列は**実行役（W）の上限を `opus` とし、`fable` 行を持ってはならない**（MUST NOT。4 分類のいずれに当たっても W は `opus` 止まりで、聖域パスの `opus` は据え置き）。表には、読んで判断する役（R1・G が要求するレビュアー）が `fable` 相当の分類に当たるときは `subagent_type: dev-workflow:decider` で spawn し、`general-purpose` に `model: fable` を付けないことを明記しなければならない（MUST）。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担うことを書く（SHALL）。`worker.md` の return には「指示のどこまでやって、どこで何が起きたか」を含める義務を書かなければならない（MUST。決める役の入力契約になるため）。

`spec-reviewer.md` は 6 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合・守備範囲の明記）と、既定 2 周と 2 周目以降の周の終わりに直し方の判定を通して続ける規則を含む（MUST。判定役・入力・書式の正本は `references/fix-check.md` で、`spec-reviewer.md` は規則を書いて正本を指す）。観点の中身の正本は `dev-workflow-spec-review` とする（SHALL）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

`worker.md`・`spec-reviewer.md`・`gate-runner.md` の 3 つはいずれも、長時間処理の完了通知を待つためにターンを終えてはならない旨を明記しなければならない（MUST）。待ち方の詳細の正本は `plugins/dev-workflow/references/subagent-waiting.md` とし、各指示書はそこを参照する（SHALL）。`spec-reviewer.md` の 1 行は、decider 経路で spawn される R1 が `Bash` を持たず待ちループ自体を実行できないため、「長い処理の完了を待つ目的でターンを終えない（decider 経路の R1 は待ちを伴う作業を持たない）」の形で書く（SHALL。読んだ R1 が実行できない手順を探しに行かないようにするため）。

`gate-runner.md` は Codex の**起動**の事実（(a) `codex exec -c approval_policy=never -c model_reasoning_effort=medium` を `run_in_background` で起動する経路と、(b) `codex-companion.mjs` に `task … --effort medium` を投げる経路。companion の path-discovery を含む）を持ち、**完了の確認方法は正本 `plugins/dev-workflow/references/subagent-waiting.md` に委ねなければならない（MUST）**。完了マーカーの雛形・具体の待ち値・総待ちの上限を `gate-runner.md` に再掲してはならない（MUST NOT。2026-09-09 のレビューで、再掲した companion の判定方法が事実と食い違ったまま残っていたため）。「出力ファイルを読め」だけで待ち方を書かない記述を残してはならない（MUST NOT）。`gate-runner.md` に残す待ち関連の記述は、完了通知に頼ってターンを終えない禁止・正本への参照・上限到達時の G 固有の分岐（待ちをやめて `needs-reviewer` を return し、根拠に「Codex タイムアウト」と実際に待った時間を書く）に限る（SHALL）。

#### Scenario: worker.md に記録書式と事前分類表がある
- **WHEN** `references/roles/worker.md` を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式、`gh` で記録先にコメントする手順、4 分類の事前分類表（「1 周目」列がすべて `opus` で `fable` 行が無い）、レビュアーの fable は `dev-workflow:decider` 経由であること、return に「指示のどこまでやって、どこで何が起きたか」を書く義務が書かれている

#### Scenario: spec-reviewer.md に 6 観点と周回の規則がある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 6 観点がすべて列挙され、既定 2 周・2 周目以降の周の終わりに BLOCKER が残れば直し方の判定を通し、すべて直し方の決まったもので PR トークン上限の内側なら主に聞かず次の周を回すことが書かれ、「3 周目の例外は設けない」の文は無い

#### Scenario: gate-runner.md は pr-review-gate を手順書として参照する
- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** pr-review-gate スキルを読んで手順 1〜5 を実行すること、Codex は `codex exec` / `codex-companion.mjs` を Bash で呼ぶこと、Codex が使えないときは `needs-reviewer`（判定・HEAD SHA・推奨モデル・受け入れ条件の所在を含む）を return して本体にレビュアーの spawn を委ねること、failed の return に原因分類を含めることが書かれている、Codex の完了確認を同一ターン内の前景ポーリングで行うこと・その手順の正本が `references/subagent-waiting.md` であること・総待ちの上限に達したら `needs-reviewer` を return することが書かれており、待ちの雛形と具体の待ち値は再掲されていない

#### Scenario: 3 つの指示書に待ちでターンを終えない禁止がある
- **WHEN** `references/roles/` 配下の `worker.md` / `spec-reviewer.md` / `gate-runner.md` をそれぞれ読む
- **THEN** どのファイルにも「完了通知を待つためにターンを終えない」旨の記述があり、待ち方の正本として `references/subagent-waiting.md` が参照されている

#### Scenario: spec-reviewer.md の 1 行は decider 経路を踏まえている
- **WHEN** `references/roles/spec-reviewer.md` の待ちに関する 1 行を読む
- **THEN** 禁止が書かれたうえで、decider 経路の R1 は待ちを伴う作業を持たない旨が添えられており、実行できない待ちループの手順を探しに行かずに済む

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
SKILL.md は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。

**回し方（経路の決め方）**: interactive の本体は子の依存グラフを読み、blocked されていない子の番号を `plugins/dev-workflow/scripts/epic-dispatch.sh route` に渡して経路を決める（MUST）。`route` が `orca` か `tmux` を返したとき（Orca 管理のワークツリーにいる、または tmux の中にいる）は、その起動部品で子を別のセッションとして起こす **別セッション方式**、`subagent` を返したときは **サブエージェント方式**で進める（MUST）。別セッション方式とサブエージェント方式は二本立てではなく、子を起こす手段を起動部品として差し替える一本の手順で書く（MUST。共通の手順に、部品ごとに違う点だけを部品ごとの欄に書く）。経路は `/develop <エピック番号>` の最初の開始時に 1 回決め、途中で変えてはならず（MUST NOT）、決めた経路をエピックに `回し方:` で始まる 1 行コメントで残す（MUST）。別セッションで同じエピックを再開したときは、`回し方:` で始まる最新のコメントを読んで経路を引き継ぎ、`route` をやり直してはならない（MUST NOT）。最新の `回し方:` が `Orca` か `tmux` のときは、本体が `epic-dispatch.sh launch` と `adopt` に環境変数 `EPIC_DISPATCH_LAUNCHER=<そのコメントの部品名（小文字の orca か tmux）>` を付けて呼ばなければならない（MUST。付けないと部品を今の環境から選び直し、前のセッションの記録の子と別の部品で新しい子が起動しうる）。その部品が今の環境で使えず `launch`・`adopt` が exit 1 で終わったら、別の部品にもサブエージェント方式にも振り替えず、stderr を添えて主に報告して止まる（MUST。部品の違う子の混在を作らない）。`reply`・`notify-closed`・`reap`・`wait --resolve` は記録の `launcher` で部品が決まるので、再開で環境が変わっても部品名を渡さない。unmanned（`--unmanned`）では `route` を呼ばず、サブエージェント方式で進める（MUST。背景で待って起こされる動きが 1 サイクル 1 仕事と合わないため）。channel でも `route` を呼ばず、サブエージェント方式で進め、エピックに `回し方: サブエージェント（channel モード）` を残す（MUST）。channel で再開したエピックの最新の `回し方:` が別セッション方式（Orca・tmux）なら、`launch` もサブエージェント方式も使わず、その旨をチャンネルで主に報告して止まる（MUST。channel は別セッション方式を引き継がない）。channel の本体は、develop の手順のために別の Claude Code セッション（Orca・tmux など）を起こしてはならない（MUST NOT。別に起こしたセッションには印 `DEV_WORKFLOW_UNATTENDED` が届かず、その画面を誰も見ていないので、子が主の返事待ちで止まっても誰も気づかない）。develop の外で住人が別のセッションを起こすときの印の渡し方は、この要件の範囲に入れない（#1123）。

**回し方（別セッション方式）**: 本体は `epic-dispatch.sh launch` で子ごとに起動部品（Orca か tmux）の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。再開時も、依存が解けた open の子を、最新の `回し方:` の部品名を付けた `launch` に渡し（上の段落のとおり）、起動済みの子は `launch` の `skipped` で見分ける（同じ子を二重に起動しない）。本体は `launch` が `launched` / `skipped` を出した子を動いている子とし、`epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める。`closed` なら閉じた子ごとに `state_reason` を読み、`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントして依存グラフを読み直し、解けた子を件数にかかわらず `launch` する。`completed` 以外ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子を起動してはならず（MUST NOT）、ユーザーに報告する。そのあと残りの動いている子で再び `wait` する。`timeout` なら待っている子に `needs-approval` などの停止の兆候が無いかを見て、あればユーザーに報告し、報告したかどうかにかかわらず残りの動いている子で再び `wait` する。子が自分のタブでユーザーに質問して止まっている場合はこの確認では気づけないことを書く（SHALL）。`wait` の `error` と `launch` の `failed` はユーザーに報告して止まる。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子セッションのモデルは `epic-dispatch.sh launch` が起動時に `cld --model` で指定し、既定は `opus` で環境変数 `EPIC_DISPATCH_MODEL` で変えられること（Claude Code の既定モデルは子に効かないこと）、コマンド部分（既定 `cld`）は環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ、Orca に設定したコマンドはハーネスから読めないので（tmux の部品はこの環境変数のコマンドをそのまま打ち込む）Orca 側のコマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変えることを書く（SHALL）。子セッションは `cld` が付ける `--dangerously-skip-permissions` で動き許可の確認画面が出ないこと（`epic-dispatch.sh` が足すのは `--model` だけであること）、マージを止めているのは develop と pr-review-gate の規則と hooks であることを書く（SHALL）。本体は子の PR を `gh pr merge` や merge API で直接マージしてはならない（MUST NOT）。子の PR のマージは、子セッションの中の人の承認か自動マージの処理（`.github/workflows/auto-merge.yml`）が行い、`human-merge` の付いた子の PR は、本体が要件「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」の手順で判断の印を付けたときに限って自動マージの処理がマージすることを書く（SHALL）。

**回し方（サブエージェント方式）**: 今までどおり blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと。本体が W を `isolation: "worktree"` で spawn して用意し、W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。

どちらの経路でも、スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった新しい問題は新しい子 issue として追加する。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

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
- **THEN** `launch` で子を起動し、`wait` を `run_in_background: true` で起動して待つこと、`closed` で `state_reason` を読み `completed` なら `子 #N マージ → 残り k 件` をコメントして解けた子を `launch` し、それ以外なら `見送り` とコメントして後続を起動せず報告すること、`timeout` で停止の兆候を確かめて報告したうえで再び待つこと、子のタブでの質問は検知できないこと、本体が子の PR を直接マージせず、`human-merge` の付いた子の PR は本体が判断の印を付けたときに限って自動マージの処理がマージすることが書かれている

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

#### Scenario: SKILL.md の回し方が起動部品の差し替えとして書かれている
- **WHEN** develop の `references/epic.md`「エピックの扱い」→「回し方」を読む
- **THEN** 起動・待ち・閉じた子・止まった子・片付け・完了の手順は 1 本で書かれ、Orca の部品・tmux の部品・サブエージェント方式のどれで起こすかによって違う点だけが部品ごとの欄に書かれており、「Orca 経路」と「サブエージェント方式」を別々の手順として二重に書いていない。サブエージェント方式は状態の記録を書かない、と書かれている

### Requirement: エピックの並列起動は 1 段で止める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子セッションを起動する端末のコマンドの先頭に `EPIC_DISPATCH_PARENT_EPIC=<epic>` を置かなければならない（MUST。`<epic>` は `launch` に渡したエピック番号）。そのうしろ、`<cmd>` の前には `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` を置く（MUST。`<値>` の既定と上書きは要件「時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める」が定める）。コマンド全体は `EPIC_DISPATCH_PARENT_EPIC=<epic> CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値> <cmd> --model <model>` の形になり、端末を作れなかった子について stderr に出す `orca terminal create --command ...` の作り直しのコマンドにも同じ前置きが入る（SHALL）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の出力の規定、`<cmd>` の形の規定、および Scenario「EPIC_DISPATCH_MODEL…」「EPIC_DISPATCH_CLAUDE_CMD…」の `--command` の値に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

環境変数 `EPIC_DISPATCH_PARENT_EPIC` が空でない環境では:

- `route <child>...` は、子の番号の検査（数字でなければ使い方を出して exit 1）のあと、子の件数・`orca` の有無・`orca worktree current` の結果によらず stdout に `nested` の 1 行を出して exit 0 で終わらなければならない（MUST）。`orca` を呼んではならない（MUST NOT）
- `launch` は、引数の検査（既存の使い方の誤り）のあと、`orca` と `git` を 1 つも呼ばず、stderr に親エピックの番号と展開しない旨を出して exit 1 で終わらなければならない（MUST。子ワークツリーを作らない）。stdout には何も出さない（SHALL）
- `wait` の振る舞いは変えない（SHALL）

develop の `references/epic.md`「エピックの扱い」は次を規定しなければならない（MUST）。

- **エピックの子を外す**: 本体は依存グラフから求めた blocked されていない子のうち、sub-issue を持つ子（`gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` が 1 以上。`null` や空は 0 とみなす）をエピックとして外し、`route`・`launch`・サブエージェント方式のどれにも渡してはならない（MUST NOT）。経路が `nested` でないと確定したら（`route` が `nested` 以外を返したとき。`route` を呼ばない unmanned と、`回し方:` のコメントから経路を引き継いだ再開を含む）、外した子ごとにエピックへ `後で別に起動するエピック: #N` と 1 行コメントする（MUST）。再開時に `回し方:` のコメントから経路を引き継いだ場合も、`launch` に渡す前に同じ確認で外す（MUST）
- **`nested` を受けたセッション**: `route` が `nested` を返したら、そのセッションはエピックを展開してはならない（MUST NOT。Orca 経路もサブエージェント方式も使わない）。親エピック（`EPIC_DISPATCH_PARENT_EPIC` の番号）と自分の issue に `後で別に起動するエピック: #<自分の issue>` とコメントし、ユーザーに後で `/develop #<自分の issue>` を別に起動して回すと伝えて止まる（MUST）。自分の issue を閉じてはならない（MUST NOT）。`launch` が stderr に展開しない旨を出して exit 1 で終わったときも同じに扱い、「親ワークツリーで開き直す」とは報告しない（MUST NOT）
- **親の待ち受け**: Orca 経路の本体は、`timeout` と `closed` で起こされたときの確認で、エピックに `後で別に起動するエピック: #N` の行がある子を動いている子から外す（MUST）
- **親の完了報告**: 動いている子が無くなったときの本体の報告（エピックへのコメントとユーザーへの報告）に、エピックに記録した `後で別に起動するエピック:` の番号をすべて載せる（MUST）。子エピックが閉じるまで親エピックの完了条件は満たされないので、親エピックを閉じてはならない（MUST NOT）

この要件の守備範囲で入力として扱うのは、`launch` が子の端末のコマンドに前置きした `EPIC_DISPATCH_PARENT_EPIC`（子セッションの Claude Code とその Bash・サブエージェントに引き継がれる）、本体が依存グラフから求めた子の番号ごとの `sub_issues_summary.total`、エピックのコメントの `後で別に起動するエピック:` で始まる行である。拾いたい誤りは、並列起動された子のセッションが自分の issue をエピックとして孫のワークツリーとセッションを作ることである。次は通してよく、この要件では止めない: `EPIC_DISPATCH_PARENT_EPIC` の値は空でなければ数字かどうかを検査しない／人が手で `EPIC_DISPATCH_PARENT_EPIC` を付けて起動したセッションも `nested` になる／sub-issue を持たず本文で子を列挙しているだけのエピックは事前確認を通り、Orca 経路で起動された子なら子のセッションの `route` で止まり、サブエージェント方式で起こされた子（変数が無い）は止まらない／`回し方:` のコメントからサブエージェント方式を引き継いだ子エピックのセッションはスクリプトでは止まらない／この変更の前に起動された子セッションには変数が無く従来どおり展開しうる／`EPIC_DISPATCH_CLAUDE_CMD` が前置きの代入を受け付けない形（`exec` で始まる文字列など）のときは値が渡らない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`EPIC_DISPATCH_PARENT_EPIC` の前置き、`route` の `nested`、`launch` の拒否、SKILL.md の上の記述を確かめなければならない（MUST）。

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

#### Scenario: SKILL.md に子エピックの扱いと完了報告が書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** sub-issue を持つ子を外して `後で別に起動するエピック: #N` とコメントすること、`route` の `nested` を受けたら展開せず親エピックと自分の issue にコメントして止まること、`nested` と同じく `launch` の拒否でも止まり「親ワークツリーで開き直す」と報告しないこと、`timeout` と `closed` の確認でその行がある子を待つ対象から外すこと、完了報告に `後で別に起動するエピック:` の番号を載せることが書かれている

### Requirement: 新しいセッションの本体は引き継ぎのコメントとラベルから続ける

`skills/develop/references/handover.md` は、記録先に `引き継ぎ: 主の返事待ち` のコメントがある記録先で新しいセッションの本体が起動したときの再開手順を規定しなければならない（MUST）。手順は次のとおり。

1. 記録先の最新の引き継ぎのコメントを読む。
2. そのコメントより後の主の回答（記録先または対象 PR のコメント、または `/develop` の引数の残り。引き継ぎの `実行モード` が `channel` のときは、このセッションが受けた `#<記録先>` を添えたチャンネルの返事も含む）を探し、あれば使う。無ければ、引き継ぎの「主への依頼」を主に見せ直して返事を聞き、返事が来るまで役割を起こさない。
3. 引き継ぎの「ラベルの付け先」に `needs-approval` が付いていることと、対象の PR の HEAD が引き継ぎの HEAD と同じことを確かめる（ラベルはコメントの記録先ではなく、この項目の指す先で見る）。ラベルが無ければ保留は既に解かれているので、記録先のコメントから今の状態を組み立て直して主に報告する。HEAD が動いていれば、引き継ぎの HEAD からの差分を主に報告し、続けるかを聞く。
4. W は SendMessage で再開せず、手渡し（前任の return と記録先を渡して新しい W を起こす）にする。引き継ぎの「前任 W」が `手渡し: 可` のとき、または `手渡し: 不要`（前任の W がいない。最初の W を起こす前に止まった場合など）のときに新しい W を起こす。`可` は前任の return と記録先を渡す手渡しで、`不要` は前任がいないので「次に起こす役割」の入力で初回の W を起こす。`手渡し: 不可` のときは W を起こさず、理由を主に報告して指示を聞く。G は従来どおり段ごとに新しく起こす。
5. 実行先: 引き継ぎに明示の実行先オプションがあれば、再推測せずそのまま使う（主の返事に同じオプションが無いときは引き継ぎの値を使う）。自動選択のときは、次に起こす役割が属する phase の選択結果が引き継ぎの「実行先」の指すコメント（最初の phase は develop 開始コメント、以降は dispatch 記録）にあれば、その構成・executor・account・model を続け、選び直さない（開始済みの role は途中で切り替えない）。どちらのコメントにも選択結果が無い（未開始の）phase だけ、その phase の開始時に adapter で自動選択を評価する。
6. PR トークン上限の計測の `--cap` には、記録先の最新の `PR トークン上限:` コメントの値を使う。

**守備範囲（再開手順が通す入力と守らない入力）**: 再開手順が読む入力は、記録先のコメント（本体・G・主が書く）・主の返事（記録先または対象 PR のコメントか `/develop` の引数）・ラベル・PR の HEAD で、出どころは GitHub の記録先と PR と、引き継ぎの `実行モード` が `channel` のときのチャンネルの返事（このセッションの会話に届いた主の発言）である（チャンネルの返事の扱いは要件「channel モードの保留はチャンネルの返事で再開する」）。拾いたい誤りは、引き継ぎが最新でないまま読まれること、返事が無いまま役割を起こすこと、保留が既に解かれているのに再開を進めること、HEAD が動いているのに気づかず続けること、手渡し不可の前任に代えて W を起こすことの 5 つである。通してよい入力は、項目の並び順が書式と違うコメント、値の前後の空白、返事が引数ではなく記録先か PR のコメントで来たもの、channel の返事がチャンネルで来たもの、HEAD が引き継ぎと同じ PR である。守らないのは、引き継ぎの値（周回の数・要約）が事実と合っているかの検証と、主の返事の真正性（真正性は pr-review-gate 手順 5 が正本で、ここでは確かめない）である。上の 5 つ以外の入力の不備を見つけるたびに検査を足し続けることを、この要件の完了条件にしない（MUST NOT）。

新しいセッションの本体は、前のセッションの会話・名前付きの W への SendMessage・引き継ぎに書かれていない実行先の推測に頼ってはならない（MUST NOT）。

#### Scenario: 返事を添えて新しいセッションで再開する

- **WHEN** 主が新しいセッションで `/develop <記録先>` に返事を添えて起動し、記録先に引き継ぎのコメントがあり、ラベルの付け先に `needs-approval` がある
- **THEN** 本体は引き継ぎのコメントを読み、引き継ぎの「次に起こす役割」どおりに保留の解除の G（または `手渡し: 可` の W の手渡し）を新しく起こし、前のセッションの W に SendMessage しない

#### Scenario: issue が記録先で、ラベルは PR にある

- **WHEN** 記録先が issue で、`needs-approval` が PR に付いており、引き継ぎのラベルの付け先が `PR #N`
- **THEN** 本体は issue ではなく PR #N のラベルを見て再開に進む

#### Scenario: 返事が無いまま起動する

- **WHEN** 主が返事を添えずに `/develop <記録先>` で起動し、引き継ぎのコメントより後に主の回答が無い
- **THEN** 本体は引き継ぎの「主への依頼」を主に見せ直して返事を聞き、返事が来るまで W も G も起こさない

#### Scenario: 引き継ぎのあとで HEAD が動いている

- **WHEN** 引き継ぎのコメントの HEAD と PR の今の HEAD が違う
- **THEN** 本体は差分を主に報告し、続けるかを聞いてから役割を起こす

#### Scenario: 最初の W を起こす前に止まった

- **WHEN** PR トークン上限で最初の W を起こす前に止まり、引き継ぎの「前任 W」が `手渡し: 不要`、返事が「続ける」
- **THEN** 本体は「次に起こす役割」の入力で初回の W を新しく起こす

#### Scenario: 手渡し不可の前任

- **WHEN** 引き継ぎの「前任 W」が `手渡し: 不可` で、返事は届いている
- **THEN** 本体は新しい W を起こさず、理由を主に報告して指示を聞く

#### Scenario: 開始済みの phase の実行先

- **WHEN** 自動選択で、次に起こす役割の phase の選択結果が develop 開始コメントまたは dispatch 記録にある
- **THEN** 本体は記録の構成・executor・account・model で続け、選び直さない

#### Scenario: channel の引き継ぎに返事がチャンネルで届く

- **WHEN** 引き継ぎの `実行モード` が `channel` で、新しいセッションがチャンネルで `#<記録先> 確認した` を受ける
- **THEN** 本体はそのチャンネルの返事を手順 2 の主の回答として使い、`/develop` の引数や PR のコメントを主に求めない

### Requirement: /develop の入口は引き継ぎのある記録先を再開手順へ進める

`commands/develop.md` は、引数で特定した記録先（数字または URL）に `引き継ぎ: 主の返事待ち` のコメントがあるとき、`needs-approval` の有無によらず、通常の入口 0 に進まず、`skills/develop/references/handover.md` の新しいセッションでの再開手順に進めなければならない（MUST）。ラベルの確認は再開手順 3 が行い（記録先ではなく引き継ぎの「ラベルの付け先」で見る。issue が記録先で保留の PR にラベルがある場合があるため）、ラベルが無ければ再開手順が状態を組み立て直して主に報告する（入口の条件と再開手順の条件を揃える）。引数の記録先より後ろの文字列は主の返事として本体に渡す（MUST）。①③の分岐で記録先を特定する挙動は変えない。この分岐の守備範囲（入力の出どころ・拾う誤り・通してよい入力・完了条件にしないこと）は、前の要件の「守備範囲」の段落に従う（MUST）。

#### Scenario: 引き継ぎのある issue 番号で起動する

- **WHEN** `/develop <issue 番号> 許容する` のように記録先と返事を渡し、その記録先に引き継ぎのコメントがある
- **THEN** 本体は入口 0 をやり直さず、再開手順に進み、`許容する` を主の回答として扱う

#### Scenario: 引き継ぎはあるがラベルが無い

- **WHEN** `/develop <記録先>` の記録先に引き継ぎのコメントがあるが、「ラベルの付け先」に `needs-approval` が無い
- **THEN** 本体は入口 0 に進まず再開手順に入り、記録先のコメントから状態を組み立て直して主に報告する

### Requirement: 本体は W の起動指示と再開指示に段を書く

本体は W の起動指示・SendMessage による再開指示・手渡しの起動指示に、`段: spec` / `段: implement` / `段: finish` のいずれか 1 行を書かなければならない（MUST）。`段:` の値は、その起動・再開で本体が W に指示する工程で決めなければならない（MUST）: (1) の spawn と R1 の REQUEST_CHANGES を受けた再開は `spec`、(3a) の再開と G の failed や CI の見張りの `fix` を受けて直させる再開は `implement`、(3b) の再開は `finish` とする。手渡しの起動指示も同じ規則で決める: 前任が工程の途中で止まり（前任の return の 1 行目が `工程完了:` でない）、後任に同じ工程を続けさせるときは前任が担っていた段、前任が工程を終えて（1 行目が `工程完了:`）return したあとに交代させるときは、本体が後任に次に指示する工程の段とする（MUST。例: (3a) を終えた前任の後任に (3b) を指示するなら `finish`、(1) を終えた前任の後任に R1 の REQUEST_CHANGES の修正を指示するなら `spec`）。次に指示する工程は、既存要件「W の (3) は 2 回の return に分かれる」のとおり本体が自分の指示した工程から決め、前任の return の工程名の文字列から決めてはならない（MUST NOT）。保留で止まる本体は、引き継ぎのコメント（既存要件「保留で止まるときは記録先に引き継ぎのコメントを 1 種類の書式で残す」）の「次に起こす役割」が W のとき、その W の起動指示に書く `段:` の値を同じ項目に書かなければならない（MUST）。新しいセッションで引き継ぎから再開する本体は自分の指示した工程を持たないので、W の起動指示の `段:` を引き継ぎの「次に起こす役割」に書かれた値で決めなければならない（MUST）。develop の `SKILL.md`（1 ループの各工程）と `references/handover.md`（引き継ぎの「次に起こす役割」と再開手順）はこの対応を書かなければならない（MUST）。

仕様化しないと判定した W に、本体が同じコンテキストのまま (3a) へ進むよう指示したときは、W は `worker/implement.md` を読んでから進まなければならない（MUST）。`worker/spec.md` はこれを書かなければならない（MUST）。

#### Scenario: SKILL.md が段の値を書く

- **WHEN** develop の `SKILL.md` の 1 ループを読む
- **THEN** `段: spec`・`段: implement`・`段: finish` がそれぞれ、対応する W の起動・再開の場面とともに書かれている

#### Scenario: 手渡しで同じ工程を続けさせる

- **WHEN** 本体が (3a) の途中で `工程中断:` を返した前任の後任を起こし、(3a) を続けさせる
- **THEN** 後任の起動指示の `段:` は `implement` である

#### Scenario: 工程を終えた前任の後任に次の工程を指示する

- **WHEN** 本体が `工程完了: 実装＋verify` を返した前任の代わりに後任を起こし、(3b) を指示する
- **THEN** 後任の起動指示の `段:` は `finish` で、前任が担っていた `implement` ではない

#### Scenario: 新しいセッションで引き継ぎから W を起こす

- **WHEN** 新しいセッションの本体が、「次に起こす役割」に W と `段: implement` が書かれた引き継ぎのコメントから再開して W を起こす
- **THEN** 本体は W の起動指示に `段: implement` を書く

#### Scenario: 仕様化しない経路でそのまま進むとき

- **WHEN** `worker/spec.md` の仕様化しないと判定した場合の段落を読む
- **THEN** 本体が同じコンテキストで (3a) へ進むよう指示したら `worker/implement.md` を読んでから進むことが書かれている

### Requirement: レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける

`skills/develop/references/fix-check.md` は、節「レビューの周を主に聞かずに続ける（直し方の判定）」を 1 か所だけ持ち、仕様レビュー（R1）と PR のレビュー（G）の両方について、2 周目以降の周の終わりに止める指摘が残ったときの本体の手順の正本としなければならない（MUST）。`references/roles/spec-reviewer.md` と `skills/pr-review-gate/stages/triage.md` は規則を短く書いてこの節を指し、判定の記録と事後報告の書式を再掲してはならない（MUST NOT）。

**規則**: 2 周目以降の周の終わりに残った止める指摘（仕様レビューは R1 の `REQUEST_CHANGES` の BLOCKER、PR のレビューは G が `needs-fix-check` で渡した指摘）がすべて直し方の決まったもので、PR トークン上限の計測が exit 2 でなければ、本体は主に聞かず次の周を回し、記録先に事後報告を残す（MUST）。主に聞くのは、直し方の判定が「選び直しが要る」とき（入力不足で判定が出なかったときを含む）と、PR トークン上限の計測が exit 2 のときの 2 つだけとする（MUST）。interactive と unmanned で同じに扱う（MUST）。主に聞かずに回す周の回数に上限を置かない（MUST NOT。止めるのは PR トークン上限、直し方の判定、PR 側の順 6 の「PR ごとに 1 回まで」）。

**判定役**: 本体が決める役を `subagent_type: dev-workflow:decider` で起こす（MUST）。モデルは仕分け表の順 6 の決める役と同じく残量モードどおりとし、`model` を明示する（MUST）。description には記録先番号 `#N` を入れる（MUST。PR トークン上限の計測に含めるため）。起こす前に PR トークン上限を計測し、exit 2 なら起こさずに exit 2 の手順で止まる（MUST）。G・本体・レビュアーの申告を判定の代わりにしてはならない（MUST NOT）。

**「直し方が決まっている」の定義**: 指摘ごとに、①直し方が 1 つに決まる。選択肢が残っていても、どれを選んでも受け入れ条件と利用者に見える振る舞いが変わらず、選ぶのに主の側にしか無い情報（好み・事業判断・許容度）が要らないなら、決める役が記録先と指摘から 1 つを選び、選んだ直し方とその理由を返答の指摘ごとの直し方に書いたうえで「決まっている」に数える②記録先の範囲（受け入れ条件・issue の範囲）を変えない ③前の周で「決まっている」と判定した直し方を当てたのに閉じなかった指摘ではない、の 3 つをすべて満たすとき「決まっている」とする（MUST）。1 件でも満たさなければ、その周の判定は「選び直しが要る」とする（MUST）。

**入力**: 決める役は `Bash` を持たないので、本体が次を入力文に貼る（MUST）: 記録先の本文と関連コメント（受け入れ条件・`仕様化判断:` の記録・それまでの `直し方の判定:` の記録）、残った指摘の原文（仕様レビューは最新の `仕様レビュー: REQUEST_CHANGES` のコメント、PR のレビューは G の仕分けの PR コメントとレビュアーの要約）、前の周の指摘の原文、対象ファイルのパス（change の artifact、または PR の変更ファイル）、W の直近の return。

**依頼の契約**: 依頼は、順 6 の裁定とマージ可否を問うときと同じ `agents/decider.md` の既存の「可否と根拠」の出力契約で出し、問いを「残った指摘はすべて直し方が決まっているか（可）、1 件でも選び直しが要るか（否）」の 1 つにする（MUST）。決める役が通常の 3 点（原因の分類・直す箇所と方法・次の実行役のモデル）で返す取り違えを防ぐため、依頼文に「3 点ではなく可否と根拠で返す」ことを書く（MUST）。`agents/decider.md` の入力契約と出力契約は変えない（MUST NOT。「G の needs-decider を受けた本体の動き」Requirement と同じ扱い）。

**返答の 1 行目**: 依頼文で返答の 1 行目を `裁定: 可`（すべて決まっている）・`裁定: 否`（1 件でも選び直しが要る）・`不足: <足りないもの>` のどれかちょうどに指定し、2 行目以降に指摘ごとの直し方（1 行）か選び直しが要る理由（選択肢、または変わる範囲）を書かせる（MUST）。本体は 1 行目だけで分岐する（MUST。本文の読み取りで分岐しない）。1 行目が `不足:` か 3 形のどれにも一致しなければ、足りないものを補って同じ問いで 1 回だけ依頼し直し、2 回目も同じなら「選び直しが要る」として扱う（MUST）。

**判定の記録**: 本体は返答を受け取ったら、記録先に判定の記録のコメントを投稿する（MUST。決める役は投稿できないので代理投稿する。PR のレビューでも G ではなく本体が投稿する）。1 行目は正規表現 `^直し方の判定: (決まっている|選び直しが要る)$` に完全一致させ（MUST。太字・全角コロン・末尾句点を付けない）、2 行目以降に次を `項目名: 値` で書く（MUST）: `対象:`（`仕様レビュー` または `PR レビュー（PR #N）`）、`周:`（何周目の終わりか）、`判定役:`（`dev-workflow:decider`・モデル・本体が代理投稿）、`指摘ごとの判定:`（続く行に 1 行 1 件で、指摘の要約と原文の URL、直し方か選び直しの理由）、`入力不足:`（`なし`、または 2 回目も不足で「選び直しが要る」とした場合の足りなかったもの）。

**続行と事後報告**: 判定が「決まっている」なら、本体は仕様レビューでは W を `段: spec` で再開して artifact を直させ R1 に次の周の差分再レビューをさせ、PR のレビューでは判定の記録の URL と裁定を渡して照合と振り分けの G を新しく起こす（MUST）。各 spawn・再開の前の PR トークン上限の計測は省かない（MUST）。主に聞かずに回した周の結果を本体が受け取ったら（仕様レビューは R1 の結果、PR のレビューはその周の照合と振り分けの G の return）、記録先に事後報告のコメントを投稿する（MUST）。1 行目は正規表現 `^主に聞かずに回した周: [0-9]+ 周目$` に完全一致させ（MUST）、2 行目以降に `対象:`・`残っていた指摘:`（前の周の終わりに残った指摘の要約を 1 行 1 件、またはそれを載せたコメントの URL）・`判定の根拠:`（判定の記録のコメント URL）・`使ったトークン:`（周の前の合計 → 周のあとの合計、その差、上限）・`周の結果:`（その周のレビュー結果）を書く（MUST）。`使ったトークン:` の 2 つの値は、本体が spawn・再開の前に毎回とる PR トークン上限の計測の値を使う（周の前は直し方の判定の決める役を起こす前の計測、周のあとは周の結果を受け取ったあと最初の計測。MUST。新しい計測の仕組みを足さない）。

**主に聞くとき**: 判定が「選び直しが要る」なら、仕様レビューでは `needs-approval` を付けて主に聞き（`dev-workflow-spec-review` の「仕様レビューは 2 周で確定し結果を issue に記録する」Requirement）、PR のレビューでは判定の記録の URL と裁定を渡して照合と振り分けの G を新しく起こし、G が順 5 に当てる（MUST）。仕様レビューで主に聞くときの引き継ぎのコメントは「保留で止まるときは記録先に引き継ぎのコメントを 1 種類の書式で残す」Requirement の場面「レビューの 2 周キャップ超え」として書き、待ち理由は `2 周キャップ超え` とする（MUST）。

この判定の守備範囲は、レビューの 2 周目以降の周の終わりに残った指摘（仕様レビューの R1 の BLOCKER、PR のレビューで G が `needs-fix-check` で渡した指摘）について、主の判断が要る指摘を主に聞かずに進めてしまうことを防ぐことである。拾いたいのは、選ぶのに主の側にしか無い情報が要る、または選択肢によって受け入れ条件や利用者に見える振る舞いが変わる設計の選択肢から選ぶ必要がある指摘・記録先の範囲を変える指摘・前の周で決まっているとした直し方で閉じなかった指摘で、これらは主に上げる。直し方が 1 つに決まる指摘（例: 受け入れ条件の文と artifact の 1 文が食い違い、artifact 側を受け入れ条件に合わせれば閉じる BLOCKER。同じ文言が別の場所に残っている指摘）と、選択肢の違いが受け入れ条件と利用者に見える振る舞いを変えない指摘（例: BLOCKER を閉じるテストを、外から親を一時停止して書くか、本体にテスト用の待ちを入れて書くか。どちらでも実装の振る舞いは同じ）は主に聞かずに通す。判定が「決まっている」とした直し方が外れることは防がない（次の周の終わりの判定の ③ で拾う）ので、判定の誤りが 1 件も無いことをこの手順の完了条件にしない。

#### Scenario: 正本の節が 1 か所にある
- **WHEN** `skills/develop/references/fix-check.md`・`references/roles/spec-reviewer.md`・`skills/pr-review-gate/stages/triage.md` を読む
- **THEN** 判定役・定義・入力・返答の 1 行目・判定の記録と事後報告の書式は `references/fix-check.md` の節「レビューの周を主に聞かずに続ける（直し方の判定）」にだけあり、ほかの 2 つはその節を指している

#### Scenario: 主に聞く条件が 2 つだけ書かれている
- **WHEN** `references/fix-check.md` の節「レビューの周を主に聞かずに続ける（直し方の判定）」を読む
- **THEN** 主に聞くのは「方針の選び直しが要る」と「PR トークン上限を超える（`pr-token-budget.sh` が exit 2）」の 2 つだけと書かれている

#### Scenario: 判定は可否と根拠の契約で依頼する
- **WHEN** `references/fix-check.md` の節「レビューの周を主に聞かずに続ける（直し方の判定）」を読み、この change の前後で `plugins/dev-workflow/agents/decider.md` を比べる
- **THEN** 節には依頼を `agents/decider.md` の「可否と根拠」の契約で出し、3 点ではなく可否と根拠で返すよう依頼文に書くことが書かれ、`agents/decider.md` には差分が無い

#### Scenario: 判定の入力が固定されている
- **WHEN** `references/fix-check.md` の節「レビューの周を主に聞かずに続ける（直し方の判定）」を読む
- **THEN** 入力として、記録先の本文と関連コメント・残った指摘の原文・前の周の指摘の原文・対象ファイルのパス・W の直近の return の 5 つが書かれている

#### Scenario: 1 回目の入力不足は補って依頼し直す
- **WHEN** 決める役の返答の 1 行目が 1 回目だけ `不足: <足りないもの>` で、依頼し直した 2 回目が `裁定: 可`
- **THEN** 本体は 1 回目を判定として扱わず、足りないものを補って同じ問いで 1 回だけ依頼し直し、2 回目の `裁定: 可` で判定の記録（`入力不足: なし`）を投稿して続行する。3 回目の依頼はしない

#### Scenario: 2 回とも入力不足
- **WHEN** 決める役の返答の 1 行目が 2 回続けて `不足:` で始まる
- **THEN** 本体は「選び直しが要る」として判定の記録を投稿し（`入力不足:` に足りなかったものを書く）、主に聞く経路に進む

#### Scenario: 前の周で決まっているとした直し方で閉じなかった
- **WHEN** 3 周目の終わりに、2 周目の終わりの判定で「決まっている」とされた BLOCKER が閉じずに残る
- **THEN** 決める役はその指摘を「選び直しが要る」とし、本体は主に聞く

#### Scenario: 主に聞かずに回した周の事後報告
- **WHEN** 直し方の判定で開いた 3 周目の R1 の結果を本体が受け取る
- **THEN** 本体は 1 行目 `主に聞かずに回した周: 3 周目` のコメントを記録先に投稿し、残っていた指摘・判定の記録の URL・周の前とあとのトークンの合計とその差と上限・周の結果を書く

#### Scenario: 振る舞いを変えない選択肢は決める役が選ぶ
- **WHEN** 2 周目の終わりに残った BLOCKER の直し方に 2 つのテストの書き方があり、どちらを選んでも受け入れ条件と利用者に見える振る舞いが変わらない
- **THEN** 決める役はどちらか 1 つを選んで理由とともに返し、判定は「決まっている」になり、本体は主に聞かず次の周を回す

#### Scenario: 選択肢で振る舞いが変わるなら主に聞く
- **WHEN** 残った BLOCKER の直し方の選択肢によって、利用者に見える振る舞いか受け入れ条件が変わる
- **THEN** 判定は「選び直しが要る」になり、本体は主に聞く

### Requirement: 保留の許容は会話の返事で受け、PR へのコメントを求めない

この要件の案内と、会話で受けた許容に PR へのコメントを求めない決まりは、interactive の本体のものである。channel の本体は、要件「channel モードのリスク許容はチャンネルの返事を確かめられるときだけチャンネルで受ける」と「channel モードの保留はチャンネルの返事で再開する」に従う（MUST。チャンネルの返事を確かめられるセッションでは、チャンネルの返事を会話で受けた回答として同じく PR へのコメントを求めない）。interactive の本体では、`skills/develop/references/handover.md` の「保留で止まるときの引き継ぎ」の主への案内は、リスク許容の返事について「このセッションの会話で返すか、新しいセッションで `/develop <記録先> 許容する` と打てばよく、PR へのコメントは要らない」と書かなければならない（MUST）。本体は会話で許容の返事を受けたら、主に PR へのコメントを求めてはならず（MUST NOT）、保留の解除の G に、自分のセッション ID（`$CLAUDE_CODE_SESSION_ID`）・その発言の日時（会話ログの timestamp）・原文を渡さなければならない（MUST）。新しいセッションでの再開手順は、`/develop` の引数の残り（`許容する` など）を会話で受けた回答として扱い、その新しいセッションのセッション ID・日時・原文を同じく G に渡さなければならない（MUST）。ただし Orca 経路のエピックの子が親経由でリスク許容を受けたとき（会話に届いた入力が `主の返事（親エピック #<E> 経由）:` で始まるとき、または起動し直されたセッションの最初の指示の引数の残りのうち、起動し直しの括弧 `（エピック #<E> の子。返事を受けて起動し直し）` のうしろが `主の返事（親エピック #<E> 経由）:` で始まるとき）は、自分のセッション ID・日時・原文を渡さず、要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」の手順（`owner-reply-check.sh --relayed`）で確かめてから G に渡さなければならない（MUST）。この手順は `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」の「親から届いた返事」に書き、再開手順の手順 2 より先に当てる。再開手順の本文は変えない（MUST）。記録の書式と真正性確認は pr-review-gate の手順 5 が正本で、develop の手順書（SKILL.md と `references/epic-child-stop.md`）には書式を再掲しない（MUST NOT）。（起動し直しで届いた親経由の許容の Scenario は、要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」の「起動し直しの指示に付いて届いた親経由の許容を確かめる」が正本）

#### Scenario: 案内に会話の返事と /develop の引数がある

- **WHEN** `skills/develop/references/handover.md` の「保留で止まるときの引き継ぎ」の主への案内を読む
- **THEN** 会話で返すか `/develop <記録先> 許容する` と打てばよく、PR へのコメントは要らないことが書かれている

#### Scenario: 新しいセッションで引数に許容を添えて再開する

- **WHEN** 主が新しいセッションで `/develop 721 許容する` と打ち、記録先に引き継ぎのコメントがある
- **THEN** 本体は `許容する` を会話で受けた回答として、新しいセッションのセッション ID・日時・原文を保留の解除の G に渡し、主に PR へのコメントを求めない

#### Scenario: channel では新しいセッションの案内を出さない

- **WHEN** channel の本体がリスク許容の保留で主に案内する
- **THEN** 案内に `/develop <記録先> 許容する` と新しいセッションを開く案内が無く、チャンネルの返事を確かめられないセッションでだけ PR のコメントを案内する

### Requirement: epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` に加えて `mark` と `reap` を持たなければならない（MUST）。どちらも LLM を呼んではならない（MUST NOT）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち、次の 5 点に優先する。サブコマンドを `route`・`launch`・`wait` とする規定／`wait` が stdout にちょうど 1 行を出す規定／`wait` の子が 0 件なら使い方を出す規定／「失敗したポーリング」の定義（`--watch-done` が 1 つ以上あるときは、一覧の取得の失敗も失敗したポーリングに数える）／`wait` の終わり方の列挙（`closed`・`timeout`・`error gh` に、`done` と `error workspaces` が加わる）。

`mark` と `reap` は、環境変数 `EPIC_DISPATCH_PARENT_EPIC` の有無によらず同じに動かなければならない（MUST。並列起動された子のセッションは `EPIC_DISPATCH_PARENT_EPIC` を持ったまま自分のループを終えて `mark` を呼び、`reap` を呼ぶのは親セッションなので、どちらもこの変数の影響を受けない）。

この要件で `<ブランチ>` は、一覧の `branch` から先頭の `refs/heads/` を外した名前を言う。

**`mark <done|waiting> <issue>`** は、今いるワークスペースに印を付ける。`done` は Orca のボードの列 `completed`、`waiting` は `in-review` に対応させる（MUST）。次の順で動かなければならない（MUST）。

- 1 つ目の引数が `done` / `waiting` のどちらでもない、`<issue>` が数字でない、引数の数が 2 でないときは、stderr に使い方を出して exit 1 で終わる
- `orca` が PATH に無いか、`orca worktree current --json` が非 0 で終わるときは、stdout に `skipped <issue> no-workspace` の 1 行を出して exit 0 で終わる。ほかの `orca` のコマンドを呼んではならない（MUST NOT）。印の代わりになるもの（ファイルなど）を作ってはならない（MUST NOT）
- `orca worktree current --json` の `.result.worktree.linkedIssue` が `<issue>` と一致しないとき（null を含む）は、`orca worktree set` を呼ばず、stdout に `skipped <issue> not-linked` の 1 行を出して exit 0 で終わる
- 一致するときは `orca worktree set --worktree current --workspace-status <completed|in-review>` を 1 回呼び、exit 0 なら stdout に `marked <issue> <done|waiting>` の 1 行を出して exit 0、非 0 なら `failed <issue>` の 1 行を出して exit 1 で終わる。`orca` 自身の出力は stderr に流す（SHALL）

**`wait [--interval <sec>] [--timeout <sec>] [--watch-done <N>]... [<child>...]`** は、`--watch-done` が 1 つも無いときは今までどおりに動き、`orca` を呼んではならない（MUST NOT）。`--watch-done` が 1 つ以上あるときは次のとおり動かなければならない（MUST）。

- 位置引数の子が 0 件でも受け付ける。`--watch-done` の値が数字でなければ stderr に使い方を出して exit 1 で終わる
- ポーリングを始める前に `orca worktree current --json` で今の repo の `repoId` を得る。`orca` か `jq` が PATH に無い、このコマンドが非 0 で終わる、`repoId` が取れないときは、stderr に理由を出し、stdout に何も出さず exit 1 で終わる
- ポーリングごとに、位置引数の子の `gh` の確認（今までどおり）のあと、`orca worktree list --json` を 1 回だけ呼ぶ。`--watch-done` の子 `<N>` は、一覧に `repoId` が同じ・`linkedIssue` が `<N>`・`isArchived` が true でない・`workspaceStatus` が `completed` のワークツリーがあれば「印が付いた」とする。子の数によらず、ポーリング 1 回あたりの `gh` の呼び出しは位置引数の子の数と同じでなければならない（MUST）
- 閉じた子か印が付いた子が 1 件以上あれば、閉じた子がいるとき `closed <N>...`、印が付いた子がいるとき `done <N>...` を、この順で出して exit 0 で終わる（1 行か 2 行）
- 一覧の取得が非 0 で終わるか、`.result.worktrees` が配列でないポーリングは、閉じた子も印が付いた子も無ければ「失敗したポーリング」に数える。失敗したポーリングが 3 回続いたとき、`gh` で失敗した子がいれば `error gh <N>...`、いなければ `error workspaces` の 1 行を出して exit 1 で終わる
- 上限時間に達したら `timeout` に続けて閉じていない位置引数の子の番号を出して exit 2 で終わる。位置引数が 0 件なら `timeout` だけの 1 行とする

**`reap <child>...`** は、印が付いた子のワークスペースを片付ける。子が 0 件か番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。`orca` か `jq` が PATH に無い、`orca worktree current --json` が非 0 で終わるか `repoId`・`id` が取れない、`orca worktree list --json` が非 0 で終わるか `.result.worktrees` が配列でないときは、何も消さず、stdout に何も出さず exit 1 で終わらなければならない（MUST）。一覧は 1 回だけ取る（SHALL）。子ごとに次の順で確かめ、外れた時点でその子についてはそれ以上何も呼ばず、対応する 1 行を出して次の子へ進まなければならない（MUST）。同じ呼び出しの中で 2 回目以降に現れた番号は何もせず行も出さない（SHALL）。

1. 一覧のうち、`repoId` が今のワークツリーと同じ・`linkedIssue` が `<N>`・`isArchived` が true でないワークツリーを子の候補とする。0 件なら `gone <N>`、2 件以上なら `kept <N> ambiguous`
2. 候補の `isMainWorktree` が true、または `parentWorktreeId` が今のワークツリーの `id` と一致しなければ `kept <N> not-child`（この確認は要件「Orca の印を正本にした既存要件を状態の記録の項目で読み替える」により行わない）
3. 候補の `workspaceStatus` が `completed` でなければ `kept <N> not-done`
4. `git -C <子のパス> status --porcelain` が非 0 なら `kept <N> git-failed`、出力が空でなければ `kept <N> dirty`
5. `<子のパス>/LLM` が存在すれば `kept <N> llm-logs`
6. 候補の `branch` が `refs/heads/` で始まらなければ `kept <N> no-branch`
7. マージ済み PR の先端（`headRefOid`）と `git -C <子のパス> rev-parse HEAD` の出力（以下 HEAD）が一致するかを、次の 2 段で確かめる。最終判定はどちらも「`headRefOid` が HEAD と完全一致する行がある」ことで、一致の条件は変えない
   1. `gh pr list --head <ブランチ> --state merged --json headRefOid --jq '.[].headRefOid'` が非 0 なら `kept <N> pr-lookup-failed`。出力のどれかの行が HEAD と一致すれば 7 を通る
   2. 1 で一致する行が無い（出力が空、または一致しない）ときに限り、ブランチ名を問わずに探す。`gh pr list --state merged --search <HEAD> --json headRefOid --jq '.[].headRefOid'` が非 0 なら `kept <N> pr-lookup-failed`、出力のどれかの行が HEAD と一致すれば 7 を通る（squash マージでは子の HEAD が main の祖先にならず、子のブランチと別名のブランチの PR で入ることがあるため）。一致する行が無ければ、1 と 2 の出力がどちらも空なら `kept <N> no-merged-pr`、どちらかに出力があったなら `kept <N> head-mismatch`

1〜7 をすべて通った子に限り、`orca terminal close --worktree path:<子のパス> --all`、`orca worktree rm --worktree path:<子のパス>` をこの順に呼ばなければならない（MUST。rm は子ごとに 1 回、close は成功すれば 1 回）。`orca worktree rm` に `--force` を付けてはならない（MUST NOT）。close が非 0 で終わったとき（Orca が `terminal_close_incomplete` を返す場合。子のセッションが印を付けた直後でターンをまだ終えておらず、端末を閉じきれないことがある）は、次の順で 1 回だけ閉じ直さなければならない（MUST）。(a) 原因の手がかりとして `orca terminal list --worktree path:<子のパス> --json` を 1 回呼び、その出力を stderr に流す（読めなくても先へ進む）。(b) `EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT` 秒（既定 10。数字でなければ既定）待つ。(c) `orca terminal close` を同じ引数でもう 1 回呼ぶ。閉じ直しで exit 0 になれば、そのまま rm へ進む。閉じ直しも非 0 なら、rm を呼ばずに `kept <N> close-failed` を出し、stderr に主がする操作（どの画面で何をするか。Orca で子のワークスペース `<子のパス>` を開き、動いているターンの終了を待つか端末を手で閉じてから、親で `epic-dispatch.sh reap <N>` をやり直す）を 1〜2 行で出す（MUST）。閉じ直しは 1 回までで、3 回目は呼ばない（MUST NOT）。rm が非 0 なら `kept <N> rm-failed` を出す（MUST）。ただし rm が非 0 で、その stderr に `terminal sweep failed` を含むとき（Orca が端末の片付けを確かめられずに削除を止めたとき）は、理由を `rm-failed-terminal-sweep` にして `kept <N> rm-failed-terminal-sweep` を出す（MUST）。どちらの rm の失敗でも `--force` を付けた再試行をしてはならず、rm は子ごとに 1 回しか呼ばない（MUST NOT。`--force` は端末の片付けの確認だけでなく git の未コミット変更の保護も外すため。Orca を再起動してから `reap` をやり直せば通る見込みで、やり直しは親の判断に残す）。rm の stderr は従来どおり親の stderr にも流す（SHALL）。rm が exit 0 のあと、`git rev-parse --verify --quiet refs/heads/<ブランチ>` が exit 0 で、その出力が 7 で一致した HEAD と同じときだけ、`git worktree list --porcelain` にその子のパスが無くなるまで待ち（`EPIC_DISPATCH_REAP_DETACH_TIMEOUT` 秒を上限、既定 30。確認の回数（上限秒数 ÷ 間隔 + 1 回）か経過秒数のどちらか早い方で止める。`EPIC_DISPATCH_REAP_DETACH_INTERVAL` 秒間隔、既定 1。`git worktree list` が非 0 のときは残っているものとして待つ）、無くなったら、ブランチの先端を読み直して HEAD と同じときだけ `git branch -D <ブランチ>` を呼ぶ（MUST。違えば呼ばずに `reaped <N> branch-kept`）。上限を超えても残っているときは `git branch -D` を呼ばずに `reaped <N> branch-kept` を出す（MUST）。ブランチが無いか、`git branch -D` が exit 0 なら `reaped <N>`、先端が違うか `git branch -D` が非 0 なら `reaped <N> branch-kept` を出す（MUST）。1〜7 のどれかで外れた子、close か rm が失敗した子について、`git branch -D` を呼んではならない（MUST NOT）。stdout には子ごとに 1 行だけを出し、`orca`・`git`・`gh` 自身の出力は stderr に流す（SHALL）。子ごとの行を出し終えたら、`kept` があっても exit 0 で終わる（MUST）。

この要件の守備範囲で入力として扱うのは、develop の本体が `references/epic.md` の手順どおりに渡す番号と、`orca worktree current --json`・`orca worktree list --json` の出力（2026-10-08、Orca 1.4.222 で確かめた `id`・`repoId`・`path`・`branch`・`linkedIssue`・`isArchived`・`isMainWorktree`・`workspaceStatus`・`parentWorktreeId`）に加え、7 の 2 段目で判定する `gh pr list --state merged --search <HEAD>` の出力（`headRefOid` の行。検索が返す PR の絞り込みは信用せず、完全一致だけで判定する）と、`orca terminal close` の終了コード（非 0 なら失敗として閉じ直す。失敗の種類は区別しない）と、閉じ直しの前に呼ぶ診断用の `orca terminal list --worktree path:<子のパス> --json` の出力（stderr に流すだけで、中身は読まず判定に使わない。非 0 でも先へ進む）と、`orca worktree rm` の stderr（`terminal sweep failed` を含むかだけを見る。文言が変わると `rm-failed` に戻り、消す側には倒れない）と、`orca worktree rm` が exit 0 のあとに `git worktree list --porcelain` が返す出力と終了コード（`worktree <パス>` の行だけを見て、対象の子のパスと完全一致する行があるかだけで判定する。非 0 のときは残っているものとして扱う）である。拾いたい誤りは、対象のワークツリーが git に残っている間にそのブランチを消そうとして失敗すること（残っている間は消さずに待つ。上限を超えたら消さずに `branch-kept`）、印が付いていない子・親の `launch` が作っていないワークツリー・push していないコミットや未コミットの変更や `LLM/` を持つワークツリーを消すことである。次は通してよく、この要件では止めない: 一覧に対象以外のパスだけがある（対象のパスは無い。パスの前方一致・部分一致は残っている扱いにしない）ときは待たずにブランチ削除へ進む／Orca の出力の形が変わったときの検知（読めなければ `gone` か `kept` になり、消す側には倒れない）／フォークの同名ブランチのマージ済み PR（HEAD の一致で落ちる）／オーナーがボードで手で `completed` に動かした子（子が付けた印と同じに扱う）／確認から削除までの間に子が積んだコミット（`--force` を付けない rm と、ブランチの先端の比較で残る）。`mark` は `<issue>` の PR がマージ済みかを検査しない（手順書の条件に頼る。誤って付いた印は `reap` の `no-merged-pr`・`head-mismatch` で止まる）。`.gitignore` の対象のうち `LLM/` 以外は守らない（`git status --porcelain` に出ないので、ワークツリーと一緒に消える）。すり抜ける入力が見つかるたびに確認を足すことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、下の Scenario を確かめなければならない（MUST）。

#### Scenario: 自分の issue のワークスペースに完了の印を付ける
- **WHEN** `orca worktree current --json` の `linkedIssue` が 11 のスタブ環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** `orca worktree set --worktree current --workspace-status completed` が 1 回呼ばれ、stdout は `marked 11 done` の 1 行で exit 0

#### Scenario: 確認待ちの印は in-review になる
- **WHEN** `linkedIssue` が 11 のスタブ環境で `epic-dispatch.sh mark waiting 11` を実行する
- **THEN** `orca worktree set` は `--workspace-status in-review` で呼ばれ、stdout は `marked 11 waiting` で exit 0

#### Scenario: 別の issue のワークスペースには印を付けない
- **WHEN** `linkedIssue` が 400（エピックの番号）のスタブ環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** `orca worktree set` は呼ばれず、stdout は `skipped 11 not-linked` で exit 0

#### Scenario: Orca 管理外と orca が無い環境では何もしない
- **WHEN** `orca worktree current` が exit 1 を返すスタブ環境、および `orca` が PATH に無い環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** どちらも `orca worktree set` は呼ばれず、stdout は `skipped 11 no-workspace` で exit 0

#### Scenario: 並列起動された子のセッションでも印を付ける
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=400` を付け、`linkedIssue` が 11 のスタブ環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** `orca worktree set --worktree current --workspace-status completed` が呼ばれ、stdout は `marked 11 done` で exit 0

#### Scenario: 印を付けられなければ failed
- **WHEN** `orca worktree set` が非 0 で終わるスタブ環境で `epic-dispatch.sh mark done 11` を実行する
- **THEN** stdout は `failed 11` で exit 1

#### Scenario: mark の引数の誤りは使い方を出す
- **WHEN** `epic-dispatch.sh mark completed 11`、`epic-dispatch.sh mark done`、`epic-dispatch.sh mark done '#11'` を実行する
- **THEN** どれも `orca` を呼ばず、stderr に使い方が出て exit 1

#### Scenario: issue が open のままでも印が付いた子を検知して終わる
- **WHEN** 子 11 の `gh` が常に `open` を返し、一覧の子 11 のワークツリーが 2 回目のポーリングから `workspaceStatus: completed` になるスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11 11` を実行する
- **THEN** stdout は `done 11` の 1 行で exit 0、`gh` の呼び出しは 2 回

#### Scenario: 閉じた子と印が付いた子が同じポーリングにいれば 2 行を出す
- **WHEN** 子 12 の `gh` が `closed` を返し、一覧の子 11 のワークツリーが `completed` のスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11 --watch-done 12 12` を実行する
- **THEN** stdout は `closed 12`、`done 11` の順の 2 行で exit 0

#### Scenario: 位置引数が無くても印だけを待てる
- **WHEN** 一覧の子 11 のワークツリーが `in-review` のままのスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** `gh` は呼ばれず、stdout は `timeout` の 1 行で exit 2

#### Scenario: --watch-done が無ければ orca を呼ばない
- **WHEN** 子 11 の `gh` が `closed` を返すスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11` を実行する
- **THEN** stdout は `closed 11` の 1 行で exit 0、`orca` は 1 回も呼ばれない

#### Scenario: 別の repo や archive されたワークツリーの印は数えない
- **WHEN** 一覧に、`repoId` が違う `linkedIssue` 11 の `completed` のワークツリーと、`isArchived` が true の `linkedIssue` 11 の `completed` のワークツリーだけがあるスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout` で exit 2

#### Scenario: 一覧を取れないポーリングが 3 回続いたら error で終わる
- **WHEN** `orca worktree list` が常に非 0 で終わるスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 3 回のポーリングのあと stdout は `error workspaces` の 1 行で exit 1

#### Scenario: 条件をすべて満たす子は端末を閉じてからワークツリーを消す
- **WHEN** 一覧の子 11 のワークツリーが、同じ `repoId`・`parentWorktreeId` が今のワークツリーの `id`・`isMainWorktree` が false・`workspaceStatus` が `completed`・`branch` が `refs/heads/oratta/issue-11` で、`git status --porcelain` が空、`LLM/` が無く、マージ済み PR の `headRefOid` がワークツリーの HEAD と同じスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close --worktree path:<子> --all` と `orca worktree rm --worktree path:<子>` がこの順に 1 回ずつ呼ばれ、どの `orca` の呼び出しにも `--force` が無く、stdout は `reaped 11` の 1 行で exit 0

#### Scenario: 条件を外れた子は消さずに理由を出す
- **WHEN** 上の Scenario から 1 点だけを変えたスタブ環境（`workspaceStatus` が `in-review`／ワークツリーの HEAD が PR の `headRefOid` と違う／`git status --porcelain` に出力がある／`<子>/LLM` がある）それぞれで `epic-dispatch.sh reap 11` を実行する
- **THEN** どの場合も `orca terminal close`・`orca worktree rm`・`git branch -D` は 1 回も呼ばれず、stdout は順に `kept 11 not-done`・`kept 11 head-mismatch`・`kept 11 dirty`・`kept 11 llm-logs` の 1 行で exit 0

#### Scenario: マージ済みの PR が無い子と、PR を調べられない子は消さない
- **WHEN** `gh pr list` の出力が空のスタブ環境、および `gh pr list` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca worktree rm` は呼ばれず、stdout は順に `kept 11 no-merged-pr`・`kept 11 pr-lookup-failed` で exit 0

#### Scenario: 別名のブランチで入った子は先端が HEAD と一致すれば片付ける
- **WHEN** `gh pr list --head oratta/issue-11` の出力が空で、`gh pr list --state merged --search <HEAD>` の出力に HEAD と同じ `headRefOid` の行があるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` と `orca worktree rm` が 1 回ずつ呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: ブランチ名を問わない検索でも先端が一致しなければ消さない
- **WHEN** `--head` の出力が空で、`--search <HEAD>` の出力が空のスタブ環境、`--search <HEAD>` の出力が HEAD と違う `headRefOid` だけのスタブ環境、`--search <HEAD>` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca worktree rm` は呼ばれず、stdout は順に `kept 11 no-merged-pr`・`kept 11 head-mismatch`・`kept 11 pr-lookup-failed` で exit 0

#### Scenario: ワークツリーが既に無い子は gone
- **WHEN** 一覧に `linkedIssue` が 11 のワークツリーが無いスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git` も `gh` も呼ばれず、stdout は `gone 11` で exit 0

#### Scenario: 残ったブランチは先端が PR の最終コミットと同じときだけ消す
- **WHEN** `orca worktree rm` のあともローカルブランチ `oratta/issue-11` が残り、その先端が PR の `headRefOid` と同じスタブ環境、および先端が違うスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** 前者は `git branch -D oratta/issue-11` が 1 回呼ばれて stdout は `reaped 11`、後者は `git branch -D` が呼ばれず stdout は `reaped 11 branch-kept`、どちらも exit 0

#### Scenario: ブランチが残っていなければ git branch -D を呼ばない
- **WHEN** `orca worktree rm` のあと `git rev-parse --verify --quiet refs/heads/oratta/issue-11` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git branch -D` は呼ばれず、stdout は `reaped 11` で exit 0

#### Scenario: 端末を閉じられなければ 1 回だけ閉じ直し、それでも閉じられなければワークツリーを消さない
- **WHEN** `orca terminal close` が常に非 0 で終わり、待ち時間を 0 秒にしたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` はちょうど 2 回呼ばれ、`orca worktree rm` と `git branch -D` は呼ばれず、stdout は `kept 11 close-failed` の 1 行で exit 0。stderr には主がする操作（`issue-11` のワークスペースを Orca で開いて端末を閉じ、`epic-dispatch.sh reap 11` をやり直す）が出る

#### Scenario: 1 回目の閉じが不完全でも、閉じ直しで成功すれば片付ける
- **WHEN** `orca terminal close` が 1 回目は非 0、2 回目は exit 0 で終わるスタブ環境（ほかは全部の確認を通る子）で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` はちょうど 2 回呼ばれ、`orca worktree rm` が 1 回呼ばれ、stdout は `reaped 11` の 1 行で exit 0

#### Scenario: 端末の片付けの失敗で止まった rm は別の理由で返し、強制しない
- **WHEN** 条件をすべて満たす子 11 について、`orca worktree rm` が非 0 で終わり stderr に `terminal sweep failed` を含むスタブ環境、および非 0 で終わるが stderr にそれを含まないスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** 前者は stdout が `kept 11 rm-failed-terminal-sweep`、後者は `kept 11 rm-failed`、どちらも exit 0。`orca worktree rm` はどちらも 1 回だけ呼ばれ、どの `orca` の呼び出しにも `--force` が無く、`git branch -D` は呼ばれない。rm の stderr は親の stderr にも出る

#### Scenario: 複数の子は 1 件ずつ判定する
- **WHEN** 子 11 は条件をすべて満たし、子 12 は `workspaceStatus` が `in-review` のスタブ環境で `epic-dispatch.sh reap 11 12` を実行する
- **THEN** stdout は `reaped 11` と `kept 12 not-done` の 2 行で、`orca worktree rm` は子 11 のパスに 1 回だけ呼ばれ、exit 0

#### Scenario: 一覧を取れなければ何も消さない
- **WHEN** `orca worktree list` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close` も `orca worktree rm` も呼ばれず、stdout は空で exit 1

#### Scenario: rm のあとしばらくワークツリーが git に残っても、外れたらブランチを消す
- **WHEN** `orca worktree rm` が exit 0 で、その後 `git worktree list --porcelain` に子のパスが 2 回目の確認まで残り、先端が HEAD と同じブランチが残るスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git branch -D oratta/issue-11` が 1 回呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: 上限を超えても残るなら branch-kept
- **WHEN** `git worktree list --porcelain` が常に子のパスを返し、上限を短くしたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git branch -D` は呼ばれず、stdout は `reaped 11 branch-kept` で exit 0

#### Scenario: 先端が HEAD と違うブランチは待たずに消さない
- **WHEN** ブランチの先端が HEAD と違い、`git worktree list --porcelain` に子のパスが残るスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git worktree list` を繰り返し呼んで待つことはなく、`git branch -D` は呼ばれず、stdout は `reaped 11 branch-kept` で exit 0

#### Scenario: 一覧に対象以外のパスだけがあるときは待たずにブランチを消す
- **WHEN** `git worktree list --porcelain` が `/work/issue-110`（子 11 のパスの前方一致）と別のワークツリーのパスだけを返し、先端が HEAD と同じブランチが残るスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `git branch -D oratta/issue-11` が 1 回呼ばれ、stdout は `reaped 11` で exit 0

### Requirement: Orca 経路の本体は印が付いた子のワークスペースを片付ける
develop の `references/epic.md`「エピックの扱い」の Orca 経路は、次を規定しなければならない（MUST）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」の Orca 経路の規定に加わる。

- 本体は `epic-dispatch.sh wait` に、片付け待ちの子を `--watch-done <N>` で渡す（MUST）。片付け待ちの子は、`launch` に渡して `deferred` 以外を返したことのある子（閉じた子を含む）から、エピックに `子 #N のワークツリーを残した` で始まる行がある子と、このセッションで `reap` が `reaped <N>`（`branch-kept` を含む）か `gone <N>` を返した子と、本体が確かめて消した子（下の `kept` の扱い）を除いたものとする（MUST）。除いたあとにこのセッションの `launch` が `launched <N>` を返した子は片付け待ちに戻す（MUST。前のセッションで起動に失敗した子やワークツリーを手で消した子は `gone` になるが、起動し直すとワークツリーができるため）。除いた子は渡さない（MUST NOT。ワークツリーが無い子は印が付かず、`wait` が最長 6 時間待つため）
- `done <N>...` で起こされたら、本体は `epic-dispatch.sh reap <N>...` を Bash で 1 回呼ぶ（MUST）。wt-clean を呼んではならない（MUST NOT）。子ごとの確認をオーナーに取ってはならない（MUST NOT。子が印を付けたことを承認として扱う）
- `reaped <N>` と `gone <N>` はワークツリーに何もしないが、本体はその子を以後の片付け待ちから外す（MUST）。`reaped <N> branch-kept` はエピックに `子 #N のローカルブランチを残した` と 1 行コメントする。`kept <N> not-done` は待ちを続ける。それ以外の `kept <N> <理由>` は、本体が主に聞かずに次の 2 つを確かめて、消すか残すかを決める（MUST。主には判断材料が無い）。(a) `reap` がそのワークツリーを残した理由が解消していて、未コミットの変更が無い（`git -C <path> status --porcelain` が空、かつ `<path>/LLM` が無い。`LLM/` は gitignore 済みで `status` に出ないが、`reap` は `kept <N> llm-logs` で残す理由にしている。本体は `LLM/` を消さない）。(b) ワークツリーの HEAD が、`launch` の起点ブランチ（`EPIC_DISPATCH_BASE` か `--base`。既定は main）のリモートの今の先端に含まれるか、マージ済みの PR の HEAD に入っている（HEAD がその PR の `headRefOid` と同じか、HEAD の tree が `headRefOid` の tree と同じ。squash でマージされた PR は tree の一致で見る）。対象のワークツリーは、`reap` が `kept <N> ambiguous`（候補が複数）か `kept <N> not-child`（親の子ではない）を返したときは一意にも親の子としても特定できないので、確かめも消しもせず残す（MUST。単一の `<path>` を前提にした削除をしない）。`reap` が `kept <N> close-failed`（1 回閉じ直しても端末を閉じられなかった）を返したときも、子のターンがまだ動いている見込みがあるので確かめも消しもせず残し、エピックに `子 #N のワークツリーを残した（close-failed） — <reap の stderr の owner action の行>` と 1 行コメントする（MUST。どの画面で何をするかを主に渡す）。両方を満たしたら、本体が `orca worktree rm --worktree path:<path>`（`--force` なし）で消し、エピックに `子 #N のワークツリーを確かめて消した（<理由>）` と 1 行コメントして、その子を片付け待ちから外す（MUST。この行は `子 #N のワークツリーを残した` で始めない）。どちらかを満たさないか `rm` が失敗したら、消さずに残し、エピックに `子 #N のワークツリーを残した（<理由>） — <満たさなかったこと、または rm 失敗、または ambiguous / not-child で特定できない>` と 1 行コメントする（MUST）。どちらの場合も主に消すかを聞かない（MUST NOT）

この規定の守備範囲で入力として扱うのは、`reap` の `kept` の行、対象ワークツリーの `git status` と `LLM/` の有無と HEAD、起点ブランチのリモートの先端、マージ済み PR の `headRefOid` である。拾いたい誤りは、消してはいけないもの（未コミットの変更、起点ブランチに入っていない commit、ログ）を含むワークツリーを消すことと、特定できないワークツリーを消すことである。次は通ってよく、この規定では止めない: PR が複数ありどれかの `headRefOid` と一致すれば取り込み済みとみなすこと、HEAD より後の commit が PR に無くても tree が一致すれば消すこと、`gh` や `git` の一時的な失敗で消さずに残すこと。穴を塞ぎ切ることは完了条件にしない（`--force` なしの `rm` が未コミットの変更で止まる安全網があり、取りこぼしは残す側に倒れる）
- `closed` と `done` の 2 行で起こされたら、両方を処理する（MUST）
- 開いている子が無くなったら、片付け待ちの子で `reap` を 1 回呼び、`reaped`・`gone` の子を片付け待ちから外す。残った片付け待ちの子（`kept <N> not-done` の子）が 1 件以上あれば、その子だけを `--watch-done` に渡して（位置引数の子なしで）待つ。0 件なら `wait` を呼ばずに待ちを終える（MUST）。完了条件の確認と報告がまだなら行う。待ちの途中で `done <N>...` で起こされたときも、`reap` の結果で `reaped`・`gone` の子を外して同じに扱う（MUST。このとき読まれるのは `done` で起こされたときの手順なので、動いている子と片付け待ちの子がどちらも 0 件なら `wait` を呼ばずに待ちを終え、完了条件の確認と報告がまだなら行うことを、その手順にも書く）。エピックの完了条件の確認と報告を、この待ちを理由に遅らせない（SHALL）。この待ちが `timeout` で終わっても、下のやめる直前の確認を通すまでは待ちをやめてはならない（MUST NOT）。親が `wait` を呼ばずにターンを終えてよいのは、`references/epic.md` の **待ちをやめてよい条件** のどれかを満たすときだけである（MUST）。その条件は、(a) 動いている子も片付け待ちの子も 0 件になり `clear` まで済ませたとき（下の確認は `clear` の前に行う）、(b) 動いている子も片付け待ちの子も 0 件で後回しの子だけが残り主に報告して止まるとき、(c) 手順 6 と 7 の `error`・`failed`、`launch` が子を 1 件も作らず exit 1 で終わったこと、`adopt` の失敗、`wait`・`reap`・`pending-owner` が stdout に何も出さず exit 1 で終わったことを主に報告して止まるとき、(d) 片付け待ちの子だけを待つ `wait` が `timeout` で終わったとき、(e) 主がやめるよう言ったとき、の 5 つとする。動いている子が残るあいだに `timeout` が続く・変化が無い・待ちが長い・主に上げた・主の返事待ちの子が残っている・親の側の予算や時間は、やめる理由にしない（MUST NOT）。(a)〜(d) でやめる直前には、`launch` に渡したことのある子のうち issue が開いている子（開いた子）について、主の返事待ちで止まった子が無いことを、`epic-dispatch.sh wait --interval 0 --timeout 0 --watch-stopped <開いた子>...`、`epic-dispatch.sh pending-owner <開いた子>...`、開いた子の issue の `needs-approval` ラベルの有無で確かめる（MUST。開いた子が 0 件なら呼ばずに、報告に確かめる子が無かったと書く）。(1) が `stopped`・`closed` の行を返した、(2) が手順 7 の照合で外さなかった `pending <N>` を返した、または `needs-approval` の子がいたときは、(a)(b)(d) ではやめずに返った行を `references/epic.md` の手順 4・8 で処理して待ちに戻り、(c) では見つかった子を止まる報告に書く（MUST）。(1) か (2) が exit 1 で終わったか、stderr に何か出たときは、報告に確かめられなかった子の番号と stderr を書く（MUST）。やめるときの報告には、確かめたことと残っている子の番号を書く（MUST）
- `回し方: Orca` を引き継いで再開したら、`launch` の前に、`launch` に渡したことのある子（閉じた子を含む。`子 #N のワークツリーを残した` の行がある子も除かない）で `reap` を 1 回呼び、`reaped`・`gone` の子を片付け待ちから外す（SHALL。再開したセッションは前のセッションの `reap` の結果を持たないので、この 1 回で作り直す）。そのあとの `launch` を終えて、動いている子と片付け待ちの子がどちらも 0 件なら `wait` を呼ばずに待ちを終え、完了条件の確認と報告がまだなら行う（MUST）
- `wait` の `error workspaces` は `error gh ...` と同じく、ユーザーに報告して止まる（MUST）
- `--watch-done` か `--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わったら（stderr に `not in an Orca-managed worktree` などが出て、今のワークツリーを Orca から読めない）、`launch` の exit 1 と同じく、Orca の親ワークツリーで開き直すようユーザーに報告して止まる（MUST）。stderr が `usage:` を含むときは、stderr を添えて設定の誤りとして報告して止まる（MUST）

#### Scenario: Orca 経路に片付けの手順が書かれている
- **WHEN** `references/epic.md` の「回し方」を読む
- **THEN** `wait` に `--watch-done` を付けること、`done` で起こされたら `reap` を 1 回呼ぶこと、`kept` の子は本体が未コミットの変更の有無と HEAD の取り込み済みを確かめ、満たせば消してエピックに `子 #N のワークツリーを確かめて消した（<理由>）`、満たさなければ残して `子 #N のワークツリーを残した（<理由>） — <満たさなかったこと>` とコメントし、どちらも主に聞かないこと、`not-done` は待ちを続けること、`reaped`・`gone` の子を片付け待ちから外すこと、開いている子が無くなったあとは確認待ちの子だけを待つこと、待ちをやめてよいのは `references/epic.md` の待ちをやめてよい条件を満たしたときだけで、`timeout` で終わっても確認を通すまではやめないこと、やめる前に開いた子に主の返事待ちで止まった子が無いことを `wait --watch-stopped`・`pending-owner`・`needs-approval` ラベルで確かめること、再開時に `reap` を 1 回呼ぶことが書かれている

#### Scenario: 片付けた子と消えた子は片付け待ちから外れる
- **WHEN** `references/epic.md` の「エピックの扱い」の「回し方」の手順 2〜4 を読む
- **THEN** 片付け待ちの子から `reaped`（`branch-kept` を含む）と `gone` の子を除くことが、手順 2 の集合の定義と手順 3 に書かれ、除いたあとに `launched <N>` を返した子は戻すことが手順 2 に書かれている

#### Scenario: 全 issue が閉じたあと最後の done を片付けたら待たずに終える
- **WHEN** `references/epic.md` の「エピックの扱い」の「回し方」の手順 3（`done <N>...` で起こされたときの手順）を読む
- **THEN** `reap` のあと、動いている子か片付け待ちの子があれば手順 2 に戻ることと、どちらも 0 件なら `wait` を呼ばずに待ちを終え、完了条件の確認と報告がまだなら行うことが、手順 3 の中に書かれている（手順 4 の記述だけでは満たさない。全 issue が閉じたあとの最後の `done` では手順 4 が読まれないため）

#### Scenario: 開いている子が無くなったとき確認待ちの子が無ければ待たずに終える
- **WHEN** `references/epic.md` の「エピックの扱い」の「回し方」の手順 4（`closed <N>...` で起こされたときの手順）を読む
- **THEN** 開いている子が無くなったあと、`reaped`・`gone` を外した片付け待ちの子が 0 件なら `wait` を呼ばずに待ちを終えること、`kept <N> not-done` の子が残っているときだけその子を `--watch-done` に渡して待つことが手順 4 に書かれている

#### Scenario: 再開して動かす子も片付け待ちの子も無ければ待たずに終える
- **WHEN** `references/epic.md` の「エピックの扱い」の「回し方」の手順 7（`回し方: Orca` を引き継いで再開したときの手順）を読む
- **THEN** `reap` と `launch` のあと、動いている子と片付け待ちの子がどちらも 0 件なら `wait` を呼ばずに待ちを終え、完了条件の確認と報告がまだなら行うことが手順 7 に書かれている

#### Scenario: --watch-stopped 付きの wait が Orca から読めずに終わったら親ワークツリーで開き直す
- **WHEN** `references/epic.md` の「エピックの扱い」の「回し方」の手順 6 を読む
- **THEN** `--watch-done` か `--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わった場合に、報告に「親ワークツリーで開き直す」と書くことが書かれている

#### Scenario: 残された子のワークツリーを本体が確かめて決める
- **WHEN** `reap` が `kept <N> unmerged-commits` や `kept <N> rm-failed` を返し、本体が `references/epic.md` の手順 3 に従う
- **THEN** 本体は残された理由の解消と未コミットの変更・`LLM/` の有無と HEAD の取り込み済み（設定された起点ブランチ（`EPIC_DISPATCH_BASE` / `--base`、既定 main）のリモートの先端への包含、またはマージ済み PR の HEAD との一致・tree の一致）を確かめ、満たせば `orca worktree rm` で消して `子 #N のワークツリーを確かめて消した（<理由>）` を、満たさなければ残して `子 #N のワークツリーを残した（<理由>） — <満たさなかったこと>` をエピックにコメントし、主に消すかを聞かない

#### Scenario: 特定できないワークツリーは消さずに残す
- **WHEN** `reap` が `kept <N> ambiguous` を返した
- **THEN** 本体は確かめも `orca worktree rm` もせず、エピックに `子 #N のワークツリーを残した（ambiguous）` で始まる 1 行をコメントし、主に聞かない

#### Scenario: 端末を閉じられなかったワークツリーは確かめずに残し、主の操作を添える
- **WHEN** `reap` が `kept <N> close-failed` を返し、stderr に `owner action for #<N>: ...` の行を出した
- **THEN** 本体は確かめも `orca worktree rm` もせず、エピックに `子 #N のワークツリーを残した（close-failed） — ` に続けてその `owner action` の行を書いた 1 行をコメントする

#### Scenario: LLM/ が残るワークツリーは消さない
- **WHEN** `reap` が `kept <N> llm-logs` を返した（`git status` は空）
- **THEN** 本体は `<path>/LLM` があるので確認 (a) を満たさず、消さずに残して `子 #N のワークツリーを残した（llm-logs） — LLM/ が残っている` をコメントする

### Requirement: develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする
`plugins/dev-workflow/skills/develop/` 配下のファイルは、`orca` を実行する書き方（`orca worktree ...`・`orca terminal ...` など、`orca` の直後に半角英小文字のサブコマンドが続く書き方）を含んではならない（MUST NOT）。例外は 1 つだけで、要件「Orca 経路の本体は印が付いた子のワークスペースを片付ける」で本体が確かめて消すときの `orca worktree rm --worktree path:<path>` を、`references/epic.md` の「エピックの扱い」の回し方の手順 3 に 1 回だけ書いてよい（MAY。`reap` が残したワークツリーを消す判断は本体がその場で行うもので、`epic-dispatch.sh` のサブコマンドにすると `reap` の処理を変えることになるため）。この 1 件と同じ行に別の `orca` のコマンドを書くことと、この書き方を 2 回以上書くことは、例外に含めない（MUST NOT）。手順書には環境によらない動作（「このワークスペースに印を付ける」「印が付いた子のワークスペースを片付ける」）と、それを行う `epic-dispatch.sh` のサブコマンドだけを書く（MUST）。前提の表の `orca` の行、`route` が返す値 `orca`、その条件の説明（`orca` が PATH にある）は、`orca` を実行する書き方ではないので残してよい。指示が届かなかった子の確認は、`launch` が stderr に出した確認のコマンドを指す書き方にする（SHALL）。

`plugins/dev-workflow/` 配下のシェルスクリプト（`*.sh`）のうち、`orca` をコマンドとして書いた行（`orca` が行頭・`;`・`&`・`|`・`(`・`!`・`$(`・`if`/`then`/`do`/`else`/`while`/`until` のあとにあり、半角英小文字のサブコマンドが続く行。文字列とコメントの中の `orca` は数えない）を含むのは、Orca の起動部品 `scripts/epic-launch-orca.sh` だけでなければならない（MUST）。`epic-dispatch.sh` は `orca` のコマンドを直接呼ばず、Orca の起動部品のサブコマンドを呼ぶ（MUST。`launcher` の値・`route` の出力・stderr の文言としての `orca` の語は、コマンドとして書いた行ではないので含んでよい）。`epic-launch-orca.sh` の中では `orca` のコマンドをそのまま呼び、Orca の機能を自前で作り直してはならない（MUST NOT）。Orca が無い環境のための代わりの実装を持ってはならない（MUST NOT。`route` の `subagent` と `mark` の `skipped` のように、何もしないで終わる分岐は代わりの実装に数えない）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、この 2 つの検索の結果を確かめなければならない（MUST）。手順書の検索では、許可した 1 件を出現ごとに取り除いてから残りを探し、行ごと除外してはならない（MUST NOT。同じ行に置いた別の `orca` のコマンドを見逃すため）。この 2 つの検索で拾いたい誤りは、手順書に `orca` のサブコマンドを書き足すことと、`epic-launch-orca.sh` 以外のシェルスクリプトに `orca` の呼び出しを足すことである。変数やコマンド置換を介した呼び出し、`orca` の語を含まない別名など、検索をすり抜ける書き方が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: 手順書に orca を実行する書き方は許可した 1 件しか無い
- **WHEN** `grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` の各行から `orca worktree rm --worktree path:<path>` を 1 回取り除き、残りを `grep -E 'orca [a-z]+'` で探す
- **THEN** 出力は 0 行であり、`grep -rhoF 'orca worktree rm --worktree path:<path>' plugins/dev-workflow/skills/develop` の出力は `references/epic.md` の手順 3 にある 1 行だけである

#### Scenario: 許可した 1 件と同じ行に別の orca のコマンドがあると落ちる
- **WHEN** 手順書の 1 行に `orca worktree rm --worktree path:<path>` と `orca terminal close --all` を並べて書く
- **THEN** 手順書の検索は `orca terminal close` を見つけ、`epic-dispatch.bats` のテストは失敗する

#### Scenario: orca を呼ぶスクリプトは Orca の起動部品 1 本だけ
- **WHEN** `grep -rlE '(^|[;&|(!]|(if|then|do|else|while|until) )[[:space:]]*orca [a-z]+' plugins/dev-workflow --include='*.sh'` を実行する
- **THEN** 出力は `plugins/dev-workflow/scripts/epic-launch-orca.sh` の 1 行だけである

#### Scenario: epic-dispatch.sh に orca のコマンドを足すと落ちる
- **WHEN** `epic-dispatch.sh` を写した一時ファイルに `orca terminal list --json` の 1 行を足し、同じ検索をその写しのあるディレクトリに対して行う
- **THEN** 検索はその写しを出し、照合は失敗する

### Requirement: エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、子のセッションを閉じて同じワークツリーで `/develop #<N>` だけを打ち直しても、親が `launch --note` で渡した注意書きと「エピックの子である」ことが失われないようにしなければならない（MUST）。この要件は、要件「エピックの並列起動は 1 段で止める」のうち `route` が `nested` を返す条件と `launch` の拒否の条件、`references/epic.md` に書かせている親エピックの番号の出どころ（「親エピック（`EPIC_DISPATCH_PARENT_EPIC` の番号）」。この要件では `route` の stderr の `parent epic: #<N>`）、同要件の守備範囲のうち変数の無いセッションに関する 2 項（「この変更の前に起動された子セッションには変数が無く従来どおり展開しうる」は、Orca 経路で作られた子ワークツリーなら親子関係で `nested` になる。「サブエージェント方式で起こされた子（変数が無い）は止まらない」は、そのセッションのワークツリーが親ワークツリーを持てば `nested` になり、持たなければ今までどおり止まらない）、および要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の判定と `launch` の呼び出し順に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

**注意書きのコメント**: `launch --note <text>` は、`orca worktree create` が exit 0 で終わった子ごとに 1 回、端末を作る前に、`gh issue comment <N> --body <本文>` で子 issue にコメントしなければならない（MUST）。本文の 1 行目は `親エピックからの注意書き: #<epic>`、2 行目は空行、3 行目以降は `<text>` そのものとする（MUST）。`--note` が無いとき、`skipped <N>` の子、worktree create が非 0 で終わった子には投稿してはならない（MUST NOT）。worktree create が exit 0 で終わり、その JSON に `path` が無くて `failed <N>` になる子には投稿する（SHALL。ワークツリーが作られていれば次の `launch` で `skipped` になり、投稿の機会が無くなるため）。投稿が非 0 で終わっても、その子の stdout の 1 行と `launch` の exit code を変えてはならず（MUST NOT）、stderr に `note not posted to #<N>` を含む行と、同じ本文を単一引用符で囲んだ `gh issue comment <N> --body '<本文>'` を出す（SHALL）。最初の指示の文面に `<text>` を含める既存の規定は変えない（SHALL）。

**エピックの子の判定**: 次のどちらかが成り立つとき、そのセッションを「エピックの子」とし、親エピックの番号を次のとおりとする（MUST）。

1. 環境変数 `EPIC_DISPATCH_PARENT_EPIC` が空でない。親エピックの番号はその値。このとき `orca` を呼んではならない（MUST NOT）
2. 1 が成り立たず、`orca` と `jq` が PATH にあり、`orca worktree current --json` が exit 0 で終わり、その `.result.worktree.parentWorktreeId` が空でも `null` でもなく、`orca worktree list --json` の `.result.worktrees[]` のうち `id` がその値と一致するワークツリーの `linkedIssue` が `null` でない。親エピックの番号はその `linkedIssue`。親ワークツリーの `isArchived` は判定に使わない（SHALL）

`orca worktree list --json` は、`parentWorktreeId` が空でも `null` でもないときだけ呼ぶ（MUST）。`jq` が無い、`orca worktree list --json` が非 0 で終わる、出力の `.result.worktrees` が配列でないときは、2 は成り立たないとして扱う（MUST）。ただし `launch` は、`parentWorktreeId` が空でも `null` でもないのに一覧を読めなかったとき（非 0 で終わる、または `.result.worktrees` が配列でない）、子かどうかを決められないので先へ進まずに止まる（下の `launch` の規定）。

**`route`**: 子の番号の検査のあと、子の件数によらず最初にエピックの子の判定を行い、エピックの子なら stdout に `nested` の 1 行、stderr に `parent epic: #<親エピックの番号>` の 1 行を出して exit 0 で終わらなければならない（MUST）。エピックの子でなければ、子が 1 件以上で `orca worktree current --json` が exit 0 なら `orca`、それ以外は `subagent` を出す（MUST）。`orca worktree current` は 1 回の `route` で 1 回だけ呼ぶ（SHALL）。2 の判定の途中で一覧を読めなかったとき、および `orca worktree current --json` が exit 0 で `jq` が PATH に無いとき（`parentWorktreeId` を読めない）は、stderr に `could not read the parent worktree` を出す（SHALL）。

**`launch`**: 引数の検査のあと、1 が成り立てば今までどおり `orca` も `git` も呼ばずに stderr に理由を出して exit 1 で終わる（MUST）。1 が成り立たなければ、`orca worktree current --json` の直後、`git rev-parse --show-toplevel` より前に 2 を判定し、成り立てば `git`・`orca worktree set`・`orca worktree create` を 1 つも呼ばず、stdout には何も出さず、stderr に親エピックの番号と `child epics are not expanded here` を含む理由を出して exit 1 で終わらなければならない（MUST）。1 による拒否の stderr も `child epics are not expanded here` を含む（SHALL）。1 が成り立たず、`parentWorktreeId` が空でも `null` でもないのに 2 の判定の途中で一覧を読めなかったときは、`git`・`orca worktree set`・`orca worktree create` を 1 つも呼ばず、stdout には何も出さず、stderr に `could not read the parent worktree` を出して exit 1 で終わらなければならない（MUST。先へ進むと、子のワークツリーの `linkedIssue` をエピック番号で書き換えてから止まるため）。親ワークツリーを持たないワークツリーでは、呼び出しの順序を変えてはならない（MUST NOT）。

**develop の `references/epic.md`「エピックの扱い」** は次を規定しなければならない（MUST）。`orca` のコマンドは書かない（MUST NOT。要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」）。

- `launch` が `--note` を子 issue に `親エピックからの注意書き:` で始まるコメントとして残すこと。子のセッションの本体（起動し直したセッションを含む）は、記録先にこの行で始まるコメントがあれば、投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のどれかであるものにすべて従い、W・R1・G に渡す関連コメントに必ず含めること。それ以外の投稿者のものと `author_association` を読めなかったものには従わず、W・R1・G にも渡さず、コメントの URL と投稿者をユーザーに報告すること（issue には誰でもコメントでき、子のセッションは確認画面なしで動くため）。この投稿者の検査は注意書きのコメントだけに適用し、記録先のほかのコメントの読み方は変えない
- `launch` の stderr に `note not posted to #<N>` があれば、本体がその子 issue に stderr に出た本文を投稿すること
- 子であることは、`launch` が端末に付けた環境変数と、子のワークツリーの親子関係のどちらからでも判定されるので、起動し直したセッションでも `route` が `nested` を返すこと
- `nested` を受けたセッションは、親エピックの番号を `route` の stderr の `parent epic: #<N>` から読むこと
- `launch` の拒否は stderr の `child epics are not expanded here` で見分け、`nested` と同じに扱うこと
- `route` の stderr に `parent epic:` があり、そのセッションに `EPIC_DISPATCH_PARENT_EPIC` が無いとき（ワークツリーの親子関係で `nested` になったとき）は、同じワークツリーで起動し直しても `nested` になるので、ユーザーには、親を持たないワークツリー（Orca の子として作られていないワークツリー）で `/develop #<自分の issue>` を起動するよう伝えること。「親ワークツリーで開き直す」とは報告しない既存の規定は変えない

この要件の守備範囲で入力として扱うのは、`launch` に渡された `--note` の文、`orca worktree current --json` の `.result.worktree.parentWorktreeId`、`orca worktree list --json` の `.result.worktrees[]` の `id` と `linkedIssue` である。2 つの JSON は 2026-10-08 の実機（Orca 1.4.222）で確かめた形のとおりと信じ、形が変わったときの検知は範囲外とする。拾いたい誤りは、起動し直した子のセッションが注意書きを知らずに範囲外に手を出すこと、自分を子だと知らずに孫のワークツリーやサブエージェントを作ることである。次は通してよく、この要件では止めない: `launch` 以外で、`linkedIssue` の付いたワークツリーを親にして作ったワークツリーで回すエピックは `nested` になる／一覧の一時的な失敗と `route` の 1 回が重なると子のセッションが `nested` にならない（そのとき `launch` は一覧を読めずに子を作らない）／この変更の前に `launch` された子の issue には注意書きのコメントが無い／注意書きの本文の長さや内容は検査しない／親ワークツリーが一覧から消えていれば子ではない扱いになる／親ワークツリーの `linkedIssue` が後の `launch` で別のエピックに変わると、`parent epic:` はその番号になる／サブエージェント方式の隔離 worktree からの `route`・`launch` の呼び出しは想定しない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`gh issue comment` の呼び出しの回数と本文、親子関係による `nested` と `launch` の拒否、上の SKILL.md の記述を確かめなければならない（MUST）。

#### Scenario: --note があれば子ごとに 1 回注意書きをコメントする
- **WHEN** 一覧に子のワークツリーが無いスタブ環境で `epic-dispatch.sh launch --note "後続の範囲に手を出さない" 400 11 12` を実行する
- **THEN** `gh issue comment` は子 11 と子 12 にそれぞれ 1 回呼ばれ、どちらの本文も 1 行目が `親エピックからの注意書き: #400` で `後続の範囲に手を出さない` を含み、各子の `gh issue comment` は `orca terminal create` より前に呼ばれ、stdout は `launched 11` と `launched 12`、exit 0

#### Scenario: --note が無ければコメントしない
- **WHEN** 一覧に子のワークツリーが無いスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `gh issue comment` は 1 回も呼ばれない

#### Scenario: skipped の子と worktree create に失敗した子にはコメントしない
- **WHEN** 一覧に子 11 のワークツリーがあり、子 12 の `orca worktree create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch --note "x" 400 11 12 13` を実行する
- **THEN** `gh issue comment` は子 13 にだけ 1 回呼ばれ、stdout は `skipped 11`・`failed 12`・`launched 13`、exit 1

#### Scenario: 端末を作れなかった子にもコメントは残る
- **WHEN** 子 11 の `orca terminal create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch --note "x" 400 11` を実行する
- **THEN** `gh issue comment` は子 11 に 1 回呼ばれ、stdout は `failed 11`、exit 1

#### Scenario: コメントに失敗しても起動の結果は変えない
- **WHEN** `gh issue comment` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch --note "x" 400 11` を実行する
- **THEN** stdout は `launched 11`、exit 0、stderr に `note not posted to #11` と `gh issue comment 11 --body` を含む行が出る

#### Scenario: 環境変数が無くても、親ワークツリーに issue があれば nested
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` が無く、`orca worktree current --json` の `parentWorktreeId` が `repo-a::/work/parent`、一覧の `id` が `repo-a::/work/parent` のワークツリーの `linkedIssue` が 420 のスタブ環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `nested` の 1 行、stderr に `parent epic: #420`、exit 0

#### Scenario: 子が 1 件でも親ワークツリーに issue があれば nested
- **WHEN** 上と同じスタブ環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `nested` の 1 行で exit 0

#### Scenario: 親ワークツリーに issue が無ければ今までどおり
- **WHEN** `parentWorktreeId` が `repo-a::/work/parent` で、一覧のそのワークツリーの `linkedIssue` が `null` のスタブ環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: 親も環境変数も無ければ今までどおりで一覧を読まない
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` が無く、`orca worktree current --json` に `parentWorktreeId` が無いスタブ環境で `epic-dispatch.sh route 11 12` と `epic-dispatch.sh route 11` を実行する
- **THEN** stdout はどちらも `orca` の 1 行で exit 0、`orca worktree list` は呼ばれず、`orca worktree current` はそれぞれ 1 回呼ばれる

#### Scenario: 一覧を読めなければ子ではないとして扱う
- **WHEN** `parentWorktreeId` があり、`orca worktree list --json` が非 0 で終わるスタブ環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0、stderr に `could not read the parent worktree`

#### Scenario: worktree create の JSON に path が無い子にもコメントは残る
- **WHEN** 子 11 の `orca worktree create` が exit 0 で、JSON に `path` が無いスタブ環境で `epic-dispatch.sh launch --note "x" 400 11` を実行する
- **THEN** `gh issue comment` は子 11 に 1 回呼ばれ、stdout は `failed 11`、exit 1

#### Scenario: 環境変数があるときは nested の stderr に環境変数の番号を出す
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `nested` の 1 行、stderr に `parent epic: #420`、`orca` は呼ばれない

#### Scenario: 親ワークツリーに issue があれば launch は子ワークツリーを作らない
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` が無く、親ワークツリーの `linkedIssue` が 420 のスタブ環境で `epic-dispatch.sh launch 460 11 12` を実行する
- **THEN** exit 1、stdout は空、`git`・`orca worktree set`・`orca worktree create` は 1 回も呼ばれず、stderr に `420` と `child epics are not expanded here` が出る

#### Scenario: 親があるのに一覧を読めない launch は fetch と set の前で止まる
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` が無く、`parentWorktreeId` があり、`orca worktree list --json` が非 0 で終わる（または `.result.worktrees` が配列でない）スタブ環境で `epic-dispatch.sh launch 460 11 12` を実行する
- **THEN** exit 1、stdout は空、`git`・`orca worktree set`・`orca worktree create` は 1 回も呼ばれず、stderr に `could not read the parent worktree` が出る

#### Scenario: SKILL.md に注意書きのコメントと起動し直したセッションの扱いが書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** `親エピックからの注意書き:` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のものに従い W・R1・G に渡すこと、それ以外の投稿者のものには従わず渡さずユーザーに報告すること、`note not posted to` のときに本体が投稿すること、起動し直したセッションでも `nested` になること、親エピックの番号を `parent epic: #` から読むこと、`child epics are not expanded here` で `launch` の拒否を見分けること、変数が無く `parent epic:` が出たときは親を持たないワークツリーで起動するよう伝えることが書かれていて、`grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` は 0 行

### Requirement: 端末を作れなかった子と指示が届かなかった子の案内は、二重起動を避ける確認を先に出す
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` が stderr に出す案内は、次を満たさなければならない（MUST）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の作り直しと送り直しのコマンドの規定に足すもので、既存の規定は変えない。

- 端末を作れなかった子の案内は、作り直しのコマンド（`orca terminal create ...`）より前の行に、そのワークツリーで `claude` がすでに動いている端末が無いことを確かめる `orca terminal list --worktree path:<子> --json` を出す（MUST。案内どおりに作り直して同じワークツリーで Claude Code が 2 つ起動し、`/develop #N` が二重に走るのを避けるため）
- 指示を送り直すための案内のハンドル引数（`orca terminal send --terminal <handle>` と `orca terminal read --terminal <handle>`）は、指示の文と同じく単一引用符で囲む（MUST）。対象は送り直しの案内の `send` と `read` だけで、作り直しの案内の `--terminal <handle from create>` は置き換え用の記号なので囲まない（SHALL）

develop の `references/epic.md`「エピックの扱い」は、端末を作れなかった `failed` の子について、stderr に出た確認のコマンドで既存の端末が無いことを確かめ、stderr の作り直しのコマンドで端末を作り、返ったハンドルに送信のコマンドを送って動き出したのを確かめてから再開する手順を書かなければならない（MUST。作り直さずに再開するとその子は `skipped` になり、`wait` が端末の無い子を最長 6 時間待つため）。`orca` のコマンドは書かない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、`launch` が端末の作成や送信に失敗した子の、子のワークツリーのパスとハンドルである。ハンドルは Orca が払い出す単純な識別子（`term-11` など）で、引用符で囲むのは表示の揃えのためであり、ハンドルに記号が入る場合の検知は範囲外とする。

#### Scenario: 作り直しの案内の前に既存端末の確認を出す
- **WHEN** 子 11 の `orca terminal create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** stderr の `orca terminal list --worktree path:<子 11 のパス> --json` を含む行は、`orca terminal create --worktree` を含む行より前にある

#### Scenario: 送り直しの案内のハンドルは引用符で囲まれる
- **WHEN** 子 11 の `orca terminal send` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stderr の送り直しのコマンドは `--terminal 'term-11'` を含み、確認のコマンドも `orca terminal read --terminal 'term-11'` を含む

#### Scenario: SKILL.md に端末を作れなかった子の再開手順が書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** 端末を作れなかった `failed` の子について、既存の端末が無いことを確かめ、作り直して送り、動き出したのを確かめてから再開することが書かれている

### Requirement: エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する
develop の `references/epic-child-stop.md` は、エピックの子のセッションが主の返事を待って止まるときの手順を、`references/epic.md` は、Orca 経路の親が `stopped` を受けたときの手順を規定しなければならない（MUST）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」のうち、子が自分のタブでユーザーに質問して止まっている場合は `timeout` の確認では気づけないと書く規定に優先する（記録を残さずに止まった子に限って気づけないと書く）。

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
- 記録を残さずに子のタブで質問して止まった子は、`timeout` の確認でも検知できないので、ユーザーに子のタブも見るよう伝えることを残す（SHALL）
- 端末の入力待ちが続いたことで子の止まりを推定する手順を書いてはならない（MUST NOT。誤検知が多いため。根拠は change `epic-child-stop-signal` の design.md）

develop の手順書（`skills/develop` 配下）に `orca` のサブコマンドを書いてはならない（MUST NOT。既存の規定どおり、`orca` を呼ぶのは Orca の起動部品 `epic-launch-orca.sh` だけ）。

この要件の守備範囲で入力として扱うのは、子のセッションでは `epic-dispatch.sh route`（子の番号なし）の出力と `mark` の出力、主の返事を待つかどうかの子自身の判断（本文で質問するか、質問ツールを使うか、背景のタスクを待つだけか）、記録先の issue 番号で、親のセッションでは `wait` の出力と子 issue のコメント（1 行目が `子の停止: 主の返事待ち` の最新の 1 件）である。拾いたい誤りは、エピックの子が主の返事を待っているのに記録も印も残さずに止まること、印が記録より先に付いて親が記録の無い止まりを読むこと、質問ツールで待つ子が回答を受けたあとも止まった印を残すこと、エピックの子でないセッションが読む者のいない記録を残すこと、親が止まった子を動いている子から外して閉じたことを検知できなくなること、`mark stopped` が印を付けられなかった（`skipped` か `failed`）のに子が主に伝えずに止まることの 6 つである。次は通ってよく、この要件では止めない: 記録の項目の値の長さと改行の違い（値が複数行に続くこと）／止まるたびに記録が増えること（最新の 1 件を正とする）／保留の場面で引き継ぎと記録の 2 件のコメントが並ぶこと／主が子のタブで先に答えて、親が既に再開した子の `stopped` を受けること（親は記録を読んで報告するだけで、返事の仕方は #1034 で決める）／子が記録を書かずに止まり、親が `timeout` まで気づかないこと（入力待ちからの推定は入れない）。記録の中身（理由・推奨・リスクの正しさ）を確かめることと、手順を守らない子を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

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
- **WHEN** `references/epic.md` の Orca 経路の `timeout` の手順を読む
- **THEN** 記録を残さずに子のタブで質問して止まった子は検知できず、ユーザーに子のタブも見るよう伝えることが書かれている

### Requirement: 時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` が子の起動コマンドに前置きする `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` の `<値>` は、既定で `120000` でなければならない（MUST）。環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` が設定されていればその値を使う（SHALL）。設定された値が空文字か、数字だけでない文字列なら、`launch` は stderr に変数名と使い方を出して exit 1 で終わり、`orca` と `git` を 1 つも呼んではならない（MUST）。100,000 未満の値は拒まない（SHALL。下限の扱いは Claude Code が持つ）。

時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、次を書かなければならない（MUST）。

- **閾値**: 子は 120,000（`launch` が付ける。`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` で変えられる）、親も同じ 120,000。親は主が起動するセッションなので `launch` は付けられず、主が起動するセッションは主の起動コマンド（例: `cld`）が、値が未設定のときだけ 120000 を入れる（外から渡された値は上書きしない）。個人の設定ファイルのパスは書かない。どちらの値も `~/.claude/settings.json` の `env` に置かない（主の手元の全セッションに効くため）
- **分ける条件**: 子に返事を送る前に、子の端末が無ければ起動し直す。子の最後のリクエストから 60 分未満ならそのまま送る。60 分以上で、その間に待っている間の自動コンパクトが走っていればそのまま送る。60 分以上でコンパクトが走っていなければ、会話量 N が 150,000 トークン以上なら起動し直し、150,000 未満ならそのまま送る
- **判定に使う事実**: 子の端末の有無（子のワークスペースに端末が残っているか。`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻と、そのあとの `compact_boundary` の有無、会話量 N（`plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>`）
- **親への適用**: 親自身が長く待ったあとも同じ条件で、そのまま続けるか起動し直すかを決める。親の状態のうち、回し方（`回し方:`）・終わった子（`子 #N マージ → 残り k 件` / `子 #N 見送り`）・外した子エピック（`後で別に起動するエピック:`）・残したワークツリー（`子 #N のワークツリーを残した`）・親が通した判断（`親の判断: 子 #N 通した`）はエピックのコメントから、残りの子は依存グラフと子 issue の状態から復元できる
- **根拠と限り**: 値と条件の根拠として #1039 の集計コメントの URL と要点（返事の直前の会話の中央値、起動し直しの費用、閾値ごとの費用の増減）、実績の少なさと PC が寝ているとコンパクトが走らないこと。加えて、コンパクトのあと develop を呼んでいた会話には SessionStart の hook（`scripts/develop-compact-reread.sh`）が `SKILL.md` の読み直しを差し込むことと、その費用（1 回約 39k トークンで、集計の控えめの想定で足した 40k とは別にかかること）、両方を足した想定は計算し直しておらず #1264 で計算すること、控えめの想定でも 120,000 は最良と差が小さく既定の 200,000 より子で安いので値を変えていないこと（#1217 の計算コメントの URL）
- **再集計**: 1〜2 週間回したあとに同じ集計をやり直して #1039 にコメントし、値を見直す。件数・金額は合否に使わず記録する

送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順（develop の `references/epic.md` の Orca 経路と `epic-dispatch.sh reply`）が書き、このファイルを参照する）。

develop の `references/epic.md`「エピックの扱い」の「回し方」は、子セッションの起動コマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が付くことと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で「そのまま送る」か「起動し直す」かを決めることを書かなければならない（MUST）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、既定の前置き、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` での上書き、空文字と数字でない値の拒否、規則のファイルの上の記述（値・分ける条件・`settings.json` に置かないこと）、SKILL.md の上の記述を確かめなければならない（MUST）。

この要件の守備範囲は、閾値の上書き値の検査と、返事の前の分類の 2 つである。

閾値の上書き値の検査について、入力として扱うのは `launch` を実行したシェルの環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS`（主か親のセッションが `launch` の呼び出しに付けたもの）だけである。拾いたい誤りは、空文字や `120k`・`1.2e5`・`120,000` のような数字だけでない値がそのまま子の起動コマンドに入り、子の Claude Code が閾値を読めずに既定の 200,000 で動くことと、値の空白や記号でコマンドが壊れることである。次は通してよく、この検査では止めない: `0` や `99999` のような 100,000 未満の数字（下限の扱いは Claude Code が持つ）／`200000` や `1000000` のような大きな数字／`0120000` のような先頭に 0 の付いた数字／変数が設定されていない環境（既定の 120000 を使う）。

返事の前の分類について、入力として扱うのは、子の端末の有無（子のワークスペースに端末が残っているか）、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）に記録された最後のリクエストの時刻とそのあとの `compact_boundary` の有無、同じトランスクリプトから `plugins/dev-workflow/scripts/subagent-context.sh --file` で測った会話量 N である。この分類は、`epic-dispatch.sh wait --resolve` が親の代わりに通す返事を除き、スクリプトではなく本体が規則のファイルを読んで行う。`wait --resolve` が通す返事は、要件「wait --resolve は通す返事を送る前に起動し直すかを表で決める」のとおり `resolve_stopped` が同じ表で分類する（例外）。拾いたい誤りは、PC が寝ていてコンパクトが走らなかった 150,000 トークン以上の会話に、そのまま返事を送って会話全体を書き込み直すことと、コンパクトが走った子や 60 分未満の子を起動し直して、子が積んだ判断と起動し直しの費用（平均約 258k）を無駄にすることである。次は通してよく、この分類では止めない: 経過時間がちょうど 60 分前後で、時刻の読み方によって扱いが分かれる子／N が 150,000 前後で、測り方の誤差で扱いが分かれる子／トランスクリプトが複数あってどれが子のセッションか分からず、そのまま送った子／この変更より前に起動され、前置きが無く既定の 200,000 で動いている子／主の起動コマンドが値を入れず、既定のまま動く親／`EPIC_DISPATCH_CLAUDE_CMD` が前置きの代入を受け付けない形（`exec` で始まる文字列など）で値が渡らなかった子。

どちらについても、すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: launch は子の起動コマンドに既定の閾値を前置きする
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` の無い環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'` である

#### Scenario: 閾値は環境変数で変えられる
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=150000` の環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=150000 cld --model 'opus'` である

#### Scenario: 閾値の上書きが空なら起動しない
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=` の環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stderr に `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` と使い方が出て exit 1、`orca` と `git` は呼ばれない

#### Scenario: 閾値の上書きが数字でなければ起動しない
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=120k` の環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stderr に `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` と使い方が出て exit 1、`orca` と `git` は呼ばれない

#### Scenario: 規則のファイルに値と分ける条件が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 子・親とも 120,000 の値、親の値を主の起動コマンドが未設定のときだけ入れる形で付けて `settings.json` の `env` に置かないこと、端末が無い・60 分未満・コンパクトが走った・N が 150,000 以上か未満で「そのまま送る」か「起動し直す」かを分ける条件、判定に使う事実（端末の有無は `epic-dispatch.sh reply` が確かめること）、親の状態の復元（親が通した判断を含む）、1〜2 週間後の再集計が書かれている。さらに、コンパクトのあと hook が `SKILL.md` の読み直しを差し込むこと、その費用が 1 回約 39k であること、#1264 で計算し直すことが書かれている

#### Scenario: SKILL.md の回し方が規則のファイルを指す
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** 子の起動コマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が付くことと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で決めることが書かれている

### Requirement: Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる
develop の `references/epic.md`「エピックの扱い」→「回し方」の Orca 経路の手順は、次を規定しなければならない（MUST）。この要件は、要件「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」の親の側のうち、`stopped` で起こされたら記録を読んでユーザーに報告する規定と、止まった子への返事の仕方を #1034 で決めるとする規定に優先する。

- 動いている子を待つ `wait` には、`--watch-stopped` に加えて `--resolve <エピック番号>` を付ける（MUST）。通すと判断された止まりは `wait` の中で返事が送られ、親は起こされない
- `wait` の出力が `closed`・`done`・`stopped`・`unrecorded` の 1〜4 行であることを書く（MUST）。この 1〜4 行は `--resolve` を付けたときだけで、要件「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」の `closed`・`done`・`stopped` の 1〜3 行とする規定に優先する。`--resolve` を付けない `wait` の出力は従来どおり 1〜3 行であることも書く（MUST）
- `unrecorded <N>...` で起こされたら、子には返事が届いているので主に上げず、`wait` が stderr に出した投稿し直しのコマンドでエピックに `親の判断: 子 #N 通した` の 1 行を残す（MUST）。stderr を読めなければ、`親の判断: 子 #N 通した — 理由は記録できなかった <最新の子の停止の記録の URL>` を投稿する（MUST）
- `stopped <N>...` で起こされたら、止まった子ごとに子 issue の最新の `子の停止: 主の返事待ち` のコメントと、2 行目の `停止の記録:` がその URL と一致する最新の `親の判断:` のコメントを読む（MUST）。一致する `親の判断:` が無ければ、判断が無いものとして扱う（MUST。前回の止まりへの判断を今回の判断と取り違えないため）
  - `親の判断: 通すが送れなかった` の件（以前の形の `親の判断: 判断できなかった` で、送るはずだった返事があり、送信だけが失敗した件も同じ）は（`止まった理由:` が `PR トークン上限（` で始まる止まりは送り直さず、下の **PR トークン上限の子** で照らし直す）、主に上げずに `epic-dispatch.sh reply --as parent` で送り直してよい（MAY）。送れたらエピックに `親の判断: 子 #N 通した` の 1 行を残す（MUST）
  - 最新の記録の `止まった理由:` が `PR トークン上限（` で始まる止まりは、下の照らし直しを行わず、要件「親は PR トークン上限の止まりを権限に照らして続けさせる」の手順で親の権限に照らす（MUST。権限の内でなければ、下の主に上げる手順で上げる。主の答えの扱いは要件「権限の内でない止まりは主に上げ、主が権限を広げたら照らし直す」に従い、下の「主の答えを受けたら…`reply --as owner`」の規定より優先する）
  - 最新の記録の `止まった理由:` が `PR のマージ待ち（` で始まる止まりは、下の照らし直しを行わず、要件「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」（Orca 経路の **マージ待ちの子** の段落）の手順に進む（MUST。マージは決まりで主の承認が要るので、照らし直しでは通らない）
  - それ以外（判断が「主に上げる」・判断できなかった・一致する判断が無い）は、主に上げる前に、親が自分で記録を `references/parent-pass-criteria.md` に照らす（MUST）。照らす前に、エピックのコメントの同じ子の `親の判断: 子 #N 通した`（手順 7 と同じ author_association の条件）と、あれば配役表（`.claude/casting/project.md`・`.claude/casting/local.md`）を読み、同じ件を既に一度通していれば覆さずに主に上げる（MUST）。主に聞く理由の 3 つ（主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作）のどれにも当たらず、基準のほかの条件も満たす止まりは、主に上げずに `epic-dispatch.sh reply --as parent` で通し、送れたらエピックに `親の判断: 子 #N 通した — <理由> <停止の記録の URL>` の 1 行を残す（MUST）。判断が「主に上げる」としたものを覆して通すときの `<理由>` には、主に聞く理由の 3 つの理由のどれにも当たらない根拠を 1 文で書く（MUST）。主に聞く理由が成り立つか迷うときは主に上げる（MUST）
  - 主に上げるときは、説明を本文で書き、質問ツールで聞かない（MUST。子の `--relayed` は親の発言の本文に停止の記録の URL があることで結び付けを見る）。説明は `~/.claude/output-styles/readable.md` の節 3（主に問いを返す文章の書き方の正本）の型で書く（MUST。手順 8 に順を写さない）。子の停止の記録の項目は正本の段に置き直す（MUST）: `止まった理由:` を質問に、`主に聞く理由:` を主に聞く理由に、`前提:` をいま困っていることに、`推奨:` と `推奨の根拠:` を推奨と根拠に、`受け入れるリスク:` を受け入れるリスクにする。記録の項目名を見出しや語としてそのまま主に渡してはならない（MUST NOT）。子が作業中に使った言葉は主の言葉に直す（MUST）。説明には、エピックの目的と他の子との関係を含め、子の停止の記録の URL を添える。実機操作は、どの子の・どの画面で・何をするかを書く
  - 主に上げる止まりが複数あっても、1 通で上げるのは 1 件にする（MUST。正本の「1 通で聞くのは 1 件」）。残りは主の答えを受けてから次の報告で上げる。待ちに入る通知の本文に、まだ上げていない止まった子の番号を 1 行書く（MUST）
- 主の答えを受けたら、`references/reply-after-idle.md` の表でそのまま送るか起動し直すかを決め、`epic-dispatch.sh reply --as owner`（起動し直すなら `--relaunch` も）に主の答えを書き換えずに渡して子に届ける（MUST）。主の答えの末尾には、要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」の発言の場所の添え書き（` [主の発言: セッション <親のセッション ID> / uuid <uuid>]`）を付けて渡す（MUST。主の答えそのものは書き換えず、末尾に足すだけ。場所を引けないときの扱いも同じ要件に従う）。`reply` の出力が `failed` なら主に報告する（MUST）
- 止まった子を動いている子から外さず、2 に戻る（MUST。既存の規定のまま）
- 親が通してよい範囲の基準は `references/parent-pass-criteria.md` を指す（MUST）

develop の手順書（`skills/develop` 配下）に `orca` のサブコマンドを書いてはならない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、`wait` の出力と、子 issue の `子の停止:` と `親の判断:` のコメント、主の答え（親のセッションの会話）、`reply` の出力である。拾いたい誤りは、通せなかった止まりを主に上げずに待ち続けること、主に上げる説明が子の会話や子の項目名を前提にして主が読めないこと、主に聞く理由の無い止まりを主に上げること、主の答えを子に届けないこと、時間がたった子に表を見ずに送ることの 5 つである。次は通ってよく、この要件では止めない: 説明の文の良し悪し（順序と含めるものが書かれていればよい）／主が子のタブで先に答えていて、親の届けた答えが 2 度目になること（子は受け取って続ける）／判断のモデルが主に上げた止まりを親が通し、あとで主に止められること（エピックの 1 行から事後に止める作り）。説明が主に読めない書き方を見つけるたびに手順を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 親の手順に resolve と主に上げる説明の順が書かれている
- **WHEN** `references/epic.md` の Orca 経路の手順を読む
- **THEN** `wait` に `--watch-stopped` と `--resolve <エピック番号>` を付けること、`--resolve` を付けたときの出力が `unrecorded` を含む 1〜4 行で、付けないときは従来どおり 1〜3 行であること、`unrecorded` で起こされたらエピックに 1 行を残して主に上げないこと、`stopped` で起こされたら `子の停止:` と、`停止の記録:` がその URL と一致する `親の判断:` を読むこと、主に上げる説明を `~/.claude/output-styles/readable.md` の節 3 の型で書き（旧い 5 段の順を写していない）、エピックの目的と他の子との関係と記録の URL を含めること、実機操作はどの子の・どの画面で・何をするかを書くこと、主に上げる説明を本文で書き質問ツールで聞かないこと、主の答えを `reply-after-idle.md` の表で決めてから、書き換えずに末尾に発言の場所の添え書きを付けて `reply --as owner` で届けること、`parent-pass-criteria.md` を指すことが書かれている

#### Scenario: 手順 8 が記録の項目を正本の段に置き直す
- **WHEN** `references/epic.md` の Orca 経路の手順 8 を読む
- **THEN** 「同じ項目名のまま」の文言が無く、`止まった理由:`・`主に聞く理由:`・`前提:`・`推奨:`・`推奨の根拠:`・`受け入れるリスク:` をそれぞれ正本の質問・主に聞く理由・いま困っていること・推奨と根拠・受け入れるリスクに置き直すこと、項目名をそのまま主に渡さないこと、1 通で上げるのは 1 件であることが書かれている

#### Scenario: 主に聞く理由の無い止まりは親が通す
- **WHEN** `references/epic.md` の Orca 経路の手順 8 を読む
- **THEN** 判断が「主に上げる」・判断できなかった・一致する判断が無い止まりも、主に上げる前に親が `parent-pass-criteria.md` に照らすこと、主に聞く理由の 3 つのどれにも当たらない止まりは `reply --as parent` で通してエピックに `親の判断: 子 #N 通した — <理由> <停止の記録の URL>` を残すこと、判断が「主に上げる」としたものを覆すときの理由は 3 つの理由のどれにも当たらない根拠を 1 文で書くこと、`止まった理由:` が `PR のマージ待ち（` で始まる止まりは照らし直さずマージ待ちの子の手順に進むこと、迷うときは主に上げることが書かれている

#### Scenario: PR トークン上限の止まりは基準に照らし直さず権限に照らす
- **WHEN** `references/epic.md` の Orca 経路の手順 8 を読む
- **THEN** `止まった理由:` が `PR トークン上限（` で始まる止まりは `parent-pass-criteria.md` に照らし直さず、親の権限に照らす専用の手順に進むこと、権限の内でなければ主に上げることが書かれている

#### Scenario: 実機で親の報告が正本の型になり、理由の無い止まりは上がらない
- **WHEN** `claude -p --plugin-dir` で、親の手順 8 の立場に、ログの 3 場面（rm の許可・CI が落ちた 2 件・初版の記録を配布の前提から外す件）を 7 項目の形で書き起こした子の停止の記録を渡し、主への報告か通す判断を書かせる
- **THEN** 主に上げた報告は質問で始まり、主に聞く理由・いま困っていること・推奨と根拠・頻度と根拠を含む受け入れるリスク・答え方の順で、記録の項目名を見出しにせず、記録の URL を添えている。主に聞く理由が書けない件（Mac が空いてからの CI の再実行で足りる件）は主に上げず、`reply --as parent` の返事とエピックへの `親の判断: 子 #N 通した` の 1 行を出す

### Requirement: エピックの子は親から届いた返事を止まった件への返事として受け取る
develop の `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」は、端末に `親エピック #<E> の判断（主の承認ではない）:` か `主の返事（親エピック #<E> 経由）:` で始まる入力が届いたら、止まった件への返事として受け取り、既存の手順どおり `mark resumed` を呼んで続きから進むことを規定しなければならない（MUST）。親の判断で進めた件は完了報告に書く（MUST）。`親エピック #<E> の判断（主の承認ではない）:` の入力を、聖域の変更や破壊的な操作の承認として扱ってはならない（MUST NOT）。記録の形と完了報告の書式は変えない（要件「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」と #1036 の範囲）。

この要件の守備範囲で入力として扱うのは、子のセッションに届いた入力の頭の文字列だけである。拾いたい誤りは、親の判断を主の承認として聖域や破壊的操作を進めること、親の返事を受けても止まったままか再び同じ件で止まることの 2 つである（確かめられなかった親経由のリスク許容で、主に子のタブでの返事を頼むために新しい記録と印を残して止まることは除く）。入力の末尾の添え書き（`[主の発言: セッション <ID> / uuid <uuid>]`）は、要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」で読む。次は通ってよく、この要件では止めない: 頭の無い入力（主が子のタブで直接答えたもの。今までどおり主の返事として扱う）。頭の文字列を真似た入力など、すり抜ける形が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 子の手順に親から届いた返事の扱いが書かれている
- **WHEN** `references/epic-child-stop.md` のエピックの子が止まるときの手順を読む
- **THEN** 2 つの頭の文字列、止まった件への返事として受け取り `mark resumed` を呼ぶこと、親の判断で進めた件を完了報告に書くこと、親の判断を聖域や破壊的操作の承認として扱わないことが書かれている

### Requirement: 親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る

develop の手順書（SKILL.md と `references/epic.md`・`references/epic-child-stop.md`）は、Orca 経路のエピックで主が親のセッションに書いたリスク許容を、子のゲートが主本人の返事として受け取れるよう、次の 3 か所を規定しなければならない（MUST）。

**Orca 経路の手順 8（親の送り方）**: 親は主の答えを `scripts/epic-dispatch.sh reply --as owner` で送る前に、`owner-reply-check.sh --locate "$CLAUDE_CODE_SESSION_ID" <主の答え>` を回し、`MATCH:` のうち全文が主の答えと同じ（どちらも連続する空白を 1 個にまとめて比べる）で timestamp がいちばん新しい行の uuid を取り、主の答えの末尾に ` [主の発言: セッション <親のセッション ID> / uuid <uuid>]` を添えて渡さなければならない（MUST）。主の答えそのものは書き換えてはならない（MUST NOT。添え書きは末尾に足すだけ）。`--relayed` の結び付けは親の発言の本文に停止の記録の URL があることで見るので、親は止まった子の報告を本文で書き（質問ツールで聞かない）、その本文に停止の記録の URL を書かなければならない（MUST）。URL を書いた最後の報告と主の答えのあいだに主の別の発言が挟まると子の `--relayed` は `not-direct` で落ちるので、そのときは報告を本文で出し直してから主の答えを受け直さなければならない（MUST）。終了コードが 0 でない、または該当する行が無いときは添え書きを付けずに送り、主に「<OK すると起きること>でよければ、子のタブで『許容する』と打ってほしい（親のタブの返事を子が確かめられなかったため）」と伝えなければならない（MUST）。

**「エピックの子が主の返事を待って止まるとき」の「親から届いた返事」（子の受け取り方）**: 子は、`主の返事（親エピック #<E> 経由）:` で始まる入力（起動し直されたセッションの最初の指示 `/develop #<N> （エピック #<E> の子。返事を受けて起動し直し） 主の返事（親エピック #<E> 経由）: …` の、括弧のうしろに付いて届いたものを含む）が止まった件のリスク許容への返事で、末尾に `[主の発言: セッション <ID> / uuid <uuid>]` があるとき、記録先の最新の `子の停止: 主の返事待ち` のコメント（投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のもの）の作成日時と URL で `owner-reply-check.sh --relayed <ID> <uuid> <作成日時> <URL>` を回さなければならない（MUST）。exit 0 で、`MATCH:` の全文から許容の意思が読め、全文がこの子・この PR への許容と読め、別の子・別の PR・別のリスクだけを名指しした答えでないときだけ、保留の解除の G に、親のセッション ID・uuid・`MATCH:` の timestamp・停止の記録の URL・`MATCH:` の全文を渡さなければならない（MUST。記録の書式と真正性確認は pr-review-gate 手順 5 の「親経由で受領」が正本で、develop の手順書（SKILL.md と `references/epic-child-stop.md`）に書式を再掲しない）。exit 0 で、`MATCH:` の全文から不許容の意思が読め、全文がこの子・この PR への答えと読め、別の子・別の PR・別のリスクだけを名指しした答えでないときは、主本人の不許容として受け取り、保留の解除の G に同じ値を渡して pr-review-gate の手順 6 の復帰手順の不許容の行で扱わせなければならない（MUST。主に子のタブで打ち直してもらわない）。添え書き（`[主の発言: …]` も `[主の委任: …]` も）が無い・`--relayed` が exit 0 でない・全文から許容とも不許容とも読めないときは、主本人の返事として扱ってはならず（MUST NOT）、G を起こさずに、主に子のタブで直接返事を打ってもらうよう頼み（止まる前の記録と印は同じ節の手順どおり）、頼む文に確かめられなかった理由（`REASON=` の値か「添え書きが無い」）を添えなければならない（MUST）。起動し直されたセッションでは、この受け取り方を「新しいセッションでの再開」の手順 2（`/develop` の引数の残りを自分のセッションの会話で受けた回答として扱う）より先に当て、引数の残りのうち `主の返事（親エピック #<E> 経由）:` で始まる部分を自分のセッション ID で `owner-reply-check.sh` に掛けてはならない（MUST NOT。子の会話ログのその行は⑨で主の発言として数えないので、掛けると主に受け直しを頼むことに落ちる）。この順序は「親から届いた返事」の箇条に書き、再開手順の本文は変えない（MUST）。リスク許容以外の返事（動作確認の結果・切り出しの確認への回答など）の受け取り方は変えない。末尾が `[主の委任: セッション <ID> / uuid <uuid> / 記録 <URL>]` の返事は、要件「子は委任の返事を確かめてから G に渡す」の手順で確かめ、この段落の `--relayed` に掛けてはならない（MUST NOT）。

**保留の行の「リスク許容を会話で受けたら」の文**: エピックの子が親経由で許容を受けたときは、自分のセッション ID ではなく、上の「親から届いた返事」の手順で確かめてから G に渡すことを、参照で書かなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、親の会話の主の答え、子に届いた入力の頭と末尾の添え書き、子の記録先の停止の記録のコメント、同じ PC の親の会話ログである。拾いたい誤りは、親の打ち込みや確かめられない親経由の返事を主のリスク許容として G に渡すこと、別の止まり・別の子への主の答えを流用すること、親が場所を添えずに送ったときに主に子のタブでの返事を頼まないこと、の 3 つである。次は通ってよく、この要件では止めない: 親が報告した 2 件の止まりにまとめて答えた名指しの無い「許容」と、両方の子を名指しした「1034 も 1030 も許容」（どちらも両方の子で受け取る）、親の報告と主の答えのあいだに親の会話の圧縮が挟まったもの。委任の添え書きの返事の守備範囲は要件「子が委任の返事を受ける経路の守備範囲」に従う。会話ログの改変と、頭の無い自由な文での親の打ち込みを見破ること、偽造の経路を見つけるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 親の送り方が手順 8 に書かれている

- **WHEN** `references/epic.md` の Orca 経路の手順 8 を読む
- **THEN** 止まった子の報告を本文で書き（質問ツールで聞かない）停止の記録の URL を添えること、主の答えを書き換えないこと、`owner-reply-check.sh --locate` で主の発言の uuid を引くこと、`[主の発言: セッション <親のセッション ID> / uuid <uuid>]` を主の答えの末尾に添えて `reply --as owner` に渡すこと、引けないときは添え書きを付けずに送り主に子のタブでの返事を頼むことが書かれている

#### Scenario: 子の受け取り方が「親から届いた返事」に書かれている

- **WHEN** `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」の「親から届いた返事」を読む
- **THEN** 添え書きのある親経由のリスク許容を、最新の停止の記録の作成日時と URL で `owner-reply-check.sh --relayed` に掛け、exit 0 で全文から許容と読めるときだけ G に許容として渡すこと、exit 0 で全文から不許容と読めるときは主本人の不許容として G に渡すこと、どちらとも読めないか確かめられなければ主に子のタブでの返事を理由付きで頼むこと、起動し直しの最初の指示に付いて届いたときも同じに扱い再開手順 2 より先に当てること、書式の正本が pr-review-gate 手順 5 の「親経由で受領」であることが書かれている

#### Scenario: 確かめられない親経由の許容では G を起こさない

- **WHEN** 子に `主の返事（親エピック #1038 経由）: 許容 [主の発言: セッション <ID> / uuid <uuid>]` が届き、`--relayed` が `REASON=not-after` で exit 1 を返す
- **THEN** 子は保留の解除の G を起こさず、主に子のタブでの返事を、止まる前の記録と印を残してから頼む

#### Scenario: 確かめられた親経由の不許容は主本人の不許容として受け取る

- **WHEN** 子に `主の返事（親エピック #1038 経由）: 1034 は許容しない。代替案で [主の発言: セッション <ID> / uuid <uuid>]` が届き、`--relayed` が exit 0 を返す
- **THEN** 子は主に子のタブでの打ち直しを頼まず、保留の解除の G に同じ値を不許容の回答として渡し、G は pr-review-gate 手順 6 の復帰手順の不許容の行で扱う

#### Scenario: 起動し直しの指示に付いて届いた親経由の許容を確かめる

- **WHEN** 子が `/develop #1034 （エピック #1038 の子。返事を受けて起動し直し） 主の返事（親エピック #1038 経由）: 許容 [主の発言: セッション <ID> / uuid <uuid>]` で起動し直され、記録先に `引き継ぎ: 主の返事待ち` のコメントがある
- **THEN** 子は引数の残りを自分のセッション ID で `owner-reply-check.sh` に掛けず、「親から届いた返事」の手順どおり `--relayed` で確かめ、exit 0 なら保留の解除の G に渡す

#### Scenario: 保留の行が親経由の受け取り方を指している

- **WHEN** SKILL.md の保留の行の「リスク許容を会話で受けたら」の文を読む
- **THEN** エピックの子が親経由で受けたときは「親から届いた返事」の手順に従うことが書かれている

#### Scenario: 委任の添え書きの返事は --relayed に掛けない

- **WHEN** 子に `主の返事（親エピック #1038 経由）: 許容する（主の委任による。停止の記録: <URL>） [主の委任: セッション <ID> / uuid <uuid> / 記録 <委任の記録の URL>]` が届く
- **THEN** 子は `--relayed` を回さず、要件「子は委任の返事を確かめてから G に渡す」の手順で確かめる（添え書きが無い返事としても扱わない）

### Requirement: Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける
develop の `references/epic.md`「エピックの扱い」→「回し方」は、Orca 経路の手順のあとに、マージ待ちで止まった子の扱いを規定しなければならない（MUST）。この要件は、要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」の `stopped` で主に上げるどちらの経路（一致する `親の判断:` が無いとき、と、判断が「主に上げる」・判断できなかったとき）にも、子の最新の停止の記録の `止まった理由:` が `PR のマージ待ち（` で始まる子について優先する（主に上げる前にこの手順を行い、ここで主に上げると決まったものは同じ要件の報告の形で上げる）。手順 2 の文は変えない。手順 8 は、`止まった理由:` が `PR のマージ待ち（` で始まる止まりを照らし直さずこの手順に回す分岐を持つ。

- **気づく経路**: 子が「エピックの子が主の返事を待って止まるとき」の記録を `止まった理由: PR のマージ待ち（human-merge）: <PR の URL>` で残し、`wait --resolve` の判断がマージを通さないので親が `stopped` で起こされる経路に乗る。epic-dispatch.sh にマージ待ちを返す出力を足さない
- **前提の確認**（`gh` で機械的に見る。どれかを満たさなければ決める役を起こさずに主に上げる。MUST）: 対象リポの PR の base ブランチの `.github/workflows/auto-merge.yml`（`gh api "repos/<owner>/<repo>/contents/.github/workflows/auto-merge.yml?ref=<PR の base ブランチ>" --jq .content | base64 -d`） に `parent-merge-approved` の語がある／PR が open で、見送りラベル（`human-merge`・`needs-human-merge`・`human-only`・`needs-approval`）のうち付いているのが `human-merge` だけ／記録の PR の本文で最初に現れる `Closes #N`・`Fixes #N`・`Refs #N` の `N` が子 issue の番号である／PR に、今の HEAD を `親が見た HEAD:` に持つ `親のマージ判断: 可` のコメントがまだ無い（あれば自動マージの処理の側が止めているので、`docs/auto-merge.md` の「親の判断の印を付けたのにマージされないとき」の調べ方を添えて上げる）
- **判断**: `subagent_type: dev-workflow:decider` を起こし、`references/parent-merge-criteria.md` で判断させる（MUST）。親は自分で可否を決めない（MUST NOT）。決める役は `Bash` を持たないので、親がエピックの本文、子 issue の本文と OWNER・MEMBER・COLLABORATOR の `親エピックからの注意書き:`、子の停止の記録、PR の本文とラベルと今の HEAD の SHA、変更ファイルの一覧と差分、PR のリスク宣言・動作確認・ゲートのコメント、CI の結果、取得した `auto-merge.yml` の `# >>> sacred-paths` 〜 `# <<< merge-condition-paths` の行（聖域とマージ条件そのもののパスの正規表現）、PR のコメントのうち自動マージの処理が `human-merge` を付けた旨の投稿（`🔒 **auto-merge 対象外（聖域パス接触）**` で始まるもの）、あれば配役表を入力文に貼る
- **可のとき**: 古い HEAD の判断で付けた `parent-merge-approved` が PR に残っていれば、先に外す（MUST。付いたままでは付け直しても新しい `labeled` が起きず、自動マージの処理には `issue_comment` のきっかけが無いので、日次の判定まで判定が走らない）。そのあと PR の今の HEAD を取り直し、決める役に渡した HEAD と一致することを確かめる（一致しなければ印を付けずに主に上げる。MUST）。一致したら、PR に 1 行目 `親のマージ判断: 可`・2 行目 `親が見た HEAD: <40 桁 SHA>`・3 行目 `理由: <決める役の理由>` のコメントを投稿し、そのあとに `parent-merge-approved` ラベルを付ける（この順。MUST）。続けて `epic-dispatch.sh reply --as parent <エピック番号> <N> <返事>` で、自動マージの処理に回したこと・子は `ci-watch.sh wait --until-merged` で見届けること・子は何も承認せず印も付けないことを伝え、エピックに `親の判断: 子 #N マージに回した — <理由> <PR の URL>` の 1 行を残す（MUST）。`reply` が `failed` なら主に報告する（印は外さない）
- **否・不足・形が崩れた出力・迷ったとき**: 印を付けずに主に上げる（MUST）。報告には PR の URL と決める役の理由（`不足:` なら足りないもの）を含める
- **印を付ける者**: 判断の印（ラベルとコメント）を付けるのは親だけで、子は付けない（MUST NOT）ことを書く。親が `gh pr merge` や merge API を叩いてはならない（MUST NOT）。印が数えられるのは `gh` の認証アカウントが対象リポの OWNER・MEMBER・COLLABORATOR のときだけであることを書く（SHALL）

この要件の守備範囲で入力として扱うのは、子の停止の記録、`gh` で読める PR と PR の base ブランチの `auto-merge.yml`、決める役の出力である。拾いたい誤りは、印が効かないリポや `human-merge` 以外の見送りラベルが付いた PR に印を付けること、決める役の判断を経ずに印を付けること、判断したあとに変わった HEAD に印を付けること、ラベルをコメントより先に付けて最初の判定を空振りさせること、マージされない印を付け直し続けること、古い HEAD のラベルを残したまま新しい HEAD を承認して判定を走らせないことの 6 つである。次は通ってよく、この要件では止めない: 決める役が通してよい PR を否とすること（主の手間は増えるが危険は無い）／マージ待ちの止まりのたびに `stop-judge.sh` のモデル呼び出しが 1 回空振りすること／子が技術的には印を付けられること（受け取り側の判定と手順書の規則に任せる。#1030 で主が受け入れた）。基準をすり抜ける PR が見つかるたびに手順を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 親の手順にマージ待ちの判断と印の付け方が書かれている
- **WHEN** `references/epic.md` の Orca 経路の手順のあとの段落を読む
- **THEN** `止まった理由:` が `PR のマージ待ち（` で始まる子について、手順 8 で主に上げるどちらの経路でも報告の前に行うこと、決める役に `auto-merge.yml` の聖域とマージ条件の行と `human-merge` を付けたロボットの投稿を貼ること、4 つの前提（PR の base ブランチの `auto-merge.yml` の `parent-merge-approved`、見送りラベルが `human-merge` だけ、PR 本文の最初の `Closes`・`Fixes`・`Refs` が子 issue の番号、今の HEAD の判断のコメントがまだ無い）、`dev-workflow:decider` に `parent-merge-criteria.md` で判断させること、可のとき残っている `parent-merge-approved` を外し、HEAD を確かめてから `親のマージ判断: 可`・`親が見た HEAD:` のコメント → `parent-merge-approved` ラベルの順に付け、`reply --as parent` で子に伝え、エピックに `マージに回した` の 1 行を残すこと、否・不足・迷ったときは主に上げること、印を付けるのは親だけで直接マージしないことが書かれている

#### Scenario: マージ待ち以外の止まりは今までどおり
- **WHEN** 子の停止の記録の `止まった理由:` が `PR のマージ待ち（` で始まらない
- **THEN** 親はこの手順を行わず、手順 8 のとおりに扱う

### Requirement: Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る
`plugins/dev-workflow/scripts/epic-dispatch.sh` は `notify-closed [--relaunch] <epic> <child>` を受け付けなければならない（MUST）。`<epic>` か `<child>` が数字でない・引数の数が違う・`--relaunch` 以外のフラグがある・返事の送り方の環境変数が誤っているときは、使い方を出して exit 1 で終わり、`orca` を呼んではならない（MUST）。

`notify-closed` は次の順に確かめ、条件を満たした子にだけ返事を送らなければならない（MUST）。

1. 子 issue（`gh api repos/{owner}/{repo}/issues/<child>`）の `state` が `closed` でなければ `skipped <child> not-closed`、`state_reason` が `completed` でなければ `skipped <child> not-completed` を出す。`gh` が失敗したら `failed <child> issue` を出す
2. 今のワークツリーと同じ repoId・linkedIssue が `<child>`・archive されていない子のワークツリーが 0 件なら `skipped <child> no-worktree`、2 件以上なら `failed <child> ambiguous-worktree`、一覧を読めなければ `failed <child> list` を出す
3. そのワークツリーの `workspaceStatus` が `completed` なら `skipped <child> already-done`、コメント欄が `epic-stopped` でも `epic-stopped-seen` でもなければ `skipped <child> not-stopped` を出す
4. 条件を満たしたら、要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の `--as parent` と同じ処理（`--relaunch` があれば起動し直す）で、`記録先の issue #<child> は completed で閉じた。完了報告を書き、mark done で終える（停止の記録: <URL>）` を子に送る。`<URL>` は子 issue の 1 行目が `子の停止: 主の返事待ち` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` の最新のものの URL で、見つからなければ子 issue の URL とする。送信の結果が `failed <child> <段>` なら、それを出して exit 1 で終わる
5. 送れたら（`sent` か `relaunched`）、エピックに `親の判断: 子 #<child> 通した — 記録先が completed で閉じたので、完了報告と mark done を促した <URL>` の 1 行をコメントする。投稿できたら `notified <child>` を出し、投稿に失敗したら `unrecorded <child>` を出して stderr に投稿し直すコマンド（`gh issue comment <epic> --body <その 1 行>`）を出す。エピックへの記録は送信のあとに投稿しなければならない（MUST。送る前に投稿すると、送れなかったときに送っていない判断が残るため）

`skipped`・`notified`・`unrecorded` はどれも exit 0 で、stdout はちょうど 1 行とする（MUST）。`skipped` のときは子に何も送らず、エピックにも子 issue にも投稿してはならない（MUST NOT）。

develop の `references/epic.md`「エピックの扱い」→「回し方」の Orca 経路の手順 4 は、`closed <N>...` で起こされて `state_reason` が `completed` の子ごとに、`references/reply-after-idle.md` の表で起動し直すかを決めてから `scripts/epic-dispatch.sh notify-closed`（起動し直すなら `--relaunch`）を呼ぶと書かなければならない（MUST）。`notify-closed` は、依存が解けた子の `launch` より先に呼ぶと書く（MUST。`launch` が `failed` を返すと親は手順 6 で止まり、再開の手順 7 は `notify-closed` を呼ばないので、後ろに置くと閉じた子に送られないまま残る）。出力の扱いとして、`notified` と `skipped` は何もしない、`unrecorded` は stderr に出た投稿し直しのコマンドでエピックに 1 行を残す、`failed` は主に報告する（主に出す発言の 1 行目と最後の行は、要件「エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う」に従う）と書く（MUST）。`state_reason` が `completed` でない子には `notify-closed` を呼ばない（SHALL。作業されていない件に完了を促さない）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、偽の `orca` と `gh` で、上の振る舞い（止まった印のまま completed で閉じた子には返事が送られ、エピックに `親の判断: 子 #<child> 通した` で始まる 1 行が残ること、止まっていない子・既に完了の印の子・completed でない子・閉じていない子には何も送らずどこにも投稿しないこと、送れたがエピックへの投稿に失敗すると `unrecorded` を出すこと、送信の失敗で `failed` を出しエピックに投稿しないこと、引数の誤りで `orca` を呼ばないこと）と、手順 4 の文面が `notify-closed` を呼ぶこと、手順 4 の中で `notify-closed` が `launch` より先に現れることを確かめなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、`gh` の出力（子 issue の状態・閉じた理由・コメント）と `orca` の出力（ワークツリーの一覧・端末）である。拾いたい誤りは、止まった印のまま completed で閉じた子に何も届かずワークツリーが残り続けること、止まっていない子や作業されていない件に完了を促すこと、送れなかった返事をエピックに通したと残すことの 3 つである。次は通ってよく、この要件では止めない: 親が同じ `closed` を 2 回処理して同じ促しが 2 回届くこと（子は完了報告を 1 回書いて印を付けるだけ）／主が PR をマージせずに issue を completed で閉じた子に促しが届くこと（`reap` の既存の確認が片付けを止める）／判定のあとに子が自分で再開していて、促しが進んでいる子に届くこと。この 3 つの誤りを起こす入力の組み合わせが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 止まった印のまま completed で閉じた子には返事を送り、エピックに 1 行を残す
- **WHEN** 子 11 の issue が `closed`・`completed` で、子 11 のワークツリーのコメント欄が `epic-stopped-seen`、`workspaceStatus` が `in-review` で、`notify-closed 400 11` を実行する
- **THEN** 子 11 の端末に `親エピック #400 の判断（主の承認ではない）: 記録先の issue #11 は completed で閉じた。完了報告を書き、mark done で終える` で始まる文が送られ、エピック 400 に `親の判断: 子 #11 通した` で始まるコメントが投稿され、stdout は `notified 11` で exit 0 で終わる

#### Scenario: 止まっていない子が閉じたときは返事を送らない
- **WHEN** 子 11 の issue が `closed`・`completed` で、子 11 のワークツリーのコメント欄が空か `epic-resumed` で、`notify-closed 400 11` を実行する
- **THEN** stdout は `skipped 11 not-stopped` で exit 0 で終わり、`orca terminal send` も `orca terminal create` も呼ばれず、`gh issue comment` も呼ばれない

#### Scenario: completed でない理由で閉じた子には返事を送らない
- **WHEN** 子 11 の issue が `closed`・`not_planned` で、ワークツリーのコメント欄が `epic-stopped` で、`notify-closed 400 11` を実行する
- **THEN** stdout は `skipped 11 not-completed` で exit 0 で終わり、子の端末には何も送られず、`gh issue comment` は呼ばれない

#### Scenario: 既に完了の印を付けた子には返事を送らない
- **WHEN** 子 11 の issue が `closed`・`completed` で、ワークツリーの `workspaceStatus` が `completed`、コメント欄が `epic-stopped-seen` で、`notify-closed 400 11` を実行する
- **THEN** stdout は `skipped 11 already-done` で exit 0 で終わり、子の端末には何も送られない

#### Scenario: 送れたがエピックに残せなければ unrecorded を出す
- **WHEN** 条件を満たした子 11 への送信は成功し、エピック 400 へのコメントの投稿が失敗する
- **THEN** stdout は `unrecorded 11` で exit 0 で終わり、stderr に `gh issue comment 400` で始まり `親の判断: 子 #11 通した` を含む投稿し直しのコマンドが出る

#### Scenario: 送れなければエピックに残さず failed を出す
- **WHEN** 条件を満たした子 11 の端末への送信が失敗する
- **THEN** stdout は `failed 11 send` で exit 1 で終わり、`gh issue comment` は呼ばれない

#### Scenario: 引数の誤りでは orca を呼ばない
- **WHEN** `notify-closed 400 abc` か `notify-closed 400` を実行する
- **THEN** stderr に使い方が出て exit 1 で終わり、`orca` は呼ばれない

#### Scenario: 手順 4 は completed の子に notify-closed を呼ぶ
- **WHEN** develop の `references/epic.md`「回し方」の Orca 経路の手順 4 を読む
- **THEN** `state_reason` が `completed` の子ごとに `scripts/epic-dispatch.sh notify-closed` を呼ぶことと、`unrecorded`・`failed` の扱いが書かれている
- **AND** `notify-closed` は、依存が解けた子を `launch` するより前に書かれている

### Requirement: 起動し直した親は主の返事待ちの子を主に出し直す
`epic-dispatch.sh` は読み取り専用のサブコマンド `pending-owner <子>...` を持たなければならない（MUST）。各子について、同じ repoId・linkedIssue が一致・archive されていないワークツリーのコメント欄が `epic-stopped-seen` のものがあれば、`pending <N>` を 1 行ずつ出して exit 0 で終わる。`orca worktree set` を呼んではならない（MUST NOT）。`references/epic.md` の Orca 経路の手順 7（`回し方: Orca` を引き継いだ再開）は、`launch` の前に、`launch` に渡したことのある開いた子で `pending-owner` を呼び、`pending` の子ごとに、最新の `子の停止: 主の返事待ち` に一致する最新の `親の判断:`（手順 8 と同じ照合）が「通した」以外のものを、手順 8 と同じ報告で本文に出し直してから待ちに入ると書かなければならない（MUST）。再開済みかどうかは子のワークツリーのコメント欄（子が `mark resumed` で付ける `epic-resumed`）で決め、子 issue のコメントの新旧では決めない（MUST。停止後に親が投稿する `親の判断:` で除外されないため）。エピックのコメントの `親の判断: 子 #N 通した`（手順 8 と同じ author_association の条件）で、その行の停止の記録の URL が子の最新の `子の停止: 主の返事待ち` の URL と一致するものがある子は、通して送った解決済みの件なので再報告から外す（MUST。通した直後に子が `mark resumed` を付ける前に親が起動し直されても再報告しない）。`親の判断: 通すが送れなかった` の件は手順 8 と同じく送り直す。`references/reply-after-idle.md` の「親への適用」の復元元の表は、主の返事待ちの子の行（復元元は子のワークツリーの印 `epic-stopped-seen` と、子 issue の `子の停止: 主の返事待ち` および対応する `親の判断:`）を持たなければならない（MUST）。`tests/develop-skill.bats` は手順 7 と表の行を、`tests/epic-dispatch.bats` は `pending-owner` を確かめなければならない（MUST）。

この要件の入力は、`orca worktree list --json` が返す `repoId`・`linkedIssue`・`isArchived`・`comment`、`gh` が返す子 issue のコメント（投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のもの）である。拾いたい誤りは、起動し直した親が `epic-stopped-seen` の子を動いている子として 6 時間待ち、主に何も出さないことと、すでに再開した子や親が通した件を主に出し直すことの 2 つである。次は通してよく、この要件では止めない: 子が `mark resumed` を付け忘れ、`epic-stopped-seen` が残ったまま動いていること（主に出し直された主が子のタブで答えれば済む。次の `mark stopped` で上書きされる）／同じ linkedIssue のワークツリーが 2 つ以上あること（1 つでも `epic-stopped-seen` なら `pending`）／子 issue の `子の停止:` コメントの投稿者が権限の無いユーザーで、照合に使えず「判断が無い」として主に出されること。印の付け方の揺れを見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 手順 7 が主の返事待ちの子の出し直しを書いている
- **WHEN** `references/epic.md` の手順 7 を読む
- **THEN** `pending-owner` で `epic-stopped-seen` の子を集め、`launch` の前に手順 8 と同じ報告で出し直すと書いてある

#### Scenario: 復元元の表に主の返事待ちの子の行がある
- **WHEN** `reply-after-idle.md` の「親への適用」の表を読む
- **THEN** 主の返事待ちの子の行があり、復元元に `epic-stopped-seen`・`子の停止: 主の返事待ち`・`親の判断:` が書いてある

#### Scenario: pending-owner は受けた印のままの子だけを返す
- **WHEN** 子 11 が `epic-stopped-seen`、子 12 が `epic-resumed`、子 13 が `epic-stopped` の一覧で `epic-dispatch.sh pending-owner 11 12 13` を実行する
- **THEN** stdout は `pending 11` だけで、`orca worktree set` は呼ばれない

### Requirement: epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、エピックの子を同時に動かす数の上限を次のとおり決めなければならない（MUST）。環境変数 `EPIC_DISPATCH_MAX_PARALLEL` が設定されていればその値を使う。値は 1 以上の整数でなければならず、空文字・0・数字以外のときは stderr に変数名と使い方を出して exit 1 で終わる（MUST）。設定されていなければ既定値を使う。既定値は物理メモリの GiB（バイト数を 1073741824 で割った値）を 4 で割って切り捨てた値で、1 未満なら 1 とする（MUST）。物理メモリは `sysctl -n hw.memsize`（バイト）で読み、読めなければ `/proc/meminfo` の `MemTotal`（kB）で読む。どちらも読めない・数字でないときは既定値を 2 とし、stderr に物理メモリを読めなかったことを出す（MUST）。`/proc/meminfo` の代わりに読むファイルはテスト用の環境変数 `EPIC_DISPATCH_MEMINFO_FILE`（既定 `/proc/meminfo`）で差し替えられる（スクリプトの冒頭の説明にだけ書き、SKILL.md には書かない）。

`epic-dispatch.sh` はサブコマンド `max-parallel` を持ち、上の規則で決めた上限を stdout に数字 1 行で出して exit 0 で終わらなければならない（MUST）。`max-parallel` は `orca` も `gh` も `git` も呼んではならない（MUST NOT）。`EPIC_DISPATCH_MAX_PARALLEL` の値が誤っているときは上と同じく exit 1 で終わる。

既定値の式と、その根拠にした実測値（2026-10-20 にオーナーの Mac（物理メモリ 32 GiB）で、同時に動いていた Claude Code のセッション 36 個の RSS が本体のプロセスのみで 146〜404 MB、子プロセスを含めて最大 564 MB だったこと）、子 1 件に 2 GiB を見込み物理メモリの半分を子に充てるという見込み（うちテスト・ビルドの山の 1.5 GiB は実測でないこと）は、develop の `references/epic.md`「エピックの扱い」→「回し方」に書かなければならない（MUST）。

この要件の入力は、`EPIC_DISPATCH_MAX_PARALLEL` の値と、`EPIC_DISPATCH_MEMINFO_FILE` の値と、`sysctl` と `/proc/meminfo` が返す物理メモリ量である。拾いたい誤りは、設定が無いときに上限が無くなること、値の打ち間違い（`two`・`0`・空文字）で上限が無くなるか 0 になって何も起動しなくなることである。次は通してよく、この要件では止めない: 非常に大きい値（上限なしと同じに動く）／物理メモリが実際より大きく報告される環境／コンテナで物理メモリと使えるメモリが違う環境。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は `sysctl` を PATH 上のスタブにして、次の Scenario を確かめなければならない（MUST）。既存の `launch` のテストは、上限に引っかからないよう `EPIC_DISPATCH_MAX_PARALLEL` を大きな値にして従来どおりの出力を確かめる（SHALL）。

#### Scenario: 設定が無いときは物理メモリから決めた既定値を使う
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL` が未設定で、`sysctl -n hw.memsize` が `17179869184`（16 GiB）を返す環境で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stdout は `4` の 1 行で exit 0、`orca`・`gh`・`git` は呼ばれない

#### Scenario: 物理メモリが少なくても既定値は 1 を下回らない
- **WHEN** `sysctl -n hw.memsize` が `2147483648`（2 GiB）を返す環境で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stdout は `1`

#### Scenario: 物理メモリを読めなければ既定値は 2
- **WHEN** `sysctl` が失敗し `/proc/meminfo` も読めない環境で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stdout は `2`、stderr に物理メモリを読めなかったことが出る

#### Scenario: 環境変数が既定値より優先する
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=3` で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stdout は `3`

#### Scenario: 環境変数が 0 や数字以外なら使い方を出す
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=0` または `EPIC_DISPATCH_MAX_PARALLEL=two` で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stderr に `EPIC_DISPATCH_MAX_PARALLEL` と使い方が出て exit 1

#### Scenario: SKILL.md に既定値と根拠の実測値が書かれている
- **WHEN** develop の `references/epic.md`「回し方」を読む
- **THEN** `EPIC_DISPATCH_MAX_PARALLEL`、既定値の式（物理メモリの GiB を 4 で割って切り捨て・最小 1・読めなければ 2）、根拠の実測値（1 セッションの RSS の範囲）が書かれている

### Requirement: 親は枠が空いたら後回しの子を起動し、サブエージェント方式でも同じ上限を当てる
develop の `references/epic.md`「エピックの扱い」→「回し方」は、次を書かなければならない（MUST）。これは要件「エピックの条件・作り方・回し方・完了条件を規定する」の回し方を書き換えず、上限と後回しの子の扱いを足すものである（「解けた子を件数にかかわらず `launch` する」は、`launch` に渡す子の選び方として今までどおりで、件数を抑えるのは `launch` である）。

**Orca 経路**: 手順 1 に、`launch` の出力に `deferred <N>`（上限に達したので起動しなかった子。後回しの子）があること、上限は `EPIC_DISPATCH_MAX_PARALLEL`（無ければ物理メモリから決める既定値）であることを書く。手順 2 に、後回しの子は `wait` の位置引数（動いている子）にも `--watch-done`（片付け待ちの子）にも入れないことを書く。手順 3（`done` を処理したあと）と手順 8（`stopped` を処理したあと）に、後回しの子が残っていれば、2 に戻る前に依存の解けた開いた子を `launch` に渡し直す（起動済みの子は `skipped`、枠がまだ無ければまた `deferred`）ことを書く。手順 4 の依存グラフを読み直して解けた子を `launch` する処理が後回しの子も含むことを書く。`completed` 以外で閉じたときも枠は空くので、見送りの子を前提にしていた子を除いて、後回しの子が残っていれば 2 に戻る前に依存の解けた開いた子を `launch` に渡し直すことを書く。後回しの子を `launch` に渡し直すときは、最初に渡したときと同じ `--note` を付けること（後回しの子には注意書きが投稿されていない）を書く。`launch` のあと動いている子も片付け待ちの子も 0 件なのに後回しの子が残るときは、`wait` を呼ばずに主に報告し、報告に `launch` の stderr の枠を使っている子の行を添えることを書く。後回しの子の一覧はどこにも保存せず、起動し直した親（手順 7）は依存の解けた開いた子を `launch` に渡した出力で後回しの子を知ることを書く。

**サブエージェント方式**: 開始時に `scripts/epic-dispatch.sh max-parallel` を 1 回呼んでその値を上限にし（exit 1 なら stderr を添えて設定の誤りとして報告して止まる）、エピックの全部の子をまたいで、枠を使っている W の総数をその上限までに抑えることを書く（MUST）。W 1 体（名前付きで起こし SendMessage で再開する 1 系列）は、起こしてから、その W が担う change のループが終わる（PR がマージされる・記録先が閉じる）か、主の返事待ちで保留に入るまで、1 枠を使う。主の返事待ちは本体が `needs-approval` を付けて待つ場面（W の停止・G の保留のどちらも）とし、そこで枠を返す。コンテキスト上限で手渡した後任の W は前任の枠を引き継ぐ。1 つの子の中で change ごとに W を並列に起こすときは、その W ごとに 1 枠を使う。本体は、新しい子の最初の W を起こす前・同じ子の中で別の change の W を起こす前・保留から戻る W を再開する前に、そのつど空き枠（上限から枠を使っている W の数を引き、0 未満なら 0）を確かめ、空き枠が 0 なら起こさず再開もせずに待ちに回すことを書く（MUST）。枠が空いたら、待ちに回したもののうち、保留から戻る W の再開を先に、そのあと同じ子の中の別の change の W、そのあと依存の解けた新しい子の最初の W の順で起こすことを書く（SHALL。主の返事を受けた件と始まっている子を先に進めるため）。

**Orca 経路と両経路に共通の数え方**: 「枠を使っている子」に、完了の印の子・閉じた子・主の返事待ちで止まった子を数えないこと、その理由（止まった子はアイドルで、数えると主の返事が遅れるあいだ全体が止まる）を書く。Orca 経路では止まった子が戻るのは子のセッションの中なので親が止められず、戻った子の分だけ一時的に上限を超えうることを書く。サブエージェント方式では再開を本体が行うので、上の手順で再開前に空きを確かめ、上限を超えないことを書く。

`plugins/dev-workflow/tests/epic-dispatch.bats`（または `tests/develop-skill.bats`）は、SKILL.md のこれらの記述があることを確かめなければならない（MUST）。

この要件の入力は `references/epic.md` の本文である。拾いたい誤りは、親が `deferred` の子を動いている子として `wait` に渡して最長 6 時間待つこと、枠が空いても後回しの子を起動しないこと、サブエージェント方式で上限を超えて W を起こすことである。次は通してよく、この要件では止めない: `timeout` で起こされたときに後回しの子を `launch` に渡し直さないこと（枠は変わっていない）／サブエージェント方式で R1・G・決める役など W 以外の役割を枠に数えないこと（上限が抑えるのは W の数）／W が R1 や G の結果を待って動いていないあいだも 1 枠を使い続けること。手順書の読み方の揺れ（すり抜ける入力）が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: Orca 経路の手順に後回しの子の扱いが書かれている
- **WHEN** `references/epic.md` の Orca 経路の手順 1〜4・8 を読む
- **THEN** `deferred <N>` の意味、後回しの子を `wait` に渡さないこと、手順 3 と手順 8 のあとで後回しの子があれば `launch` に渡し直すこと、手順 4 の `launch` が後回しの子を含むことが書かれている

#### Scenario: 後回しの子だけが残ったら主に報告する
- **WHEN** `references/epic.md` の Orca 経路の手順を読む
- **THEN** 動いている子も片付け待ちの子も 0 件で後回しの子が残るとき、`wait` を呼ばずに `launch` の stderr を添えて主に報告することが書かれている

#### Scenario: サブエージェント方式に同じ上限が書かれている
- **WHEN** SKILL.md のサブエージェント方式の段落を読む
- **THEN** `epic-dispatch.sh max-parallel` の値を上限に、子をまたいだ W の総数を抑えること、W 1 体が枠を使う期間、新しい子の W・同じ子の別の change の W・保留から戻る W のどれも起こす前に空き枠を確かめること、待ちに回したものを起こす順（再開 → 同じ子の別の change → 新しい子）が書かれている

#### Scenario: 保留から戻る W は枠が空くまで再開しない
- **WHEN** 上限 2 のサブエージェント方式で、子 A と子 B の W を起こし、A が主の返事待ちで保留に入ったので子 C の W を起こしたあと、主が A に返事をした（B・C の W はまだ動いている）場面を、`references/epic.md` の手順に当てはめる
- **THEN** 手順からは、A の W を再開せずに待ちに回し、B か C の W が枠を返したら（ループが終わるか保留に入ったら）A を新しい子より先に再開する、と読める。同時に枠を使う W は 2 体を超えない

#### Scenario: 子の中で change ごとに W を起こすときも枠を使う
- **WHEN** 上限 2 のサブエージェント方式で、子 A の W と子 B の W が動いているあいだに、子 A が 2 つの change に割れて 2 つめの change の W を起こそうとする場面を、SKILL.md の手順に当てはめる
- **THEN** 手順からは、空き枠が 0 なので 2 つめの change の W を起こさずに待ちに回し、枠が空いたら新しい子より先に起こす、と読める

#### Scenario: Orca 経路で戻った子の扱いが書かれている
- **WHEN** SKILL.md の枠の数え方を読む
- **THEN** Orca 経路では戻った子の分だけ一時的に上限を超えうること、サブエージェント方式では再開前に空きを確かめるので超えないことが書かれている

#### Scenario: 枠を使っている子の数え方が書かれている
- **WHEN** `references/epic.md` の回し方を読む
- **THEN** 完了の印の子・閉じた子・主の返事待ちで止まった子を数えないことと、戻った子の分だけ一時的に上限を超えうることが書かれている

### Requirement: SKILL.md の回し方は再開時に adopt を呼び、待ちを終えるときに clear を呼ぶ

develop の `references/epic.md`「エピックの扱い」→「回し方」の Orca 経路は、次を書かなければならない（MUST）。

- 手順 7（`回し方: Orca` を引き継いだ再開）は、`reap` より前に、`launch` に渡したことのある子（エピックの状態ディレクトリにある記録の子と、エピックのコメントから分かる子を合わせたもの）で `scripts/epic-dispatch.sh adopt <エピック番号> <子>...` を 1 回呼び、そのあと `reap` → `pending-owner` → `launch` の順に進むと書く。`adopted` / `skipped` / `none` は何もせず、`failed <N> ambiguous` は主に聞かずにその子を残して進み、エピックに `子 #N の記録を取り込めなかった（ambiguous）` と 1 行コメントすると書く。`failed <N> state-unreadable`（その子の記録が読めない）も同じに、止まらずにその子を残して進み、`子 #N の記録を取り込めなかった（state-unreadable）` と 1 行コメントすると書く。理由の無い `failed <N>`（記録を書けなかった）は、stderr を添えて主に報告して止まると書く。`adopt` が stdout に何も出さず exit 1 で終わったら（`orca` が無い・一覧を読めない・origin を読めない）、stderr を添えて主に報告して止まると書く（`failed <N> ambiguous` の行を出して exit 1 で終わったときは止まらない）
- 手順 3・4・7 の「動いている子と片付け待ちの子がどちらも 0 件なら `wait` を呼ばずに待ちを終える」箇所は、待ちを終える前に `scripts/epic-dispatch.sh clear <エピック番号>` を 1 回呼ぶと書く。`cleared` / `none` は何もせず、exit 1 は主に報告すると書く。`clear` は待ちを終えるときに 1 回だけ呼び、エピックを閉じるのを待たない
- 手順 3 の `kept` の扱いのうち「`ambiguous`・`not-child` は対象を特定できないので確かめず残す」から `not-child` を外す（`reap` が出さなくなる）。`kept <N> state-unreadable` は確かめず残し、`子 #N のワークツリーを残した（state-unreadable） — <reap の stderr の記録のパス>` と 1 行コメントすると書く
- 手順 6 の「`--watch-done` か `--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わった（今のワークツリーを Orca から読めない）ときは親ワークツリーで開き直す」は、`wait` が Orca を読まなくなるので消し、`launch` が exit 1 で子を 1 件も作らなかったときと `adopt` が stdout に何も出さず exit 1 で終わったときの報告として書き直す
- 完了条件の節は、エピックの完了時に状態のディレクトリが `clear` で消えていることを、動いている子が無くなったときの報告の前に確かめると書く
- 子の状態の正本は状態の記録で、Orca のボードの列とコメント欄は記録の写しであること、オーナーが Orca の画面で印を手で変えても親の見張りには効かないことを書く
- 「エピックの子が主の返事を待って止まるとき」の印の説明は、`mark stopped` / `mark resumed` が自分の記録に印を付け、Orca の画面には写しが出ると書く（子の手順・呼ぶ順序・出力の扱いは変えない）

`references/reply-after-idle.md` のうち、主の返事待ちの子を Orca のコメント欄の `epic-stopped-seen` で見分けると書いた箇所は、記録の `stop` が `stopped-seen` で見分けると書き直さなければならない（MUST）。

#### Scenario: 手順 7 が adopt から始まる

- **WHEN** `references/epic.md` の回し方の手順 7 を読む
- **THEN** `adopt` を `reap`・`pending-owner`・`launch` より前に呼ぶと書いてあり、`failed <N> ambiguous` と、stdout に何も出さない exit 1 の扱いが書き分けてある

#### Scenario: 待ちを終えるときに clear を呼ぶ

- **WHEN** `references/epic.md` の回し方の手順 3・4・7 のうち、`wait` を呼ばずに待ちを終える箇所を読む
- **THEN** どの箇所も待ちを終える前に `clear <エピック番号>` を 1 回呼ぶと書いてある

#### Scenario: Orca の画面の印は写しだと書いてある

- **WHEN** `references/epic.md`「エピックの扱い」を読む
- **THEN** 子の状態の正本が状態の記録で、Orca の画面の印を手で変えても親の見張りに効かないと書いてある

### Requirement: channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない

channel の本体は AskUserQuestion を呼んではならない（MUST NOT）。主に聞くときは、依頼の届いたチャンネル（依頼の発言の開きタグの `chat_id`）にチャンネルの返信ツールで質問を送り、そのターンを終えなければならない（MUST）。依頼がチャンネルから届いていないときは、そのセッションの運用が決める主への連絡先に送り、連絡先が分からなければ記録先に質問をコメントして `needs-approval` を付けて止まる（MUST）。記録に残す問い（保留の依頼・2 周キャップ超え・PR トークン上限）は先に PR か記録先のコメントに書き、チャンネルの質問にそのコメントのフル URL を添える（MUST）。

`skills/develop/references/channel.md` の「channel の聞き方」は、develop と develop から読む文書の「interactive は AskUserQuestion で聞く」を、channel ではこの聞き方に読むと 1 か所に書き、対象の文書（`skills/develop/references/decision-criteria.md`・`skills/develop/references/epic-child-stop.md`・`skills/develop/references/fix-check.md`・`skills/develop/references/roles/spec-reviewer.md`・`skills/develop/references/roles/worker/common.md`・`skills/develop/references/roles/worker/spec.md`・`templates/escalation-tripwires.md`・`commands/develop.md`・`commands/work-issue.md`・`skills/issueify/SKILL.md`）を、`plugins/dev-workflow/` からの相対パスの 1 つの形で挙げなければならない（MUST）。`plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く。`changes/` は変更の記録で、手順として読まれない）で `AskUserQuestion` を含むファイルは、SKILL.md と `skills/develop/references/channel.md` を除いてすべて、`plugins/dev-workflow/` からの相対パスがそのまま（バッククォートで囲んだ形で）この列挙に載っていなければならず（MUST）、bats で確かめる（SHALL。読み替えを 1 か所に書く方式は、列挙が漏れると漏れた文書の本体の手順が AskUserQuestion に流れるため）。`commands/develop.md` は、引数の分岐 ②⑤ の候補の提示と issueify フォールバックの承認が channel ではチャンネルでの質問になることを、その場にも書かなければならない（MUST。本体は SKILL.md より先にこの分岐を処理するため）。

この要件の守備範囲は、channel で本体が AskUserQuestion に流れる経路を develop の文面から無くすことである。拾いたい誤りは、develop の手順のどこかが channel の本体に AskUserQuestion を呼ばせること。develop 以外のスキル（wt-clean など）が AskUserQuestion を呼ぶことと、本体が文面に反して呼ぶことを機械的に止めることは、この要件の範囲に入れない。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 2 周キャップ超えで選び直しが要る

- **WHEN** channel の本体で、仕様レビューの直し方の判定が「選び直しが要る」になる
- **THEN** 本体は記録先に `needs-approval` を付けて経緯をコメントし、そのコメントの URL を添えた質問を依頼の届いたチャンネルに送ってターンを終え、AskUserQuestion を呼ばない

#### Scenario: 引数なしの /develop をチャンネルで頼まれた

- **WHEN** channel の本体が `commands/develop.md` の分岐 ⑤（引数なし）を処理する
- **THEN** 開いている issue の一覧と 2 つの選択肢をチャンネルに送ってターンを終え、AskUserQuestion を呼ばない

#### Scenario: AskUserQuestion の経路が残っていない

- **WHEN** SKILL.md と `commands/develop.md` で `AskUserQuestion` を含む行を読む
- **THEN** その行か、`references/channel.md` の読み替えの規則によって、channel では AskUserQuestion を呼ばないことが読み取れる

#### Scenario: AskUserQuestion に触れるファイルが列挙から漏れていない

- **WHEN** bats が `plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く）で `AskUserQuestion` を含むファイルを集める
- **THEN** SKILL.md と `skills/develop/references/channel.md` 以外のすべてのファイルの `plugins/dev-workflow/` からの相対パスが、バッククォートで囲んだ形で `references/channel.md` の読み替えの対象の列挙に載っている

### Requirement: 別のリポジトリの子を含むエピックの回し方を SKILL.md に書く

develop の `references/epic.md`「エピックの扱い」は、エピックの子がエピックと別のリポジトリにあるときの挙動を、既存の要件（子エピックの外し方・マージ待ちの子・子の側の手順・コメントの書式）の読み替えとして書かなければならない（MUST）。読み替えは次の表のとおりで、同じリポジトリの子の呼び出しの形・書式・判定は表の外では変えない（MUST）。既存の要件の本文は書き直さず、この要件が読み替えを持つ。

| 既存の書き方 | 別のリポジトリの子での読み替え |
|---|---|
| 子の依存を `gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by` で読む | 子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/dependencies/blocked_by`）で読む。前提の issue のリポジトリは応答の `repository_url` から取り、前提の state もそのリポジトリで読む。前提が別リポジトリにあっても閉じていれば解けている。前提の issue を `gh` が読めないときは、解けていないものとして待つ（この change で新しく決めた扱い。今の SKILL.md にこの記述は無い） |
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
| `後で別に起動するエピック:` の行で子を外す照合（手順 2・`timeout` と `closed` の確認） | 別のリポジトリの子は `<owner>/<repo>#N` の形の行で照合する（同じリポジトリの子は `#N`） |
| 子を `route`・`launch`・`wait`（位置引数と `--watch-done`）・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt` に渡す | 別のリポジトリの子は `<owner>/<repo>#N` の形で渡す（同じリポジトリの子は番号だけ） |
| `references/epic.md` の注意書き `親エピックからの注意書き: #<エピック番号>`、手順 1 の「起点は `origin/main`」 | 別のリポジトリの子は注意書きが `親エピックからの注意書き: <エピックの owner>/<repo>#<E>`（子のリポジトリの issue に残る）。起点は `--base` / `EPIC_DISPATCH_BASE`、無ければ子のリポジトリの既定ブランチ |
| `stop-judge.sh <epic> <child>` の `<child>` は番号 | 番号か `<owner>/<repo>#<N>`。後者は子の本文・コメントを `repos/<o>/<r>/issues/<N>` から読み、エピックのコメントの過去の判断を `親の判断: 子 <o>/<r>#<N> ` で始まる行から探す。同じリポジトリの子は今までどおり。入力文の見出しも同じ呼び方にする |

サブエージェント方式（unmanned・channel・Orca 管理外で選ばれる）では、別のリポジトリの子を W に渡してはならない（MUST。W は親のリポジトリに worktree を作るので、別のリポジトリの issue を親のリポジトリの PR として実装してしまう）。本体はエピックに `子 <owner>/<repo>#N は別のリポジトリなので Orca 経路でだけ起動する` と 1 行コメントし、その子と、その子を前提にする子を起こさずに、主に報告する（1 行目と最後の行は、`~/.claude/output-styles/readable.md` の節 3 の書き分けに従う）。

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
- **WHEN** SKILL.md の「サブエージェント方式」を読む
- **THEN** 別のリポジトリの子を W に渡さず、エピックに 1 行残して、その子とそれを前提にする子を起こさずに主に報告すると書いてある

#### Scenario: コメントの書式が書いてある
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** 別のリポジトリの子は `子 <owner>/<repo>#N`・`後で別に起動するエピック: <owner>/<repo>#N`・`親の判断: 子 <owner>/<repo>#N 通した` と書くことが書いてあり、同じリポジトリの子は今のままの書式で残っている

#### Scenario: マージ待ちの子を子のリポジトリで扱うと書いてある
- **WHEN** SKILL.md の「マージ待ちの子」を読む
- **THEN** `auto-merge.yml` の取得・`親のマージ判断:` のコメント・`parent-merge-approved` のラベルを子のリポジトリの PR に付けること、認証アカウントが子のリポジトリで権限を持たないときは主に上げることが書いてある

#### Scenario: 子の側が親エピックのリポジトリにコメントする
- **WHEN** SKILL.md の「`nested` を受けたセッション」を読む
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

### Requirement: 着手できる子が 1 件でも別セッション方式で回す
`plugins/dev-workflow/scripts/epic-dispatch.sh` の `route` は、エピックの子のセッションでなく（`nested` でなく）、子の番号が 1 件以上あるときは、子の件数が何件でも、起動部品が使えれば `orca` か `tmux` を出さなければならない（MUST。順は要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `route` の段落のとおり）。子が 0 件のとき、起動部品が使えないときは `subagent` を出す。`nested` の判定が先に行われること、`orca worktree current` を 1 回の `route` で 1 回だけ呼ぶこと、子の番号が数字でなければ exit 1 で終わることは変えない。develop の `references/epic.md`「エピックの扱い」の「経路の決め方」は、`orca` になる条件として子の件数の下限（2 件以上など）を書いてはならない（MUST NOT）。着手できる子が 0 件のとき `subagent` になることと、エピックの子のセッションでは件数によらず `nested` になることは、`route` の実際の結果の説明として書いてよい。

経路は `/develop <エピック番号>` の最初の開始時に 1 回決めて途中で変えず、再開時は `回し方:` で始まる最新のコメントから引き継ぎ、すでに `回し方: サブエージェント` と記録したエピックを途中で 別セッション方式に切り替える規則は置かない（SHALL。進行中のサブエージェント方式の子と 起動部品の子ワークツリーの子が混在する状態を扱う規則が無く、別セッション方式の手順の規定は別の変更が扱うため）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」の `route` が `orca` を返す条件の規定、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `route` の判定の規定、要件「エピックの子への注意書きと…引き継ぐ」の `route` の段落のうち、子の件数の条件に関わる部分に優先する。

この要件の守備範囲で入力として扱うのは、本体が依存グラフから求めた子の番号の並びと、`orca` の有無・`orca worktree current` の終了コードである。この要件で新しく拾う誤りは無く、引数の検査（数字でない番号を exit 1 で止めること）は既存の要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」が受け持つ。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。次は通してよく、この要件では止めない: 存在しない・重複した・blocked されている子の番号は `route` では検証しない（既存の規定どおり）／この変更より前に `回し方: サブエージェント` と記録した進行中のエピックは、そのエピックが終わるまでサブエージェント方式のまま進む。

#### Scenario: Orca 管理のワークツリーで子が 1 件なら orca を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: 子が 2 件でも今までどおり orca を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: 子が 1 件でも orca が無い・Orca 管理外で、tmux の中でもなければサブエージェント方式になる
- **WHEN** `orca` が PATH に無い環境と、`orca` が PATH にあり `orca worktree current` が exit 1 を返す環境のそれぞれで、環境変数 `TMUX` が空のとき `epic-dispatch.sh route 11` を実行する
- **THEN** どちらも stdout は `subagent` の 1 行で exit 0

#### Scenario: 子が 0 件なら Orca 管理下でも subagent を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route` を子なしで実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: nested の判定は子が 1 件でも先に行われる
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `orca` が PATH にあり Orca 管理のワークツリーにいるとき、`epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `nested` の 1 行で exit 0、`orca` は呼ばれない

#### Scenario: SKILL.md の経路の決め方に orca になる条件としての件数の下限が書かれていない
- **WHEN** `skills/develop/references/epic.md` の「エピックの扱い」の「経路の決め方」を読む
- **THEN** `orca` になる条件が「`orca` が PATH にあり、本体が Orca 管理のワークツリーにいる」だけで書かれ（`tmux` になる条件は別に「`TMUX` が空でなく `tmux` が PATH にある」と書かれ）、`orca` になる条件として blocked されていない子の件数の下限（2 件以上など）が無く（着手できる子が 0 件のとき `subagent` になる旨の文はあってよい）、経路は最初の開始時に 1 回だけ決めて途中で変えないこと、再開時は `回し方:` のコメントから引き継ぐことは残っている

#### Scenario: Orca 管理外でも tmux の中なら tmux を返す
- **WHEN** `orca` が PATH に無く、環境変数 `TMUX` が空でなく、`tmux` が PATH にある環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `tmux` の 1 行で exit 0

#### Scenario: Orca 管理下かつ tmux の中なら orca が先
- **WHEN** Orca 管理のワークツリーにいて、環境変数 `TMUX` も空でない環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `orca` の 1 行である

#### Scenario: 環境変数で部品を固定できる
- **WHEN** Orca 管理のワークツリーにいて `TMUX` も空でない環境で、`EPIC_DISPATCH_LAUNCHER=tmux` を付けて `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `tmux` の 1 行である。`EPIC_DISPATCH_LAUNCHER=orca` で Orca 管理外なら `subagent`、`EPIC_DISPATCH_LAUNCHER=zellij` なら stderr に使い方が出て exit 1 である

#### Scenario: tmux の外ならサブエージェント方式になる
- **WHEN** `orca` が PATH に無く、環境変数 `TMUX` が空の環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `subagent` の 1 行である

### Requirement: 回し方の手順は推定した done も子の付けた done と同じに片付ける

develop の `references/epic.md`「エピックの扱い」→「回し方」の別セッション方式の手順は、次を書かなければならない（MUST）。

- 手順 2 の `--watch-done` の説明に、`wait` は片付け待ちの子のうち、完了の印の無いまま記録先が `completed` で閉じてから `EPIC_DISPATCH_DONE_IDLE_SEC`（既定 1800 秒）以上たち、子のトランスクリプト（サブエージェントのものを含む）の最後の活動もそれ以上前の子を、LLM なしで完了と推定して `done <N>` を返すこと（`status` が `waiting` の子・止まった印の子・トランスクリプトが無い子は推定しない）
- 手順 3 に、推定の `done` も子が付けた `done` と同じに `reap` を 1 回呼んで扱い、区別しないこと（片付けの安全確認は `reap` が行う）。同じ子が `closed` と `done` の両方の行に出たら、手順 4 を処理してから手順 3 の `reap` を呼ぶこと
- 手順 4 に、`notify-closed` が `skipped <N> not-stopped` を返した子（止まった印を付けずに見張りを終えた子。主に直接マージを頼んだ子など）は、片付け待ちとして `--watch-done` に渡しておけば、子のセッションが止まって閾値を過ぎたあとの `wait` が完了と推定すること。主に子のステータスを変えるよう頼まない（MUST NOT）

`plugins/dev-workflow/tests/epic-dispatch.bats`（または `tests/develop-skill.bats`）は、手順 2〜4 の文面に `EPIC_DISPATCH_DONE_IDLE_SEC` と推定の扱いがあることを確かめなければならない（MUST）。

#### Scenario: 回し方に推定の扱いが書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」の「回し方」の手順 2〜4 を読む
- **THEN** 手順 2 に `wait` が完了を推定する条件と `EPIC_DISPATCH_DONE_IDLE_SEC` が、手順 3 に推定の `done` も同じに `reap` することと、同じ子が `closed` と `done` の両方に出たら手順 4 を処理してから `reap` を呼ぶことが、手順 4 に `skipped <N> not-stopped` の子は `--watch-done` の推定で片付くことが書かれている
