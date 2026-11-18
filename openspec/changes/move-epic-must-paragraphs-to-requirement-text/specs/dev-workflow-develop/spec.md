## MODIFIED Requirements

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
`skills/develop/references/epic.md` と入口から場面ごとに読む参照先は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。

**回し方（経路の決め方）**: interactive の本体は子の依存グラフを読み、blocked されていない子の番号を `plugins/dev-workflow/scripts/epic-dispatch.sh route` に渡して経路を決める（MUST）。`route` が `orca` か `tmux` を返したとき（Orca 管理のワークツリーにいる、または tmux の中にいる）は、その起動部品で子を別のセッションとして起こす **別セッション方式**、`subagent` を返したときは **サブエージェント方式**で進める（MUST）。別セッション方式とサブエージェント方式は二本立てではなく、子を起こす手段を起動部品として差し替える一本の手順で書く（MUST。共通の手順に、部品ごとに違う点だけを部品ごとの欄に書く）。経路は `/develop <エピック番号>` の最初の開始時に 1 回決め、途中で変えてはならず（MUST NOT）、決めた経路をエピックに `回し方:` で始まる 1 行コメントで残す（MUST）。別セッションで同じエピックを再開したときは、`回し方:` で始まる最新のコメントを読んで経路を引き継ぎ、`route` をやり直してはならない（MUST NOT）。最新の `回し方:` が `Orca` か `tmux` のときは、本体が `epic-dispatch.sh launch` と `adopt` に環境変数 `EPIC_DISPATCH_LAUNCHER=<そのコメントの部品名（小文字の orca か tmux）>` を付けて呼ばなければならない（MUST。付けないと部品を今の環境から選び直し、前のセッションの記録の子と別の部品で新しい子が起動しうる）。その部品が今の環境で使えず `launch`・`adopt` が exit 1 で終わったら、別の部品にもサブエージェント方式にも振り替えず、stderr を添えて主に報告して止まる（MUST。部品の違う子の混在を作らない）。`reply`・`notify-closed`・`reap`・`wait --resolve` は記録の `launcher` で部品が決まるので、再開で環境が変わっても部品名を渡さない。unmanned（`--unmanned`）では `route` を呼ばず、サブエージェント方式で進める（MUST。背景で待って起こされる動きが 1 サイクル 1 仕事と合わないため）。channel でも `route` を呼ばず、サブエージェント方式で進め、エピックに `回し方: サブエージェント（channel モード）` を残す（MUST）。channel で再開したエピックの最新の `回し方:` が別セッション方式（Orca・tmux）なら、`launch` もサブエージェント方式も使わず、その旨をチャンネルで主に報告して止まる（MUST。channel は別セッション方式を引き継がない）。channel の本体は、develop の手順のために別の Claude Code セッション（Orca・tmux など）を起こしてはならない（MUST NOT。別に起こしたセッションには印 `DEV_WORKFLOW_UNATTENDED` が届かず、その画面を誰も見ていないので、子が主の返事待ちで止まっても誰も気づかない）。develop の外で住人が別のセッションを起こすときの印の渡し方は、この要件の範囲に入れない（#1123）。

**回し方（別セッション方式）**: 本体は `epic-dispatch.sh launch` で子ごとに起動部品（Orca か tmux）の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。再開時も、依存が解けた open の子を、最新の `回し方:` の部品名を付けた `launch` に渡し（上の段落のとおり）、起動済みの子は `launch` の `skipped` で見分ける（同じ子を二重に起動しない）。本体は `launch` が `launched` / `skipped` を出した子を動いている子とし、`epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める。`closed` なら閉じた子ごとに `state_reason` を読み、`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントして依存グラフを読み直し、解けた子を件数にかかわらず `launch` する。`completed` 以外ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子を起動してはならず（MUST NOT）、ユーザーに報告する。そのあと残りの動いている子で再び `wait` する。`timeout` なら、子 issue もエピックも読まず、主に報告もせず、直前と同じ引数の `wait` を 1 回掛け直してターンを終える（要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」）。子が記録と印を残さずに自分のタブでユーザーに質問して止まっている場合は、親が気づけないことを書く（SHALL）。`wait` の `error` と `launch` の `failed` はユーザーに報告して止まる。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子セッションのモデルは `epic-dispatch.sh launch` が起動時に起動コマンド（既定は `plugins/dev-workflow/bin/cld`）に `--model` を付けて指定し、既定は `opus` で環境変数 `EPIC_DISPATCH_MODEL` で変えられること（Claude Code の既定モデルは子に効かないこと）、コマンド部分（既定は `bin/cld` の絶対パス。ログイン zsh のシェル関数には頼らない）は環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ、Orca に設定したコマンドはハーネスから読めないので（tmux の部品はこの環境変数のコマンドをそのまま打ち込む）Orca 側のコマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変えることを書く（SHALL）。子セッションの `--dangerously-skip-permissions` は環境変数 `CLD_DEFAULT_ARGS` に入れた値で付き、`launch` と、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）が親の環境の `CLD_DEFAULT_ARGS` を子の起動コマンドの前に代入として付けて子へ渡すこと（親の環境に値が無ければ付けず、子は許可の確認画面で止まる。許可を飛ばしたければ親の環境に `CLD_DEFAULT_ARGS` を置くことが前提であること）、`epic-dispatch.sh` 自身が足すのは `--settings` と `--model` だけであること、マージを止めているのは develop と pr-review-gate の規則と hooks であることを書く（SHALL）。本体は子の PR を `gh pr merge` や merge API で直接マージしてはならない（MUST NOT）。子の PR のマージは、子セッションの中の人の承認か自動マージの処理（`.github/workflows/auto-merge.yml`）が行い、`human-merge` の付いた子の PR は、本体が要件「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」の手順で判断の印を付けたときに限って自動マージの処理がマージすることを書く（SHALL）。

