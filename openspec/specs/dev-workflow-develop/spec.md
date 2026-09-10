# dev-workflow-develop Specification

## Purpose
TBD - created by archiving change dev-workflow-develop-orchestrator. Update Purpose after archive.
## Requirements
### Requirement: develop スキルは入口を問わず発火する
`plugins/dev-workflow/skills/develop/SKILL.md` は、ソースコード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変える作業を、依頼の入口（GitHub issue・会話・cron・エピックの子）を問わずこのスキルを通すことを「いつ使うか」として規定しなければならない（MUST）。例外は「読むだけ・回答だけ・生成物を出すだけ」の作業に限る（SHALL）。frontmatter の `description` は、旧 `github-issue` の発火語（issue 番号・issue URL・「この issue 対応して」等の自然文）を含まなければならない（MUST）。`skills/github-issue/` は存在してはならない（MUST NOT）。

#### Scenario: いつ使うかと例外が書かれている
- **WHEN** `skills/develop/SKILL.md` の「いつ使うか」節を読む
- **THEN** コード・スキル・コマンド・規範文書を変える作業は入口を問わず通すこと、例外が「読むだけ・回答だけ・生成物を出すだけ」であることが書かれている

#### Scenario: 旧 github-issue の発火語を吸収している
- **WHEN** `skills/develop/SKILL.md` の frontmatter `description` を読む
- **THEN** issue 番号・URL・「この issue 対応して」の発火語が含まれ、`skills/github-issue/SKILL.md` は存在しない

### Requirement: 本体はオーケストレータ専任でコードもレビューも書かない
SKILL.md は本体（メインセッション）の役割を「役割 W / R1 / G を `model` 明示で spawn し、return の要約と記録先（issue または Draft PR）のコメント・ラベルだけを見て次に誰を起こすかを決める」と規定しなければならない（MUST）。禁止事項として、本体が Edit でコードを書かないこと、本体がレビュー（仕様レビュー・PR レビュー）を代行しないことを明記しなければならない（MUST）。並列可能な役割は並列に起こしてよい（MAY）。**ただし、1 つの作業ディレクトリ（worktree）で同時に動く同一役割のサブエージェントは常に 1 人でなければならない（MUST）。並列に起こしてよいのは、別々の worktree を持つ役割（エピックの子どうし、独立した change の W どうし）に限る（SHALL）。** 複数 change に割れた場合の change ごとの W 並列も、change ごとに worktree を分けて起こすものとする（MUST）。W は名前付きで spawn し、再開は SendMessage でコンテキストを引き継ぐ（SHALL）。別コンテキストを要する工程はすべて本体が起こし、W が孫を呼ぶ必要がある工程を設けてはならない（MUST NOT）。

#### Scenario: 禁止事項が明記されている
- **WHEN** SKILL.md の「本体の役割」節を読む
- **THEN** 本体が Edit でコードを書かないこと、レビューを代行しないこと、役割を `model` 明示で spawn することが書かれている

#### Scenario: W の再開は SendMessage
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** W を名前付きで spawn し SendMessage で再開すること、W が孫を呼ぶ工程が無いことが書かれている

#### Scenario: 同一 worktree に同一役割を二重に spawn しない
- **WHEN** ある worktree で W が稼働中である（手渡し待ち・停止指示待ちを含む）
- **THEN** 本体はその worktree に対して別の W をもう 1 人 spawn しない（手渡し・再開のいずれであっても。いつ手渡してよいかは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本）

#### Scenario: 別 worktree の並列はこの制約の対象外
- **GIVEN** エピックの子どうし、または独立した change の W どうしが、それぞれ別の worktree で動いている
- **THEN** 本体はこれらを並列に起こしてよく、同一 worktree 制約には抵触しない

