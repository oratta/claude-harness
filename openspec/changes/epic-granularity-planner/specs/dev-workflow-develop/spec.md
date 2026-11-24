## MODIFIED Requirements

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
`skills/develop/references/epic.md` と入口から場面ごとに読む参照先は次を規定しなければならない（MUST）。**条件**: 作業項目を粒度計算に通し、意味上の分離境界または消費容量、空き W 枠を考慮した結果が複数の子になるときにエピックにする。capability 数や順序依存だけでエピックにしてはならない（MUST NOT）。**作り方**: 作業項目・量・依存・境界・実効上限・空き W 枠を入力にして計算スクリプトを通し、配置可能な出力の組み方に従う（MUST）。異なる組み方を選ぶなら入力、出力、変更した所属と理由を記録先に残し、意味上の分離境界と容量は守る（MUST）。エピック issue にユーザーストーリー・完了条件・代表子の一覧と依存順・元 issue との対応表を書く。エピック自身にコードを紐づけず、PR の Closes は代表子に向ける。各子は単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。計算の入力形式と既存 issue 集約の詳細は `references/epic-granularity.md` に置く（MUST）。

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

#### Scenario: 計算結果からエピックの子を作る
- **WHEN** 洗い出した項目の計算結果が容量内の 2 group になる
- **THEN** エピックの作成手順はその 2 group に対応する代表子と依存順を作り、計算入力と出力を記録する。capability の数だけでさらに子を増やさない

## ADDED Requirements

### Requirement: 手順への組込みでは Step C が計算結果から分割を決める

Step C は作業項目と消費・境界・現在の空き W 枠を計算器に渡し、その組み方を既定にしなければならない（MUST）。受け入れ条件 1〜5 個、設計判断 1 個、単一 capability を分割の必須条件にしてはならない（MUST NOT）。個数・順序・ファイル量は項目の洗い出しと計算の材料にし、配置不能は項目の分解と再入力へ戻す（SHALL）。

#### Scenario: 個数の旧条件だけを超える
- **WHEN** 受け入れ条件が 6 個、設計判断が 2 個、複数 capability にまたがるが、計算が容量内の単一 group を返す
- **THEN** Step C は単一 change を既定とし、個数を理由に複数 change を必須としない

#### Scenario: 計算結果と違う組み方を採用する
- **WHEN** 本体が計算器と異なる所属を選ぶ
- **THEN** 記録先に元の入力と出力、採用する所属、変更理由、境界と両容量を満たす再確認を残す。理由なしに結果を飛ばさない

### Requirement: 手順への組込みでは W 枠の snapshot と起動を分ける

本体は epic-worker-slots.md の上限と使用中 W 数から現在の空きを入力しなければならない（MUST）。計算器の並列候補を起動許可とみなしてはならない（MUST NOT）。起動・再開の直前は既存の枠検査と再開優先順に従う（SHALL）。

#### Scenario: 計画後に別の W が枠を使う
- **WHEN** 空き 2 で並列候補が出た後、起動前には空きが 0 になった
- **THEN** 本体は新しい W を起動せず、既存の枠が返るまで待ち、保留からの再開を既存の優先順で処理する

### Requirement: 手順への組込みでは既存 issue を代表子へ集約する

既存 issue の作業も同じ計算に通し、group ごとに代表子を 1 本設けなければならない（MUST）。既存 issue の再利用は、group がその元 issue 1 本だけに対応し、その全項目が単一 group に収まり、他 group がその元 issue を参照しない場合に限る（MUST）。それ以外は group ごとに別々の代表子を新設し、元 issue を代表として再利用してはならない（MUST NOT）。親・代表・元 issue に対応と受け入れ条件を残し、親の直接の子と起動・監視の対象を代表に統一する（SHALL）。元 issue を代表の sub-issue にしたり、代表と重ねて起動したりしてはならない（MUST NOT）。進行中 W／worktree／未マージ PR／状態記録のある issue は自動集約しない（SHALL）。

#### Scenario: 未着手の既存 issue 二つを一つにまとめる
- **WHEN** 既存 A/B の全項目が計算後の group G に入り、どちらも未着手である
- **THEN** 代表 C を親の直接の子にし、親と C に G と A/B の対応・受け入れ条件を残し、A/B に C へのコメントを残す。A/B は親の直接の子から外し、route/launch/wait/adopt へは C だけを渡す。C は sub-issue を持たない

#### Scenario: 元 issue の全項目が単一 group に収まる
- **WHEN** 未着手の元 A の全項目が group G に収まり、G は A だけに対応し、他 group が A を参照しない
- **THEN** A を G の代表として再利用できる

#### Scenario: 同じ元 issue が二つの group に分かれる
- **WHEN** 元 A の項目だけを容量で二つの group に分ける
- **THEN** 各 group に別々の代表 C/D を新設し、どちらにも A を再利用しない。親の直接の子と route/launch/wait/adopt の対象は C/D だけにし、対応表で A→C/D を保持する。各 PR の Closes はそれぞれ C または D だけに向ける。C だけがマージされても A を閉じず、A の全受け入れ条件が満たされるまで精算待ちとする

#### Scenario: 依存を代表に写す
- **WHEN** 既存 A/B を C にまとめ、A に未完了の外部前提 X、A/B の間に内部依存、A に依存する外部後続 Y がある
- **THEN** C に X の依存を写し、内部依存を除き、Y→A は A の精算まで残す。付替えと依存の確認が終わるまで C を起動しない

#### Scenario: 着手済みの既存 issue がある
- **WHEN** まとめる候補 A に未マージ PR または状態記録がある
- **THEN** A は自動で代表へ移さず、待つか対象から除外した理由を親に記録する

### Requirement: 手順への組込みでは代表一件を親の完了一件として数える

PR の Closes は代表子だけに向け、マージ後に対応表で元 issue の全条件を確認し、証拠と PR URL を残して completed で閉じなければならない（MUST）。親は代表ごとに一度だけ進捗を数え、元 issue の閉鎖を加算してはならない（MUST NOT）。未精算の元 issue・未マージ PR がある間、または親の実機確認の証拠がない間は親を閉じてはならない（MUST NOT）。

#### Scenario: 代表一件で元二件を完了する
- **WHEN** C の PR がマージされ、対応する元 A/B の全条件の証拠がそろう
- **THEN** A/B を証拠と PR URL 付きで completed として閉じ、親の完了増分は C の 1 件だけになる。親はストーリー成立の実機確認も行う

#### Scenario: 元 issue の閉鎖に失敗する
- **WHEN** 代表 C の closed/done を受け取ったが、元 B の閉鎖 API が失敗した
- **THEN** 親は C の進捗を重複加算せず、B を未精算として残し、再開時に閉鎖を再試行する。精算と実機確認が完了するまで親を閉じない