**回し方（サブエージェント方式）**: 今までどおり blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと。本体が W を `isolation: "worktree"` で spawn して用意し、W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。

どちらの経路でも、スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった新しい問題は新しい子 issue として追加する。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

この要件の入力は、`/develop <エピック番号>` で渡される記録先の issue、`scripts/epic-dispatch.sh route` の出力（`orca`・`tmux`・`subagent`・`nested`）、エピックの `回し方:` で始まるコメント、`wait` の出力の 1 行（`closed`・`done`・`timeout`・`stopped`・`unrecorded`・`error`）、`launch` の出力（`launched`・`skipped`・`failed`・`deferred`）である。拾いたい誤りは、`route` や最新の `回し方:` を読まずに経路を選び直すこと、`nested` を受けたのにエピックを展開すること、出力の 1 行を取り違えて待ちを終えたり子を起こしたりすること、子が全部マージされただけでエピックを閉じることである。次は通してよく、この要件では止めない: `回し方:` のコメントが無い新しいエピックで `route` から経路を決めること／`timeout` で起こされたとき何もせず再び待つこと／子が記録を残さずに自分のタブで質問して止まったとき、親が検知できないこと（手順書にその旨が書かれている）。手順書の読み方の揺れ（すり抜ける入力）が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

回し方の本文は `references/epic-loop.md`（通常の進行）と `references/epic-subagent.md`（サブエージェント方式）、停止の解決は `references/epic-stop.md` に置く（MUST）。入口に親の起動・片付け・見張りの操作本文を残してはならない（MUST NOT）。

#### Scenario: エピックの 4 節が存在する
- **WHEN** `references/epic.md` の「エピックの扱い」節を読む
- **THEN** 条件・作り方・nested・完了条件と読むものの表があり、親の通常進行は epic-loop.md、停止は epic-stop.md、委任は epic-delegation.md、マージ待ちは epic-merge-wait.md、別 repo は epic-multirepo.md、サブエージェント方式は epic-subagent.md へ案内され、完了条件に「子が全部マージされただけでは閉じない」が書かれている

#### Scenario: 子は並列に worktree 分離で起こす
- **WHEN** `references/epic-subagent.md` のサブエージェント方式と `references/epic.md` の「エピックの扱い」を読む
- **THEN** サブエージェント方式として、blocked されていない子から `isolation: "worktree"` で 1 ループを並列に起こすことが書かれ、どちらの経路でも新しい問題は子の中で直さず新しい子 issue にすることが書かれている

#### Scenario: 回し方に経路の振り分け条件が書かれている
- **WHEN** `references/epic-loop.md` の「経路の決め方」を読む
- **THEN** `epic-dispatch.sh route` の出力で経路を決めること、`orca` になる条件（`orca` が PATH にある・本体が Orca 管理のワークツリーにいる）、`tmux` になる条件（Orca 管理外で `TMUX` が空でなく `tmux` が PATH にある）、環境変数 `EPIC_DISPATCH_LAUNCHER` で固定できること、どれでもなければサブエージェント方式で進むこと、経路を最初の開始時に 1 回決めて途中で変えないこと、再開時は `回し方:` のコメントから経路を引き継ぐこと、unmanned はサブエージェント方式のままであることが書かれている

#### Scenario: 別セッション方式の本体は wait の出力で次を決める
- **WHEN** 別セッション方式の本体の手順を読む
- **THEN** `launch` で子を起動し、`wait` を `run_in_background: true` で起動して待つこと、`closed` で `state_reason` を読み `completed` なら `子 #N マージ → 残り k 件` をコメントして解けた子を `launch` し、それ以外なら `見送り` とコメントして後続を起動せず報告すること、`timeout` で子を調べ直さず報告もせずに同じ `wait` を掛け直すこと、子のタブでの質問は検知できないこと、本体が子の PR を直接マージせず、`human-merge` の付いた子の PR は本体が判断の印を付けたときに限って自動マージの処理がマージすることが書かれている

#### Scenario: 別セッション方式に子セッションのモデルの決め方が書かれている
- **WHEN** 別セッション方式の説明を読む
- **THEN** 子セッションのモデルは `epic-dispatch.sh launch` が起動コマンド（既定 `bin/cld`）に `--model` を付けて指定すること、既定が `opus` であること、`EPIC_DISPATCH_MODEL` で変えられること、Claude Code の既定モデルが何であっても子は指定したモデルで起動すること、コマンド部分を `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ Orca 側のコマンドを変えたら合わせて変えること、`--dangerously-skip-permissions` は環境変数 `CLD_DEFAULT_ARGS` から来て、`launch` と、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）が親の環境の値を渡すこと、親に値が無ければ子は許可の確認画面で止まることが書かれている

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

#### Scenario: epic-loop.md の通常進行が起動部品の差し替えとして書かれている
- **WHEN** develop の `references/epic.md` の表から `references/epic-loop.md` の「通常進行の手順」と、経路に応じた `references/epic-subagent.md` を読む
- **THEN** 起動・待ち・閉じた子・止まった子・片付け・完了の手順は 1 本で書かれ、Orca の部品・tmux の部品・サブエージェント方式のどれで起こすかによって違う点だけが部品ごとの欄に書かれており、「Orca 経路」と「サブエージェント方式」を別々の手順として二重に書いていない。サブエージェント方式は状態の記録を書かない、と書かれている

### Requirement: エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、子のセッションを閉じて同じワークツリーで `/develop #<N>` だけを打ち直しても、親が `launch --note` で渡した注意書きと「エピックの子である」ことが失われないようにしなければならない（MUST）。この要件は、要件「エピックの並列起動は 1 段で止める」のうち `route` が `nested` を返す条件と `launch` の拒否の条件、`references/epic.md` に書かせている親エピックの番号の出どころ（「親エピック（`EPIC_DISPATCH_PARENT_EPIC` の番号）」。この要件では `route` の stderr の `parent epic: #<N>`）、同要件の守備範囲のうち変数の無いセッションに関する 2 項（「この変更の前に起動された子セッションには変数が無く従来どおり展開しうる」は、Orca 経路で作られた子ワークツリーなら親子関係で `nested` になる。「サブエージェント方式で起こされた子（変数が無い）は止まらない」は、そのセッションのワークツリーが親ワークツリーを持てば `nested` になり、持たなければ今までどおり止まらない）、および要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の判定と `launch` の呼び出し順に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

