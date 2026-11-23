# Spec Delta

## MODIFIED Requirements

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
`skills/develop/references/epic.md` と入口から場面ごとに読む参照先は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。

**回し方（経路の決め方）**: interactive の本体は子の依存グラフを読み、blocked されていない子の番号を `plugins/dev-workflow/scripts/epic-dispatch.sh route` に渡して経路を決める（MUST）。`route` が `orca` か `tmux` を返したとき（Orca 管理のワークツリーにいる、または tmux の中にいる）は、その起動部品で子を別のセッションとして起こす **別セッション方式**、`subagent` を返したときは **サブエージェント方式**で進める（MUST）。別セッション方式とサブエージェント方式は二本立てではなく、子を起こす手段を起動部品として差し替える一本の手順で書く（MUST。共通の手順に、部品ごとに違う点だけを部品ごとの欄に書く）。経路は `/develop <エピック番号>` の最初の開始時に 1 回決め、途中で変えてはならず（MUST NOT）、決めた経路をエピックに `回し方:` で始まる 1 行コメントで残す（MUST）。別セッションで同じエピックを再開したときは、`回し方:` で始まる最新のコメントを読んで経路を引き継ぎ、`route` をやり直してはならない（MUST NOT）。最新の `回し方:` が `Orca` か `tmux` のときは、本体が `epic-dispatch.sh launch` と `adopt` に環境変数 `EPIC_DISPATCH_LAUNCHER=<そのコメントの部品名（小文字の orca か tmux）>` を付けて呼ばなければならない（MUST。付けないと部品を今の環境から選び直し、前のセッションの記録の子と別の部品で新しい子が起動しうる）。その部品が今の環境で使えず `launch`・`adopt` が exit 1 で終わったら、別の部品にもサブエージェント方式にも振り替えず、stderr を添えて主に報告して止まる（MUST。部品の違う子の混在を作らない）。`reply`・`notify-closed`・`reap`・`wait --resolve` は記録の `launcher` で部品が決まるので、再開で環境が変わっても部品名を渡さない。unmanned（`--unmanned`）では `route` を呼ばず、サブエージェント方式で進める（MUST。背景で待って起こされる動きが 1 サイクル 1 仕事と合わないため）。channel でも `route` を呼ばず、サブエージェント方式で進め、エピックに `回し方: サブエージェント（channel モード）` を残す（MUST）。channel で再開したエピックの最新の `回し方:` が別セッション方式（Orca・tmux）なら、`launch` もサブエージェント方式も使わず、その旨をチャンネルで主に報告して止まる（MUST。channel は別セッション方式を引き継がない）。channel の本体は、develop の手順のために別の Claude Code セッション（Orca・tmux など）を起こしてはならない（MUST NOT。別に起こしたセッションには印 `DEV_WORKFLOW_UNATTENDED` が届かず、その画面を誰も見ていないので、子が主の返事待ちで止まっても誰も気づかない）。develop の外で住人が別のセッションを起こすときの印の渡し方は、この要件の範囲に入れない（#1123）。

