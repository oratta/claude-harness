## MODIFIED Requirements

### Requirement: 本体はオーケストレータ専任でコードもレビューも書かない
SKILL.md は本体（メインセッション）の役割を「役割 W / R1 / G を model 明示で spawn し、return の要約と記録先（issue または Draft PR）のコメント・ラベルだけを見て次に誰を起こすかを決める」と規定しなければならない（MUST）。禁止事項として、本体が Edit でコードを書かないこと、本体がレビュー（仕様レビュー・PR レビュー）を代行しないことを明記しなければならない（MUST）。並列可能な役割は並列に起こしてよい（MAY）。ただし、1 つの作業ディレクトリ（worktree）で同時に動く同一役割のサブエージェントは常に 1 人でなければならない（MUST）。並列に起こしてよいのは、別々の worktree を持つ役割（エピックの子どうし、独立した change の W どうし）に限る（SHALL）。複数 change に割れた場合の change ごとの W 並列も、change ごとに worktree を分けて起こすものとする（MUST）。

名前付き profile を使わない Claude 経路では、W は名前付きで spawn する（SHALL）。名前付き profile を使う場合は profile role ごとに thread と起動時の要求 tuple / 適用 model を記録する。canonical develop が同じ Claude role を再開する前には毎回、現在有効な残量モードの上限を確認し、既存 thread の適用 model が上限内である場合に限って SendMessage で再開しなければならない（MUST）。適用 model が現在の上限を超える場合は SendMessage で再開せず、既存の工程完了または停止確認の条件を満たしてから、要求 tuple を変更せず、上限内の適用 model で同じ role の fresh thread へ手渡しし、要求値・適用値・変更理由を記録しなければならない（MUST）。profile role が変わる場合、または executor=codex の場合も fresh thread に成果物と必要な要約を渡す（SHALL）。どの経路でも、別コンテキストを要する工程はすべて本体が起こし、W が孫を呼ぶ必要がある工程を設けてはならない（MUST NOT）。

#### Scenario: 禁止事項が明記されている
- **WHEN** SKILL.md の「本体の役割」節を読む
- **THEN** 本体が Edit でコードを書かないこと、レビューを代行しないこと、役割を model 明示で spawn することが書かれている

#### Scenario: W の再開は profile role と executor に従う
- **WHEN** SKILL.md の 1 ループと profile 経路の記述を読む
- **THEN** profile 無しと同じ profile role の Claude W は再開前に現在の上限を確認し、適用 model が上限内のときだけ名前付き thread を SendMessage で再開すること、上限超過・profile role の変更・Codex W の場合は fresh thread に成果物と必要な要約を渡すこと、W が孫を呼ぶ工程が無いことが書かれている

#### Scenario: 再開前に exhausted へ変わった
- **GIVEN** requested model=`fable`、applied model=`fable` で起動した同じ Claude role の名前付き thread がある
- **WHEN** 再開前に `FABLE_BUDGET_MODE=exhausted` へ変わり、共有枠は depleted でない
- **THEN** SendMessage で再開せず、工程完了または停止確認後に requested model=`fable` を保持した fresh thread へ applied model=`opus` で手渡しし、変更理由=`FABLE_BUDGET_MODE=exhausted` を記録する

#### Scenario: 再開前に depleted へ変わった
- **GIVEN** requested model=`fable`、applied model=`fable` で起動した同じ Claude role の名前付き thread がある
- **WHEN** 再開前に `SHARED_BUDGET_MODE=depleted` へ変わる
- **THEN** SendMessage で再開せず、工程完了または停止確認後に requested model=`fable` を保持した fresh thread へ applied model=`sonnet` で手渡しし、変更理由=`SHARED_BUDGET_MODE=depleted` を記録する

#### Scenario: 同一 worktree に同一役割を二重に spawn しない
- **WHEN** ある worktree で W が稼働中である（手渡し待ち・停止指示待ちを含む）
- **THEN** 本体はその worktree に対して別の W をもう 1 人 spawn しない（手渡し・再開のいずれであっても。いつ手渡してよいかは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本）

#### Scenario: 別 worktree の並列はこの制約の対象外
- **GIVEN** エピックの子どうし、または独立した change の W どうしが、それぞれ別の worktree で動いている
- **THEN** 本体はこれらを並列に起こしてよく、同一 worktree 制約には抵触しない

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとのモデルを次のとおり規定しなければならない（MUST）: W は既定 `sonnet`、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか、実行側が原因の失敗ループでの昇格か、事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たれば `opus`。**W を `fable` で spawn してはならない**（MUST NOT。実行役の上限は `opus` で、強制層は `scripts/agent-model-guard.sh`）。R1 は既定 `opus`、仕様がマージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する（聖域パスだけでは上げない）。G は既定 `sonnet` で上げない（G の仕事は照合・ラベル操作で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う）。G が要求するレビュアーは既定 `opus`、対象がマージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。従来経路では G の `needs-reviewer` が示す推奨 model に従い、adapter 経路では phase `review` の adapter が返した model に残量上限を適用した値を使い、G の推奨 model は参考値として扱わなければならない（MUST）。役割のモデルは残量モード（`FABLE_BUDGET_MODE`）と共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）の上限に従わなければならない（MUST）。2 つのモードの値ごとの効果は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の残量モードと共有枠モードの表 1 か所で定める（その表では、`abundant` はどの役割の既定も上げず、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定で、Fable 残量モードと食い違えば共有枠モードが勝つ。これは SKILL.md が書く中身ではない）。SKILL.md の「モデル」節は 2 つのモードの名前（`FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE`）と、効果がその表にあることだけを書かなければならない（MUST。値ごとの効果を再掲してはならない。同じ規則を 2 か所に書くと、直すときに片方が漏れて食い違うため）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）は、失敗の原因が判断側か実行側かで決める役と実行役のどちらか一方だけを上げるラダー（正本は `templates/escalation-tripwires.md`）として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測らなければならない（MUST）。上限超過（exit 2）を検知したあとの扱い（送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目にどちらの宣言を置くか・前任が動作中のまま交代させるときの手順）について、SKILL.md は本文を書かず、`plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」への参照だけを置かなければならない（MUST。正本の位置・参照だけにする面の一覧・テストの形は `dev-workflow-execution-strategy` が規定する）。

この要件の守備範囲で入力として扱うのは、G の起動・再開指示にある `レビュー経路:`、G の `needs-reviewer` が示す推奨 model、phase `review` の adapter が返す model、および `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` から決まる残量上限である。防ぐ誤りは、経路ごとの決定元を取り違えること、adapter が選んだ model を G の推奨 model で上書きすること、残量上限を適用せずに model を採用することである。一方、adapter が `sonnet` を返して G が `opus` を推奨していても、残量上限を適用した adapter の値を採用することは許容する。任意の不正な経路・model・残量モード入力を検出して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が `sonnet` で上限が `opus`、R1 の既定が `opus`、G の既定が `sonnet`、事前分類（聖域パス・マージ権限・層間契約・課金/法務）で W は `opus` 止まり、R1 とレビュアーの fable は `dev-workflow:decider` 経由と書かれている
- **AND** `FABLE_BUDGET_MODE` と `SHARED_BUDGET_MODE` の効果は `references/decision-criteria.md` の表を見るよう書かれており、`abundant`・`reserve`・`exhausted`・`throttled`・`depleted` の値ごとの効果を述べた文は無い

#### Scenario: レビュアーの model 決定元を経路で分ける
- **WHEN** SKILL.md の「G が要求するレビュアー」の行を読む
- **THEN** 従来経路では G の推奨 model に従い、adapter 経路では adapter が返した model に残量上限を適用した値を使って推奨 model は参考値とする、と書かれている

#### Scenario: 失敗ループでは片方だけ上げる
- **WHEN** SKILL.md の失敗ループの記述を読む
- **THEN** 決める役と実行役のどちらを上げるかを失敗の原因分類で決め、両方同時に上げないこと、実行役の上限が `opus` であることが書かれている

#### Scenario: 再開前にコンテキスト量を測る
- **WHEN** SKILL.md の「1 ループ」節を読む
- **THEN** W / G を SendMessage で再開する前に `subagent-context.sh` で測ること、G の再開も同じであること、上限超過のあとの扱いは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本であることが参照として書かれている
- **AND** そこに手渡しの条件・宣言の選び方・停止確認の手順を言い換えた文は無い

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
`skills/develop/references/epic.md` は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。

**回し方（経路の決め方）**: interactive の本体は子の依存グラフを読み、blocked されていない子の番号を `plugins/dev-workflow/scripts/epic-dispatch.sh route` に渡して経路を決める（MUST）。`route` が `orca` か `tmux` を返したとき（Orca 管理のワークツリーにいる、または tmux の中にいる）は、その起動部品で子を別のセッションとして起こす **別セッション方式**、`subagent` を返したときは **サブエージェント方式**で進める（MUST）。別セッション方式とサブエージェント方式は二本立てではなく、子を起こす手段を起動部品として差し替える一本の手順で書く（MUST。共通の手順に、部品ごとに違う点だけを部品ごとの欄に書く）。経路は `/develop <エピック番号>` の最初の開始時に 1 回決め、途中で変えてはならず（MUST NOT）、決めた経路をエピックに `回し方:` で始まる 1 行コメントで残す（MUST）。別セッションで同じエピックを再開したときは、`回し方:` で始まる最新のコメントを読んで経路を引き継ぎ、`route` をやり直してはならない（MUST NOT）。最新の `回し方:` が `Orca` か `tmux` のときは、本体が `epic-dispatch.sh launch` と `adopt` に環境変数 `EPIC_DISPATCH_LAUNCHER=<そのコメントの部品名（小文字の orca か tmux）>` を付けて呼ばなければならない（MUST。付けないと部品を今の環境から選び直し、前のセッションの記録の子と別の部品で新しい子が起動しうる）。その部品が今の環境で使えず `launch`・`adopt` が exit 1 で終わったら、別の部品にもサブエージェント方式にも振り替えず、stderr を添えて主に報告して止まる（MUST。部品の違う子の混在を作らない）。`reply`・`notify-closed`・`reap`・`wait --resolve` は記録の `launcher` で部品が決まるので、再開で環境が変わっても部品名を渡さない。unmanned（`--unmanned`）では `route` を呼ばず、サブエージェント方式で進める（MUST。背景で待って起こされる動きが 1 サイクル 1 仕事と合わないため）。channel でも `route` を呼ばず、サブエージェント方式で進め、エピックに `回し方: サブエージェント（channel モード）` を残す（MUST）。channel で再開したエピックの最新の `回し方:` が別セッション方式（Orca・tmux）なら、`launch` もサブエージェント方式も使わず、その旨をチャンネルで主に報告して止まる（MUST。channel は別セッション方式を引き継がない）。channel の本体は、develop の手順のために別の Claude Code セッション（Orca・tmux など）を起こしてはならない（MUST NOT。別に起こしたセッションには印 `DEV_WORKFLOW_UNATTENDED` が届かず、その画面を誰も見ていないので、子が主の返事待ちで止まっても誰も気づかない）。develop の外で住人が別のセッションを起こすときの印の渡し方は、この要件の範囲に入れない（#1123）。

**回し方（別セッション方式）**: 本体は `epic-dispatch.sh launch` で子ごとに起動部品（Orca か tmux）の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。再開時も、依存が解けた open の子を、最新の `回し方:` の部品名を付けた `launch` に渡し（上の段落のとおり）、起動済みの子は `launch` の `skipped` で見分ける（同じ子を二重に起動しない）。本体は `launch` が `launched` / `skipped` を出した子を動いている子とし、`epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める。`closed` なら閉じた子ごとに `state_reason` を読み、`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントして依存グラフを読み直し、解けた子を件数にかかわらず `launch` する。`completed` 以外ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子を起動してはならず（MUST NOT）、ユーザーに報告する。そのあと残りの動いている子で再び `wait` する。`timeout` なら、子 issue もエピックも読まず、主に報告もせず、直前と同じ引数の `wait` を 1 回掛け直してターンを終える（要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」）。子が記録と印を残さずに自分のタブでユーザーに質問して止まっている場合は、親が気づけないことを書く（SHALL）。`wait` の `error` と `launch` の `failed` はユーザーに報告して止まる。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子セッションのモデルは `epic-dispatch.sh launch` が起動時に起動コマンド（既定は `plugins/dev-workflow/bin/cld`）に `--model` を付けて指定し、既定は `opus` で環境変数 `EPIC_DISPATCH_MODEL` で変えられること（Claude Code の既定モデルは子に効かないこと）、コマンド部分（既定は `bin/cld` の絶対パス。ログイン zsh のシェル関数には頼らない）は環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ、Orca に設定したコマンドはハーネスから読めないので（tmux の部品はこの環境変数のコマンドをそのまま打ち込む）Orca 側のコマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変えることを書く（SHALL）。子セッションの `--dangerously-skip-permissions` は環境変数 `CLD_DEFAULT_ARGS` に入れた値で付き、`launch` と、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）が親の環境の `CLD_DEFAULT_ARGS` を子の起動コマンドの前に代入として付けて子へ渡すこと（親の環境に値が無ければ付けず、子は許可の確認画面で止まる。許可を飛ばしたければ親の環境に `CLD_DEFAULT_ARGS` を置くことが前提であること）、`epic-dispatch.sh` 自身が足すのは `--settings` と `--model` だけであること、マージを止めているのは develop と pr-review-gate の規則と hooks であることを書く（SHALL）。本体は子の PR を `gh pr merge` や merge API で直接マージしてはならない（MUST NOT）。子の PR のマージは、子セッションの中の人の承認か自動マージの処理（`.github/workflows/auto-merge.yml`）が行い、`human-merge` の付いた子の PR は、本体が要件「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」の手順で判断の印を付けたときに限って自動マージの処理がマージすることを書く（SHALL）。

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

#### Scenario: epic.md の回し方が起動部品の差し替えとして書かれている
- **WHEN** develop の `references/epic.md`「エピックの扱い」→「回し方」を読む
- **THEN** 起動・待ち・閉じた子・止まった子・片付け・完了の手順は 1 本で書かれ、Orca の部品・tmux の部品・サブエージェント方式のどれで起こすかによって違う点だけが部品ごとの欄に書かれており、「Orca 経路」と「サブエージェント方式」を別々の手順として二重に書いていない。サブエージェント方式は状態の記録を書かない、と書かれている

### Requirement: 前提環境を明記する
SKILL.md は「前提」節として、Agent ツール（`model` 明示・名前付き spawn・`isolation: "worktree"`・W は `subagent_type: dev-workflow:worker`、G は `subagent_type: dev-workflow:gate-runner`）と SendMessage、`gh`（issue / PR コメントとラベル、issue dependencies API）、openspec CLI（W は CLI だけで仕様化経路を進め、経路の有無は `openspec --version` で決める。opsx コマンドは本体や主が対話で使う道具で、W の経路の有無を決めない。CLI が無ければ仕様化経路が発生しない）、Codex CLI（無ければ G が `needs-reviewer` に縮退）、`orca` コマンド（エピックの子を Orca の子ワークツリーで独立セッションとして起動する。無いとき、または本体が Orca 管理外のワークツリーにいるときは、エピックをサブエージェント方式で回す）を列挙しなければならない（MUST）。

#### Scenario: 前提節がある
- **WHEN** SKILL.md の「前提」節を読む
- **THEN** Agent / SendMessage / gh / openspec CLI / Codex CLI / orca とそれぞれ無いときの縮退が書かれ、Agent の行に W と G の種別が書かれ、openspec の行に W の経路の有無を `openspec --version` で決めることが書かれ、orca の行には Orca 管理外のワークツリーにいるときもサブエージェント方式になることが書かれている

### Requirement: 手渡し先は未コミット差分を先に確認する

手渡しで起こされた W / G の指示書は、前任が途中停止で return した可能性があるため、再出発の前に作業ツリーの未コミット差分（`git status` / `git diff`）を確認しなければならない（MUST）と書かなければならない。これは `references/roles/worker/common.md` の手渡しの節に置く役割固有の動作であり、閾値や振る舞いの再掲ではない。

#### Scenario: 手渡し先が未コミット差分を先に見る

- **WHEN** `references/roles/worker/common.md` の手渡しの節を読む
- **THEN** 前任が途中停止した可能性があるので `git status` / `git diff` で未コミット差分を先に確認する、と書かれている

### Requirement: 強制停止で止まった作業ツリーは本体が引き取る

強制停止中は `Bash` がコマンド内容によらず全件拒否されるため、止まったサブエージェント自身は commit できない（`dev-workflow-execution-strategy`「強制停止の閾値を超えたら PreToolUse が編集を拒否する」）。手渡し先（`worker/common.md` の手渡しの節）が拾うのは**次に起こされた**サブエージェントの `git status` / `git diff` だけなので、①手渡しが発生しない経路（そのサイクルを終える・別の子 issue に移る・工程が G で終わる）、②後継が G の場合（`gate-runner.md` には同じ規則が無い）は未コミット差分の確認が誰にも渡らない。SKILL.md は、`工程中断:` の return を受け取ったとき、および次の手渡し・次の spawn・そのサイクルの終了・worktree の撤去のいずれよりも先に、**本体**が return に書かれた作業ツリーのパス（強制停止による中断なら hook の `permissionDecisionReason` に含まれる `cwd`。それ以外の `工程中断:` なら return に書かれたパス）に対して `git -C <path> status --porcelain` を実行して未コミット差分を確認し、残っていれば本体が commit しなければならない（MUST）ことを明記しなければならない（MUST）。

#### Scenario: 本体が未コミット差分を引き取る

- **WHEN** SKILL.md の本体の手順を読む
- **THEN** `工程中断:` を受け取ったとき、および次の手渡し・次の spawn・サイクルの終了・worktree の撤去のいずれよりも先に、本体が return に書かれた作業ツリーのパスに対して `git -C <path> status --porcelain` で未コミット差分を確認し、残っていれば本体が commit すると書かれている

### Requirement: 周回は前の段から引き継ぐ

G は `周回:` を前の段の Gate Result の値から引き継がなければならない（MUST）。W の修正後の再レビューで起こされた前提確認と重さ判定の G だけが 1 増やす（MUST）。戻した指摘が順 3 だけの修正のあとは周を消費しない（`stages/triage.md` の既存規則のまま）。

#### Scenario: 再レビューの周

- **WHEN** 周回 1 で failed が返り、W の修正後に前提確認と重さ判定の G を起こす
- **THEN** その G の Gate Result は `周回: 2` を持つ

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

### Requirement: 段ごとの読み込み字数を分割前と並べて記録する

`plugins/dev-workflow/tests/develop-worker-stages.bats` は、`spec` / `implement` / `finish` のそれぞれについて `worker/common.md` とその段のファイルの字数（改行を含む Unicode の文字数。`python3` で数える）の合計を計算し、段の名前とともに bats の診断出力（ファイル記述子 3 に `# ` で始まる行）へ出さなければならない（MUST）。この検査は字数の上限で落ちてはならない（MUST NOT。数字は達成の可否ではなく、使うときの期待値として残す）。