### Requirement: 入口 0 は記録先を決める
SKILL.md は 1 ループの最初の工程「入口 0」として記録先の決め方を規定しなければならない（MUST）: issue があれば（番号・URL・自然文マッチ）それを記録先にする。無ければ issue を切らず、W が worktree を用意された直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする。この Draft PR は仕様化判断を記録する**前**に存在していなければならない（MUST。記録先が無い状態で判定を先に進めない）。Draft PR を記録先にする場合、受け入れ条件は PR 本文（位置づけ・動作確認ポイント）に書かなければならず（MUST）、受け入れ条件自体を省いてはならない（MUST NOT）。記録先を PR にした場合、PR 本文に `Closes` / `Fixes` / `Refs #N` の issue 参照を書いてはならない（MUST NOT。書くと pr-review-gate の照合先がその issue に移る。エピックの子は子 issue が記録先なので `Closes #子` を書く）。仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（SHALL）。仕様宣言（`対象 HEAD:` 付き。書式の正本は pr-review-gate スキル手順 3-b）は記録先が issue か Draft PR かにかかわらず常に **PR コメント**に置き、記録先が issue のときに issue コメントへ置いてはならない（MUST NOT。pr-review-gate 手順 5 は PR のコメントで 3 見出しを照合し、`対象 HEAD:` 規約は PR の HEAD に紐づくため）。SKILL.md はこの分離（記録先に置くもの＝仕様化判断・仕様レビュー結果、PR コメントに置くもの＝仕様宣言）を入口 0 に明記しなければならない（MUST）。issue を切るのは追跡・キュー・議論が要るとき（エピック／無人キュー／判断を残す議論）に限ることを明記する（SHALL）。

#### Scenario: issue が無い依頼は Draft PR が記録先になる
- **WHEN** 会話で依頼された変更に対応する issue が無い
- **THEN** SKILL.md は issue を切らず、worktree 直後に空 commit → push → `gh pr create --draft` で Draft PR を開いてから仕様化判断を記録し、受け入れ条件を PR 本文に書き、PR 本文に issue 参照を書かないよう指示している

#### Scenario: issue を切る条件が限定されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** issue を切る条件がエピック・無人キュー・判断を残す議論の 3 つに限定されている

#### Scenario: 仕様宣言の投稿先は記録先と分離されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** 仕様化判断・仕様レビュー結果は記録先のコメントに置くと書かれ、仕様宣言は記録先が issue でも PR コメントに置くと書かれており、記録先のコメントに置くものの列挙に仕様宣言が含まれていない

### Requirement: 1 ループは W→R1→W→G の順で回る
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 → (1) W が仕様化判断の記録・分割判定・`/opsx:ff` まで行い return（仕様化しない判定なら (3) へ直行）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（2 周キャップ。超えたら `needs-approval`）→ (3) W を再開して apply（TDD）・verify・archive・PR を Ready に（または作成）・仕様宣言まで書いて return → (4) G が pr-review-gate の手順 1〜5 を実行し passed / failed / 保留を return。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら実行役を `opus` に上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く。**W を `fable` で再開してはならない**（MUST NOT。実行役の上限は `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。修正後は G を再開して差分再レビュー（2 周）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

worktree は本体が用意する（SHALL）: 本体が既に対象専用の worktree にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。W は自分で worktree を切らない（MUST NOT。セットアップは worktree プラグインの hooks が担う）。**W / G を `isolation: "remote"` で起こしてはならない**（MUST NOT）。強制停止に当たったサブエージェントの未コミット差分は本体が確認して commit する設計（下の「強制停止で止まった作業ツリーは本体が引き取る」Requirement）だが、`remote` 隔離は本体から見えない環境で動くため、そこで強制停止に当たると作業がそのまま失われる。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ 2 周キャップがある

#### Scenario: W / G は remote 隔離で起こさない
- **WHEN** SKILL.md の spawn の記述を読む
- **THEN** W / G を `isolation: "remote"` で起こしてはならないと書かれている

#### Scenario: G の failed は片方だけ上げて W の再開に戻る
- **WHEN** G が failed を return する
- **THEN** SKILL.md は実装品質起因のときだけ原因分類に応じて実行役を `opus` に上げるか決める役を `dev-workflow:decider` で立てるかの一方だけを行い、仕様が曖昧・レビュアーの誤検出ではモデルを上げず、W を `fable` にはせず、G を再開して差分再レビューするよう指示している

#### Scenario: decider として起こした R1 の結果は本体が投稿する
- **WHEN** SKILL.md の (2) の記述を読む
- **THEN** R1 が `dev-workflow:decider` の場合は本体が return を同じ書式で記録先に代理投稿すると書かれている

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker.md`（W）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）・仕様レビュー結果の記録書式・「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。事前分類表の「1 周目」列は**実行役（W）の上限を `opus` とし、`fable` 行を持ってはならない**（MUST NOT。4 分類のいずれに当たっても W は `opus` 止まりで、聖域パスの `opus` は据え置き）。表には、読んで判断する役（R1・G が要求するレビュアー）が `fable` 相当の分類に当たるときは `subagent_type: dev-workflow:decider` で spawn し、`general-purpose` に `model: fable` を付けないことを明記しなければならない（MUST）。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担うことを書く（SHALL）。`worker.md` の return には「指示のどこまでやって、どこで何が起きたか」を含める義務を書かなければならない（MUST。決める役の入力契約になるため）。