**回し方（別セッション方式）**: 本体は `epic-dispatch.sh launch` で子ごとに起動部品（Orca か tmux）の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。再開時も、依存が解けた open の子を、最新の `回し方:` の部品名を付けた `launch` に渡し（上の段落のとおり）、起動済みの子は `launch` の `skipped` で見分ける（同じ子を二重に起動しない）。本体は `launch` が `launched` / `skipped` を出した子を動いている子とし、`epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める。`closed` なら閉じた子ごとに `state_reason` を読み、`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントして依存グラフを読み直し、解けた子を件数にかかわらず `launch` する。`completed` 以外ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子を起動してはならず（MUST NOT）、ユーザーに報告する。そのあと残りの動いている子で再び `wait` する。`timeout` なら、子 issue もエピックも読まず、主に報告もせず、直前と同じ引数の `wait` を 1 回掛け直してターンを終える（要件「親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す」）。子が記録と印を残さずに自分のタブでユーザーに質問して止まっている場合は、親が気づけないことを書く（SHALL）。`wait` の `error` と `launch` の `failed` はユーザーに報告して止まる。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子セッションのモデルは `epic-dispatch.sh launch` が起動時に起動コマンド（既定は `plugins/dev-workflow/bin/cld`）に `--model` を付けて指定し、既定は `opus` で環境変数 `EPIC_DISPATCH_MODEL` で変えられること（Claude Code の既定モデルは子に効かないこと）、コマンド部分（既定は `bin/cld` の絶対パス。ログイン zsh のシェル関数には頼らない）は環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ、Orca に設定したコマンドはハーネスから読めないので（tmux の部品はこの環境変数のコマンドをそのまま打ち込む）Orca 側のコマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変えることを書く（SHALL）。子セッションの `--dangerously-skip-permissions` は環境変数 `CLD_DEFAULT_ARGS` に入れた値で付き、`launch` と、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）が親の環境の `CLD_DEFAULT_ARGS` を子の起動コマンドの前に代入として付けて子へ渡すこと（親の環境に値が無ければ付けず、子は許可の確認画面で止まる。許可を飛ばしたければ親の環境に `CLD_DEFAULT_ARGS` を置くことが前提であること）、`epic-dispatch.sh` 自身が足すのは `--settings` と `--model` だけであること、マージを止めているのは develop と pr-review-gate の規則と hooks であることを書く（SHALL）。本体は子の PR を `gh pr merge` や merge API で直接マージしてはならない（MUST NOT）。子の PR のマージは、子セッションの中の人の承認か自動マージの処理（`.github/workflows/auto-merge.yml`）が行い、`human-merge` の付いた子の PR は、本体が要件「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」の手順で判断の印を付けたときに限って自動マージの処理がマージすることを書く（SHALL）。

**回し方（サブエージェント方式）**: 今までどおり blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと。本体が W を `isolation: "worktree"` で spawn して用意し、W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。

どちらの経路でも、スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった記録先の範囲外の新しい問題は、その子の中では直さず、段 B・段 C・段 D・段 E の問いで振り分ける（MUST）。エピックの子にできるのは段 C で完了条件に効くとした問題だけとする（MUST）。効かない問題は段 D・段 E に進め、既存 issue への参考コメント・エピックの外の新しい issue・捨てる、のいずれかにし、親の注意書きが新しい子 issue を指定していてもエピックの子にしてはならない（MUST NOT）。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

この要件の入力は、`/develop <エピック番号>` で渡される記録先の issue、`scripts/epic-dispatch.sh route` の出力（`orca`・`tmux`・`subagent`・`nested`）、エピックの `回し方:` で始まるコメント、`wait` の出力の 1 行（`closed`・`done`・`timeout`・`stopped`・`unrecorded`・`error`）、`launch` の出力（`launched`・`skipped`・`failed`・`deferred`）である。拾いたい誤りは、`route` や最新の `回し方:` を読まずに経路を選び直すこと、`nested` を受けたのにエピックを展開すること、出力の 1 行を取り違えて待ちを終えたり子を起こしたりすること、子が全部マージされただけでエピックを閉じることである。次は通してよく、この要件では止めない: `回し方:` のコメントが無い新しいエピックで `route` から経路を決めること／`timeout` で起こされたとき何もせず再び待つこと／子が記録を残さずに自分のタブで質問して止まったとき、親が検知できないこと（手順書にその旨が書かれている）。手順書の読み方の揺れ（すり抜ける入力）が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

回し方の本文は `references/epic-loop.md`（通常の進行）と `references/epic-subagent.md`（サブエージェント方式）、停止の解決は `references/epic-stop.md` に置く（MUST）。入口に親の起動・片付け・見張りの操作本文を残してはならない（MUST NOT）。

#### Scenario: エピックの 4 節が存在する
- **WHEN** `references/epic.md` の「エピックの扱い」節を読む
- **THEN** 条件・作り方・nested・完了条件と読むものの表があり、親の通常進行は epic-loop.md、停止は epic-stop.md、委任は epic-delegation.md、マージ待ちは epic-merge-wait.md、別 repo は epic-multirepo.md、サブエージェント方式は epic-subagent.md へ案内され、完了条件に「子が全部マージされただけでは閉じない」が書かれている

#### Scenario: 子は並列に worktree 分離で起こす
- **WHEN** `references/epic-subagent.md` のサブエージェント方式と `references/epic.md` の「エピックの扱い」を読む
- **THEN** サブエージェント方式として、blocked されていない子から `isolation: "worktree"` で 1 ループを並列に起こすことが書かれ、どちらの経路でも範囲外の新しい問題は子の中で直さず振り分け、段 C で完了条件に効くものだけをエピックの子にでき、効かないものは段 D・段 E に進むことが書かれている

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