**注意書きのコメント**: `launch --note <text>` は、`orca worktree create` が exit 0 で終わった子ごとに 1 回、端末を作る前に、`gh issue comment <N> --body <本文>` で子 issue にコメントしなければならない（MUST）。本文の 1 行目は `親エピックからの注意書き: #<epic>`、2 行目は空行、3 行目以降は `<text>` そのものとする（MUST）。`--note` が無いとき、`skipped <N>` の子、worktree create が非 0 で終わった子には投稿してはならない（MUST NOT）。worktree create が exit 0 で終わり、その JSON に `path` が無くて `failed <N>` になる子には投稿する（SHALL。ワークツリーが作られていれば次の `launch` で `skipped` になり、投稿の機会が無くなるため）。投稿が非 0 で終わっても、その子の stdout の 1 行と `launch` の exit code を変えてはならず（MUST NOT）、stderr に `note not posted to #<N>` を含む行と、同じ本文を単一引用符で囲んだ `gh issue comment <N> --body '<本文>'` を出す（SHALL）。最初の指示の文面に `<text>` を含める既存の規定は変えない（SHALL）。

**エピックの子の判定**: 次のどちらかが成り立つとき、そのセッションを「エピックの子」とし、親エピックの番号を次のとおりとする（MUST）。

1. 環境変数 `EPIC_DISPATCH_PARENT_EPIC` が空でない。親エピックの番号はその値。このとき `orca` を呼んではならない（MUST NOT）
2. 1 が成り立たず、`orca` と `jq` が PATH にあり、`orca worktree current --json` が exit 0 で終わり、その `.result.worktree.parentWorktreeId` が空でも `null` でもなく、`orca worktree list --json` の `.result.worktrees[]` のうち `id` がその値と一致するワークツリーの `linkedIssue` が `null` でない。親エピックの番号はその `linkedIssue`。親ワークツリーの `isArchived` は判定に使わない（SHALL）

`orca worktree list --json` は、`parentWorktreeId` が空でも `null` でもないときだけ呼ぶ（MUST）。`jq` が無い、`orca worktree list --json` が非 0 で終わる、出力の `.result.worktrees` が配列でないときは、2 は成り立たないとして扱う（MUST）。ただし `launch` は、`parentWorktreeId` が空でも `null` でもないのに一覧を読めなかったとき（非 0 で終わる、または `.result.worktrees` が配列でない）、子かどうかを決められないので先へ進まずに止まる（下の `launch` の規定）。

**`route`**: 子の番号の検査のあと、子の件数によらず最初にエピックの子の判定を行い、エピックの子なら stdout に `nested` の 1 行、stderr に `parent epic: #<親エピックの番号>` の 1 行を出して exit 0 で終わらなければならない（MUST）。エピックの子でなければ、子が 1 件以上で `orca worktree current --json` が exit 0 なら `orca`、それ以外は `subagent` を出す（MUST）。`orca worktree current` は 1 回の `route` で 1 回だけ呼ぶ（SHALL）。2 の判定の途中で一覧を読めなかったとき、および `orca worktree current --json` が exit 0 で `jq` が PATH に無いとき（`parentWorktreeId` を読めない）は、stderr に `could not read the parent worktree` を出す（SHALL）。

**`launch`**: 引数の検査のあと、1 が成り立てば今までどおり `orca` も `git` も呼ばずに stderr に理由を出して exit 1 で終わる（MUST）。1 が成り立たなければ、`orca worktree current --json` の直後、`git rev-parse --show-toplevel` より前に 2 を判定し、成り立てば `git`・`orca worktree set`・`orca worktree create` を 1 つも呼ばず、stdout には何も出さず、stderr に親エピックの番号と `child epics are not expanded here` を含む理由を出して exit 1 で終わらなければならない（MUST）。1 による拒否の stderr も `child epics are not expanded here` を含む（SHALL）。1 が成り立たず、`parentWorktreeId` が空でも `null` でもないのに 2 の判定の途中で一覧を読めなかったときは、`git`・`orca worktree set`・`orca worktree create` を 1 つも呼ばず、stdout には何も出さず、stderr に `could not read the parent worktree` を出して exit 1 で終わらなければならない（MUST。先へ進むと、子のワークツリーの `linkedIssue` をエピック番号で書き換えてから止まるため）。親ワークツリーを持たないワークツリーでは、呼び出しの順序を変えてはならない（MUST NOT）。

**develop の子向け入口 `references/epic.md` と親向け `references/epic-loop.md`** は読み手を分けて次を規定しなければならない（MUST）。`orca` のコマンドは書かない（MUST NOT。要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」）。

