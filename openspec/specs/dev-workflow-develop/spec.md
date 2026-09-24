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
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 → (1) W が仕様化判断の記録・分割判定・`/opsx:ff` まで行い return（仕様化しない判定なら (3) へ直行）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（2 周キャップ。超えたら `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) apply（TDD）・verify まで行って return、本体が計測してから (3b) archive・PR を Draft のまま用意（無ければ Draft で作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → (4) G が pr-review-gate の手順 1〜5 を実行し `passed` / `failed` / `保留` / `needs-reviewer` / `needs-decider` / `review-incomplete` のいずれかを return。PR の Ready 化は G が手順 5 の合格処理で行い（Draft なら Ready にしてから `agent-review:passed` を付ける）、W は行ってはならない（MUST NOT）。

G が `review-incomplete` を return したとき、本体は新しい reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止めなければならない（MUST）。`needs-reviewer` が一周目照合の補足要求である場合、本体は fresh reviewer に固定 HEAD・元の三表・残差・補足済み回数を渡し、同じレビューの不足分だけを補わせなければならず（MUST）、レビューを最初からやり直させてはならない（MUST NOT）。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら実行役を `opus` に上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く。**W を `fable` で再開してはならない**（MUST NOT。実行役の上限は `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。修正後は G を再開して差分再レビュー（2 周）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

worktree は本体が用意する（SHALL）: 本体が既に対象専用の worktree にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。W は自分で worktree を切らない（MUST NOT。セットアップは worktree プラグインの hooks が担う）。**W / G を `isolation: "remote"` で起こしてはならない**（MUST NOT）。強制停止に当たったサブエージェントの未コミット差分は本体が確認して commit する設計（下の「強制停止で止まった作業ツリーは本体が引き取る」Requirement）だが、`remote` 隔離は本体から見えない環境で動くため、そこで強制停止に当たると作業がそのまま失われる。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ 2 周キャップがある

#### Scenario: (3) は 2 段に分かれて書かれている
- **WHEN** SKILL.md の 1 ループの (3) を読む
- **THEN** (3a) と (3b) が別々の return として並び、(3a) に apply（TDD）と verify が、(3b) に archive・PR・仕様宣言が入っている

#### Scenario: (3b) は PR を Draft のまま G に渡す
- **WHEN** SKILL.md の 1 ループの (3b) と `references/roles/worker.md` の (3b) を読む
- **THEN** PR を Draft のまま用意する（issue が記録先なら `gh pr create --draft`）と書かれ、W が PR を Ready に切り替える記述が無く、Ready 化は G が pr-review-gate 手順 5 で行うと書かれている

#### Scenario: W / G は remote 隔離で起こさない
- **WHEN** SKILL.md の spawn の記述を読む
- **THEN** W / G を `isolation: "remote"` で起こしてはならないと書かれている

#### Scenario: G の failed は片方だけ上げて W の再開に戻る
- **WHEN** G が failed を return する
- **THEN** SKILL.md は実装品質起因のときだけ原因分類に応じて実行役を `opus` に上げるか決める役を `dev-workflow:decider` で立てるかの一方だけを行い、仕様が曖昧・レビュアーの誤検出ではモデルを上げず、W を `fable` にはせず、G を再開して差分再レビューするよう指示している

#### Scenario: decider として起こした R1 の結果は本体が投稿する
- **WHEN** SKILL.md の (2) の記述を読む
- **THEN** R1 が `dev-workflow:decider` の場合は本体が return を同じ書式で記録先に代理投稿すると書かれている