この変更の PR 本文は、段ごとの字数を、分割前の worker.md 全体の字数（2850fe32 時点で 13,416 字）と並べて記録しなければならない（MUST。issue #556 の受け入れ条件 1）。

#### Scenario: 段ごとの字数が出る

- **WHEN** `bats --tap plugins/dev-workflow/tests/develop-worker-stages.bats` を実行する
- **THEN** `spec` / `implement` / `finish` の 3 段それぞれの `common.md`＋段のファイルの字数が `# ` で始まる行に出ており、字数の大きさで失敗するテストが無い

#### Scenario: PR 本文に分割前との比較がある

- **WHEN** この変更の PR 本文を読む
- **THEN** 3 段の字数と分割前の 13,416 字が並んだ表がある

#### Scenario: 同じ節が 2 か所に無い

- **WHEN** `worker/` の 4 本・索引・`references/pre-classification.md` の `## ` 見出しを集める
- **THEN** 同じ見出し行が 2 ファイル以上に無い

#### Scenario: (3) を細かく切らない理由は SKILL.md にある

- **WHEN** develop の `SKILL.md` の (3) と `worker/common.md` を読む
- **THEN** SKILL.md の (3) に手渡しの固定分と Red のテストから再出発する理由が書かれ、`worker/common.md` にその箇条が無い

### Requirement: 停止確認が返らないときの終端を観測できる量で定義し、帰結は手渡さず人間に報告する

前任のサブエージェントへ停止を指示したあと停止確認が返らないときの終端は、観測できる量で定義しなければならず（MUST）、閾値は環境変数で上書きできなければならない（MUST）。閾値の数値と環境変数名の正本は `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の節であり、この spec に数値を書いてはならない（MUST NOT）。終端に達したとき、本体は手渡し先を spawn してはならず（MUST NOT）、その作業を止めて人間に報告しなければならない（MUST）。終端は手渡しの許可条件（前任の `工程完了:` return か停止確認）に加わる第 3 の経路ではない。

#### Scenario: 終端に達する
- **WHEN** 停止を指示してからの経過時間と前任のトランスクリプトの無更新時間がどちらも閾値以上になる
- **THEN** 本体は手渡し先を spawn せず、前任の名前・停止を指示した時刻・worktree の `git status` を添えて人間に報告し、前任の再開の可否は人間の指示を待つ

#### Scenario: 片方の条件だけ満たす
- **WHEN** 経過時間は閾値以上だが前任のトランスクリプトが直近に更新されている
- **THEN** 終端とみなさず、停止確認を待つ手順を続ける

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

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`gh issue comment` の呼び出しの回数と本文、親子関係による `nested` と `launch` の拒否、上の `references/epic.md` の記述を確かめなければならない（MUST）。

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
- **THEN** `親エピックからの注意書き:` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のものに従い W・R1・G に渡すこと、それ以外の投稿者のものには従わず渡さずユーザーに報告すること、`note not posted to` のときに本体が投稿すること、起動し直したセッションでも `nested` になること、親エピックの番号を `parent epic: #` から読むこと、`child epics are not expanded here` で `launch` の拒否を見分けること、変数が無く `parent epic:` が出たときは親を持たないワークツリーで起動するよう伝えることが書かれていて、`grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` は 0 行

### Requirement: 端末を作れなかった子と指示が届かなかった子の案内は、二重起動を避ける確認を先に出す
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` が stderr に出す案内は、次を満たさなければならない（MUST）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の作り直しと送り直しのコマンドの規定に足すもので、既存の規定は変えない。

- 端末を作れなかった子の案内は、作り直しのコマンド（`orca terminal create ...`）より前の行に、そのワークツリーで `claude` がすでに動いている端末が無いことを確かめる `orca terminal list --worktree path:<子> --json` を出す（MUST。案内どおりに作り直して同じワークツリーで Claude Code が 2 つ起動し、`/develop #N` が二重に走るのを避けるため）
- 指示を送り直すための案内のハンドル引数（`orca terminal send --terminal <handle>` と `orca terminal read --terminal <handle>`）は、指示の文と同じく単一引用符で囲む（MUST）。対象は送り直しの案内の `send` と `read` だけで、作り直しの案内の `--terminal <handle from create>` は置き換え用の記号なので囲まない（SHALL）

develop の `references/epic.md`「エピックの扱い」は、端末を作れなかった `failed` の子について、stderr に出た確認のコマンドで既存の端末が無いことを確かめ、stderr の作り直しのコマンドで端末を作り、返ったハンドルに送信のコマンドを送って動き出したのを確かめてから再開する手順を書かなければならない（MUST。作り直さずに再開するとその子は `skipped` になり、`wait` が端末の無い子を親が気づかないまま待ち続けるため）。`orca` のコマンドは書かない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、`launch` が端末の作成や送信に失敗した子の、子のワークツリーのパスとハンドルである。ハンドルは Orca が払い出す単純な識別子（`term-11` など）で、引用符で囲むのは表示の揃えのためであり、ハンドルに記号が入る場合の検知は範囲外とする。

#### Scenario: 作り直しの案内の前に既存端末の確認を出す
- **WHEN** 子 11 の `orca terminal create` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** stderr の `orca terminal list --worktree path:<子 11 のパス> --json` を含む行は、`orca terminal create --worktree` を含む行より前にある

#### Scenario: 送り直しの案内のハンドルは引用符で囲まれる
- **WHEN** 子 11 の `orca terminal send` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stderr の送り直しのコマンドは `--terminal 'term-11'` を含み、確認のコマンドも `orca terminal read --terminal 'term-11'` を含む

#### Scenario: epic.md に端末を作れなかった子の再開手順が書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** 端末を作れなかった `failed` の子について、既存の端末が無いことを確かめ、作り直して送り、動き出したのを確かめてから再開することが書かれている

### Requirement: 本体は主の側にしか無い情報が要るときだけ主に聞く

`skills/develop/SKILL.md` は節「主に聞かずに決めること」を 1 か所持ち、本体・W・G が主に聞くのは、主の側にしか無い情報（好み・事業判断・許容度）、主の手でしかできない操作（MFA・OAuth・ログインなど）、規則が主の承認を求める操作（`rules/destructive-git-guard.md` の一覧・マージ・聖域）のどれかが要るときだけであると書かなければならない（MUST）。節は次の 4 つの型の決め方を持たなければならない（MUST）。

- **自分側の誤りの後始末**: 本体・W・G・レビュアーが記録先の範囲の外に誤って入れた変更（実ホームの設定ファイルへの書き足しなど）は、控え・git の履歴・自分のツール呼び出しの記録のどれかと今の状態を比べて、差分が自分側の入れた分だけで戻し先が一意に決まるなら、主に聞かずに戻す（MUST）。戻す前に今の状態の控えを取り（MUST）、戻したあと記録先に何を・どこから戻したか・控えの場所を事後報告する（MUST）。差分が自分側の分だけと確かめられないときは主に聞く（MUST）。git の破壊的操作（`rules/destructive-git-guard.md` の一覧）はこの型に入らず、従来どおり事前承認とする（MUST）。聖域（CLAUDE.md・hooks・権限設定）への変更を戻す操作も、差分が一意でもこの型に入らず、従来どおり無条件で人間承認とする（MUST）。`rules/destructive-git-guard.md` は変えない（MUST NOT）
- **範囲外の問題の起票**: 本体が作業中に見つけた記録先の範囲外の問題（レビュー指摘ではないもの。G の振り分けを経た指摘は G の振り分けのまま扱う）は、本体が次の手順で行き先（捨てる・既存 issue に参考として入れる・新しい issue）を決め、起票したら URL を事後報告する（MUST）。`skills/pr-review-gate/stages/triage.md` は PR 番号・PR コメント・G の手順 3 を前提にしているので丸ごとは当てず、段 B・段 D・段 E の問い（エピックの子の記録先なら段 C の問いも）と段 B の表だけを借りる（MUST）。
  - 候補探し: 段 B を通った問題が 1 件以上あれば、問題がファイルを指すなら `plugins/dev-workflow/scripts/review-issue-candidates.sh --repo $R --exclude <記録先の番号> [--epic <エピック番号>] <パス>...` を、ファイルを指さないなら `gh issue list --repo $R --state open --search "<問題を表す語>"` を、それぞれ 1 回だけ走らせる（MUST。打ち切りの再実行だけ例外）。記録先の番号は記録先の issue、記録先が Draft PR ならその PR の番号とする。エピックに属するときは、`--exclude` にエピックの番号も渡す（MUST。エピック自身が `other` の候補に返るのを防ぐ）。出力に `(15 件で打ち切り。ほかにも一致あり)` が出たパスがあり、エピックに属するときは、そのパスだけに `--epic <エピック番号> --children-only` を付けて走らせ直し、子の候補を足す（MUST。打ち切られたパスごとに 1 回を超えない）。再実行を含め、終了コードが 0 でないときの扱いは `triage.md` の候補探しの段落に従う（MUST）。再試行後の終了コードは記録先の `範囲外の問題の振り分け` コメントに書き、既存 issue への相乗りをせずに段 E へ進む（MUST）
  - 判断結果の記録: 記録先（issue、または Draft PR）に 1 行目が `範囲外の問題の振り分け` ちょうどのコメントを 1 件置き、問題ごとに、問題の要約・当てた段・行き先（issue にした・コメントで入れたならその URL、捨てたなら理由の 1 行）を書く（MUST）
  - 段 B の確認待ち: 条件がいつ成り立つかを本体が記録先・エピックの本文・受け入れ条件・コード・本文の節 `## 条件の答え` から決められないときは、起票の可否ではなく条件についての問いを主に聞く（MUST）。同じコメントにその問題を `条件の確認待ち` として質問文とともに残し、`needs-approval` を付けず、作業を止めない（MUST）。答えは 1 行にして記録先（エピックの子ならエピック）の本文の節 `## 条件の答え` に足し（節が無ければ作る）、その問題を段 B から当て直す（MUST）
  - エピックの注意書き: 記録先にエピックの親（OWNER）からの注意書きがあり、新しい問題の置き場所を指定している（例: エピック #1038 の「新しい問題はエピックに新しい子 issue として切る」）ときは、段 C の「既存の子 issue の受け入れ条件に足す」より注意書きを優先する（MUST）

  起票の可否を主に聞いてはならない（MUST NOT）。G の振り分けの結果を主への報告にまとめるときに、行き先を「オーナーが決める」に書き換えてはならない（MUST NOT）。起票によって配布や後続の作業の順番を変えるかは主に聞いてよいが、起票はその前に済ませる（MUST）
- **小さな実装の選択**: どれを選んでも受け入れ条件と利用者に見える振る舞いが変わらない選択肢は、その工程の担い手が選び、選んだ理由を記録先に残す（MUST）。レビューの 2 周目以降の周の終わりに残った指摘の直し方は「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement に従う（MUST）
- **閉じる操作**: 受け入れ条件を満たした記録先を閉じる操作は「develop のループの終わりは片付けを聞かず、ワークスペースに印を付ける」Requirement に従い、主に渡さない（MUST NOT）

この節はエピック #1038 の兄弟が直す節（「保留で止まるときの引き継ぎ」「エピックの扱い」）とは別の節として置く（MUST）。節は、自分側の誤りの後始末と範囲外の問題の起票のそれぞれに、次の守備範囲の段落を持たなければならない（MUST）。

自分側の誤りの後始末の守備範囲は、本体・W・G・レビュアーのツール呼び出しが記録先の範囲の外（実ホームの設定ファイル・別のリポジトリなど）に書いた変更である。拾いたい誤りは、戻す内容が差分から一意に決まるのに、戻してよいか・いつ戻すかを主に聞いて止まることで、これは主に聞かずに戻す。通してよい例は、控えの `.bak` との差分が自分側の書き足した 1 件だけで、その 1 件を消すこと（claude-harness #977 の `~/.claude/accounts.json` の `z`）。主の変更と区別できない差分・git の破壊的操作・聖域への変更を戻す操作は主に上げる。戻した内容が誤っていたことは防がない（戻す前に取った控えから取り消せる）。

範囲外の問題の起票の守備範囲は、本体が作業中（リハーサル・調査・実装の確認など）に見つけた、レビュー指摘ではない記録先の範囲外の問題である。拾いたい誤りは、起票してよいか・誰が起票するかを主に聞いて止まることと、G の振り分けの結果を「オーナーが決める」に書き換えて主に渡すことで、これらは主に聞かずに起票か捨てるかを決める。通してよい例は、リハーサルで詰まった操作を新しい issue にして URL を事後報告すること（flatmate #1104）。主に上げるのは、段 B の条件が本体に決められないときの条件についての問いと、起票によって配布や後続の作業の順番を変えるかの判断だけである。行き先の選び方が外れること（捨てた問題が後で効くなど）は防がない（記録先のコメントに理由が残るので、後から拾い直せる）。

#### Scenario: 節に主に聞く条件と 4 つの型がある
- **WHEN** SKILL.md の節「主に聞かずに決めること」を読む
- **THEN** 主に聞くのは主の側にしか無い情報・主の手でしかできない操作・規則が承認を求める操作が要るときだけと書かれ、自分側の誤りの後始末・範囲外の問題の起票・小さな実装の選択・閉じる操作の 4 つの決め方がある

#### Scenario: 自分側が誤って足した 1 件を戻す
- **WHEN** ゲート担当が実ホームの `~/.claude/accounts.json` に存在しないアカウントを 1 件誤って書き足し、控えの `.bak` との差分がその 1 件だけ
- **THEN** 本体は主に聞かず、今の状態の控えを取ってからその 1 件を消し、記録先に何を・どこから戻したか・控えの場所を事後報告する

#### Scenario: 差分が自分側の分だけと確かめられない
- **WHEN** 誤って書き足したファイルに、控えのあとで主が手で足したかもしれない変更が混ざっている
- **THEN** 本体は戻さず主に聞く

#### Scenario: git の破壊的操作は後始末でも事前承認
- **WHEN** 自分側の誤った commit を `git reset --hard` で戻したくなる
- **THEN** 本体は実行せず主に聞く（`rules/destructive-git-guard.md` に従う）

#### Scenario: 本体が見つけた範囲外の問題を自分で起票する
- **WHEN** 本体がリハーサルの記録を仕分けていて、記録先の範囲外の詰まった箇所を見つける
- **THEN** 本体は段 B の条件を決めてから候補探しを 1 回走らせ、段 D・段 E の問いで行き先を決め、記録先に 1 行目 `範囲外の問題の振り分け` のコメントを置き、新しい issue にしたら URL を事後報告し、起票してよいかを主に聞かない

#### Scenario: 聖域への変更は後始末でも人間承認
- **WHEN** 自分側が誤って `.claude/settings.json` の権限設定に 1 行を書き足し、控えとの差分がその 1 行だけ
- **THEN** 本体は差分が一意でも戻さず主に聞く