#### Scenario: 子の実装中の問題が完了条件に効かない

- **WHEN** エピックの子の実装中に範囲外の問題が見つかり、段 B ではいまの範囲で成り立つが、段 C では完了条件に効かず、段 D の候補が無く、段 E で手間に見合うと判断する
- **THEN** 本体はその子の中で直さずエピックの外の issue にし、エピックの子には足さない

### Requirement: 本体は主の側にしか無い情報が要るときだけ主に聞く

`skills/develop/SKILL.md` は節「主に聞かずに決めること」を 1 か所持ち、本体・W・G が主に聞くのは、主の側にしか無い情報（好み・事業判断・許容度）、主の手でしかできない操作（パスワード・MFA・CAPTCHA のように、エージェントの手では通せないもの。ログイン済みのブラウザで押せる操作（OAuth の認可ボタン・チャットの板の作成など）は入らない）、規則が主の承認を求める操作（`rules/destructive-git-guard.md` の一覧・マージ・聖域）のどれかが要るときだけであると書かなければならない（MUST）。節は次の 4 つの型の決め方を持たなければならない（MUST）。

- **自分側の誤りの後始末**: 本体・W・G・レビュアーが記録先の範囲の外に誤って入れた変更（実ホームの設定ファイルへの書き足しなど）は、控え・git の履歴・自分のツール呼び出しの記録のどれかと今の状態を比べて、差分が自分側の入れた分だけで戻し先が一意に決まるなら、主に聞かずに戻す（MUST）。戻す前に今の状態の控えを取り（MUST）、戻したあと記録先に何を・どこから戻したか・控えの場所を事後報告する（MUST）。差分が自分側の分だけと確かめられないときは主に聞く（MUST）。git の破壊的操作（`rules/destructive-git-guard.md` の一覧）はこの型に入らず、従来どおり事前承認とする（MUST）。聖域（CLAUDE.md・hooks・権限設定）への変更を戻す操作も、差分が一意でもこの型に入らず、従来どおり無条件で人間承認とする（MUST）。`rules/destructive-git-guard.md` は変えない（MUST NOT）
- **範囲外の問題の起票**: 本体が作業中に見つけた記録先の範囲外の問題（レビュー指摘ではないもの。G の振り分けを経た指摘は G の振り分けのまま扱う）は、本体が次の手順で行き先（捨てる・既存 issue に参考として入れる・新しい issue）を決め、起票したら URL を事後報告する（MUST）。`skills/pr-review-gate/stages/triage-nonblocking.md`（段 C は `skills/pr-review-gate/stages/triage-epic.md`）は PR 番号・PR コメント・G の手順 3 を前提にしているので丸ごとは当てず、段 B・段 D・段 E の問い（エピックの子の記録先なら段 C の問いも）と段 B の表だけを借りる（MUST）。
  - 候補探し: 段 B を通った問題が 1 件以上あれば、問題がファイルを指すなら `plugins/dev-workflow/scripts/review-issue-candidates.sh --repo $R --exclude <記録先の番号> [--epic <エピック番号>] <パス>...` を、ファイルを指さないなら `gh issue list --repo $R --state open --search "<問題を表す語>"` を、それぞれ 1 回だけ走らせる（MUST。打ち切りの再実行だけ例外）。記録先の番号は記録先の issue、記録先が Draft PR ならその PR の番号とする。エピックに属するときは、`--exclude` にエピックの番号も渡す（MUST。エピック自身が `other` の候補に返るのを防ぐ）。出力に `(15 件で打ち切り。ほかにも一致あり)` が出たパスがあり、エピックに属するときは、そのパスだけに `--epic <エピック番号> --children-only` を付けて走らせ直し、子の候補を足す（MUST。打ち切られたパスごとに 1 回を超えない）。再実行を含め、終了コードが 0 でないときの扱いは `stages/triage-nonblocking.md` の候補探しの段落に従う（MUST）。再試行後の終了コードは記録先の `範囲外の問題の振り分け` コメントに書き、既存 issue への相乗りをせずに段 E へ進む（MUST）
  - 判断結果の記録: 記録先（issue、または Draft PR）に 1 行目が `範囲外の問題の振り分け` ちょうどのコメントを 1 件置き、問題ごとに、問題の要約・当てた段・行き先（issue にした・コメントで入れたならその URL、捨てたなら理由の 1 行）を書く（MUST）
  - 段 B の確認待ち: 条件がいつ成り立つかを本体が記録先・エピックの本文・受け入れ条件・コード・本文の節 `## 条件の答え` から決められないときは、起票の可否ではなく条件についての問いを主に聞く（MUST）。同じコメントにその問題を `条件の確認待ち` として質問文とともに残し、`needs-approval` を付けず、作業を止めない（MUST）。答えは 1 行にして記録先（エピックの子ならエピック）の本文の節 `## 条件の答え` に足し（節が無ければ作る）、その問題を段 B から当て直す（MUST）
  - エピックの注意書き: 記録先にエピックの親（OWNER）からの注意書きがあり、新しい問題の置き場所を指定している（例: エピック #1038 の「新しい問題はエピックに新しい子 issue として切る」）ときも、まず段 C の完了条件に効くかの境界を守る（MUST）。効かない問題の行き先は段 D・段 E で決め、注意書きを理由にエピックの子にしてはならない（MUST NOT）。完了条件に効く問題については、段 C の「既存の子 issue の受け入れ条件に足す」より、新しい子 issue を指定した注意書きを優先する（MUST）

  起票の可否を主に聞いてはならない（MUST NOT）。G の振り分けの結果を主への報告にまとめるときに、行き先を「オーナーが決める」に書き換えてはならない（MUST NOT）。起票によって配布や後続の作業の順番を変えるかは主に聞いてよいが、起票はその前に済ませる（MUST）
