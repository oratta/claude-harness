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
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 → (1) W が仕様化判断の記録・分割判定・openspec CLI による change の作成（`openspec new change` と artifact の直書き）まで行い return（仕様化しない判定なら (3) へ直行）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（2 周キャップ。超えたら `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) 実装（`tasks.md` を TDD で。直行なら TDD）・verify（`openspec validate --strict`）まで行って return、本体が計測し、W の return の `画面確認:` の行が `要る` なら画面確認役 V を起こしてから（下の「画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす」Requirement）、(3b) `openspec archive`・PR を Draft のまま用意（無ければ Draft で作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → (4) G が pr-review-gate の手順 1〜5 を実行し `passed` / `failed` / `保留` / `needs-reviewer` / `needs-decider` / `review-incomplete` のいずれかを return。PR の Ready 化は G が手順 5 の合格処理で行い（Draft なら Ready にしてから `agent-review:passed` を付ける）、W は行ってはならない（MUST NOT）。

G が `review-incomplete` を return したとき、本体は新しい reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止めなければならない（MUST）。`needs-reviewer` が一周目照合の補足要求である場合、本体は fresh reviewer に固定 HEAD・元の三表・残差・補足済み回数を渡し、同じレビューの不足分だけを補わせなければならず（MUST）、レビューを最初からやり直させてはならない（MUST NOT）。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら実行役を `opus` に上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く。**W を `fable` で再開してはならない**（MUST NOT。実行役の上限は `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。修正後は G を再開して差分再レビュー（2 周）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

worktree は本体が用意する（SHALL）: 本体が既に対象専用の worktree にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。W は自分で worktree を切らない（MUST NOT。セットアップは worktree プラグインの hooks が担い、`.worktreeinclude` が無いときの `/wt-setup` は本体が行う）。**W / G を `isolation: "remote"` で起こしてはならない**（MUST NOT）。強制停止に当たったサブエージェントの未コミット差分は本体が確認して commit する設計（下の「強制停止で止まった作業ツリーは本体が引き取る」Requirement）だが、`remote` 隔離は本体から見えない環境で動くため、そこで強制停止に当たると作業がそのまま失われる。

`/opsx:*` のスラッシュコマンドは、本体や主が対話で change を作る場面の道具として SKILL.md に書いてよい（MAY）が、W が実行する工程として 1 ループに書いてはならない（MUST NOT。W の種別 `dev-workflow:worker` は `Skill` を持たない）。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、(1) の W の工程に `openspec new change` があり、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ 2 周キャップがある

#### Scenario: (3) は 2 段に分かれて書かれている
- **WHEN** SKILL.md の 1 ループの (3) を読む
- **THEN** (3a) と (3b) が別々の return として並び、(3a) に TDD の実装と `openspec validate --strict` が、(3b) に `openspec archive`・PR・仕様宣言が入り、(3a) と (3b) の間に V を起こす分岐がある

#### Scenario: 1 ループに W が /opsx を実行する工程が無い
- **WHEN** SKILL.md の 1 ループの節を読む
- **THEN** `/opsx:ff`・`/opsx:apply`・`/opsx:verify`・`/opsx:archive` の文字列が無い

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

**回し方（Orca 経路）**: 本体は `epic-dispatch.sh launch` で子ごとに Orca の子ワークツリーを作り、子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回す（本体は子の W / R1 / G を起こさない）。再開時も、依存が解けた open の子を `launch` に渡し、起動済みの子は `launch` の `skipped` で見分ける（同じ子を二重に起動しない）。本体は `launch` が `launched` / `skipped` を出した子を動いている子とし、`epic-dispatch.sh wait` を Bash の `run_in_background: true` で起動して待ち、終わって起こされたら出力の 1 行で次を決める。`closed` なら閉じた子ごとに `state_reason` を読み、`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントして依存グラフを読み直し、解けた子を件数にかかわらず `launch` する。`completed` 以外ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子を起動してはならず（MUST NOT）、ユーザーに報告する。そのあと残りの動いている子で再び `wait` する。`timeout` なら待っている子に `needs-approval` などの停止の兆候が無いかを見て、あればユーザーに報告し、報告したかどうかにかかわらず残りの動いている子で再び `wait` する。子が自分のタブでユーザーに質問して止まっている場合はこの確認では気づけないことを書く（SHALL）。`wait` の `error` と `launch` の `failed` はユーザーに報告して止まる。`launch` に失敗した子をサブエージェント方式に自動で振り替えてはならない（MUST NOT）。子セッションのモデルは `epic-dispatch.sh launch` が起動時に `cld --model` で指定し、既定は `opus` で環境変数 `EPIC_DISPATCH_MODEL` で変えられること（Claude Code の既定モデルは子に効かないこと）、コマンド部分（既定 `cld`）は環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ、Orca に設定したコマンドはハーネスから読めないので Orca 側のコマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変えることを書く（SHALL）。子セッションは `cld` が付ける `--dangerously-skip-permissions` で動き許可の確認画面が出ないこと（`epic-dispatch.sh` が足すのは `--model` だけであること）、マージを止めているのは develop と pr-review-gate の規則と hooks であることを書く（SHALL）。子の PR のマージは今までどおり子セッションの中で人の承認で行い、本体が自動でマージしてはならない（MUST NOT）。

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

#### Scenario: Orca 経路に子セッションのモデルの決め方が書かれている
- **WHEN** Orca 経路の説明を読む
- **THEN** 子セッションのモデルは `epic-dispatch.sh launch` が `cld --model` で指定すること、既定が `opus` であること、`EPIC_DISPATCH_MODEL` で変えられること、Claude Code の既定モデルが何であっても子は指定したモデルで起動すること、コマンド部分を `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ Orca 側のコマンドを変えたら合わせて変えること、`--dangerously-skip-permissions` を付けるのは `cld` であることが書かれている