#### Scenario: エピックに属する記録先の候補探しでエピックを除く
- **WHEN** 記録先がエピックの子で、本体がファイルを指す範囲外の問題の候補探しを走らせる
- **THEN** `--exclude` に記録先の番号とエピックの番号の両方を渡す

#### Scenario: 打ち切りが出たパスだけ子の候補を取り直す
- **WHEN** 記録先がエピックの子で、候補探しの出力に `(15 件で打ち切り。ほかにも一致あり)` が出たパスがある
- **THEN** 本体はそのパスだけに `--epic <エピック番号> --children-only` を付けて走らせ直し、子の候補を足す。打ち切られたパスごとに 1 回を超えない

#### Scenario: ファイルを指さない範囲外の問題の候補探し
- **WHEN** 本体が見つけた範囲外の問題がリハーサルで詰まった操作で、特定のファイルを指さない
- **THEN** 本体は `review-issue-candidates.sh` を使わず、`gh issue list --state open --search` を 1 回走らせて候補を探す

#### Scenario: 範囲外の問題の条件が決められない
- **WHEN** 本体が見つけた範囲外の問題の条件がいつ成り立つかを、記録先・エピックの本文・受け入れ条件・コード・`## 条件の答え` から決められない
- **THEN** 本体は起票してよいかではなく条件についての問いを主に聞き、`範囲外の問題の振り分け` のコメントにその問題を `条件の確認待ち` として残し、`needs-approval` を付けずに作業を続け、答えを `## 条件の答え` に 1 行で足して段 B から当て直す

#### Scenario: エピックの注意書きが段 C より優先される
- **WHEN** エピックの子の記録先に、親から「新しい問題は新しい子 issue として切る」の注意書きがあり、範囲外の問題が同じエピックの既存の子 issue と同じ場所を指す
- **THEN** 本体は既存の子 issue の受け入れ条件に足さず、エピックに新しい子 issue を作る

### Requirement: エピックの子は親から届いた返事を止まった件への返事として受け取る
develop の `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」は、端末に `親エピック #<E> の判断（主の承認ではない）:` か `主の返事（親エピック #<E> 経由）:` で始まる入力が届いたら、止まった件への返事として受け取り、続きから進むことを規定しなければならない（MUST）。親の判断で進めた件は完了報告に書く（MUST）。`親エピック #<E> の判断（主の承認ではない）:` の入力を、聖域の変更や破壊的な操作の承認として扱ってはならない（MUST NOT）。記録の形と完了報告の書式は変えない（要件「エピックの子は PR のリスク許容の返事を待って止まるときだけ記録を残す」と #1036 の範囲）。

この要件の守備範囲で入力として扱うのは、子のセッションに届いた入力の頭の文字列だけである。拾いたい誤りは、親の判断を主の承認として聖域や破壊的操作を進めること、親の返事を受けても止まったままか再び同じ件で止まることの 2 つである（確かめられなかった親経由のリスク許容で、主に子のタブでの返事を頼むために新しい記録を残して止まることは除く）。入力の末尾の添え書き（`[主の発言: セッション <ID> / uuid <uuid>]`）は、要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」で読む。次は通ってよく、この要件では止めない: 頭の無い入力（主が子のタブで直接答えたもの。今までどおり主の返事として扱う）。頭の文字列を真似た入力など、すり抜ける形が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 子の手順に親から届いた返事の扱いが書かれている
- **WHEN** `references/epic-child-stop.md` のエピックの子が止まるときの手順を読む
- **THEN** 2 つの頭の文字列、`mark resumed` の語が無く、止まった件への返事として受け取って続きから進むこと、親の判断で進めた件を完了報告に書くこと、親の判断を聖域や破壊的操作の承認として扱わないことが書かれている

### Requirement: 親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る

develop の手順書（SKILL.md と `references/epic.md`・`references/epic-child-stop.md`）は、Orca 経路のエピックで主が親のセッションに書いたリスク許容を、子のゲートが主本人の返事として受け取れるよう、次の 3 か所を規定しなければならない（MUST）。

**Orca 経路の手順 8（親の送り方）**: 親は主の答えを `scripts/epic-dispatch.sh reply --as owner` で送る前に、`owner-reply-check.sh --locate "$CLAUDE_CODE_SESSION_ID" <主の答え>` を回し、`MATCH:` のうち全文が主の答えと同じ（どちらも連続する空白を 1 個にまとめて比べる）で timestamp がいちばん新しい行の uuid を取り、主の答えの末尾に ` [主の発言: セッション <親のセッション ID> / uuid <uuid>]` を添えて渡さなければならない（MUST）。主の答えそのものは書き換えてはならない（MUST NOT。添え書きは末尾に足すだけ）。`--relayed` の結び付けは親の発言の本文に停止の記録の URL があることで見るので、親は止まった子の報告を本文で書き（質問ツールで聞かない）、その本文に停止の記録の URL を書かなければならない（MUST）。URL を書いた最後の報告と主の答えのあいだに主の別の発言が挟まると子の `--relayed` は `not-direct` で落ちるので、そのときは報告を本文で出し直してから主の答えを受け直さなければならない（MUST）。終了コードが 0 でない、または該当する行が無いときは添え書きを付けずに送り、主に「<OK すると起きること>でよければ、子のタブで『許容する』と打ってほしい（親のタブの返事を子が確かめられなかったため）」と伝えなければならない（MUST）。

**「エピックの子が主の返事を待って止まるとき」の「親から届いた返事」（子の受け取り方）**: 子は、`主の返事（親エピック #<E> 経由）:` で始まる入力（起動し直されたセッションの最初の指示 `/develop #<N> （エピック #<E> の子。返事を受けて起動し直し） 主の返事（親エピック #<E> 経由）: …` の、括弧のうしろに付いて届いたものを含む）が止まった件のリスク許容への返事で、末尾に `[主の発言: セッション <ID> / uuid <uuid>]` があるとき、記録先の最新の `子の停止: 主の返事待ち` のコメント（投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のもの）の作成日時と URL で `owner-reply-check.sh --relayed <ID> <uuid> <作成日時> <URL>` を回さなければならない（MUST）。exit 0 で、`MATCH:` の全文から許容の意思が読め、全文がこの子・この PR への許容と読め、別の子・別の PR・別のリスクだけを名指しした答えでないときだけ、保留の解除の G に、親のセッション ID・uuid・`MATCH:` の timestamp・停止の記録の URL・`MATCH:` の全文を渡さなければならない（MUST。記録の書式と真正性確認は pr-review-gate 手順 5 の「親経由で受領」が正本で、develop の手順書（SKILL.md と `references/epic-child-stop.md`）に書式を再掲しない）。exit 0 で、`MATCH:` の全文から不許容の意思が読め、全文がこの子・この PR への答えと読め、別の子・別の PR・別のリスクだけを名指しした答えでないときは、主本人の不許容として受け取り、保留の解除の G に同じ値を渡して pr-review-gate の手順 6 の復帰手順の不許容の行で扱わせなければならない（MUST。主に子のタブで打ち直してもらわない）。添え書き（`[主の発言: …]` も `[主の委任: …]` も）が無い・`--relayed` が exit 0 でない・全文から許容とも不許容とも読めないときは、主本人の返事として扱ってはならず（MUST NOT）、G を起こさずに、主に子のタブで直接返事を打ってもらうよう頼み（止まる前の記録は同じ節の手順どおり）、頼む文に確かめられなかった理由（`REASON=` の値か「添え書きが無い」）を添えなければならない（MUST）。起動し直されたセッションでは、この受け取り方を「新しいセッションでの再開」の手順 2（`/develop` の引数の残りを自分のセッションの会話で受けた回答として扱う）より先に当て、引数の残りのうち `主の返事（親エピック #<E> 経由）:` で始まる部分を自分のセッション ID で `owner-reply-check.sh` に掛けてはならない（MUST NOT。子の会話ログのその行は⑨で主の発言として数えないので、掛けると主に受け直しを頼むことに落ちる）。この順序は「親から届いた返事」の箇条に書き、再開手順の本文は変えない（MUST）。リスク許容以外の返事（動作確認の結果・切り出しの確認への回答など）の受け取り方は変えない。末尾が `[主の委任: セッション <ID> / uuid <uuid> / 記録 <URL>]` の返事は、要件「子は委任の返事を確かめてから G に渡す」の手順で確かめ、この段落の `--relayed` に掛けてはならない（MUST NOT）。

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
- **THEN** 子は保留の解除の G を起こさず、主に子のタブでの返事を、止まる前の記録を残してから頼む

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

### Requirement: 起動し直した親は主の返事待ちの子を主に出し直す
`epic-dispatch.sh` は読み取り専用のサブコマンド `pending-owner <子>...` を持たなければならない（MUST）。各子について、子の記録の `stop` が `stopped-seen` なら、`pending <N>`（記録に `stop_uuid` があれば `pending <N> <uuid>`）を 1 行ずつ出して exit 0 で終わる。`stop_uuid` のある子は、会話ログの最後の子の発言か最後の入力がその発言より後なら出さない（MUST。読み取り専用のままで、記録の `stop` は書き換えない。会話ログを読めなければ今どおり出す）。`orca worktree list` も `orca worktree set` も呼んではならない（MUST NOT）。`references/epic.md` の Orca 経路の手順 7（`回し方: Orca` を引き継いだ再開）は、`launch` の前に、`launch` に渡したことのある開いた子で `pending-owner` を呼び、`pending` の子ごとに、その止まりの uuid に一致する最新の `親の判断:`（手順 8 と同じ照合）が「通した」以外のものを、手順 8 と同じ報告で本文に出し直してから待ちに入ると書かなければならない（MUST。今回の停止の記録が無く最後の発言が主への問いでない子は、手順 8 と同じく `dismiss` で戻して出し直さない）。再開済みかどうかは記録の `stop`（子が `mark resumed` で書く `resumed`）と子の会話ログの動きで決め、子 issue のコメントの新旧では決めない（MUST。停止後に親が投稿する `親の判断:` で除外されないため）。エピックのコメントの `親の判断: 子 #N 通した`（手順 8 と同じ author_association の条件）で、その行の `発言 <uuid>` が記録の `stop_uuid` と一致するもの（`stop_uuid` が空の止まりは、行の停止の記録の URL が子の最新の `子の停止: 主の返事待ち` の URL と一致するもの）がある子は、通して送った解決済みの件なので再報告から外す（MUST。通した直後に子が `mark resumed` を付ける前に親が起動し直されても再報告しない）。`親の判断: 通すが送れなかった` の件は手順 8 と同じく送り直す。`references/reply-after-idle.md` の「親への適用」の復元元の表は、主の返事待ちの子の行（復元元は子の記録の `stop` の `stopped-seen` と、子 issue の `子の停止: 主の返事待ち` および対応する `親の判断:`）を持たなければならない（MUST）。`tests/develop-skill.bats` は手順 7 と表の行を、`tests/epic-dispatch.bats` は `pending-owner` を確かめなければならない（MUST）。

この要件の入力は、子の記録の `stop` と `stop_uuid`、子の会話ログ、`gh` が返す子 issue のコメント（投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のもの）である。拾いたい誤りは、起動し直した親が記録の `stop` が `stopped-seen` の子を動いている子として 6 時間待ち、主に何も出さないことと、すでに再開した子や親が通した件を主に出し直すことの 2 つである。次は通してよく、この要件では止めない: 子が `mark resumed` を付け忘れ、`stopped-seen` が残ったまま動いていること（主に出し直された主が子のタブで答えれば済む。次の `mark stopped` で上書きされる）／読めない記録の子が `pending` に出ないこと／子 issue の `子の停止:` コメントの投稿者が権限の無いユーザーで、照合に使えず「判断が無い」として主に出されること。印の付け方の揺れを見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 手順 7 が主の返事待ちの子の出し直しを書いている
- **WHEN** `references/epic.md` の手順 7 を読む
- **THEN** `pending-owner` で記録の `stop` が `stopped-seen` の子を集め、`launch` の前に手順 8 と同じ報告で出し直すと書いてある

#### Scenario: 復元元の表に主の返事待ちの子の行がある
- **WHEN** `reply-after-idle.md` の「親への適用」の表を読む
- **THEN** 主の返事待ちの子の行があり、復元元に記録の `stop` の `stopped-seen`・`子の停止: 主の返事待ち`・`親の判断:` が書いてある

#### Scenario: pending-owner は受けた印のままの子だけを返す
- **WHEN** 子 11 の記録の `stop` が `stopped-seen`、子 12 が `resumed`、子 13 が `stopped` の状態で `epic-dispatch.sh pending-owner 11 12 13` を実行する
- **THEN** stdout は `pending 11` だけで、`orca worktree list` も `orca worktree set` も呼ばれない

#### Scenario: pending-owner は会話ログが進んだ子を出さない
- **WHEN** 子 11 の記録の `stop` が `stopped-seen`、`stop_uuid` が `d1` で、会話ログに `d1` のあとの子の発言がある。子 12 は同じ状態で `d2` が最後の発言である
- **THEN** stdout は `pending 12 d2` の 1 行で、記録は書き換えられない

### Requirement: 親は枠が空いたら後回しの子を起動し、サブエージェント方式でも同じ上限を当てる
develop の `references/epic.md`「エピックの扱い」→「回し方」は、次を書かなければならない（MUST）。これは要件「エピックの条件・作り方・回し方・完了条件を規定する」の回し方を書き換えず、上限と後回しの子の扱いを足すものである（「解けた子を件数にかかわらず `launch` する」は、`launch` に渡す子の選び方として今までどおりで、件数を抑えるのは `launch` である）。

**Orca 経路**: 手順 1 に、`launch` の出力に `deferred <N>`（上限に達したので起動しなかった子。後回しの子）があること、上限は `EPIC_DISPATCH_MAX_PARALLEL`（無ければ物理メモリから決める既定値）であることを書く。手順 2 に、後回しの子は `wait` の位置引数（動いている子）にも `--watch-done`（片付け待ちの子）にも入れないことを書く。手順 3（`done` を処理したあと）と手順 8（`stopped` を処理したあと）に、後回しの子が残っていれば、2 に戻る前に依存の解けた開いた子を `launch` に渡し直す（起動済みの子は `skipped`、枠がまだ無ければまた `deferred`）ことを書く。手順 4 の依存グラフを読み直して解けた子を `launch` する処理が後回しの子も含むことを書く。`completed` 以外で閉じたときも枠は空くので、見送りの子を前提にしていた子を除いて、後回しの子が残っていれば 2 に戻る前に依存の解けた開いた子を `launch` に渡し直すことを書く。後回しの子を `launch` に渡し直すときは、最初に渡したときと同じ `--note` を付けること（後回しの子には注意書きが投稿されていない）を書く。`launch` のあと動いている子も片付け待ちの子も 0 件なのに後回しの子が残るときは、`wait` を呼ばずに主に報告し、報告に `launch` の stderr の枠を使っている子の行を添えることを書く。後回しの子の一覧はどこにも保存せず、起動し直した親（手順 7）は依存の解けた開いた子を `launch` に渡した出力で後回しの子を知ることを書く。

**サブエージェント方式**: 開始時に `scripts/epic-dispatch.sh max-parallel` を 1 回呼んでその値を上限にし（exit 1 なら stderr を添えて設定の誤りとして報告して止まる）、エピックの全部の子をまたいで、枠を使っている W の総数をその上限までに抑えることを書く（MUST）。W 1 体（名前付きで起こし SendMessage で再開する 1 系列）は、起こしてから、その W が担う change のループが終わる（PR がマージされる・記録先が閉じる）か、主の返事待ちで保留に入るまで、1 枠を使う。主の返事待ちは本体が `needs-approval` を付けて待つ場面（W の停止・G の保留のどちらも）とし、そこで枠を返す。コンテキスト上限で手渡した後任の W は前任の枠を引き継ぐ。1 つの子の中で change ごとに W を並列に起こすときは、その W ごとに 1 枠を使う。本体は、新しい子の最初の W を起こす前・同じ子の中で別の change の W を起こす前・保留から戻る W を再開する前に、そのつど空き枠（上限から枠を使っている W の数を引き、0 未満なら 0）を確かめ、空き枠が 0 なら起こさず再開もせずに待ちに回すことを書く（MUST）。枠が空いたら、待ちに回したもののうち、保留から戻る W の再開を先に、そのあと同じ子の中の別の change の W、そのあと依存の解けた新しい子の最初の W の順で起こすことを書く（SHALL。主の返事を受けた件と始まっている子を先に進めるため）。

**Orca 経路と両経路に共通の数え方**: 「枠を使っている子」に、完了の印の子・閉じた子・主の返事待ちで止まった子を数えないこと、その理由（止まった子はアイドルで、数えると主の返事が遅れるあいだ全体が止まる）を書く。Orca 経路では止まった子が戻るのは子のセッションの中なので親が止められず、戻った子の分だけ一時的に上限を超えうることを書く。サブエージェント方式では再開を本体が行うので、上の手順で再開前に空きを確かめ、上限を超えないことを書く。