- `launch` が `--note` を子 issue に `親エピックからの注意書き:` で始まるコメントとして残すこと。子のセッションの本体（起動し直したセッションを含む）は、記録先にこの行で始まるコメントがあれば、投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のどれかであるものにすべて従い、W・R1・G に渡す関連コメントに必ず含めること。それ以外の投稿者のものと `author_association` を読めなかったものには従わず、W・R1・G にも渡さず、コメントの URL と投稿者をユーザーに報告すること（issue には誰でもコメントでき、子のセッションは確認画面なしで動くため）。この投稿者の検査は注意書きのコメントだけに適用し、記録先のほかのコメントの読み方は変えない
- `launch` の stderr に `note not posted to #<N>` があれば、本体がその子 issue に stderr に出た本文を投稿すること
- 子であることは、`launch` が端末に付けた環境変数と、子のワークツリーの親子関係のどちらからでも判定されるので、起動し直したセッションでも `route` が `nested` を返すこと
- `nested` を受けたセッションは、親エピックの番号を `route` の stderr の `parent epic: #<N>` から読むこと
- `launch` の拒否は stderr の `child epics are not expanded here` で見分け、`nested` と同じに扱うこと
- `route` の stderr に `parent epic:` があり、そのセッションに `EPIC_DISPATCH_PARENT_EPIC` が無いとき（ワークツリーの親子関係で `nested` になったとき）は、同じワークツリーで起動し直しても `nested` になるので、ユーザーには、親を持たないワークツリー（Orca の子として作られていないワークツリー）で `/develop #<自分の issue>` を起動するよう伝えること。「親ワークツリーで開き直す」とは報告しない既存の規定は変えない

この要件の守備範囲で入力として扱うのは、`launch` に渡された `--note` の文、`orca worktree current --json` の `.result.worktree.parentWorktreeId`、`orca worktree list --json` の `.result.worktrees[]` の `id` と `linkedIssue` である。2 つの JSON は 2026-10-08 の実機（Orca 1.4.222）で確かめた形のとおりと信じ、形が変わったときの検知は範囲外とする。拾いたい誤りは、起動し直した子のセッションが注意書きを知らずに範囲外に手を出すこと、自分を子だと知らずに孫のワークツリーやサブエージェントを作ることである。次は通してよく、この要件では止めない: `launch` 以外で、`linkedIssue` の付いたワークツリーを親にして作ったワークツリーで回すエピックは `nested` になる／一覧の一時的な失敗と `route` の 1 回が重なると子のセッションが `nested` にならない（そのとき `launch` は一覧を読めずに子を作らない）／この変更の前に `launch` された子の issue には注意書きのコメントが無い／注意書きの本文の長さや内容は検査しない／親ワークツリーが一覧から消えていれば子ではない扱いになる／親ワークツリーの `linkedIssue` が後の `launch` で別のエピックに変わると、`parent epic:` はその番号になる／サブエージェント方式の隔離 worktree からの `route`・`launch` の呼び出しは想定しない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`gh issue comment` の呼び出しの回数と本文、親子関係による `nested` と `launch` の拒否、上の `references/epic.md` の記述を確かめなければならない（MUST）。

注意書きに従う投稿者の検査と nested の子側の処理は epic.md、親の投稿失敗への対処は epic-loop.md に置く（MUST）。子が注意書きを受けるだけで親の起動手順まで読むようにしてはならない（MUST NOT）。

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

#### Scenario: epic.md に注意書きのコメントと起動し直したセッションの扱いが書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** `親エピックからの注意書き:` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のものに従い W・R1・G に渡すこと、それ以外の投稿者のものには従わず渡さずユーザーに報告すること、起動し直したセッションでも `nested` になること、親エピックの番号を `parent epic: #` から読むこと、`child epics are not expanded here` で `launch` の拒否を見分けること、変数が無く `parent epic:` が出たときは親を持たないワークツリーで起動するよう伝えることが書かれていて、`grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` は 0 行

#### Scenario: 親が注意書きの投稿失敗に対処する
- **WHEN** `references/epic-loop.md`「通常進行の手順」手順１を読む
- **THEN** `note not posted to` のときに本体が注意書きを子 issue に投稿すると書かれている

### Requirement: 親は枠が空いたら後回しの子を起動し、サブエージェント方式でも同じ上限を当てる
develop の手順書は、別セッション方式の通常進行を `references/epic-loop.md`、停止処理の手順 8 を `references/epic-stop.md`、サブエージェント方式を `references/epic-worker-slots.md` に分け、次を書かなければならない（MUST）。これは要件「エピックの条件・作り方・回し方・完了条件を規定する」の回し方を書き換えず、上限と後回しの子の扱いを足すものである（「解けた子を件数にかかわらず `launch` する」は、`launch` に渡す子の選び方として今までどおりで、件数を抑えるのは `launch` である）。

**Orca 経路**: `epic-loop.md` の手順 1 に、`launch` の出力に `deferred <N>`（上限に達したので起動しなかった子。後回しの子）があること、上限は `EPIC_DISPATCH_MAX_PARALLEL`（無ければ物理メモリから決める既定値）であることを書く。手順 2 に、後回しの子は `wait` の位置引数（動いている子）にも `--watch-done`（片付け待ちの子）にも入れないことを書く。`epic-loop.md` の手順 3（`done` を処理したあと）と `epic-stop.md` の手順 8（`stopped` を処理したあと）に、後回しの子が残っていれば、2 に戻る前に依存の解けた開いた子を `launch` に渡し直す（起動済みの子は `skipped`、枠がまだ無ければまた `deferred`）ことを書く。手順 4 の依存グラフを読み直して解けた子を `launch` する処理が後回しの子も含むことを書く。`completed` 以外で閉じたときも枠は空くので、見送りの子を前提にしていた子を除いて、後回しの子が残っていれば 2 に戻る前に依存の解けた開いた子を `launch` に渡し直すことを書く。後回しの子を `launch` に渡し直すときは、最初に渡したときと同じ `--note` を付けること（後回しの子には注意書きが投稿されていない）を書く。`launch` のあと動いている子も片付け待ちの子も 0 件なのに後回しの子が残るときは、`wait` を呼ばずに主に報告し、報告に `launch` の stderr の枠を使っている子の行を添えることを書く。後回しの子の一覧はどこにも保存せず、起動し直した親（手順 7）は依存の解けた開いた子を `launch` に渡した出力で後回しの子を知ることを書く。