`spec-reviewer.md` は 5 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合）と 2 周キャップを含む（MUST）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

`worker.md`・`spec-reviewer.md`・`gate-runner.md` の 3 つはいずれも、長時間処理の完了通知を待つためにターンを終えてはならない旨を明記しなければならない（MUST）。待ち方の詳細の正本は `plugins/dev-workflow/references/subagent-waiting.md` とし、各指示書はそこを参照する（SHALL）。`spec-reviewer.md` の 1 行は、decider 経路で spawn される R1 が `Bash` を持たず待ちループ自体を実行できないため、「長い処理の完了を待つ目的でターンを終えない（decider 経路の R1 は待ちを伴う作業を持たない）」の形で書く（SHALL。読んだ R1 が実行できない手順を探しに行かないようにするため）。

`gate-runner.md` は Codex の**起動**の事実（(a) `codex exec -c approval_policy=never -c model_reasoning_effort=medium` を `run_in_background` で起動する経路と、(b) `codex-companion.mjs` に `task … --effort medium` を投げる経路。companion の path-discovery を含む）を持ち、**完了の確認方法は正本 `plugins/dev-workflow/references/subagent-waiting.md` に委ねなければならない（MUST）**。完了マーカーの雛形・具体の待ち値・総待ちの上限を `gate-runner.md` に再掲してはならない（MUST NOT。2026-09-09 のレビューで、再掲した companion の判定方法が事実と食い違ったまま残っていたため）。「出力ファイルを読め」だけで待ち方を書かない記述を残してはならない（MUST NOT）。`gate-runner.md` に残す待ち関連の記述は、完了通知に頼ってターンを終えない禁止・正本への参照・上限到達時の G 固有の分岐（待ちをやめて `needs-reviewer` を return し、根拠に「Codex タイムアウト」と実際に待った時間を書く）に限る（SHALL）。

#### Scenario: worker.md に記録書式と事前分類表がある
- **WHEN** `references/roles/worker.md` を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式、`gh` で記録先にコメントする手順、4 分類の事前分類表（「1 周目」列がすべて `opus` で `fable` 行が無い）、レビュアーの fable は `dev-workflow:decider` 経由であること、return に「指示のどこまでやって、どこで何が起きたか」を書く義務が書かれている

#### Scenario: spec-reviewer.md に 5 観点と 2 周キャップがある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 5 観点がすべて列挙され、2 周で確定し 3 周目の例外を設けないことが書かれている

#### Scenario: gate-runner.md は pr-review-gate を手順書として参照する
- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** pr-review-gate スキルを読んで手順 1〜5 を実行すること、Codex は `codex exec` / `codex-companion.mjs` を Bash で呼ぶこと、Codex が使えないときは `needs-reviewer`（判定・HEAD SHA・推奨モデル・受け入れ条件の所在を含む）を return して本体にレビュアーの spawn を委ねること、failed の return に原因分類を含めることが書かれている、Codex の完了確認を同一ターン内の前景ポーリングで行うこと・その手順の正本が `references/subagent-waiting.md` であること・総待ちの上限に達したら `needs-reviewer` を return することが書かれており、待ちの雛形と具体の待ち値は再掲されていない

#### Scenario: 3 つの指示書に待ちでターンを終えない禁止がある
- **WHEN** `references/roles/` 配下の `worker.md` / `spec-reviewer.md` / `gate-runner.md` をそれぞれ読む
- **THEN** どのファイルにも「完了通知を待つためにターンを終えない」旨の記述があり、待ち方の正本として `references/subagent-waiting.md` が参照されている