`plugins/dev-workflow/tests/epic-dispatch.bats`（または `tests/develop-skill.bats`）は、`references/epic.md` のこれらの記述があることを確かめなければならない（MUST）。

この要件の入力は `references/epic.md` の本文である。拾いたい誤りは、親が `deferred` の子を動いている子として `wait` に渡して親が気づかないまま待ち続けること、枠が空いても後回しの子を起動しないこと、サブエージェント方式で上限を超えて W を起こすことである。次は通してよく、この要件では止めない: `timeout` で起こされたときに後回しの子を `launch` に渡し直さないこと（枠は変わっていない）／サブエージェント方式で R1・G・決める役など W 以外の役割を枠に数えないこと（上限が抑えるのは W の数）／W が R1 や G の結果を待って動いていないあいだも 1 枠を使い続けること。手順書の読み方の揺れ（すり抜ける入力）が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: Orca 経路の手順に後回しの子の扱いが書かれている
- **WHEN** `references/epic.md` の Orca 経路の手順 1〜4・8 を読む
- **THEN** `deferred <N>` の意味、後回しの子を `wait` に渡さないこと、手順 3 と手順 8 のあとで後回しの子があれば `launch` に渡し直すこと、手順 4 の `launch` が後回しの子を含むことが書かれている

#### Scenario: 後回しの子だけが残ったら主に報告する
- **WHEN** `references/epic.md` の Orca 経路の手順を読む
- **THEN** 動いている子も片付け待ちの子も 0 件で後回しの子が残るとき、`wait` を呼ばずに `launch` の stderr を添えて主に報告することが書かれている

#### Scenario: サブエージェント方式に同じ上限が書かれている
- **WHEN** `references/epic.md` の「回し方」のサブエージェント方式の段落を読む
- **THEN** `epic-dispatch.sh max-parallel` の値を上限に、子をまたいだ W の総数を抑えること、W 1 体が枠を使う期間、新しい子の W・同じ子の別の change の W・保留から戻る W のどれも起こす前に空き枠を確かめること、待ちに回したものを起こす順（再開 → 同じ子の別の change → 新しい子）が書かれている

#### Scenario: 保留から戻る W は枠が空くまで再開しない
- **WHEN** 上限 2 のサブエージェント方式で、子 A と子 B の W を起こし、A が主の返事待ちで保留に入ったので子 C の W を起こしたあと、主が A に返事をした（B・C の W はまだ動いている）場面を、`references/epic.md` の手順に当てはめる
- **THEN** 手順からは、A の W を再開せずに待ちに回し、B か C の W が枠を返したら（ループが終わるか保留に入ったら）A を新しい子より先に再開する、と読める。同時に枠を使う W は 2 体を超えない

#### Scenario: 子の中で change ごとに W を起こすときも枠を使う
- **WHEN** 上限 2 のサブエージェント方式で、子 A の W と子 B の W が動いているあいだに、子 A が 2 つの change に割れて 2 つめの change の W を起こそうとする場面を、`references/epic.md` の手順に当てはめる
- **THEN** 手順からは、空き枠が 0 なので 2 つめの change の W を起こさずに待ちに回し、枠が空いたら新しい子より先に起こす、と読める

#### Scenario: Orca 経路で戻った子の扱いが書かれている
- **WHEN** `references/epic.md` の「回し方」の枠の数え方を読む
- **THEN** Orca 経路では戻った子の分だけ一時的に上限を超えうること、サブエージェント方式では再開前に空きを確かめるので超えないことが書かれている

#### Scenario: 枠を使っている子の数え方が書かれている
- **WHEN** `references/epic.md` の回し方を読む
- **THEN** 完了の印の子・閉じた子・主の返事待ちで止まった子を数えないことと、戻った子の分だけ一時的に上限を超えうることが書かれている

### Requirement: 実行モードは引数・印・依頼の届き方で開始時に決める

本体は develop を始めるときに 1 回、次の順で実行モードを決めなければならない（MUST）。

1. 引数に `--unmanned` があれば unmanned
2. セッションに印 `DEV_WORKFLOW_UNATTENDED` があるか、develop の依頼の発言がチャンネルのメッセージ（本文が `<channel source=` で始まる発言）なら channel。印の読み方は git ガード（`destructive-git-hook` の要件）と同じにする（未設定・空・`0` は印なし、それ以外は印あり。前後の空白は除いて比べる）。本体は印を Bash で読む
3. どちらでもなければ interactive

本体は決めたモードを develop 開始コメントに `実行モード: <モード>（<理由>）` の 1 行で残さなければならない（MUST。理由は `引数`・`印`・`チャンネルの依頼`・`既定` のどれか）。途中でモードを変えてはならない（MUST NOT）。新しいセッションで引き継ぎから再開するときは、引き継ぎの `実行モード` の値を使い、決め直さない（MUST）。

この要件の守備範囲は、画面を見ている人のいないセッションやチャンネルで頼まれた開発が interactive になって AskUserQuestion で止まることを防ぐことである。拾いたい誤りは、印のある住人と、印が付く前でもオーナーが Discord で頼んだ住人が interactive になること。オーナーが自分の画面の前にいて Discord から頼んだセッションが channel になることは止めない（質問の届く先が変わるだけで止まらない）。印が付かず、依頼もチャンネル以外から届いた住人が interactive になることは、この要件では塞がない。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 印のあるセッション

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` のセッションで、引数に `--unmanned` の無い develop を始める
- **THEN** 本体は channel に決め、develop 開始コメントに `実行モード: channel（印）` を残す

#### Scenario: 印は無いがチャンネルで頼まれた

- **WHEN** 印の無いセッションで、develop の依頼の発言が `<channel source="plugin:discord:discord" ...>` で始まる
- **THEN** 本体は channel に決め、develop 開始コメントに `実行モード: channel（チャンネルの依頼）` を残す

#### Scenario: 印の値が 0

- **WHEN** `DEV_WORKFLOW_UNATTENDED=0` のセッションで、画面の入力欄から develop を頼まれる
- **THEN** 本体は interactive に決める

#### Scenario: SKILL.md の文面

- **WHEN** SKILL.md の実行モードの節を読む
- **THEN** 決める順（`--unmanned` → 印かチャンネルの依頼 → interactive）と、印の読み方（未設定・空・`0` は印なし）と、開始コメントの `実行モード:` の行が書かれている

### Requirement: エピックの子は主にマージを頼むとき、マージ後の連絡を頼まない

develop の `SKILL.md`「ループの終わり」は、エピックの子（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested`）が PR のマージを主に頼んで（PR がマージされていないので `mark` を呼ばずに）ループを終えるとき、完了報告で「マージしたら教えてください」「ステータスを変えます」のような、マージ後に子のタブへ戻る連絡を主に頼んではならない（MUST NOT）と書き、代わりに「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くことを規定しなければならない（MUST）。親の `wait --watch-done` が完了を推定することを理由として添える（SHALL）。エピックの子でないセッションの完了報告には、この規定を当てない。

#### Scenario: ループの終わりにマージ後の連絡を頼まない規定がある
- **WHEN** SKILL.md の「ループの終わり」を読む
- **THEN** エピックの子が主にマージを頼んで終えるとき、マージ後の連絡を頼まず「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くことと、その理由（親の `wait` が完了を推定する）が書かれている

### Requirement: 親は権限のコメントが無ければ既定値で投稿して主に伝える
エピックの親は、次の 4 つの機会に、権限のコメントが無ければ既定値で投稿しなければならない（MUST）。最初の開始時（`回し方:` を残すとき）、エピックを再開したとき（手順 7）、手順 8 で PR トークン上限の止まりを扱うとき（照らす前）、サブエージェント方式の本体が子の記録先の exit 2 で照らすとき（照らす前）。投稿したら、interactive と channel では主に「子 1 件 6,000 万トークンで回す。広げたければ声をかけて」と伝える（MUST）。unmanned ではコメントだけを残す。

#### Scenario: 起動時に権限を置いて主に伝える
- **WHEN** interactive で `/develop <エピック番号>` を最初に始め、経路を決める
- **THEN** 親はエピックに 1 行目 `子の PR トークン権限: 60000000` のコメントを投稿し、主に「子 1 件 6,000 万トークンで回す。広げたければ声をかけて」と伝える

#### Scenario: 変更の前に起動したエピックの止まりを扱う
- **WHEN** 権限のコメントの無いエピックで、手順 8 の親が PR トークン上限の止まりを扱う
- **THEN** 親は既定値で `子の PR トークン権限: 60000000` を投稿して主に伝えてから、その値で照らす

### Requirement: 権限の内でない止まりは主に上げ、主が権限を広げたら照らし直す
親は、権限に照らして通さなかった PR トークン上限の止まりを、権限の値と権限を広げる選び方を添えて主に上げなければならない（MUST）。主が権限を広げて答えたら、親は新しい値で権限のコメントを投稿し直し、同じ止まりを (a)・(b) に照らし直して、満たせば `reply --as parent` で新しい上限 ＝ 新しい権限を送る（MUST）。主が権限を広げずに「続ける」とだけ答えたら、今までどおり `reply --as owner` で届け、子の本体は既存の式（合計 ＋ 直前の上限）で新しい上限を書く（MUST）。

#### Scenario: 権限を超える見込みは主に上がる
- **WHEN** 記録の合計の見込みが 75000000、権限が 60000000
- **THEN** 親は通さず、権限の値と権限を広げる選び方を添えて主に上げる

#### Scenario: 主が権限を広げて答える
- **WHEN** その止まりに主が「1 億まで広げていい」と答える
- **THEN** 親は `子の PR トークン権限: 100000000` と `主の発言:` の行を投稿し、見込み 75000000 ≤ 100000000 かつ上限 30000000 < 100000000 なので `reply --as parent` で新しい上限 100000000 を送る

#### Scenario: 主が広げずに続けると答える
- **WHEN** その止まりに主が「続ける」とだけ答える
- **THEN** 親は `reply --as owner` で届け、子の本体は合計 ＋ 直前の上限で `PR トークン上限:` を書く

### Requirement: 親の権限で続けた上限は子の本体が記録先に書く
親の権限で続けることになったら、子の本体は次の計測より前に記録先へコメントを投稿しなければならない（MUST）。書式は、1 行目 `PR トークン上限: <権限>`、2 行目 `決めた人: <親エピック #<E> の判断（親の権限の内。主の承認ではない）か、エピック #<E> の本体（親の権限の内）>`、3 行目 `権限: <権限のコメントの URL>`、4 行目 `停止の記録: <停止の記録の URL か なし>`。親の返事 `続ける。新しい上限 <権限>（親の権限。<URL>）` は、主が権限のコメントで先に承認した範囲の執行である。要件「エピックの子は親から届いた返事を止まった件への返事として受け取る」の「聖域の承認として扱わない」と、基準の聖域の「課金」には当たらない。子の本体は主に聞き直さず、権限の URL を `権限:` の行に残す（MUST）。

#### Scenario: 別セッション方式の子の本体が書く
- **WHEN** 子の本体が `親エピック #<E> の判断（主の承認ではない）: 続ける。新しい上限 60000000（親の権限。<URL>）` を受け取る
- **THEN** 子の本体は主に聞き直さず、記録先に `PR トークン上限: 60000000` と `決めた人:`・`権限: <URL>`・`停止の記録:` の行を投稿し、次の計測に `--cap 60000000` を付けて再開する

### Requirement: サブエージェント方式では親を兼ねる本体が権限に照らす
サブエージェント方式（unmanned・channel を含む）のエピックでは、親を兼ねる本体が、子の記録先の計測の exit 2 で主に聞く前に、見込みを子の記録先にコメントしなければならない（MUST）。そのうえで要件「親は PR トークン上限の止まりを権限に照らして続けさせる」の条件 (a)・(b) で照らし、満たせば要件「親の権限で続けた上限は子の本体が記録先に書く」の書式で投稿して続ける（MUST）。満たさなければ、exit 2 の手順で主に問う。手順は SKILL.md「PR トークン上限」に書く。

#### Scenario: サブエージェント方式では本体が照らして書く
- **WHEN** サブエージェント方式のエピックで、子の記録先の計測が exit 2（合計 31000000 / 上限 30000000）になり、本体の見込みが合計 40000000、権限が 60000000
- **THEN** 本体は見込みを子の記録先にコメントし、主に聞かずに `PR トークン上限: 60000000`（`決めた人: エピック #<E> の本体（親の権限の内）`・`停止の記録: なし`）を投稿して続ける

### Requirement: 判定できないときは何も出さず、セッションの開始を止めない
スクリプトは常に exit 0 で終わらなければならない（MUST）。次のときは何も出してはならない（MUST NOT。fail-open）: stdin が空か JSON でない、`transcript_path` が無いかファイルが無い、`CLAUDE_PLUGIN_ROOT` が空、`python3` が PATH に無い。会話記録のうち JSON として読めない行と、JSON として読めるが値の型が想定と違う行は 1 行ずつ飛ばし、走査を続けなければならない（MUST。そのあとの行に呼び出しがあれば差し込む）。

#### Scenario: stdin が JSON でなければ何も出さない
- **WHEN** stdin に `not json` を渡すか、stdin を空にして実行する
- **THEN** どちらも stdout は空で exit 0

#### Scenario: 会話記録が無ければ何も出さない
- **WHEN** `transcript_path` が存在しないファイルを指す `source: compact` の入力で実行する
- **THEN** stdout は空で exit 0

#### Scenario: CLAUDE_PLUGIN_ROOT が空なら何も出さない
- **WHEN** develop を呼んでいた会話記録で、`CLAUDE_PLUGIN_ROOT` を空にして `source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: python3 が無ければ何も出さない
- **WHEN** develop を呼んでいた会話記録で、`python3` の無い PATH で `source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: 壊れた行を飛ばして走査を続ける
- **WHEN** 会話記録に JSON として読めない行だけがあるときに実行し、続けてそのあとに `dev-workflow:develop` の Skill 呼び出しを足して実行する
- **THEN** 1 回目は stdout が空で exit 0、2 回目は読み直しの文を差し込む

#### Scenario: 形の違う行を飛ばして走査を続ける
- **WHEN** 会話記録に `skills` が数値の `invoked_skills`、`name` が一覧の要素、`input.skill` が一覧の Skill 呼び出し、`text` が一覧の text のブロック、最上位が一覧の行だけがあるときに実行し、続けてそのあとに `dev-workflow:develop` の Skill 呼び出しを足して実行する
- **THEN** 1 回目は stdout が空で exit 0、2 回目は読み直しの文を差し込む

### Requirement: モデルの表に引き継ぎの判定役の行がある

`skills/develop/SKILL.md` の「モデル」節の表は、引き継ぎの判定役の行を持たなければならない（MUST）。行は、種別が `dev-workflow:decider`、モデルが `opus` で残量モードによって上げも下げもしないこと、`SHARED_BUDGET_MODE=depleted` のときは起こさず主に聞く側に倒すことを書かなければならない（MUST）。

#### Scenario: モデルの表を読む

- **WHEN** SKILL.md の「モデル」節の表を読む
- **THEN** 引き継ぎの判定役の行に `dev-workflow:decider`・`opus`・depleted のときは起こさないことが書かれている

### Requirement: 親が通してよい範囲の基準は、ランナーの状態の確認を含む推奨の読み方を決める
`parent-pass-criteria.md` は、表でなく文章で、子の推奨がランナーの状態の確認を含むときの読み方を一通りに決めなければならない（MUST。条件表の 9 条件は増やさない。節「CI の見張りのやり直しの上限で止まった子」の対象の止まりには当てない）。`gh api` などで読むだけで済む確認は実機操作に当たらない（条件「実機操作でない」を満たす）。ランナーの機械での操作（ログイン・再起動・プロセスやディスクの確認と操作・設定変更）が要る確認は実機操作に当たる（満たさない）。判断できなければ実機操作に当たる側に倒す。確認が `gh api` だけで済むなら、推奨をそのまま（確認を含めて）通し、返事にその確認を書いてよい。機械での確認が要る推奨は、再実行が確認の結果に依らず推奨の中に独立した再実行が書かれているときだけ再実行だけを切り出して通し、返事は機械での確認を求めない。再実行が機械での確認や操作の結果に依るときは主に上げる。

#### Scenario: 基準のファイルが確認の種類で実機操作かを分けている
- **WHEN** `parent-pass-criteria.md` のランナーの状態の確認を含む推奨の読み方を読む
- **THEN** `gh api` で見られる確認は実機操作に当たらず、ランナーの機械での操作が要る確認は実機操作に当たり、判断できなければ実機操作に当たる側に倒すと書かれている

#### Scenario: gh api で確かめて結果に応じて再実行する推奨はそのまま通す
- **WHEN** 同じ箇所を読む
- **THEN** 確認が `gh api` だけで済む推奨（例: ランナーがオンラインか `gh api` で確かめ、結果に応じて再実行）は、確認を含めて通し、返事にその確認を書いてよいと書かれている