**サブエージェント方式**: `epic-worker-slots.md` に、開始時に `scripts/epic-dispatch.sh max-parallel` を 1 回呼んでその値を上限にし（exit 1 なら stderr を添えて設定の誤りとして報告して止まる）、エピックの全部の子をまたいで、枠を使っている W の総数をその上限までに抑えることを書く（MUST）。W 1 体（名前付きで起こし SendMessage で再開する 1 系列）は、起こしてから、その W が担う change のループが終わる（PR がマージされる・記録先が閉じる）か、主の返事待ちで保留に入るまで、1 枠を使う。主の返事待ちは本体が `needs-approval` を付けて待つ場面（W の停止・G の保留のどちらも）とし、そこで枠を返す。コンテキスト上限で手渡した後任の W は前任の枠を引き継ぐ。1 つの子の中で change ごとに W を並列に起こすときは、その W ごとに 1 枠を使う。本体は、新しい子の最初の W を起こす前・同じ子の中で別の change の W を起こす前・保留から戻る W を再開する前に、そのつど空き枠（上限から枠を使っている W の数を引き、0 未満なら 0）を確かめ、空き枠が 0 なら起こさず再開もせずに待ちに回すことを書く（MUST）。枠が空いたら、待ちに回したもののうち、保留から戻る W の再開を先に、そのあと同じ子の中の別の change の W、そのあと依存の解けた新しい子の最初の W の順で起こすことを書く（SHALL。主の返事を受けた件と始まっている子を先に進めるため）。

**Orca 経路と両経路に共通の数え方**（Orca 側は `epic-loop.md`、サブエージェント側は `epic-worker-slots.md` に置く）: 「枠を使っている子」に、完了の印の子・閉じた子・主の返事待ちで止まった子を数えないこと、その理由（止まった子はアイドルで、数えると主の返事が遅れるあいだ全体が止まる）を書く。Orca 経路では止まった子が戻るのは子のセッションの中なので親が止められず、戻った子の分だけ一時的に上限を超えうることを書く。サブエージェント方式では再開を本体が行うので、上の手順で再開前に空きを確かめ、上限を超えないことを書く。

`plugins/dev-workflow/tests/epic-dispatch.bats`（または `tests/develop-skill.bats`）は、`references/epic-loop.md` の通常進行、`references/epic-stop.md` の手順 8、`references/epic-worker-slots.md` の枠・手渡し・再開優先順の記述と、各場面に入る前の読込指示があることを確かめなければならない（MUST）。

この要件の入力は `references/epic-loop.md`・`references/epic-stop.md`・`references/epic-worker-slots.md` の各担当部分の本文と読込指示である。拾いたい誤りは、親が `deferred` の子を動いている子として `wait` に渡して親が気づかないまま待ち続けること、枠が空いても後回しの子を起動しないこと、サブエージェント方式で上限を超えて W を起こすことである。次は通してよく、この要件では止めない: `timeout` で起こされたときに後回しの子を `launch` に渡し直さないこと（枠は変わっていない）／サブエージェント方式で R1・G・決める役など W 以外の役割を枠に数えないこと（上限が抑えるのは W の数）／W が R1 や G の結果を待って動いていないあいだも 1 枠を使い続けること。手順書の読み方の揺れ（すり抜ける入力）が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

別セッション方式の後回しの子の通常進行は epic-loop.md、手順 8 の停止処理後の起動し直しは epic-stop.md、サブエージェント方式の枠・手渡し・再開の優先順は epic-worker-slots.md に置く（MUST）。

#### Scenario: Orca 経路の手順に後回しの子の扱いが書かれている
- **WHEN** `references/epic-loop.md` の Orca 経路の手順 1〜4 と `references/epic-stop.md` の手順 8 を読む
- **THEN** `deferred <N>` の意味、後回しの子を `wait` に渡さないこと、手順 3 と手順 8 のあとで後回しの子があれば `launch` に渡し直すこと、手順 4 の `launch` が後回しの子を含むことが書かれている

#### Scenario: 後回しの子だけが残ったら主に報告する
- **WHEN** `references/epic-loop.md` の Orca 経路の手順を読む
- **THEN** 動いている子も片付け待ちの子も 0 件で後回しの子が残るとき、`wait` を呼ばずに `launch` の stderr を添えて主に報告することが書かれている

#### Scenario: サブエージェント方式に同じ上限が書かれている
- **WHEN** `references/epic-worker-slots.md` のサブエージェント方式の段落を読む
- **THEN** `epic-dispatch.sh max-parallel` の値を上限に、子をまたいだ W の総数を抑えること、W 1 体が枠を使う期間、新しい子の W・同じ子の別の change の W・保留から戻る W のどれも起こす前に空き枠を確かめること、待ちに回したものを起こす順（再開 → 同じ子の別の change → 新しい子）が書かれている

#### Scenario: 保留から戻る W は枠が空くまで再開しない
- **WHEN** 上限 2 のサブエージェント方式で、子 A と子 B の W を起こし、A が主の返事待ちで保留に入ったので子 C の W を起こしたあと、主が A に返事をした（B・C の W はまだ動いている）場面を、`references/epic-worker-slots.md` の手順に当てはめる
- **THEN** 手順からは、A の W を再開せずに待ちに回し、B か C の W が枠を返したら（ループが終わるか保留に入ったら）A を新しい子より先に再開する、と読める。同時に枠を使う W は 2 体を超えない

#### Scenario: 子の中で change ごとに W を起こすときも枠を使う
- **WHEN** 上限 2 のサブエージェント方式で、子 A の W と子 B の W が動いているあいだに、子 A が 2 つの change に割れて 2 つめの change の W を起こそうとする場面を、`references/epic-worker-slots.md` の手順に当てはめる
- **THEN** 手順からは、空き枠が 0 なので 2 つめの change の W を起こさずに待ちに回し、枠が空いたら新しい子より先に起こす、と読める

#### Scenario: Orca 経路で戻った子の扱いが書かれている
- **WHEN** `references/epic-loop.md` の Orca 経路と `references/epic-worker-slots.md` のサブエージェント方式の枠の数え方を読む
- **THEN** Orca 経路では戻った子の分だけ一時的に上限を超えうること、サブエージェント方式では再開前に空きを確かめるので超えないことが書かれている