#### Scenario: spec-reviewer.md の 1 行は decider 経路を踏まえている
- **WHEN** `references/roles/spec-reviewer.md` の待ちに関する 1 行を読む
- **THEN** 禁止が書かれたうえで、decider 経路の R1 は待ちを伴う作業を持たない旨が添えられており、実行できない待ちループの手順を探しに行かずに済む

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとのモデルを次のとおり規定しなければならない（MUST）: W は既定 `sonnet`、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか、実行側が原因の失敗ループでの昇格か、事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たれば `opus`。**W を `fable` で spawn してはならない**（MUST NOT。実行役の上限は `opus` で、強制層は `scripts/agent-model-guard.sh`）。R1 は既定 `opus`、仕様がマージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する（聖域パスだけでは上げない）。G は既定 `sonnet` で上げない（G の仕事は照合・ラベル操作で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う）。G が要求するレビュアーは既定 `opus`、対象がマージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。残量モード（`FABLE_BUDGET_MODE`）は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の表に従い、`abundant` はどの役割の既定も上げず、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限とする（MUST）。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が役割の既定モデルの下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定とし、Fable 残量モードと食い違えば共有枠モードが勝つ（MUST）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）は、失敗の原因が判断側か実行側かで決める役と実行役のどちらか一方だけを上げるラダー（正本は `templates/escalation-tripwires.md`）として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測らなければならない（MUST）。上限超過（exit 2）を検知したあとの扱い（送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目にどちらの宣言を置くか・前任が動作中のまま交代させるときの手順）について、SKILL.md は本文を書かず、`plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」への参照だけを置かなければならない（MUST。正本の位置・参照だけにする面の一覧・テストの形は `dev-workflow-execution-strategy` が規定する）。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が `sonnet` で上限が `opus`、R1 の既定が `opus`、G の既定が `sonnet`、事前分類（聖域パス・マージ権限・層間契約・課金/法務）で W は `opus` 止まり、R1 とレビュアーの fable は `dev-workflow:decider` 経由、`abundant` はどの役割も上げない、`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限、`SHARED_BUDGET_MODE` の `throttled` / `depleted` で `sonnet` 起点、と書かれている

#### Scenario: 失敗ループでは片方だけ上げる
- **WHEN** SKILL.md の失敗ループの記述を読む
- **THEN** 決める役と実行役のどちらを上げるかを失敗の原因分類で決め、両方同時に上げないこと、実行役の上限が `opus` であることが書かれている

#### Scenario: 再開前にコンテキスト量を測る
- **WHEN** SKILL.md の「1 ループ」節を読む
- **THEN** W / G を SendMessage で再開する前に `subagent-context.sh` で測ること、G の再開も同じであること、上限超過のあとの扱いは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本であることが参照として書かれている
- **AND** そこに手渡しの条件・宣言の選び方・停止確認の手順を言い換えた文は無い

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
SKILL.md は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。**回し方**: 本体は子の依存グラフを読み、blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと。本体が W を `isolation: "worktree"` で spawn して用意し、W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった新しい問題は新しい子 issue として追加する。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

#### Scenario: エピックの 4 節が存在する
- **WHEN** SKILL.md の「エピックの扱い」節を読む
- **THEN** 条件・作り方・回し方・完了条件の 4 つが揃い、完了条件に「子が全部マージされただけでは閉じない」が書かれている

#### Scenario: 子は並列に worktree 分離で起こす
- **WHEN** エピックの回し方を読む
- **THEN** blocked されていない子から `isolation: "worktree"` で 1 ループを並列に起こすこと、新しい問題は子の中で直さず新しい子 issue にすることが書かれている