#### Scenario: 機械での確認が要る推奨は再実行だけを切り出せる条件が決まっている
- **WHEN** 同じ箇所を読む
- **THEN** 再実行が確認の結果に依らず独立した再実行が推奨に書かれているときは再実行だけを切り出して通し、返事は機械での確認を求めないこと、再実行が機械での確認や操作の結果に依るときは主に上げることが書かれている

### Requirement: 親が通してよい範囲の基準は、ランナーの状態の確認と見張りの上限の優先順位の守備範囲を限る
上の 2 つの要件の守備範囲を、次のとおりに限らなければならない（MUST）。入力として扱うのは、`stop-judge.sh` が集める子の最新の停止の記録と過去の `親の判断:`、および手順 8 で親のセッションが読む同じ記録である。拾いたい誤りは、ランナーの機械での操作が要る確認を含む推奨を通すこと、`gh api` だけで済む確認の止まりを主に上げること、見張りのやり直しの上限で止まった子の再実行を通る例の CI の再実行で通すことの 3 つである。次は通ってよい: 子が機械での確認を `gh api` の確認と書き誤った記録を通すこと（損失は CI 1 周分で、再び止まれば次は主に上がる）／通してよい止まりを判断のモデルが主に上げること。すり抜けを塞ぎ切ることは完了条件としない。

#### Scenario: 守備範囲が拾う誤りと通ってよい入力を分けている
- **WHEN** 上の 2 つの要件の守備範囲を読む
- **THEN** 入力は子の最新の停止の記録と過去の `親の判断:`、拾いたい誤りは 3 つ、通ってよい入力は機械での確認を `gh api` の確認と書き誤った記録を通すことと通してよい止まりを主に上げることで、すり抜けを塞ぎ切ることは完了条件でないと読める

### Requirement: 親は主の委任を、定型の委任の記録への主の直接の確認で受ける

`references/epic.md` は、別セッション方式の親が、主が親のタブで子のリスク許容を任せる旨を述べたとき、その発言だけを委任として扱わず（MUST NOT）、エピックの issue に定型の委任の記録を投稿し、本文に記録の URL と範囲・期間の文を書いて主に問うことを書かなければならない（MUST）。問いの答え方の行には、親のタブで `任せる` を、この問いの直後に別の発言を挟まずに打つことを書く（MUST）。主の直後の発言を委任の確認とし、全文から任せる意思が読めなければ委任を使わず問い直す（MUST）。

#### Scenario: 委任の記録の書式

- **WHEN** 親が委任の記録を投稿する
- **THEN** 本文は次の形で、1〜4 行目はこの文字列ちょうど（`<E>` はエピックの番号）になる

  ```
  主の委任: リスク許容
  エピック: #<E>
  範囲: このエピックの子が pr-review-gate で求めるリスク許容のうち、子の停止の記録の推奨が「許容する」のもの。聖域の変更・破壊的な操作・マージの承認・不許容は含まない
  期間: この記録への主の確認の発言から、このエピックに `主の委任:` で始まる次のコメントが付くか、エピックが閉じるまで
  きっかけ: <主が任せる旨を述べた発言の全文。無ければ なし>
  ```

#### Scenario: 主の自由な委任の発言を受けたとき

- **WHEN** 主が親のタブで「このエピックの子の許容は全部答えて」と述べる
- **THEN** 親は委任の記録をエピックに投稿し、本文に記録の URL と範囲・期間の文と答え方の行を書いて問い、主の直後の確認を受けるまで委任で返事を送らない

#### Scenario: 確認の前に別の発言が挟まったとき

- **WHEN** 親の問いのあとに主が別の件を話してから `任せる` と答える
- **THEN** 親は問いを本文で出し直してから確認を受け直す（子の `--delegated` は `not-direct` で落ちるため）

#### Scenario: 確認から任せる意思が読めないとき

- **WHEN** 親の問いの直後の主の発言が「ちょっと待って」のように任せる意思を読めない
- **THEN** 親は委任を使わず、問いを本文で出し直す

### Requirement: 親は委任の確認の場所をエピックに残す

`references/epic.md` は、親が委任の確認を受けたら、`owner-reply-check.sh --locate "$CLAUDE_CODE_SESSION_ID" <確認の全文>` で確認の uuid を引き、エピックに `委任の確認の場所: セッション <親のセッション ID> / uuid <uuid> / 記録 <委任の記録の URL>` の 1 行を投稿することを書かなければならない（MUST）。親は起動し直したあとも、最新の `主の委任:` で始まるコメントの URL を `記録` に持つ最新のこの行から値を取る（MUST）。引けないときは委任を使わない（MUST）。

#### Scenario: 起動し直した親が委任を使う

- **WHEN** 親のセッションが起動し直され、エピックに有効な委任の記録と、その URL を持つ `委任の確認の場所:` の行がある
- **THEN** 親はその行のセッション ID と uuid を添え書きに使う

### Requirement: 主の委任は取り消しと新しい記録とエピックの終わりで切れる

`references/epic.md` は、主が委任の取り消しを述べたら、親がその発言を受けた次のターンの最初のツール呼び出しでエピックに 1 行目 `主の委任: 取り消し` のコメントを投稿し、以後は委任で返事を送らないことを書かなければならない（MUST）。取り消しは主本人の確認を求めず、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` のどれかなら効く（MUST。範囲を狭める向きにしか働かないため）。それ以外の投稿者の `主の委任:` で始まるコメントは数えない（MUST）。

#### Scenario: 取り消しのあとは委任で送らない

- **WHEN** エピックの、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` の `主の委任:` で始まる最新のコメントが `主の委任: 取り消し`
- **THEN** 親は止まった子を今どおり主に上げ、委任で返事を送らない

### Requirement: 委任が有効かを決まった条件で確かめる

親・子・G は、委任が有効かを次の同じ文で確かめなければならない（MUST）: 委任の記録が、①エピック #<E> の issue のコメントで、1〜4 行目が定型の文ちょうど、2 行目の番号が <E> ②投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` のどれか ③エピックの、投稿者が同じ 3 種の `主の委任:` で始まるコメントのうち最新 ④`lastEditedAt` が null ⑤エピックが開いている ⑥子 issue がエピックの子（sub-issue か本文の子の表にある）。<E> は子では返事の頭 `主の返事（親エピック #<E> 経由）` の番号で、記録の URL の issue 番号と同じでなければならない（MUST）。

#### Scenario: 別のエピックの記録では効かない

- **WHEN** 返事の頭が `親エピック #1038` で、添え書きの記録の URL が別の issue のコメント、または記録の 2 行目が `エピック: #1100`
- **THEN** 委任は有効でないとして扱う

#### Scenario: 編集された記録では効かない

- **WHEN** 委任の記録の `lastEditedAt` が null でない
- **THEN** 委任は有効でないとして扱う

### Requirement: 委任が効く止まりを決まった条件で確かめる

親・子・G は、止まりに委任が効くかを次の同じ文で確かめなければならない（MUST）: ①子 issue の番号を、本文で最初に現れる `Closes #N`・`Fixes #N`・`Refs #N` の `N` に持つ開いた PR に `needs-approval` が付いている ②その PR の、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` で `## リスク宣言` で始まる最新のコメントが `主のリスク許容が必要。` の行を持ち、`対象 HEAD:` が PR の今の HEAD と同じで、`主の回答:` で始まる行をまだ持たない（G では、今確かめている委任の形の記録の行だけは除く） ③停止の記録の作成日時が、そのコメントの作成日時と委任の確認の timestamp の両方より後 ④停止の記録の `推奨:` の値（先頭の空白を除く）が `許容する` で始まる。

#### Scenario: 推奨が許容しないの止まりには効かない

- **WHEN** 停止の記録の `推奨:` の値が `許容しない。代替案で`
- **THEN** 委任は効かず、親は今どおり主に上げ、子は委任の返事を受け取らない

#### Scenario: リスク許容待ちでない止まりには効かない

- **WHEN** 止まった理由がマージ待ち・実機操作・方針の選び直しで、PR に `needs-approval` が無いか、最新の `## リスク宣言` のコメントに `主のリスク許容が必要。` の行が無い
- **THEN** 委任は効かない

#### Scenario: 委任の確認より前の止まりには効かない

- **WHEN** 停止の記録の作成日時が委任の確認の timestamp より前
- **THEN** 委任は効かず、親は今どおり報告して主の直接の答えを受ける

### Requirement: 親は有効な委任が効く止まりにだけ、委任で許容を送る

`references/epic.md` の手順 8 は、今回の停止の記録があり、委任が有効で止まりに委任が効くときだけ、主に上げずに `epic-dispatch.sh reply --as owner` で `許容する（主の委任による。停止の記録: <URL>） [主の委任: セッション <親のセッション ID> / uuid <確認の uuid> / 記録 <委任の記録の URL>]` を送ることを書かなければならない（MUST）。送れたらエピックに `委任で送った: 子 #<N> <停止の記録の URL>` の 1 行を残す（MUST。`親の判断:` で始めない）。同じ子のこの行の URL が今回の停止の記録の URL と同じなら送り直さない（MUST）。

#### Scenario: 委任で送った件をエピックに残す

- **WHEN** 親が委任で `reply --as owner` を送り、出力が `sent` か `relaunched`
- **THEN** エピックに `委任で送った: 子 #<N> <停止の記録の URL>` の 1 行を投稿する

#### Scenario: 同じ止まりに二度送らない

- **WHEN** 手順 7 か 8 で同じ子が再び挙がり、エピックにその子の `委任で送った:` の行があって URL が今回の停止の記録と同じ
- **THEN** 親は委任で送り直さず、子の再開を待つ

### Requirement: 親が委任で送る経路の守備範囲

親が委任で送る経路は、次の守備範囲で読まなければならない（MUST）。①入力の出どころは、親の会話の主の発言、エピックと子 issue と PR のコメント・ラベル（`gh` で読む）、同じ PC の親の会話ログ。親は協力的だが、主の雑談を委任と読み違える・別の子の止まりと取り違える前提で扱う ②拾いたい誤りは、確認の無い発言での委任、範囲外の止まり（推奨が許容でない・リスク許容待ちでない・確認より前）への送信、取り消し後の送信、二重送信 ③確認に「任せる」以外の語で任せる意思が読める答えは通してよい ④穴を塞ぎ切ることは完了条件にしない（MUST NOT）。

#### Scenario: 範囲外の止まりでは送らない

- **WHEN** 有効な委任があるが、止まりに委任が効かない
- **THEN** 親は委任で送らず、手順 8 の形で主に上げる

### Requirement: 子が委任の返事を受ける経路の守備範囲

子が委任の返事を受ける経路は、次の守備範囲で読まなければならない（MUST）。①入力の出どころは、子に届いた返事の頭と末尾の添え書き（親が書く）、エピック・子 issue・PR のコメントとラベル、同じ PC の親の会話ログ。親は写し間違い・別のエピックや別の記録との取り違えをする前提で扱う ②拾いたい誤りは、確認でない発言・別のエピックの記録・取り消し済みや編集済みの記録・範囲外の止まりでの委任を主の許容として G に渡すこと ③親と子が同じ PC で動き、委任の確認のあとに親が起動し直したものは通してよい ④会話ログの改変の検知と、穴を塞ぎ切ることは完了条件にしない（MUST NOT）。

#### Scenario: 別のエピックの記録を添えた返事は受けない

- **WHEN** 添え書きの記録の URL がこの子の属さないエピックのコメント
- **THEN** 子は G を起こさず、主に子のタブでの返事を頼む

### Requirement: エピックの親は報告に付ける状態表を区切りより下に置く

`references/epic.md` は、エピックの親が主に出す報告すべて（別セッション方式の「親が別セッション方式でターンを終えるときに主に出す発言すべて」と、サブエージェント方式の主への報告）に、次段落の例外を除いて状態表を付け、表・答えが要る子の URL・「前回の報告から片付いたもの」を報告の区切りより下に置くと規定しなければならない（MUST）。区切りより上の本文の最後の行は、既存の要件「エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う」のとおり答え方のままにし、1 行目も変えない。

例外は、待機前の最後のリクエストから 60 分以上経過した旧親の引き継ぎ・再開案内（エピックへの記録失敗時の停止報告を含む）に限る。この案内では状態表と、そのための `child-log` 確認を省略しなければならない（MUST）。新親は状態を復元後、別セッション方式では要件「別セッション方式の親は表を書く前に子の会話ログの末尾を読む」に従ってログを確認し、その結果を反映した状態表を区切りより下に置いて報告しなければならない（MUST）。サブエージェント方式では従来どおり本体の会話から状態表を書く。通常の報告や 60 分未満の通知・返事の処理後の報告へ例外を広げてはならない（MUST NOT）。

#### Scenario: 区切りより上の最後の行と 1 行目は変わらない
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** 表・URL・片付いたものは区切りより下に置くと書かれ、区切りより上の最後の行は答え方のまま、1 行目は今回いちばん先に答えてほしい 1 件の質問（なければ `主がすること: なし`）のままと書かれている

#### Scenario: 長時間後の旧親の引き継ぎ案内は状態表を省略する
- **WHEN** 待機前の最後のリクエストから 60 分以上経過した旧親が、既知の状態と未処理の受信内容をエピックに記録して新セッションでの再開を案内する
- **THEN** 旧親は状態表と `child-log` 確認を省略し、子を再調査せず案内して終える
- **AND** 主への再開案内自体は発言の一覧から除外せず、1 行目と答え方は既存の書き分けに従う

#### Scenario: 長時間後の記録失敗時も状態表を作るために再調査しない
- **WHEN** 60 分以上経過した旧親が引き継ぎ内容の記録に失敗する
- **THEN** 状態表と `child-log` 確認を省略したまま、エラーと未保存内容を主に示して止める
- **AND** 再開可能とは報告しない

#### Scenario: 通常の報告では状態表を省略しない
- **WHEN** 親が通常の報告、または 60 分未満の通知・主の返事を処理したあとの報告を出す
- **THEN** 別セッション方式・サブエージェント方式とも状態表を区切りより下に付け、長時間後の旧親の案内に限る例外を適用しない

### Requirement: 状態表は全部の子と親自身を決まった列で並べる

状態表は、表の上に確かめた時刻（JST）を書き、行を、まだ閉じていない全部の子 issue と親自身（エピックの番号）の 1 行ずつにし、列を `issue 番号・内容・ステータス・確認内容・推奨・答え方` にしなければならない（MUST）。確認内容は主に聞いていることの中身、答え方はどの画面で何を打つかを書き、答えが要らない行は `なし` と書く。

#### Scenario: epic.md が表の列を規定する
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** 確かめた時刻（JST）・親自身の行・列 `issue 番号・内容・ステータス・確認内容・推奨・答え方` が書かれ、答えが要らない行は `なし` と書くと書かれている

### Requirement: 状態表の規定の守備範囲を限る

状態表の規定が入力として扱うのは `references/epic.md` の文面でなければならない（MUST）。拾いたい誤りは、主が最新の 1 通だけで、閉じていない子の状態と自分がすることを読み取れないことである。次は通ってよい: 内容・確認内容の文の良し悪し／子が 1 件も残らない報告で表が空になること。書き方の穴を見つけるたびに決まりを足して塞ぎ切ることは、この規定の完了条件としない。

#### Scenario: 表の文の良し悪しは止めない
- **WHEN** 表の内容の列の文が分かりにくいという指摘が出る
- **THEN** この規定の範囲外として扱い、読み取れない誤り（状態と自分がすることが分からない）だけを直す

### Requirement: 別セッション方式の親は表を書く前に子の会話ログの末尾を読む

`references/epic.md` は、別セッション方式（Orca・tmux）の親が状態表を書く前に、`launch` に渡した子ごとに `scripts/epic-dispatch.sh child-log` で会話ログの末尾を読み（別のリポジトリの子は `<owner>/<repo>#N` で渡す。まだ起動していない子は渡さず、ステータスを `未起動（<理由>）` と書く）、子のタブで進んだ分を表に反映すると規定しなければならない（MUST）。子のタブで主が直接答えても子は issue の停止の記録を書き直さないので、記録だけを見て書くと表が子の実際の状態とずれる。会話ログの末尾と issue の記録が食い違うときは会話ログを優先する。

待機前の最後のリクエストから 60 分以上経過した旧親の引き継ぎ・再開案内（エピックへの記録失敗時の停止報告を含む）に限り、要件「エピックの親は報告に付ける状態表を区切りより下に置く」の例外に従い、旧親は状態表と `child-log` 確認を省略しなければならない（MUST）。この義務は新親へ移し、新親は状態を復元後、上記のログ確認を行ってから状態表を書かなければならない（MUST）。通常の報告や 60 分未満の通知・返事の処理後の報告では、ログ確認を省略してはならない（MUST NOT）。

#### Scenario: epic.md が会話ログの確認を表より前に置く
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** 別セッション方式では表を書く前に `child-log` で子の会話ログの末尾を読むこと、食い違えば会話ログを優先することが書かれている