#### Scenario: 枠を使っている子の数え方が書かれている
- **WHEN** `references/epic-loop.md` の「通常進行の手順」を読む
- **THEN** 完了の印の子・閉じた子・主の返事待ちで止まった子を数えないことと、戻った子の分だけ一時的に上限を超えうることが書かれている

### Requirement: エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う
develop の `references/epic-loop.md` の「通常進行の手順」の別セッション方式（Orca・tmux。以下 Orca 経路）は、親が主に出す発言について、次を規定しなければならない（MUST）。対象は、Orca 経路で親がターンを終えるときに主に出す発言すべてで、次を含む。手順 2 で `wait` を背景で起動して待ちに入るときの通知、手順 3・4・8 を処理して手順 2 に戻るたびの発言、手順 4 の見送りの報告、手順 6 の `error`・`failed` の報告、手順 7 と完了条件で待ちを終えるときの報告、**マージ待ちの子** の `reply` の `failed` の報告、手順 8 の止まった子の報告。手順 5 の `timeout` で起こされたときは主に発言を書かない（要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」）。書くなら `主がすること: なし` の 1 行だけで、この書き分けに従う。主への問いが未回答のあいだは、その 1 行も書かない。

- 1 行目と 2 行目は、`~/.claude/output-styles/readable.md` の節 3 が定める書き分けに従う（MUST）。判断・確認・操作を求める発言は 1 行目を題名（依頼の形。質問にしない）にし、2 行目を `アクション:` で始まるアクションの行にする。主の操作も判断も要らない報告は 1 行目を `主がすること: なし` にする（主の質問への答えは正本のとおり 1 行目に答えを書く）（手順 2 で待ちに入るときは普通こちら）。`references/epic-loop.md` は書き分けを写さず、正本を参照する（MUST）
- 同じターンで主に問いを出したあとに手順 2 で待ちに入るときは、待ちに入る通知を `主がすること: なし` で始めない（MUST）。通知の 1 行目に問いの題名を、2 行目にアクションの行を繰り返す（直前の問いを `なし` で上書きしない）
- 規定は Orca 経路の導入部に 1 か所で書き、各手順は参照する（MUST。手順ごとに書式を複写しない）
- 子の記録の推奨を主に OK してもらう報告（手順 8 で、止まった子の停止の記録の URL を添えて主の答えを求めるもの。正本の型で書き、1 行目は中身で書いた題名にし、論点の項目に論点の有無を書く）のアクションの行には、打つ場所が親のタブであることと、報告の直後に別の発言を挟まないことを書く（MUST）
- 手順 8 の中でも返事の場所が親のタブでない発言は、アクションの行にその場所を書く（MUST）。`owner-reply-check.sh --locate` で主の発言を引けなかったときの「子のタブで『許容する』と打ってほしい」の連絡は、アクションの行に子のタブを出す。`reply` の出力が `failed <N> <段>` のときの報告は、主の操作が要れば依頼の形（題名とアクションの行）にし、要らなければ 1 行目を `主がすること: なし` にする
- 子の完了報告の 1 行目（`主がこのセッションで次にすること:`）は変えない（MUST。要件「エピックの子の完了報告は、主がこのセッションで次にすることを 1 行目に書く」に従う）
- `主がすること: <どこで> <何を>` の形を使わない（MUST NOT）

この要件の守備範囲で入力として扱うのは、`references/epic-loop.md` の Orca 経路の文面である。拾いたい誤りは 2 つある。主が親の発言から、答えが要るかどうかと、どこで何を打つかを読み取れないこと。子の記録の推奨を主に OK してもらう報告で、返事の場所と条件が発言から読めないこと。次は通ってよく、この要件では止めない: 2 行目以降の説明の文の良し悪し／アクションの中身の正しさ。穴が見つかるたびに決まりを足して塞ぎ切ることは、この要件の完了条件としない。

手順書では epic-loop.md の「主への報告」に共通の宣言を一度だけ置き、他の親向け文書はそこを読むよう指示する（MUST）。各手順末に同じ宣言を繰り返すことは要求しない。場面固有の例外・問いをなしで上書きしない条件は維持する（MUST）。

#### Scenario: Orca 経路が正本の書き分けを参照する
- **WHEN** `references/epic-loop.md` の「主への報告」を読む
- **THEN** 親が主に出す発言の 1 行目と 2 行目を `~/.claude/output-styles/readable.md` の節 3 の書き分けに従わせると書かれ、`主がすること: なし` の場合が書かれ、`主がすること: <どの画面・入力欄で>` の形が無い

#### Scenario: 待ちに入る通知が直前の問いを上書きしない
- **WHEN** `references/epic-loop.md` の Orca 経路の導入部と手順 2 を読む
- **THEN** 同じターンで主に問いを出したときは、待ちに入る通知を `主がすること: なし` で始めず、問いの題名とアクションの行を繰り返すと書かれている

#### Scenario: 子の記録の推奨を主に OK してもらう報告の答え方に場所と条件が入る
- **WHEN** `references/epic-stop.md` の手順 8 を読む
- **THEN** 子の記録の推奨を主に OK してもらう報告のアクションの行に、親のタブで打つことと、報告の直後に別の発言を挟まないことを書くと書かれ、主の発言を引けなかったときの連絡のアクションの行には子のタブを出すと書かれている

### Requirement: 親は主の委任を、定型の委任の記録への主の直接の確認で受ける