- **小さな実装の選択**: どれを選んでも受け入れ条件と利用者に見える振る舞いが変わらない選択肢は、その工程の担い手が選び、選んだ理由を記録先に残す（MUST）。レビューの 2 周目以降の周の終わりに残った指摘の直し方は「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement に従う（MUST）
- **閉じる操作**: 受け入れ条件を満たした記録先を閉じる操作は「develop のループの終わりは片付けを聞かず、ワークスペースに印を付ける」Requirement に従い、主に渡さない（MUST NOT）

この節はエピック #1038 の兄弟が直す節（「保留で止まるときの引き継ぎ」「エピックの扱い」）とは別の節として置く（MUST）。節は、自分側の誤りの後始末と範囲外の問題の起票のそれぞれに、次の守備範囲の段落を持たなければならない（MUST）。

自分側の誤りの後始末の守備範囲は、本体・W・G・レビュアーのツール呼び出しが記録先の範囲の外（実ホームの設定ファイル・別のリポジトリなど）に書いた変更である。拾いたい誤りは、戻す内容が差分から一意に決まるのに、戻してよいか・いつ戻すかを主に聞いて止まることで、これは主に聞かずに戻す。通してよい例は、控えの `.bak` との差分が自分側の書き足した 1 件だけで、その 1 件を消すこと（claude-harness #977 の `~/.claude/accounts.json` の `z`）。主の変更と区別できない差分・git の破壊的操作・聖域への変更を戻す操作は主に上げる。戻した内容が誤っていたことは防がない（戻す前に取った控えから取り消せる）。

範囲外の問題の起票の守備範囲は、本体が作業中（リハーサル・調査・実装の確認など）に見つけた、レビュー指摘ではない記録先の範囲外の問題である。拾いたい誤りは、起票してよいか・誰が起票するかを主に聞いて止まることと、G の振り分けの結果を「オーナーが決める」に書き換えて主に渡すことで、これらは主に聞かずに起票か捨てるかを決める。通してよい例は、リハーサルで詰まった操作を新しい issue にして URL を事後報告すること（flatmate #1104）。主に上げるのは、段 B の条件が本体に決められないときの条件についての問いと、起票によって配布や後続の作業の順番を変えるかの判断だけである。行き先の選び方が外れること（捨てた問題が後で効くなど）は防がない（記録先のコメントに理由が残るので、後から拾い直せる）。