#### Scenario: 長時間後の旧親は案内と記録失敗時の停止報告のためにログを読まない
- **WHEN** 60 分以上経過した旧親が引き継ぎ・再開案内、またはその記録失敗時の停止報告を出す
- **THEN** `child-log` 確認も状態表も省略し、既知の状態と受信内容だけで記録・案内または停止報告を行う

#### Scenario: 新親は復元後にログを確認してから状態表を書く
- **WHEN** 別セッション方式の新親が同じ worktree で develop の手順書とエピックの記録から状態を復元する
- **THEN** `launch` に渡した子の会話ログの末尾を `child-log` で確認してから、その結果を反映した状態表を区切りより下に置いて報告する
- **AND** ログと issue の記録が食い違うときはログを優先し、未起動の子は渡さず、読めない子は既存要件どおり `確かめられなかった` と書く

### Requirement: 読めない子のステータスは確かめられなかったと書く

`child-log` が `unreadable` を返した子のステータスは `確かめられなかった` と書き、記録から推測して書いてはならない（MUST NOT）。サブエージェント方式の子には独立した会話ログが無いので、`child-log` を使わず、本体が自分の会話から子の状態を書く。

#### Scenario: 読めない子とサブエージェント方式
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** `unreadable` の子は `確かめられなかった` と書き、サブエージェント方式は本体の会話から書くと書かれている

### Requirement: 子のセッションはアイドル時のコンパクトを切って起動する
`plugins/dev-workflow/scripts/epic-dispatch.sh` が作る子の起動コマンド（`launch` と、端末が無い子・`--relaunch` の子を起動し直す `reply`）は、子のアイドル時のコンパクト（待っている間の自動コンパクト）を切る `--settings '{"idleCompaction":false}'` を含み、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を含んではならない（MUST。置く場所は要件「エピックの並列起動は 1 段で止める」）。通常の自動コンパクトを止める指定（`DISABLE_AUTO_COMPACT` など）を付けてはならない（MUST NOT）。環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` は読まない（SHALL。設定されていても値を検査せず、起動コマンドを変えない）。

#### Scenario: launch は子の起動コマンドでアイドル時のコンパクトを切る
- **WHEN** `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=400 cld --settings '{"idleCompaction":false}' --model 'opus'` で、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を含まない

#### Scenario: 閾値の上書きの変数は読まない
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=150000`、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=`、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=120k` のそれぞれの環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** どれも stdout は `launched 11`、exit 0 で、`--command` は `EPIC_DISPATCH_PARENT_EPIC=400 cld --settings '{"idleCompaction":false}' --model 'opus'` である

#### Scenario: 端末が無い子を起動し直すコマンドもアイドル時のコンパクトを切る
- **WHEN** 端末が無い子 11 に `epic-dispatch.sh reply --as owner 400 11 <返事>` を実行する
- **THEN** `orca terminal create` の `--command` は `--settings '{"idleCompaction":false}'` を含み、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を含まない

この要件は、要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の表の `relaunched` の行の起動コマンドの説明（待っている間の自動コンパクトの閾値を前置きしたもの）に優先する。

この要件の守備範囲で入力として扱うのは、`launch` と、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）を実行したシェルの環境変数（`EPIC_DISPATCH_CLAUDE_CMD`・`EPIC_DISPATCH_MODEL`）だけである。拾いたい誤りは、子の起動コマンドにアイドル時のコンパクトを切る指定が入らず、子がコンパクトされて `SKILL.md` の中身を持たないまま進むことと、通常の自動コンパクトまで止めて子の会話が上限を越えることである。次は通してよく、この要件では止めない: 主の起動コマンド（`cld`）が子のプロセスの環境に入れる `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`（アイドル時のコンパクトを切った子では効かない）／`EPIC_DISPATCH_CLAUDE_CMD` が `--settings` を `claude` に渡さない形で、指定が効かなかった子／Claude Code が v2.1.290 より古く、指定が効かなかった子／この変更より前に起動され、従来の閾値で動いている子／`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` が設定された環境（値を見ずに無視する）。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

### Requirement: 親が長く待ったあとは親の表で続けるか起動し直すかを決める
`plugins/dev-workflow/skills/develop/references/reply-after-idle.md` は、親も子・単発と同じくアイドル時のコンパクトを切ること、親が最後のリクエストから 60 分以上待ったら compact の有無や会話量によらずエピックの記録から起動し直すこと、60 分未満なら続けることを規定しなければならない（MUST）。親だけの 120,000 の設定・compact 後なら続ける分岐・監視が続くから残す説明は現行の規則に残さない（MUST NOT）。

時間分類は timeout・子の通知・主の返事を処理する前に適用する（MUST）。最後のリクエストは起床の API リクエストを除いた待機前のものを使い、キャッシュを書いた行の時刻と混同しない。60 分以上なら旧親は未処理イベントをエピックに記録し、同じ worktree の新セッションで `/develop <エピック番号>` から手順書と記録を読み直して再開するよう主に案内して終える（MUST）。再開手順は要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」に定め、親の表と epic.md の手順 5 のどちらから読んでも時間分類が優先すると分かるようにする（MUST）。

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

### Requirement: 規則のファイルに親の待ちの費用と使用量の超過中の扱いを書く

`references/reply-after-idle.md` は、時間分類の表とは別の節に、wait が TTL によって 1h / unknown は上限 3000 秒、5m は 21600 秒を選ぶことと費用の理由を書かなければならない（MUST）。3000 秒は通常のポーリング間隔で約 45 分に起き、1 時間のキャッシュが切れる前に短く掛け直して読み出しで延ばすためと説明する。全 develop で idle compaction を無効にするため、約 54 分の idle compact 回避を現行の理由としてはならない（MUST NOT）。5m では短く起きてもキャッシュが残らず、起床回数を減らすため 21600 秒にする説明を残す（MUST）。

短い timeout の掛け直しは 60 分未満に限り、5m の長い timeout やスリープで 60 分以上たった場合は時間分類が優先し、記録から新セッションで再開すると書く（MUST）。使用量の超過中は有効期限が 5 分に縮むので 21600 秒に戻すこと（根拠 https://code.claude.com/docs/en/prompt-caching を添える）、`CLAUDE_CODE_PROMPT_CACHE_TTL` / `promptCacheTtl` で固定した人の扱い、PC が寝ている間はキャッシュを延ばせないこと、片付け待ちだけの明示上限も残す（MUST）。従来の「節を足すだけで表と文を変えない」という制約は、この change の共通 idle 無効化と親の表の改定には適用しない。

守備範囲: 入力は親の会話の TTL と最後のリクエストからの経過時間である。拾う誤りは、idle compact 回避を無効化後も費用の根拠にすることと、TTL による上限選択を捨てること。TTL の判定方法・値・wait の stdout / exit code は変更しない。

#### Scenario: 規則のファイルに親の待ちの費用と超過中の扱いがある

- **WHEN** 規則のファイルの親の待ちの費用の節を読む
- **THEN** 3000 / 21600 秒の TTL 選択、1 時間のキャッシュ維持と 5 分の起床回数削減、使用量超過時の 5 分への短縮と根拠 URL、TTL 固定、スリープの限りが分かる
- **AND** 約 54 分の idle compact の前に起きることを現行の理由にせず、共通 idle 無効化と親の 60 分の表に整合する

#### Scenario: 待ちの費用の節も長時間後の再開を優先する
- **WHEN** 5m の 21600 秒の timeout またはスリープ後の 60 分以上の経過を、費用の節からたどる
- **THEN** 旧親で無条件に掛け直す案内は無く、時間分類を先に適用して記録から起動し直すと分かる

### Requirement: 子への声かけ文と返事の形は一か所の定義を共有する

キャッシュ維持の声かけは、固定文・返事専用の接頭辞・順序付き欄名と区切りを一つの機械可読定義で持ち、送信・子の受信手順・発言の除外が共有しなければならない（MUST）。初期の欄名は #1374 の案の `待ち:`・`次:` とし、欄の意味の確定や調査による失敗検出を追加してはならない（MUST NOT）。返事は専用の接頭辞と各欄の短い値を持つ一行で、値に改行・区切り文字を含めない（SHALL）。

#### 判定要件に共通の守備範囲

この節は、送信対象・期限・TTL・端末状態・受信文・wait の起床・child-log の主/子の発言除外を判定する各要件に適用する。入力元は、同じプラグインの dispatch の引数、既存 epic-state の子の記録、GitHub の停止コメントと返事、子のトップレベル CLI 会話ログ（user/assistant/usage/timestamp）、共通定義、Orca/tmux の一覧・画面の CLI 出力である。拾いたい誤りは、別の親・完了・片付け済み・回答済みの子への送信、期限切れや不正時刻・TTL 不明を送信可とすること、曖昧な端末や実行中・入力済み・選択画面への送信、通常の主の回答や新しい質問の隠蔽、声かけだけで停止解除・親の起床・期限延長が起きることである。

通してよい入力の例は、dispatch が検査済みの worktree/待ち時間、tool_result/meta が間にある正常な往復、型の各欄の任意の短い値（意味や真偽を検証しない）、予約文と完全一致する主の入力である。最後の例は送信元を識別せず声かけとして扱い、対応する型どおりの返事も除外する限界を受け入れる。識別用の仕組みは作らない。複数行・型違いの返事は通して表示し、受け入れ条件 3 の質問保持は正常な一行の往復に限る。この逸脱だけでは stop=stopped-seen を変えず、親を起こさず、停止期間の基点を延ばさない。確認できない状態は送信しないが、CLI 観測と送信の間の主の入力競合、予約文の衝突、画面・JSON・ログのあらゆる崩れ方まで穴を塞ぎ切ることは完了条件にしない。

#### Scenario: 欄を追加しても照合が同じ定義に従う
- **WHEN** 共通定義の順序付き欄名を追加・変更して声かけを生成する
- **THEN** 生成した固定文に返事の型が含まれ、その型に従った返事を発言の除外が認識する。別のファイルに同じ固定文や欄名の一覧を持たない

### Requirement: 子の声かけには最後のリクエストと停止期間の期限を適用する

判定の守備範囲は要件「子への声かけ文と返事の形は一か所の定義を共有する」の「判定要件に共通の守備範囲」に従う。

声かけは、子の最後の成功した CLI リクエストからの経過が 3000 秒以上かつ 3600 秒未満で、記録の `stop_at`（空なら同じ停止の記録の作成時刻）から `EPIC_DISPATCH_OWNER_WAIT_SEC`（0 以上の整数。既定 43200）秒未満のときだけ送らなければならない（MUST）。この値は要件「wait は主に伝え済みの止まりだけが残るあいだ上限で起きずに待つ」の長い待ちの上限と同じ値である。声かけや wait 掛け直しで停止の基点を延ばしてはならない（MUST NOT）。起動し直しの会話量条件に該当する子、時刻・会話量・現行セッションを判定できない子、前の声かけの返事が未着の子には送らない（MUST NOT）。

#### Scenario: 最後のキャッシュ読み出しをリクエストとして扱う
- **WHEN** 1h のキャッシュ書き込みは 2 時間前だが、現在の一意の CLI セッションの最後の有効な assistant usage は cache-read のみで 3000 秒前であり、他の条件も満たす
- **THEN** 固定文を送る。書き込みの時刻をリクエストの時刻として使わない

#### Scenario: 境界とスリープ復帰
- **WHEN** 他の条件を満たす子について最後のリクエストから 2999 秒・3000 秒・3599 秒・3600 秒、またはスリープ等で 1 時間を超える経過をそれぞれ用意する
- **THEN** 3000 秒・3599 秒の場合だけ送る。3600 秒以上では起動も声かけもせず、実際の返事時に #1323 の規則へ渡す

#### Scenario: 同じ停止の 24 時間を超えない
- **WHEN** `EPIC_DISPATCH_OWNER_WAIT_SEC=86400` で、記録の `stop_at`（空なら最新の停止記録の作成時刻）が 86400 秒以上前で、直前の声かけの返事と wait の掛け直しは 3000 秒前である
- **THEN** 固定文を送らず、停止の印を保ち、記録の `keepalive` は `skipped expired` で終わる。同じ値で停止から 86399 秒（43200 秒を過ぎていても）で他の条件を満たす場合は送る

#### Scenario: 同じ停止の既定の上限を超えない
- **WHEN** `EPIC_DISPATCH_OWNER_WAIT_SEC` を設定せず、記録の `stop_at`（空なら最新の停止記録の作成時刻）が 43200 秒以上前で、直前の声かけの返事と wait の掛け直しは 3000 秒前である
- **THEN** 固定文を送らず、停止の印を保つ。停止から 43199 秒で他の条件を満たす場合は送る

#### Scenario: 多重送信と起動し直しを避ける
- **WHEN** 前の固定文にまだ返事が無い、または会話量が既存の起動し直し閾値以上である
- **THEN** 固定文を送らず、そのために新しいセッションを起動しない

### Requirement: 声かけは入力待ちの既存セッションにだけ届く

判定の守備範囲は要件「子への声かけ文と返事の形は一か所の定義を共有する」の「判定要件に共通の守備範囲」に従う。

Orca/tmux の起動部品は、キャッシュ維持の声かけを、既存の子のセッションが一意に決まり、前景が空いた入力待ちで入力欄が空のときだけ送らなければならない（MUST）。端末無し・曖昧・実行中・選択画面・入力済みは送らない（MUST NOT）。声かけのために端末の起動・再起動・終了・入力の消去をしてはならない（MUST NOT）。送信確認は返事の内容や費用削減の検証と区別する（SHALL）。

画面・空欄の判定と起動時の `--prompt-suggestions false` は、同じ change の `dev-workflow-epic-state` の起動部品の契約に従う（MUST）。

#### Scenario: 入力待ちに送って開始を確かめる
- **WHEN** 既存セッションが一意で、入力待ちかつ入力欄が空である
- **THEN** 固定文を送ってターンの開始を確かめる。起動・close は行わない

#### Scenario: 対象の端末を送信できない
- **WHEN** 端末が無い・複数の候補・空の `❯` とスピナーが同居・主の文字または Orca の提案文が draft に入っている・質問ツールや許可やフォルダ信頼の確認画面、の各状態で声かけを試みる
- **THEN** 送信を見送り、端末や入力内容を変えない。通常の主の返事を待てる状態を保つ

#### Scenario: バックグラウンドのシェルだけなら声かけできる
- **WHEN** 既存セッションが一意で、前景の入力待ちと空欄を確認でき、実行中・選択画面は無く、`· 1 shell still running` が表示され、他の送信条件も満たす
- **THEN** バックグラウンドの表示を busy とみなさず声かけを送る

### Requirement: 子は声かけにだけ返し停止の状態を保つ

判定の守備範囲は要件「子への声かけ文と返事の形は一か所の定義を共有する」の「判定要件に共通の守備範囲」に従う。

子は、停止前に共通定義を読み、固定文の受信を通常の主の返事や親の判断より先に分類し、定義どおりの一行だけ返さなければならない（MUST）。声かけの受信ターンではツール・調査・作業・停止コメントの投稿を行ってはならない（MUST NOT）。固定文と完全一致しない実際の返事が届いた場合は従来の再開手順に従う（SHALL）。固定文は主が入力した場合も予約文として扱い、送信元の識別を追加しない（SHALL）。

#### Scenario: 主の返事待ちを継続する
- **WHEN** 質問して止まり、親が停止を受けて stop=stopped-seen になった子に固定文が届く
- **THEN** 子は指定の一行だけ返し、status/stop・最新の停止記録の URL と本文は変わらず、元の質問が未回答のまま残る

#### Scenario: 通常の返事は再開する
- **WHEN** 声かけ後に、固定文に完全一致しない主の直接の返事または正規の親からの返事が届く
- **THEN** 子は声かけの返事として扱わず、続きの作業に進む

### Requirement: 親と子のキャッシュ維持費用を実エピックで比較する

#1383 の完了前に、実装後の実エピック一本と実装前の比較区間を既存 cost-ledger で比べ、親と子を分けて issue に記録しなければならない（MUST）。書き直しの tokens/USD、cache-read、声かけと親の起床を含む費用、件数・会話量・モデル・TTL・比較期間を記す（SHALL）。実測無しや比較不能を費用削減の成功と扱ってはならない（MUST NOT）。

#### Scenario: 親子の費用を分けて記録する
- **WHEN** 実装後の実エピックで一時間以上の主の返事待ちを含むログが得られる
- **THEN** 子の再開区間と親の長い待ち後の起床区間について、声かけ・定期起床を含む区間全体を実装前と比較する。声かけでリクエストの空白が短くなっていても待ち区間に含め、元データの識別子と差異を #1383 に記録する

#### Scenario: 実測が足りない
- **WHEN** 実装後の実エピックが未実行、該当区間がゼロ、または比較できるログが得られない
- **THEN** 理由と不足するデータを記録し、費用比較のタスクは未完了とする