`references/epic-stop.md` は、別セッション方式の親が、主が親のタブで子の止まりを任せる旨を述べたとき、その発言だけを委任として扱わず（MUST NOT）、エピックの issue に定型の委任の記録を投稿し、本文に記録の URL と範囲・期間の文を書いて主に問うことを書かなければならない（MUST）。記録の種類は `主の委任: リスク許容` と `主の委任: 論点なしの止まり` の 2 つで、主が任せた範囲がどちらか読めないときは狭い側の `主の委任: リスク許容` を投稿する（MUST）。問いの答え方の行には、親のタブで `任せる` と打つことを書く（MUST）。問いのあとの主の発言のうち、全文から任せる意思が読める最初の発言を委任の確認とする（MUST）。問いと確認のあいだに主の別の発言が挟まっただけでは問い直さない（MUST NOT）。挟まった発言が委任を取り消すか範囲を変える内容なら、委任を使わずに問いを本文で出し直す（MUST）。

委任の定型と有効性・種類別の適用条件の正本は `references/epic-delegation.md` とし、この親の操作手順から適用前に読む（MUST）。

#### Scenario: 委任の記録の書式

- **WHEN** 親が委任の記録を投稿する
- **THEN** 本文は次のどちらかの形で、`主の委任: リスク許容` は 1〜4 行目が、`主の委任: 論点なしの止まり` は 1〜5 行目が、この文字列ちょうど（`<E>` はエピックの番号）になる

  ```
  主の委任: リスク許容
  エピック: #<E>
  範囲: このエピックの子が pr-review-gate で求めるリスク許容のうち、子の停止の記録の推奨が「許容する」のもの。聖域の変更・破壊的な操作・マージの承認・不許容は含まない
  期間: この記録への主の確認の発言から、このエピックに `主の委任:` で始まる次のコメントが付くか、エピックが閉じるまで
  きっかけ: <主が任せる旨を述べた発言の全文。無ければ なし>
  ```

  ```
  主の委任: 論点なしの止まり
  エピック: #<E>
  範囲: このエピックの子の止まりのうち、子の停止の記録の `主に聞く理由:` が論点なしと書き、推奨と根拠があるリスク許容・聖域の変更・破壊的な git 操作と、同じ HEAD の論点なしの確認で通ったマージ待ち。論点ありの止まり・不許容・実機操作は含まない
  期間: この記録への主の確認の発言から、このエピックに `主の委任:` で始まる次のコメントが付くか、エピックが閉じるまで
  根拠: 主の決定（2026-11-01。線は論点の有無で引き、種類による例外は置かない） https://github.com/genetta-inc/flatmate/issues/1796#issuecomment-6551902839
  きっかけ: <主が任せる旨を述べた発言の全文。無ければ なし>
  ```

#### Scenario: 主の自由な委任の発言を受けたとき

- **WHEN** 主が親のタブで「このエピックの子の許容は全部答えて」と述べる
- **THEN** 親は委任の記録をエピックに投稿し、本文に記録の URL と範囲・期間の文と答え方の行を書いて問い、主の確認を受けるまで委任で返事を送らない

#### Scenario: 確認の前に別の発言が挟まったとき

- **WHEN** 親の問いのあとに主が別の件を話してから `任せる` と答え、挟まった発言は委任を取り消すことも範囲を変えることも述べていない
- **THEN** 親は問い直さず、`任せる` の発言を委任の確認として受ける（子の `--delegated` は挟まった主の発言で落とさない。dev-workflow-owner-reply-check の要件）

#### Scenario: 挟まった発言が範囲を変えるとき

- **WHEN** 親の問いのあとに主が「マージは除いて」と述べてから `任せる` と答える
- **THEN** 親は委任を使わず、範囲を直した記録を投稿して問いを本文で出し直す

#### Scenario: 確認から任せる意思が読めないとき

- **WHEN** 親の問いのあとの主の発言がどれも「ちょっと待って」のように任せる意思を読めない
- **THEN** 親は委任を使わず、問いを本文で出し直す

#### Scenario: 任せた範囲が読めないとき

- **WHEN** 主が「任せる」とだけ述べ、リスク許容だけか論点なしの止まり全体かが読めない
- **THEN** 親は `主の委任: リスク許容` の記録を投稿して問う

### Requirement: 親は委任の確認の場所をエピックに残す

`references/epic-stop.md` は、親が委任の確認を受けたら、`owner-reply-check.sh --locate "$CLAUDE_CODE_SESSION_ID" <確認の全文>` で確認の uuid を引き、エピックに `委任の確認の場所: セッション <親のセッション ID> / uuid <uuid> / 記録 <委任の記録の URL>` の 1 行を投稿することを書かなければならない（MUST）。親は起動し直したあとも、最新の `主の委任:` で始まるコメントの URL を `記録` に持つ最新のこの行から値を取る（MUST）。引けないときは委任を使わない（MUST）。

委任の定型と有効性・種類別の適用条件の正本は `references/epic-delegation.md` とし、この親の操作手順から適用前に読む（MUST）。

#### Scenario: 起動し直した親が委任を使う

- **WHEN** 親のセッションが起動し直され、エピックに有効な委任の記録と、その URL を持つ `委任の確認の場所:` の行がある
- **THEN** 親はその行のセッション ID と uuid を添え書きに使う

### Requirement: 主の委任は取り消しと新しい記録とエピックの終わりで切れる

`references/epic-stop.md` は、主が委任の取り消しを述べたら、親がその発言を受けた次のターンの最初のツール呼び出しでエピックに 1 行目 `主の委任: 取り消し` のコメントを投稿し、以後は委任で返事を送らないことを書かなければならない（MUST）。取り消しは主本人の確認を求めず、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` のどれかなら効く（MUST。範囲を狭める向きにしか働かないため）。それ以外の投稿者の `主の委任:` で始まるコメントは数えない（MUST）。

委任の定型と有効性・種類別の適用条件の正本は `references/epic-delegation.md` とし、この親の操作手順から適用前に読む（MUST）。

#### Scenario: 取り消しのあとは委任で送らない

- **WHEN** エピックの、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` の `主の委任:` で始まる最新のコメントが `主の委任: 取り消し`
- **THEN** 親は止まった子を今どおり主に上げ、委任で返事を送らない