### Requirement: 実行モードと unmanned の責務分割
SKILL.md は実行モード表（interactive / unmanned）を持ち、unmanned（`--unmanned`。loop-dev-agent の憲法 Step 3 から呼ばれる）では次を規定しなければならない（MUST）: develop の本体は憲法のメイン自身が務め、W / R1 をメインが spawn する。worktree は憲法側が用意したものを使う。1 ループのうち (0)〜(3) を回し、(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。(4) の G は unmanned では起こさず、憲法 Step 1（レビューモード）が次サイクル以降で担う（1 サイクル 1 仕事を維持）。複数 change に割れた場合は子 issue を作って `blocked_by` で順序付けし、そのサイクルを終える。仕様化判断の記録と仕様レビューは unmanned でも免除しない（MUST）。

#### Scenario: unmanned では G を起こさない
- **WHEN** SKILL.md の実行モード表を読む
- **THEN** unmanned では憲法のメインが本体を務めて W / R1 を spawn し、(3) で Draft PR と `agent-review:pending` まで W が行い、G は憲法 Step 1 に委ねると書かれている

### Requirement: 前提環境を明記する
SKILL.md は「前提」節として、Agent ツール（`model` 明示・名前付き spawn・`isolation: "worktree"`）と SendMessage、`gh`（issue / PR コメントとラベル、issue dependencies API）、opsx コマンドまたは openspec CLI（無ければ仕様化経路が発生しない）、Codex CLI（無ければ G が `needs-reviewer` に縮退）を列挙しなければならない（MUST）。

#### Scenario: 前提節がある
- **WHEN** SKILL.md の「前提」節を読む
- **THEN** Agent / SendMessage / gh / opsx または openspec / Codex CLI とそれぞれ無いときの縮退が書かれている

### Requirement: /develop コマンドと /work-issue エイリアス
`plugins/dev-workflow/commands/develop.md` が存在し、`skills/develop/SKILL.md` を path-discovery で特定して Read し interactive モードでインライン実行する薄いラッパーでなければならない（MUST）。frontmatter の `allowed-tools` は Agent と SendMessage を含み、Edit を含まない（MUST。本体はコードを書かない）。`commands/work-issue.md` は `/develop` のエイリアスとして残し、同じ引数を develop の手順に渡す（MUST）。plugin.json の `skills` に `./skills/develop`、`commands` に `./commands/develop.md` と `./commands/work-issue.md` が登録されている（MUST）。

#### Scenario: /work-issue が /develop として動く
- **WHEN** `/work-issue 42` を起動する
- **THEN** `commands/work-issue.md` は develop の手順に `42` を渡す旨だけを書いており、独自の手順を持たない。`commands/develop.md` の `allowed-tools` には Agent と SendMessage があり Edit が無い

#### Scenario: plugin.json の登録
- **WHEN** `.claude-plugin/plugin.json` を読む
- **THEN** `skills` に `./skills/develop` があり `./skills/github-issue` が無く、`commands` に `./commands/develop.md` と `./commands/work-issue.md` がある

### Requirement: コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く

コンテキスト計測の規則の本文——2 経路（本体が再開前に測る／起動の途中で hook が測る）・閾値の環境変数（`DEV_WORKFLOW_CONTEXT_CAP`＝通知、`DEV_WORKFLOW_CONTEXT_HARD_CAP`＝強制停止、`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`＝全解除）・通知を受けたときの振る舞い・強制停止中にできること・return の 1 行目の書き分け——は、`references/decision-criteria.md`「コンテキスト上限」の節に置かなければならない（MUST）。

`skills/develop/SKILL.md`、`references/roles/worker.md`、`references/roles/gate-runner.md`、`templates/escalation-tripwires.md`、`plugins/dev-workflow/README.md` は、その節への**ポインタと、その役割固有の動作だけ**を書かなければならない（MUST）。閾値の数値・環境変数名・通知や強制停止の振る舞いを言い換えて再掲してはならない（MUST NOT）。同じ規則を複数のファイルに言い換えて置くと、次に閾値や振る舞いが変わったときにどれかが取り残されるためである（`README.md` を対象に含めるのは、プラグインの概観であっても閾値の数値を書けば取り残される対象になるため。実際に着手時点の `README.md` には `150K tokens` の再掲があった）。

#### Scenario: 規則の本文が decision-criteria.md にある

- **WHEN** `references/decision-criteria.md` のコンテキスト上限の節を読む
- **THEN** 2 経路・3 つの環境変数・通知時と強制停止時の振る舞い・return の 1 行目の書き分けが、そこだけで完結して書かれている

#### Scenario: 他の面はポインタだけ

- **WHEN** `SKILL.md` / `references/roles/worker.md` / `references/roles/gate-runner.md` / `templates/escalation-tripwires.md` / `README.md` を読む
- **THEN** `references/decision-criteria.md`「コンテキスト上限」への参照があり、閾値の数値や環境変数名の再掲が無い

### Requirement: 途中停止したときの return の 1 行目

途中計測で工程を締めるとき、W / G が return の 1 行目に書く申告（#253 の規約）は次のとおりでなければならない（MUST）。

- **強制停止**（`DEV_WORKFLOW_CONTEXT_HARD_CAP` 超でツールを拒否された）で止まった場合は、成果を書いていても必ず `工程中断:` とする（MUST）。拒否された時点で予定していた作業が残っているため。
- **通知**（`DEV_WORKFLOW_CONTEXT_CAP` 超）を受けて締める場合は、そのとき進めていた tasks グループの項目がすべて完了していれば `工程完了:`、1 つでも残っていれば `工程中断:` とする（MUST）。

この区別が要るのは、`工程完了:` が手渡しの条件として使われており、手渡し先の W / G が未コミット差分と残作業を先に確認しなければならないのは中断のときだけだからである。判定は「そのとき進めていた tasks グループの項目がすべて済んでいるか」だけで行い、他の材料を要求してはならない（MUST NOT）。

途中計測の通知は役割で出し分けないため、`tasks.md` を持たない受け手（仕様化しない依頼の W、pr-review-gate の手順を回す G）にも同じ文言が届く。したがって「tasks グループ」が何を指すかを次のとおり定めなければならない（MUST）: `tasks.md` があればそのとき進めていた章のグループ、無ければ本体から渡された作業項目、G は pr-review-gate の手順 1〜5 を 1 グループとみなす。

#### Scenario: 強制停止は常に工程中断

- **WHEN** `references/decision-criteria.md` のコンテキスト上限の節を読む
- **THEN** 強制停止で止まった場合は成果があっても `工程中断:` にする、と書かれている

#### Scenario: 通知は tasks の残りで決める

- **WHEN** 同じ節を読む
- **THEN** 通知を受けて締める場合は、そのとき進めていた tasks グループが全部済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:` にする、と書かれており、`tasks.md` が無い場合に何を 1 グループとみなすかも書かれている

### Requirement: 手渡し先は未コミット差分を先に確認する

手渡しで起こされた W / G の指示書は、前任が途中停止で return した可能性があるため、再出発の前に作業ツリーの未コミット差分（`git status` / `git diff`）を確認しなければならない（MUST）と書かなければならない。これは `references/roles/worker.md` の手渡しの節に置く役割固有の動作であり、閾値や振る舞いの再掲ではない。

#### Scenario: 手渡し先が未コミット差分を先に見る

- **WHEN** `references/roles/worker.md` の手渡しの節を読む
- **THEN** 前任が途中停止した可能性があるので `git status` / `git diff` で未コミット差分を先に確認する、と書かれている

### Requirement: 強制停止で止まった作業ツリーは本体が引き取る

強制停止中は `Bash` がコマンド内容によらず全件拒否されるため、止まったサブエージェント自身は commit できない（`dev-workflow-execution-strategy`「強制停止の閾値を超えたら PreToolUse が編集を拒否する」）。手渡し先（`worker.md` の手渡しの節）が拾うのは**次に起こされた**サブエージェントの `git status` / `git diff` だけなので、①手渡しが発生しない経路（そのサイクルを終える・別の子 issue に移る・工程が G で終わる）、②後継が G の場合（`gate-runner.md` には同じ規則が無い）は未コミット差分の確認が誰にも渡らない。SKILL.md は、`工程中断:` の return を受け取ったとき、および次の手渡し・次の spawn・そのサイクルの終了・worktree の撤去のいずれよりも先に、**本体**が return に書かれた作業ツリーのパス（強制停止による中断なら hook の `permissionDecisionReason` に含まれる `cwd`。それ以外の `工程中断:` なら return に書かれたパス）に対して `git -C <path> status --porcelain` を実行して未コミット差分を確認し、残っていれば本体が commit しなければならない（MUST）ことを明記しなければならない（MUST）。

#### Scenario: 本体が未コミット差分を引き取る

- **WHEN** SKILL.md の本体の手順を読む
- **THEN** `工程中断:` を受け取ったとき、および次の手渡し・次の spawn・サイクルの終了・worktree の撤去のいずれよりも先に、本体が return に書かれた作業ツリーのパスに対して `git -C <path> status --porcelain` で未コミット差分を確認し、残っていれば本体が commit すると書かれている

### Requirement: 強制停止に当たった G のレビュー結果は本体が代理投稿する

強制停止中は `Bash` がコマンド内容によらず全件拒否されるため `gh pr comment` も拒否され、G（ゲート実行者）が強制停止に当たるとレビュー結果を記録先に投稿できず、commit もできないまま return することになる。この経路を手順書に書いておかなければならない（MUST）。

`references/roles/gate-runner.md` は、この場合に G がレビュー結果を return の本文に含めて `工程中断:` で返すことを書かなければならない（MUST）。`skills/develop/SKILL.md` は、本体が `工程中断:` の return を受け取ったとき、そこに含まれるレビュー結果を**本体が記録先に代理投稿する**ことを書かなければならない（MUST）。R1 の仕様レビューを本体が代理投稿している（`subagent_type: dev-workflow:decider` は `gh` を実行できない）のと同じ経路である。

#### Scenario: G は結果を return に載せて返す

- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** 強制停止で `gh pr comment` が拒否されたらレビュー結果を return の本文に含めて `工程中断:` で返す、と書かれている

#### Scenario: 本体が代理投稿する

- **WHEN** `skills/develop/SKILL.md` の本体の手順を読む
- **THEN** `工程中断:` の return にレビュー結果が含まれていたら本体が記録先に代理投稿する、と書かれている