### Requirement: 仕様レビューの残った指摘は直し方の判定の前に条件を確かめる

`skills/develop/references/fix-check.md` は、節「残った指摘の条件を確かめる」を 1 か所だけ持ち、仕様レビューの残った BLOCKER の条件を確かめる本体の手順の正本としなければならない（MUST）。`skills/develop/SKILL.md` の 1 ループの (2) は、直し方の判定の前に残った指摘の条件が成り立つかを確かめ、成り立つ予定が無い指摘は判定に回さず捨てることを短く書き、この節を指さなければならない（MUST）。

**通す時点**: 本体は次の 3 つの時点でこの節の手順を通す（MUST）。①R1 の `REQUEST_CHANGES` の BLOCKER に `条件の問い:` の行があるとき、周によらず W を再開する前 ②2 周目以降の周の終わりに BLOCKER が残ったとき、決める役を起こす前 ③直し方の判定が「選び直しが要る」で主に聞いた問いへの答えが条件についての答えのとき、W を再開する前。R1 の NOTE に `後で成り立つ:` の行があるときは、周と結果によらず段落「NOTE の後で成り立つ指摘」だけを当て、手順は通さない（MUST）。

#### Scenario: SKILL.md の (2) に判定の前の段が書かれている
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (2) を読む
- **THEN** 直し方の判定の前に残った指摘の条件を確かめること、成り立つ予定が無い指摘は判定に回さず捨てること、`references/fix-check.md` の節「残った指摘の条件を確かめる」を Read することが書かれている

#### Scenario: 条件の判定がすべて書かれていれば手順は素通りする
- **WHEN** 2 周目の終わりに残った BLOCKER のすべてが「いまの範囲で成り立つ」で、問いが無く、`## 条件の答え` に新しい行も無い
- **THEN** 本体は主に聞かず R1 も起こさず、そのまま直し方の判定に進む

### Requirement: 成り立つ予定が無い指摘は直し方の判定に回さず捨てる

**判定に回す指摘**: 成り立つ予定が無い指摘は判定に回さず捨てる（MUST）。本体は、この節を通したあとの最新の結果に BLOCKER として残った指摘だけを、直し方の判定の「残った指摘の原文」に入れる（MUST）。当て直しの結果が `APPROVE` なら直し方の判定を起こさず (3) へ進む（MUST）。BLOCKER が残れば、周の扱いは通常どおり（1 周目は W を再開し、2 周目以降は直し方の判定を通す）とする（MUST）。

#### Scenario: 2 周目に残った指摘を判定の前に捨てる（flatmate #702）
- **WHEN** 2 周目の終わりに「同じ枠を別アカウントで使い回したあとの使用量の帰属」の BLOCKER だけが `条件の問い:` の行つきで残り、主が「新しいアカウントは新しい枠を作るので起きない」と答える
- **THEN** 本体は答えを `## 条件の答え` に足して R1 に当て直させ、R1 は「成り立つ予定が無い」として捨てて `APPROVE` を投稿し、本体は決める役を起こさない

#### Scenario: 一部が捨てられたら残りだけを判定に回す
- **WHEN** 2 周目の終わりに BLOCKER が 2 件残り、当て直しで 1 件が捨てられ 1 件が「いまの範囲で成り立つ」のまま残る
- **THEN** 本体は残った 1 件だけを入力に直し方の判定を依頼し、当て直しは周に数えない

### Requirement: 条件の問いは条件だけを主に聞く

**主への問い**: 問いは条件についての問いだけにし、指摘を直すか・捨ててよいかを聞いてはならない（MUST NOT）。主がいつ答えるかを本体は知らないので、どのモードでも、答えを待つ前に `needs-approval` を付けて問いを PR（無ければ記録先）のコメントに書き、そのコメントを「主への依頼」として `references/handover.md` の引き継ぎを待ち理由 `条件の問い` で残す（MUST）。そのうえで interactive は AskUserQuestion で聞き（MUST）、channel はそのコメントの URL を添えてチャンネルで聞き（MUST）、unmanned はそのサイクルを終える（MUST）。

#### Scenario: 主への問いは条件だけを聞く
- **WHEN** `references/fix-check.md` の節「残った指摘の条件を確かめる」を読む
- **THEN** 聞くのは条件についての問いだけで、指摘を直すか・捨ててよいかを聞かないこと、どのモードでも答えを待つ前に `needs-approval` を付け、待ち理由 `条件の問い` の引き継ぎを残すこと、unmanned はサイクルを終えることが書かれている

#### Scenario: interactive の問いも答えを待つ前に記録に残す
- **WHEN** interactive の本体が R1 の `条件の問い:` を主に聞く
- **THEN** 本体は AskUserQuestion の前に `needs-approval` を付け、問いのコメントと待ち理由 `条件の問い` の引き継ぎを残す。主がセッションを閉じても、新しいセッションが同じ問いを拾える

#### Scenario: channel の問いもコメントの URL を添えて聞く
- **WHEN** channel の本体が R1 の `条件の問い:` を主に聞く
- **THEN** 本体は問いのコメントと待ち理由 `条件の問い` の引き継ぎを残し、そのコメントのフル URL を添えた質問をチャンネルに送ってターンを終える

#### Scenario: 条件の問いの答えで再開する
- **WHEN** 待ち理由 `条件の問い` の引き継ぎがある記録先を新しいセッションの本体が再開し、再開の手順 2 で主の答えを得る
- **THEN** 本体は同じ問いを出さず、手順 3 の確認のあとで答えを `## 条件の答え` に足してラベルの付け先から `needs-approval` を外し、先に R1 を起こして当て直させ、W はその結果に従って起こす

### Requirement: 条件の確かめの守備範囲

`references/fix-check.md` の節はこの手順の守備範囲を書かなければならない（MUST）。この手順の守備範囲は、仕様レビューで起きる予定の無い場面への BLOCKER が、直し方の判定と主への確認に進むことを防ぐことである。想定する入力の出どころは R1 の結果の BLOCKER で、拾いたい誤りは、運用上成り立たない条件の指摘を「どの直し方か」の問いに回してしまうことである。通ることを許す入力の例として、R1 が「いまの範囲で成り立つ」と判定した指摘は本体が疑わずに判定へ回す（本体は条件を自分で判定しない）。その指摘が「選び直しが要る」で主に上がり、主が条件を答えたときは、答えを節に足して当て直す。判定の誤りが 1 件も無いことをこの手順の完了条件にしない。

#### Scenario: 守備範囲が書かれている
- **WHEN** `references/fix-check.md` の節「残った指摘の条件を確かめる」を読む
- **THEN** 守備範囲として、指摘の出どころ・拾いたい誤り・通すことを許す例・判定の誤りが 1 件も無いことを完了条件にしないことが書かれている

### Requirement: 記録の無い止まりを主に上げるときは最後の発言から組み立てる

親は今回の停止の記録が無い止まりを主に上げるとき、`child-log --last` の全文を読み、`~/.claude/output-styles/readable.md` の節 3 の型で説明を組み立て、子の番号と発言の時刻を添えなければならない（MUST）。要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」の、本文に停止の記録の URL を書く規定は、記録のある止まりに限る。`stages/pass.md` の親経由の受領は変えない（MUST）。

#### Scenario: 手順 8 が記録の無い止まりを書いている
- **WHEN** `references/epic.md` の手順 8 を読む
- **THEN** 記録が無いときは `child-log --last` の全文から同じ型で説明を組み立て、子の番号と発言の時刻を添えること、記録のある止まりは URL を添えることが書かれている

### Requirement: 親の側は子の発言の本文を公開のコメントに載せない

`wait`・`stop-judge.sh`・親は、子の発言の本文を issue のコメントに自動で投稿してはならない（MUST NOT。公開の issue に作業中の内容が漏れるため）。記録の無い止まりの見分けには uuid だけを書く（MUST）。

#### Scenario: 親の判断のコメントに発言の本文が入らない
- **WHEN** 記録の無い止まりで判断のスタブが `判断: 主に上げる` を出し、会話ログの最後の発言に特定の文字列がある
- **THEN** 子 issue の `親の判断:` のコメントにその文字列は無く、`止まりの発言:` の uuid と `停止の記録: なし` がある

### Requirement: エピックの子の止まりの手順は親に止まりを気づかせる義務を持たない
子の側の規定:

- 対象は `scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッションに限る（MUST）。それ以外のセッションでは記録を残さない（MUST NOT）
- 子の止まりに親が気づくのは親の `wait` の役割で、子の側に親に止まりを気づかせるための手順を規定してはならない（MUST NOT）。定型の `止まった理由:` の行は親の分岐の入力で、書かなくても `wait` で気づくので当たらない。`references/epic-child-stop.md` に `mark stopped` / `mark resumed` を呼ぶ手順を書いてはならない（MUST NOT）
- 記録を残さない止まりでは、最後の発言の中で質問・推奨・根拠を中身で書く（SHALL。読み手は親と主で、書き方の正本は `rules/communication-style.md`）。マージ待ち・PR トークン上限・CI の見張りの止まりは要件「定型の止まりは最後の発言の `止まった理由:` の行で親に渡す」に従う（MUST）

#### Scenario: 子の止まりの手順に mark の義務が無い
- **WHEN** `references/epic-child-stop.md` のエピックの子が止まるときの手順を読む
- **THEN** `mark stopped` / `mark resumed` の語が無く、`route` が `nested` を返すセッションに限ることが書かれている

### Requirement: 端末の画面や入力待ちの時間で子の止まりを決めない
端末の画面や入力待ちの時間だけで子の止まりを決める手順を書いてはならない（MUST NOT。誤検知が多いため。根拠は change `epic-child-stop-signal` の design.md）。子の止まりの検知は要件「wait は子の会話ログから止まった子を検知する」の条件に限り、背景のタスクの扱いは要件「wait は背景のタスクの有無で止まりとみなす待ち時間を変える」に、問いでない発言の扱いは要件「epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける」に従う（MUST）

develop の手順書（`skills/develop` 配下）に `orca` のサブコマンドを書いてはならない（MUST NOT。既存の規定どおり、`orca` を呼ぶのは Orca の起動部品 `epic-launch-orca.sh` だけ）。

#### Scenario: 手順書に端末の画面での判定と orca のサブコマンドが無い
- **WHEN** develop の手順書（`skills/develop` 配下）を読む
- **THEN** 端末の画面や入力待ちの時間だけで子の止まりを決める手順が無く、`orca` のサブコマンドが書かれていない

### Requirement: エピックの子の止まりの手順の守備範囲を限る
要件「エピックの子の止まりの手順と、親が stopped を受けて報告する手順を規定する」「エピックの子の止まりの手順は親に止まりを気づかせる義務を持たない」「エピックの子は PR のリスク許容の返事を待って止まるときだけ記録を残す」「親は検知できない止まりを手順 5 と手順 2 に書く」「端末の画面や入力待ちの時間で子の止まりを決めない」の検査が入力として扱わなければならない（MUST）のは、子のセッションでは `epic-dispatch.sh route`（子の番号なし）の出力、PR のリスク許容の返事を待つかどうかの子自身の判断、記録先の issue 番号で、親のセッションでは `wait` の出力と子 issue のコメント（1 行目が `子の停止: 主の返事待ち` のもののうち今回の停止の記録）である。拾いたい誤りは、PR のリスク許容の返事を待つ子が記録を残さずに止まって親経由の受領が確かめられないこと、エピックの子でないセッションが読む者のいない記録を残すこと、親が止まった子を動いている子から外して閉じたことを検知できなくなることの 3 つである。

#### Scenario: 止まりの手順の検査が止めないもの
- **WHEN** 次のどれかに当たる: 記録の項目の値の長さと改行の違い（値が複数行に続くこと）／止まるたびに記録が増えること（最新の 1 件を正とする）／保留の場面で引き継ぎと記録の 2 件のコメントが並ぶこと／主が子のタブで先に答えて、親が既に再開した子の `stopped` を受けること（親は記録を読んで報告するだけで、返事の仕方は #1034 で決める）／子の会話ログを読めない（置き場が無い・`entrypoint` が `cli` の行が無い）ために親が気づかないこと／更新前の版の子が記録と `mark` を残すこと（検知は要件「wait は子の会話ログから止まった子を検知する」の条件に限る）
- **THEN** これらの要件では止めない。記録の中身（理由・推奨・リスクの正しさ）を確かめることと、手順を守らない子を見つけるたびに検査を足して塞ぎ切ることは、この要件群の完了条件としない

### Requirement: 親は今回の止まった理由を記録か最後の発言から読む

親（`references/epic.md` の手順 8、マージ待ちの子、PR トークン上限の子、`parent-merge-criteria.md`）は「今回の止まった理由」を次のとおり読まなければならない（MUST）: 今回の停止の記録があればその `止まった理由:` の値、無ければ `child-log --last` の `.text` の行のうち行頭が `止まった理由: ` の最後の行の値。`epic.md` はこの語の定義を 1 か所に書き、分岐の文はこの語で読む（MUST）。

守備範囲: 入力は親が読む子の最後の発言と、更新前の版の子の停止の記録である。拾いたい誤りは、親がこの行だけで何かを承認すること。行は子の発言なので、親はこの行だけで何かを承認してはならない（MUST NOT）。マージ待ちは PR の前提の確認と決める役を、PR トークン上限は権限の条件を、CI は基準の節を通す。発言に外の文章が引用されて行が偽装されることを塞ぎ切ることは完了条件としない。

#### Scenario: 親は記録の無い止まりの定型の行で分岐する
- **WHEN** 今回の停止の記録が無く、`child-log --last` の `.text` の末尾の行が `止まった理由: PR のマージ待ち（human-merge）: https://github.com/o/r/pull/9`
- **THEN** 親は `parent-pass-criteria.md` に照らし直さず、マージ待ちの子の手順に進む

#### Scenario: 更新前の版の子の記録は先に読む
- **WHEN** 今回の停止の記録の `止まった理由:` が `PR トークン上限（合計 31000000 / 上限 30000000）` で、最後の発言に `止まった理由:` の行が無い
- **THEN** 親はこの記録の値を今回の止まった理由として読み、PR トークン上限の子の手順に進む

### Requirement: 長い待ちは止まりの変化で既存の行で返る

長い待ちのあいだに、子の止まりの uuid が変わったら `stopped`、子 issue が閉じたら `closed`、会話ログが止まりの発言より進んで記録が `resumed` になったら（主の返事が届いた）普通の上限の判定に戻し、その上限を過ぎていれば `timeout` の行で返らなければならない（MUST）。新しい行を足してはならない（MUST NOT）。

#### Scenario: 子 issue が閉じたら closed で返る
- **WHEN** 伝え済みの止まりの子 11 で長い待ちに入ったあと、子 11 の issue が `closed` を返すようになる
- **THEN** stdout は `closed 11` の 1 行で exit 0

#### Scenario: 止まりが変わったら stopped で返る
- **WHEN** 長い待ちに入ったあと、子 11 の会話ログに `d1` より新しい問いの発言 `d2` が足される
- **THEN** 記録の `stop_uuid` が `d2` になり、stdout は `stopped 11` を含んで exit 0

#### Scenario: 主の返事が届いたら timeout で返る
- **WHEN** `--timeout 2` で長い待ちに入り、2 秒を過ぎてから子 11 の会話ログに `d1` のあとの主の発言が足される
- **THEN** 記録の `stop` が `resumed` になり、そのポーリングで stdout は `timeout 11` の 1 行で exit 2

### Requirement: 長い待ちのあいだは材料が更新されたときだけ判断し直す

`--resolve` 付きの長い待ちでは、エピックと位置引数の各子の issue について「材料の版」を持ち、版が処理済みの版から変わったときだけ、エピックの版が変われば全員を、子の版が変わればその子を、`wait --resolve` と同じ判断に 1 回かけなければならない（MUST）。材料の版は、その issue の本文と、投稿者が OWNER・MEMBER・COLLABORATOR のコメントのうち 1 行目が `親の判断: ` で始まらないもの（`id` と `updated_at`）から作る。`親の判断: ` で始まる親自身の投稿・ラベル・タイトルの変化だけでは判断してはならない（MUST NOT）。

#### Scenario: 子 issue が更新されたら 1 回だけ判断し、通せば返事を送る
- **WHEN** 長い待ちのあいだに子 11 の issue に主のコメントが 1 件足され、判断のコマンドが `判断: 通す` と返事を返す
- **THEN** 判断のコマンドはちょうど 1 回呼ばれ、子に返事が送られ、エピックに `親の判断: 子 #11 通した` の行が投稿される

#### Scenario: 更新が無ければ判断しない
- **WHEN** 長い待ちのあいだ、エピックと子 11 の `updated_at` が変わらない
- **THEN** 判断のコマンドは 1 回も呼ばれない

#### Scenario: 判断し直して主に上げても親を起こさない
- **WHEN** 子 11 の版が変わり、判断のコマンドが `判断: 主に上げる` を返す
- **THEN** 子 issue に `親の判断: 主に上げる` が投稿され、stdout に `stopped 11` は出ず、長い待ちが続く