### Requirement: 親は有効な委任が効く止まりにだけ、委任で許容を送る

`references/epic-stop.md` の手順 8 は、`references/epic-delegation.md` を読んで、今回の停止の記録があり、委任が有効で止まりに委任が効くときだけ、主に上げずに `epic-dispatch.sh reply --as owner` で返事を送ることを書かなければならない（MUST）。返事は止まりの種類で分ける（MUST）。

- **リスク許容の止まり**: `許容する（主の委任による。停止の記録: <URL>） [主の委任: セッション <親のセッション ID> / uuid <確認の uuid> / 記録 <委任の記録の URL>]`
- **聖域の変更・破壊的な git 操作の止まり**: `進める（主の委任による。停止の記録: <URL>）: <変更するファイルかコマンドの全文>。実行の時機: <いつ> [主の委任: セッション <親のセッション ID> / uuid <確認の uuid> / 記録 <委任の記録の URL>]`（`rules/destructive-git-guard.md` の「タイミングと方法まで」を返事で満たす）

送れたらエピックに `委任で送った: 子 #<N> <停止の記録の URL> 委任の記録: <委任の記録の URL>` の 1 行を残す（MUST。`親の判断:` で始めない）。同じ子のこの行の停止の記録の URL が今回の停止の記録の URL と同じなら送り直さない（MUST）。

委任の定型と有効性・種類別の適用条件の正本は `references/epic-delegation.md` とし、この親の操作手順から適用前に読む（MUST）。

#### Scenario: 委任で送った件をエピックに残す

- **WHEN** 親が委任で `reply --as owner` を送り、出力が `sent` か `relaunched`
- **THEN** エピックに `委任で送った: 子 #<N> <停止の記録の URL> 委任の記録: <URL>` の 1 行を投稿する

#### Scenario: 委任があれば論点なしの聖域の変更を親が進める

- **WHEN** `主の委任: 論点なしの止まり` の有効な記録があり、委任の確認より後に子が聖域の変更の承認で止まり、停止の記録の `推奨:` が `進める` で始まり `主に聞く理由:` が論点なし
- **THEN** 親は主に上げずに、変更するファイルと実行の時機を書いた `進める（主の委任による。…）` の返事を `reply --as owner` で送る

#### Scenario: 同じ止まりに二度送らない

- **WHEN** 手順 7 か 8 で同じ子が再び挙がり、エピックにその子の `委任で送った:` の行があって停止の記録の URL が今回と同じ
- **THEN** 親は委任で送り直さず、子の再開を待つ

### Requirement: 親が長く待ったあとは親の表で続けるか起動し直すかを決める
`plugins/dev-workflow/skills/develop/references/reply-after-idle.md` は、親も子・単発と同じくアイドル時のコンパクトを切ること、親が最後のリクエストから 60 分以上待ったら compact の有無や会話量によらずエピックの記録から起動し直すこと、60 分未満なら続けることを規定しなければならない（MUST）。親だけの 120,000 の設定・compact 後なら続ける分岐・監視が続くから残す説明は現行の規則に残さない（MUST NOT）。

時間分類は timeout・子の通知・主の返事を処理する前に適用する（MUST）。最後のリクエストは起床の API リクエストを除いた待機前のものを使い、キャッシュを書いた行の時刻と混同しない。60 分以上なら旧親は未処理イベントをエピックに記録し、同じ worktree の新セッションで `/develop <エピック番号>` から手順書と記録を読み直して再開するよう主に案内して終える（MUST）。再開手順は要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」に定め、親の表と epic-loop.md の手順 5 のどちらから読んでも時間分類が優先すると分かるようにする（MUST）。

親の時間分類の操作規則は reply-after-idle.md に一度だけ置き、epic-loop.md の起床時・手順 5・9 はそこを先に読む案内にする（MUST）。

#### Scenario: 規則のファイルに親の値と表と復元元が書かれている
- **WHEN** 規則のファイルを読む
- **THEN** 親にも idleCompaction false を適用し、60 分未満は続け、60 分以上は起動し直すと分かり、compact や N による継続の例外・親だけの閾値が無い
- **AND** 回し方、終わった子、外した子エピック、残した worktree、親が通した判断、主の返事待ち、残りの子の復元元が記録されている

親の状態はエピックと子 issue のコメント・依存グラフ・子の状態記録から復元できると書く（SHALL）。`回し方:`、`子 #N マージ → 残り k 件` / `子 #N 見送り`、`後で別に起動するエピック:`、`子 #N のワークツリーを残した`、`親の判断: 子 #N 通した` と停止記録 URL の対応、`pending-owner` の確認を残す。比較する相手は手順書と引き継ぎを読む新セッションであり、要約と手順書再読み込みを二重に払う親の方針を #1385 で覆したと書く（SHALL）。監視停止が compact のせいだったとは断定しない。古い集計のリンクは履歴として残せるが、親の idle 閾値の再集計を現行の宿題にしない。

この規則の入力は、親のトランスクリプトの最後のリクエスト時刻と、エピックの復元記録である。拾う誤りは、compact 済み・会話量が小さいことを理由に 60 分以上止まった親を続けること。境界の時刻が曖昧で 60 分前後の扱いが揺れる場合は続けてよく、時刻不明から長時間経過を捏造しない。復元元の記録自体の誤りや欠落はこの時間分類だけでは防がない。穴の追加封鎖を完了条件にしない。

#### Scenario: 親が compact 済みでも長く待ったら起動し直す
- **WHEN** 親の最後のリクエストから 60 分以上たち、compact_boundary がある場合と無い場合を比較する
- **THEN** どちらも会話量によらず起動し直し、エピックのコメントから親が通した判断を含め復元する

#### Scenario: 短時間の親は続ける
- **WHEN** 親の最後のリクエストから 60 分未満である
- **THEN** 親はそのまま続け、この規則を理由に短い wait のやり直しを止めない