### Requirement: 実行モードと unmanned の責務分割
SKILL.md は実行モード表（interactive / unmanned）を持ち、unmanned（`--unmanned`。loop-dev-agent の憲法 Step 3 から呼ばれる）では次を規定しなければならない（MUST）: develop の本体は憲法のメイン自身が務め、W / R1 をメインが spawn する。worktree は憲法側が用意したものを使う。1 ループのうち (0)〜(3) を回し、(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。(4) の G は unmanned では起こさず、憲法 Step 1（レビューモード）が次サイクル以降で担う（1 サイクル 1 仕事を維持）。複数 change に割れた場合は子 issue を作って `blocked_by` で順序付けし、そのサイクルを終える。仕様化判断の記録と仕様レビューは unmanned でも免除しない（MUST）。

#### Scenario: unmanned では G を起こさない
- **WHEN** SKILL.md の実行モード表を読む
- **THEN** unmanned では憲法のメインが本体を務めて W / R1 を spawn し、(3) で Draft PR と `agent-review:pending` まで W が行い、G は憲法 Step 1 に委ねると書かれている

### Requirement: 前提環境を明記する
SKILL.md は「前提」節として、Agent ツール（`model` 明示・名前付き spawn・`isolation: "worktree"`・W は `subagent_type: dev-workflow:worker`、G は `subagent_type: dev-workflow:gate-runner`）と SendMessage、`gh`（issue / PR コメントとラベル、issue dependencies API）、openspec CLI（W は CLI だけで仕様化経路を進め、経路の有無は `openspec --version` で決める。opsx コマンドは本体や主が対話で使う道具で、W の経路の有無を決めない。CLI が無ければ仕様化経路が発生しない）、Codex CLI（無ければ G が `needs-reviewer` に縮退）、`orca` コマンド（エピックの子を Orca の子ワークツリーで独立セッションとして起動する。無いとき、または本体が Orca 管理外のワークツリーにいるときは、エピックをサブエージェント方式で回す）を列挙しなければならない（MUST）。

#### Scenario: 前提節がある
- **WHEN** SKILL.md の「前提」節を読む
- **THEN** Agent / SendMessage / gh / openspec CLI / Codex CLI / orca とそれぞれ無いときの縮退が書かれ、Agent の行に W と G の種別が書かれ、openspec の行に W の経路の有無を `openspec --version` で決めることが書かれ、orca の行には Orca 管理外のワークツリーにいるときもサブエージェント方式になることが書かれている

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

- **(3a) 実装＋verify**: 実装（仕様化した場合は `tasks.md` を上から TDD で。直行なら TDD）と verify（仕様化した場合は `openspec validate <change> --strict` と `tasks.md` のチェックボックスが全部 `[x]` であることの確認）までを行い、`工程完了: 実装＋verify` を 1 行目にして return する
- **(3b) archive＋PR＋仕様宣言**: `openspec archive <change>`（仕様化した場合）・PR を Draft のまま用意すること（記録先が Draft PR ならそのまま使い、issue が記録先なら `gh pr create --draft` で作る。Ready には切り替えない）・仕様宣言を PR コメントに書くことを行い、`工程完了: archive＋PR＋仕様宣言` を 1 行目にして return する

境界は archive の手前に置き、verify は (3a) 側に含めなければならない（MUST）。verify の失敗は実装への巻き戻しであり、実装と verify を別の担い手に割ると手渡し直後に巻き戻しが起きるためである。

**(3) をこれより細かく（`tasks.md` の項目単位・「実装／verify／archive／PR／仕様宣言」の 5 段など）分割してはならない（MUST NOT）。** 手渡しが 1 回起きるたびに、後任は指示書と正本の節を読み直し、記録先を取り直し、`git status` / `git diff` でファイルの現状を確認する固定分を払う。この固定分は工程の大きさに依存しないため、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。また区切りが実装の途中に落ちると、後任は Red のまま止まったテストから再出発することになり、前任の設計意図を再発明する危険が最も高い地点で交代する。

`references/roles/worker.md` は (3a) と (3b) それぞれの return に何を書くかを列挙しなければならない（MUST）。(3a) は openspec CLI 経路（`tasks.md` を TDD で実装＋`openspec validate --strict`）・コード直行（TDD）のどちらの入口でも実装後に検査を実行するため、**worker.md は「全経路共通の大原則」に、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップを読み、検査コマンド（lint・test・ビルド等）と環境セットアップ（依存インストール等）を判別し、検査コマンドをすべて実行しなければならない（MUST）という指示を置かなければならない（MUST。経路それぞれに重複して書かない）**。例: `auto-merge.yml` や `revert-pr.yml` のように `pull_request` / `push` 以外のイベントで起動する運用系ワークフローは対象に含めない（MUST NOT）。コマンド名をこのリポジトリ固有の値（`scripts/test.sh` など）に固定してはならない（MUST NOT。develop は複数リポジトリで使われ、CI の構成はリポジトリごとに異なるため）。workflow ファイルが存在しない、または `run:` から検査コマンドを判別できないときは、慣例コマンド（`scripts/test.sh` 等）へのフォールバックを許容する（MAY）。手元にツールが無く実行できない検査（apt でプリインストールされた `shellcheck` 等）は「未導入」として実行結果と区別しなければならず、未導入を合格として扱ってはならない（MUST NOT）。**(3a) の return には、収集した検査コマンドの一覧・実行したテストコマンドと exit code（未導入の検査があれば未導入と明記）、および `openspec validate --strict` の exit code（仕様化した場合。直行した場合は「仕様化しないため verify なし」）と、画面確認の要否の行（「W の (3a) の return は画面確認の要否を 1 行で書く」Requirement）を含めなければならない（MUST）**。(3b) の担い手は pr-review-gate 手順 5 が照合する動作確認の証拠を書く必要があり、手渡しが起きた場合その証拠は前任の return からしか得られない（後任は前任の履歴を読めない）ためである。`openspec validate --strict` の exit code が無いと、(3b) の担い手は verify を通ったことを確認できないまま archive に進むことになる。CI 由来の検査コマンドをすべて return に含めることで、G がゲートを合格にしたあとに CI の一部（このリポジトリでは shellcheck）が落ち、W・レビュー・G をもう 1 周回す再発を防ぐ。

この要件の守備範囲で入力として扱うのは、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップである。拾いたい誤りは、CI が流す検査ジョブを W が取りこぼすこと（PR #489 の shellcheck）である。次は通ってよく、この要件では止めない: `matrix` / `services` / `env` / `if:` 条件により CI の実行環境と手元の実行結果が食い違うこと、CI ランナー固有の環境に依存する検査、環境セットアップの `run:` ステップを検査コマンドと誤って実行すること。取りこぼしが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。CI が実際に落ちるかどうかの最終確認は G が pr-review-gate の手順で CI の結論を見る（別の防波堤。メモリ「G は passed の前に CI を確認」）。

`skills/develop/SKILL.md` は、(3a) の return を受けてから (3b) を指示する SendMessage を送るまでのあいだに、本体が `scripts/subagent-context.sh <W の名前>` を実行してコンテキスト量を測ることを書かなければならない（MUST）。上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本である（再掲の禁止は既存の Requirement「コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く」が規定しており、ここでは重ねて規定しない）。

本体は次に指示する工程を、**自分が (3a) を指示したか (3b) を指示したかで決めなければならない**（MUST）。工程名の文字列照合で決めてはならない（MUST NOT）。(3a) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば、(3b) を指示せず (4) へ進まなければならない（MUST）。古いキャッシュの `worker.md` を読んだ W は (3a) の指示を受けても (3) を通しで終えて返してくるため、文字列照合で routing すると PR の作成と仕様宣言の投稿が二重に走るためである。

#### Scenario: worker.md が (3a) / (3b) の return 内容を列挙している
- **WHEN** `references/roles/worker.md` の実装以降の節を読む
- **THEN** (3a) と (3b) がそれぞれ別の見出し（または別の箇条）として立っており、(3a) に `openspec validate` があり `/opsx:` が無く、(3a) が CI workflow 定義から検査コマンドを収集してすべて実行する義務と、return に収集した検査コマンド一覧・実行したテストコマンドと exit code（未導入の検査は未導入と明記）・`openspec validate --strict` の exit code・`画面確認:` の行を含める義務が書かれ、(3b) に `openspec archive` があり `/opsx:` が無く、(3b) の return に PR 番号と仕様宣言のコメント URL を含める義務が書かれている

#### Scenario: CI の定義から検査コマンドを収集する指示が全経路共通の節にある
- **WHEN** `references/roles/worker.md` の「全経路共通の大原則」の節を読む
- **THEN** PR・push で起動する `.github/workflows/*.yml` / `*.yaml` の `run:` から検査コマンドを拾うこと（`auto-merge.yml` 等の運用系ワークフローは対象外）、コマンド名をリポジトリ固有の値に固定しないこと、拾った検査コマンドをすべて実行すること、workflow が無い場合の慣例コマンドへのフォールバックが許容されること、ツール未導入は「未導入」として合格と区別することが書かれており、この指示が (3a)「コード直行する場合」手順 5 だけでなく openspec CLI 経路にも及ぶ 1 箇所にまとまっている

#### Scenario: 守備範囲が明記されている
- **WHEN** `references/roles/worker.md` の全経路共通の大原則の節、CI 検査コマンドの収集を指示する段落を読む
- **THEN** 入力の出どころ（PR・push で起動する workflow の `run:` ステップ）、拾いたい誤り（CI の検査ジョブの取りこぼし。PR #489 の shellcheck）、通ってよい入力（`matrix` / `services` / `env` / `if:` 条件による CI と手元の再現差、ランナー依存の検査、環境セットアップの `run:` ステップの誤実行）、取りこぼしを塞ぎ切ることを完了条件にしない旨（最後の防波堤は G の CI 結果確認）が書かれている

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

`launch [--note <text>] [--base <branch>] <epic> <child>...` は、次の順で呼び出さなければならない（MUST）: `orca worktree current --json`（今の repo の `repoId` を得る）→ `git rev-parse --show-toplevel` → `git fetch origin <base>` → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` → 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --json` → `orca terminal create --worktree path:<子> --command <cmd> --json` → `orca terminal wait --terminal <handle> --for tui-idle --timeout-ms <ready> --json` → `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json`。worktree create に `--agent` と `--prompt` を渡してはならない（MUST NOT。`--agent` で起動すると子セッションのモデルを指定できず Claude Code の既定モデルで動くため。`--prompt` は Orca 1.4.209 では指示が子の入力欄に届かず、送信と併用すると指示が 2 回届くおそれがあるため）。`<子>` は worktree create の JSON 出力の `result.worktree.path` とする（MUST）。`<cmd>` は `<claude-cmd> --model <model>` で（`--dangerously-skip-permissions` などの許可に関わる引数は付けてはならない（MUST NOT）。付けるのは `<claude-cmd>` 側に任せる）、`<claude-cmd>` の既定は `cld` で環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で変えられ、クォートせずそのまま置く（MUST。`--command` の文字列は Orca が開いたログインシェルに打ち込まれるのでシェル関数も解決され、`cld-account b` のような引数付きも書けるため）。`<model>` はシェルに打ち込まれても 1 語のまま渡るよう単一引用符で囲む（MUST。`opus[1m]` のような値がグロブとして解釈されないため）。`<model>` の既定は `opus` で、環境変数 `EPIC_DISPATCH_MODEL` で変えられる（MUST）。`<handle>` は terminal create の JSON 出力の `result.terminal.handle` とする（MUST）。`<ready>` の既定は 60000（ミリ秒）で環境変数 `EPIC_DISPATCH_READY_TIMEOUT_MS` で、`<submit>` の既定は 30（秒）で環境変数 `EPIC_DISPATCH_SUBMIT_WAIT` で変えられる（SHALL）。`<親>` は `git rev-parse --show-toplevel` で求めた親ワークツリーの絶対パスで、親の指定は create と set の両方で `path:` を使わなければならない（MUST。`worktree:<id>` は set で `selector_not_found` になるため）。`<base>` の既定は `main` で、環境変数 `EPIC_DISPATCH_BASE` で既定を変えられ、`--base` が環境変数より優先する（MUST）。`<prompt>` は `/develop #<N>` で始まり、エピック番号を含み、`--note` があればその文を含む（SHALL）。子を `launched <N>` とするのは、worktree create が exit 0 で終わり、子のワークツリーのパスが取れ、terminal create が exit 0 で終わり、ハンドルが取れ、`terminal wait` が exit 0 で終わり、`terminal send` が exit 0 で終わってその JSON 出力のどこかの `stages` 配列に `turn_started` が含まれるときだけでなければならない（MUST）。どれか 1 つでも満たさなければ `failed <N>` とし（MUST）、子のワークツリーのパスが取れていてハンドルが取れていなければ（terminal create の失敗を含む）、端末を手で起動し直すための `orca terminal create --worktree path:<子> --command <cmd> --json` を stderr に出すに続けて、最初の指示を送るための `orca terminal send --terminal <作り直した端末のハンドル> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出す（SHALL。ワークツリーは残るので、再実行ではその子は `skipped <N>` になり端末が作られないため）。ハンドルが取れていれば、指示を手で送り直すための `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出し、あわせて「送る前に `orca terminal read --terminal <handle>` で入力欄とターンの状態を確かめる」旨の案内を出す（SHALL。送信が非 0 やターン未観測で終わっても指示が届いていることがあり、確かめずに送ると 2 回届くため）。`terminal send` の JSON 出力に送り直し用の ID（キー `retryRequestId` または `retryRequest` の文字列値）があれば、送り直しのコマンドに `--retry-request <id>` を付ける（SHALL）。ワークツリーは残すので、再実行ではその子は `skipped <N>` になり、指示を送り直さない（SHALL）。一覧に、同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出さなければならない（MUST。再開時や取り違えで同じ子を二重に起動しないため）。`orca` が PATH に無いときは何も呼ばずに exit 1 で終わり、`orca worktree current`・`git fetch`・`orca worktree set`・`orca worktree list` のどれかが失敗したとき（`jq` が無くて一覧を読めないときを含む）は子を 1 件も作らずに exit 1 で終わらなければならない（MUST）。stdout には子ごとに `launched <N>`・`skipped <N>`・`failed <N>` のどれか 1 行だけを出し、`orca` 自身の出力は stderr に流す（SHALL）。1 件の失敗で残りの子の起動を止めず、`failed` が 0 件なら exit 0、1 件でもあれば exit 1 で終わる（MUST）。

`wait [--interval <sec>] [--timeout <sec>] <child>...` は、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` で state を確かめるポーリングを繰り返し、stdout にちょうど 1 行を出して終わらなければならない（MUST）。子ごとの結果は、出力が `closed` なら閉じている、`open` なら開いている、`gh` が非 0 で終わったか出力がそれ以外（空文字を含む）なら失敗とする（MUST）。1 件以上の子が閉じていれば `closed <N>...`（閉じていた子の番号）で exit 0、上限時間に達したら `timeout <N>...`（閉じていない子の番号）で exit 2、失敗したポーリングが 3 回続いたら `error gh <N>...`（3 回目で失敗した子の番号）で exit 1 で終わる（MUST）。失敗したポーリングとは、1 件以上の子が失敗し、かつ閉じた子が 1 件も無いポーリングを言い、一部の子だけが失敗してほかの子が `open` の場合も含む（MUST）。失敗の無いポーリングがあれば数え直す（SHALL）。閉じた子がいるポーリングでは、ほかの子の失敗より `closed` を優先する（SHALL）。間隔と上限は秒で、既定は間隔 300・上限 21600、環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する（MUST）。ポーリングのあとで経過時間が上限に達しているか、経過時間と間隔の和が上限を超えるなら、眠らずに `timeout` で終わる（MUST。`--timeout 0` は間隔によらず 1 回だけ確かめて終わる）。子が 0 件、番号が数字でない、間隔・上限が非負整数でないときは stderr に使い方を出して exit 1 で終わる（SHALL）。

この要件の守備範囲で入力として扱うのは、本体（LLM）が依存グラフから求めた子の番号と、SKILL.md の手順どおりに付けるフラグである。人が手で打つことは想定しない。引数の検査で拾う誤りは、番号の取り違えで引数が空になること、`#12` のように番号に記号が付くこと、フラグ値の打ち間違いである。数字でさえあれば、存在しない issue 番号・重複した番号・blocked されている子の番号は通してよく（`route` は依存を検証しない。存在しない番号は `wait` の失敗したポーリングとして数えられ `error` で表に出る）、非常に大きい `--timeout` も通してよい。検査をすり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。`EPIC_DISPATCH_READY_TIMEOUT_MS` と `EPIC_DISPATCH_SUBMIT_WAIT` は非負の整数でなければ stderr に使い方を出し、子を 1 件も作らずに exit 1 で終わる（SHALL。`--interval` と同じ扱いで、上限は設けない）。`EPIC_DISPATCH_MODEL` か `EPIC_DISPATCH_CLAUDE_CMD` が設定されていて空文字のときも stderr に使い方を出し、子を 1 件も作らずに exit 1 で終わる（SHALL。空でない値はそのまま使い、モデル名やコマンドとしての正しさは検査しない）。worktree create の JSON 出力の `result.worktree.path` と terminal create の JSON 出力の `result.terminal.handle` は 2026-09-25 の実機での出力の形のとおりと信じ、`terminal send` の JSON 出力の `stages` 配列と `turn_started` の語は、2026-09-24 の実機での出力の形のとおりと信じ、読めないときは `failed` として表に出すだけで、形の変化そのものの検知は範囲外とする。`orca worktree list --json` の出力は確かめた形（`.result.worktrees[]` の `repoId`・`linkedIssue`・`isArchived`）のとおりと信じ、形が変わったときの検知は範囲外とする。

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
- **THEN** 呼び出しの記録は `orca worktree current --json`、`git rev-parse --show-toplevel`、`git fetch origin main`、`orca worktree set --worktree path:<親> --issue 400`、`orca worktree list --json`、子ごとに `orca worktree create`（`--name issue-<N> --issue <N> --base-branch origin/main --parent-worktree path:<親> --json`。`--agent` も `--prompt` も含まない）、`orca terminal create --worktree path:<子> --command "cld --model 'opus'" --json`、`orca terminal wait --terminal <handle> --for tui-idle`、`orca terminal send --terminal <handle> --text "/develop #<N> ..." --enter --wait-submit 30 --json` を子 11・子 12 の順に繰り返し、stdout は `launched 11` と `launched 12`、exit 0

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

### Requirement: エピックの並列起動は 1 段で止める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子セッションを起動する端末のコマンドの先頭に `EPIC_DISPATCH_PARENT_EPIC=<epic>` を置かなければならない（MUST。`<epic>` は `launch` に渡したエピック番号）。コマンド全体は `EPIC_DISPATCH_PARENT_EPIC=<epic> <cmd> --model <model>` の形になり、端末を作れなかった子について stderr に出す `orca terminal create --command ...` の作り直しのコマンドにも同じ前置きが入る（SHALL）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の出力の規定、`<cmd>` の形の規定、および Scenario「EPIC_DISPATCH_MODEL…」「EPIC_DISPATCH_CLAUDE_CMD…」の `--command` の値に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

環境変数 `EPIC_DISPATCH_PARENT_EPIC` が空でない環境では:

- `route <child>...` は、子の番号の検査（数字でなければ使い方を出して exit 1）のあと、子の件数・`orca` の有無・`orca worktree current` の結果によらず stdout に `nested` の 1 行を出して exit 0 で終わらなければならない（MUST）。`orca` を呼んではならない（MUST NOT）
- `launch` は、引数の検査（既存の使い方の誤り）のあと、`orca` と `git` を 1 つも呼ばず、stderr に親エピックの番号と展開しない旨を出して exit 1 で終わらなければならない（MUST。子ワークツリーを作らない）。stdout には何も出さない（SHALL）
- `wait` の振る舞いは変えない（SHALL）

develop の SKILL.md「エピックの扱い」は次を規定しなければならない（MUST）。

- **エピックの子を外す**: 本体は依存グラフから求めた blocked されていない子のうち、sub-issue を持つ子（`gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` が 1 以上。`null` や空は 0 とみなす）をエピックとして外し、`route`・`launch`・サブエージェント方式のどれにも渡してはならない（MUST NOT）。経路が `nested` でないと確定したら（`route` が `nested` 以外を返したとき。`route` を呼ばない unmanned と、`回し方:` のコメントから経路を引き継いだ再開を含む）、外した子ごとにエピックへ `後で別に起動するエピック: #N` と 1 行コメントする（MUST）。再開時に `回し方:` のコメントから経路を引き継いだ場合も、`launch` に渡す前に同じ確認で外す（MUST）
- **`nested` を受けたセッション**: `route` が `nested` を返したら、そのセッションはエピックを展開してはならない（MUST NOT。Orca 経路もサブエージェント方式も使わない）。親エピック（`EPIC_DISPATCH_PARENT_EPIC` の番号）と自分の issue に `後で別に起動するエピック: #<自分の issue>` とコメントし、ユーザーに後で `/develop #<自分の issue>` を別に起動して回すと伝えて止まる（MUST）。自分の issue を閉じてはならない（MUST NOT）。`launch` が stderr に展開しない旨を出して exit 1 で終わったときも同じに扱い、「親ワークツリーで開き直す」とは報告しない（MUST NOT）
- **親の待ち受け**: Orca 経路の本体は、`timeout` と `closed` で起こされたときの確認で、エピックに `後で別に起動するエピック: #N` の行がある子を動いている子から外す（MUST）
- **親の完了報告**: 動いている子が無くなったときの本体の報告（エピックへのコメントとユーザーへの報告）に、エピックに記録した `後で別に起動するエピック:` の番号をすべて載せる（MUST）。子エピックが閉じるまで親エピックの完了条件は満たされないので、親エピックを閉じてはならない（MUST NOT）

この要件の守備範囲で入力として扱うのは、`launch` が子の端末のコマンドに前置きした `EPIC_DISPATCH_PARENT_EPIC`（子セッションの Claude Code とその Bash・サブエージェントに引き継がれる）、本体が依存グラフから求めた子の番号ごとの `sub_issues_summary.total`、エピックのコメントの `後で別に起動するエピック:` で始まる行である。拾いたい誤りは、並列起動された子のセッションが自分の issue をエピックとして孫のワークツリーとセッションを作ることである。次は通してよく、この要件では止めない: `EPIC_DISPATCH_PARENT_EPIC` の値は空でなければ数字かどうかを検査しない／人が手で `EPIC_DISPATCH_PARENT_EPIC` を付けて起動したセッションも `nested` になる／sub-issue を持たず本文で子を列挙しているだけのエピックは事前確認を通り、Orca 経路で起動された子なら子のセッションの `route` で止まり、サブエージェント方式で起こされた子（変数が無い）は止まらない／`回し方:` のコメントからサブエージェント方式を引き継いだ子エピックのセッションはスクリプトでは止まらない／この変更の前に起動された子セッションには変数が無く従来どおり展開しうる／`EPIC_DISPATCH_CLAUDE_CMD` が前置きの代入を受け付けない形（`exec` で始まる文字列など）のときは値が渡らない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`EPIC_DISPATCH_PARENT_EPIC` の前置き、`route` の `nested`、`launch` の拒否、SKILL.md の上の記述を確かめなければならない（MUST）。

#### Scenario: launch は子の端末のコマンドに親エピックの番号を前置きする
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` の無い環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=420 cld --model 'opus'` である

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
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** sub-issue を持つ子を外して `後で別に起動するエピック: #N` とコメントすること、`route` の `nested` を受けたら展開せず親エピックと自分の issue にコメントして止まること、`nested` と同じく `launch` の拒否でも止まり「親ワークツリーで開き直す」と報告しないこと、`timeout` と `closed` の確認でその行がある子を待つ対象から外すこと、完了報告に `後で別に起動するエピック:` の番号を載せることが書かれている

### Requirement: launch は同じ呼び出し内で渡された重複した子番号も skipped にする
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、引数に渡された子番号を先頭から処理する際、同じ呼び出しの中で既に `launched`・`skipped`・`failed` のいずれかとして処理済みの番号が再び現れたら、`orca worktree create` を呼ばずに `skipped <N>` を出さなければならない（MUST）。これは要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち「一覧に同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出す」規定（`spec.md:462`）を書き換えず、同じ `skipped <N>` の出力形のまま、判定基準に「同じ呼び出し内で既に処理済みの番号」を追加するものである。

この要件の守備範囲で入力として扱うのは、develop 本体（呼び出し元）が `launch` に渡す子番号の並びである。拾いたい誤りは、同じ呼び出しの中で同じ子番号を 2 回以上渡したときに `orca worktree create` が複数回呼ばれ、同じ子のセッションが二重に起動することである。許容例: `launch 420 11 11 11` は `launched 11` に続けて `skipped 11` を 2 回出す（3 回目以降も出現のたびに `skipped` を出せばよく、その回数を区別した出力は要求しない）。次は範囲外で、この要件では扱わない: 別の `launch` 呼び出しをまたいだ重複は既存のワークツリー一覧チェックによる `skipped`（`spec.md:462`）が担う／`011` と `11` のような表記揺れの正規化は行わず、引数の文字列としての一致だけを重複とみなす／`route` が重複した番号をそのまま通す既存の引数検査（`spec.md:466`）は変えない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、同じ呼び出し内で子番号を重複させたとき 2 回目以降が `orca worktree create` を呼ばずに `skipped` になることを確かめなければならない（MUST）。

#### Scenario: 同じ呼び出し内で重複した子番号は 2 回目以降 skipped になる
- **WHEN** 一覧に既存ワークツリーが無い環境で `epic-dispatch.sh launch 420 11 11` を実行する
- **THEN** `orca worktree create` は子 11 について 1 回だけ呼ばれ、stdout は `launched 11` と `skipped 11` を含む

#### Scenario: 一覧チェックによる skipped と同じ呼び出し内の重複による skipped は同じ形で出る
- **WHEN** 一覧に子 12 の既存ワークツリーがあり、かつ引数に子 11 を 2 回渡した状態で `epic-dispatch.sh launch 420 11 12 11` を実行する
- **THEN** stdout は `launched 11`・`skipped 12`・`skipped 11` の3行で、`orca worktree create` は子 11 について 1 回だけ、子 12 については 0 回呼ばれる

#### Scenario: 1 回目が failed でも 2 回目以降の重複は skipped になる
- **WHEN** `orca worktree create` が子 11 について失敗する環境で `epic-dispatch.sh launch 420 11 11` を実行する
- **THEN** stdout は `failed 11` と `skipped 11` の2行、`orca worktree create` は子 11 について 1 回だけ呼ばれ、`failed` が 1 件あるため exit code は 1

### Requirement: G が passed を返したら本体が CI を見張る
`skills/develop/SKILL.md` の (4) は、G が `passed` を return したあと、本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始めることを書かなければならない（MUST）。見張りの一手が `fix` のときは、本体が W に直させ（W の再開か手渡しかは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う）、W が push したら本体が passed を外したまま同じ状態ファイルで `wait` → `next` を続け（CI のやり直し・再度の直しもここで処理する）、`ready` になってから G を起こしてゲートを取り直させ、G が再び `passed` を返したら見張りの続き（reference の「`ready` を受けたあと」）に進むこと、合格するまでマージ待ち・マージ依頼に進まないことを書く（MUST）。見張りの中身は reference を参照し、SKILL.md に言い換えて再掲してはならない（MUST NOT）。

G の指示書 `skills/develop/references/roles/gate-runner.md` は、G が CI の見張りを始めずに `passed` を return することを書かなければならない（MUST）。unmanned モードは (4) を回さないので、この見張りの対象外とする。

#### Scenario: (4) の passed のあとに本体が見張る
- **WHEN** `skills/develop/SKILL.md` の (4) を読む
- **THEN** `passed` を受けた本体が `references/ci-watch.md` の手順で見張りを始めること、`fix` なら W に直させ、push のあと passed を外したまま `wait` → `next` を続けて `ready` になってから G にゲートを取り直させることが書かれている

#### Scenario: G は見張りを始めない
- **WHEN** `skills/develop/references/roles/gate-runner.md` を読む
- **THEN** G が CI の見張りを始めずに `passed` を return することが書かれている

### Requirement: G は段ごとに要るファイルだけを読む

`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` は、`skills/pr-review-gate/SKILL.md` を Read する指示を持ってはならない（MUST NOT）。pr-review-gate の手順 1〜5 を実行する義務の文は gate-runner.md に残さなければならない（MUST。既存要件「役割の指示書は references/roles/ に分かれている」と `develop-roles.bats` がその文を見る）。代わりに、G がどの時点でどのファイルを読むかを表で示さなければならない（MUST）。表は少なくとも次を含む: 起動したら `stages/prepare.md`、従来経路でレビューを自分で起動するときだけ `stages/review-run.md`、レビュー結果に指摘が残っていたら `stages/triage.md`、宣言を書く前に `declarations.md`、合格処理で `stages/pass.md`、主のリスク許容が要る・保留に入る・保留から再開するときは `stages/hold.md`。

gate-runner.md に残すのは、役割と入力、レビュー経路の判別、上の表、一周目の三表の機械照合と補足レビュー結果の受領、return の共通部分（1 行目の宣言と Gate Result の共通欄）、再開の振り分け、モデルとコンテキスト上限とする（MUST）。特定の段でしか使わない G の規則（needs-reviewer の payload、従来経路のレビュー実行者の表と Codex の起動、Status ごとの return 書式、再開のうち段に固有のもの）は、その段のファイルの「G として動くとき（develop）」節に置かなければならない（MUST）。

#### Scenario: SKILL.md 全体を読む指示が無い

- **WHEN** gate-runner.md を読む
- **THEN** `pr-review-gate/SKILL.md` を Read する指示が無く、pr-review-gate の手順 1〜5 を実行する義務の文と、段ごとに読むファイルの表がある

#### Scenario: return の書式が段のファイルにある

- **WHEN** `stages/pass.md`・`stages/triage.md`・`stages/hold.md`・`stages/prepare.md` の「G として動くとき」節を読む
- **THEN** それぞれに passed・failed / needs-decider / review-incomplete・保留・needs-reviewer の return 書式がある

#### Scenario: 読み込み量の実測

- **WHEN** この変更を develop で PR にし、`scripts/subagent-context-audit.sh --by-role` で G の `docs_median` を測る
- **THEN** 実測値とファイルごとの内訳が PR 本文に記録されている（目標は 15K トークン以下。超えたときは加えて follow-up issue の URL が記録されている）

### Requirement: 既存要件が gate-runner.md に置いた内容のうち段に移したものは段のファイルを指す

既存要件が `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` に置く・含む・書くと定めた内容のうち、段のファイルの「G として動くとき（develop）」節へ移すものは、移した先のその節を指すものとして読まなければならない（MUST）。移すものと移し先は次のとおりとする（MUST）。

| 内容 | 移し先 |
|---|---|
| needs-reviewer の payload（判定 `full（adapter 経路）` と、証拠欄 5 つの `未実行（adapter 経路）` を含む）と、その前に済ませること | `stages/prepare.md` |
| レビュー要約を受け取った G が投稿する「レビュー実行者:」PR コメントの段落 | `stages/prepare.md` |
| 従来経路のレビュー実行者の表と Codex の起動・完了確認（Codex の起動の事実 (a)(b)・companion の path-discovery・slash command 不可を含む） | `stages/review-run.md` |
| Status ごとの return 書式のうち failed 節・仕分け欄・needs-decider 節・review-incomplete | `stages/triage.md` |
| Status ごとの return 書式のうち保留欄 | `stages/hold.md` |
| Status ごとの return 書式のうち passed | `stages/pass.md` |
| 再開節のうち W の修正後の再レビューと決める役の裁定受領 | `stages/triage.md` |
| 再開節のうち保留の解除と、許容済み PR で HEAD が動いたとき | `stages/hold.md` |

`周回:` 欄は Gate Result の共通欄として gate-runner.md に残す（MUST）。

この読み替えは、少なくとも次の 5 つの既存要件に掛かる: `dev-workflow-develop` の「役割の指示書は references/roles/ に分かれている」（Scenario「gate-runner.md は pr-review-gate を手順書として参照する」が見る needs-reviewer の項目と failed の原因分類を含む）・「adapter 経路の G はレビュアーを自分で呼ばず needs-reviewer を返す」・「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」（参照先の「`gate-runner.md`『needs-reviewer の return』節」は `stages/prepare.md` の「G として動くとき（develop）」節を指す）、`dev-workflow-pr-review-gate` の「G の指示書の failed 節と周回欄が収束ルールに揃っている」・「Codex 経路と Task サブエージェント経路で同じ書式を渡す」（gate-runner.md の payload がブロックを指す行は、`stages/prepare.md` の payload の行が `stages/reviewer-brief.md` を指すことで満たす）。gate-runner.md に残す内容（上の要件「G は段ごとに要るファイルだけを読む」が列挙したもの）を定めた既存要件は読み替えない。

#### Scenario: needs-reviewer の証拠欄の所在

- **WHEN** 既存要件「adapter 経路の G はレビュアーを自分で呼ばず needs-reviewer を返す」が gate-runner.md に求める payload を探す
- **THEN** `stages/prepare.md` の「G として動くとき（develop）」節に、判定 `full（adapter 経路）` と証拠欄 5 つの `未実行（adapter 経路）` がある

#### Scenario: failed 節の所在

- **WHEN** 既存要件「G の指示書の failed 節と周回欄が収束ルールに揃っている」が gate-runner.md に求める failed 節・仕分け欄・needs-decider 節を探す
- **THEN** `stages/triage.md` の「G として動くとき（develop）」節にそれらがあり、保留欄は `stages/hold.md` の同じ節にある

### Requirement: W の (3b) は宣言の書式ファイルを指す

`plugins/dev-workflow/skills/develop/references/roles/worker.md` の (3b) の仕様宣言は、書式と `対象 HEAD:` 規約の正本として `skills/pr-review-gate/declarations.md` を指さなければならない（MUST）。`skills/develop/SKILL.md` の「仕様宣言は記録先ではなく常に PR コメントに置く」の書式の正本の参照も同じファイルを指す（MUST）。

#### Scenario: W の参照先

- **WHEN** worker.md の (3b) を読む
- **THEN** 仕様宣言の書式の正本として `skills/pr-review-gate/declarations.md` が書かれている

### Requirement: レビュー担当に渡す指示は reviewer-brief.md を指す

gate-runner.md の needs-reviewer の payload（`stages/prepare.md` に移ったもの）と `plugins/dev-workflow/references/subagent-waiting.md` の Codex 指示文の雛形は、レビュアーに渡す指示として `skills/pr-review-gate/stages/reviewer-brief.md` のレビュアー向け指示ブロックを指さなければならない（MUST）。

#### Scenario: needs-reviewer の payload

- **WHEN** `stages/prepare.md` の needs-reviewer の payload を読む
- **THEN** 「レビュアーに渡す指示」の行が `stages/reviewer-brief.md` のレビュアー向け指示ブロックを指している

### Requirement: Codex に渡す正本の一覧を段のファイルに合わせる

`plugins/dev-workflow/scripts/codex-develop.py` は、phase `gate` の request に `skills/pr-review-gate/SKILL.md`・`stages/` の 6 ファイル・`declarations.md` を正本として含めなければならない（MUST）。phase `review` の request には `skills/develop/references/roles/gate-runner.md` と `skills/pr-review-gate/stages/reviewer-brief.md` を正本として含めなければならない（MUST）。

#### Scenario: review phase の正本

- **WHEN** `codex-develop.py` で phase `review` の request を作る
- **THEN** prompt に `CANONICAL SOURCE skills/pr-review-gate/stages/reviewer-brief.md` と `CANONICAL SOURCE skills/develop/references/roles/gate-runner.md` があり、`変更点の一覧`・`照合表`・`ハンク被覆` を含む

#### Scenario: gate phase の正本

- **WHEN** `codex-develop.py` で phase `gate` の request を作る
- **THEN** prompt に索引・6 つの段のファイル・`declarations.md` の `CANONICAL SOURCE` 行がある

### Requirement: G は段ごとに新しく起こし、SendMessage で再開しない

`plugins/dev-workflow/skills/develop/SKILL.md` の (4) は、G を段ごとに新しく spawn することを規定しなければならない（MUST）。1 体の G は次の 4 つの段のうち 1 つだけを担当する（MUST）。

| 段 | 本体が起こす時点 | G が読むファイル（`skills/pr-review-gate/` から） | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー（failed の `次の段: 前提確認と重さ判定`）、保留の解除が `次の段: 前提確認と重さ判定` を返したとき、CI の見張りで `ready` になったあとの取り直し | `stages/prepare.md`（W の修正後の再レビューのときは加えて `stages/triage.md` の収束ルールの節と「W の修正後の再レビュー」の入力） | `needs-reviewer` / 保留 |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | `stages/triage.md` | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき | `declarations.md` と `stages/pass.md`（前の HEAD の許容があるとき・保留を返すときは加えて `stages/hold.md`） | passed / 保留 |
| 保留の解除 | 主の回答が届いたとき | `stages/hold.md` | 復帰手順の表どおりに `次の段へ`（`次の段:` は合格処理か前提確認と重さ判定） / failed / needs-decider / 保留 |

本体は G の起動指示に `段: <段の名前>` の 1 行を書かなければならない（MUST）。`skills/develop/SKILL.md` の (4)（`(4) G を` で始まる行から、その行を含むコードブロックの閉じ ``` の行まで）と `skills/develop/references/roles/gate-runner.md` は、`SendMessage` の語と `G を再開` の文字列を持ってはならない（MUST NOT）。SKILL.md の (4) の「G の起動・再開・手渡しの指示」「G を再開か手渡しで起こして」も段ごとの起動の言い方に書き換える（MUST）。G への SendMessage は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の停止の指示だけに残し、その規則は decision-criteria.md にだけ書く（MUST）。`gate-runner.md` の「時点ごとに読むファイル」の表は、上の段の表に揃えなければならない（MUST）。

保留の解除の G は、復帰手順の表が別の段の作業に進むと示したとき、その作業を自分で行ってはならず（MUST NOT）、Status `次の段へ` と `次の段:` で返さなければならない（MUST）。許容したとき・切り出して残りが無いときは `次の段: 合格処理`、許容せず代替案で手順 2 からやり直すときは `次の段: 前提確認と重さ判定` とする（MUST）。

W の修正後の再レビューで起こされた前提確認と重さ判定の G は、前の周の指摘を仕分けコメントから読み、`stages/triage.md` の収束ルールどおり差分限定か全体レビューかを自分で判定し、全体レビューにしたときは 2 つの行数を PR コメントに記録しなければならない（MUST）。

保留の解除のあとで起こされた合格処理の G（前の Gate Result が `段: 保留の解除`）は、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば、宣言を出し直してはならず（MUST NOT）、手順 5 の真正性確認から入らなければならない（MUST）。そのコメントが無ければ（切り出しの確認を解除した場合）、`declarations.md` の手順 3 から入らなければならない（MUST）。照合と振り分けのあとの合格処理は、前の Gate Result の `段: 照合と振り分け` で見分ける（MUST。`次の段: 合格処理` は保留の解除の Gate Result にもあるため入口の判別に使わない）。許容済みの PR で HEAD が動いていたときの許容の引き継ぎ（手順 3-c）は、合格処理の G が宣言の前に `stages/hold.md` を読んで試す（MUST）。

この要件は、develop の本体がレビュアーを起こす adapter 経路（起動指示が `レビュー経路: adapter`）に掛かる。従来経路の G はレビューを自分の起動の中で起こすので、手順 1〜5 と保留までを 1 体で続けてよい（MAY）。そのときの Gate Result は `段: 一括（従来経路）`、`次の段: なし` と書く（MUST）。

#### Scenario: SendMessage による G の再開の記述が無い

- **WHEN** `plugins/dev-workflow/tests/` の develop の役割の bats が `skills/develop/SKILL.md` の (4) と `gate-runner.md` を検査する
- **THEN** 段ごとに新しい G を起こす記述と `段:` の行の指示があり、SKILL.md の (4) の範囲と gate-runner.md の全体に `SendMessage` と `G を再開` の文字列が無い

#### Scenario: 従来経路の G

- **WHEN** develop の本体以外の呼び出し元が `レビュー経路: 従来` で G を起こす
- **THEN** G は手順 1〜5 と保留までを 1 体で続けてよく、Gate Result に `段: 一括（従来経路）` と `次の段: なし` を書く

#### Scenario: 保留の解除のあとの合格処理

- **WHEN** 保留の解除の G が主の許容を受けて `次の段へ`・`次の段: 合格処理` で返し、本体が合格処理の G を起こす
- **THEN** 合格処理の G は前の Gate Result の `段: 保留の解除` を見て、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば宣言を出し直さず手順 5 の真正性確認から入る

#### Scenario: 切り出しの確認を解除したあとの合格処理

- **WHEN** 照合と振り分けの G が切り出すかを主に聞く保留を返し、主が「切り出す」と答えて保留の解除の G が `次の段: 合格処理` で返す
- **THEN** 今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントが無いので、合格処理の G は `declarations.md` の手順 3 から入る

#### Scenario: CI の見張りのあとの取り直し

- **WHEN** CI の見張りが `ready` になり、本体がゲートを取り直す
- **THEN** 本体は前提確認と重さ判定の G を新しく起こし、前の G を再開しない

### Requirement: Gate Result は段と次の段を持つ

`gate-runner.md` の Gate Result の共通欄は、`段: <前提確認と重さ判定|照合と振り分け|合格処理|保留の解除|一括（従来経路）>` と `次の段: <段の名前|なし>` を持たなければならない（MUST）。Status には `次の段へ` を足す（MUST）。`次の段:` の値は G が次の表どおりに決めて書く（MUST）。

| Status | `次の段:` |
|---|---|
| `次の段へ` | 照合と振り分けの G は `合格処理`。保留の解除の G は `合格処理` か `前提確認と重さ判定` |
| failed | 戻した指摘が順 3 だけなら `照合と振り分け`、それ以外は `前提確認と重さ判定` |
| needs-reviewer / needs-decider | `照合と振り分け` |
| 保留 | `保留の解除` |
| passed / review-incomplete | `なし` |

本体は Status と `次の段:` だけを見て次に起こす G の段を決め、段についての判断（止める指摘が残っているか、戻した指摘の仕分け、復帰手順がどこへ進むか）をしてはならない（MUST NOT）。failed のときは W の修正のあと、failed の Gate Result の `次の段:` どおりに起こす（MUST）。戻した指摘が順 3 だけの修正のあとに起こされた照合と振り分けの G は、`stages/prepare.md` の手順 1 で新しい HEAD を固め、前の重さ判定を写した `レビュー重量:` コメントを `固定 HEAD: <新しい HEAD>` 付きで投稿してから 2 段の照合に入らなければならない（MUST）。

#### Scenario: 順 3 だけの failed

- **WHEN** 照合と振り分けの G が、戻す指摘が順 3 だけの failed を返す
- **THEN** Gate Result は `次の段: 照合と振り分け` を持ち、本体は W の修正のあと照合と振り分けの G を起こす

#### Scenario: 止める指摘が無いとき

- **WHEN** 照合と振り分けの G が止める指摘なしで終わる
- **THEN** G は Status `次の段へ`、`次の段: 合格処理` で返し、本体は合格処理の G を新しく起こす

### Requirement: 段と段の間の受け渡しは PR コメントを正とする

G は前の段の会話を持たない前提で動かなければならない（MUST）。段と段の間で渡すものは次の PR コメントに置く（MUST）。

| 渡すもの | 置き場所 | 書く G |
|---|---|---|
| 固定した HEAD | `レビュー重量:` コメントの `固定 HEAD: <SHA>` の行（周ごとに増えるので最新の 1 件を正とする） | 前提確認と重さ判定 |
| レビューの三表と補足済み回数（補足を頼んだ時点で 1。コメントが無ければ 0） | 1 行目 `レビュー三表:` のコメント（`補足済み回数:` の行を持つ） | 照合と振り分け |
| 振り分けの結果 | 既存の仕分けコメント | 照合と振り分け |

照合と振り分けの G は、補足の `needs-reviewer` を返す前に `補足済み回数: 1` を書いた `レビュー三表:` のコメントを投稿しなければならない（MUST。補足を頼んだ時点で 1 と数え、reviewer への payload は 0 のまま）。補足済み回数は G が交代しても最新の `レビュー三表:` のコメントから読み、リセットしてはならない（MUST NOT）。止める指摘が無い周で止めない指摘を follow-up issue に切るのは照合と振り分けの G で、`次の段へ` を返す前に行う（MUST）。

固定した HEAD の行を `対象 HEAD:` と書いてはならない（MUST NOT。auto-merge workflow がこの文字列を宣言の照合に使うため）。

本体は次の G の起動指示に、前の段の `## Gate Result` ブロックを要約し直さずそのまま貼り、段に固有の入力（レビュー要約・補足レビューの結果・決める役の裁定・主の回答・W の修正の要約）を足さなければならない（MUST）。起動指示と PR コメントが食い違ったら、G は PR コメントを正としなければならない（MUST）。

`gate-runner.md` の「再開」節は、段ごとの起動と入力（その段が読む PR コメントと、本体が渡すもの）を定める節に書き換えなければならない（MUST）。段の各ファイルの「G として動くとき（develop）」節にある再開の小節は、その段で起こされたときの入力として書き換える（MUST）。

#### Scenario: 補足レビューの結果を渡す

- **WHEN** 照合と振り分けの G が補足の `needs-reviewer` を返し、本体が補足レビューを起こして結果を受け取る
- **THEN** 前の G は補足の `needs-reviewer` を返す前に `レビュー三表:` のコメントを投稿している。本体は照合と振り分けの G を新しく起こし、前の Gate Result ブロックと補足レビューの結果を渡す。G は元の三表と補足済み回数を最新の `レビュー三表:` のコメントから読む

### Requirement: 周回は前の段から引き継ぐ

G は `周回:` を前の段の Gate Result の値から引き継がなければならない（MUST）。W の修正後の再レビューで起こされた前提確認と重さ判定の G だけが 1 増やす（MUST）。戻した指摘が順 3 だけの修正のあとは周を消費しない（`stages/triage.md` の既存規則のまま）。

#### Scenario: 再レビューの周

- **WHEN** 周回 1 で failed が返り、W の修正後に前提確認と重さ判定の G を起こす
- **THEN** その G の Gate Result は `周回: 2` を持つ

### Requirement: G が工程中断で返したら同じ段の新しい G を起こす

G が `工程中断:` で返したとき、本体は同じ段の新しい G を起こさなければならない（MUST）。起こしてよい条件は `decision-criteria.md` の「手渡しの許可」を参照し、`gate-runner.md` と SKILL.md に書き写してはならない（MUST NOT）。新しい G には前任の return 全文と、前任の起動指示に書いた入力を渡す（MUST）。

`scripts/subagent-context.sh` で G を測る記述は `gate-runner.md` と SKILL.md の (4) から無くし、再開前の計測は W だけに残す（MUST）。spawn の前の PR トークン上限の計測は変えない。

#### Scenario: 前任の入力を引き継ぐ

- **WHEN** 照合と振り分けの G が `工程中断:` で返す
- **THEN** 本体は照合と振り分けの G を新しく起こし、前任の return 全文と前任に渡したレビュー要約を渡す

### Requirement: G の名前と description は段を表す

本体は G を名前 `G-<PR>-<prepare|triage|pass|hold>-<n>`（`n` はその PR・その段で起こした回数）で spawn しなければならない（MUST）。description は `G: <段> for PR #N (#issue)` の形にし、先頭の `G:` を残さなければならない（MUST。`scripts/subagent-context-audit.sh --by-role` がこの接頭辞で G と判定するため）。

#### Scenario: 役割別集計で G と判定される

- **WHEN** `G: 照合と振り分け for PR #600 (#554)` の description で起こした G のトランスクリプトを `subagent-context-audit.sh --by-role` で集計する
- **THEN** G の行に数えられる

### Requirement: 「レビュー実行者:」コメントの段落は照合と振り分けの段に置く

レビュー要約を受け取った G が投稿する「レビュー実行者:」PR コメントの段落は、`skills/pr-review-gate/stages/triage.md` の「G として動くとき（develop）」節に置かなければならない（MUST）。`stages/prepare.md` に残してはならない（MUST NOT）。

#### Scenario: 段落の所在

- **WHEN** `stages/prepare.md` と `stages/triage.md` を読む
- **THEN** 「レビュー実行者:」コメントの段落は `stages/triage.md` にだけある

### Requirement: G の再開を前提にした既存要件の読み替え

既存要件のうち G の「再開」「SendMessage で G に渡す」「G を再開して再レビュー」と書いた箇所は、上の要件「G は段ごとに新しく起こし、SendMessage で再開しない」の表で、その時点に当たる段の G を新しく起こし、その起動指示に渡すものとして読まなければならない（MUST）。`レビュー経路: adapter` で起動済みの同一 G が行の無い再開指示でも adapter 経路を保つ規則は、再開が無いので `gate-runner.md`・SKILL.md・`plugins/dev-workflow/references/codex-develop.md` から消さなければならない（MUST）。本体がすべての G の起動指示に `レビュー経路: adapter` の 1 行を書く規則は変えない。

`stages/prepare.md` に置くとした「レビュー実行者:」PR コメントの段落は、上の要件「『レビュー実行者:』コメントの段落は照合と振り分けの段に置く」どおり `stages/triage.md` を指すものとして読む（MUST）。

この読み替えは、少なくとも次の既存要件に掛かる: 「1 ループは W→R1→W→G の順で回る」（修正後は G を再開して差分再レビュー）・「役割の指示書は references/roles/ に分かれている」（要約を G に SendMessage で渡す）・「役割のモデルは事前分類と残量モードで決める」（Scenario「再開前にコンテキスト量を測る」の G の部分は適用しない）・「G の needs-decider を受けた本体の動き」（裁定を SendMessage で渡して G を再開する）・「G はレビュー経路を起動指示の 1 行で判別する」（Scenario「adapter 経路で起動済みの G を行無しで再開」は再開が無いので適用しない）・「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」（Claude の G は SendMessage で再開して渡す）・「G は段ごとに要るファイルだけを読む」・「既存要件が gate-runner.md に置いた内容のうち段に移したものは段のファイルを指す」（「レビュー実行者:」の段落の移し先と、再開節の移し先）。

#### Scenario: 裁定の渡し方

- **WHEN** 既存要件「G の needs-decider を受けた本体の動き」に従い、本体が決める役の裁定を受け取る
- **THEN** 本体は照合と振り分けの G を新しく起こし、前の Gate Result ブロックと裁定を起動指示で渡す

#### Scenario: adapter 経路の保持規則が無い

- **WHEN** `gate-runner.md`・SKILL.md・`references/codex-develop.md` を読む
- **THEN** 行の無い再開指示で adapter 経路を保つ規則が無く、G の起動指示に常に `レビュー経路: adapter` を書く規則は残っている

### Requirement: 段ごとの G で上限を超えないことを PR 本文に記録する

この変更の PR の本文は、その PR のゲートを本体が worktree 側の新しい `skills/develop/SKILL.md` と `gate-runner.md` に従って段ごとの G で回した結果として、G ごとの段と終了時のコンテキスト量、150K を超えた G の数、上限による手渡しの回数を記録しなければならない（MUST）。実行時に読まれるプラグインのキャッシュはマージ前の版なので、マージ前の版で測った値であることを本文に明記する（MUST）。

#### Scenario: 記録の確認

- **WHEN** この変更の PR 本文を読む
- **THEN** G ごとの段と終了時のコンテキスト量、150K を超えた G の数（期待値 0）、手渡しの回数（期待値 0）、マージ前の版で測った旨がある

### Requirement: W と G は役割ごとの種別で起こす
develop の本体は W を `subagent_type: dev-workflow:worker`、G を `subagent_type: dev-workflow:gate-runner` で spawn しなければならない（MUST）。`general-purpose` で起こしてはならない（MUST NOT）。種別を替えても `model` は従来どおり spawn のたびに明示しなければならない（MUST。W は事前分類に当たれば `opus`、それ以外 `sonnet`。G は `sonnet`）。手渡しで後任を起こすときと、段ごとに新しい G を起こすときも同じ種別を使う（SHALL）。

`references/codex-develop.md` の Claude role の起動（W / G を Claude で起こす経路）も同じ種別を使わなければならない（MUST。どの role をどの種別で起こすかは `manual-codex-develop` の「委譲は前景実行の 3 手順で行う」が定める）。

仕様レビュー R1（決める役でないとき）と、G が要求するレビュアーの種別は変えない（SHALL。`general-purpose`。決める役に当たるときは従来どおり `dev-workflow:decider`）。

`develop/SKILL.md` の役割表と (1)・(3)・(4) の spawn の記述、`references/roles/worker.md`・`references/roles/gate-runner.md` の冒頭、`plugins/dev-workflow/README.md` の役割とモデルの説明は、それぞれの種別を書かなければならない（MUST）。

#### Scenario: 役割表が種別を書く
- **WHEN** `plugins/dev-workflow/skills/develop/SKILL.md` の役割表を読む
- **THEN** W の行に `dev-workflow:worker`、G の行に `dev-workflow:gate-runner` があり、R1 の行とレビュアーの行には `dev-workflow:worker` も `dev-workflow:gate-runner` も無い

#### Scenario: spawn の記述が種別を書く
- **WHEN** `develop/SKILL.md` の (1) と (4) の spawn の行、`worker.md` と `gate-runner.md` の冒頭、`references/codex-develop.md` の Claude role の起動、`plugins/dev-workflow/README.md` の役割とモデルの説明を読む
- **THEN** W には `dev-workflow:worker`、G には `dev-workflow:gate-runner` が書かれ、W / G を `general-purpose` で起こす記述が無い

### Requirement: W の仕様化経路は openspec CLI だけで進める
`dev-workflow:worker` は `Skill` を持たないので、W は仕様化・実装の検証・archive を openspec CLI で行わなければならない（MUST）。仕様化は `openspec new change` と artifact の直書き（雛形と書き方の指示は `openspec instructions <artifact> --change <name>`、依存順は `openspec status --change <name>` で得る）、実装の検証は `openspec validate <change> --strict` と `tasks.md` のチェックボックスの確認、archive は `openspec archive <change>` で行う（SHALL）。工程の区切り（(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言）と R1 の仕様レビューは変えない（SHALL）。

W の仕様化経路があるかどうかは `openspec --version` が成功するかだけで決めなければならない（MUST）。`.claude/commands/opsx/` の有無で決めてはならない（MUST NOT）。opsx コマンドがあっても openspec CLI が無ければ、W は `仕様化判断: しない` の理由に「openspec 不在」と書いてコード直行する（SHALL）。

`references/roles/worker.md` で `/opsx:` のスラッシュコマンドが出てよいのは、本体や主が対話で `/opsx:*` を使う場面（例: W が来る前に本体や主が `/opsx:ff` で change を作っていた場合）を述べる行だけで、その行は `本体` か `主` の語を含まなければならない（MUST）。W が `/opsx:*` を実行する指示を書いてはならない（MUST NOT）。

#### Scenario: worker.md が CLI の経路で書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/roles/worker.md` を読む
- **THEN** `openspec new change`・`openspec validate`・`openspec archive` を使う手順があり、(3a) の節と (3b) の節に `/opsx:` の文字列が無く、`/opsx:` を含む行はどれも `本体` か `主` の語を含む

#### Scenario: 経路の有無を CLI だけで決める
- **WHEN** `worker.md` の仕様化判断の節と、`develop/SKILL.md` の前提の表の openspec の行を読む
- **THEN** W の経路の有無を `openspec --version` で決めることが書かれ、`worker.md` に `ls .claude/commands/opsx/` による検出が無い

### Requirement: .worktreeinclude が無いときの /wt-setup は本体が行う
worktree に `.worktreeinclude` が無いときに `/wt-setup` を呼ぶのは本体でなければならない（MUST）。W は `/wt-setup` を呼んではならない（MUST NOT。`dev-workflow:worker` は `Skill` を持たない）。`worker.md` の「W がしないこと」から W が `/wt-setup` を呼ぶ例外を消し、`develop/SKILL.md` の worktree を用意する節に本体の仕事として書かなければならない（MUST）。

#### Scenario: 例外が本体の仕事に移っている
- **WHEN** `worker.md` と `develop/SKILL.md` を読む
- **THEN** `worker.md` に W が `/wt-setup` を呼ぶ記述が無く、`develop/SKILL.md` の worktree を用意する節に、`.worktreeinclude` が無いとき本体が `/wt-setup` を呼ぶことが書かれている

### Requirement: W の (3a) の return は画面確認の要否を 1 行で書く
W の (3a) の return（1 行目 `工程完了: 実装＋verify`）は、`画面確認:` で始まる行を 1 行持たなければならない（MUST）。値は `不要` か、`要る — <開く URL か起動手順> / <見る点>` のどちらかとする（SHALL）。`要る` のときは開く URL か起動手順と、見る点の両方を書かなければならない（MUST。画面確認役 V は実装の経緯を知らないため）。要否は、受け入れ条件または記録先の「動作確認ポイント」が画面での観測を求めているかで W が決める（SHALL）。W 自身は画面で確認しない（MUST NOT）。

#### Scenario: 画面確認が要らない変更
- **WHEN** 受け入れ条件が画面での観測を求めない変更で W が (3a) を終えて return する
- **THEN** return に `画面確認: 不要` の行がある

#### Scenario: 画面確認が要る変更
- **WHEN** 受け入れ条件が画面での観測を求める変更で W が (3a) を終えて return する
- **THEN** return に `画面確認: 要る — ` で始まり、URL か起動手順と見る点を `/` で区切って書いた行がある

### Requirement: 画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす
本体は W の (3a) の return の `画面確認:` の行が `要る` のときだけ、(3b) を指示する前に画面確認役 V を spawn しなければならない（MUST）。`不要` のときは V を起こしてはならない（MUST NOT）。V は `subagent_type: general-purpose`・`model: sonnet` で起こし（SHALL。ブラウザの道具を持つ既存の種別を使い、新しい種別を作らない）、名前は `V-<記録先番号>-<n>`、description は `V: screen check for #N` とする（SHALL。先頭に役の略号を置く W / R1 / G の description の形に揃える。`scripts/subagent-context-audit.sh` の役割別集計は今は V を `unknown` に数え、V を集計の役に足すことはこの change の範囲外）。V の指示書は `skills/develop/references/roles/screen-checker.md` に置かなければならない（MUST）。

本体は V に、W の `画面確認:` の行と W の worktree のパスを渡し、`isolation` を付けずに起こさなければならない（MUST。V は W が実装した作業ツリーをそのまま見る）。V が dev server を起動するときは `rules/dev-server.md` に従い、同じプロジェクトのサーバーを二重に起動せず、他のプロジェクトのプロセスを止めてはならない（MUST NOT）。V が dev server を起動したときは、return に起動したポートを書く（SHALL）。

V はファイルを編集してはならず、commit・push・記録先への投稿もしてはならない（MUST NOT）。V の return の 1 行目は `^画面確認結果: (合格|不合格|実行不能)$` に一致しなければならない（MUST）。

- `合格`: 2 行目以降に、開いた URL・見た要素・観測した値を書く（MUST）。本体はその return を (3b) の W に渡し（MUST）、(3b) の W はそれを動作確認の証拠の入力にする（SHALL）
- `不合格`: 2 行目以降に、期待と違った観測を書く（MUST）。本体は (3b) に進まず、W を (3a) で再開して直させなければならない（MUST）。`不合格` の回数は本体が、同じ `画面確認:` の行（見る点が同じもの）ごとに数える（SHALL）。2 回目の `不合格` を受けたら、本体は昇格トリップワイヤーの失敗ループ（同じテストが 2 連続で落ちた）と同じ扱いにし、原因が判断側か実行側かの分類も従来どおり本体が行う（SHALL）
- `実行不能`: Chrome 拡張が繋がらない・無人実行で拡張が無いなど、観測できなかった理由を書く（MUST）。本体は (3b) の W に「画面確認は実行不能」と理由を渡し、(3b) の W は画面確認の証拠を書かない（SHALL）。そのあとは pr-review-gate の既存の保留経路（自力で検証できない動作確認を主に依頼する経路）に委ねる（SHALL）。V は待ったり、主に直接依頼したりしてはならない（MUST NOT）

V は数ターンで終わる役なので、SendMessage で再開してはならない（MUST NOT）。もう一度確認が要るときは新しい V を起こす（SHALL）。

#### Scenario: 画面確認が要るときだけ V を起こす
- **WHEN** W の (3a) の return に `画面確認: 要る — http://localhost:3000/settings / 保存ボタンを押すとトーストが出る` がある
- **THEN** 本体は (3b) の前に V を `general-purpose`・`model: sonnet`・`isolation` 無しで起こし、W の `画面確認:` の行と worktree のパスを渡し、V の return を (3b) の W に渡す

#### Scenario: 画面確認が要らないときは V を起こさない
- **WHEN** W の (3a) の return に `画面確認: 不要` がある
- **THEN** 本体は V を起こさずに (3b) を指示する

#### Scenario: V がブラウザの道具を使える
- **WHEN** Chrome 拡張が繋がった環境で V を起こし、1 ページを開かせる
- **THEN** V は `mcp__claude-in-chrome__*` の道具でページを開き、`画面確認結果: 合格` または `不合格` と観測した内容を返す

#### Scenario: 拡張が繋がらないときは既存の保留経路に落とす
- **WHEN** V が `画面確認結果: 実行不能` を返す
- **THEN** 本体は (3b) の W に実行不能とその理由を渡し、(3b) の W は画面確認の証拠を書かず、動作確認は pr-review-gate の保留経路で主に依頼される

#### Scenario: 不合格なら (3a) に戻す
- **WHEN** V が `画面確認結果: 不合格` を返す
- **THEN** 本体は (3b) を指示せず、V の観測を渡して W を (3a) で再開する

#### Scenario: 同じ画面確認の 2 回目の不合格は失敗ループに当てる
- **WHEN** 同じ `画面確認:` の行について、W を (3a) で再開したあとに起こした新しい V が再び `画面確認結果: 不合格` を返す
- **THEN** 本体はこれを失敗ループとして扱い、原因を判断側か実行側かに分類して、昇格トリップワイヤーの手順で次の担い手を決める

### Requirement: 保留で止まるときは記録先に引き継ぎのコメントを 1 種類の書式で残す

本体は、`needs-approval` を付けて主の返事を待つすべての場面で、止まる前に記録先へ引き継ぎのコメントを投稿しなければならない（MUST）。場面は pr-review-gate の保留（リスク許容・動作確認・切り出しの確認）、`skills/develop/SKILL.md`「PR トークン上限」の exit 2、レビューの 2 周キャップ超えの 3 つで、書式は場面によらず 1 種類とする（MUST）。場面ごとに別の書式を作ってはならない（MUST NOT）。

**投稿の順序**: 本体は、どの場面でも次の順で投稿する（MUST）。①主への依頼のコメントを投稿し、その URL を得る。依頼コメントの置き場は、対象の PR があれば PR、無ければ記録先とする（`stages/hold.md` 手順 6 は依頼を PR に投稿するので、記録先が issue でも PR のコメントの URL でよい。引き継ぎのコメント自体は常に記録先に投稿する）。G の保留では G が投稿した依頼コメントの URL を使い、G が投稿していなければ本体が依頼文を PR（無ければ記録先）のコメントとして投稿する。exit 2 と 2 周キャップ超えでは本体が問いを PR（無ければ記録先）のコメントに書く。②その URL を「主への依頼」に書いて引き継ぎのコメントを投稿する。③主に案内する。①より前に引き継ぎを投稿してはならない（MUST NOT。URL が無いため）。

コメントの 1 行目は正規表現 `^引き継ぎ: 主の返事待ち$` に完全一致させ（MUST。太字・全角コロン・末尾句点を付けない）、2 行目以降に次の項目を `項目名: 値` の形で 1 行ずつ書く（MUST）。

| 項目 | 中身 |
|---|---|
| 待ち理由 | `リスク許容` / `動作確認` / `切り出しの確認` / `PR トークン上限` / `2 周キャップ超え` のどれか |
| 主への依頼 | ①で得た依頼コメントの URL（PR のコメントでもよい） |
| 対象 | PR 番号（まだ無ければ `なし`）・HEAD の 40 桁 SHA・ブランチ・worktree のパス |
| ラベルの付け先 | `needs-approval` を付けた先。PR があれば `PR #N`、PR がまだ無ければ記録先（`issue #N`）。コメントの記録先とは別に書く |
| 実行モード | interactive / unmanned |
| 実行先 | 実行先オプションと account-home の対応（明示したときだけ。無ければ `自動選択`）と、開始済みの phase ごとの選択結果（構成・executor・account・model）が書かれたコメントの URL。最初の phase の選択結果は develop 開始コメント（`develop/SKILL.md`「Role profile の選択」）、以降の phase は dispatch 記録のコメントにある。両方書く（どちらも無ければ `なし`） |
| 次に起こす役割 | 返事のあとに最初に起こす役割と、渡す入力の在り処 |
| 周回 | 仕様レビューと G の周回の数・W の修正の周回の数 |
| 前任 W | 直近の return の 1 行目と要約または URL（W を起こしていなければ `なし`）と、手渡し可否（次の段落） |
| PR トークン上限 | 最新の値と、止まった時点の合計 |
| 回し方 | エピックの子のときだけ。それ以外は `なし` |

W の名前は書かない（新しいセッションでは SendMessage できないため）。同じ記録先で再び止まるときは新しいコメントを投稿し、読む側は最新の 1 件を正とする（MUST）。

**前任 W の手渡し可否**: 前任 W を後任へ手渡してよいのは、`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」を満たすときだけである（MUST）。新しいセッションの本体は前任に停止を指示できないので、本体は引き継ぎを書く前に、前任 W の直近の return の 1 行目が `工程完了:` であることを確かめるか、前任が `工程中断:` なら前任に停止を指示して停止確認を受け取り、未コミット差分があれば本体が commit する（MUST。commit してから引き継ぎを書く）。いずれかを満たしたら「前任 W」の項目に `手渡し: 可（工程完了 | 停止確認済み）` と確認結果（編集ファイル・commit の SHA）を書く。どちらも満たせないとき（exit 2 で SendMessage を送れない・前任が停止確認を返さない）は `手渡し: 不可（<理由>）` と書く。W を起こしていなければ `手渡し: 不要` と書く。

本体は主への依頼に「返事は新しいセッションで `/develop <記録先>` と一緒に渡す。1 時間以内に返事ができるなら、このセッションで続けてもよい」という案内を含めなければならない（MUST）。引き継ぎのコメントは、返事がいつ来るかを本体が知らないので必ず残し、どちらで続けるかは主が決める（MUST）。

#### Scenario: pr-review-gate の保留で止まる

- **WHEN** G が保留で返り、本体が `needs-approval` のまま主に 1 アクションで依頼する
- **THEN** 本体は依頼コメントの投稿のあとに記録先へ `引き継ぎ: 主の返事待ち` のコメントを投稿し、待ち理由に `リスク許容`・`動作確認`・`切り出しの確認` のどれかを、ラベルの付け先に `PR #N` を書き、主への案内に `/develop <記録先>` を含める

#### Scenario: PR トークン上限の exit 2 で止まる

- **WHEN** 計測が exit 2 を返し、本体が spawn せずに主へ「続けるか、範囲外として閉じるか」を問う
- **THEN** 本体は問いを PR（無ければ記録先）のコメントに書いたあとで同じ書式の引き継ぎのコメントを残し、待ち理由は `PR トークン上限` とする。前任 W が `工程中断:` で停止指示を送れなければ `手渡し: 不可（PR トークン上限のため SendMessage できない）` と書く

#### Scenario: 2 周キャップ超え

- **WHEN** レビューの 2 周キャップを超えて本体が `needs-approval` を付けて主に依頼する
- **THEN** 本体は同じ書式の引き継ぎのコメントを残し、待ち理由は `2 周キャップ超え` とする

#### Scenario: 前任 W が工程中断のまま保留に入る

- **WHEN** 前任 W の直近の return が `工程中断:` で、本体が保留に入る
- **THEN** 本体は前任へ停止を指示して停止確認を受け取り、未コミット差分を commit してから引き継ぎを書き、`手渡し: 可（停止確認済み）` とする。停止確認が取れなければ `手渡し: 不可` と書く

### Requirement: 新しいセッションの本体は引き継ぎのコメントとラベルから続ける

`skills/develop/SKILL.md` は、記録先に `引き継ぎ: 主の返事待ち` のコメントがある記録先で新しいセッションの本体が起動したときの再開手順を規定しなければならない（MUST）。手順は次のとおり。

1. 記録先の最新の引き継ぎのコメントを読む。
2. そのコメントより後の主の回答（記録先または対象 PR のコメント、または `/develop` の引数の残り）を探し、あれば使う。無ければ、引き継ぎの「主への依頼」を主に見せ直して返事を聞き、返事が来るまで役割を起こさない。
3. 引き継ぎの「ラベルの付け先」に `needs-approval` が付いていることと、対象の PR の HEAD が引き継ぎの HEAD と同じことを確かめる（ラベルはコメントの記録先ではなく、この項目の指す先で見る）。ラベルが無ければ保留は既に解かれているので、記録先のコメントから今の状態を組み立て直して主に報告する。HEAD が動いていれば、引き継ぎの HEAD からの差分を主に報告し、続けるかを聞く。
4. W は SendMessage で再開せず、手渡し（前任の return と記録先を渡して新しい W を起こす）にする。引き継ぎの「前任 W」が `手渡し: 可` のとき、または `手渡し: 不要`（前任の W がいない。最初の W を起こす前に止まった場合など）のときに新しい W を起こす。`可` は前任の return と記録先を渡す手渡しで、`不要` は前任がいないので「次に起こす役割」の入力で初回の W を起こす。`手渡し: 不可` のときは W を起こさず、理由を主に報告して指示を聞く。G は従来どおり段ごとに新しく起こす。
5. 実行先: 引き継ぎに明示の実行先オプションがあれば、再推測せずそのまま使う（主の返事に同じオプションが無いときは引き継ぎの値を使う）。自動選択のときは、次に起こす役割が属する phase の選択結果が引き継ぎの「実行先」の指すコメント（最初の phase は develop 開始コメント、以降は dispatch 記録）にあれば、その構成・executor・account・model を続け、選び直さない（開始済みの role は途中で切り替えない）。どちらのコメントにも選択結果が無い（未開始の）phase だけ、その phase の開始時に adapter で自動選択を評価する。
6. PR トークン上限の計測の `--cap` には、記録先の最新の `PR トークン上限:` コメントの値を使う。

**守備範囲（再開手順が通す入力と守らない入力）**: 再開手順が読む入力は、記録先のコメント（本体・G・主が書く）・主の返事（記録先または対象 PR のコメントか `/develop` の引数）・ラベル・PR の HEAD で、出どころは GitHub の記録先と PR だけである。拾いたい誤りは、引き継ぎが最新でないまま読まれること、返事が無いまま役割を起こすこと、保留が既に解かれているのに再開を進めること、HEAD が動いているのに気づかず続けること、手渡し不可の前任に代えて W を起こすことの 5 つである。通してよい入力は、項目の並び順が書式と違うコメント、値の前後の空白、返事が引数ではなく記録先か PR のコメントで来たもの、HEAD が引き継ぎと同じ PR である。守らないのは、引き継ぎの値（周回の数・要約）が事実と合っているかの検証と、主の返事の真正性（真正性は pr-review-gate 手順 5 が正本で、ここでは確かめない）である。上の 5 つ以外の入力の不備を見つけるたびに検査を足し続けることを、この要件の完了条件にしない（MUST NOT）。

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

### Requirement: /develop の入口は引き継ぎのある記録先を再開手順へ進める

`commands/develop.md` は、引数で特定した記録先（数字または URL）に `引き継ぎ: 主の返事待ち` のコメントがあるとき、`needs-approval` の有無によらず、通常の入口 0 に進まず、`skills/develop/SKILL.md` の新しいセッションでの再開手順に進めなければならない（MUST）。ラベルの確認は再開手順 3 が行い（記録先ではなく引き継ぎの「ラベルの付け先」で見る。issue が記録先で保留の PR にラベルがある場合があるため）、ラベルが無ければ再開手順が状態を組み立て直して主に報告する（入口の条件と再開手順の条件を揃える）。引数の記録先より後ろの文字列は主の返事として本体に渡す（MUST）。①③の分岐で記録先を特定する挙動は変えない。この分岐の守備範囲（入力の出どころ・拾う誤り・通してよい入力・完了条件にしないこと）は、前の要件の「守備範囲」の段落に従う（MUST）。

#### Scenario: 引き継ぎのある issue 番号で起動する

- **WHEN** `/develop <issue 番号> 許容する` のように記録先と返事を渡し、その記録先に引き継ぎのコメントがある
- **THEN** 本体は入口 0 をやり直さず、再開手順に進み、`許容する` を主の回答として扱う

#### Scenario: 引き継ぎはあるがラベルが無い

- **WHEN** `/develop <記録先>` の記録先に引き継ぎのコメントがあるが、「ラベルの付け先」に `needs-approval` が無い
- **THEN** 本体は入口 0 に進まず再開手順に入り、記録先のコメントから状態を組み立て直して主に報告する

### Requirement: W の return は読んだコードの要点を持つ

`references/roles/worker.md` は、W の return の成果一覧（この欄は W の場合のみ必須で、G の return の契約は変えない。工程の終わりの return、途中で締めた return、昇格トリップワイヤーで止まったときの return のいずれも）に「読んだコードの要点」欄を含めることを書かなければならない（MUST）。欄の書式は 1 行 1 件の `<リポジトリ相対パス>:<開始行>-<終了行> — <そこから分かったこと>` とし、上限を 20 行とし、超えるときは次の工程で読む必要が高いものを残すと書かなければならない（MUST）。

`worker.md` の「コンテキスト上限と手渡し」の節は、手渡しで起こされた W に向けて、前任の要点は読む場所の案内であり、編集する前には該当範囲を自分で読んで確かめることを書かなければならない（MUST）。要点を判断の根拠として読み替えてよいと書いてはならない（MUST NOT）。

`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の節が成果一覧を列挙する箇所（`工程完了:` の説明と、通知を受けたときの振る舞い）は W / G 共通の定義なので、「読んだコードの要点」を「W の場合のみ必須」という条件付きで含まなければならない（MUST）。G に必須と読める無条件の追記をしてはならない（MUST NOT。G は段ごとに新しく起こされ、`工程中断:` の return を同じ段の新しい G に渡す既存の経路はこの欄を前提にしないため）。書式（1 行の形・上限行数）は `worker.md` を正本とし、`decision-criteria.md` に再掲してはならない（MUST NOT。上限を変えたときに片方が取り残されるため）。

#### Scenario: worker.md の手渡しの節に欄と書式がある
- **WHEN** `references/roles/worker.md` の「コンテキスト上限と手渡し」の節を読む
- **THEN** 成果一覧に「読んだコードの要点」があり、W の場合のみ必須であること、1 行 1 件の `ファイル:行の範囲 — 分かったこと` の形と上限 20 行が書かれている

#### Scenario: 後任は要点を案内として扱う
- **WHEN** `references/roles/worker.md` の「コンテキスト上限と手渡し」の節の、手渡しで起こされたときの箇条を読む
- **THEN** 前任の要点は読む場所の案内であり、編集前に該当範囲を自分で読んで確かめると書かれている

#### Scenario: (3a) とトリップワイヤーの return にも欄がある
- **WHEN** `references/roles/worker.md` の「(3a) の return に書くこと」と「昇格トリップワイヤー」の節を読む
- **THEN** どちらにも「読んだコードの要点」を書くことが含まれている

#### Scenario: 手渡しの入力の定義に欄の名前がある
- **WHEN** `references/decision-criteria.md` の「コンテキスト上限（サブエージェントの手渡し）」の節を読む
- **THEN** 成果一覧を列挙する 2 箇所がどちらも「読んだコードの要点」を「W の場合のみ必須」の条件付きで含み、書式は `worker.md` を参照していて、上限行数の数値は書かれていない

### Requirement: (1) で作業項目ごとに触る範囲を書く

`references/roles/worker.md` は、仕様化する場合、W が `tasks.md` の各タスクに `触る範囲: <パス>:<開始行>-<終了行>`（複数は並べる。新しく作るファイルは `<パス>（新規）`）を書くことを書かなければならない（MUST）。行番号は仕様づくりの時点の値で前のタスクの編集でずれうること、実装の担い手は編集前に該当範囲を読むことを添えなければならない（MUST）。

仕様化しない（コード直行）と判定した場合は、同じ内容を作業項目ごとに (1) の return に書くことを書かなければならない（MUST）。

#### Scenario: 仕様化する場合の tasks.md に触る範囲を書く
- **WHEN** `references/roles/worker.md` の「仕様化する場合（(1) の終わり）」の節を読む
- **THEN** `tasks.md` の各タスクに `触る範囲:` を `ファイル:行` の形で書くこと、行番号は着手時点の値でずれうること、編集前に該当範囲を読むことが書かれている

#### Scenario: 仕様化しない場合は return に書く
- **WHEN** `references/roles/worker.md` の仕様化判断の節の、仕様化しないと判定した場合の段落を読む
- **THEN** 作業項目ごとの `触る範囲:` を (1) の return に書くことが書かれている

### Requirement: adapter 経路の本体は Claude のレビュアーを区画ごとに起こす

develop の SKILL.md の (4) の `needs-reviewer` の手順は、phase `review` で選ばれた executor が claude で、G の payload の `区画:` に区画の一覧があるときは、区画ごとにレビュアーを 1 体ずつ並列に起こすことを書かなければならない（MUST）。各レビュアーの Agent の `description` は `Reviewer: 区画 <k>/<n> for PR #<N> (#<issue>)` の形にしなければならない（MUST。`subagent-context-audit.sh --by-role` が先頭トークン `Reviewer` でレビュアーに数えるため）。executor が codex のときは区画を使わず、差分全体を 1 つの request に渡さなければならない（MUST）。

本体は全区画の要約が揃ってから、照合と振り分けの G を 1 体だけ新しく起こし、全区画の要約を `区画 <k>/<n>` の見出しを付けてまとめて渡さなければならない（MUST）。区画ごとに G を起こしてはならない（MUST NOT）。

#### Scenario: claude の executor で区画がある

- **WHEN** G の `needs-reviewer` の payload に区画が 3 つあり、phase `review` の executor が claude である
- **THEN** 本体はレビュアーを 3 体並列に起こし、`description` は `Reviewer: 区画 1/3 for PR #N (#issue)` の形で、3 体の要約が揃ってから照合と振り分けの G を 1 体起こして全区画の要約を渡す

#### Scenario: codex の executor では区画を使わない

- **WHEN** G の `needs-reviewer` の payload に区画があり、phase `review` の executor が codex である
- **THEN** 本体は区画に分けず、差分全体を 1 つの request で Codex のレビュアーに渡す

### Requirement: 補足は一周目の区画の構成のまま、選び直した executor で残差だけを補う

一周目照合の補足要求（`needs-reviewer` の補足 payload）でも、本体は既存要件「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」のとおり phase `review` の投げ先を選び直す。SKILL.md の (4) は、選び直しで executor が一周目と変わっても変わらなくても、補足を一周目の区画の構成（G が `レビュー三表:` のコメントと補足 payload に書いた `一周目の区画:`）のまま行うことを書かなければならない（MUST）。補足のときに区画を計算し直してはならず、差分全体のレビューを始めてはならない（MUST NOT）。一周目の三表の変更点 ID と finding ID はそのまま残し、補った項目にも一周目と同じ ID の付け方（区画があれば補足先の区画の `P<k>-`、区画が無ければ接頭辞なし）を使わなければならない（MUST）。既存の「元の三表を置き換えず、残差に挙げた不足した項目だけを補う」と「補足は PR 全体で 1 回まで（補足済み回数は PR で 1 つ）」は変えない（MUST）。

executor ごとの起こし方は次のとおりとしなければならない（MUST）:

- 一周目に区画があり、補足の executor が claude: 残差のある区画だけに補足のレビュアーを 1 体ずつ起こし、その区画の元の三表と残差を渡す。`description` は `Reviewer: 補足 区画 <k>/<n> for PR #<N> (#<issue>)` とする
- 一周目に区画があり、補足の executor が codex: 1 つの request に、残差のある区画ごとに区画の番号・その区画のファイル一覧・元の三表・残差を分けて載せ、区画ごとに `P<k>-` の ID で補わせる。差分全体のレビューは頼まない
- 一周目に区画が無く（一周目が Codex、または `区画: なし`）、補足の executor が claude: 補足のレビュアーを 1 体だけ起こし、1 組の元の三表と残差を渡して接頭辞の無い ID で補わせる。payload の `区画:` に区画の一覧があっても区画ごとに起こさない
- 一周目に区画が無く、補足の executor が codex: 今までどおり 1 つの request で補わせる

#### Scenario: 区画に分けた Claude の一周目のあと、補足で Codex が選ばれる

- **WHEN** 一周目は claude で 3 区画に分けてレビューし、G が区画 2 と区画 3 に残差を出して `一周目の区画: 3` の補足 payload を返し、補足の選び直しで executor が codex になる
- **THEN** 本体は 1 つの request に区画 2 と区画 3 の番号・ファイル一覧・元の三表・残差を分けて載せ、`P2-`・`P3-` の ID で不足分だけを補わせ、差分全体のレビューも区画 1 の補足も頼まない。補足済み回数は PR で 1 のまま

#### Scenario: 区画に分けなかった Codex の一周目のあと、補足で Claude が選ばれる

- **WHEN** 一周目は codex で差分全体を 1 体で見て（payload の `区画:` には 3 区画があった）、G が `一周目の区画: なし` の補足 payload を返し、補足の選び直しで executor が claude になる
- **THEN** 本体は補足のレビュアーを 1 体だけ起こし、1 組の元の三表と残差を渡して接頭辞の無い ID で不足分だけを補わせ、区画ごとに起こさず差分全体のレビューも始めない