### Requirement: 判断し直しは判断した版を処理済みにする

版は `updated_at` が前段の基準から変わったときだけ読む（SHALL）。待ちに入ったポーリングで `updated_at` と版を読んで前段の基準と処理済みの版にする。判断にかけるときは、判断の直前に読んだ版を判断した版とし、判断のあとは処理済みの版をその判断した版に、前段の基準をその版と同じときに読んだ `updated_at` にしなければならない（MUST）。判断のあとに読み直した値を処理済みにしてはならない（MUST NOT）。これにより、判断のあいだ（判断のコマンドが材料を読んでからモデルの応答を待つあいだ）に足された更新は次のポーリングで判断にかかり、判断が書いた親自身のコメントは判断にかからない。`updated_at` と版を読めないポーリングでは判断せず、前段の基準と処理済みの版を変えず、失敗したポーリングにも数えない。

待ちに入ったポーリングで版を読めなかった issue は、処理済みの版を「未判断」として控えなければならない（MUST）。そのとき `updated_at` だけ読めていればそれを前段の基準にし、読めなければ前段の基準も未判断にする。以後のポーリングで版を読めたら、その版を判断にかけ、判断のあとに処理済みにしなければならない（MUST）。読めた版を判断にかけずに処理済みにしてはならない（MUST NOT。読めなかったあいだの主の更新を取りこぼすため）。`updated_at` を前段の基準に控えられた issue は、それが変わらないあいだは判断しない（SHALL）。前段の基準も読めなかった issue は、材料が変わったかを確かめる手段が無いので、読めたときに 1 回判断する。

#### Scenario: 親自身の判断のコメントでは判断し直さない
- **WHEN** 子 11 の issue に主のコメントが 1 件足されて判断のコマンドが `判断: 主に上げる` を返し、子 issue に `親の判断: 主に上げる` が投稿されて `updated_at` が変わり、そのあと材料が変わらない
- **THEN** 判断のコマンドはちょうど 1 回だけ呼ばれる

#### Scenario: 判断のあいだに足された更新は次のポーリングで判断する
- **WHEN** 子 11 の issue に主のコメント A が足されて判断にかかり、判断のコマンドが材料を読んだあと応答を返す前に、子 11 の本文が主によって書き換えられる（判断のコマンドのスタブが、呼ばれたときに gh のスタブの返す本文と `updated_at` を変える）
- **THEN** 判断のコマンドは 2 回呼ばれる（コメント A の版で 1 回、書き換え後の本文の版で 1 回）。2 回目のあとに材料が変わらなければ 3 回目は呼ばれない

#### Scenario: 待ちに入ったときに読めなかったあいだの更新は読めたときに判断する
- **WHEN** 長い待ちに入るポーリングで子 11 の issue が読めず、読めないあいだに主が子 11 にコメントし、次のポーリングで読めるようになる
- **THEN** 判断のコマンドはちょうど 1 回だけ呼ばれる。そのあと材料が変わらなければ 2 回目は呼ばれない

#### Scenario: 待ちに入ったときにコメントだけ読めず材料が変わらなければ判断しない
- **WHEN** 長い待ちに入るポーリングで子 11 の本文と `updated_at` は読めてコメントだけが読めず、次のポーリングで読めるようになり、材料は変わっていない
- **THEN** 判断のコマンドは呼ばれない

### Requirement: 1 ループは W→R1→W→G の順で回る
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 → (1) W が仕様化判断の記録・分割判定・openspec CLI による change の作成（`openspec new change` と artifact の直書き）まで行い return（仕様化しない判定なら (3) へ直行。文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）なら、W は仕様の差分 1 ファイルだけを書いて return し、本体は記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があることを確かめてから (2) を飛ばして (3) へ進む）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりに BLOCKER が残れば、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の直し方の判定を通し、「決まっている」で PR トークン上限の内側なら主に聞かず次の周を回し、そうでなければ `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) 実装（`tasks.md` を TDD で。直行なら TDD。文言合わせの通し方なら W が (1) の return に書いた作業項目を TDD で）・verify（`openspec validate --strict`）まで行って return、本体が計測し、W の return の `画面確認:` の行が `要る` なら画面確認役 V を起こしてから（下の「画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす」Requirement）、(3b) `openspec archive`・PR を Draft のまま用意（無ければ Draft で作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → 文言合わせの通し方では、本体は G を起こす前に、記録先の最新の仕様化判断のコメントの `直す文:` の行が archive 済みの差分の要件名と一致することを確かめる（SHALL） → (4) G が pr-review-gate の手順 1〜5 を実行し `passed` / `failed` / `保留` / `needs-reviewer` / `needs-decider` / `needs-fix-check` / `review-incomplete` のいずれかを return。PR の Ready 化は G が手順 5 の合格処理で行い（Draft なら Ready にしてから `agent-review:passed` を付ける）、W は行ってはならない（MUST NOT）。

G が `review-incomplete` を return したとき、本体は新しい reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止めなければならない（MUST）。`needs-reviewer` が一周目照合の補足要求である場合、本体は fresh reviewer に固定 HEAD・元の三表・残差・補足済み回数を渡し、同じレビューの不足分だけを補わせなければならず（MUST）、レビューを最初からやり直させてはならない（MUST NOT）。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出／段 A だけ（昇格なし））で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら実行役を `opus` に上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く。**W を `fable` で再開してはならない**（MUST NOT。実行役の上限は `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。段 A だけなら W を据え置きで再開する（MUST）。修正後は G を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりの扱いは pr-review-gate の収束ルールと、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement に従う）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

worktree は本体が用意する（SHALL）: 本体が既に対象専用の worktree にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。W は自分で worktree を切らない（MUST NOT。セットアップは worktree プラグインの hooks が担い、`.worktreeinclude` が無いときの `/wt-setup` は本体が行う）。**W / G を `isolation: "remote"` で起こしてはならない**（MUST NOT）。強制停止に当たったサブエージェントの未コミット差分は本体が確認して commit する設計（下の「強制停止で止まった作業ツリーは本体が引き取る」Requirement）だが、`remote` 隔離は本体から見えない環境で動くため、そこで強制停止に当たると作業がそのまま失われる。

`/opsx:*` のスラッシュコマンドは、本体や主が対話で change を作る場面の道具として SKILL.md に書いてよい（MAY）が、W が実行する工程として 1 ループに書いてはならない（MUST NOT。W の種別 `dev-workflow:worker` は `Skill` を持たない）。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、(1) の W の工程に `openspec new change` があり、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ既定 2 周と、2 周目以降の周の終わりに直し方の判定を通す続行がある

#### Scenario: 文言合わせの通し方は (2) を飛ばす
- **WHEN** SKILL.md の 1 ループの (1) と (2) を読む
- **THEN** 文言合わせの通し方では W が仕様の差分 1 ファイルだけを書いて return し、本体が記録先の仕様化判断のコメントの `通し方: 文言合わせ` の行を確かめて R1 を起こさずに (3) へ進むことが書かれ、その行が無ければ (2) の R1 を通すことが書かれている

#### Scenario: 文言合わせの通し方では G を起こす前に本体が直す文の行を確かめる
- **WHEN** SKILL.md の 1 ループの (4) を読む
- **THEN** 文言合わせの通し方では、本体が G を起こす前に、記録先の最新の仕様化判断のコメントの `直す文:` の行が archive 済みの差分の要件名と一致することを確かめると書かれている

#### Scenario: (3) は 2 段に分かれて書かれている
- **WHEN** SKILL.md の 1 ループの (3) を読む
- **THEN** (3a) と (3b) が別々の return として並び、(3a) に TDD の実装と `openspec validate --strict` が、(3b) に `openspec archive`・PR・仕様宣言が入り、(3a) と (3b) の間に V を起こす分岐がある

#### Scenario: 1 ループに W が /opsx を実行する工程が無い
- **WHEN** SKILL.md の 1 ループの節を読む
- **THEN** `/opsx:ff`・`/opsx:apply`・`/opsx:verify`・`/opsx:archive` の文字列が無い

#### Scenario: (3b) は PR を Draft のまま G に渡す
- **WHEN** SKILL.md の 1 ループの (3b) と `references/roles/worker/finish.md` の (3b) を読む
- **THEN** PR を Draft のまま用意する（issue が記録先なら `gh pr create --draft`）と書かれ、W が PR を Ready に切り替える記述が無く、Ready 化は G が pr-review-gate 手順 5 で行うと書かれている

#### Scenario: W / G は remote 隔離で起こさない
- **WHEN** SKILL.md の spawn の記述を読む
- **THEN** W / G を `isolation: "remote"` で起こしてはならないと書かれている

#### Scenario: G の failed は片方だけ上げて W の再開に戻る
- **WHEN** G が failed を return する
- **THEN** SKILL.md は実装品質起因のときだけ原因分類に応じて実行役を `opus` に上げるか決める役を `dev-workflow:decider` で立てるかの一方だけを行い、仕様が曖昧・レビュアーの誤検出・段 A だけ（昇格なし）ではモデルを上げず、段 A だけなら W を据え置きで再開し、W を `fable` にはせず、G を再開して差分再レビューするよう指示している

#### Scenario: decider として起こした R1 の結果は本体が投稿する
- **WHEN** SKILL.md の (2) の記述を読む
- **THEN** R1 が `dev-workflow:decider` の場合は本体が return を同じ書式で記録先に代理投稿すると書かれている

#### Scenario: review-incomplete は reviewer を再起動しない
- **WHEN** G が補足後の残差を `review-incomplete` で return する
- **THEN** 本体は fresh reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止める

### Requirement: G は段ごとに新しく起こし、SendMessage で再開しない

`plugins/dev-workflow/skills/develop/SKILL.md` の (4) は、G を段ごとに新しく spawn することを規定しなければならない（MUST）。1 体の G は次の 4 つの段のうち 1 つだけを担当する（MUST）。

| 段 | 本体が起こす時点 | G が読むファイル（`skills/pr-review-gate/` から） | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー（failed の `次の段: 前提確認と重さ判定`）、保留の解除が `次の段: 前提確認と重さ判定` を返したとき、CI の見張りで `ready` になったあとの取り直し | `stages/prepare.md`（W の修正後の再レビューのときは加えて `stages/triage.md` の収束ルールの節と「W の修正後の再レビュー」の入力） | `needs-reviewer` / 保留 / `重複で降りた` |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定・直し方の判定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | `stages/triage.md` | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `needs-fix-check` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき、引き継ぎの判定を受け取ったとき（合格処理の G が `needs-carryover-judge` を返したあと） | `declarations.md` と `stages/pass.md`（前の HEAD の許容があるとき・保留を返すとき・`needs-carryover-judge` を返すときは加えて `stages/hold.md`） | passed / 保留 / `needs-carryover-judge` |
| 保留の解除 | 主の回答が届いたとき | `stages/hold.md`（切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節） | 復帰手順の表どおりに `次の段へ`（`次の段:` は合格処理か前提確認と重さ判定） / failed / needs-decider / 保留 |

本体は G の起動指示に `段: <段の名前>` の 1 行を書かなければならない（MUST）。`skills/develop/SKILL.md` の (4)（`(4) G を` で始まる行から、その行を含むコードブロックの閉じ ``` の行まで）と `skills/develop/references/roles/gate-runner.md` は、`SendMessage` の語と `G を再開` の文字列を持ってはならない（MUST NOT）。SKILL.md の (4) の「G の起動・再開・手渡しの指示」「G を再開か手渡しで起こして」も段ごとの起動の言い方に書き換える（MUST）。G への SendMessage は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の停止の指示だけに残し、その規則は decision-criteria.md にだけ書く（MUST）。`gate-runner.md` の「時点ごとに読むファイル」の表は、上の段の表に揃えなければならない（MUST）。

保留の解除の G は、復帰手順の表が別の段の作業に進むと示したとき、その作業を自分で行ってはならず（MUST NOT）、Status `次の段へ` と `次の段:` で返さなければならない（MUST）。許容したとき・切り出して残りが無いときは `次の段: 合格処理`、許容せず代替案で手順 2 からやり直すときは `agent-review:failed` に付け替えて failed（`次の段: 前提確認と重さ判定`）で返す（MUST）。`次の段へ` の `次の段: 前提確認と重さ判定` は、W の修正が要らないときだけに使う。

W の修正後の再レビューで起こされた前提確認と重さ判定の G は、前の周の指摘を仕分けコメントから読み、`stages/triage.md` の収束ルールどおり差分限定か全体レビューかを自分で判定し、全体レビューにしたときは 2 つの行数を PR コメントに記録しなければならない（MUST）。

保留の解除のあとで起こされた合格処理の G（前の Gate Result が `段: 保留の解除`）は、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば、宣言を出し直してはならず（MUST NOT）、手順 5 の真正性確認から入らなければならない（MUST）。そのコメントが無ければ（切り出しの確認を解除した場合）、`declarations.md` の手順 3 から入らなければならない（MUST）。照合と振り分けのあとの合格処理は、前の Gate Result の `段: 照合と振り分け` で見分ける（MUST。`次の段: 合格処理` は保留の解除の Gate Result にもあるため入口の判別に使わない）。許容済みの PR で HEAD が動いていたときの許容の引き継ぎ（手順 3-c）は、合格処理の G が宣言の前に `stages/hold.md` を読んで試す（MUST）。引き継ぎの判定を受けて起こされた合格処理の G（前の Gate Result が `段: 合格処理`・Status `needs-carryover-judge`）は、`declarations.md` の手順 3 から入り直し、3-c で PR の判定の記録を読まなければならない（MUST）。

この要件は、develop の本体がレビュアーを起こす adapter 経路（起動指示が `レビュー経路: adapter`）に掛かる。従来経路の G はレビューを自分の起動の中で起こすので、手順 1〜5 と保留までを 1 体で続けてよい（MAY）。そのときの Gate Result は `段: 一括（従来経路）`、`次の段: なし` と書く（MUST）。

#### Scenario: SendMessage による G の再開の記述が無い

- **WHEN** `plugins/dev-workflow/tests/` の develop の役割の bats が `skills/develop/SKILL.md` の (4) と `gate-runner.md` を検査する
- **THEN** 段ごとに新しい G を起こす記述と `段:` の行の指示があり、SKILL.md の (4) の範囲と gate-runner.md の全体に `SendMessage` と `G を再開` の文字列が無い

#### Scenario: 従来経路の G

- **WHEN** develop の本体以外の呼び出し元が `レビュー経路: 従来` で G を起こす
- **THEN** G は手順 1〜5 と保留までを 1 体で続けてよく、Gate Result に `段: 一括（従来経路）` と `次の段: なし` を書く

#### Scenario: 代替案への作り直し

- **WHEN** 主が許容せず、代替案で手順 2 からやり直すと答える
- **THEN** 保留の解除の G は `agent-review:failed` に付け替えて failed（`次の段: 前提確認と重さ判定`）で返し、次の前提確認と重さ判定の G は W の修正後の再レビューとして `周回:` を 1 増やす

#### Scenario: 保留の解除のあとの合格処理

- **WHEN** 保留の解除の G が主の許容を受けて `次の段へ`・`次の段: 合格処理` で返し、本体が合格処理の G を起こす
- **THEN** 合格処理の G は前の Gate Result の `段: 保留の解除` を見て、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば宣言を出し直さず手順 5 の真正性確認から入る

#### Scenario: 切り出しの確認を解除したあとの合格処理

- **WHEN** 照合と振り分けの G が切り出すかを主に聞く保留を返し、主が「切り出す」と答えて保留の解除の G が `次の段: 合格処理` で返す
- **THEN** 今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントが無いので、合格処理の G は `declarations.md` の手順 3 から入る

#### Scenario: 保留の解除の G が切り出しの確認の回答で追加に読むもの

- **WHEN** `gate-runner.md` の「時点ごとに読むファイル」の表の保留の解除の行を読む
- **THEN** 切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節を読むことが書かれている

#### Scenario: CI の見張りのあとの取り直し

- **WHEN** CI の見張りが `ready` になり、本体がゲートを取り直す
- **THEN** 本体は前提確認と重さ判定の G を新しく起こし、前の G を再開しない

#### Scenario: 段の表に needs-fix-check がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 照合と振り分けの行の起こす時点に「直し方の判定を受け取ったとき」があり、返しうる Status に `needs-fix-check` がある

#### Scenario: 段の表に needs-carryover-judge がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 合格処理の行の起こす時点に「引き継ぎの判定を受け取ったとき」があり、返しうる Status に `needs-carryover-judge` がある

#### Scenario: 引き継ぎの判定のあとの合格処理

- **WHEN** 合格処理の G が `needs-carryover-judge` で返し、本体が判定の記録を投稿して合格処理の G を新しく起こす
- **THEN** 新しい合格処理の G は前の Gate Result の `段: 合格処理`・Status `needs-carryover-judge` を見て `declarations.md` の手順 3 から入り直し、3-c で判定の記録を読む