#### Scenario: review-incomplete は reviewer を再起動しない
- **WHEN** G が補足後の残差を `review-incomplete` で return する
- **THEN** 本体は fresh reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止める

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker.md`（W）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）・仕様レビュー結果の記録書式・「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。事前分類表の「1 周目」列は**実行役（W）の上限を `opus` とし、`fable` 行を持ってはならない**（MUST NOT。4 分類のいずれに当たっても W は `opus` 止まりで、聖域パスの `opus` は据え置き）。表には、読んで判断する役（R1・G が要求するレビュアー）が `fable` 相当の分類に当たるときは `subagent_type: dev-workflow:decider` で spawn し、`general-purpose` に `model: fable` を付けないことを明記しなければならない（MUST）。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担うことを書く（SHALL）。`worker.md` の return には「指示のどこまでやって、どこで何が起きたか」を含める義務を書かなければならない（MUST。決める役の入力契約になるため）。

`spec-reviewer.md` は 6 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合・守備範囲の明記）と 2 周キャップを含む（MUST）。観点の中身の正本は `dev-workflow-spec-review` とする（SHALL）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

`worker.md`・`spec-reviewer.md`・`gate-runner.md` の 3 つはいずれも、長時間処理の完了通知を待つためにターンを終えてはならない旨を明記しなければならない（MUST）。待ち方の詳細の正本は `plugins/dev-workflow/references/subagent-waiting.md` とし、各指示書はそこを参照する（SHALL）。`spec-reviewer.md` の 1 行は、decider 経路で spawn される R1 が `Bash` を持たず待ちループ自体を実行できないため、「長い処理の完了を待つ目的でターンを終えない（decider 経路の R1 は待ちを伴う作業を持たない）」の形で書く（SHALL。読んだ R1 が実行できない手順を探しに行かないようにするため）。

`gate-runner.md` は Codex の**起動**の事実（(a) `codex exec -c approval_policy=never -c model_reasoning_effort=medium` を `run_in_background` で起動する経路と、(b) `codex-companion.mjs` に `task … --effort medium` を投げる経路。companion の path-discovery を含む）を持ち、**完了の確認方法は正本 `plugins/dev-workflow/references/subagent-waiting.md` に委ねなければならない（MUST）**。完了マーカーの雛形・具体の待ち値・総待ちの上限を `gate-runner.md` に再掲してはならない（MUST NOT。2026-09-09 のレビューで、再掲した companion の判定方法が事実と食い違ったまま残っていたため）。「出力ファイルを読め」だけで待ち方を書かない記述を残してはならない（MUST NOT）。`gate-runner.md` に残す待ち関連の記述は、完了通知に頼ってターンを終えない禁止・正本への参照・上限到達時の G 固有の分岐（待ちをやめて `needs-reviewer` を return し、根拠に「Codex タイムアウト」と実際に待った時間を書く）に限る（SHALL）。

#### Scenario: worker.md に記録書式と事前分類表がある
- **WHEN** `references/roles/worker.md` を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式、`gh` で記録先にコメントする手順、4 分類の事前分類表（「1 周目」列がすべて `opus` で `fable` 行が無い）、レビュアーの fable は `dev-workflow:decider` 経由であること、return に「指示のどこまでやって、どこで何が起きたか」を書く義務が書かれている

#### Scenario: spec-reviewer.md に 6 観点と 2 周キャップがある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 6 観点がすべて列挙され、2 周で確定し 3 周目の例外を設けないことが書かれている

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
SKILL.md は役割ごとのモデルを次のとおり規定しなければならない（MUST）: W は既定 `sonnet`、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか、実行側が原因の失敗ループでの昇格か、事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たれば `opus`。**W を `fable` で spawn してはならない**（MUST NOT。実行役の上限は `opus` で、強制層は `scripts/agent-model-guard.sh`）。R1 は既定 `opus`、仕様がマージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する（聖域パスだけでは上げない）。G は既定 `sonnet` で上げない（G の仕事は照合・ラベル操作で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う）。G が要求するレビュアーは既定 `opus`、対象がマージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。従来経路では G の `needs-reviewer` が示す推奨 model に従い、adapter 経路では phase `review` の adapter が返した model に残量上限を適用した値を使い、G の推奨 model は参考値として扱わなければならない（MUST）。残量モード（`FABLE_BUDGET_MODE`）は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の表に従い、`abundant` はどの役割の既定も上げず、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限とする（MUST）。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が役割の既定モデルの下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定とし、Fable 残量モードと食い違えば共有枠モードが勝つ（MUST）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）は、失敗の原因が判断側か実行側かで決める役と実行役のどちらか一方だけを上げるラダー（正本は `templates/escalation-tripwires.md`）として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測らなければならない（MUST）。上限超過（exit 2）を検知したあとの扱い（送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目にどちらの宣言を置くか・前任が動作中のまま交代させるときの手順）について、SKILL.md は本文を書かず、`plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」への参照だけを置かなければならない（MUST。正本の位置・参照だけにする面の一覧・テストの形は `dev-workflow-execution-strategy` が規定する）。

この要件の守備範囲で入力として扱うのは、G の起動・再開指示にある `レビュー経路:`、G の `needs-reviewer` が示す推奨 model、phase `review` の adapter が返す model、および `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` から決まる残量上限である。防ぐ誤りは、経路ごとの決定元を取り違えること、adapter が選んだ model を G の推奨 model で上書きすること、残量上限を適用せずに model を採用することである。一方、adapter が `sonnet` を返して G が `opus` を推奨していても、残量上限を適用した adapter の値を採用することは許容する。任意の不正な経路・model・残量モード入力を検出して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が `sonnet` で上限が `opus`、R1 の既定が `opus`、G の既定が `sonnet`、事前分類（聖域パス・マージ権限・層間契約・課金/法務）で W は `opus` 止まり、R1 とレビュアーの fable は `dev-workflow:decider` 経由、`abundant` はどの役割も上げない、`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限、`SHARED_BUDGET_MODE` の `throttled` / `depleted` で `sonnet` 起点、と書かれている

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
SKILL.md は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。

**回し方（経路の決め方）**: interactive の本体は子の依存グラフを読み、blocked されていない子の番号を `plugins/dev-workflow/scripts/epic-dispatch.sh route` に渡して経路を決める（MUST）。`route` が `orca` を返したとき（blocked されていない子が 2 件以上あり、`orca` コマンドが PATH にあり、本体が Orca 管理のワークツリーにいる）は **Orca 経路**、`subagent` を返したときは **サブエージェント方式**で進める（MUST）。経路は `/develop <エピック番号>` の最初の開始時に 1 回決め、途中で変えてはならず（MUST NOT）、決めた経路をエピックに `回し方:` で始まる 1 行コメントで残す（MUST）。別セッションで同じエピックを再開したときは、`回し方:` で始まる最新のコメントを読んで経路を引き継ぎ、`route` をやり直してはならない（MUST NOT）。unmanned（`--unmanned`）では `route` を呼ばず、サブエージェント方式で進める（MUST。背景で待って起こされる動きが 1 サイクル 1 仕事と合わないため）。

**回し方（Orca 経路）**: 本体は `epic-dispatch.sh launch` で子ごとに Orca の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。再開時も、依存が解けた open の子を `launch` に渡し、起動済みの子は `launch` の `skipped` で見分ける（同じ子を二重に起動しない）。本体は `launch` が `launched` / `skipped` を出した子を動いている子とし、`epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める。`closed` なら閉じた子ごとに `state_reason` を読み、`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントして依存グラフを読み直し、解けた子を件数にかかわらず `launch` する。`completed` 以外ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子を起動してはならず（MUST NOT）、ユーザーに報告する。そのあと残りの動いている子で再び `wait` する。`timeout` なら待っている子に `needs-approval` などの停止の兆候が無いかを見て、あればユーザーに報告し、報告したかどうかにかかわらず残りの動いている子で再び `wait` する。子が自分のタブでユーザーに質問して止まっている場合はこの確認では気づけないことを書く（SHALL）。`wait` の `error` と `launch` の `failed` はユーザーに報告して止まる。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子セッションは `--dangerously-skip-permissions` で動き許可の確認画面が出ないこと、マージを止めているのは develop と pr-review-gate の規則と hooks であることを書く（SHALL）。子の PR のマージは今までどおり子セッションの中で人の承認で行い、本体が自動でマージしてはならない（MUST NOT）。

**回し方（サブエージェント方式）**: 今までどおり blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと。本体が W を `isolation: "worktree"` で spawn して用意し、W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。

どちらの経路でも、スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった新しい問題は新しい子 issue として追加する。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

#### Scenario: エピックの 4 節が存在する
- **WHEN** SKILL.md の「エピックの扱い」節を読む
- **THEN** 条件・作り方・回し方・完了条件の 4 つが揃い、完了条件に「子が全部マージされただけでは閉じない」が書かれている

#### Scenario: 子は並列に worktree 分離で起こす
- **WHEN** エピックの回し方を読む
- **THEN** サブエージェント方式として、blocked されていない子から `isolation: "worktree"` で 1 ループを並列に起こすことが書かれ、どちらの経路でも新しい問題は子の中で直さず新しい子 issue にすることが書かれている

#### Scenario: 回し方に 2 経路の振り分け条件が書かれている
- **WHEN** エピックの回し方を読む
- **THEN** `epic-dispatch.sh route` の出力で経路を決めること、`orca` になる条件（blocked されていない子が 2 件以上・`orca` が PATH にある・本体が Orca 管理のワークツリーにいる）、それ以外はサブエージェント方式で進むこと、経路を最初の開始時に 1 回決めて途中で変えないこと、再開時は `回し方:` のコメントから経路を引き継ぐこと、unmanned はサブエージェント方式のままであることが書かれている

#### Scenario: Orca 経路の本体は wait の出力で次を決める
- **WHEN** Orca 経路の本体の手順を読む
- **THEN** `launch` で子を起動し、`wait` を `run_in_background: true` で起動して待つこと、`closed` で `state_reason` を読み `completed` なら `子 #N マージ → 残り k 件` をコメントして解けた子を `launch` し、それ以外なら `見送り` とコメントして後続を起動せず報告すること、`timeout` で停止の兆候を確かめて報告したうえで再び待つこと、子のタブでの質問は検知できないこと、子の PR を本体が自動でマージしないことが書かれている