節は、ログイン済みのブラウザで押せる操作を主の手でしかできない操作に数えないと書き（MUST）、その操作が主の名義で外へ公開・送信する・課金する・外部のアプリやサービスに権限を渡す（OAuth の認可を含む）・取り消せないもののときは、手が要るからではなく規則が主の承認を求める操作として聞くと書き分けなければならない（MUST）。例に OAuth・ログイン・ダッシュボードの操作を、主の手でしかできない操作として挙げてはならない（MUST NOT）。

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
- **WHEN** エピックの子の記録先に、親から「新しい問題は新しい子 issue として切る」の注意書きがあり、範囲外の問題が段 C で完了条件に効くと判断され、同じエピックの既存の子 issue と同じ場所を指す
- **THEN** 本体は既存の子 issue の受け入れ条件に足さず、エピックに新しい子 issue を作る

#### Scenario: ログイン済みのブラウザで押せる操作は主の手の操作に入らない

- **WHEN** `skills/develop/SKILL.md` の節「主に聞かずに決めること」を読む
- **THEN** 主の手でしかできない操作の例がパスワード・MFA・CAPTCHA で、OAuth・ログイン・ダッシュボードの操作が例に無く、ログイン済みのブラウザで押せる操作は入らないことと、主の名義で外へ公開・送信する・課金する・外部のアプリやサービスに権限を渡す（OAuth の認可を含む）・取り消せない操作は、同じ文で、規則が主の承認を求める操作として聞くことが書かれている

#### Scenario: 注意書きがあっても完了条件に効かない問題は子にしない

- **WHEN** 親の注意書きが「新しい問題は新しい子 issue」と指定していても、範囲外の問題が段 C で完了条件に効かず、段 D の候補が無く、段 E で手間に見合うと判断する
- **THEN** 本体はエピックの外の issue を作り、注意書きを理由にエピックの子には足さず、記録先の振り分けコメントに段と行き先の URL を残す

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

- `launch` が `--note` を子 issue に `親エピックからの注意書き:` で始まるコメントとして残すこと。子のセッションの本体（起動し直したセッションを含む）は、記録先にこの行で始まるコメントがあれば、投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のどれかであるものに従い、W・R1・G に渡す関連コメントに必ず含めること。ただし、新しい問題の置き場所の指定には段 C の完了条件に効くかの境界を優先し、効かない問題は段 D・段 E で行き先を決め、注意書きを理由にエピックの子にしてはならない（MUST NOT）。この例外があっても、対象投稿者の注意書きのコメント自体は W・R1・G に引き継ぐこと。それ以外の投稿者のものと `author_association` を読めなかったものには従わず、W・R1・G にも渡さず、コメントの URL と投稿者をユーザーに報告すること（issue には誰でもコメントでき、子のセッションは確認画面なしで動くため）。この投稿者の検査は注意書きのコメントだけに適用し、記録先のほかのコメントの読み方は変えない
- `launch` の stderr に `note not posted to #<N>` があれば、本体がその子 issue に stderr に出た本文を投稿すること
- 子であることは、`launch` が端末に付けた環境変数と、子のワークツリーの親子関係のどちらからでも判定されるので、起動し直したセッションでも `route` が `nested` を返すこと
- `nested` を受けたセッションは、親エピックの番号を `route` の stderr の `parent epic: #<N>` から読むこと
- `launch` の拒否は stderr の `child epics are not expanded here` で見分け、`nested` と同じに扱うこと
- `route` の stderr に `parent epic:` があり、そのセッションに `EPIC_DISPATCH_PARENT_EPIC` が無いとき（ワークツリーの親子関係で `nested` になったとき）は、同じワークツリーで起動し直しても `nested` になるので、ユーザーには、親を持たないワークツリー（Orca の子として作られていないワークツリー）で `/develop #<自分の issue>` を起動するよう伝えること。「親ワークツリーで開き直す」とは報告しない既存の規定は変えない