### Requirement: 実行モードと unmanned の責務分割
SKILL.md は実行モード表（interactive / unmanned）を持ち、unmanned（`--unmanned`。loop-dev-agent の憲法 Step 3 から呼ばれる）では次を規定しなければならない（MUST）: develop の本体は憲法のメイン自身が務め、W / R1 をメインが spawn する。worktree は憲法側が用意したものを使う。1 ループのうち (0)〜(3) を回し、(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。(4) の G は unmanned では起こさず、憲法 Step 1（レビューモード）が次サイクル以降で担う（1 サイクル 1 仕事を維持）。複数 change に割れた場合は子 issue を作って `blocked_by` で順序付けし、そのサイクルを終える。仕様化判断の記録と仕様レビューは unmanned でも免除しない（MUST）。

#### Scenario: unmanned では G を起こさない
- **WHEN** SKILL.md の実行モード表を読む
- **THEN** unmanned では憲法のメインが本体を務めて W / R1 を spawn し、(3) で Draft PR と `agent-review:pending` まで W が行い、G は憲法 Step 1 に委ねると書かれている

### Requirement: 前提環境を明記する
SKILL.md は「前提」節として、Agent ツール（`model` 明示・名前付き spawn・`isolation: "worktree"`）と SendMessage、`gh`（issue / PR コメントとラベル、issue dependencies API）、opsx コマンドまたは openspec CLI（無ければ仕様化経路が発生しない）、Codex CLI（無ければ G が `needs-reviewer` に縮退）、`orca` コマンド（エピックの子を Orca の子ワークツリーで独立セッションとして起動する。無いとき、または本体が Orca 管理外のワークツリーにいるときは、エピックをサブエージェント方式で回す）を列挙しなければならない（MUST）。

#### Scenario: 前提節がある
- **WHEN** SKILL.md の「前提」節を読む
- **THEN** Agent / SendMessage / gh / opsx または openspec / Codex CLI / orca とそれぞれ無いときの縮退が書かれ、orca の行には Orca 管理外のワークツリーにいるときもサブエージェント方式になることが書かれている

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

### Requirement: W の (3) は 2 回の return に分かれる
本体がサブエージェントのコンテキスト量を測れるのは、W を SendMessage で再開する直前（＝ W が return した直後）だけである。したがって return の区切りの数がそのまま計測点の数になる。W の実装以降の工程 (3) は、次の 2 つの return に分けなければならない（MUST）。

- **(3a) 実装＋verify**: `/opsx:apply`（または直叩きの TDD）と `/opsx:verify` までを行い、`工程完了: 実装＋verify` を 1 行目にして return する
- **(3b) archive＋PR＋仕様宣言**: `/opsx:archive`（仕様化した場合）・PR を Draft のまま用意すること（記録先が Draft PR ならそのまま使い、issue が記録先なら `gh pr create --draft` で作る。Ready には切り替えない）・仕様宣言を PR コメントに書くことを行い、`工程完了: archive＋PR＋仕様宣言` を 1 行目にして return する

境界は archive の手前に置き、verify は (3a) 側に含めなければならない（MUST）。verify の失敗は実装への巻き戻しであり、実装と verify を別の担い手に割ると手渡し直後に巻き戻しが起きるためである。

**(3) をこれより細かく（`tasks.md` の項目単位・「実装／verify／archive／PR／仕様宣言」の 5 段など）分割してはならない（MUST NOT）。** 手渡しが 1 回起きるたびに、後任は指示書と正本の節を読み直し、記録先を取り直し、`git status` / `git diff` でファイルの現状を確認する固定分を払う。この固定分は工程の大きさに依存しないため、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。また区切りが実装の途中に落ちると、後任は Red のまま止まったテストから再出発することになり、前任の設計意図を再発明する危険が最も高い地点で交代する。

`references/roles/worker.md` は (3a) と (3b) それぞれの return に何を書くかを列挙しなければならない（MUST）。**(3a) の return には、実行したテストコマンドと exit code、および `/opsx:verify` の合否を含めなければならない（MUST）**。(3b) の担い手は pr-review-gate 手順 5 が照合する動作確認の証拠を書く必要があり、手渡しが起きた場合その証拠は前任の return からしか得られない（後任は前任の履歴を読めない）ためである。`/opsx:verify` の合否が無いと、(3b) の担い手は verify を通ったことを確認できないまま archive に進むことになる。

`skills/develop/SKILL.md` は、(3a) の return を受けてから (3b) を指示する SendMessage を送るまでのあいだに、本体が `scripts/subagent-context.sh <W の名前>` を実行してコンテキスト量を測ることを書かなければならない（MUST）。上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本である（再掲の禁止は既存の Requirement「コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く」が規定しており、ここでは重ねて規定しない）。

本体は次に指示する工程を、**自分が (3a) を指示したか (3b) を指示したかで決めなければならない**（MUST）。工程名の文字列照合で決めてはならない（MUST NOT）。(3a) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば、(3b) を指示せず (4) へ進まなければならない（MUST）。古いキャッシュの `worker.md` を読んだ W は (3a) の指示を受けても (3) を通しで終えて返してくるため、文字列照合で routing すると PR の作成と仕様宣言の投稿が二重に走るためである。

#### Scenario: worker.md が (3a) / (3b) の return 内容を列挙している
- **WHEN** `references/roles/worker.md` の実装以降の節を読む
- **THEN** (3a) と (3b) がそれぞれ別の見出し（または別の箇条）として立っており、(3a) の return に実行したテストコマンドと exit code および `/opsx:verify` の合否を含める義務が書かれ、(3b) の return に PR 番号と仕様宣言のコメント URL を含める義務が書かれている

#### Scenario: 旧世代の W が (3) を通しで返してきても (3b) を再指示しない
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** 本体は次に指示する工程を自分が指示した工程で決めると書かれており、工程名の文字列照合では決めないことと、(3a) の return に PR 番号と仕様宣言のコメント URL が揃っていれば (3b) を指示せず次へ進むことが書かれている

#### Scenario: worker.md の工程名が 3 つになっている
- **WHEN** `references/roles/worker.md` のコンテキスト上限と手渡しの節を読む
- **THEN** W が return する工程の単位が「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つとして列挙されている

#### Scenario: SKILL.md が (3a) と (3b) のあいだの計測を指示している
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** (3a) の return のあと (3b) を指示する前に `scripts/subagent-context.sh` で測ると書かれており、上限超のときの扱いは `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を正本として参照している

#### Scenario: タスク単位のさらなる分割は禁止されている
- **WHEN** `references/roles/worker.md` のコンテキスト上限と手渡しの節を読む
- **THEN** (3) を (3a)/(3b) より細かく切らないことと、その理由（手渡しごとに払う固定分と、実装の途中で切ると後任が Red のまま止まったテストから再出発すること）が書かれている

### Requirement: 本体は role profile から executor を選ぶ
名前付き role profile を使う develop 本体は、新しい profile role を起動する直前に canonical role の executor/account/model/effort を共通 resolver から取得し、executor=claude なら Agent、executor=codex なら foreground request/run 経路を選ばなければならない（MUST）。事前分類に当たる R1 または G が要求したレビュアーを起動するときは、対象 role の entry ではなく profile の `decider` entry（executor/account/model）を使い、`subagent_type: dev-workflow:decider` として起動しなければならない（MUST）。resolver は profile の model を要求値として変更せず返す。Claude Agent の起動時には既存の `FABLE_BUDGET_MODE` と `SHARED_BUDGET_MODE` の上限を要求 model より優先し、要求 model・実際に Agent へ渡す適用 model・変更理由（変更しない場合は変更なし）を区別して扱わなければならない（MUST）。executor の選択は transport と execution setting だけを変え、仕様化判断、工程順、独立レビュー、差戻し上限、verify、archive、PR gate の条件を変えてはならない（MUST NOT）。

#### Scenario: 1 つの profile で executor が工程間に変わる
- **WHEN** spec-write=codex、spec-review=claude の profile で仕様化工程を進める
- **THEN** W は Codex foreground 経路、R1 は Claude Agent 経路で別 thread として動き、R1 の APPROVE が記録されるまで実装へ進まない

#### Scenario: 事前分類に当たる R1 またはレビュアーを起動する
- **WHEN** R1 または G が要求したレビュアーの対象がマージ条件・層間契約・課金/法務に触れる
- **THEN** 対象 role の entry ではなく profile の `decider` entry の executor/account/model を使い、`subagent_type: dev-workflow:decider` として起動する

#### Scenario: executor 切替でも canonical role を維持する
- **WHEN** 同じ role の executor を profile で Claude から Codex または Codex から Claude へ変える
- **THEN** role の指示書、read-only/write 権限、return 契約、記録先、次工程の判定は変わらず、provider 固有の起動操作だけが変わる

#### Scenario: 通常モードでは要求 model をそのまま適用する
- **WHEN** decider の resolver 結果が requested model=`fable` で、Fable と共有枠の残量モードがその model を制限しない
- **THEN** applied model=`fable`、変更理由=変更なしとして Agent を起動する

#### Scenario: exhausted は Fable 要求を Opus に制限する
- **WHEN** decider の resolver 結果が requested model=`fable` で、`FABLE_BUDGET_MODE=exhausted` かつ共有枠が depleted ではない
- **THEN** resolver 結果は `fable` のまま保持し、applied model=`opus`、変更理由=`FABLE_BUDGET_MODE=exhausted` として Agent を起動する

#### Scenario: depleted はすべての要求を Sonnet に固定する
- **WHEN** Claude role の resolver 結果が requested model=`fable` で、`SHARED_BUDGET_MODE=depleted`
- **THEN** resolver 結果は `fable` のまま保持し、applied model=`sonnet`、変更理由=`SHARED_BUDGET_MODE=depleted` として Agent を起動する

### Requirement: G の needs-decider を受けた本体の動き

`plugins/dev-workflow/skills/develop/SKILL.md` の (4) は、G の return の分岐に `needs-decider`（pr-review-gate の仕分け表の順 6。同じ型の再発）の行を持たなければならない（MUST）。その行は次を規定する（MUST）: 本体は `subagent_type: dev-workflow:decider` を、残量モードの規定どおりのモデルで spawn する。入力は、`agents/decider.md` の入力契約の 4 項目に揃え、記録先（issue または Draft PR）の本文、判断に必要な関連コメント（`仕様化判断:` の記録・G の仕分けの PR コメント・順 3 の一覧表の PR コメントがあればそれ）、G の return に載った同じ型の指摘と前の周の指摘の原文（PR コメントの本文を貼る）、対象ファイルのパス、G の仕分け欄、W の直近の return とする。依頼は、マージ可否を問うときと同じ `agents/decider.md` の既存の「可否と根拠」の出力契約で出し（決める役が 3 点の契約で返す取り違えを防ぐため、行にその旨を書く）、問いを「この PR の中で、同じ型を全部列挙してから直すべきか（可）、切り出すべきか（否）」の 1 つにする。依頼文では、返答の 1 行目を `裁定: 可`・`裁定: 否`・`不足: <足りないもの>` のどれかちょうどにするよう指定し、本体はその 1 行目で分岐する（MUST。本文の読み取りで分岐しない）。本体は返ってきた可否を方式（`裁定: 可`＝全部列挙してから直す、`裁定: 否`＝切り出す）に読み替え、根拠とともに SendMessage で G に渡して G を再開する。本体は裁定を記録先に投稿しない（記録は G が PR コメントに行う）。これは「`dev-workflow:decider` で起こした役割の return は本体が代理投稿する」一般則の例外であり、SKILL.md は一般則の記述にもこの例外を一言書かなければならない（MUST）。`agents/decider.md` の入力契約と出力契約は変えない（MUST NOT）。

決める役の返答の 1 行目が `不足:` なら、本体はそれを裁定として扱ってはならず、G に渡してはならない（MUST NOT）。本体は足りないものを補って、同じ問いで 1 回だけ依頼し直す（MUST）。依頼し直しても不足が返ったら、本体は G に「裁定なし（入力不足）」と足りなかったものを SendMessage で渡して G を再開する（MUST。G はそれを「切り出す」として順 5 の経路で主に聞く）。

#### Scenario: (4) に needs-decider の行がある

- **WHEN** develop の SKILL.md (4) の G の return の分岐を読む
- **THEN** `needs-decider` の行があり、`dev-workflow:decider` をマージ可否と同じ「可否と根拠」の契約で起こすこと、入力（記録先の本文・関連コメント・同じ型の指摘と前の周の指摘・対象ファイル・仕分け欄・W の return）、返答の 1 行目を `裁定: 可`／`裁定: 否`／`不足:` のどれかに指定しその 1 行目で分岐すること、可否を方式に読み替えること、裁定を SendMessage で G に返すこと、本体は裁定を代理投稿しないことが書かれており、代理投稿の一般則の記述にこの例外が書かれている

#### Scenario: 決める役が不足を返す

- **WHEN** 順 6 の依頼に対して、決める役の返答の 1 行目が `不足: <足りないもの>` である
- **THEN** 本体はそれを G に渡さず、足りないものを補って 1 回だけ依頼し直す。2 回目も不足なら「裁定なし（入力不足）」として G に渡す

#### Scenario: decider の契約を変えない

- **WHEN** この change の前後で `plugins/dev-workflow/agents/decider.md` を比べる
- **THEN** 差分が無い

### Requirement: G はレビュー経路を起動指示の 1 行で判別する
develop の本体は、(4) で G を起動する指示・再開する指示・手渡しで後任の G を起動する指示のすべてに、起動形を問わず**常に** `レビュー経路: adapter` の 1 行を書かなければならない（MUST）。条件付きにしてはならない（MUST NOT）。現行の develop は実行先の 3 つの起動形（自動選択・明示 profile・旧形式の account/model 指定）すべてを adapter（`codex-develop.py request`）で解決するため、develop の本体が G を起こす場面はすべて adapter 経路である。Codex の G に対しては、request の instructions（`--input` に渡す指示ファイル）が起動指示に当たり、そこにも同じ行を書かなければならない（MUST）。

`レビュー経路: 従来` は、develop の本体以外の呼び出し元が `gate-runner.md` で G を起こす場合と、行を書かない古い本体のための値であり、develop の本体は書いてはならない（MUST NOT）。

`gate-runner.md` は、新しい G が起動指示の `レビュー経路:` 行だけで経路を判別し、環境変数・記録先のコメント・自分の起動方法から推測しないことを書かなければならない（MUST）。`レビュー経路: adapter` で起動された同一の G は、その後の再開指示に `レビュー経路:` 行が無くても adapter 経路のまま動かなければならない（MUST）。行が無いときに従来経路として扱う規則は、新しい G の起動指示（手渡しで起こされた後任 G の起動指示を含む）に行が無かった場合にだけ適用しなければならない（MUST）。あわせて、`レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成（`claude-default` を含む）を指し、従来モードのレビュー実行者の表は `レビュー経路: 従来`、または行の無い起動指示で開始された G にだけ適用すると書かなければならない（MUST）。`SKILL.md` は、G の起動・再開指示に常に `レビュー経路: adapter` を書く本体の責任を、Role profile の選択節と (4) の両方に書かなければならない（MUST）。

`codex-develop.md` は、行が無い fresh G を従来経路として扱う説明を executor ごとに分け、Claude の G は full で Codex を直接呼び、Codex の G は prompt の禁止により Codex を直接呼ばないことを書かなければならない（MUST）。経路の既定と executor に許された操作を同一視してはならない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、呼び出し元から G へ渡される起動指示と再開指示である。防ぐ誤りは、adapter 経路で起動済みの同一 G が、再開指示で `レビュー経路:` 行が欠落したために従来経路へ切り替わることと、従来経路の Codex G が provider の禁止を越えて別の Codex を直接呼ぶことである。一方、行の無い指示で新しい G または手渡し後の後任 G が起動された場合に従来経路として扱うこと、従来経路の Claude G が Codex を直接呼ぶことは許容される。任意の不正入力や将来の executor へ対応を際限なく追加することは、この要件の完了条件としない。

#### Scenario: 自動選択での G 起動
- **WHEN** 本体が自動選択（profile も旧形式も無指定）で develop を進め、(4) で G を起動する
- **THEN** G の起動指示に `レビュー経路: adapter` の行があり、G はこの行を見て adapter 経路の規則に従う

#### Scenario: 明示 profile で Codex の G を起動
- **WHEN** 本体が明示 profile で develop を進め、phase `gate` の投げ先が Codex で request を作る
- **THEN** request の instructions に `レビュー経路: adapter` の行がある

#### Scenario: 行が無い Claude G 起動
- **WHEN** `レビュー経路:` の行を含まない起動指示で新しい Claude の G（手渡しで起こされた後任 G を含む）が起動される
- **THEN** G は従来経路として扱い、full では Bash から Codex を直接呼ぶ

#### Scenario: 行が無い Codex G 起動
- **WHEN** `レビュー経路:` の行を含まない起動指示で新しい Codex の G（手渡しで起こされた後任 G を含む）が起動される
- **THEN** G は従来経路として扱うが、prompt の禁止に従って Codex を直接呼ばず `needs-reviewer` を返す

#### Scenario: adapter 経路で起動済みの G を行無しで再開
- **WHEN** `レビュー経路: adapter` で起動された同一の G が、`レビュー経路:` の行を含まない指示で再開される
- **THEN** G は adapter 経路のまま動き、従来経路へ切り替わらない

#### Scenario: 手渡し後の G 再開
- **WHEN** 本体が G を SendMessage で再開する、または手渡しで後任の G を起動する
- **THEN** その指示にも `レビュー経路: adapter` の行がある

### Requirement: adapter 経路の G はレビュアーを自分で呼ばず needs-reviewer を返す
`gate-runner.md` の冒頭にある本体からの入力一覧は、PR 番号・記録先・実行モードに加えて `レビュー経路:` の 1 行を含み、adapter 経路でレビュー要約を受けて再開するときは、選ばれた executor / model と dispatch 記録のコメント URL も入力に含むことを書かなければならない（MUST）。

`gate-runner.md` は、G（phase `gate` として起動された G）が `レビュー経路: adapter` のとき、full でも light でも `codex exec`・`codex-companion.mjs`・レビュアーを自分で呼ばず、手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）を済ませ、同一 PR/HEAD で他の G が着手済みでないことを確認してから `needs-reviewer` を返すことを書かなければならない（MUST）。full のときの payload の判定は `full（adapter 経路）` とし、Codex 不可の実測を行わないことを書かなければならない（MUST）。adapter 経路の payload では `選んだ経路`・`実行コマンド`・`終了コード`・`出力の要点`・`実待ち時間` を `未実行（adapter 経路）` と書き、Codex の証拠を作らないことを書かなければならない（MUST）。`pr-review-gate/SKILL.md` の PR コメント雛形も、この 5 欄すべての閉じた列挙に `未実行（adapter 経路）` を含めなければならない（MUST）。

この規則は phase `review` のレビュアーとして起動されたときには適用しないと限定しなければならない（MUST）。従来経路の Claude G の既定（full は G の Bash から Codex を直接呼び、Codex が使えないときと light のときだけ `needs-reviewer` を返す）は変えてはならない（MUST NOT）。従来経路の Codex G は prompt の禁止に従って別の Codex を直接呼んではならない（MUST NOT）。

この要件で検査する入力は、G の起動・再開指示、同一 PR/HEAD の着手記録、G が返す payload である。拾う誤りは、経路や再開情報の入力漏れ、同じ PR/HEAD への review dispatch の重複、adapter 経路なのに Codex を実行したような証拠を作ることである。fresh G の行無し指示を従来経路として扱うこと、adapter 経路で 5 欄を明示的な未実行として通すことは許容する。任意の malformed な指示や分散実行のすべての競合を塞ぎ切ることは完了条件としない。

#### Scenario: G の入力一覧が経路と再開情報を含む
- **WHEN** `gate-runner.md` 冒頭の「本体が渡すもの」を読む
- **THEN** `レビュー経路:` の 1 行が含まれ、adapter 経路の再開時は executor / model と dispatch 記録のコメント URL をレビュー要約に含める、と書かれている

#### Scenario: adapter 経路の full レビュー
- **WHEN** `レビュー経路: adapter` で起動された G が手順 2-0 で full と判定する
- **THEN** G は同一 PR/HEAD で他の G が着手済みでないことを確認し、Codex を起動せず、判定 `full（adapter 経路）`・HEAD SHA・受け入れ条件の所在を含み、実行の証拠欄が `未実行（adapter 経路）` の `needs-reviewer` を返す

#### Scenario: adapter 経路の証拠欄をコメント雛形で選べる
- **WHEN** `pr-review-gate/SKILL.md` の PR コメント雛形を読む
- **THEN** `選んだ経路`・`実行コマンド`・`終了コード`・`出力の要点`・`実待ち時間` の 5 欄すべてで `未実行（adapter 経路）` を選べる

#### Scenario: 従来経路の Claude G による full レビュー
- **WHEN** `レビュー経路: 従来` で起動された Claude の G が手順 2-0 で full と判定する
- **THEN** G は Bash から `codex exec` または `codex-companion.mjs` で Codex を呼ぶ

#### Scenario: 従来経路の Codex G による full レビュー
- **WHEN** `レビュー経路: 従来` で起動された Codex の G が手順 2-0 で full と判定する
- **THEN** G は prompt の禁止に従って Codex を直接呼ばず `needs-reviewer` を返す

#### Scenario: phase review のレビュアーが gate-runner.md を読む
- **WHEN** Codex に委譲された phase `review` のレビュアーが `gate-runner.md` を読む
- **THEN** adapter 経路の `needs-reviewer` 規則は G 向けに限定されており、レビュアーは自分でレビューを行う

### Requirement: 本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する
`SKILL.md` の (4) は、adapter 経路で G から `needs-reviewer` を受けた本体の手順として、次の順序を書かなければならない（MUST）: `codex-develop.py request --phase review` で投げ先を選び直す（実行先オプションはその develop の開始時と同じ）→ 返った選択（構成・reason・Claude と最良 Codex の margin・各 `fetched_at`。欠測は `missing`）と解決した executor / model を記録先の dispatch 記録に投稿する → 投稿に成功してから、選ばれた投げ先でレビュアーを起動する → レビュー要約と、選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。

review phase の executor が `codex` のときは、本体は worker の結果 JSON にある `execution.model_resolution.requested` と `execution.model_resolution.resolved` も G に渡さなければならない（MUST）。G は `レビュー実行者:` 行の `<model>` を `<requested>→<resolved>` の形で記録しなければならない（MUST）。解決値が未観測のときは要求値や dispatch 時の model から補完してはならない（MUST NOT）。

渡し方は G の起動形で分けて書かなければならない（MUST）: Claude の G は SendMessage で再開して渡す（`gate-runner.md`「needs-reviewer の return」節と `SKILL.md` の (4) の既存規則）。Codex の G は新しい phase `gate` を開始してその入力に渡す（`codex-develop.md`「品質と transport 差分」の G の項）。

本体は選び直しと記録の前にレビュアーを起動してはならない（MUST NOT）。従来経路（`レビュー経路: 従来` または行が無い G）が `needs-reviewer` を返したときに呼び出し元がレビュアーを起こす手順（`gate-runner.md` の既存記述）は変えてはならない（MUST NOT）。

`gate-runner.md` と `pr-review-gate/SKILL.md` は、adapter 経路で要約を受け取った G の「レビュー実行者:」コメントの形 `レビュー実行者: <executor>/<model>（adapter 経路・<light|full>・dispatch 記録: <URL>）` を持たなければならない（MUST）。`<light|full>` には手順 2-0 の判定を書く。executor が `codex` なら `<model>` は `execution.model_resolution.requested` と `resolved` を使った `<requested>→<resolved>` とし、executor が `claude` なら従来の model 値を使う。`pr-review-gate/SKILL.md` の「レビュー実行者:」の書き分けと PR コメント雛形にこの 1 形を足し、gate-runner.md と正本が食い違わないようにしなければならない（MUST）。

#### Scenario: claude-default が選ばれる
- **WHEN** adapter 経路（自動選択）で G が `needs-reviewer` を返し、`request --phase review` が構成 `claude-default`・executor `claude`・model `opus` を返す
- **THEN** 本体は構成・reason・両 provider の margin と `fetched_at` を記録先に投稿してから、Agent ツールで `opus` のレビュアーを起動し、Codex を呼ばない。要約を渡すとき `claude/opus` と dispatch 記録の URL も G に渡す

#### Scenario: Codex が選ばれる
- **WHEN** adapter 経路で `request --phase review` が executor `codex` の request を返し、worker の結果 JSON の `execution.model_resolution` が requested=`sol`、resolved=`gpt-6-sol` を返す
- **THEN** 本体は選択を記録先に投稿してから request を実行し、レビュー要約・dispatch 記録 URL とともに requested=`sol`、resolved=`gpt-6-sol` を G に渡す

#### Scenario: G がレビュー実行者を記録する
- **WHEN** adapter 経路の G が本体から Codex レビュー要約と requested=`sol`、resolved=`gpt-6-sol`、dispatch 記録の URL を受け取る
- **THEN** G は `レビュー実行者: codex/sol→gpt-6-sol（adapter 経路・<light|full>・dispatch 記録: <URL>）` の PR コメントを投稿し、その埋め方は `pr-review-gate/SKILL.md` の雛形にも説明される

#### Scenario: 回帰テスト
- **WHEN** `bash scripts/test.sh` を実行する
- **THEN** `gate-runner.md`・`SKILL.md`・`codex-develop.md`・`pr-review-gate/SKILL.md` の上記文言を照合する bats を含めて exit 0 になる

### Requirement: epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、サブコマンド `route`・`launch`・`wait` を持たなければならない（MUST）。どのサブコマンドも LLM を呼んではならない（MUST NOT）。

`route <child>...` は、引数の子が 2 件以上あり、`orca` コマンドが PATH にあり、かつ `orca worktree current` が exit 0 で終わる（今いるディレクトリが Orca 管理のワークツリー）ときだけ stdout に `orca` の 1 行を出し、それ以外は `subagent` の 1 行を出して exit 0 で終わらなければならない（MUST）。子の番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。

`launch [--note <text>] [--base <branch>] <epic> <child>...` は、次の順で呼び出さなければならない（MUST）: `orca worktree current --json`（今の repo の `repoId` を得る）→ `git rev-parse --show-toplevel` → `git fetch origin <base>` → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` → 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --agent claude --prompt <prompt> --json`。`<親>` は `git rev-parse --show-toplevel` で求めた親ワークツリーの絶対パスで、親の指定は create と set の両方で `path:` を使わなければならない（MUST。`worktree:<id>` は set で `selector_not_found` になるため）。`<base>` の既定は `main` で、環境変数 `EPIC_DISPATCH_BASE` で既定を変えられ、`--base` が環境変数より優先する（MUST）。`<prompt>` は `/develop #<N>` で始まり、エピック番号を含み、`--note` があればその文を含む（SHALL）。一覧に、同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出さなければならない（MUST。再開時や取り違えで同じ子を二重に起動しないため）。`orca` が PATH に無いときは何も呼ばずに exit 1 で終わり、`orca worktree current`・`git fetch`・`orca worktree set`・`orca worktree list` のどれかが失敗したとき（`jq` が無くて一覧を読めないときを含む）は子を 1 件も作らずに exit 1 で終わらなければならない（MUST）。stdout には子ごとに `launched <N>`・`skipped <N>`・`failed <N>` のどれか 1 行だけを出し、`orca` 自身の出力は stderr に流す（SHALL）。1 件の失敗で残りの子の起動を止めず、`failed` が 0 件なら exit 0、1 件でもあれば exit 1 で終わる（MUST）。

`wait [--interval <sec>] [--timeout <sec>] <child>...` は、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` で state を確かめるポーリングを繰り返し、stdout にちょうど 1 行を出して終わらなければならない（MUST）。子ごとの結果は、出力が `closed` なら閉じている、`open` なら開いている、`gh` が非 0 で終わったか出力がそれ以外（空文字を含む）なら失敗とする（MUST）。1 件以上の子が閉じていれば `closed <N>...`（閉じていた子の番号）で exit 0、上限時間に達したら `timeout <N>...`（閉じていない子の番号）で exit 2、失敗したポーリングが 3 回続いたら `error gh <N>...`（3 回目で失敗した子の番号）で exit 1 で終わる（MUST）。失敗したポーリングとは、1 件以上の子が失敗し、かつ閉じた子が 1 件も無いポーリングを言い、一部の子だけが失敗してほかの子が `open` の場合も含む（MUST）。失敗の無いポーリングがあれば数え直す（SHALL）。閉じた子がいるポーリングでは、ほかの子の失敗より `closed` を優先する（SHALL）。間隔と上限は秒で、既定は間隔 300・上限 21600、環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する（MUST）。ポーリングのあとで経過時間が上限に達しているか、経過時間と間隔の和が上限を超えるなら、眠らずに `timeout` で終わる（MUST。`--timeout 0` は間隔によらず 1 回だけ確かめて終わる）。子が 0 件、番号が数字でない、間隔・上限が非負整数でないときは stderr に使い方を出して exit 1 で終わる（SHALL）。

この要件の守備範囲で入力として扱うのは、本体（LLM）が依存グラフから求めた子の番号と、SKILL.md の手順どおりに付けるフラグである。人が手で打つことは想定しない。引数の検査で拾う誤りは、番号の取り違えで引数が空になること、`#12` のように番号に記号が付くこと、フラグ値の打ち間違いである。数字でさえあれば、存在しない issue 番号・重複した番号・blocked されている子の番号は通してよく（`route` は依存を検証しない。存在しない番号は `wait` の失敗したポーリングとして数えられ `error` で表に出る）、非常に大きい `--timeout` も通してよい。検査をすり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。`orca worktree list --json` の出力は確かめた形（`.result.worktrees[]` の `repoId`・`linkedIssue`・`isArchived`）のとおりと信じ、形が変わったときの検知は範囲外とする。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、呼び出しの引数と順序、stdout の 1 行と exit code を確かめなければならない（MUST）。テストの途中に素の `[[ ]]` を置いてはならない（MUST NOT。bash 3.2 では偽でも素通りする）。

#### Scenario: orca が無い環境ではサブエージェント方式になる
- **WHEN** `orca` が PATH に無い環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: orca はあるが Orca 管理外のワークツリーならサブエージェント方式になる
- **WHEN** `orca` が PATH にあり `orca worktree current` が exit 1 を返す環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: 並列にできる子が 1 件ならサブエージェント方式になる
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: 並列にできる子が 2 件以上で Orca 管理下なら Orca 経路になる
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: launch は fetch してから path: で親を渡して子を作る
- **WHEN** 一覧に子のワークツリーが無いスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 呼び出しの記録は `orca worktree current --json`、`git rev-parse --show-toplevel`、`git fetch origin main`、`orca worktree set --worktree path:<親> --issue 400`、`orca worktree list --json`、子 11 と子 12 の `orca worktree create`（それぞれ `--name issue-<N> --issue <N> --base-branch origin/main --parent-worktree path:<親> --agent claude --prompt "/develop #<N> ..."`）の順で、stdout は `launched 11` と `launched 12`、exit 0

#### Scenario: 起点のブランチを変えられる
- **WHEN** `EPIC_DISPATCH_BASE=develop` のスタブ環境で `epic-dispatch.sh launch --base trunk 400 11` を実行する
- **THEN** `git fetch origin trunk` と `--base-branch origin/trunk` で呼ばれる

#### Scenario: 起動済みの子は作らない
- **WHEN** 一覧に同じ `repoId` で `linkedIssue` が 11 の archive されていないワークツリーがあるスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** 子 11 の `orca worktree create` は呼ばれず、stdout は `skipped 11` と `launched 12`、exit 0

#### Scenario: fetch に失敗したら子を作らない
- **WHEN** `git fetch` が失敗するスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** `orca worktree create` は 1 回も呼ばれず、exit 1

#### Scenario: orca が無い環境では launch は何も呼ばない
- **WHEN** `orca` が PATH に無い環境で `epic-dispatch.sh launch 400 11 12` を実行する
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