この要件の守備範囲で入力として扱うのは、`launch` に渡された `--note` の文、`orca worktree current --json` の `.result.worktree.parentWorktreeId`、`orca worktree list --json` の `.result.worktrees[]` の `id` と `linkedIssue` である。2 つの JSON は 2026-10-08 の実機（Orca 1.4.222）で確かめた形のとおりと信じ、形が変わったときの検知は範囲外とする。拾いたい誤りは、起動し直した子のセッションが注意書きを知らずに範囲外に手を出すこと、自分を子だと知らずに孫のワークツリーやサブエージェントを作ることである。次は通してよく、この要件では止めない: `launch` 以外で、`linkedIssue` の付いたワークツリーを親にして作ったワークツリーで回すエピックは `nested` になる／一覧の一時的な失敗と `route` の 1 回が重なると子のセッションが `nested` にならない（そのとき `launch` は一覧を読めずに子を作らない）／この変更の前に `launch` された子の issue には注意書きのコメントが無い／注意書きの本文の長さや内容の一般的な妥当性は検査しない（新しい問題の置き場所には上記の段 C の境界を当てる）／親ワークツリーが一覧から消えていれば子ではない扱いになる／親ワークツリーの `linkedIssue` が後の `launch` で別のエピックに変わると、`parent epic:` はその番号になる／サブエージェント方式の隔離 worktree からの `route`・`launch` の呼び出しは想定しない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

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
- **THEN** `親エピックからの注意書き:` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のものに従い W・R1・G に渡すこと、ただし新しい問題の置き場所の指定には段 C の境界を優先し、効かない問題を子にしないこと、それ以外の投稿者のものには従わず渡さずユーザーに報告すること、起動し直したセッションでも `nested` になること、親エピックの番号を `parent epic: #` から読むこと、`child epics are not expanded here` で `launch` の拒否を見分けること、変数が無く `parent epic:` が出たときは親を持たないワークツリーで起動するよう伝えることが書かれていて、`grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` は 0 行

#### Scenario: 親が注意書きの投稿失敗に対処する
- **WHEN** `references/epic-loop.md`「通常進行の手順」手順１を読む
- **THEN** `note not posted to` のときに本体が注意書きを子 issue に投稿すると書かれている

#### Scenario: 起動し直して引き継いだ注意書きでも効かない問題は子にしない

- **WHEN** 起動し直した子のセッションで、記録先に `OWNER` が投稿した `親エピックからの注意書き:` のコメントがあり「新しい問題は新しい子 issue」と指定しているが、範囲外の問題は段 B でいまの範囲で成り立ち、段 C で完了条件に効かず、段 D の候補が無く、段 E で手間に見合う
- **THEN** 本体は投稿者を検査した注意書きのコメントを W・R1・G に引き継ぐ一方、置き場所には段 C の境界を優先して外の issue を作り、エピックの子には足さず、振り分けの記録に段と URL を残す

## ADDED Requirements

### Requirement: 完了条件の節が無いエピックは子の起動前に本文に記す

`/develop <エピック番号>` の本体は、開始時にエピック本文の完了条件の節を確かめ、無ければ本文のユーザーストーリー・依頼から決めた完了条件を本文に記してから子を起動しなければならない（MUST）。本文だけでは決められないときだけ主に聞き、答えを本文に記すまでは子を起動してはならない（MUST NOT）。既存の節はこの手順で書き換えない（MUST NOT）。この手順は、両方式の親が開始時に読む `references/epic-loop.md` に置く（MUST）。

この要件の守備範囲の入力は、開始時に取得したエピック本文の依頼・ユーザーストーリー・完了条件と、不明点への主の回答である。拾う誤りは、節の欠落を放置して子を起動することと、補完で依頼に無い目的を足すことである。既存の節が「画面を使いやすくする」だけで曖昧でも、書き換えず通すことを許す。既存の条件の十分さや本文の意味の読み違いをすべて塞ぐことは完了条件にしない。

#### Scenario: 本文から完了条件を決められる

- **WHEN** develop の外で作られたエピックに完了条件の節が無く、本文の依頼とユーザーストーリーからストーリーの成立を確かめる条件を決められる
- **THEN** 本体は主に聞かずに本文へ完了条件の節を追加し、依頼に無い目的を足さず、記録を済ませてから別セッション方式でもサブエージェント方式でも子を起動する

#### Scenario: 本文だけでは完了条件を決められない

- **WHEN** エピックに完了条件の節が無く、本文を読んでも何を確かめればストーリーが成立するかを決められない
- **THEN** 本体は決められない点を主に聞き、答えから完了条件を本文に記してから子を起動する

#### Scenario: 既に完了条件の節がある

- **WHEN** 回し始めるエピックの本文に完了条件の節がある
- **THEN** 本体はその節を根拠に進め、この欠落時の手順を理由に主へ確認を増やしたり、節を書き直したりしない
