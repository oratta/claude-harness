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
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 → (1) W が仕様化判断の記録・分割判定・openspec CLI による change の作成（`openspec new change` と artifact の直書き）まで行い return（仕様化しない判定なら (3) へ直行。文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）なら、W は仕様の差分 1 ファイルだけを書いて return し、本体は記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があることを確かめてから (2) を飛ばして (3) へ進む）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりに BLOCKER が残れば、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の直し方の判定を通し、「決まっている」で PR トークン上限の内側なら主に聞かず次の周を回し、そうでなければ `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) 実装（`tasks.md` を TDD で。直行なら TDD。文言合わせの通し方なら W が (1) の return に書いた作業項目を TDD で）・verify（`openspec validate --strict`）まで行って return、本体が計測し、W の return の `画面確認:` の行が `要る` なら画面確認役 V を起こしてから（下の「画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす」Requirement）、(3b) `openspec archive`・PR を Draft のまま用意（無ければ Draft で作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → 文言合わせの通し方では、本体は G を起こす前に、記録先の最新の仕様化判断のコメントの `直す文:` の行が archive 済みの差分の要件名と一致することを確かめる（SHALL） → (4) G が pr-review-gate の手順 1〜5 を実行し `passed` / `failed` / `保留` / `needs-reviewer` / `needs-decider` / `needs-fix-check` / `review-incomplete` のいずれかを return。PR の Ready 化は G が手順 5 の合格処理で行い（Draft なら Ready にしてから `agent-review:passed` を付ける）、W は行ってはならない（MUST NOT）。

G が `review-incomplete` を return したとき、本体は新しい reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止めなければならない（MUST）。`needs-reviewer` が一周目照合の補足要求である場合、本体は fresh reviewer に固定 HEAD・元の三表・残差・補足済み回数を渡し、同じレビューの不足分だけを補わせなければならず（MUST）、レビューを最初からやり直させてはならない（MUST NOT）。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら実行役を `opus` に上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く。**W を `fable` で再開してはならない**（MUST NOT。実行役の上限は `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。修正後は G を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりの扱いは pr-review-gate の収束ルールと、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement に従う）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

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
- **THEN** SKILL.md は実装品質起因のときだけ原因分類に応じて実行役を `opus` に上げるか決める役を `dev-workflow:decider` で立てるかの一方だけを行い、仕様が曖昧・レビュアーの誤検出ではモデルを上げず、W を `fable` にはせず、G を再開して差分再レビューするよう指示している

#### Scenario: decider として起こした R1 の結果は本体が投稿する
- **WHEN** SKILL.md の (2) の記述を読む
- **THEN** R1 が `dev-workflow:decider` の場合は本体が return を同じ書式で記録先に代理投稿すると書かれている

#### Scenario: review-incomplete は reviewer を再起動しない
- **WHEN** G が補足後の残差を `review-incomplete` で return する
- **THEN** 本体は fresh reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止める

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker/`（W の指示書。`common.md`・`spec.md`・`implement.md`・`finish.md` の 4 本）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker/spec.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）を、`worker/common.md` は仕様レビュー結果の記録書式を、`references/pre-classification.md` は「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。事前分類表の「1 周目」列は**実行役（W）の上限を `opus` とし、`fable` 行を持ってはならない**（MUST NOT。4 分類のいずれに当たっても W は `opus` 止まりで、聖域パスの `opus` は据え置き）。表には、読んで判断する役（R1・G が要求するレビュアー）が `fable` 相当の分類に当たるときは `subagent_type: dev-workflow:decider` で spawn し、`general-purpose` に `model: fable` を付けないことを明記しなければならない（MUST）。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担うことを書く（SHALL）。`worker/common.md` の return には「指示のどこまでやって、どこで何が起きたか」を含める義務を書かなければならない（MUST。決める役の入力契約になるため）。

`spec-reviewer.md` は 6 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合・守備範囲の明記）と、既定 2 周と 2 周目以降の周の終わりに直し方の判定を通して続ける規則を含む（MUST。判定役・入力・書式の正本は `references/fix-check.md` で、`spec-reviewer.md` は規則を書いて正本を指す）。観点の中身の正本は `dev-workflow-spec-review` とする（SHALL）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

`worker/implement.md`・`spec-reviewer.md`・`gate-runner.md` の 3 つはいずれも、長時間処理の完了通知を待つためにターンを終えてはならない旨を明記しなければならない（MUST）。待ち方の詳細の正本は `plugins/dev-workflow/references/subagent-waiting.md` とし、各指示書はそこを参照する（SHALL）。`spec-reviewer.md` の 1 行は、decider 経路で spawn される R1 が `Bash` を持たず待ちループ自体を実行できないため、「長い処理の完了を待つ目的でターンを終えない（decider 経路の R1 は待ちを伴う作業を持たない）」の形で書く（SHALL。読んだ R1 が実行できない手順を探しに行かないようにするため）。

`gate-runner.md` は Codex の**起動**の事実（(a) `codex exec -c approval_policy=never -c model_reasoning_effort=medium` を `run_in_background` で起動する経路と、(b) `codex-companion.mjs` に `task … --effort medium` を投げる経路。companion の path-discovery を含む）を持ち、**完了の確認方法は正本 `plugins/dev-workflow/references/subagent-waiting.md` に委ねなければならない（MUST）**。完了マーカーの雛形・具体の待ち値・総待ちの上限を `gate-runner.md` に再掲してはならない（MUST NOT。2026-09-09 のレビューで、再掲した companion の判定方法が事実と食い違ったまま残っていたため）。「出力ファイルを読め」だけで待ち方を書かない記述を残してはならない（MUST NOT）。`gate-runner.md` に残す待ち関連の記述は、完了通知に頼ってターンを終えない禁止・正本への参照・上限到達時の G 固有の分岐（待ちをやめて `needs-reviewer` を return し、根拠に「Codex タイムアウト」と実際に待った時間を書く）に限る（SHALL）。

#### Scenario: worker/ の 4 本と pre-classification.md に記録書式と事前分類表がある
- **WHEN** `references/roles/worker/` の 4 本と `references/pre-classification.md` を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式、`gh` で記録先にコメントする手順、4 分類の事前分類表（「1 周目」列がすべて `opus` で `fable` 行が無い）、レビュアーの fable は `dev-workflow:decider` 経由であること、return に「指示のどこまでやって、どこで何が起きたか」を書く義務が書かれている

#### Scenario: spec-reviewer.md に 6 観点と周回の規則がある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 6 観点がすべて列挙され、既定 2 周・2 周目以降の周の終わりに BLOCKER が残れば直し方の判定を通し、すべて直し方の決まったもので PR トークン上限の内側なら主に聞かず次の周を回すことが書かれ、「3 周目の例外は設けない」の文は無い

#### Scenario: gate-runner.md は pr-review-gate を手順書として参照する
- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** pr-review-gate スキルを読んで手順 1〜5 を実行すること、Codex は `codex exec` / `codex-companion.mjs` を Bash で呼ぶこと、Codex が使えないときは `needs-reviewer`（判定・HEAD SHA・推奨モデル・受け入れ条件の所在を含む）を return して本体にレビュアーの spawn を委ねること、failed の return に原因分類を含めることが書かれている、Codex の完了確認を同一ターン内の前景ポーリングで行うこと・その手順の正本が `references/subagent-waiting.md` であること・総待ちの上限に達したら `needs-reviewer` を return することが書かれており、待ちの雛形と具体の待ち値は再掲されていない

#### Scenario: 3 つの指示書に待ちでターンを終えない禁止がある
- **WHEN** `references/roles/` 配下の `worker/implement.md` / `spec-reviewer.md` / `gate-runner.md` をそれぞれ読む
- **THEN** どのファイルにも「完了通知を待つためにターンを終えない」旨の記述があり、待ち方の正本として `references/subagent-waiting.md` が参照されている

#### Scenario: spec-reviewer.md の 1 行は decider 経路を踏まえている
- **WHEN** `references/roles/spec-reviewer.md` の待ちに関する 1 行を読む
- **THEN** 禁止が書かれたうえで、decider 経路の R1 は待ちを伴う作業を持たない旨が添えられており、実行できない待ちループの手順を探しに行かずに済む

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

### Requirement: 実行モードと unmanned の責務分割
SKILL.md は実行モード表（interactive / channel / unmanned）を持ち、unmanned（`--unmanned`。loop-dev-agent の憲法 Step 3 から呼ばれる）では次を規定しなければならない（MUST）: develop の本体は憲法のメイン自身が務め、W / R1 をメインが spawn する。worktree は憲法側が用意したものを使う。1 ループのうち (0)〜(3) を回し、(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。(4) の G は unmanned では起こさず、憲法 Step 1（レビューモード）が次サイクル以降で担う（1 サイクル 1 仕事を維持）。複数 change に割れた場合は子 issue を作って `blocked_by` で順序付けし、そのサイクルを終える。仕様化判断の記録と仕様レビューは unmanned でも免除しない（MUST）。文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）で R1 を起こさないのは、モードによる免除ではなく、interactive と同じ対象・同じ当てる条件で unmanned にも当てる（SHALL）。

channel（画面を見ている人がいないセッションで、主とチャンネル（Discord など）だけで会話する。flatmate の住人がオーナーから開発を頼まれたときの形）は、interactive と同じ (0)〜(4) を回す（MUST。G を起こし、PR の合格まで進む）。W・R1 の起動指示の実行モードには interactive と書く（MUST。W・R1 の手順の分岐は channel でも interactive 側をとり、主に聞くのは W・R1 の return を受けた本体がチャンネルで行う）。interactive との違いは、主に聞く先と主への発言の宛先（チャンネル）・保留からの再開の案内（G の依頼文を含む）・リスク許容の受け方・エピックの回し方・主への発言の 1 行目と答え方の行だけで、それぞれの決まりは要件「channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない」「channel モードの保留はチャンネルの返事で再開する」「channel モードのリスク許容はチャンネルの返事を確かめられるときだけチャンネルで受ける」「エピックの条件・作り方・回し方・完了条件を規定する」（回し方の経路の決め方）「channel モードの主への発言はすべてチャンネルに送り、チャンネルでする操作を答え方の行に書く」に従う（MUST）。モードの決め方は要件「実行モードは引数・印・依頼の届き方で開始時に決める」に従う（MUST）。

#### Scenario: unmanned でも文言合わせの通し方は同じ条件で当たる
- **WHEN** SKILL.md の実行モードの節を読む
- **THEN** 仕様化判断の記録と仕様レビューを unmanned でも免除しないことと、文言合わせの通し方は interactive と同じ条件で unmanned にも当てることが書かれている

#### Scenario: unmanned では G を起こさない
- **WHEN** SKILL.md の実行モード表を読む
- **THEN** unmanned では憲法のメインが本体を務めて W / R1 を spawn し、(3) で Draft PR と `agent-review:pending` まで W が行い、G は憲法 Step 1 に委ねると書かれている

#### Scenario: channel は interactive と同じ工程を回す
- **WHEN** SKILL.md の実行モード表を読む
- **THEN** `channel` の行があり、回す工程が (0)〜(4) で、対話の欄に「チャンネルで聞く（AskUserQuestion は使わない）」と書かれている

### Requirement: 前提環境を明記する
SKILL.md は「前提」節として、Agent ツール（`model` 明示・名前付き spawn・`isolation: "worktree"`・W は `subagent_type: dev-workflow:worker`、G は `subagent_type: dev-workflow:gate-runner`）と SendMessage、`gh`（issue / PR コメントとラベル、issue dependencies API）、openspec CLI（W は CLI だけで仕様化経路を進め、経路の有無は `openspec --version` で決める。opsx コマンドは本体や主が対話で使う道具で、W の経路の有無を決めない。CLI が無ければ仕様化経路が発生しない）、Codex CLI（無ければ G が `needs-reviewer` に縮退）、`orca` コマンド（エピックの子を Orca の子ワークツリーで独立セッションとして起動する。無いとき、または本体が Orca 管理外のワークツリーにいるときは、エピックをサブエージェント方式で回す）を列挙しなければならない（MUST）。

#### Scenario: 前提節がある
- **WHEN** SKILL.md の「前提」節を読む
- **THEN** Agent / SendMessage / gh / openspec CLI / Codex CLI / orca とそれぞれ無いときの縮退が書かれ、Agent の行に W と G の種別が書かれ、openspec の行に W の経路の有無を `openspec --version` で決めることが書かれ、orca の行には Orca 管理外のワークツリーにいるときもサブエージェント方式になることが書かれている

### Requirement: /develop コマンドと /work-issue エイリアス
`plugins/dev-workflow/commands/develop.md` が存在し、`skills/develop/SKILL.md` を path-discovery で特定して Read し、SKILL.md「実行モード」の決め方（要件「実行モードは引数・印・依頼の届き方で開始時に決める」）でモードを決めてインライン実行する薄いラッパーでなければならない（MUST）。印もチャンネルの依頼も無ければ interactive（既定）で実行し、`--unmanned` はこのコマンドから使わない（MUST）。引数の分岐 ②⑤ の候補の提示と issueify フォールバックの承認は、channel ではチャンネルでの質問になることをその場に書く（MUST。要件「channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない」）。frontmatter の `allowed-tools` は Agent と SendMessage を含み、Edit を含まない（MUST。本体はコードを書かない）。`commands/work-issue.md` は `/develop` のエイリアスとして残し、同じ引数を develop の手順に渡す（MUST）。plugin.json の `skills` に `./skills/develop`、`commands` に `./commands/develop.md` と `./commands/work-issue.md` が登録されている（MUST）。

#### Scenario: /work-issue が /develop として動く
- **WHEN** `/work-issue 42` を起動する
- **THEN** `commands/work-issue.md` は develop の手順に `42` を渡す旨だけを書いており、独自の手順を持たない。`commands/develop.md` の `allowed-tools` には Agent と SendMessage があり Edit が無い

#### Scenario: plugin.json の登録
- **WHEN** `.claude-plugin/plugin.json` を読む
- **THEN** `skills` に `./skills/develop` があり `./skills/github-issue` が無く、`commands` に `./commands/develop.md` と `./commands/work-issue.md` がある

#### Scenario: モードは SKILL.md の決め方で決まる
- **WHEN** `commands/develop.md` の実行の文を読む
- **THEN** SKILL.md「実行モード」の決め方でモードを決めること、印もチャンネルの依頼も無ければ interactive（既定）であること、`--unmanned` をこのコマンドから使わないことが書かれている

### Requirement: コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く

コンテキスト計測の規則の本文——2 経路（本体が再開前に測る／起動の途中で hook が測る）・閾値の環境変数（`DEV_WORKFLOW_CONTEXT_CAP`＝通知、`DEV_WORKFLOW_CONTEXT_HARD_CAP`＝強制停止、`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`＝全解除）・通知を受けたときの振る舞い・強制停止中にできること・return の 1 行目の書き分け——は、`references/decision-criteria.md`「コンテキスト上限」の節に置かなければならない（MUST）。

`references/roles/worker/common.md`・`skills/develop/SKILL.md`・`references/roles/gate-runner.md`・`templates/escalation-tripwires.md`・`plugins/dev-workflow/README.md` は、その節への**ポインタと、その役割固有の動作だけ**を書かなければならない（MUST）。ポインタを書くのは `worker/common.md` であり、索引 `references/roles/worker.md`・`references/roles/worker/` の他 3 本（`spec.md`・`implement.md`・`finish.md`）・`references/pre-classification.md` はポインタを持たなくてよい（この 5 本には再掲の禁止だけを掛ける）。上のどのファイルも、閾値の数値・環境変数名・通知や強制停止の振る舞いを言い換えて再掲してはならない（MUST NOT）。同じ規則を複数のファイルに言い換えて置くと、次に閾値や振る舞いが変わったときにどれかが取り残されるためである（`README.md` を対象に含めるのは、プラグインの概観であっても閾値の数値を書けば取り残される対象になるため。実際に着手時点の `README.md` には `150K tokens` の再掲があった）。

#### Scenario: 規則の本文が decision-criteria.md にある

- **WHEN** `references/decision-criteria.md` のコンテキスト上限の節を読む
- **THEN** 2 経路・3 つの環境変数・通知時と強制停止時の振る舞い・return の 1 行目の書き分けが、そこだけで完結して書かれている

#### Scenario: 他の面はポインタだけ

- **WHEN** `SKILL.md` / `references/roles/worker/common.md` / `references/roles/gate-runner.md` / `templates/escalation-tripwires.md` / `README.md` を読む
- **THEN** `references/decision-criteria.md`「コンテキスト上限」への参照があり、閾値の数値や環境変数名の再掲が無い

#### Scenario: ポインタを持たない面は再掲だけを禁じる

- **WHEN** 索引 `references/roles/worker.md` / `references/roles/worker/` の `spec.md`・`implement.md`・`finish.md` / `references/pre-classification.md` を読む
- **THEN** 閾値の数値や環境変数名の再掲が無い（`decision-criteria.md`「コンテキスト上限」への参照は求めない）

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

手渡しで起こされた W / G の指示書は、前任が途中停止で return した可能性があるため、再出発の前に作業ツリーの未コミット差分（`git status` / `git diff`）を確認しなければならない（MUST）と書かなければならない。これは `references/roles/worker/common.md` の手渡しの節に置く役割固有の動作であり、閾値や振る舞いの再掲ではない。

#### Scenario: 手渡し先が未コミット差分を先に見る

- **WHEN** `references/roles/worker/common.md` の手渡しの節を読む
- **THEN** 前任が途中停止した可能性があるので `git status` / `git diff` で未コミット差分を先に確認する、と書かれている

### Requirement: 強制停止で止まった作業ツリーは本体が引き取る

強制停止中は `Bash` がコマンド内容によらず全件拒否されるため、止まったサブエージェント自身は commit できない（`dev-workflow-execution-strategy`「強制停止の閾値を超えたら PreToolUse が編集を拒否する」）。手渡し先（`worker/common.md` の手渡しの節）が拾うのは**次に起こされた**サブエージェントの `git status` / `git diff` だけなので、①手渡しが発生しない経路（そのサイクルを終える・別の子 issue に移る・工程が G で終わる）、②後継が G の場合（`gate-runner.md` には同じ規則が無い）は未コミット差分の確認が誰にも渡らない。SKILL.md は、`工程中断:` の return を受け取ったとき、および次の手渡し・次の spawn・そのサイクルの終了・worktree の撤去のいずれよりも先に、**本体**が return に書かれた作業ツリーのパス（強制停止による中断なら hook の `permissionDecisionReason` に含まれる `cwd`。それ以外の `工程中断:` なら return に書かれたパス）に対して `git -C <path> status --porcelain` を実行して未コミット差分を確認し、残っていれば本体が commit しなければならない（MUST）ことを明記しなければならない（MUST）。

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

`references/roles/worker/implement.md` と `references/roles/worker/finish.md` は (3a) と (3b) それぞれの return に何を書くかを列挙しなければならない（MUST）。(3a) は openspec CLI 経路（`tasks.md` を TDD で実装＋`openspec validate --strict`）・コード直行（TDD）のどちらの入口でも実装後に検査を実行するため、**`worker/implement.md` は「全経路共通の大原則」に、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップを読み、検査コマンド（lint・test・ビルド等）と環境セットアップ（依存インストール等）を判別し、拾った検査コマンドを種類ごとに次のとおり扱わなければならない（MUST）という指示を置かなければならない（MUST。経路それぞれに重複して書かない）**: lint・型検査などの静的検査は手元で実行する（ツールがファイルを引数に取れるなら変えたファイルに当て、取れないなら CI と同じ形で実行する）。テストの全体実行（テストランナーをファイルで絞らずに起動するもの）は手元で実行してはならず（MUST NOT）、変えたファイルに関係するテストだけを実行し、全体は CI に任せる。ビルドは手元で実行せず CI に任せる。関係するテストは、この変更で足した・変えたテストのファイル、テストのファイルのうち変えたファイルのパスかファイル名を含むもの（`git grep -l` 等で探す）、テストランナーが変えたファイルから関係するテストを選ぶ機能を持つならその結果、CI の見張りの `fix`（`references/ci-watch.md` 7）で直すときは落ちた run のログ（`gh run view <run> --log-failed`）に出たテストのファイル、の和集合とし、テストランナーにファイルを渡して実行する。例: `auto-merge.yml` や `revert-pr.yml` のように `pull_request` / `push` 以外のイベントで起動する運用系ワークフローは対象に含めない（MUST NOT）。コマンド名をこのリポジトリ固有の値（`scripts/test.sh` など）に固定してはならない（MUST NOT。develop は複数リポジトリで使われ、CI の構成はリポジトリごとに異なるため）。PR・push で起動してテストの全体実行をするジョブが無い（workflow ファイルが存在しない、テストのジョブが無い、または `run:` から検査コマンドを判別できない）ときは、全体のテストを CI に任せられないので、手元で全体を実行しなければならず（MUST）、慣例コマンド（`scripts/test.sh` 等）へのフォールバックを許容する（MAY）。Draft では CI を走らせないリポジトリは、Ready にした時点で CI が走るので CI に任せられる側に数える。手元にツールが無く実行できない検査（apt でプリインストールされた `shellcheck` 等）は「未導入」として実行結果と区別しなければならず、未導入を合格として扱ってはならない（MUST NOT）。**(3a) の return には、収集した検査コマンドの一覧・手元で実行した検査コマンド（関係するテスト・静的検査）と exit code（未導入の検査があれば未導入と明記）・関係するテストを探したコマンド・手元で実行せず CI に任せた検査とその CI のジョブ名、および `openspec validate --strict` の exit code（仕様化した場合。直行した場合は「仕様化しないため verify なし」）と、画面確認の要否の行（「W の (3a) の return は画面確認の要否を 1 行で書く」Requirement）を含めなければならない（MUST）**。(3b) の担い手は pr-review-gate 手順 5 が照合する動作確認の証拠を書く必要があり、手渡しが起きた場合その証拠は前任の return からしか得られない（後任は前任の履歴を読めない）ためである。`openspec validate --strict` の exit code が無いと、(3b) の担い手は verify を通ったことを確認できないまま archive に進むことになる。CI 由来の検査コマンドをすべて return に含め、静的検査を手元で実行することで、G がゲートを合格にしたあとに CI の一部（このリポジトリでは shellcheck）が落ち、W・レビュー・G をもう 1 周回す再発を防ぐ。テストの全体実行を手元で行わないのは、CI が同じ中身を分けて短時間で回し、ゲート合格後の CI の見張り（`references/ci-watch.md`）が落ちた CI を直しに回すためで、手元で全体を回すと実装・仕上げ・指摘の修正のたびに全体の所要（claude-harness では約 40 分）を待つことになる（#1211）。

この要件の守備範囲で入力として扱うのは、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップと、変えたファイルの一覧である。拾いたい誤りは、CI が流す静的検査を W が取りこぼすこと（PR #489 の shellcheck）と、変えたファイルを名前で参照するテストの失敗をゲートより後まで持ち越すことである。変えたファイルを別のスクリプト経由で間接的に読むテストを関係するテストとして拾えないことは、この要件では止めない（CI とゲート合格後の CI の見張りが拾う）。次は通ってよく、この要件では止めない: `matrix` / `services` / `env` / `if:` 条件により CI の実行環境と手元の実行結果が食い違うこと、CI ランナー固有の環境に依存する検査、環境セットアップの `run:` ステップを検査コマンドと誤って実行すること。取りこぼしが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。CI が実際に落ちるかどうかは、G が pr-review-gate 手順 4 で対象 HEAD の CI の結果を証拠として見ることに加え、ゲート合格後の CI の見張り（`references/ci-watch.md`）が拾う。auto-merge を配備したリポジトリでは必須チェックが緑になるまでマージされない。

`skills/develop/SKILL.md` は、(3a) の return を受けてから (3b) を指示する SendMessage を送るまでのあいだに、本体が `scripts/subagent-context.sh <W の名前>` を実行してコンテキスト量を測ることを書かなければならない（MUST）。上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本である（再掲の禁止は既存の Requirement「コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く」が規定しており、ここでは重ねて規定しない）。

本体は次に指示する工程を、**自分が (3a) を指示したか (3b) を指示したかで決めなければならない**（MUST）。工程名の文字列照合で決めてはならない（MUST NOT）。

#### Scenario: worker/implement.md と worker/finish.md が (3a) / (3b) の return 内容を列挙している
- **WHEN** `references/roles/worker/implement.md` と `references/roles/worker/finish.md` を読む
- **THEN** (3a) と (3b) がそれぞれ別の見出し（または別の箇条）として立っており、(3a) に `openspec validate` があり `/opsx:` が無く、(3a) が CI workflow 定義から検査コマンドを収集して種類ごとに扱う義務と、return に収集した検査コマンド一覧・手元で実行した検査コマンドと exit code（未導入の検査は未導入と明記）・関係するテストを探したコマンド・CI に任せた検査とその CI のジョブ名・`openspec validate --strict` の exit code・`画面確認:` の行を含める義務が書かれ、(3b) に `openspec archive` があり `/opsx:` が無く、(3b) の return に PR 番号と仕様宣言のコメント URL を含める義務が書かれている

#### Scenario: CI の定義から検査コマンドを収集する指示が全経路共通の節にある
- **WHEN** `references/roles/worker/implement.md` の「全経路共通の大原則」の節を読む
- **THEN** PR・push で起動する `.github/workflows/*.yml` / `*.yaml` の `run:` から検査コマンドを拾うこと（`auto-merge.yml` 等の運用系ワークフローは対象外）、コマンド名をリポジトリ固有の値に固定しないこと、静的検査は手元で実行しテストの全体実行とビルドは手元で実行せず CI に任せること、関係するテストの選び方（足した・変えたテスト、変えたファイルのパスかファイル名を含むテスト、テストランナーの選ぶ機能）、PR・push で全体のテストを回すジョブが無いときは手元で全体を実行し慣例コマンドへのフォールバックが許容されること、ツール未導入は「未導入」として合格と区別することが書かれており、この指示が (3a)「コード直行する場合」手順 5 だけでなく openspec CLI 経路にも及ぶ 1 箇所にまとまっている

#### Scenario: CI が全体のテストを回すリポジトリでは手元で全体を回さない
- **WHEN** PR・push で起動する workflow にテストの全体実行をするジョブがあるリポジトリで、W が (3a) の検査を行う
- **THEN** W はテストランナーをファイルで絞らずに起動せず、関係するテストのファイルをテストランナーに渡して実行し、return にテストの全体実行を CI に任せたこととその CI のジョブ名を書く

#### Scenario: CI が全体のテストを回さないリポジトリでは手元で全体を回す
- **WHEN** PR・push で起動する workflow が無い、またはテストのジョブが無いリポジトリで、W が (3a) の検査を行う
- **THEN** W は手元でテストの全体を実行し（慣例コマンドへのフォールバックを含む）、その exit code を return に書く

#### Scenario: 守備範囲が明記されている
- **WHEN** `references/roles/worker/implement.md` の全経路共通の大原則の節、CI 検査コマンドの収集を指示する段落を読む
- **THEN** 入力の出どころ（PR・push で起動する workflow の `run:` ステップと変えたファイルの一覧）、拾いたい誤り（CI の静的検査の取りこぼし。PR #489 の shellcheck）、間接的に読むテストを拾えないことは CI と CI の見張りが拾う旨、通ってよい入力（`matrix` / `services` / `env` / `if:` 条件による CI と手元の再現差、ランナー依存の検査、環境セットアップの `run:` ステップの誤実行）、取りこぼしを塞ぎ切ることを完了条件にしない旨（最後の防波堤は合格後の CI の見張り）が書かれている

#### Scenario: 旧世代の W が (3) を通しで返してきても (3b) を再指示しない
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** 本体は次に指示する工程を自分が指示した工程で決めると書かれており、工程名の文字列照合では決めないことが書かれている
- **AND** (3a) の return に PR 番号と仕様宣言のコメント URL が揃っているかどうかで (3b) を飛ばす分岐は書かれていない

#### Scenario: worker/common.md の工程名が 3 つになっている
- **WHEN** `references/roles/worker/common.md` のコンテキスト上限と手渡しの節を読む
- **THEN** W が return する工程の単位が「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つとして列挙されている

#### Scenario: SKILL.md が (3a) と (3b) のあいだの計測を指示している
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** (3a) の return のあと (3b) を指示する前に `scripts/subagent-context.sh` で測ると書かれており、上限超のときの扱いは `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を正本として参照している

#### Scenario: タスク単位のさらなる分割は禁止されている
- **WHEN** `skills/develop/SKILL.md` の (3) を読む
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

`route <child>...` は stdout にちょうど 1 行を出して exit 0 で終わらなければならない（MUST）。判定は次の順で、最初に当たったものを出す: (1) エピックの子のセッション（環境変数 `EPIC_DISPATCH_PARENT_EPIC` があるか、今のワークツリーを `worktree` に持つ状態の記録がある）なら `nested`、(2) 引数の子が 0 件なら `subagent`、(3) 環境変数 `EPIC_DISPATCH_LAUNCHER` が `orca` か `tmux` ならその値（部品が使えるかを確かめ、使えなければ stderr に理由を出して `subagent`）、(4) Orca の部品の `here` が exit 0（`orca` が PATH にあり、今いるディレクトリが Orca 管理のワークツリー）なら `orca`、(5) 環境変数 `TMUX` が空でなく `tmux` コマンドが PATH にあれば `tmux`、(6) それ以外は `subagent`。`EPIC_DISPATCH_LAUNCHER` が `orca`・`tmux`・空のどれでもなければ stderr に使い方を出して exit 1 で終わる。子の番号が数字でなければ stderr に使い方を出して exit 1 で終わる（SHALL）。`launch` と `adopt` は、同じ順の (3)〜(5) で使う起動部品を決め、決められなければ exit 1 で終わる。

`launch [--note <text>] [--base <branch>] <epic> <child>...` は、起動部品が Orca のとき、次の順で呼び出さなければならない（MUST。tmux の部品のときの呼び出しは capability `dev-workflow-epic-state` の要件「tmux の部品は…」が決める。部品の選び方は要件「記録の launcher ごとに起動部品を選ぶ」）: `orca worktree current --json`（今の repo の `repoId` を得る）→ `git rev-parse --show-toplevel` → `git fetch origin <base>` → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` → 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --json` → 子の端末を用意する（`orca terminal list --worktree path:<子> --json` で端末を数え、0 個のときだけ `orca terminal create --worktree path:<子> --command <cmd> --json` で作る。ちょうど 1 つのときは作らずにその端末を使う。詳細は要件「launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ」）→ `orca terminal wait --terminal <handle> --for tui-idle --timeout-ms <ready> --json` → `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json`。worktree create に `--agent` と `--prompt` を渡してはならない（MUST NOT。`--agent` で起動すると子セッションのモデルを指定できず Claude Code の既定モデルで動くため。`--prompt` は Orca 1.4.209 では指示が子の入力欄に届かず、送信と併用すると指示が 2 回届くおそれがあるため）。`<子>` は worktree create の JSON 出力の `result.worktree.path` とする（MUST）。`<cmd>` は `<claude-cmd> --model <model>` で（`--dangerously-skip-permissions` などの許可に関わる引数は付けてはならない（MUST NOT）。付けるのは `<claude-cmd>` 側に任せる）、`<claude-cmd>` の既定は `cld` で環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で変えられ、クォートせずそのまま置く（MUST。`--command` の文字列は Orca が開いたログインシェルに打ち込まれるのでシェル関数も解決され、`cld-account b` のような引数付きも書けるため）。`<model>` はシェルに打ち込まれても 1 語のまま渡るよう単一引用符で囲む（MUST。`opus[1m]` のような値がグロブとして解釈されないため）。`<model>` の既定は `opus` で、環境変数 `EPIC_DISPATCH_MODEL` で変えられる（MUST）。`<handle>` は、端末を作ったときは terminal create の JSON 出力の `result.terminal.handle`、使い回したときはその端末のハンドルとする（MUST）。`<ready>` の既定は 60000（ミリ秒）で環境変数 `EPIC_DISPATCH_READY_TIMEOUT_MS` で、`<submit>` の既定は 30（秒）で環境変数 `EPIC_DISPATCH_SUBMIT_WAIT` で変えられる（SHALL）。`<親>` は `git rev-parse --show-toplevel` で求めた親ワークツリーの絶対パスで、親の指定は create と set の両方で `path:` を使わなければならない（MUST。`worktree:<id>` は set で `selector_not_found` になるため）。`<base>` の既定は `main` で、環境変数 `EPIC_DISPATCH_BASE` で既定を変えられ、`--base` が環境変数より優先する（MUST）。`<prompt>` は `/develop #<N>` で始まり、エピック番号を含み、`--note` があればその文を含む（SHALL）。子を `launched <N>` とするのは、worktree create が exit 0 で終わり、子のワークツリーのパスが取れ、端末を用意でき（terminal create が exit 0 で終わりハンドルが取れた、または使い回した端末が Claude Code になった）、`terminal wait` が exit 0 で終わり、`terminal send` が exit 0 で終わってその JSON 出力のどこかの `stages` 配列に `turn_started` が含まれるときだけでなければならない（MUST）。どれか 1 つでも満たさなければ `failed <N>` とし（MUST）、子のワークツリーのパスが取れていて、端末を作る経路でハンドルが取れていなければ（terminal create の失敗を含む）、端末を手で起動し直すための `orca terminal create --worktree path:<子> --command <cmd> --json` を stderr に出すに続けて、最初の指示を送るための `orca terminal send --terminal <作り直した端末のハンドル> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出す（SHALL。ワークツリーは残るので、再実行ではその子は `skipped <N>` になり端末が作られないため）。端末を用意できたあと（`terminal wait` か `terminal send` の段）で失敗し、ハンドルが取れていれば、指示を手で送り直すための `orca terminal send --terminal <handle> --text <prompt> --enter --wait-submit <submit> --json` を stderr に出し、あわせて「送る前に `orca terminal read --terminal <handle>` で入力欄とターンの状態を確かめる」旨の案内を出す（SHALL。送信が非 0 やターン未観測で終わっても指示が届いていることがあり、確かめずに送ると 2 回届くため）。`terminal send` の JSON 出力に送り直し用の ID（キー `retryRequestId` または `retryRequest` の文字列値）があれば、送り直しのコマンドに `--retry-request <id>` を付ける（SHALL）。ワークツリーは残すので、再実行ではその子は `skipped <N>` になり、指示を送り直さない（SHALL）。一覧に、同じ `repoId` で `linkedIssue` が `<N>` の archive されていないワークツリーがある子には create を呼ばず `skipped <N>` を出さなければならない（MUST。再開時や取り違えで同じ子を二重に起動しないため）。`orca` が PATH に無いときは何も呼ばずに exit 1 で終わり、`orca worktree current`・`git fetch`・`orca worktree set`・`orca worktree list` のどれかが失敗したとき（`jq` が無くて一覧を読めないときを含む）は子を 1 件も作らずに exit 1 で終わらなければならない（MUST）。stdout には子ごとに `launched <N>`・`skipped <N>`・`failed <N>` のどれか 1 行だけを出し、`orca` 自身の出力は stderr に流す（SHALL）。1 件の失敗で残りの子の起動を止めず、`failed` が 0 件なら exit 0、1 件でもあれば exit 1 で終わる（MUST）。

`wait [--interval <sec>] [--timeout <sec>] <child>...` は、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` で state を確かめるポーリングを繰り返し、stdout にちょうど 1 行を出して終わらなければならない（MUST）。子ごとの結果は、出力が `closed` なら閉じている、`open` なら開いている、`gh` が非 0 で終わったか出力がそれ以外（空文字を含む）なら失敗とする（MUST）。1 件以上の子が閉じていれば `closed <N>...`（閉じていた子の番号）で exit 0、上限時間に達したら `timeout <N>...`（閉じていない子の番号）で exit 2、失敗したポーリングが 3 回続いたら `error gh <N>...`（3 回目で失敗した子の番号）で exit 1 で終わる（MUST）。失敗したポーリングとは、1 件以上の子が失敗し、かつ閉じた子が 1 件も無いポーリングを言い、一部の子だけが失敗してほかの子が `open` の場合も含む（MUST）。失敗の無いポーリングがあれば数え直す（SHALL）。閉じた子がいるポーリングでは、ほかの子の失敗より `closed` を優先する（SHALL）。間隔と上限は秒で、間隔の既定は 300、上限の既定は要件「上限を明示しない wait は親の会話キャッシュの有効期限で上限を決める」が決める（3000 か 21600）。環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する（MUST）。ポーリングのあとで経過時間が上限に達しているか、経過時間と間隔の和が上限を超えるなら、眠らずに `timeout` で終わる（MUST。`--timeout 0` は間隔によらず 1 回だけ確かめて終わる）。子が 0 件、番号が数字でない、間隔・上限が非負整数でないときは stderr に使い方を出して exit 1 で終わる（SHALL）。

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
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子セッションを起動する端末のコマンドの先頭に `EPIC_DISPATCH_PARENT_EPIC=<epic>` を置かなければならない（MUST。`<epic>` は `launch` に渡したエピック番号）。そのうしろに `<cmd>` を置き、`<cmd>` と `--model` のあいだに `--settings '{"idleCompaction":false}'` を置く（MUST。子のセッションのアイドル時のコンパクトを切る。`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を付けないことを含め、要件「子のセッションはアイドル時のコンパクトを切って起動する」が定める）。コマンド全体は `EPIC_DISPATCH_PARENT_EPIC=<epic> <cmd> --settings '{"idleCompaction":false}' --model <model>` の形になり、端末を作れなかった子について stderr に出す `orca terminal create --command ...` の作り直しのコマンドにも同じ前置きが入る（SHALL）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の出力の規定、`<cmd>` の形の規定、および Scenario「EPIC_DISPATCH_MODEL…」「EPIC_DISPATCH_CLAUDE_CMD…」の `--command` の値と、Scenario「端末を作れなければ送らずに failed で端末の作り直しのコマンドを出す」の作り直しのコマンドが `cld --model` を含むという値（新しい形では `cld --settings '{"idleCompaction":false}' --model` を含む）に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

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
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=420 cld --settings '{"idleCompaction":false}' --model 'opus'` である

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
`skills/develop/SKILL.md` の (4) は、G が `passed` を return したあと、本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始めることを書かなければならない（MUST）。G の `passed` の return に `issue で承認済み:` の行があれば、本体は見張りを始める前に、主へその行（宣言コメントの URL・当たった分類・引用した issue の文）を 1 回伝えなければならない（MUST。pr-review-gate 手順 5 の事後報告。auto-merge 配備リポではマージまで主との会話が起きないため、本体の手順に置かないと報告が起きない）。見張りの一手が `fix` のときは、本体が W に直させ（W の再開か手渡しかは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う）、W が push したら本体が passed を外したまま同じ状態ファイルで `wait` → `next` を続け（CI のやり直し・再度の直しもここで処理する）、`ready` になってから G を起こしてゲートを取り直させ、G が再び `passed` を返したら見張りの続き（reference の「`ready` を受けたあと」）に進むこと、合格するまでマージ待ち・マージ依頼に進まないことを書く（MUST）。見張りの中身は reference を参照し、SKILL.md に言い換えて再掲してはならない（MUST NOT）。

G の指示書 `skills/develop/references/roles/gate-runner.md` は、G が CI の見張りを始めずに `passed` を return することを書かなければならない（MUST）。unmanned モードは (4) を回さないので、この見張りの対象外とする。

#### Scenario: (4) の passed のあとに本体が見張る
- **WHEN** `skills/develop/SKILL.md` の (4) を読む
- **THEN** `passed` を受けた本体が `references/ci-watch.md` の手順で見張りを始めること、`fix` なら W に直させ、push のあと passed を外したまま `wait` → `next` を続けて `ready` になってから G にゲートを取り直させることが書かれている

#### Scenario: G は見張りを始めない
- **WHEN** `skills/develop/references/roles/gate-runner.md` を読む
- **THEN** G が CI の見張りを始めずに `passed` を return することが書かれている

#### Scenario: issue で承認済みの passed は見張りの前に主へ伝える
- **WHEN** `skills/develop/SKILL.md` の (4) の passed の行を読む
- **THEN** return に `issue で承認済み:` の行があれば、CI の見張りを始める前に主へその行（宣言 URL・分類・引用）を 1 回伝えることが書かれている

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

`plugins/dev-workflow/skills/develop/references/roles/worker/finish.md` の (3b) の仕様宣言は、書式と `対象 HEAD:` 規約の正本として `skills/pr-review-gate/declarations.md` を指さなければならない（MUST）。`skills/develop/SKILL.md` の「仕様宣言は記録先ではなく常に PR コメントに置く」の書式の正本の参照も同じファイルを指す（MUST）。

#### Scenario: W の参照先

- **WHEN** `worker/finish.md` の (3b) を読む
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
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定・直し方の判定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | `stages/triage.md` | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `needs-fix-check` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき、引き継ぎの判定を受け取ったとき（合格処理の G が `needs-carryover-judge` を返したあと） | `declarations.md` と `stages/pass.md`（前の HEAD の許容があるとき・保留を返すとき・`needs-carryover-judge` を返すときは加えて `stages/hold.md`） | passed / 保留 / `needs-carryover-judge` |
| 保留の解除 | 主の回答が届いたとき | `stages/hold.md` | 復帰手順の表どおりに `次の段へ`（`次の段:` は合格処理か前提確認と重さ判定） / failed / needs-decider / 保留 |

本体は G の起動指示に `段: <段の名前>` の 1 行を書かなければならない（MUST）。`skills/develop/SKILL.md` の (4)（`(4) G を` で始まる行から、その行を含むコードブロックの閉じ ``` の行まで）と `skills/develop/references/roles/gate-runner.md` は、`SendMessage` の語と `G を再開` の文字列を持ってはならない（MUST NOT）。SKILL.md の (4) の「G の起動・再開・手渡しの指示」「G を再開か手渡しで起こして」も段ごとの起動の言い方に書き換える（MUST）。G への SendMessage は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の停止の指示だけに残し、その規則は decision-criteria.md にだけ書く（MUST）。`gate-runner.md` の「時点ごとに読むファイル」の表は、上の段の表に揃えなければならない（MUST）。

保留の解除の G は、復帰手順の表が別の段の作業に進むと示したとき、その作業を自分で行ってはならず（MUST NOT）、Status `次の段へ` と `次の段:` で返さなければならない（MUST）。許容したとき・切り出して残りが無いときは `次の段: 合格処理`、許容せず代替案で手順 2 からやり直すときは `次の段: 前提確認と重さ判定` とする（MUST）。

W の修正後の再レビューで起こされた前提確認と重さ判定の G は、前の周の指摘を仕分けコメントから読み、`stages/triage.md` の収束ルールどおり差分限定か全体レビューかを自分で判定し、全体レビューにしたときは 2 つの行数を PR コメントに記録しなければならない（MUST）。

保留の解除のあとで起こされた合格処理の G（前の Gate Result が `段: 保留の解除`）は、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば、宣言を出し直してはならず（MUST NOT）、手順 5 の真正性確認から入らなければならない（MUST）。そのコメントが無ければ（切り出しの確認を解除した場合）、`declarations.md` の手順 3 から入らなければならない（MUST）。照合と振り分けのあとの合格処理は、前の Gate Result の `段: 照合と振り分け` で見分ける（MUST。`次の段: 合格処理` は保留の解除の Gate Result にもあるため入口の判別に使わない）。許容済みの PR で HEAD が動いていたときの許容の引き継ぎ（手順 3-c）は、合格処理の G が宣言の前に `stages/hold.md` を読んで試す（MUST）。引き継ぎの判定を受けて起こされた合格処理の G（前の Gate Result が `段: 合格処理`・Status `needs-carryover-judge`）は、`declarations.md` の手順 3 から入り直し、3-c で PR の判定の記録を読まなければならない（MUST）。

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

#### Scenario: 段の表に needs-fix-check がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 照合と振り分けの行の起こす時点に「直し方の判定を受け取ったとき」があり、返しうる Status に `needs-fix-check` がある

#### Scenario: 段の表に needs-carryover-judge がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 合格処理の行の起こす時点に「引き継ぎの判定を受け取ったとき」があり、返しうる Status に `needs-carryover-judge` がある

#### Scenario: 引き継ぎの判定のあとの合格処理

- **WHEN** 合格処理の G が `needs-carryover-judge` で返し、本体が判定の記録を投稿して合格処理の G を新しく起こす
- **THEN** 新しい合格処理の G は前の Gate Result の `段: 合格処理`・Status `needs-carryover-judge` を見て `declarations.md` の手順 3 から入り直し、3-c で判定の記録を読む

### Requirement: Gate Result は段と次の段を持つ

`gate-runner.md` の Gate Result の共通欄は、`段: <前提確認と重さ判定|照合と振り分け|合格処理|保留の解除|一括（従来経路）>` と `次の段: <段の名前|なし>` を持たなければならない（MUST）。Status には `次の段へ` と `needs-fix-check`（直し方の判定の依頼）と `needs-carryover-judge`（許容の引き継ぎの判定の依頼）を足す（MUST）。`次の段:` の値は G が次の表どおりに決めて書く（MUST）。

| Status | `次の段:` |
|---|---|
| `次の段へ` | 照合と振り分けの G は `合格処理`。保留の解除の G は `合格処理` か `前提確認と重さ判定` |
| failed | 戻した指摘が順 3 だけなら `照合と振り分け`、それ以外は `前提確認と重さ判定` |
| needs-reviewer / needs-decider / needs-fix-check | `照合と振り分け` |
| needs-carryover-judge | `合格処理` |
| 保留 | `保留の解除` |
| passed / review-incomplete | `なし` |

本体は Status と `次の段:` だけを見て次に起こす G の段を決め、段についての判断（止める指摘が残っているか、戻した指摘の仕分け、復帰手順がどこへ進むか）をしてはならない（MUST NOT）。failed のときは W の修正のあと、failed の Gate Result の `次の段:` どおりに起こす（MUST）。戻した指摘が順 3 だけの修正のあとに起こされた照合と振り分けの G は、`stages/prepare.md` の手順 1 で新しい HEAD を固め、前の重さ判定を写した `レビュー重量:` コメントを `固定 HEAD: <新しい HEAD>` 付きで投稿してから 2 段の照合に入らなければならない（MUST）。

#### Scenario: 順 3 だけの failed

- **WHEN** 照合と振り分けの G が、戻す指摘が順 3 だけの failed を返す
- **THEN** Gate Result は `次の段: 照合と振り分け` を持ち、本体は W の修正のあと照合と振り分けの G を起こす

#### Scenario: 止める指摘が無いとき

- **WHEN** 照合と振り分けの G が止める指摘なしで終わる
- **THEN** G は Status `次の段へ`、`次の段: 合格処理` で返し、本体は合格処理の G を新しく起こす

#### Scenario: needs-fix-check の次の段

- **WHEN** 照合と振り分けの G が Status `needs-fix-check` で返す
- **THEN** Gate Result は `次の段: 照合と振り分け` を持ち、本体は直し方の判定のあと照合と振り分けの G を新しく起こす

#### Scenario: needs-carryover-judge の次の段

- **WHEN** 合格処理の G が Status `needs-carryover-judge` で返す
- **THEN** Gate Result は `次の段: 合格処理` を持ち、本体は判定役の判定のあと合格処理の G を新しく起こす

### Requirement: 段と段の間の受け渡しは PR コメントを正とする

G は前の段の会話を持たない前提で動かなければならない（MUST）。段と段の間で渡すものは次の PR コメントに置く（MUST）。

| 渡すもの | 置き場所 | 書く G |
|---|---|---|
| 固定した HEAD | `レビュー重量:` コメントの `固定 HEAD: <SHA>` の行（周ごとに増えるので最新の 1 件を正とする） | 前提確認と重さ判定 |
| レビューの三表と補足済み回数（補足を頼んだ時点で 1。コメントが無ければ 0） | 1 行目 `レビュー三表:` のコメント（`補足済み回数:` の行を持つ） | 照合と振り分け |
| 振り分けの結果 | 既存の仕分けコメント | 照合と振り分け |

照合と振り分けの G は、補足の `needs-reviewer` を返す前に `補足済み回数: 1` を書いた `レビュー三表:` のコメントを投稿しなければならない（MUST。補足を頼んだ時点で 1 と数え、reviewer への payload は 0 のまま）。補足済み回数は G が交代しても最新の `レビュー三表:` のコメントから読み、リセットしてはならない（MUST NOT）。止める指摘が無い周で止めない指摘を振り分け表（dev-workflow-pr-review-gate の「止めない指摘は振り分け表に上から当てる」Requirement）に通すのは照合と振り分けの G で、`次の段へ` を返す前に行う（MUST。1 周目に段 A に当たる指摘があれば `次の段へ` ではなく `agent-review:failed` で返す）。

固定した HEAD の行を `対象 HEAD:` と書いてはならない（MUST NOT。auto-merge workflow がこの文字列を宣言の照合に使うため）。

本体は次の G の起動指示に、前の段の `## Gate Result` ブロックを要約し直さずそのまま貼り、段に固有の入力（レビュー要約・補足レビューの結果・決める役の裁定・直し方の判定とその記録の URL・主の回答・W の修正の要約）を足さなければならない（MUST）。起動指示と PR コメントが食い違ったら、G は PR コメントを正としなければならない（MUST）。

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

既存要件のうち G の「再開」「SendMessage で G に渡す」「G を再開して再レビュー」と書いた箇所は、上の要件「G は段ごとに新しく起こし、SendMessage で再開しない」の表で、その時点に当たる段の G を新しく起こし、その起動指示に渡すものとして読まなければならない（MUST）。`レビュー経路: adapter` で起動済みの同一 G が行の無い再開指示でも adapter 経路を保つ規則は、再開が無いので `gate-runner.md`・SKILL.md・`plugins/dev-workflow/references/codex-develop.md` から消さなければならない（MUST）。本体がすべての G の起動指示に `レビュー経路: adapter` の 1 行を書く規則は変えない（本文は SKILL.md の「Role profile の選択」節に置き、`references/codex-develop.md` はそこを指す）。

`stages/prepare.md` に置くとした「レビュー実行者:」PR コメントの段落は、上の要件「『レビュー実行者:』コメントの段落は照合と振り分けの段に置く」どおり `stages/triage.md` を指すものとして読む（MUST）。

この読み替えは、少なくとも次の既存要件に掛かる: 「1 ループは W→R1→W→G の順で回る」（修正後は G を再開して差分再レビュー）・「役割の指示書は references/roles/ に分かれている」（要約を G に SendMessage で渡す）・「役割のモデルは事前分類と残量モードで決める」（Scenario「再開前にコンテキスト量を測る」の G の部分は適用しない）・「G の needs-decider を受けた本体の動き」（裁定を SendMessage で渡して G を再開する）・「G はレビュー経路を起動指示の 1 行で判別する」（Scenario「adapter 経路で起動済みの G を行無しで再開」は再開が無いので適用しない）・「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」（Claude の G は SendMessage で再開して渡す）・「G は段ごとに要るファイルだけを読む」・「既存要件が gate-runner.md に置いた内容のうち段に移したものは段のファイルを指す」（「レビュー実行者:」の段落の移し先と、再開節の移し先）。

#### Scenario: 裁定の渡し方

- **WHEN** 既存要件「G の needs-decider を受けた本体の動き」に従い、本体が決める役の裁定を受け取る
- **THEN** 本体は照合と振り分けの G を新しく起こし、前の Gate Result ブロックと裁定を起動指示で渡す

#### Scenario: adapter 経路の保持規則が無い

- **WHEN** `gate-runner.md`・SKILL.md・`references/codex-develop.md` を読む
- **THEN** 行の無い再開指示で adapter 経路を保つ規則が無い。G の起動指示に常に `レビュー経路: adapter` を書く規則は、SKILL.md が本文を持ち、`references/codex-develop.md` はその本文を持たず SKILL.md の「Role profile の選択」節と `gate-runner.md`「レビュー経路の判別」を指している

### Requirement: 段ごとの G で上限を超えないことを PR 本文に記録する

この変更の PR の本文は、その PR のゲートを本体が worktree 側の新しい `skills/develop/SKILL.md` と `gate-runner.md` に従って段ごとの G で回した結果として、G ごとの段と終了時のコンテキスト量、150K を超えた G の数、上限による手渡しの回数を記録しなければならない（MUST）。実行時に読まれるプラグインのキャッシュはマージ前の版なので、マージ前の版で測った値であることを本文に明記する（MUST）。

#### Scenario: 記録の確認

- **WHEN** この変更の PR 本文を読む
- **THEN** G ごとの段と終了時のコンテキスト量、150K を超えた G の数（期待値 0）、手渡しの回数（期待値 0）、マージ前の版で測った旨がある

### Requirement: W と G は役割ごとの種別で起こす
develop の本体は W を `subagent_type: dev-workflow:worker`、G を `subagent_type: dev-workflow:gate-runner` で spawn しなければならない（MUST）。`general-purpose` で起こしてはならない（MUST NOT）。種別を替えても `model` は従来どおり spawn のたびに明示しなければならない（MUST。W は事前分類に当たれば `opus`、それ以外 `sonnet`。G は `sonnet`）。手渡しで後任を起こすときと、段ごとに新しい G を起こすときも同じ種別を使う（SHALL）。

`references/codex-develop.md` の Claude role の起動（W / G を Claude で起こす経路）も同じ種別を使わなければならない（MUST。どの role をどの種別で起こすかは `manual-codex-develop` の「委譲は前景実行の 3 手順で行う」が定める）。

G が要求するレビュアー（決める役でないとき）は、本体が `subagent_type: dev-workflow:reviewer` で spawn しなければならない（MUST）。`general-purpose` で起こしてはならない（MUST NOT）。`model` は spawn のたびに明示する（MUST。既定 `opus`）。区画ごとに起こすときと、補足のレビュアーを起こすときも同じ種別を使う（SHALL）。レビュー対象がマージ条件・層間契約・課金/法務に触れるときは従来どおり `dev-workflow:decider` で起こす（SHALL）。pr-review-gate を develop 以外で回すときのフォールバックの Task サブエージェントも `dev-workflow:reviewer` で起こす（SHALL）。ただし change `reviewer-agent-type` の PR（issue #650 の PR）のゲートはマージ前で配布版に新種別が無いので、本体はその change の design.md「この PR のゲートでレビュアーを起こす手順」（`claude -p --plugin-dir` のセッションの中で `dev-workflow:reviewer` を起こす）で行い、そのレビュアーを本体が spawn したものとして扱う（SHALL）。

仕様レビュー R1（決める役でないとき）の種別は変えない（SHALL。`general-purpose`。決める役に当たるときは従来どおり `dev-workflow:decider`）。

`develop/SKILL.md` の役割表と Agent ツールの行、(1)・(3)・(4) の spawn の記述とモデル表、`references/roles/worker/common.md`・`references/roles/gate-runner.md` の冒頭、`skills/pr-review-gate/stages/prepare.md` の needs-reviewer の payload、`skills/pr-review-gate/stages/review-run.md` 2-1 の優先順の表、`plugins/dev-workflow/README.md` の役割とモデルの説明は、それぞれの種別を書かなければならない（MUST）。

#### Scenario: 役割表が種別を書く
- **WHEN** `plugins/dev-workflow/skills/develop/SKILL.md` の役割表を読む
- **THEN** W の行に `dev-workflow:worker`、G の行に `dev-workflow:gate-runner` があり、R1 の行には `dev-workflow:worker` も `dev-workflow:gate-runner` も `dev-workflow:reviewer` も無い

#### Scenario: spawn の記述が種別を書く
- **WHEN** `develop/SKILL.md` の (1) と (4) の spawn の行、`worker/common.md` と `gate-runner.md` の冒頭、`references/codex-develop.md` の Claude role の起動、`plugins/dev-workflow/README.md` の役割とモデルの説明を読む
- **THEN** W には `dev-workflow:worker`、G には `dev-workflow:gate-runner` が書かれ、W / G を `general-purpose` で起こす記述が無い

#### Scenario: レビュアーの spawn の記述が種別を書く
- **WHEN** `develop/SKILL.md` の Agent ツールの行とモデル表の「G が要求するレビュアー」の行、`stages/prepare.md` の needs-reviewer の payload の前の段落と `推奨モデル` の行、`stages/review-run.md` 2-1 の表のフォールバックの行を読む
- **THEN** レビュアーの既定の種別として `dev-workflow:reviewer` が書かれ、事前分類に当たるときの `dev-workflow:decider` が残り、レビュアーの段落・行に `subagent_type: general-purpose` と `` Agent ツール（`general-purpose`） `` の形が無い（`` `general-purpose` に `model: fable` は付けない `` の文言は残ってよい）

### Requirement: W の仕様化経路は openspec CLI だけで進める
`dev-workflow:worker` は `Skill` を持たないので、W は仕様化・実装の検証・archive を openspec CLI で行わなければならない（MUST）。仕様化は `openspec new change` と artifact の直書き（雛形と書き方の指示は `openspec instructions <artifact> --change <name>`、依存順は `openspec status --change <name>` で得る）、実装の検証は `openspec validate <change> --strict` と `tasks.md` のチェックボックスの確認、archive は `openspec archive <change>` で行う（SHALL）。工程の区切り（(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言）は変えない（SHALL）。R1 の仕様レビューも、文言合わせの通し方（次の段落）を除いて変えない（SHALL）。

文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）では、change に proposal.md が無いので、W は実装の検証を `openspec validate <change> --type change --strict` で行わなければならない（MUST。`--type change` を付けない形の結果は openspec の版で変わる。change を見つけられず `Unknown item` で終了コード 1 になる版も、change として検証して終了コード 0 になる版もある。付けておけば版によらず change として検証され、spec と同名のときの曖昧さも避けられる。`openspec validate --changes --strict` もこの change を検査しない版があるので使わない）。`tasks.md` が無いのでチェックボックスの確認は行わない（SHALL）。`openspec archive <change>` は見出しが既存の要件名と一致しないとき、何も変えずに終了コード 0 で終わるので、W は archive のあと `openspec/changes/archive/` に change のディレクトリがあることを確かめる（MUST）。`references/roles/worker/implement.md` と `references/roles/worker/finish.md` はこの 2 点を書かなければならない（MUST）。

W の仕様化経路があるかどうかは `openspec --version` が成功するかだけで決めなければならない（MUST）。`.claude/commands/opsx/` の有無で決めてはならない（MUST NOT）。opsx コマンドがあっても openspec CLI が無ければ、W は `仕様化判断: しない` の理由に「openspec 不在」と書いてコード直行する（SHALL）。

索引 `references/roles/worker.md`・`references/roles/worker/` の 4 本・`references/pre-classification.md` で `/opsx:` のスラッシュコマンドが出てよいのは、本体や主が対話で `/opsx:*` を使う場面（例: W が来る前に本体や主が `/opsx:ff` で change を作っていた場合）を述べる行だけで、その行は `本体` か `主` の語を含まなければならない（MUST）。W が `/opsx:*` を実行する指示を書いてはならない（MUST NOT）。

#### Scenario: worker/ の 4 本が CLI の経路で書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/roles/` の索引 `worker.md`・`worker/` の 4 本・`pre-classification.md` を読む
- **THEN** `openspec new change`・`openspec validate`・`openspec archive` を使う手順があり、(3a) の節と (3b) の節に `/opsx:` の文字列が無く、`/opsx:` を含む行はどれも `本体` か `主` の語を含む

#### Scenario: 文言合わせの通し方の検証コマンドが書かれている
- **WHEN** `references/roles/worker/implement.md` の実装と verify の記述と、`references/roles/worker/finish.md` の archive の記述を読む
- **THEN** `implement.md` に文言合わせの通し方では `openspec validate <change-name> --type change --strict` を使うことが書かれ、`finish.md` に archive のあと `openspec/changes/archive/` に change のディレクトリがあることを確かめることが書かれている

#### Scenario: proposal.md の無い change を名前だけで検証する
- **WHEN** `specs/<capability>/spec.md` だけを持つ change（どの spec とも名前が違うもの）に `openspec validate <change> --type change --strict` を実行する
- **THEN** 差分が検査され、正しい差分なら版によらず終了コード 0 で終わる。`--type change` を付けない形は、終了コード 0 で終わるか、`Unknown item` と出て終了コード 1 で終わるかのどちらかで、どちらになるかは openspec の版で決まる。change と同名の spec があると名前が曖昧になり、`Ambiguous item` と出て終了コード 1 で終わる版がある。`--type change` を付ければこの曖昧さは起きない

#### Scenario: 経路の有無を CLI だけで決める
- **WHEN** `worker/spec.md` の仕様化判断の節と、`develop/SKILL.md` の前提の表の openspec の行を読む
- **THEN** W の経路の有無を `openspec --version` で決めることが書かれ、索引 `worker.md`・`worker/` の 4 本・`pre-classification.md` に `ls .claude/commands/opsx/` による検出が無い

### Requirement: .worktreeinclude が無いときの /wt-setup は本体が行う
worktree に `.worktreeinclude` が無いときに `/wt-setup` を呼ぶのは本体でなければならない（MUST）。W は `/wt-setup` を呼んではならない（MUST NOT。`dev-workflow:worker` は `Skill` を持たない）。`worker/common.md` の「W がしないこと」から W が `/wt-setup` を呼ぶ例外を消し、`develop/SKILL.md` の worktree を用意する節に本体の仕事として書かなければならない（MUST）。

#### Scenario: 例外が本体の仕事に移っている
- **WHEN** 索引 `worker.md`・`worker/` の 4 本・`pre-classification.md` と `develop/SKILL.md` を読む
- **THEN** 索引 `worker.md`・`worker/` の 4 本・`pre-classification.md` に W が `/wt-setup` を呼ぶ記述が無く、`develop/SKILL.md` の worktree を用意する節に、`.worktreeinclude` が無いとき本体が `/wt-setup` を呼ぶことが書かれている

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
| 実行モード | interactive / channel / unmanned |
| 実行先 | 実行先オプションと account-home の対応（明示したときだけ。無ければ `自動選択`）と、開始済みの phase ごとの選択結果（構成・executor・account・model）が書かれたコメントの URL。最初の phase の選択結果は develop 開始コメント（`develop/SKILL.md`「Role profile の選択」）、以降の phase は dispatch 記録のコメントにある。両方書く（どちらも無ければ `なし`） |
| 次に起こす役割 | 返事のあとに最初に起こす役割と、渡す入力の在り処 |
| 周回 | 仕様レビューと G の周回の数・W の修正の周回の数 |
| 前任 W | 直近の return の 1 行目と要約または URL（W を起こしていなければ `なし`）と、手渡し可否（次の段落） |
| PR トークン上限 | 最新の値と、止まった時点の合計 |
| 回し方 | エピックの子のときだけ。それ以外は `なし` |

W の名前は書かない（新しいセッションでは SendMessage できないため）。同じ記録先で再び止まるときは新しいコメントを投稿し、読む側は最新の 1 件を正とする（MUST）。

**前任 W の手渡し可否**: 前任 W を後任へ手渡してよいのは、`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」を満たすときだけである（MUST）。新しいセッションの本体は前任に停止を指示できないので、本体は引き継ぎを書く前に、前任 W の直近の return の 1 行目が `工程完了:` であることを確かめるか、前任が `工程中断:` なら前任に停止を指示して停止確認を受け取り、未コミット差分があれば本体が commit する（MUST。commit してから引き継ぎを書く）。いずれかを満たしたら「前任 W」の項目に `手渡し: 可（工程完了 | 停止確認済み）` と確認結果（編集ファイル・commit の SHA）を書く。どちらも満たせないとき（exit 2 で SendMessage を送れない・前任が停止確認を返さない）は `手渡し: 不可（<理由>）` と書く。W を起こしていなければ `手渡し: 不要` と書く。

interactive の本体は主への依頼に「返事は新しいセッションで `/develop <記録先>` と一緒に渡す。1 時間以内に返事ができるなら、このセッションで続けてもよい」という案内を含めなければならない（MUST）。channel の本体はこの案内を出さず、要件「channel モードの保留はチャンネルの返事で再開する」の案内を出す（MUST）。引き継ぎのコメントは、返事がいつ来るかを本体が知らないので、どのモードでも必ず残し、どちらで続けるかは主が決める（MUST）。

#### Scenario: pr-review-gate の保留で止まる

- **WHEN** interactive の G が保留で返り、本体が `needs-approval` のまま主に 1 アクションで依頼する
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

#### Scenario: channel の保留でも引き継ぎを残す

- **WHEN** channel の本体が pr-review-gate の保留で止まる
- **THEN** 本体は同じ書式の引き継ぎのコメントを `実行モード: channel` で残し、主への案内に新しいセッションを開く案内を含めない

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

### Requirement: W の return は読んだコードの要点を持つ

`references/roles/worker/common.md` は、W の return の成果一覧（この欄は W の場合のみ必須で、G の return の契約は変えない。工程の終わりの return、途中で締めた return、昇格トリップワイヤーで止まったときの return のいずれも）に「読んだコードの要点」欄を含めることを書かなければならない（MUST）。欄の書式は 1 行 1 件の `<リポジトリ相対パス>:<開始行>-<終了行> — <そこから分かったこと>` とし、上限を 20 行とし、超えるときは次の工程で読む必要が高いものを残すと書かなければならない（MUST）。

`worker/common.md` の「コンテキスト上限と手渡し」の節は、手渡しで起こされた W に向けて、前任の要点は読む場所の案内であり、編集する前には該当範囲を自分で読んで確かめることを書かなければならない（MUST）。要点を判断の根拠として読み替えてよいと書いてはならない（MUST NOT）。

`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の節が成果一覧を列挙する箇所（`工程完了:` の説明と、通知を受けたときの振る舞い）は W / G 共通の定義なので、「読んだコードの要点」を「W の場合のみ必須」という条件付きで含まなければならない（MUST）。G に必須と読める無条件の追記をしてはならない（MUST NOT。G は段ごとに新しく起こされ、`工程中断:` の return を同じ段の新しい G に渡す既存の経路はこの欄を前提にしないため）。書式（1 行の形・上限行数）は `worker/common.md` を正本とし、`decision-criteria.md` に再掲してはならない（MUST NOT。上限を変えたときに片方が取り残されるため）。

#### Scenario: worker/common.md の手渡しの節に欄と書式がある
- **WHEN** `references/roles/worker/common.md` の「コンテキスト上限と手渡し」の節を読む
- **THEN** 成果一覧に「読んだコードの要点」があり、W の場合のみ必須であること、1 行 1 件の `ファイル:行の範囲 — 分かったこと` の形と上限 20 行が書かれている

#### Scenario: 後任は要点を案内として扱う
- **WHEN** `references/roles/worker/common.md` の「コンテキスト上限と手渡し」の節の、手渡しで起こされたときの箇条を読む
- **THEN** 前任の要点は読む場所の案内であり、編集前に該当範囲を自分で読んで確かめると書かれている

#### Scenario: (3a) とトリップワイヤーの return にも欄がある
- **WHEN** `references/roles/worker/implement.md` の「(3a) の return に書くこと」と `references/roles/worker/common.md` の「昇格トリップワイヤー」の節を読む
- **THEN** どちらにも「読んだコードの要点」を書くことが含まれている

#### Scenario: 手渡しの入力の定義に欄の名前がある
- **WHEN** `references/decision-criteria.md` の「コンテキスト上限（サブエージェントの手渡し）」の節を読む
- **THEN** 成果一覧を列挙する 2 箇所がどちらも「読んだコードの要点」を「W の場合のみ必須」の条件付きで含み、書式は `worker/common.md` を参照していて、上限行数の数値は書かれていない

### Requirement: (1) で作業項目ごとに触る範囲を書く

`references/roles/worker/spec.md` は、仕様化する場合、W が `tasks.md` の各タスクに `触る範囲: <パス>:<開始行>-<終了行>`（複数は並べる。新しく作るファイルは `<パス>（新規）`）を書くことを書かなければならない（MUST）。行番号は仕様づくりの時点の値で前のタスクの編集でずれうること、実装の担い手は編集前に該当範囲を読むことを添えなければならない（MUST）。

仕様化しない（コード直行）と判定した場合は、同じ内容を作業項目ごとに (1) の return に書くことを書かなければならない（MUST）。

#### Scenario: 仕様化する場合の tasks.md に触る範囲を書く
- **WHEN** `references/roles/worker/spec.md` の「仕様化する場合（(1) の終わり）」の節を読む
- **THEN** `tasks.md` の各タスクに `触る範囲:` を `ファイル:行` の形で書くこと、行番号は着手時点の値でずれうること、編集前に該当範囲を読むことが書かれている

#### Scenario: 仕様化しない場合は return に書く
- **WHEN** `references/roles/worker/spec.md` の仕様化判断の節の、仕様化しないと判定した場合の段落を読む
- **THEN** 作業項目ごとの `触る範囲:` を (1) の return に書くことが書かれている

### Requirement: W の 1 周目モデルの変更は過去 PR の再実行による比較記録に基づく

事前分類表（`references/pre-classification.md`）の「1 周目」列のモデルを変える場合は、変更の前に、過去にマージされた PR のうち issue の対象条件（聖域パス・スキル本文・hooks などに触れる）を満たし、事前分類に当たる W が元のモデルで実装したもの 3 件を、マージ前の base から新しいモデルの W で再実行し、元の実績と比べた記録を `plugins/dev-workflow/changes/<記録先 issue 番号>.md` に残さなければならない（MUST）。記録には対象 3 件の PR 番号、3 件それぞれのテスト結果（exit code）・ゲート指摘件数（severity が `blocking` かつ status が `confirmed` の件数。元 / 新の両方）・トリップワイヤー発火の有無（元 / 新の両方）を並べた表、再実行の W が新しいモデルで動いた証拠（subagent の jsonl の `"model"` 値の検索コマンドと結果）、判定（表を変えるか変えないか）とその根拠を含めなければならない（SHALL）。

再実行のゲート指摘件数は、本体が再実行ごとに独立レビュアーを起動し、元のゲートと同じ指摘基準を渡して、指摘一覧をローカルの成果物として返させ、本体はその件数を集計するだけにしなければならない（MUST。本体はレビューを書かない）。

判定の「同等」は、次の 3 項目がすべて成り立つことを指す（SHALL）。(a) 各 PR で追加・変更されたテストと `bats plugins/dev-workflow/tests` が、再実行でも exit 0 である。(b) severity が `blocking` かつ status が `confirmed` の指摘件数が、元の件数以下である。(c) W のトリップワイヤー（規模超過・失敗ループ・仕様の発明）の発火が、元に無ければ再実行にも無い。3 件とも同等なら変える、1 件でも成り立たなければ変えない。テストの失敗、元のログの欠測、再実行やレビューの実行不能など証拠が足りない項目は同等と判定してはならない（MUST NOT。「変えない」に倒す）。結果を見てから規則を動かしてはならない（MUST NOT）。

再実行の W は GitHub に書き込んではならない（MUST NOT。push・issue と PR へのコメント・PR 作成・ラベル付けをせず、ローカル commit とテスト実行までに留める）。変える場合でも W の上限は `opus` のままとし、R1・G・決める役のモデルと昇格ラダーは変えてはならない（MUST NOT）。変える場合は、`references/pre-classification.md` の表と `skills/develop/SKILL.md` の事前分類に関する記述、および既存要件（役割の指示書は references/roles/ に分かれている／役割のモデルは事前分類と残量モードで決める／W と G は役割ごとの種別で起こす）を、表を変える前の R1 再レビューで一緒に示さなければならない（MUST）。

この要件の守備範囲: 入力は、本体が集めた再実行の結果（bats の exit code、独立レビュアーの指摘一覧、W の return のトリップワイヤー記録）と、元の PR コメント・issue コメントから取った実績である。拾う誤りは、比べる証拠が足りないまま、または基準を動かしてモデルを下げること。通してよい入力の例は、3 件で指摘件数が元と同じ 0 件、元の Gate Result のコメントに件数が書かれているもの。同じ観点の別表現（例: `should` 1 件を `nit` と数えるレビュアーのぶれ）は、元と同じ指摘基準を渡す範囲で許容する。3 件では、まれにしか起きない失敗や、レビュアーの判断のぶれを見つけきれないが、それを塞ぎ切ることは完了条件にしない。表を変えたあとの品質低下は、W の失敗の return から Opus で再開する既存の昇格で拾う。

#### Scenario: 記録に 3 件の比較表がある
- **WHEN** 事前分類表のモデルを変える検証の記録 `plugins/dev-workflow/changes/<記録先 issue 番号>.md` を読む
- **THEN** 対象 3 件の PR 番号と、各件のテスト結果・ゲート指摘件数・トリップワイヤー発火の有無が元 / 新の別で並んだ表があり、`grep -cE '^\| *#[0-9]+'` が 3 以上を返す

#### Scenario: 新しいモデルで動いた証拠がある
- **WHEN** 記録の「新しいモデルで動いた証拠」を読む
- **THEN** 再実行の W の subagent jsonl に対する `grep -o '"model":"<新しいモデルの ID>"'` のコマンドと 1 件以上のヒット結果が書かれている

#### Scenario: 証拠が足りない項目は同等にならない
- **WHEN** 3 件のうち 1 件でテストが失敗した、または元のゲート指摘件数が取れなかった
- **THEN** 判定は「変えない」で、事前分類表は従来のままである

#### Scenario: 独立レビュアーが指摘を数える
- **WHEN** 再実行のゲート指摘件数を集める手順を読む
- **THEN** 本体は独立レビュアーを起動して指摘一覧をローカルの成果物で受け取り、件数の集計だけを行う

### Requirement: W の指示書は索引・共通・段のファイルに分かれている

`plugins/dev-workflow/skills/develop/references/roles/worker.md` は索引でなければならない（MUST）。索引は、段の表（段の名前 `spec` / `implement` / `finish`・日本語名・担う工程・読むファイル）だけを持ち、手順の本文・コードブロック（```）・旧 worker.md の節から移し先への対応表を持ってはならない（MUST NOT）。

W の手順の本文は `skills/develop/references/roles/worker/` の次の 4 本に置かなければならない（MUST）:

- `common.md`（全段で読む）: 本体が渡すもの（`段:` の行を含む）・W がしないこと・実装に入る前の確認（仕様化判断の記録前に実装へ進まないこと・仕様化した場合に R1 の APPROVE を確認してから実装に入ること・仕様レビュー結果の書式）・昇格トリップワイヤー・コンテキスト上限と手渡し（「(3) をこれより細かく切らない」の箇条を除く）
- `spec.md`（仕様づくり。(1) と R1 の差し戻しの修正）: 記録先の用意（Draft PR を記録先にする場合）・仕様化判断と記録・分割判定・仕様化する場合
- `implement.md`（実装と検証。(3a) と、G の failed や CI の見張りの `fix` を受けた修正）: (3a) 実装＋verify
- `finish.md`（仕上げ。(3b)）: (3b) archive＋PR＋仕様宣言

どの段でも要る規則（W がしないこと・実装に入る前の確認・昇格トリップワイヤー・コンテキスト上限と手渡し）は `common.md` に置き、それを使う全部の段から読める位置になければならない（MUST。1 つの段のファイルにだけ置いて、他の段で効かなくしてはならない）。1 回の起動で読む字数に上限は置かない。字数を減らすことを配置の理由にしてはならず（MUST NOT）、節の置き場所は、その節を使う段と読み手（W か本体か）で決める。`worker/` の 4 本・索引・`references/pre-classification.md` の `## ` 見出しは、このうち 1 ファイルにだけなければならない（MUST。同じ節を 2 か所に書かない）。移すときに手順の中身（規則・書式・コマンド・閾値）を変えてはならない（MUST NOT）。段をまたぐ参照はファイル名と節名で書き、中身を言い換えて再掲してはならない（MUST NOT）。

「(3) をこれより細かく切らない」の箇条（手渡しの固定分と、実装の途中で交代させたときに後任が Red のテストから再出発する理由）は、develop の `SKILL.md` の (3) に置かなければならない（MUST）。SKILL.md はこれを理由の正本として持ち、索引 `references/roles/worker.md` や `references/roles/worker/` の指示書を理由の正本として指してはならない（MUST NOT）。

この要件の回帰テスト（`plugins/dev-workflow/tests/develop-worker-stages.bats`）の守備範囲は次のとおりとする。入力は索引 `references/roles/worker.md`・`worker/` の 4 本・`references/pre-classification.md` のファイルの中身で、拾うのは、索引の中のコードブロック・段の表が指すファイルの不在・昇格トリップワイヤーの節が `common.md` に無いこと・同じ `## ` 見出し行が 2 ファイル以上にあること、である。次はテストを通ってしまい、この要件の回帰テストでは止めない: 見出しを変えて同じ節を別のファイルに書いたもの、見出し以外の本文で規則を言い換えて再掲したもの、移すときに規則・書式・コマンド・閾値の文言を変えたもの、索引がコードブロックを使わずに旧 worker.md の節から移し先への対応表を持つもの、W が段のファイル以外（`decision-criteria.md` の節など）を読む分。これらは PR レビューで見る。この穴をテストで塞ぎ切ることは完了条件にしない。

#### Scenario: 索引が中身を持たない

- **WHEN** `references/roles/worker.md` を読む
- **THEN** コードブロックが無く、段の表の `spec` / `implement` / `finish` の各行がそれぞれ `worker/spec.md` / `worker/implement.md` / `worker/finish.md` の 1 つだけを指し、そのファイルと `worker/common.md` が実在する

#### Scenario: どの段でも要る規則が全段から読める

- **WHEN** `worker/common.md` の見出しを読む
- **THEN** 「W がしないこと」「実装に入る前の確認」「昇格トリップワイヤー」「コンテキスト上限と手渡し」の節があり、段のファイル（`spec.md` / `implement.md` / `finish.md`）にはこれらの見出しが無い

#### Scenario: 実装の段から起こされた W も承認の確認を読む

- **WHEN** 手渡しや Codex の新しい phase で `段: implement` の W が起こされ、`worker/common.md` と `worker/implement.md` だけを読む
- **THEN** 仕様化判断の記録前に実装へ進まないことと、仕様化した場合に R1 の APPROVE のコメントを確認してから実装に入ることが読める

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

### Requirement: 事前分類表は W が読まないファイルに置く

重要実装の事前分類（聖域パス・マージ権限・層間契約・課金/法務の表と、W の上限・読んで判断する役の種別・残量モードの優先の説明）は、`plugins/dev-workflow/skills/develop/references/pre-classification.md` に置かなければならない（MUST）。このファイルが事前分類の正本であり、`worker/` の 4 本と索引に表を再掲してはならない（MUST NOT）。

事前分類を参照する次の箇所は `references/pre-classification.md` を指さなければならず（MUST）、事前分類について索引 `references/roles/worker.md` や `references/roles/worker/` の指示書を指してはならない（MUST NOT）: develop の `SKILL.md` の (1) の spawn の行と「モデル」の役割表・`references/roles/spec-reviewer.md`・`references/decision-criteria.md` の残量モード表・pr-review-gate の `stages/triage.md`・`plugins/dev-workflow/references/model-tiers.md`・`plugins/dev-workflow/README.md`。

#### Scenario: 表が 1 か所にある

- **WHEN** `references/pre-classification.md` と `worker/` の 4 本と索引を読む
- **THEN** 事前分類表の 4 行は `pre-classification.md` にだけある

#### Scenario: 参照元が新しい置き場所を指す

- **WHEN** 上に挙げた参照元の、事前分類に触れる行を読む
- **THEN** どれも `pre-classification.md` を指し、事前分類について `roles/worker.md` や `roles/worker/` の指示書を指す行が無い

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

### Requirement: Codex の W の phase には共通と段のファイルを正本として渡す

`plugins/dev-workflow/scripts/codex-develop.py` は、Codex の W の phase に次の正本を付けなければならない（MUST）: `spec` は `skills/develop/references/roles/worker/common.md` と `worker/spec.md`、`implement` と `finish` は `worker/common.md` とそれぞれ `worker/implement.md`・`worker/finish.md`、`explore` と `summarize` は `worker/common.md` だけ。`skills/develop/references/decision-criteria.md` を付けることは変えない（MUST）。索引 `roles/worker.md` を正本として付けてはならない（MUST NOT）。

#### Scenario: phase ごとの正本

- **WHEN** `codex-develop.py request` で `spec` / `implement` / `finish` / `explore` / `summarize` の依頼を作り、prompt の `CANONICAL SOURCE` 行を読む
- **THEN** 上の組み合わせのファイルが付き、`skills/develop/references/roles/worker.md` は付いていない

### Requirement: W の指示書の読み込み量は個体ごとに測り、分割前と並べて記録する

W の指示書の読み込み量は、`plugins/dev-workflow/scripts/subagent-context-audit.sh --by-role` で W の個体ごとに測った値として、分割前と分割後を並べて記録しなければならない（MUST。issue #556 の受け入れ条件 2）。分割前の値はこの変更の PR（#610）の本文に記録する（MUST）。分割後の値は、この変更のマージ後に、最初に変更後の指示書（キャッシュに入った `worker/` の段のファイル）で動いた develop の W を同じ方法で測り、PR #610 とエピック #511 のコメントに追記する（MUST）。この issue の W は変更後の指示書を手順として読んでおらず（編集対象として worktree のパスから開いただけ）、分割後の値を取れないためである（主の承認 2026-09-29、issue #556 のコメント）。読み込み量に上限は置かず、値の大きさを達成の可否に使ってはならない（MUST NOT）。

分割後の計測対象は、マージ後に最初に変更後の指示書で動いた develop の 1 本に現れた W の全個体（(1) の spawn・SendMessage で再開された個体・手渡しの後任を含む）とする（MUST）。分割前の値は、変更前の worker.md で動いた W の個体（この issue 自身の develop の W）を同じ方法で測った値とする。`by_role.W.docs_median` は W の個体ごとの合計の中央値（同スクリプト冒頭のコメント）なので、担当全体の `docs_median` だけを記録して個体ごとの値の代わりにしてはならない（MUST NOT）。個体の値は、その個体の `agent-<id>.jsonl` と `agent-<id>.meta.json` だけを `<作業用ディレクトリ>/<任意>/<任意>/subagents/` に置き、その作業用ディレクトリを `--projects` に、別の作業用ファイルを `--cache` に渡して `--refresh` 付きで実行し、`by_role.W.count` が 1 であることを確かめてから読んだ `by_role.W.docs_median` とする（MUST）。

同スクリプトが指示書の Read として数えるのは、`plugins/cache/oratta-claude-harness/` を含み `.md` で終わるパス（`INSTR_RE`）だけである。この外のパス（worktree の中など）から変更後の指示書を読んだ個体の値は指示書の分が入らず小さく出るので、その値を読み込み量として記録してはならず（MUST NOT）、測れなかった個体として理由とともに記録しなければならない（MUST）。

#### Scenario: 分割前の個体ごとの値が PR 本文にある

- **WHEN** この変更の PR 本文の受け入れ条件 2 の節を読む
- **THEN** 分割前の W の個体ごとに agent id・担った工程・`by_role.W.count` が 1 だったこと・値が並び、担当全体の `docs_median` だけで済ませておらず、分割後の値はマージ後の develop で測って追記することが書かれている

#### Scenario: 分割後の値はマージ後に追記する

- **WHEN** この変更のマージ後、最初に変更後の指示書で動いた develop が終わった
- **THEN** その develop の W の個体ごとに agent id・担った工程・`by_role.W.count` が 1 だったこと・値が、分割前の値と同じ形で PR #610 とエピック #511 のコメントに追記されている

#### Scenario: 数えられないパスから読んだ個体

- **WHEN** 計測に使った W が変更後の指示書を `plugins/cache/oratta-claude-harness/` を含まないパス（worktree の中など）から読んでいた
- **THEN** その個体は値ではなく、測れなかった個体として理由とともに記録されている

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

### Requirement: 停止確認が返らないときの終端を観測できる量で定義し、帰結は手渡さず人間に報告する

前任のサブエージェントへ停止を指示したあと停止確認が返らないときの終端は、観測できる量で定義しなければならず（MUST）、閾値は環境変数で上書きできなければならない（MUST）。閾値の数値と環境変数名の正本は `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の節であり、この spec に数値を書いてはならない（MUST NOT）。終端に達したとき、本体は手渡し先を spawn してはならず（MUST NOT）、その作業を止めて人間に報告しなければならない（MUST）。終端は手渡しの許可条件（前任の `工程完了:` return か停止確認）に加わる第 3 の経路ではない。

#### Scenario: 終端に達する
- **WHEN** 停止を指示してからの経過時間と前任のトランスクリプトの無更新時間がどちらも閾値以上になる
- **THEN** 本体は手渡し先を spawn せず、前任の名前・停止を指示した時刻・worktree の `git status` を添えて人間に報告し、前任の再開の可否は人間の指示を待つ

#### Scenario: 片方の条件だけ満たす
- **WHEN** 経過時間は閾値以上だが前任のトランスクリプトが直近に更新されている
- **THEN** 終端とみなさず、停止確認を待つ手順を続ける

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

### Requirement: G の needs-fix-check を受けた本体の動き

`skills/develop/SKILL.md` の 1 ループの (4) は、G の Status `needs-fix-check` を受けた本体の動きを書かなければならない（MUST）: 本体は「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の手順で決める役を起こして判定を受け取り、判定の記録を記録先に投稿し、判定（「決まっている」または「選び直しが要る」）と判定の記録の URL を渡して照合と振り分けの G を新しく起こす（MUST）。本体は判定を受けて自分で `agent-review:failed` を付けたり W を再開したりしてはならない（MUST NOT。ラベルの付け替えと W に戻す指摘の一覧は G が決める）。

#### Scenario: needs-fix-check で返った
- **WHEN** G が Status `needs-fix-check`・`次の段: 照合と振り分け` で return する
- **THEN** 本体は PR トークン上限を測ってから決める役を起こし、判定の記録を記録先に投稿し、判定とその URL を渡して照合と振り分けの G を新しく起こす

### Requirement: 保留の許容は会話の返事で受け、PR へのコメントを求めない

この要件の案内と、会話で受けた許容に PR へのコメントを求めない決まりは、interactive の本体のものである。channel の本体は、要件「channel モードのリスク許容はチャンネルの返事を確かめられるときだけチャンネルで受ける」と「channel モードの保留はチャンネルの返事で再開する」に従う（MUST。チャンネルの返事を確かめられるセッションでは、チャンネルの返事を会話で受けた回答として同じく PR へのコメントを求めない）。interactive の本体では、`skills/develop/references/handover.md` の「保留で止まるときの引き継ぎ」の主への案内は、リスク許容の返事について「このセッションの会話で返すか、新しいセッションで `/develop <記録先> 許容する` と打てばよく、PR へのコメントは要らない」と書かなければならない（MUST）。本体は会話で許容の返事を受けたら、主に PR へのコメントを求めてはならず（MUST NOT）、保留の解除の G に、自分のセッション ID（`$CLAUDE_CODE_SESSION_ID`）・その発言の日時（会話ログの timestamp）・原文を渡さなければならない（MUST）。新しいセッションでの再開手順は、`/develop` の引数の残り（`許容する` など）を会話で受けた回答として扱い、その新しいセッションのセッション ID・日時・原文を同じく G に渡さなければならない（MUST）。ただし Orca 経路のエピックの子が親経由でリスク許容を受けたとき（会話に届いた入力が `主の返事（親エピック #<E> 経由）:` で始まるとき、または起動し直されたセッションの最初の指示の引数の残りのうち、起動し直しの括弧 `（エピック #<E> の子。返事を受けて起動し直し）` のうしろが `主の返事（親エピック #<E> 経由）:` で始まるとき）は、自分のセッション ID・日時・原文を渡さず、要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」の手順（`owner-reply-check.sh --relayed`）で確かめてから G に渡さなければならない（MUST）。この手順は `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」の「親から届いた返事」に書き、再開手順の手順 2 より先に当てる。再開手順の本文は変えない（MUST）。記録の書式と真正性確認は pr-review-gate の手順 5 が正本で、develop の手順書（SKILL.md と `references/epic-child-stop.md`）には書式を再掲しない（MUST NOT）。（起動し直しで届いた親経由の許容の Scenario は、要件「親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る」の「起動し直しの指示に付いて届いた親経由の許容を確かめる」が正本）

この要件の入力は、主が保留の許容を返す場所（このセッションの会話・新しいセッションの `/develop` の引数・Orca 経路のエピックの子に親経由で届く返事・channel のチャンネル）である。拾いたい誤りは、会話で受けた許容に PR へのコメントを求めること、親経由の返事を確かめずに自分の発言として G に渡すことである。次は通してよく、この要件では止めない: チャンネルの返事を確かめられないセッションで PR へのコメントを案内すること。許容の受け方の揺れが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

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

### Requirement: wait のテストはポーリングごとの stderr の空化を固定する
`plugins/dev-workflow/tests/epic-dispatch.bats` の「`gh` の stderr はエラー行の直前に出る」テストは、`error` で終わったときに本体の stderr に出るのが最後（3 回目）のポーリングの `gh` の stderr だけであることを確かめなければならない（MUST）。`gh` のスタブは失敗のたびに `gh: mock failure for issue <N> (poll <回数>)` を stderr に出すので、stderr に `(poll 3)` が含まれることと、`mock failure` を含む行がちょうど 1 行であることを確かめる（MUST）。

#### Scenario: 3 回目のポーリングの stderr だけが出る
- **WHEN** `gh` が常に失敗するスタブ環境で `epic-dispatch.sh wait --interval 0 --timeout 60 11` を実行する
- **THEN** stderr は `(poll 3)` を含み、`mock failure` を含む行はちょうど 1 行である

#### Scenario: 空にする処理を消すとテストが落ちる
- **WHEN** `epic-dispatch.sh` の `wait` から、ポーリングごとに stderr の置き場を空にする処理を消して同じテストを実行する
- **THEN** `mock failure` を含む行が 3 行になり、テストは失敗する

### Requirement: develop のループの終わりは片付けを聞かず、ワークスペースに印を付ける
develop の SKILL.md は「ループの終わり」の節を持ち、次を規定しなければならない（MUST）。

- 本体は、完了報告でも途中でも、worktree の片付けを提案も質問もしてはならない（MUST NOT）。片付けは、Orca 経路のエピックの子なら親セッションが行い、それ以外はオーナーが別のセッションで `/wt-clean` を使う
- 記録先が issue で PR がマージ済みのとき、本体はそのループの最後のツール呼び出しとして `scripts/epic-dispatch.sh mark <done|waiting> <記録先の issue 番号>` を 1 回呼ぶ（MUST）。オーナーに頼むことが残っていなければ `done`、完了報告にマージ後の依頼（動作確認など）を書いたなら `waiting` とし、オーナーが済んだと返事をしたら `done` で呼び直す（MUST）
- PR を伴わない記録先 issue（調査だけの issue など、受け入れ条件がリポジトリの変更を求めないもの）で受け入れ条件を満たしたら、本体は結果を記録先にコメントし、`gh issue close <N> --reason completed` で閉じる（MUST）。閉じる操作を主に渡してはならない（MUST NOT）。受け入れ条件が推奨を出すことなら、推奨を出した時点で満たしたと数え、主が推奨を採るかを閉じる条件にしてはならない（MUST NOT）。閉じたあとは、PR がマージ済みのときと同じく最後のツール呼び出しで `scripts/epic-dispatch.sh mark <done|waiting> <記録先の issue 番号>` を呼ぶ（MUST）
- PR がマージされていないとき（保留・マージ待ち・unmanned）と、記録先が Draft PR のときは呼ばない（MUST NOT。PR を伴わない記録先 issue を閉じたときを除く）
- 出力が `marked` / `skipped` なら何もせず、`failed` なら完了報告に 1 行書く。どの出力でも止まらない（SHALL）
- 印を最後に置く理由（印が付くと親セッションがそのワークスペースの端末を閉じること）を書く（SHALL）

この規定は SKILL.md に置き、`launch --note` で子に渡す指示に頼ってはならない（MUST NOT。起動し直したセッションにも効かせるため）。

#### Scenario: SKILL.md にループの終わりの節がある
- **WHEN** SKILL.md の「ループの終わり」の節を読む
- **THEN** worktree の片付けを提案も質問もしないこと、片付けは親セッションか別セッションの `/wt-clean` が担うこと、記録先が issue で PR がマージ済みのときに最後のツール呼び出しとして `epic-dispatch.sh mark` を呼ぶこと、`done` と `waiting` の使い分け、オーナーの返事のあとに `done` で呼び直すこと、マージされていないときと記録先が Draft PR のときは呼ばないことが書かれている

#### Scenario: 片付けの記述を grep で確かめられる
- **WHEN** `grep -rn "worktree" plugins/dev-workflow/skills/develop/SKILL.md` を実行する
- **THEN** 「worktree の片付けを提案も質問もしない」に当たる行が出る

#### Scenario: PR を伴わない調査の issue は本体が閉じる
- **WHEN** 調査だけの記録先 issue で、受け入れ条件（測った結果と推奨のコメント）を満たした
- **THEN** 本体は結果を記録先にコメントし、`gh issue close <N> --reason completed` で閉じてから `epic-dispatch.sh mark` を呼び、主に閉じる操作も推奨の採否も渡さない

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

### Requirement: Codex がオフのとき自動選択は Claude だけの構成を返し、明示指定は拒否する
`plugins/dev-workflow/scripts/codex-develop.py` は、レジストリの `codex.enabled` が `false`（`usage-account-registry` capability の要件「Codex を codex.enabled でオフにできる」）のとき、次のとおり動かなければならない（SHALL）。

自動選択（profile も旧形式も無指定）は、Codex の週次の余裕の値にかかわらず、構成 `claude-default`・reason `codex-off` を返す。Codex の使用量を取得せず（app-server の起動もキャッシュの更新もしない）、selection evidence の `codex` ブロックは `account`・`margin`・`fetched_at` を `null`、`enabled` を `false` とする。Claude の余裕の評価と、`claude` ブロックの形は変えない。`select_configuration` は、`codex_enabled` を引数に取り（既定は真）、偽なら余裕の値にかかわらず `('claude-default', 'codex-off')` を返す。

明示指定は、オフのとき黙って Claude に差し替えてはならない（MUST NOT）。旧形式（`--account` / `--model`）と、いずれかの role の executor が `codex` の profile（`--profile`）は、依頼ファイルを作らず、`status: blocked` と exit 2 で拒否する。エラー文にはオフであること、戻し方（`codex.enabled` を `true` にするか `codex` のキーを消すこと）、読んだ登録簿のパスを入れる。この拒否は、アカウント対応表の検査（`account is not registered` など）より先に行う。executor が `codex` の role を 1 つも持たない profile は拒否しない。

`codex.enabled` の読み方（入力の出どころ、オフになる条件が `false` との一致 1 つであること、書き損じを防ぎ切ることを完了条件にしないこと）は `usage-account-registry` の要件「Codex を codex.enabled でオフにできる」の守備範囲に従い、ここで独自の検査を足さない（SHALL）。

`codex.enabled` が無い、または `false` 以外のとき、選ばれる構成・reason・selection evidence・依頼ファイルは変更前と同一でなければならない（SHALL）。

#### Scenario: オフなら Codex の余裕が大きくても Claude だけを選ぶ
- **WHEN** `codex.enabled` が `false` で、Codex の週次の余裕が Claude より大きい（両方 0 以上）状態で自動選択する
- **THEN** 構成は `claude-default`、reason は `codex-off` で、`codex.enabled` は `false`。Codex の使用量の取得は呼ばれない

#### Scenario: オフで Claude にも余裕が無いとき
- **WHEN** `codex.enabled` が `false` で、Claude の余裕が負（または欠測）の状態で自動選択する
- **THEN** 構成は `claude-default`、reason は `codex-off`（`no-provider-has-headroom` ではない）

#### Scenario: オフで Codex の profile を明示すると拒否する
- **WHEN** `codex.enabled` が `false` で、`--profile codex-standard` を指定して `request` を実行する
- **THEN** exit 2 で終わり、`status` は `blocked`、エラー文にオフであることが出る。依頼ファイルは作られない

#### Scenario: オフで旧形式を明示しても拒否する
- **WHEN** `codex.enabled` が `false` で、`--account NAME --model MODEL` を指定して `request` を実行する
- **THEN** exit 2 で終わり、エラー文にオフであることが出る

#### Scenario: オフの拒否は対応表の検査より先
- **WHEN** `codex.enabled` が `false` で、`--account-home` を渡さずに `--profile codex-standard` を指定する
- **THEN** エラー文は `account is not registered` ではなくオフであることを示す

#### Scenario: 設定が無い環境では変わらない
- **WHEN** `codex` を書いていないレジストリ、レジストリ無し、`codex.enabled` が `true` のレジストリのそれぞれで、同じ使用量の入力で自動選択する
- **THEN** 3 つとも、選ばれる構成・reason・selection evidence が同一で、`codex` ブロックに `enabled` のキーは無い

### Requirement: 本体は主の側にしか無い情報が要るときだけ主に聞く

`skills/develop/SKILL.md` は節「主に聞かずに決めること」を 1 か所持ち、本体・W・G が主に聞くのは、主の側にしか無い情報（好み・事業判断・許容度）、主の手でしかできない操作（MFA・OAuth・ログインなど）、規則が主の承認を求める操作（`rules/destructive-git-guard.md` の一覧・マージ・聖域）のどれかが要るときだけであると書かなければならない（MUST）。節は次の 4 つの型の決め方を持たなければならない（MUST）。

- **自分側の誤りの後始末**: 本体・W・G・レビュアーが記録先の範囲の外に誤って入れた変更（実ホームの設定ファイルへの書き足しなど）は、控え・git の履歴・自分のツール呼び出しの記録のどれかと今の状態を比べて、差分が自分側の入れた分だけで戻し先が一意に決まるなら、主に聞かずに戻す（MUST）。戻す前に今の状態の控えを取り（MUST）、戻したあと記録先に何を・どこから戻したか・控えの場所を事後報告する（MUST）。差分が自分側の分だけと確かめられないときは主に聞く（MUST）。git の破壊的操作（`rules/destructive-git-guard.md` の一覧）はこの型に入らず、従来どおり事前承認とする（MUST）。聖域（CLAUDE.md・hooks・権限設定）への変更を戻す操作も、差分が一意でもこの型に入らず、従来どおり無条件で人間承認とする（MUST）。`rules/destructive-git-guard.md` は変えない（MUST NOT）
- **範囲外の問題の起票**: 本体が作業中に見つけた記録先の範囲外の問題（レビュー指摘ではないもの。G の振り分けを経た指摘は G の振り分けのまま扱う）は、本体が次の手順で行き先（捨てる・既存 issue に参考として入れる・新しい issue）を決め、起票したら URL を事後報告する（MUST）。`skills/pr-review-gate/stages/triage.md` は PR 番号・PR コメント・G の手順 3 を前提にしているので丸ごとは当てず、段 B・段 D・段 E の問い（エピックの子の記録先なら段 C の問いも）と段 B の表だけを借りる（MUST）。
  - 候補探し: 段 B を通った問題が 1 件以上あれば、問題がファイルを指すなら `plugins/dev-workflow/scripts/review-issue-candidates.sh --repo $R --exclude <記録先の番号> [--epic <エピック番号>] <パス>...` を、ファイルを指さないなら `gh issue list --repo $R --state open --search "<問題を表す語>"` を、それぞれ 1 回だけ走らせる（MUST）。記録先の番号は記録先の issue、記録先が Draft PR ならその PR の番号とする。終了コードが 0 でないときの扱いは `triage.md` の候補探しの段落に従う（MUST）。再試行後の終了コードは記録先の `範囲外の問題の振り分け` コメントに書き、既存 issue への相乗りをせずに段 E へ進む（MUST）
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

#### Scenario: ファイルを指さない範囲外の問題の候補探し
- **WHEN** 本体が見つけた範囲外の問題がリハーサルで詰まった操作で、特定のファイルを指さない
- **THEN** 本体は `review-issue-candidates.sh` を使わず、`gh issue list --state open --search` を 1 回走らせて候補を探す

#### Scenario: 範囲外の問題の条件が決められない
- **WHEN** 本体が見つけた範囲外の問題の条件がいつ成り立つかを、記録先・エピックの本文・受け入れ条件・コード・`## 条件の答え` から決められない
- **THEN** 本体は起票してよいかではなく条件についての問いを主に聞き、`範囲外の問題の振り分け` のコメントにその問題を `条件の確認待ち` として残し、`needs-approval` を付けずに作業を続け、答えを `## 条件の答え` に 1 行で足して段 B から当て直す

#### Scenario: エピックの注意書きが段 C より優先される
- **WHEN** エピックの子の記録先に、親から「新しい問題は新しい子 issue として切る」の注意書きがあり、範囲外の問題が同じエピックの既存の子 issue と同じ場所を指す
- **THEN** 本体は既存の子 issue の受け入れ条件に足さず、エピックに新しい子 issue を作る

### Requirement: epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す
`plugins/dev-workflow/scripts/epic-dispatch.sh` の `mark` は、種別 `done`・`waiting` に加えて `stopped` と `resumed` を受け付けなければならない（MUST）。`wait` はフラグ `--watch-stopped`（値なし）を受け付けなければならない（MUST）。どちらも LLM を呼んではならない（MUST NOT）。この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」のうち、次の 4 点に優先する。`mark` の種別を `done|waiting` とする規定と、それ以外の種別を引数の誤りとする規定／`wait` が `--watch-done` が 1 つも無いときは `orca` を呼ばないとする規定（`--watch-done` も `--watch-stopped` も無いときに読み替える）／`wait` が `closed` と `done` を 1 行か 2 行で出す規定（`stopped` を加えて 1〜3 行）／一覧の取得の失敗だけを「失敗したポーリング」に数える規定（止まった印の書き換えの失敗を加える）。

止まった印は Orca のワークツリーのコメント欄（`orca worktree set --comment`、`orca worktree list --json` の `comment`）に置き、ボードの列（`workspaceStatus`）には触れてはならない（MUST NOT。`mark waiting` の `in-review` と取り違えないため）。コメント欄の値は次の 3 つに固定し、完全一致で比べる（MUST）: `epic-stopped`（止まった。親はまだ受けていない）／`epic-stopped-seen`（親の `wait` が一度受けた）／`epic-resumed`（返事を受けて動いている）。

**`mark stopped <issue>`** は、今のワークスペースの linkedIssue が `<issue>` のときだけ、`orca worktree set --worktree current --comment epic-stopped` を 1 回呼ぶ（MUST）。exit 0 なら `marked <issue> stopped`、非 0 なら `failed <issue>`（exit 1）を出す。`orca` が無い・Orca 管理外・linkedIssue が違うときの出力と、`EPIC_DISPATCH_PARENT_EPIC` を見ないことは、`done` / `waiting` と同じとする（MUST）。

**`mark resumed <issue>`** は、linkedIssue が `<issue>` で、今のワークスペースの `comment` が `epic-stopped` か `epic-stopped-seen` のときだけ、`orca worktree set --worktree current --comment epic-resumed` を 1 回呼び、`marked <issue> resumed`（失敗なら `failed <issue>`、exit 1）を出す（MUST）。`comment` がそれ以外のときは `orca worktree set` を呼ばず、stdout に `skipped <issue> not-stopped` を出して exit 0 で終わる（MUST）。

**`wait --watch-stopped`** は次のとおり動かなければならない（MUST）。

- `--watch-stopped` は位置引数の子を対象にする。位置引数の子が 0 件なら、`--watch-done` があってもなくても `--watch-stopped` は何も見ない。`--watch-done` も位置引数の子も無ければ、`--watch-stopped` があっても stderr に使い方を出して exit 1 で終わる
- ポーリングを始める前の `orca worktree current --json` による `repoId` の取得と、取れないときの終わり方（stdout に何も出さず exit 1）は `--watch-done` と同じとする
- ポーリングごとの `orca worktree list --json` は、`--watch-done` と `--watch-stopped` の両方があっても 1 回だけ呼ぶ。ポーリング 1 回あたりの `gh` の呼び出しは位置引数の子の数と同じのままとする
- 位置引数の子 `<N>` のうち、そのポーリングで閉じていなかった子について、一覧に `repoId` が同じ・`linkedIssue` が `<N>`・`isArchived` が true でない・`comment` が `epic-stopped` のワークツリーがあれば、その全部に `orca worktree set --worktree path:<そのパス> --comment epic-stopped-seen` を呼ぶ。全部が exit 0 ならその子を「止まった子」とする。1 つでも非 0 ならその子を止まった子にせず、そのポーリングを「失敗したポーリング」に数える。`orca` 自身の出力は stderr に流す
- 閉じた子・印が付いた子・止まった子が 1 件以上あれば、`closed <N>...`・`done <N>...`・`stopped <N>...` を、該当するものだけこの順で 1 行ずつ出して exit 0 で終わる
- `comment` が `epic-stopped-seen`・`epic-resumed`・それ以外の値のワークツリーは止まった子に数えない
- `--watch-stopped` が無ければ、コメント欄を見てはならず、`orca worktree set` を呼んではならない（MUST NOT）

この要件の守備範囲で入力として扱うのは、`orca worktree current --json` と `orca worktree list --json` が返す Orca のメタデータ（`repoId`・`linkedIssue`・`isArchived`・`comment`・`path`）、`orca worktree set` の終了コード、`gh` が返す子 issue の state、`mark` と `wait` の引数である。拾いたい誤りは、止まった子を親が受けずに待ち続けること、一度受けた止まりで親の `wait` が起き続けること、再開して再び止まった子を取りこぼすこと、完了の印（ボードの列 `completed` / `in-review`）と止まった印を取り違えること、別の repo や archive されたワークツリーの印を数えること、受けた印に書き換えられていない止まりを報告することの 6 つである。次は通ってよく、この要件では止めない: 主がコメント欄に書いたメモ（`epic-stopped` の 3 つの値以外は無視するだけで、`mark stopped` が上書きする）／一覧を読んでから受けた印に書き換えるまでの間に子が `mark resumed` を呼び、再開した子の `stopped` を親が受けること（間はミリ秒単位で、親は記録を読んで報告するだけ）／子が `mark resumed` を付け忘れ、`epic-stopped-seen` が残ったまま動いていること（次の `mark stopped` で上書きされる）／同じ linkedIssue のワークツリーが 2 つ以上あること（全部を書き換える）。Orca がコメント欄を別の値に書き換えるなど、ここに挙げていない入力の組み合わせを見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。この要件は要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の `reap` の守備範囲に頼らない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`sleep` を PATH 上のスタブにして、下の Scenario を確かめなければならない（MUST）。

#### Scenario: 自分の issue のワークスペースに止まった印を付ける
- **WHEN** linkedIssue が 460 のワークスペースで `epic-dispatch.sh mark stopped 460` を実行する
- **THEN** `orca worktree set --worktree current --comment epic-stopped` が 1 回呼ばれ、`--workspace-status` を含む呼び出しは無く、stdout は `marked 460 stopped`、exit 0 である

#### Scenario: 別の issue のワークスペースには止まった印を付けない
- **WHEN** linkedIssue が 461 のワークスペースで `epic-dispatch.sh mark stopped 460` を実行する
- **THEN** `orca worktree set` は呼ばれず、stdout は `skipped 460 not-linked`、exit 0 である

#### Scenario: 止まった印があるときだけ再開の印に書き換える
- **WHEN** `comment` が `epic-stopped`、`epic-stopped-seen`、`メモ` のワークスペースで、それぞれ `epic-dispatch.sh mark resumed 460` を実行する
- **THEN** 前の 2 つでは `orca worktree set --worktree current --comment epic-resumed` が 1 回呼ばれて stdout は `marked 460 resumed`、`メモ` では `orca worktree set` が呼ばれず stdout は `skipped 460 not-stopped` で、どれも exit 0 である

#### Scenario: 止まった印を付けられなければ failed
- **WHEN** `orca worktree set` が非 0 で終わる環境で `epic-dispatch.sh mark stopped 460` を実行する
- **THEN** stdout は `failed 460`、exit 1 である

#### Scenario: 止まった子を受けた印に書き換えて stopped で終わる
- **WHEN** 子 11 が open のまま、一覧で 11 の `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** `orca worktree set --worktree path:<11 のパス> --comment epic-stopped-seen` が 1 回呼ばれ、stdout は `stopped 11`、exit 0 である

#### Scenario: 受けた印と再開の印では起きない
- **WHEN** 一覧で 11 の `comment` が `epic-stopped-seen`、12 の `comment` が `epic-resumed` で、どちらも open の環境で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-stopped 11 12` を実行する
- **THEN** `orca worktree set` は呼ばれず、stdout は `timeout 11 12`、exit 2 である

#### Scenario: 閉じた子・印が付いた子・止まった子は 3 行で出す
- **WHEN** 子 12 が closed、`--watch-done` の子 11 が `completed`、子 13 が open で `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11 --watch-stopped 12 13` を実行する
- **THEN** stdout は `closed 12`・`done 11`・`stopped 13` の 3 行がこの順で、exit 0、`orca worktree list --json` の呼び出しは 1 回である

#### Scenario: 閉じた子は止まった子に数えない
- **WHEN** 子 11 が closed で、一覧の 11 の `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** stdout は `closed 11` の 1 行だけで、`orca worktree set` は呼ばれない

#### Scenario: 別の repo や archive されたワークツリーの止まった印は数えない
- **WHEN** 一覧で 11 の `comment` が `epic-stopped` のワークツリーが、`repoId` の違うものと `isArchived` が true のものだけの環境で `--watch-stopped 11` の `wait` を `--timeout 0` で実行する
- **THEN** `orca worktree set` は呼ばれず、stdout は `timeout 11`、exit 2 である

#### Scenario: 受けた印に書き換えられないポーリングが 3 回続いたら error で終わる
- **WHEN** 一覧で 11 の `comment` が `epic-stopped` のまま、`orca worktree set` が常に非 0 で終わる環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** stdout は `error workspaces` の 1 行、exit 1 で、`stopped` の行は出ない

#### Scenario: --watch-stopped が無ければコメント欄を見ない
- **WHEN** 一覧で 11 の `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 0 11` を実行する
- **THEN** `orca` は呼ばれず、stdout は `timeout 11`、exit 2 である

#### Scenario: 受けた止まりでは起き直さず、付け直した止まりではまた起きる
- **WHEN** 子 11 が open のまま、一覧で 11 の `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行し、続けて同じスタブの状態（コメント欄はスタブの `orca worktree set` が書き換えた値を一覧に返す）で `--timeout 0` の `wait` を実行し、さらに linkedIssue が 11 のワークスペースとして `epic-dispatch.sh mark stopped 11` を実行してから 3 回目の `--timeout 60` の `wait` を実行する
- **THEN** 1 回目は stdout `stopped 11`・exit 0、2 回目は stdout `timeout 11`・exit 2 で `orca worktree set` を呼ばず、3 回目は stdout `stopped 11`・exit 0 である

#### Scenario: --watch-stopped だけで子が無ければ使い方を出す
- **WHEN** `epic-dispatch.sh wait --watch-stopped` を子なしで実行する
- **THEN** stderr に使い方が出て exit 1 で、`orca` も `gh` も呼ばれない

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

### Requirement: epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける
`plugins/dev-workflow/scripts/epic-dispatch.sh wait` は `--resolve <epic>` を受け付けなければならない（MUST）。`<epic>` が数字でなければ使い方を出して exit 1 で終わる（MUST）。`--resolve` は `--watch-stopped` と位置引数の子が 1 件以上あるときだけ働き（SHALL）、それ以外では何もしない。`--resolve` が無い `wait` の振る舞いは変えない（MUST）。

`--resolve <epic>` が働くとき、`wait` はポーリングで止まった子（既存の要件のとおり `epic-stopped-seen` に書き換えられた子）ごとに、次を行わなければならない（MUST）。

1. 判断のコマンド（環境変数 `EPIC_DISPATCH_JUDGE`。既定は `epic-dispatch.sh` と同じディレクトリの `stop-judge.sh`）を `<epic> <child>` を引数に 1 回呼ぶ
2. 判断の出力の 1 行目が `判断: 通す` で、3 行目が `返事: ` に続く空でない文なら、要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の `--as parent` と同じ処理でその文を子に送る。結果が `sent` か `relaunched` なら、エピックに `親の判断: 子 #<child> 通した — <2 行目の 理由: のうしろ> <4 行目の 記録: のうしろ>` の 1 行をコメントする。投稿できたらその子を出力に含めない。投稿に失敗したら、その子を `unrecorded` に含め、stderr に投稿し直すコマンド（`gh issue comment <epic> --body <その 1 行>`）を出す（エピックへの記録は送信のあとに投稿する。送る前に投稿すると、送れなかったときに通していない判断が残るため）
3. 判断が `判断: 主に上げる` なら、子 issue に 1 行目 `親の判断: 主に上げる`、2 行目 `停止の記録: <4 行目の 記録: のうしろ>`、3 行目以降に判断の理由を書いたコメントを投稿し、その子を `stopped` に含める
4. 判断のコマンドが非 0 で終わった・出力が 1〜4 行目の形で読めない、または判断が `判断: 通す` で送れなかった（`failed`）なら、子 issue に 1 行目 `親の判断: 判断できなかった`（送れなかったときは `親の判断: 通すが送れなかった`。判断は通すで送信だけが失敗したことを事実どおりに書く）、2 行目 `停止の記録: <URL>`（判断の出力から読めたときだけ。読めなければ `停止の記録: 不明`）、3 行目以降に何が失敗したかと（あれば）送るはずだった返事を書いたコメントを投稿し、その子を `stopped` に含める。判断の出力そのものはコメントに貼らない（MUST NOT。判断の入力には gitignore 済みの `.claude/casting/local.md` も入り、出力に引用されうるため。見たいときのために stderr にだけ出す）

`--resolve` が働く `wait` の出力は、`closed <N>...`・`done <N>...`・`stopped <N>...`・`unrecorded <N>...` を該当するものだけこの順に（1〜4 行）出して exit 0 とする（MUST）。`unrecorded` は「返事は子に届いたが、エピックへの 1 行を残せなかった」子で、親を起こして記録させるために出す。この出力の規定は、`--resolve` が働く場合に限り、既存の要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」と「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」が定める `closed`・`done`・`stopped` の 1〜3 行の規定に優先する。`--resolve` が働かない `wait` は、`unrecorded` を出さず、従来どおり 1〜3 行を出さなければならない（MUST）。ポーリングで `stopped` にも `unrecorded` にも含める子が 1 件も無く、閉じた子も完了の印の子もいなければ、`wait` は待ちを続けなければならない（MUST）。

子 issue への `親の判断:` のコメントの投稿に失敗しても、その子は `stopped` に含める（MUST）。stderr に投稿し直すコマンドを出す（SHALL）。親は子 issue の `親の判断:` のうち、2 行目の `停止の記録:` が最新の `子の停止: 主の返事待ち` のコメントの URL と一致するものだけを今回の判断として読む（要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」）ので、投稿に失敗して前回の判断が残っていても、親はそれを今回の判断と取り違えず、判断が無いものとして扱う（要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」の手順 8 で親が照らす）。

`plugins/dev-workflow/scripts/stop-judge.sh <epic> <child>` は、次の入力だけを集めてモデルを 1 回呼び、stdout に 4 行を出さなければならない（MUST）。

- 入力: エピックの本文と子 issue の本文（どちらも、その issue の投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のときだけ）、子 issue の `親エピックからの注意書き:` で始まるコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のもの、子 issue の 1 行目が `子の停止: 主の返事待ち` のコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` の最新のものの本文と URL、エピックのコメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` で `親の判断: 子 #<child> ` で始まるもの、`plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md` の本文、リポジトリの `.claude/casting/project.md`・`.claude/casting/local.md`（あるものだけ）
- 呼び方: 既定は `claude -p --model <モデル> --tools "" --no-session-persistence`。モデルは `EPIC_DISPATCH_JUDGE_MODEL`（既定 `sonnet`）、コマンド全体は `EPIC_DISPATCH_JUDGE_CMD` で変えられる。ツールを渡してはならない（MUST NOT）
- 出力: 1〜3 行目はモデルの出力の 1 行目 `判断: 通す` か `判断: 主に上げる`、2 行目 `理由: <1 行>`、3 行目 `返事: <1 行>`。4 行目は `stop-judge.sh` 自身が付ける `記録: <停止の記録のコメントの URL>`。モデルの出力が 1〜3 行目の形で読めなければ、stdout に何も出さず exit 1 で終わる（MUST）
- 停止の記録のコメントが見つからない・`gh` が失敗した・エピックか子 issue の投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のどれでもないか読めないときは、モデルを呼ばずに exit 1 で終わる（MUST）。exit 1 は `wait` の側で判断の失敗になり、子は主に上がる（issue は誰でも立てられるので、ほかの投稿者の本文で判断を誘導されないようにする）
- `orca` の語を含んではならない（MUST NOT。既存要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」）

`plugins/dev-workflow/tests/epic-dispatch.bats` と `plugins/dev-workflow/tests/stop-judge.bats` は、判断のコマンドとモデルのコマンドをスタブにして、上の振る舞い（通して送れたら出力に含めずエピックに 1 行残すこと、送れたがエピックへの投稿に失敗すると `unrecorded` を出すこと、主に上げると `stopped` を出し子 issue のコメントに `停止の記録:` の行があること、子 issue への投稿に失敗しても `stopped` を出すこと、判断の失敗・形の崩れ・送信の失敗で `stopped` を出すこと、`--resolve` なしでは判断を呼ばないこと、入力の集め方と出力の形の検査）を確かめなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、`wait` では判断のコマンドの終了コードと stdout、`reply` と同じ処理の結果で、`stop-judge.sh` では `gh` の出力（エピック・子 issue・コメント）と、モデルのコマンドの stdout である。拾いたい誤りは、判断に失敗した止まりや主に上げる止まりを親に知らせずに待ち続けること、判断の結果を読み違えて通さない件を子に送ること、通した件がエピックに残らないまま親が起こされないこと、親が前回の止まりへの判断を今回の判断と取り違えること、判断の入力に親の会話が混ざって費用が増えることの 5 つである。次は通ってよく、この要件では止めない: モデルの理由や返事の文の中身の良し悪し（基準の当てはめの正しさはこの要件の完了条件にしない）／判断のあとに子が自分で再開していて、返事が既に進んでいる子に届くこと（子は受け取って続ける）／1 回のポーリングで複数の子が止まり、判断を子の数だけ順に呼ぶこと／エピックへの投稿が一時的に失敗し、親が `unrecorded` で起こされて投稿し直すこと。モデルが基準を当てはめ損ねる入力や、投稿の失敗の組み合わせが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 通すと判断した子には返事を送り、親を起こさない
- **WHEN** `--watch-stopped --resolve 400 11` の `wait` で、子 11 のワークスペースが `epic-stopped` になり、判断のスタブが `判断: 通す`・`理由: 範囲の内側`・`返事: 推奨どおり進めてよい`・`記録: <URL>` を出し、送信が成功する
- **THEN** 子 11 の端末に `親エピック #400 の判断（主の承認ではない）: 推奨どおり進めてよい` が送られ、エピック 400 に `親の判断: 子 #11 通した — 範囲の内側` で始まるコメントが投稿され、`wait` は `stopped 11` を出さずに待ちを続ける

#### Scenario: 送れたがエピックに残せなければ unrecorded で親を起こす
- **WHEN** 判断のスタブが `判断: 通す` を出し、送信は成功し、エピック 400 へのコメントの投稿が失敗する
- **THEN** `wait` は `unrecorded 11` を出して exit 0 で終わり、stderr に `gh issue comment 400` で始まり `親の判断: 子 #11 通した` を含む投稿し直しのコマンドが出る

#### Scenario: 子 issue への判断の投稿に失敗しても stopped で返す
- **WHEN** 判断のスタブが `判断: 主に上げる` を出し、子 issue へのコメントの投稿が失敗する
- **THEN** `wait` は `stopped 11` を出して exit 0 で終わる

#### Scenario: 主に上げると判断した子は stopped で返す
- **WHEN** 判断のスタブが `判断: 主に上げる` を出す
- **THEN** 子 issue に 1 行目 `親の判断: 主に上げる`、2 行目 `停止の記録: <URL>` のコメントが投稿され、`wait` は `stopped 11` を出して exit 0 で終わり、子の端末には何も送られない

#### Scenario: 判断に失敗した子は stopped で返す
- **WHEN** 判断のスタブが exit 1 で終わる、または 1 行目が `判断: たぶん通す` である
- **THEN** 子 issue に 1 行目 `親の判断: 判断できなかった` のコメントが投稿され、`wait` は `stopped 11` を出して exit 0 で終わる

#### Scenario: 通すと判断したが送れなかった子は、通すが送れなかったと残して stopped で返す
- **WHEN** 判断のスタブが `判断: 通す`・`返事: 推奨どおり進めてよい` を出し、子の端末への送信が失敗する
- **THEN** 子 issue に 1 行目 `親の判断: 通すが送れなかった`、2 行目 `停止の記録: <URL>` で、送るはずだった返事を含むコメントが投稿され、エピックには何も投稿されず、`wait` は `stopped 11` を出して exit 0 で終わる

#### Scenario: resolve が無ければ判断を呼ばない
- **WHEN** `--resolve` を付けずに `--watch-stopped 11` の `wait` で子 11 が止まる
- **THEN** 判断のスタブは呼ばれず、`wait` は `stopped 11` を出し、出力に `unrecorded` の行は無い

#### Scenario: stop-judge.sh は形の崩れた出力を通さない
- **WHEN** モデルのスタブが `判断: 通す` の 1 行だけを出す
- **THEN** `stop-judge.sh` は stdout に何も出さず exit 1 で終わる

#### Scenario: stop-judge.sh は信頼できない投稿者の issue の本文を判断に渡さない
- **WHEN** 子 11 の issue の投稿者の `author_association` が `NONE` で、`stop-judge.sh 400 11` をモデルのスタブで実行する
- **THEN** `stop-judge.sh` はモデルのスタブを呼ばず、stdout に何も出さず exit 1 で終わる

#### Scenario: stop-judge.sh は親の会話を渡さず、基準と記録を渡す
- **WHEN** `stop-judge.sh 400 11` をモデルのスタブで実行する
- **THEN** スタブが受け取った入力に、エピック 400 の本文、子 11 の本文、最新の `子の停止: 主の返事待ち` の本文と URL、`parent-pass-criteria.md` の本文が含まれ、スタブの引数に `--tools` と空の値、`--model sonnet` が含まれる

### Requirement: epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける
`plugins/dev-workflow/scripts/epic-dispatch.sh` は `reply [--relaunch] --as <parent|owner> <epic> <child> <text>` を受け付けなければならない（MUST）。`--as` が無い・値が `parent` / `owner` 以外・`<epic>` か `<child>` が数字でない・`<text>` が空なら、使い方を出して exit 1 で終わり、`orca` を呼んではならない（MUST）。

送る文の頭には、`--as parent` なら `親エピック #<epic> の判断（主の承認ではない）: `、`--as owner` なら `主の返事（親エピック #<epic> 経由）: ` を付けなければならない（MUST）。

`reply` は今の Orca の一覧から、今のワークツリーと同じ repoId・linkedIssue が `<child>`・archive されていない子のワークツリーを探し、次のとおりに動かなければならない（MUST）。stdout は 1 行。

| 状態 | 動き | stdout | exit |
|---|---|---|---|
| ワークツリーがちょうど 1 件、端末が 1 つ以上、`--relaunch` なし、子のセッションの端末が決まる | 子のセッションの端末（下記）に送り、ターンの開始まで確かめる（`launch` と同じ確かめ方） | `sent <child>` | 0 |
| ワークツリーがちょうど 1 件、端末が 0 か `--relaunch` | `--relaunch` なら先にそのワークツリーの端末を全部閉じる。`launch` と同じ起動コマンド（`EPIC_DISPATCH_PARENT_EPIC=<epic>` と待っている間の自動コンパクトの閾値を前置きしたもの）で端末を作り、`/develop #<child> （エピック #<epic> の子。返事を受けて起動し直し）` のうしろに頭を付けた文を続けて送る | `relaunched <child>` | 0 |
| 端末が 1 つ以上で子のセッションの端末が決まらない（`--relaunch` なし。シェルの端末だけのときを含む） | 送らず、作らず、閉じない（シェルの端末が子のセッションでないと一覧から言い切れず、起動し直すと二重に動きうるため。stderr に `--relaunch` で起動し直せることを出す） | `failed <child> ambiguous-terminal` | 1 |
| ワークツリーが 0 件か 2 件以上 | 送らない | `failed <child> no-worktree` / `failed <child> ambiguous-worktree` | 1 |
| 端末の一覧が読めない（`orca` が失敗した、または `result.terminals` が欠落・`null`・配列以外） | 端末を 0 と数えず、送らず、作らず、閉じない（0 と数えて作り直すと、動いている子が二重に起動するため） | `failed <child> terminal-list` | 1 |
| 送信・作成・閉じるのどれかが失敗、またはターンの開始を確かめられない | 送り直しか作り直しのコマンドを stderr に出す（`launch` の案内と同じ形） | `failed <child> <段>` | 1 |

子のセッションの端末は、端末の一覧（`result.terminals`）のうち `agentIdentity` が `claude` の端末、それが 1 つも無ければ `title` に `Claude Code` を含む端末（Claude Code はタイトルを書き換えるので `agentIdentity` を先に見る）が、ちょうど 1 つのときのその端末としなければならない（MUST）。今の Orca では `launch` の `orca worktree create` が空のシェルの端末（タイトル `Terminal 1`）を作り、そのあと Claude Code の端末を足すので、端末の数では決めない。`launch` を直して端末を 1 つにする件（#1055）のあとの、Claude Code の端末だけがある形でも同じ決め方で送る。

develop の手順書には `orca` のコマンドを書かず、端末の有無の確かめ方は `reply` が持つ（MUST。既存要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca` のスタブで上の表の各行と、頭の付け方、引数の誤りで `orca` を呼ばないことを確かめなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、引数と、`orca` の一覧・端末の一覧・送信の出力である。拾いたい誤りは、親の判断を主の返事として届けること（頭の取り違え）、どの端末が子のセッションか分からないまま送ること、端末が無い子に送ったつもりで何も届かないこと、`--relaunch` で古いセッションを残したまま新しいセッションを起動して同じ子が二重に動くことの 4 つである。次は通ってよく、この要件では止めない: 返事の文の中身（親が主の答えを書き換えることは手順で防ぎ、この要件では見ない）／送った端末で子のセッションがちょうど終わっていて、シェルに文字が打ち込まれること（端末の一覧から区別できない。子が閉じた件は `wait` の `closed` で分かる）。端末やワークツリーの取り違えをすり抜ける形が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 端末が 1 つなら送り手を付けて送る
- **WHEN** 子 11 のワークツリーに Claude Code の端末が 1 つある状態で `reply --as owner 400 11 'A で進めて'` を実行する
- **THEN** その端末に `主の返事（親エピック #400 経由）: A で進めて` が送られ、stdout は `sent 11` で exit 0

#### Scenario: 端末が無ければ起動し直して返事を付ける
- **WHEN** 子 11 のワークツリーに端末が無い状態で `reply --as parent 400 11 '推奨どおり'` を実行する
- **THEN** `EPIC_DISPATCH_PARENT_EPIC=400` と閾値を前置きした起動コマンドで端末が作られ、`/develop #11` で始まり `親エピック #400 の判断（主の承認ではない）: 推奨どおり` を含む文が送られ、stdout は `relaunched 11`

#### Scenario: relaunch は先に端末を閉じる
- **WHEN** 子 11 のワークツリーに端末が 1 つある状態で `reply --relaunch --as owner 400 11 'B で'` を実行する
- **THEN** 端末を閉じる呼び出しが端末を作る呼び出しより先にあり、stdout は `relaunched 11`

#### Scenario: Orca のシェルの端末と Claude Code の端末があれば Claude Code の端末に送る
- **WHEN** 子 11 のワークツリーに、タイトル `Terminal 1` のシェルの端末と `agentIdentity` が `claude` の端末がある状態で `reply --as parent 400 11 '推奨どおり'` を実行する
- **THEN** `agentIdentity` が `claude` の端末にだけ送られ、stdout は `sent 11` で exit 0

#### Scenario: 子のセッションの端末が決まらなければ送らない
- **WHEN** 子 11 のワークツリーに Claude Code の端末が 2 つある、またはシェルの端末だけがある状態で `reply --as owner 400 11 'A'` を実行する
- **THEN** 送信・作成・閉じるの呼び出しは無く、stdout は `failed 11 ambiguous-terminal` で exit 1

#### Scenario: as が無ければ orca を呼ばない
- **WHEN** `reply 400 11 'A'` を実行する
- **THEN** stderr に使い方が出て exit 1、`orca` は呼ばれない

### Requirement: 親が通してよい範囲の基準を 1 つのファイルに置く
`plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md` は、止まった子を親の側で通してよい範囲の基準と、判断の出力の形を書かなければならない（MUST）。判断（`stop-judge.sh` が呼ぶモデル）と、Orca 経路の手順 8 で主に上げる前の親のセッションは、このファイルを読んで決める。

- **原則**: 主に聞く理由の 3 つ（主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作。正本は `~/.claude/output-styles/readable.md` の節 3）のどれにも当たらない止まりは、親が通す（MUST）。下の通す条件は、その止まりが 3 つのどれにも当たらないことを確かめる手順として書き、条件ごとにどの理由に当たらないことを確かめるものかを示す（MUST。「繰り返していない」は理由ではなく、親の判断が同じ止まりを回し続けないための歯止めと書く）
- **通す条件**: 次をすべて満たすときだけ通す。既存の規則が主に聞くと定めている止まり（PR トークン上限の計測が exit 2 のときの続けるか止めるか、レビューの周の終わりの直し方の判定が「選び直しが要る」とき、PR のマージ）でない（PR トークン上限の止まりは判断のモデルでは通さず、起こされた親が `epic.md` 手順 8 で親の権限に照らすと添える）／推奨がある／推奨がエピックの目的と子 issue の受け入れ条件の範囲を広げず逆向きにしない／聖域（`CLAUDE.md`・hooks・権限設定・`rules/`・常時注入の予算ファイル、`rules/destructive-git-guard.md` の破壊的な git 操作、秘密情報の値、外部への公開・送信・課金、PR のマージ）に触れない／そのブランチの中の取り消しや設定の戻しで戻せる（同じ操作をやり直しても何も残らない操作、CI の再実行・ジョブの打ち直しも戻せるに含める）／主の側の情報（好み・事業判断・主しか知らない事実・リスクの許容）が要らない／実機操作（MFA・OAuth・ログイン・ダッシュボードの操作）でない／配役表が渡されたとき、要る観点の担い手が主でない／同じ子の同じ件を既に一度通していない。作業中のリポジトリの中に試しの issue を作って閉じることは「外部への公開・送信」に当たらないと添える（MUST）
- **子の `主に聞く理由:` の読み方**: 子の停止の記録の `主に聞く理由:` は、書かれた理由が 3 つのどれかに当たるかを確かめて読み、書かれたことをそのまま通さない理由・主に上げる理由にしない（MUST）。`主に聞く理由: なし（…）` や、3 つのどれにも当たらない理由は、通す側で読む。項目の無い記録（以前の形）は、ほかの項目から判断する
- **迷ったとき**: 1 つでも満たすか判断できなければ主に上げる。主に聞く理由が成り立つか迷うときは、成り立つ側に倒す
- **例**: 通る例（リポジトリの中のソースでファイル名が理由で hook が止めたファイルの読み取り、手順外の判断を推奨どおり受け入れること、自分の実行の配下で暴走したプロセスの停止、実機テストのための試しの issue 作成、止まった子の起動し直し、CI の再実行（無関係なテストの時間切れ・ランナーの混雑・待って打ち直すだけで済むもの。失敗が PR と無関係と言い切れなくても、原因の切り分けを通す条件にしない）、CI の見張りのやり直しの上限で止まった子への追加のやり直し 1 回）と、通らない例（PR トークン上限の引き上げ、レビューの周の終わりで選び直しが要るときの続行、マージの承認、聖域のファイルの変更、実機操作、主しか知らない設計意図）。PR トークン上限の引き上げを判断のモデルが通さないのは、引き上げが親の権限（エピックの `子の PR トークン権限:` のコメント）に照らす止まりで、判断のモデルにはその権限が渡らないため。起こされた親が `references/epic.md` の手順 8 の専用の手順で権限に照らし、権限の内なら親が続けさせる（要件「親は PR トークン上限の止まりを権限に照らして続けさせる」）
- **出力の形**: 1 行目 `判断: 通す` か `判断: 主に上げる`、2 行目 `理由: <1 行>`、3 行目 `返事: <1 行>`
- **位置づけ**: この基準は案で主が PR で決めること、#1030 の「合理性があり危険が低い」はこの基準を参照すること

PR のマージの可否はこの基準で通してはならない（MUST NOT。#1030 の手順に任せる）。既存の規則が主に聞くと定めている止まりを、この基準で通してはならない（MUST NOT。既存の規則を変えるのはこの変更の範囲外）。

この要件の守備範囲で入力として扱うのは、`stop-judge.sh` が集めて判断に渡すものだけである（エピックの本文、子 issue の本文と OWNER・MEMBER・COLLABORATOR の注意書き、子の最新の停止の記録、同じ子への過去の `親の判断:`、このファイル、あれば配役表）と、手順 8 で親のセッションが読む同じ記録である。出どころは GitHub の issue とリポジトリのファイルで、親や子の会話は入らない。拾いたい誤りは、主の承認が要る止まり（聖域・破壊的操作・既存の規則が主に聞くと定めたもの・マージ）を親が通すこと、推奨の無い止まりや主の側の情報が要る止まりを通すこと、戻せない操作を通すこと、同じ件を通し続けること、主に聞く理由の 3 つのどれにも当たらない止まりを主に上げることの 5 つである。次は通ってよく、この要件では止めない: 子の記録の 2 行目以降の項目名や並びの違い（`主に聞く理由:` の無い以前の形を含む。形は要件「エピックの子の停止の記録は…」）／通してよい止まりを判断のモデルが主に上げること（手順 8 の親がもう一度照らす。主の手間は増えるが危険は無い）／通した判断があとで主に止められること（エピックの 1 行から事後に止める作り）。基準の文の解釈の揺れや、基準をすり抜ける止まりが見つかるたびに条件を足して塞ぎ切ることは、この要件の完了条件としない（基準は案で、主が PR と 2 週間後の再集計で見直す）。

#### Scenario: 基準のファイルに通す条件と出力の形が書かれている
- **WHEN** `parent-pass-criteria.md` を読む
- **THEN** 上の 9 つの通す条件（1 行目に、PR トークン上限の止まりは判断のモデルでは通さず、起こされた親が `epic.md` 手順 8 で親の権限に照らすことが添えてある）、判断できなければ主に上げること、通る例と通らない例（PR トークン上限の引き上げを通らない例に置き、判断のモデルには親の権限が渡らないことと、起こされた親が `epic.md` の手順 8 の専用の手順で権限に照らすことを添える。「親の返事だけでは記録が作られない」の文は無い）、3 行の出力の形が書かれ、マージと既存の規則が主に聞くと定めた止まりを通さないことが書かれている

#### Scenario: 基準のファイルが主に聞く理由の 3 つを原則に置いている
- **WHEN** `parent-pass-criteria.md` を読む
- **THEN** 「主に聞く理由の 3 つ（主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作）に当たらない止まりは親が通す」が書かれ、9 つの条件の行ごとに確かめる理由（3 つのどれか、または「繰り返していない」の歯止め）が書かれ、通る例に実機テストのための試しの issue 作成・止まった子の起動し直し・CI の再実行（無関係なテストの時間切れ・ランナーの混雑・待って打ち直すだけで済むもの）があり、CI の再実行は原因の切り分けを通す条件にしないこと、CI の見張りのやり直しの上限で止まった子への追加のやり直し 1 回が書かれている。「戻せる」の行に、同じ操作をやり直しても何も残らない操作（CI の再実行・ジョブの打ち直し）を含めることが書かれている

#### Scenario: 基準のファイルが子の主に聞く理由を鵜呑みにしない
- **WHEN** `parent-pass-criteria.md` の `主に聞く理由:` の読み方を読む
- **THEN** 書かれた理由が 3 つに当たるかを確かめること、`なし（…）` や 3 つに当たらない理由は通す側で読むこと、項目の無い記録はほかの項目から判断することが書かれている

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

### Requirement: エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く
develop の `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」は、1 行目 `子の停止: 主の返事待ち` の記録の 2 行目以降の形を次のとおり規定しなければならない（MUST）。読み手は親のセッション・親の決める役・主で、どれも子の会話を読んでいない前提で書く。

- 2 行目以降は次の 7 つの項目をこの並びで書く（MUST）。どの項目も省いてはならない（MUST NOT）
  1. `止まった理由:` — 主にしてほしいこと（決めること 1 つ、または操作）
  2. `主に聞く理由:` — 主に聞く理由の 3 つ（主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作。正本は `~/.claude/output-styles/readable.md` の節 3）のどれに当たるかを、その語で始めて 1 文で書く。「決まりで主の承認が要る」ときは、その決まりが何を守るためかまで書く。続けて論点（主が持っていて子が持っていない観点を足すと結論がよくなる点）の有無を書き、決まりで聞いているだけなら `論点なし（決まりで聞いている）` と書く。どれにも当たらないのに子の側で進められないときは `主に聞く理由: なし（<子の側で進められない理由>）` と書く
  3. `前提:` — 子が作業中に分かった事実のうち、判断に要るもの
  4. `推奨:` — 子が勧める答え
  5. `推奨の根拠:` — その推奨を選ぶ理由
  6. `受け入れるリスク:` — 推奨を選ぶことで新たに生じるリスク（他の案や何もしない場合には無いもの）だけ。無ければ `なし`。何が起きるか（被害の大きさ・戻せるか）、どれくらい起きるか（起きる条件と頻度）、その根拠（確かめたのか見込みか）を含める。分からないときは「分からない」と書き、何を調べれば分かるかを添える
  7. `再開に要る途中経過:` — 返事を受けて再開するのに要る途中経過（作業の状態・コミット・PR など）。「保留で止まるときの引き継ぎ」を書く場面では引き継ぎのコメントの URL を含める
- 主に聞く理由の 3 つのどれにも当たらない止まりは、子がそもそも止まらずに自分で進めて事後報告するのが正本の決まりであることを書く（MUST）。`主に聞く理由: なし（…）` は、子の側で進められないときだけに使う
- 各項目は行頭の `<項目名>:` で始め、値を同じ行に書く（MUST）。値は次の項目の行まで複数行に続けてよい（MAY）
- 該当が無い項目は値を `なし` と書く（MUST）。推奨を出せない（主の側にしか無い情報が要る）ときは `推奨: なし（<足りない情報>）` と書き、`推奨の根拠:` と `受け入れるリスク:` は `なし` と書く（MUST）
- 書き方として、子が作業中に振ったラベル・番号・略称や「上記」「前回」で指さず中身を書くこと、PR・issue・コメントにはフル URL を添えること、専門用語は初出で一言の言い換えを添えることを規定する（MUST）。文章全般の書き方は `rules/communication-style.md` を正本とし、`references/epic-child-stop.md` に写さない（MUST NOT）
- 親は記録の項目を正本の段に置き直して主に報告し、項目名をそのまま主に渡さないことを書く（MUST。親の側の規定は要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」）。項目名 `止まった理由` は、`references/epic.md` の「回し方」の別セッション方式の「マージ待ちの子」の段落と `references/parent-merge-criteria.md` が値の頭（`PR のマージ待ち（`）で読むので変えない（MUST）
- CI の見張り（`references/ci-watch.md`）で止まったとき（6 の表の `escalate`、`obs.state` が `wait` でない `none`（前回と同じ状態・同じ HEAD の決着。親が追加のやり直しを許したあと同じ HEAD でまた落ちたときはこれになる）、7 の直し方の手順 7 で直せずに上げたときのどれか）は、`再開に要る途中経過:` に PR の URL・落ちたチェック名・止まった時点の PR の HEAD の短い SHA を書く（MUST）。短い SHA は PR の HEAD のコミット SHA の先頭 7 文字とし（MUST）、`ci-watch.sh next` の出力の `obs.head` か `gh pr view` の `headRefOid` から取る。取れなかったときは値を作らずに `HEAD 不明` と書く（MUST）。項目の数は 7 つのままとし、HEAD のための項目を足してはならない（MUST NOT）。`references/ci-watch.md` の `escalate` と `none` の行がこの記録を指す規定は、要件「CI の見張りの手順は共有 reference に 1 本置く」（dev-workflow-ci-watch）の 6 が持ち、この要件には写さない

この要件の守備範囲で入力として扱うのは、`references/epic-child-stop.md` の記録の項の文と、子が投稿する記録のコメントの本文である。拾いたい誤りは、項目が欠けて読み手が書き忘れと該当なしを区別できないこと、子の会話の中でしか通じない呼び名で書かれて読み手が聞き返すこと、主に聞く理由とリスクの頻度・根拠が無くて親が正本の型で書けないこと、`止まった理由:` の値の頭を読む箇所と項目名が食い違うこと、CI の見張りのやり直しの上限で止まった子の記録に HEAD が無くて親が過去の `親の判断:` と同じ件かを見分けられないこと、の 5 つである。次は通ってよく、この要件では止めない: 値の長さや改行の違い／`なし` の後ろに短い補足が付くこと／同じ止まりで記録を投稿し直すこと（最新の 1 件を正とする）／この変更の前に起動された子が以前の 6 項目の形で書くこと（判断と親はほかの項目から読む）／CI の見張りで止まった子が HEAD の短い SHA を書き忘れること、HEAD を書く規定の前に起動された子が書かないこと（親は `parent-pass-criteria.md` のとおり `不明` と扱い、同じ件かを見分けられないものとして主に上げる側に倒れる）。記録の中身（理由・推奨・リスク）の正しさを確かめることと、書き方の穴が見つかるたびに検査や決まりを足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: `references/epic-child-stop.md` に記録の 7 つの項目名がこの並びで書かれている
- **WHEN** `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」を読む
- **THEN** `止まった理由:`・`主に聞く理由:`・`前提:`・`推奨:`・`推奨の根拠:`・`受け入れるリスク:`・`再開に要る途中経過:` がこの順で書かれ、どの項目も省かないこと、該当が無いときは `なし`、推奨を出せないときは `推奨: なし（<足りない情報>）` と書くことが書かれている

#### Scenario: 主に聞く理由とリスクの中身が書かれている
- **WHEN** `references/epic-child-stop.md` の同じ節の記録の形を読む
- **THEN** `主に聞く理由:` に 3 つの理由のどれかを書くこと、どれにも当たらないときは止まらずに進めるのが決まりで、子の側で進められないときだけ `主に聞く理由: なし（<子の側で進められない理由>）` と書くことが書かれ、`主に聞く理由:` に論点の有無を書くこと、`受け入れるリスク:` は推奨を選ぶことで新たに生じるものだけで、頻度と根拠（確かめたのか見込みか）を含めることが書かれている

#### Scenario: 記録の書き方の決まりが書かれている
- **WHEN** `references/epic-child-stop.md` の同じ節を読む
- **THEN** 子の会話を読んでいない読み手に向けて書くこと、子が振ったラベル・番号や「上記」「前回」で指さないこと、フル URL を添えること、専門用語に言い換えを添えることが書かれ、`rules/communication-style.md` を指している

#### Scenario: 項目名をそろえる規定が置き直しの規定に替わっている
- **WHEN** `references/epic-child-stop.md` の同じ節を読む
- **THEN** 項目名を親の手順 8 の語と同じにしてあるという文が無く、親が記録を正本の段に置き直して主に報告することが書かれている

#### Scenario: CI の見張りで止まったときの書き方が記録の形の節に書かれている
- **WHEN** `epic-child-stop.md` の「記録の形」を読む
- **THEN** CI の見張りの `escalate`、`obs.state` が `wait` でない `none`（前回と同じ状態・同じ HEAD の決着）、直し方の手順 7 のどれかで止まったときは、`再開に要る途中経過:` に PR の URL・落ちたチェック名・止まった時点の PR の HEAD の短い SHA を書くこと、短い SHA は PR の HEAD のコミット SHA の先頭 7 文字で `obs.head` か `headRefOid` から取ること、取れなければ `HEAD 不明` と書くことが書かれ、項目の数は 7 つのままである

### Requirement: エピックの子の完了報告は、主がこのセッションで次にすることを 1 行目に書く
develop の SKILL.md の節「ループの終わり」は、`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッション（エピックの子）の完了報告について、次を規定しなければならない（MUST）。

- 完了報告の 1 行目は `主がこのセッションで次にすること: なし` か `主がこのセッションで次にすること: <中身>` とする（MUST）。中身があるときは、どの画面で何をするかまで書く（MUST）
- 記録先が issue で PR がマージ済みで `mark <done|waiting>` を呼ぶときは、1 行目が `なし` なら `done`、中身があれば `waiting` を選ぶ（MUST）
- エピックの子でないセッションの完了報告には、この 1 行を求めない（MUST NOT。主が会話の前にいて、記録先の範囲を超えるため）

この要件の守備範囲で入力として扱うのは、`route` の出力と、子が書く完了報告の本文である。拾いたい誤りは、子のタブを開いた主が次に何をすればよいか分からないこと、完了報告の 1 行目と `mark` の印が食い違うこと（`なし` なのに `waiting`、中身があるのに `done`）の 2 つである。次は通ってよく、この要件では止めない: 2 行目以降の報告の形の違い／PR がマージされずに完了報告を書くとき（`mark` を呼ばないので印との対応は問わない）。1 行目の中身の正しさを確かめることと、穴が見つかるたびに検査や決まりを足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: SKILL.md のループの終わりに完了報告の 1 行目が書かれている
- **WHEN** SKILL.md の節「ループの終わり」を読む
- **THEN** エピックの子（`route` が `nested`）の完了報告の 1 行目を `主がこのセッションで次にすること:` で始め、無ければ `なし` と書くこと、中身があればどの画面で何をするかまで書くこと、`なし` なら `done`・中身があれば `waiting` を選ぶことが書かれている

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

### Requirement: epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける
この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の確認 7（マージ済み PR の先端と HEAD の一致）で一致する行が無かったときの扱いに優先しなければならない（MUST）。7 の 1 段・2 段の出力の取り方、一致したときの扱い、1〜6 の確認、片付け（`orca terminal close` → `--force` なしの `orca worktree rm` → ローカルブランチの削除）の手順は変えない。

`reap` は、7 の 1 段と 2 段のどちらでも HEAD と一致する行が無く、HEAD（`git -C <子のパス> rev-parse HEAD` の出力）が空でない子について、従来の理由を出す前に次の順で確かめなければならない（MUST）。以下で「従来の理由」は、7 の 1 段と 2 段の出力がどちらも空なら `no-merged-pr`、どちらかに出力があれば `head-mismatch` を指す。外れた時点でその子についてはそれ以上何も呼ばず、対応する 1 行を出して次の子へ進まなければならない（MUST）。HEAD が空の子は従来どおり従来の理由を出す（MUST）。

1. `gh pr list --head <ブランチ> --state all --json number --jq '.[].number'` が非 0 なら `kept <N> pr-lookup-failed`。出力が空でなければ（状態を問わずそのブランチの PR がある）`kept <N> <従来の理由>`
2. `gh api repos/{owner}/{repo}/issues/<N> --jq .state` が非 0 なら `kept <N> issue-lookup-failed`。出力が `closed` でなければ `kept <N> <従来の理由>`
3. リモートの今の base の先端（以下 base の先端）を `git ls-remote origin refs/heads/<base>` で取る。`<base>` は環境変数 `EPIC_DISPATCH_BASE` の値で、未設定か空なら `main`。`git ls-remote` が非 0 か、出力の 1 列目に 40 桁の 16 進の commit ID が無ければ `kept <N> base-lookup-failed`
4. `git cat-file -e <base の先端>^{commit}` が非 0 なら（base の先端の commit が手元に無い）、`git fetch origin <base>` を呼んでから `git cat-file -e` をもう 1 回呼ぶ。それでも非 0 なら（fetch が非 0 だったときを含む）`kept <N> base-lookup-failed`
5. `git -C <子のパス> merge-base --is-ancestor <HEAD> <base の先端>` を呼ぶ。exit 0 なら通る。exit 1 なら `kept <N> unmerged-commits`、それ以外の終了コードなら `kept <N> git-failed`

祖先の判定の相手に手元の追跡参照（`refs/remotes/origin/<base>`）を使ってはならない（MUST NOT。リモートの base が force push で巻き戻されたあと、古い追跡参照と子の HEAD が同じなら判定が通り、今の base に無い commit を持つブランチを消してしまうため）。`git ls-remote` は 1 回の `reap` の呼び出しで最大 1 回だけ呼び、その結果（失敗を含む）を後の子に使い回さなければならない（MUST）。`git fetch` も 1 回の `reap` の呼び出しで最大 1 回とし、2 件目以降の子で base の先端の commit が手元に無ければ fetch を呼ばずに `kept <N> base-lookup-failed` とする（MUST）

1〜5 をすべて通った子は、7 を通った子と同じ手順で片付けなければならない（MUST）。ローカルブランチの削除の条件（先端が HEAD と同じとき・`git worktree list` から外れるのを待つこと・消す直前に先端を読み直すこと）と、出す行（`reaped <N>` / `reaped <N> branch-kept` / `kept <N> close-failed` / `kept <N> rm-failed` / `kept <N> rm-failed-terminal-sweep`）も同じとする（MUST）。

`reap` は issue の `state_reason` を見てはならない（MUST NOT。消してよいかは main に入っていない commit が無いことで決まり、閉じ方の理由で変わらないため）。`git fetch` は 4 の場合のほかに呼んではならない（MUST NOT）。7 で HEAD と一致する行があった子について、1〜5 のどれも呼んではならない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の入力に加え、`gh pr list --head <ブランチ> --state all` の出力の有無と終了コード、`gh api repos/{owner}/{repo}/issues/<N> --jq .state` の出力と終了コード、`git ls-remote origin refs/heads/<base>` の出力と終了コード、`git cat-file -e`・`git fetch origin <base>`・`git merge-base --is-ancestor` の終了コードである。拾いたい誤りは、PR を作らず issue を閉じた子のワークツリーが `no-merged-pr`・`head-mismatch` で残り続けること、および今のリモートの base に入っていない commit（base の巻き戻しで消えた commit を含む）・マージされていない PR・開いている issue を持つ子を消すことである。次は通してよく、この要件では止めない: `.gitignore` の対象のうち `LLM/` 以外（既存の要件と同じく守らない）／`--base` で main 以外から起動したのに `EPIC_DISPATCH_BASE` を設定していない親の子（`unmerged-commits` か `git-failed` で残る）／`git ls-remote` で base の先端を取ってから子のワークツリーを消すまでの間に、リモートの base が巻き戻されること／fetch と ls-remote の間に base がさらに進み、先端の commit が手元に無いままの子（`base-lookup-failed` で残り、次の `reap` で通る）。すり抜ける入力が見つかるたびに確認を足して塞ぎ切ることは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`git`・`sleep` を PATH 上のスタブにして、下の Scenario を確かめなければならない（MUST）。

#### Scenario: PR が無く issue を閉じ、HEAD がリモートの今の main に含まれる子は片付ける
- **WHEN** 要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の 1〜6 を満たす子 11 について、`gh pr list` の出力が `--state merged`・`--search <HEAD>`・`--state all` のどれでも空、`gh api repos/{owner}/{repo}/issues/11 --jq .state` の出力が `closed`、`git ls-remote origin refs/heads/main` の出力が base の先端 `ccc333…`（40 桁）の 1 行、`git cat-file -e` が exit 0、`git -C <子> merge-base --is-ancestor <HEAD> <base の先端>` が exit 0 のスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close --worktree path:<子> --all` と `orca worktree rm --worktree path:<子>` がこの順に 1 回ずつ呼ばれ、どの `orca` の呼び出しにも `--force` が無く、`git merge-base --is-ancestor` は `refs/remotes/origin/main` ではなく base の先端の commit ID に対して呼ばれ、`git fetch` は呼ばれず、stdout は `reaped 11` の 1 行で exit 0

#### Scenario: main の先端の PR が検索に出ても、PR の無い子は片付ける
- **WHEN** 上の Scenario から、`--search <HEAD>` の出力だけを HEAD と違う `headRefOid` の 1 行に変えたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca worktree rm` が 1 回呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: PR がある子は issue が閉じていても従来の理由で残す
- **WHEN** 最初の Scenario から、`--state all` の出力だけを 1 行（PR の番号）に変えたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `gh api`・`git merge-base`・`orca terminal close`・`orca worktree rm` は 1 回も呼ばれず、stdout は `kept 11 no-merged-pr` で exit 0

#### Scenario: issue が開いている子は従来の理由で残し、状態を読めなければ issue-lookup-failed
- **WHEN** 最初の Scenario から、issue の状態の出力を `open` に変えたスタブ環境、`gh api` が非 0 で終わるスタブ環境、`--state all` の `gh pr list` が非 0 で終わるスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** どれも `git merge-base`・`orca worktree rm` は呼ばれず、stdout は順に `kept 11 no-merged-pr`・`kept 11 issue-lookup-failed`・`kept 11 pr-lookup-failed` で exit 0

#### Scenario: main に入っていない commit がある子と、祖先を判定できない子は残す
- **WHEN** 最初の Scenario から、`git merge-base --is-ancestor` の終了コードを 1 に変えたスタブ環境と 128 に変えたスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** どちらも `orca terminal close`・`orca worktree rm`・`git branch -D` は呼ばれず、stdout は順に `kept 11 unmerged-commits`・`kept 11 git-failed` で exit 0

#### Scenario: リモートの base が巻き戻されていれば、古い追跡参照と同じ HEAD の子も残す
- **WHEN** 最初の Scenario から、手元の `refs/remotes/origin/main` が子の HEAD と同じ（巻き戻し前の先端）で、`git ls-remote` が返す base の先端が巻き戻し後の別の commit、その先端に対する `git merge-base --is-ancestor <HEAD> <base の先端>` が exit 1 のスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `orca terminal close`・`orca worktree rm`・`git branch -D` は呼ばれず、stdout は `kept 11 unmerged-commits` で exit 0

#### Scenario: リモートの base を読めない子は残す
- **WHEN** 最初の Scenario から、`git ls-remote` が非 0 で終わるスタブ環境、`git ls-remote` の出力が空のスタブ環境、`git cat-file -e` が常に非 0 で `git fetch` が非 0 で終わるスタブ環境、`git cat-file -e` が常に非 0 で `git fetch` が exit 0 のスタブ環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** どれも `git merge-base`・`orca worktree rm` は呼ばれず、stdout は `kept 11 base-lookup-failed` で exit 0

#### Scenario: 先端の commit が手元に無ければ 1 回だけ fetch してから判定する
- **WHEN** 子 11 と子 12 がどちらも最初の Scenario の条件を満たし、`git cat-file -e` が 1 回目だけ非 0 で 2 回目以降は exit 0 のスタブ環境で `epic-dispatch.sh reap 11 12` を実行する
- **THEN** `git ls-remote` と `git fetch origin main` はそれぞれ 1 回だけ呼ばれ、stdout は `reaped 11` と `reaped 12` の 2 行で exit 0

#### Scenario: 起点のブランチは EPIC_DISPATCH_BASE で変わる
- **WHEN** 最初の Scenario の環境で、`EPIC_DISPATCH_BASE=develop` を付けて `epic-dispatch.sh reap 11` を実行する
- **THEN** `git ls-remote` は `origin refs/heads/develop` に対して呼ばれ、stdout は `reaped 11` で exit 0

#### Scenario: マージ済み PR で一致した子には PR の無い子の確認を呼ばない
- **WHEN** 要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の Scenario「条件をすべて満たす子は端末を閉じてからワークツリーを消す」の環境で `epic-dispatch.sh reap 11` を実行する
- **THEN** `gh pr list --state all`・`gh api`・`git ls-remote`・`git fetch`・`git merge-base` は 1 回も呼ばれず、stdout は `reaped 11` で exit 0

### Requirement: develop のループの終わりは、PR を伴わない子を親が片付ける条件を書く
develop の SKILL.md の節「ループの終わり」の、PR を伴わない記録先 issue を閉じて `mark` を呼ぶ項は、親の `epic-dispatch.sh reap` がその子を片付ける条件（そのブランチに PR が無い・issue が閉じている・HEAD がリモートの今の main に含まれる）と、main に入っていない commit を積んだまま閉じると `kept <N> unmerged-commits` で残ることを書かなければならない（MUST）。`mark` を呼ぶ手順は変えない（SHALL）。

#### Scenario: ループの終わりに PR の無い子の片付けの条件が書かれている
- **WHEN** SKILL.md の節「ループの終わり」を読む
- **THEN** PR を伴わない記録先 issue の項に、親の `reap` が片付ける条件と `unmerged-commits` の語が書かれている

### Requirement: launch は worktree create が作った空のシェルの端末を子のセッションの端末に使い、子のワークツリーの端末を 1 つに保つ
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子ごとに `orca worktree create` が終わったあと、`orca terminal list --worktree path:<子> --json` で端末を数えなければならない（MUST。Orca は worktree create で空のシェルの端末を 1 つ作り、`orca terminal create` で 2 つ目を作ると子の端末が 2 つになって、`reply` が `ambiguous-terminal` で止まるため）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の launch の呼び出し順のうち、端末を用意する段の中身を定める（その要件の本文はこの変更で端末を用意する段を条件付きに直してある）。それ以外の規定（起動コマンドの形・環境変数・`terminal wait`・`terminal send`）は変えない。`launched`/`failed` の判定は、この要件では定めない（MODIFIED 側の本文に従う）。

- 端末がちょうど 1 つなら、`orca terminal create` を呼ばず、その端末のハンドルに `orca terminal send --terminal <handle> --text <cmd> --enter --json` で起動コマンド `<cmd>`（従来 `--command` に渡していた文字列と同じ）を打ち込む（MUST）。続けて `orca terminal list --worktree path:<子> --json` を引き直し、その端末が Claude Code（`agentIdentity` が `claude`、無ければタイトルに `Claude Code` を含む）になるのを待つ（MUST。シェルは起動コマンドを打つ前から idle で、すぐ `terminal wait` を呼ぶと最初の指示がシェルに入るため）。待つ上限は `EPIC_DISPATCH_READY_TIMEOUT_MS` を秒にした値（最低 1 回）とする。Claude Code になったら、その端末のハンドルで `terminal wait --for tui-idle` と指示の `terminal send` へ進む（MUST）
- 端末が 0 個なら、従来どおり `orca terminal create` で作る（MUST。worktree create が端末を作らない版の後方互換）
- 一覧を読めない・端末が 2 個以上（起動コマンドを打ち込んだあとの引き直しで 2 個以上になった場合を含み、その場合は指示を送らない）・起動コマンドを打ち込めない・待っても Claude Code にならない、のいずれかなら、その子を `failed <N>` とし、`orca terminal create` を呼ばない（MUST。端末を増やすと二重起動の原因になるため）。stderr に理由と、確認または続きを手で行うコマンド（`orca terminal list --worktree path:<子> --json`、`orca terminal read --terminal <handle>`、打ち込めなかった起動コマンド）を出す（SHALL）

#### Scenario: worktree create が作ったシェルの端末で子のセッションが起動し、端末は 1 つのまま
- **WHEN** 子 11 のワークツリーに空のシェルの端末（`term-11`、`agentIdentity` なし）が 1 つあり、起動コマンドが届いたあとは同じ端末が `agentIdentity: claude` になるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` は呼ばれず、`orca terminal send --terminal term-11` が 2 回（1 回目は `EPIC_DISPATCH_PARENT_EPIC=400 cld --settings '{"idleCompaction":false}' --model 'opus'` を含む `--enter --json`、2 回目は `/develop #11` を含む指示）、`orca terminal wait --terminal term-11 --for tui-idle` が 1 回呼ばれ、stdout は `launched 11`、exit 0

#### Scenario: 端末が 0 個なら従来どおり terminal create で作る
- **WHEN** 子 11 のワークツリーの端末が 0 個のスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create --worktree path:<子 11> --command ... --json` が呼ばれ、stdout は `launched 11`、exit 0

#### Scenario: シェルの端末が Claude Code にならなければ端末を作らずに failed
- **WHEN** 起動コマンドを打ち込んだあとも端末が Claude Code にならないスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` も `orca terminal wait` も呼ばれず、stderr に `did not become Claude Code` を含む行が出て、stdout は `failed 11`、exit 1

#### Scenario: 端末が 2 個以上・一覧が読めないときは端末を作らずに failed
- **WHEN** 子 11 のワークツリーの端末が 2 個ある、または `orca terminal list` が非 0 で終わるスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` は呼ばれず、stdout は `failed 11`、exit 1

この要件の守備範囲で入力として扱うのは、`orca terminal list --worktree path:<子> --json` の出力である。出どころは、launch が直前に worktree create で作った子のワークツリーに対する Orca 自身の出力で、人が手で打つ入力ではない。拾いたい誤りは、端末の数を取り違えて端末を増やすこと（一覧が読めないのを 0 個として作る、2 個以上なのに作る）と、シェルが idle のうちに最初の指示を送ってしまうことである。通してよい入力は、`result.terminals` が配列で、要素の `handle` が空でない文字列のもの（`agentIdentity` や `title` が無い要素を含む。使い回す端末の識別には起動後の `agentIdentity`・タイトルだけを使う）、および `Terminal 1` 以外のタイトルの端末である。一覧の形が変わったときの検知は範囲外とし、読めなければ `failed` として表に出すだけにする。入力の穴を塞ぎ切ることをこの要件の完了条件としない。

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

### Requirement: 親がマージに回してよい子の PR の基準を 1 つのファイルに置く
`plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md` は、`human-merge` の付いた子の PR を親が自動マージの処理に回してよい範囲の基準と、判断の出力の形を書かなければならない（MUST）。条件名と「迷ったら主に上げる」は `parent-pass-criteria.md` とそろえる（MUST）。マージの条件を `parent-pass-criteria.md` に足してはならない（MUST NOT。`stop-judge.sh` がそのまま読むプロンプトで、マージはその基準で通さないと定めているため）。

- **可の条件**: 次の 6 つをすべて満たすときだけ可にする。見送りが聖域接触だけ（見送りラベルが自動マージの処理が付けた `human-merge` だけで、変更ファイル（rename 元を含む）がマージ条件そのもののパスに触れていない）／ゲートが今の HEAD で済んでいる（`agent-review:passed` と今の HEAD の宣言・証拠のコメントがあり、CI が green）／主の側の情報が要らない（リスク宣言が「リスクなし」か、主の許容が今の HEAD について記録済み）／範囲の内側（差分が子 issue の受け入れ条件とエピックの目的を広げず、逆向きにもしない）／戻せる（revert PR で元に戻り、マージから戻すまでの間にリポジトリの外へ戻せない作用（外部公開・送信・課金・データ削除・秘密情報）が出ない）／配役表で主の観点が無い（配役表が渡されたとき、この変更に要る観点の担い手が主でない）
- **迷ったとき**: 1 つでも満たさないか、満たすか判断できなければ主に上げる
- **各条件と `parent-pass-criteria.md` の条件の対応**を書く
- **出力の形**: 1 行目 `裁定: 可`・`裁定: 否`・`不足: <足りないもの>` のどれか、2 行目 `理由: <1 行>`
- **位置づけ**: マージの実行は自動マージの処理が行い、この基準は親が判断の印を付けてよいかだけを決めること。マージ条件そのもののパスと判断後の push は処理の側が止めること

この要件の守備範囲で入力として扱うのは、親が決める役に貼るもの（要件「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」の判断の項）と、このファイル、あれば配役表である。拾いたい誤りは、主のリスクの許容が要る PR を可とすること、範囲を広げる差分を可とすること、外へ戻せない作用を持つ PR を可とすること、ゲートや CI が今の HEAD で済んでいない PR を可とすることの 4 つである。次は通ってよく、この要件では止めない: 可としてよい PR を否とすること／判断した可があとで主に止められること（revert PR で戻す）。基準の文の解釈の揺れや、基準をすり抜ける PR が見つかるたびに条件を足して塞ぎ切ることは、この要件の完了条件としない（基準は案で、主が PR で見直す）。

#### Scenario: 基準のファイルに 6 条件と出力の形が書かれている
- **WHEN** `parent-merge-criteria.md` を読む
- **THEN** 上の 6 つの条件名、判断できなければ主に上げること、`parent-pass-criteria.md` の条件との対応、`裁定: 可`・`裁定: 否`・`不足:` の出力の形、マージの実行は自動マージの処理が行うことが書かれている

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

### Requirement: wait --resolve は通す返事を送る前に起動し直すかを表で決める
`epic-dispatch.sh wait --resolve` の `resolve_stopped` は、判断が `通す` のとき、`reply-after-idle.md` の子の表に従って `deliver_reply` の `relaunch` を決めなければならない（MUST）。子の会話量 `context_tokens` が `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）以上なら、経過時間と `compact_boundary` の有無によらず起動し直す（`relaunched`）。子の最後のリクエスト（トランスクリプトの最後の assistant の行の `timestamp`）から `EPIC_DISPATCH_RELAUNCH_IDLE_SEC`（既定 3600）秒以上の場合も、会話量と `compact_boundary` の有無によらず起動し直す。2 条件は OR とし、どちらも真と確認できなければ今までどおり送る（`sent`）。トランスクリプトは、状態の記録の `worktree` のパスの英数字以外を `-` に置換した名前の `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}` 直下のディレクトリの `*.jsonl` で、ちょうど 1 本のときだけ使う（MUST）。0 本・2 本以上・ファイルを読めないときはそのまま送る（端末が無いときの起動し直しは既存の送信処理に従う）。会話量は同じトランスクリプトを `plugins/dev-workflow/scripts/subagent-context.sh --file <file>` で測った `context_tokens` を使う（MUST）。exit 0 と 2 の JSON の値を比較し、`over_cap` やサブエージェント用の閾値で代用してはならない（MUST NOT）。会話量を読めなくても時間条件が真なら起動し直し、時刻を読めなくても会話量条件が真なら起動し直す（MUST）。新しい閾値と既存の時間閾値は未設定のときだけ既定を使い、数字だけの非負整数を受け付け、空か数字だけでない値なら、有効な `--resolve` の待ち受けに入る前に変数名と使い方を出して exit 1 で終わる（MUST）。`EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` は読まない（SHALL。設定されていても値を検査しない）。`tests/epic-dispatch.bats` は偽の `orca`・`gh`・トランスクリプトで次の Scenario を確かめなければならない（MUST）。

この要件の入力は、状態の記録の `worktree`、一意に選ばれたトランスクリプトの `timestamp`・`type` と会話量の計測値、上の環境変数である。拾いたい誤りは、大きい会話の子へ 60 分未満だからとそのまま送り続けること、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子を含む）へそのまま送ること、会話量が閾値未満かつ 60 分未満の子を不要に起動し直すことである。次は通してよく、この要件では止めない: 経過時間が 60 分前後で時刻の読み方により扱いが分かれる子／トランスクリプトが複数あり、そのまま送った子／PC が寝ていて、60 分未満と読め、会話量条件も真と確認できなかった子／計測に必要な情報が欠けて両方の条件を真と確認できなかった子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。送れたあとのエピックの記録と、成功した子を待ち受けの出力から外す契約は維持する（MUST）。以下の `sent` / `relaunched` は送信処理の結果であり、`wait` の stdout にその行を追加する要件ではない。

#### Scenario: 60 分以上・コンパクトなし・150,000 以上なら起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、`compact_boundary` が無く、会話量が 150,000 以上で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届き、エピックに通した記録が残る

#### Scenario: 60 分以上なら会話量によらず起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、`compact_boundary` が無く会話量が 150,000 未満で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 60 分以上ならコンパクトが走っていても起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、そのあとに `compact_boundary` がある状態で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 60 分未満ならそのまま送る
- **WHEN** 最後のリクエストが 60 分未満前で会話量が 149999 の子に、既定値で同じ実行をする
- **THEN** 返事は `sent` で届く

#### Scenario: 事実を読めなければそのまま送る
- **WHEN** トランスクリプトが無い、または 2 本ある
- **THEN** 返事は `sent` で届く

#### Scenario: 閾値の環境変数が数字でなければ起動しない
- **WHEN** `EPIC_DISPATCH_RELAUNCH_IDLE_SEC=1h` で `wait --resolve` を実行する
- **THEN** stderr に変数名と使い方が出て exit 1 である

#### Scenario: 会話量の環境変数は読まない
- **WHEN** `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS=150k` で、最後のリクエストが 60 分以上前の子に `wait --resolve` を実行する
- **THEN** exit 1 にならず、返事は `relaunched` で届く

#### Scenario: 60 分未満でも会話量が閾値ちょうどかそれ以上なら起動し直す
- **WHEN** 最後の assistant が 5 分前で `context_tokens` が 150000 または 150001 の子に、既定値で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届き、端末を起動し直して `/develop #<child>` と返事を送り、送れたあとにエピックに通した記録が残る

#### Scenario: 会話量条件は compact の有無によらない
- **WHEN** 最後の assistant が 5 分前で、`compact_boundary` がある子の最新の有効な usage による会話量が 150000 の状態で、既定値で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: compact 後の最新の会話量が小さければそのまま送る
- **WHEN** 150000 以上の usage のあとに `compact_boundary`、そのあとに 5 分前で会話量が 100000 の有効な usage がある状態で、既定値で実行する
- **THEN** 返事は `sent` で届き、compact 前の最大値では起動し直さない

#### Scenario: キャッシュの量も含む最後の有効な usage で決める
- **WHEN** 5 分前の有効な assistant usage が input 10000・cache_creation 40000・cache_read 100000 で、そのあとに usage が全部 0 の API エラーの assistant があり、既定値で実行する
- **THEN** `subagent-context.sh --file` の会話量 150000 を使い、返事は `relaunched` で届く

#### Scenario: 会話量を読めなくても時間条件で起動し直す
- **WHEN** 一意で読めるトランスクリプトに有効な usage が無い、または会話量の計測が失敗したが、最後の assistant が 60 分以上前の状態で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 時刻を読めなくても会話量条件で起動し直す
- **WHEN** 一意で読めるトランスクリプトから時刻を読めないが、会話量が 150000 の状態で既定値で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 両条件とも真と確認できなければそのまま送る
- **WHEN** 時刻と有効な usage の両方が無い、または最後の assistant が 5 分前で会話量だけを計測できない状態で実行する
- **THEN** 返事は `sent` で届く

#### Scenario: 会話量閾値は既定値と独立して上書きできる
- **WHEN** 最後の assistant が 5 分前で会話量 160000 の子に `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS=200000` で実行する
- **THEN** 返事は `sent` で届く

#### Scenario: 会話量閾値を 0 にできる
- **WHEN** 最後の assistant が 5 分前で会話量 100000 の子に `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS=0` で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 会話量閾値の不正値は待つ前に拒否する
- **WHEN** `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS` を空文字・`150k`・`-1` のいずれかにして有効な `wait --resolve` を実行する
- **THEN** 変数名と使い方を stderr に出して exit 1 となり、子の端末を作成・送信・終了しない

### Requirement: 空の return を受けたら報告を 1 回だけ求め、同じ指示で起こし直さない

本体は、W が `(Subagent completed but returned no output.)` だけを返したとき（`continue: false` による打ち切りで、拒否理由が親に届かない場合を含む）、その W に SendMessage で報告を 1 回だけ求めなければならない（MUST）。求める報告の項目は、打ちたかったコマンドの全文・対象のパス・その対象を自分で作ったか（作ったなら作ったコマンド）・なぜ要るか・拒否の記録のパスの 5 つとし（MUST。子への拒否理由が求める項目とそろえる）、何をしようとして何が拒否されたかを書かせる。本体は、報告の有無によらず `git -C <path> status --porcelain` で作業ツリーの未コミット差分を確かめ、残っていれば引き取らなければならない（MUST）。報告に破壊的 git 操作で打ち切られたとあるときは、同じ指示で W を起こし直してはならない（MUST NOT）。扱いは要件「破壊的 git 操作の拒否の報告を受けたら、条件を満たすときだけ許可を書いて再開し、それ以外はオーナーに上げる」に従い、許可を書けなかった場合は、打ち切られた操作と指示の見直しを主に上げなければならない（MUST）。許可を書いて同じ W を SendMessage で再開することは、同じ指示での起こし直しに数えない。1 回求めても報告が空のとき、または報告から打ち切りの原因が読み取れないときも、同じ指示で W を起こし直してはならず（MUST NOT）、空だったことと作業ツリーの状態を主に上げなければならない（MUST）。`skills/develop/SKILL.md` の「1 ループ」の節に、これらが書かれていなければならない（MUST）。

この要件の対象は W だけである。R1・G・レビュアーなど再開しない役が空で返ったときの扱いは、この要件の範囲外とし、既存の要件（手渡しの許可条件、G が工程中断で返したときの扱い）に従う。

**守備範囲**: 判定する入力は、develop の本体が名前付きで起こした W の return 文字列である。W は名前付きで起こされるので SendMessage で再開できる（バックグラウンドと既定の起こし方の両方で報告を取り直せることは、実機確認で確かめる）。拾いたい誤りは、拒否の理由が届かない空の return を「作業が終わった」と読み違えること、および原因が分からないまま同じ指示で W を起こし直して同じ操作に再度当たることの 2 つである。通ってよい入力は、`(Subagent completed but returned no output.)` 以外の通常の return（`工程完了:` `工程中断:` で始まるもの）で、これには従来どおりの扱いを適用する。守らないものは、W が報告で嘘や誤りを書くこと（差分は報告に頼らず `git status` で確かめるに留める）、および空の return の原因が打ち切り以外であるすべての場合（原因が読めなければ主に上げる）である。穴が見つかるたびに判定を増やして塞ぎ切ることは完了条件にしない。

#### Scenario: 報告を 1 回だけ求める

- **WHEN** `skills/develop/SKILL.md` の `returned no output` を含む段落を読む
- **THEN** SendMessage で 1 回だけ報告を求める、と書かれており、`git -C <path> status --porcelain` で未コミット差分を確かめることも書かれている

#### Scenario: 打ち切られたら起こし直さない

- **WHEN** 同じ段落を読む
- **THEN** 報告に破壊的 git 操作で打ち切られたとあれば、同じ指示では起こし直さず、許可を書いて同じ W を再開できない場合に限って主に上げる、と書かれている

#### Scenario: 再報告が空でも起こし直さない

- **WHEN** 同じ段落を読む
- **THEN** 1 回求めても報告が空のとき（または原因が読み取れないとき）も、同じ指示では起こし直さず、空だったことと作業ツリーの状態を主に上げる、と書かれている

#### Scenario: 対象は W だけ

- **WHEN** 同じ段落を読む
- **THEN** 対象が W であり、再開しない役（R1・G・レビュアー）は既存の手順に従う、と書かれている

#### Scenario: 報告の項目を求める

- **WHEN** 同じ段落を読む
- **THEN** 報告に求める項目として「コマンドの全文」「対象のパス」「自分で作った」「なぜ」が書かれている

### Requirement: epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、エピックの子を同時に動かす数の上限を次のとおり決めなければならない（MUST）。環境変数 `EPIC_DISPATCH_MAX_PARALLEL` が設定されていればその値を使う。値は 1 以上の整数でなければならず、空文字・0・数字以外のときは stderr に変数名と使い方を出して exit 1 で終わる（MUST）。設定されていなければ既定値を使う。既定値は物理メモリの GiB（バイト数を 1073741824 で割った値）を 4 で割って切り捨てた値で、1 未満なら 1 とする（MUST）。物理メモリは `sysctl -n hw.memsize`（バイト）で読み、読めなければ `/proc/meminfo` の `MemTotal`（kB）で読む。どちらも読めない・数字でないときは既定値を 2 とし、stderr に物理メモリを読めなかったことを出す（MUST）。`/proc/meminfo` の代わりに読むファイルはテスト用の環境変数 `EPIC_DISPATCH_MEMINFO_FILE`（既定 `/proc/meminfo`）で差し替えられる（スクリプトの冒頭の説明にだけ書き、`references/epic.md` には書かない）。

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

#### Scenario: epic.md に既定値と根拠の実測値が書かれている
- **WHEN** develop の `references/epic.md`「回し方」を読む
- **THEN** `EPIC_DISPATCH_MAX_PARALLEL`、既定値の式（物理メモリの GiB を 4 で割って切り捨て・最小 1・読めなければ 2）、根拠の実測値（1 セッションの RSS の範囲）が書かれている

### Requirement: epic-dispatch.sh launch は空いた枠の分だけ子を起動し、残りを deferred で出す
`epic-dispatch.sh launch` は、子を起動する前に「枠を使っている子」を数え、上限（要件「epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める」）から枠を使っている子の数を引いた空き枠（0 未満なら 0。例えば上限 2・使用中 3 なら 0）の分だけ子を起動しなければならない（MUST）。これは要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `launch` の呼び出し順と `launched` / `skipped` / `failed` の判定を書き換えず、出力の語に `deferred <N>` を加え、create を呼ぶ前の判定に空き枠を加えるものである。

「枠を使っている子」は、`orca worktree list --json` のワークツリーのうち、`repoId` が今のワークツリーと同じ・`parentWorktreeId` が今のワークツリーの id（`orca worktree current --json` の `.result.worktree.id`）・`isArchived` が true でない・`linkedIssue` があるもので、さらに次をすべて満たすものとする（MUST）: `workspaceStatus` が `completed` でない（完了の印が無い）／`comment` が `epic-stopped` でも `epic-stopped-seen` でもない（主の返事待ちで止まった印が無い）／`gh api repos/{owner}/{repo}/issues/<linkedIssue> --jq .state` が `closed` でない。`gh` が非 0 で終わったか出力が `open` / `closed` 以外のときは、その子を枠を使っている子として数え、stderr にその子を出す（MUST。メモリを守る側に倒す）。今のワークツリーの id が取れないときは枠を使っている子を 0 件とし、stderr にその旨を出す（SHALL）。

引数の子は先頭から順に処理し、同じ呼び出しで処理済みの番号と、一覧に同じ子のワークツリーがある子は、今までどおり `skipped <N>` を出して空き枠を減らさない（MUST）。それ以外の子は、空き枠が 1 以上なら `orca worktree create` 以降に進み、結果が `launched` でも `failed` でも空き枠を 1 減らす（MUST）。空き枠が 0 なら `orca worktree create` を呼ばず、注意書きも投稿せず、stdout に `deferred <N>` の 1 行を出す（MUST）。`deferred` は失敗ではなく、`failed` が 0 件なら exit 0 で終わる（MUST）。`launch` は stderr に、上限・その出どころ（`EPIC_DISPATCH_MAX_PARALLEL` か物理メモリか既定の 2 か）・枠を使っている子の番号を 1 行で出す（SHALL。全部が後回しになったときに、何が枠を塞いでいるかを主に示すため）。`EPIC_DISPATCH_MAX_PARALLEL` の値が誤っているときは、`orca` も `git` も呼ばず、子を 1 件も作らずに exit 1 で終わる（MUST）。

この要件の入力は、`orca worktree current --json` の `id` と `repoId`、`orca worktree list --json` の `repoId`・`parentWorktreeId`・`isArchived`・`linkedIssue`・`workspaceStatus`・`comment`、`gh` が返す子 issue の state、本体が渡す子の番号の並びである。拾いたい誤りは、上限を超えて子を起動すること、閉じた子・完了の印の子・止まった子が枠を塞いで後回しの子がいつまでも起動されないこと、後回しにした子が出力に出ずに親が見失うことである。次は通してよく、この要件では止めない: 主の返事待ちから戻った子（`epic-resumed`）の分だけ一時的に上限を超えること／`launch` が数えたあと、起動するまでのあいだに子が閉じること／別の親ワークツリーから同じリポジトリで起動された子は数えないこと／`failed` で create まで進まなかった子にも空き枠を使うこと。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh` のスタブで次の Scenario を確かめなければならない（MUST）。

#### Scenario: 上限 2 で着手できる子を 5 件渡すと 2 件だけ起動し 3 件を後回しにする
- **WHEN** 枠を使っている子が 0 件で、`EPIC_DISPATCH_MAX_PARALLEL=2` のスタブ環境で `epic-dispatch.sh launch 400 11 12 13 14 15` を実行する
- **THEN** stdout は `launched 11`・`launched 12`・`deferred 13`・`deferred 14`・`deferred 15` の 5 行で、`orca worktree create` は子 11 と子 12 についてだけ呼ばれ、exit 0

#### Scenario: 動いている子が 1 件閉じると後回しにした子のうち 1 件が起動される
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、一覧に今のワークツリーから作られた子 11 と子 12 のワークツリー（印なし）があり、`gh` が子 11 を `closed`、子 12 を `open` と返すスタブ環境で `epic-dispatch.sh launch 400 12 13 14 15` を実行する
- **THEN** stdout は `skipped 12`・`launched 13`・`deferred 14`・`deferred 15` の 4 行で、`orca worktree create` は子 13 についてだけ呼ばれる

#### Scenario: 完了の印と止まった印の子は枠を使わない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、一覧に今のワークツリーから作られた子 11（`workspaceStatus` が `completed`）と子 12（`comment` が `epic-stopped-seen`）のワークツリーがあり、`gh` がどちらも `open` と返すスタブ環境で `epic-dispatch.sh launch 400 13 14 15` を実行する
- **THEN** stdout は `launched 13`・`launched 14`・`deferred 15` の 3 行

#### Scenario: 戻った子は枠を使う
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、一覧に今のワークツリーから作られた子 11（`comment` が `epic-resumed`）のワークツリーがあり、`gh` が `open` と返すスタブ環境で `epic-dispatch.sh launch 400 13 14` を実行する
- **THEN** stdout は `launched 13`・`deferred 14` の 2 行

#### Scenario: issue の state を読めない子は枠を使う側に数える
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、一覧に今のワークツリーから作られた子 11 のワークツリーがあり、`gh` が子 11 について失敗するスタブ環境で `epic-dispatch.sh launch 400 13` を実行する
- **THEN** stdout は `deferred 13` の 1 行、stderr に子 11 の state を読めなかったことが出て、exit 0

#### Scenario: 別の親から作られた子と archive された子は数えない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、一覧に `parentWorktreeId` が別のワークツリーの子 11 と、`isArchived` が true の子 12 のワークツリーがあるスタブ環境で `epic-dispatch.sh launch 400 13` を実行する
- **THEN** stdout は `launched 13`

#### Scenario: 使用中が上限より多ければすべて後回しにする
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、一覧に今のワークツリーから作られた子 11・12・13 のワークツリー（印なし）があり、`gh` がどれも `open` と返すスタブ環境で `epic-dispatch.sh launch 400 14 15` を実行する
- **THEN** stdout は `deferred 14`・`deferred 15` の 2 行で、`orca worktree create` は呼ばれず、exit 0

#### Scenario: 失敗した子も空き枠を使う
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、子 11 の `orca worktree create` が失敗するスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** stdout は `failed 11`・`deferred 12` の 2 行で exit 1

#### Scenario: 後回しの子には注意書きを投稿しない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` のスタブ環境で `epic-dispatch.sh launch --note 注意 400 11 12` を実行する
- **THEN** `gh issue comment` は子 11 についてだけ呼ばれ、stdout は `launched 11`・`deferred 12`

#### Scenario: 上限の値が誤っていれば何も呼ばない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=abc` で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca` も `git` も呼ばれず、stderr に使い方が出て exit 1

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

### Requirement: 破壊的 git 操作の拒否の報告を受けたら、条件を満たすときだけ許可を書いて再開し、それ以外はオーナーに上げる

本体は、名前付きで起こした W の報告（通常の return、または空の return への報告要求の返事）に、破壊的 git 操作を hook に拒否されたこと（拒否の記録のパスがある）が書かれているとき、次のとおり扱わなければならない（MUST）。`skills/develop/SKILL.md` の「1 ループ」の節の、要件「空の return を受けたら報告を 1 回だけ求め、同じ指示で起こし直さない」の段落に、これらが書かれていなければならない（MUST）。

許可を書く条件: 次の 4 つをすべて満たすときだけ、本体の Bash で `${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-permit.sh <拒否の記録のパス> <理由>` を実行する（MUST。許可の仕組みは spec destructive-git-hook の要件のとおりで、この要件は作り直さない）。

1. 報告に 4 項目（打ちたかったコマンドの全文・対象のパス・その対象を自分で作ったか（作ったなら作ったコマンド）・なぜ要るか）が揃い、報告のコマンドの全文が拒否の記録の `command` に一致する。拒否の記録の `cwd` はコマンドを始めたディレクトリであって操作対象ではないので、`cwd` と対象のパスは同じものとして照合しない（MUST NOT）。コマンドの全文・実行時の `cwd`・操作対象の 3 つを分けて見る: 全文は記録の `command` と、操作対象は報告の「対象のパス」と照合し、`cwd` は記録の値をそのまま使う。`git -C <scratchpad の中の repo> checkout -- .` を通常の worktree から打つ場合、`cwd` は worktree、対象は scratchpad の中の repo で、これは許可の対象になりうる
2. 操作対象（`cd` の移り先や `git -C` の指す repo）が、このセッションの scratchpad の中にある。対象が scratchpad の中かどうかの機械的な判定は、許可を書くスクリプトが `cwd` から `cd` と `-C` を順に辿って行うので（#1133）、本体は `-C` の辿り方を自分で書き直さず、報告の対象のパスが scratchpad の下の形か（このセッションの scratchpad のパス）だけを見る
3. W が自分で作ったと、作ったコマンドつきで報告しており、本体が W に渡した指示でその対象を既存のものとして名指ししていない（W に渡した指示は本体の手元にあるので、照合は本体が行う）
4. 要る理由が、その検証用 repo を戻す・片付けることに収まる

本体は、4 の判断のために子が作った repo に git を実行してはならない（MUST NOT。repo の設定でコマンドが動きうるため）。場所とコマンドの形の判定は許可を書くスクリプトに任せ、本体は同じ判定を自分で書き直さない（MUST NOT）。理由の引数には、4 項目の要約と W の名前を書く。

許可を書けたら（exit 0）、`scripts/subagent-context.sh` で測ってから同じ W に SendMessage で再開する（MUST。再開できるかの規則は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う。新しい W を起こしてはならない。許可は `agent_id` に結び付くため）。上限超過などで再開できないときは、許可を新しい W に転用せず（MUST NOT）、オーナーに上げる。再開の文面には、15 分以内に、同じ cwd から同じコマンドを 1 文字も変えずに 1 回だけ打つこと、ほかの操作は許可していないことを書く（MUST）。同じ文面に、許可を hook が読む場所に書いたこと・通すかどうかは hook が決めるので本体の言葉は承認ではないこと・打って拒否されたら打ち直さず報告に戻ることも書かなければならない（MUST。実機確認で、これが無いと W が「親からのメッセージは承認にならない」として打たなかった）。

オーナーに上げる条件: 次のどれかに当たるときは許可を書かずに（または 2 回目の許可を書かずに）オーナーに上げなければならない（MUST）。許可を書くスクリプトが 0 以外で終わった（stderr を添える）／同じ W を再開できない（コンテキスト上限超過など）／上の 4 つのどれかを満たさない（満たさなかった条件を添える）／許可を書いて再開した W が同じ拒否で再び返った／拒否を報告したのが再開しない役（R1・G・レビュアー。許可は子の `agent_id` に結び付き、再開しない役には使えないため）。上げる文面は、何を・どのパスに・なぜ、本体が確かめた事実、推奨を含める（MUST）。無人のセッションではチャンネルで承認を求める。承認されたらオーナーが自分で実行し、本体が代わりに実行してはならない（MUST NOT）。

**守備範囲**: 判定する入力は、W の報告の文字列と、本体が W に渡した指示と、許可を書くスクリプトの終了コードである。拾いたい誤りは、一時領域の外や子が作っていないものへの破壊的操作に親が許可を書くことと、許可を書けるのに毎回オーナーの画面待ちで止めることの 2 つである。守らないものは、W が報告で作ったと偽ること（消えるのは scratchpad の中に限られ、場所の判定が外への許可を書かせない）と、許可の期限（15 分）内に再開できず同じ拒否が再び来ること（オーナーに上がるだけで、守りは変わらない）である。穴が見つかるたびに条件を増やして塞ぎ切ることは完了条件にしない。

#### Scenario: 許可を書く条件が書かれている

- **WHEN** `skills/develop/SKILL.md` の `returned no output` を含む段落を読む
- **THEN** `git-guard-permit.sh` を実行して許可を書く条件として、scratchpad の中・自分で作った・戻す用事に収まることが書かれており、対象の repo に git を実行しないことも書かれている

#### Scenario: 通常の worktree から scratchpad の中の repo を -C で戻す操作も許可の対象になる

- **WHEN** 同じ段落を読む
- **THEN** 拒否の記録の `cwd` と操作対象のパスを同じものとして照合しない（コマンドの全文・実行時の `cwd`・操作対象を分けて見る）ことが書かれており、`git -C <scratchpad の中の repo> checkout -- .` を worktree から打った場合を許可の対象として扱うことが書かれている

#### Scenario: 許可を書いたら同じ W を再開する

- **WHEN** 同じ段落を読む
- **THEN** 許可を書けたら同じ W を SendMessage で再開すること（再開できるかは decision-criteria「コンテキスト上限（サブエージェントの手渡し）」に従い、できないときは新しい W に転用せずオーナーに上げること）、同じコマンドを 1 文字も変えず 1 回だけ打たせること、新しい W を起こさないことが書かれている

#### Scenario: オーナーに上げる条件が書かれている

- **WHEN** 同じ段落を読む
- **THEN** スクリプトが 0 以外で終わったとき・条件を満たさないとき・再開後に同じ拒否が再び来たとき・再開しない役が報告したときはオーナーに上げることが書かれており、承認されたらオーナーが自分で実行することも書かれている

### Requirement: Orca の印を正本にした既存要件を状態の記録の項目で読み替える

`epic-dispatch.sh` の既存要件のうち、子の状態を Orca のワークツリーのメタデータから読み書きすると書いた箇所は、capability `dev-workflow-epic-state` の状態の記録の項目を読み書きするものとして読まなければならない（MUST）。読み替えは次の表のとおりで、出力の行・exit code・失敗したポーリングの数え方・`--resolve` の判断と送り方・`reap` の安全確認の中身は、表の読み替えのほかは既存要件のまま変えない（MUST）。

| 既存要件の書き方 | 読み替え |
|---|---|
| ボードの列 `workspaceStatus` が `completed`（`mark done`） | 記録の `status` が `done` |
| ボードの列 `workspaceStatus` が `in-review`（`mark waiting`） | 記録の `status` が `waiting` |
| コメント欄 `comment` が `epic-stopped` / `epic-stopped-seen` / `epic-resumed` | 記録の `stop` が `stopped` / `stopped-seen` / `resumed` |
| `orca worktree set --worktree current ...` で印を付ける | 今いるワークツリーのパスで見つけた自分の記録を書き換え、そのあと Orca の印へ写す（写しの失敗は成功扱い） |
| `orca worktree set --worktree path:<子> --comment epic-stopped-seen` で受けた印を付ける | 子の記録の `stop` を排他つきで `stopped-seen` に書き換え、そのあと Orca の印へ写す |
| 一覧の `repoId` が同じ・`linkedIssue` が子・`isArchived` が true でない・`parentWorktreeId` が今のワークツリーのワークツリー | `parent_worktree` が今のワークツリーで `child` が子の記録 |
| 「同じ linkedIssue のワークツリーが 2 つ以上」 | 「同じ親のワークツリー・同じ子の記録が 2 件以上」 |
| ポーリングごとに `orca worktree list --json` を 1 回呼ぶ | ポーリングごとに渡された子の記録を 1 回ずつ読み、`orca worktree list` は呼ばない |
| `route` / `launch` の子の判定に使う `parentWorktreeId` と親のワークツリーの `linkedIssue` | 今いるワークツリーのパスを `worktree` に持つ記録と、その `epic`（環境変数 `EPIC_DISPATCH_PARENT_EPIC` を先に見る規則は変えない） |
| `gh api repos/{owner}/{repo}/issues/<N>` | 記録の `repo` がエピックと同じリポジトリの子と、番号だけで渡した記録の無い子は今のまま。違うリポジトリの子は `gh api repos/<repo>/issues/<N>`、`<owner>/<repo>#<N>` で渡した記録の無い子は引数の `<owner>/<repo>`（小文字）で `gh api repos/<owner>/<repo>/issues/<N>`。`reap` の `gh pr list`・`git ls-remote` などの呼び出しの形は、capability `dev-workflow-epic-state` の要件「親の見張りは記録だけで子の状態を判定する」の `reap` のとおり（同じリポジトリの子は今のまま、別のリポジトリの子は子のリポジトリと子のワークツリーに向ける） |
| `reap` の `kept <N> not-child` | 出さない（親は自分の `parent_worktree` の記録しか見ない。記録の無い子は `gone <N>`） |
| `mark` の「`orca` が PATH に無いか `orca worktree current --json` が非 0 なら `skipped <issue> no-workspace`」と「印の代わりになるもの（ファイルなど）を作ってはならない」 | 今いるワークツリーのパスを `worktree` に持つ記録が無ければ `skipped <issue> no-workspace`。記録は印の代わりではなく正本で、`mark` は記録を作らない（作るのは `launch` と `adopt` だけ）。`orca` の有無は Orca の印へ写すかどうかだけを決める |
| 「Orca が無い環境のための代わりの実装を持ってはならない」 | 状態の記録は Orca の機能の代わりの実装ではない（Orca の有無によらず正本として書く）。記録を読み書きする新しいスクリプト `scripts/epic-state.sh` は `orca` の語を含まず、`orca` をコマンドとして呼ぶスクリプトは Orca の起動部品 `scripts/epic-launch-orca.sh` 1 本だけ（`epic-dispatch.sh` は起動部品を呼ぶ） |
| #1106（PR #1120）の、枠を使っている子を Orca の一覧から数える条件 | 同じ条件を記録の項目に置き換えて数える（capability `dev-workflow-epic-state` の要件「同時に枠を使う子は記録から数える」） |

この読み替えは、少なくとも次の既存要件に掛かる: 「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」（`launch` の記録の書き込みと、`route` の判定）・「エピックの並列起動は 1 段で止める」（子のセッションの判定）・「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」（`mark done` / `waiting`・`wait --watch-done`・`reap`）・「Orca 経路の本体は印が付いた子のワークスペースを片付ける」（`kept <N> not-child` の扱いは起きなくなる。`--watch-done` / `--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わったときの規定は、`wait` が Orca を読まなくなるので、`launch` が exit 1 で子を 1 件も作らなかったときと `adopt` が stdout に何も出さず exit 1 で終わったときの規定として読む）・「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」（記録は代わりの実装に数えない）・「エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ」（`route` の `parentWorktreeId` の判定）・「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」・「epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける」・「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」（子のワークツリーの見つけ方）・「epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける」・「Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る」・「起動し直した親は主の返事待ちの子を主に出し直す」（`pending-owner` は記録の `stop` が `stopped-seen` の子を出す）・「wait --resolve は通す返事を送る前に起動し直すかを表で決める」（子のワークツリーの `path` は記録の `worktree` から読む）、および #1120 がこの capability に足す上限の要件。

既存要件の Scenario のうち、スタブの Orca の一覧の `workspaceStatus` / `comment` を置いて状態を決めているものは、同じ値を記録の `status` / `stop` に置いたものとして確かめなければならない（MUST）。`plugins/dev-workflow/tests/epic-dispatch.bats` の該当するテストは、記録を一時ディレクトリ（`EPIC_STATE_ROOT`）に作って同じ出力を確かめる形に直す。

#### Scenario: 止まった子の受け取りは記録で起きる

- **WHEN** 既存要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」の Scenario のとおり、子 11 が open のまま止まった状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する。ただし止まった状態は記録の `stop` が `stopped` で表し、Orca の一覧の `comment` は空にする
- **THEN** stdout は `stopped 11`、exit 0 で、記録の `stop` は `stopped-seen` になり、`orca worktree list` は呼ばれない

#### Scenario: 片付けの安全確認は今と同じ

- **WHEN** 既存要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の、安全確認を 1 点だけ変えた Scenario を、記録の `status` を `done` にして実行する
- **THEN** stdout は既存の Scenario と同じ `kept 11 <理由>` の行で、ワークツリーは消されず、記録も消されない

#### Scenario: 記録を読み書きするスクリプトは orca の語を含まず、orca のコマンドは起動部品だけが呼ぶ

- **WHEN** `grep -rlw orca plugins/dev-workflow --include='*.sh'` と `grep -rlE '(^|[;&|(!]|(if|then|do|else|while|until) )[[:space:]]*orca [a-z]+' plugins/dev-workflow --include='*.sh'` を実行する
- **THEN** 1 つ目の出力に `plugins/dev-workflow/scripts/epic-state.sh` は無く（`epic-dispatch.sh` と `epic-launch-orca.sh` は `launcher` の値として `orca` の語を含んでよい）、2 つ目の出力は `plugins/dev-workflow/scripts/epic-launch-orca.sh` の 1 行だけである

#### Scenario: 記録の無いワークツリーの mark は記録を作らない

- **WHEN** どの記録の `worktree` とも一致しないワークツリーで `epic-dispatch.sh mark done 11` を実行する
- **THEN** stdout は `skipped 11 no-workspace`、exit 0 で、`EPIC_STATE_ROOT` の下にファイルは増えていない

#### Scenario: 起動し直した親の出し直しは記録で決まる

- **WHEN** 子 11 の記録の `stop` が `stopped-seen`、子 12 が `resumed`、子 13 が `stopped` の状態で `epic-dispatch.sh pending-owner 11 12 13` を実行する
- **THEN** stdout は `pending 11` の 1 行で、`orca worktree list` も `orca worktree set` も呼ばれない

### Requirement: epic.md の回し方は再開時に adopt を呼び、待ちを終えるときに clear を呼ぶ

develop の `references/epic.md`「エピックの扱い」→「回し方」の Orca 経路は、次を書かなければならない（MUST）。

- 手順 7（`回し方: Orca` を引き継いだ再開）は、`reap` より前に、`launch` に渡したことのある子（エピックの状態ディレクトリにある記録の子と、エピックのコメントから分かる子を合わせたもの）で `scripts/epic-dispatch.sh adopt <エピック番号> <子>...` を 1 回呼び、そのあと `reap` → `pending-owner` → `launch` の順に進むと書く。`adopted` / `skipped` / `none` は何もせず、`failed <N> ambiguous` は主に聞かずにその子を残して進み、エピックに `子 #N の記録を取り込めなかった（ambiguous）` と 1 行コメントすると書く。`failed <N> state-unreadable`（その子の記録が読めない）も同じに、止まらずにその子を残して進み、`子 #N の記録を取り込めなかった（state-unreadable）` と 1 行コメントすると書く。理由の無い `failed <N>`（記録を書けなかった）は、stderr を添えて主に報告して止まると書く。`adopt` が stdout に何も出さず exit 1 で終わったら（`orca` が無い・一覧を読めない・origin を読めない）、stderr を添えて主に報告して止まると書く（`failed <N> ambiguous` の行を出して exit 1 で終わったときは止まらない）
- 手順 3・4・7 の「動いている子と片付け待ちの子がどちらも 0 件なら `wait` を呼ばずに待ちを終える」箇所は、待ちを終える前に `scripts/epic-dispatch.sh clear <エピック番号>` を 1 回呼ぶと書く。`cleared` / `none` は何もせず、exit 1 は主に報告すると書く。`clear` は待ちを終えるときに 1 回だけ呼び、エピックを閉じるのを待たない
- 手順 3 の `kept` の扱いのうち「`ambiguous`・`not-child` は対象を特定できないので確かめず残す」から `not-child` を外す（`reap` が出さなくなる）。`kept <N> state-unreadable` は確かめず残し、`子 #N のワークツリーを残した（state-unreadable） — <reap の stderr の記録のパス>` と 1 行コメントすると書く
- 手順 6 の「`--watch-done` か `--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わった（今のワークツリーを Orca から読めない）ときは親ワークツリーで開き直す」は、`wait` が Orca を読まなくなるので消し、`launch` が exit 1 で子を 1 件も作らなかったときと `adopt` が stdout に何も出さず exit 1 で終わったときの報告として書き直す
- 完了条件の節は、エピックの完了時に状態のディレクトリが `clear` で消えていることを、動いている子が無くなったときの報告の前に確かめると書く
- 子の状態の正本は状態の記録で、Orca のボードの列とコメント欄は記録の写しであること、オーナーが Orca の画面で印を手で変えても親の見張りには効かないことを書く
- `references/epic-child-stop.md` の節「エピックの子が主の返事を待って止まるとき」の印の説明は、`mark stopped` / `mark resumed` が自分の記録に印を付け、Orca の画面には写しが出ると書く（子の手順・呼ぶ順序・出力の扱いは変えない）

`references/reply-after-idle.md` のうち、主の返事待ちの子を Orca のコメント欄の `epic-stopped-seen` で見分けると書いた箇所は、記録の `stop` が `stopped-seen` で見分けると書き直さなければならない（MUST）。

この要件の入力は、`adopt`・`clear`・`reap` の出力（`adopted`・`skipped`・`none`・`cleared`・`failed <N> <理由>`・`kept <N> <理由>`、stdout が空の exit 1）である。拾いたい誤りは、`failed <N> ambiguous` や `state-unreadable` で主に聞いて止まること、理由の無い `failed <N>` や stdout が空の exit 1 を無視して進むこと、待ちを終えるときに `clear` を呼ばずに状態のディレクトリを残すことである。次は通してよく、この要件では止めない: `adopted`・`skipped`・`none`・`cleared` で何もせず進むこと／エピックを閉じるのを待たずに `clear` を呼ぶこと／`kept <N> state-unreadable` を確かめずに残すこと。出力の分類の穴が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 手順 7 が adopt から始まる

- **WHEN** `references/epic.md` の回し方の手順 7 を読む
- **THEN** `adopt` を `reap`・`pending-owner`・`launch` より前に呼ぶと書いてあり、`failed <N> ambiguous` と、stdout に何も出さない exit 1 の扱いが書き分けてある

#### Scenario: 待ちを終えるときに clear を呼ぶ

- **WHEN** `references/epic.md` の回し方の手順 3・4・7 のうち、`wait` を呼ばずに待ちを終える箇所を読む
- **THEN** どの箇所も待ちを終える前に `clear <エピック番号>` を 1 回呼ぶと書いてある

#### Scenario: Orca の画面の印は写しだと書いてある

- **WHEN** `references/epic.md`「エピックの扱い」を読む
- **THEN** 子の状態の正本が状態の記録で、Orca の画面の印を手で変えても親の見張りに効かないと書いてある

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

### Requirement: channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない

channel の本体は AskUserQuestion を呼んではならない（MUST NOT）。主に聞くときは、依頼の届いたチャンネル（依頼の発言の開きタグの `chat_id`）にチャンネルの返信ツールで質問を送り、そのターンを終えなければならない（MUST）。依頼がチャンネルから届いていないときは、そのセッションの運用が決める主への連絡先に送り、連絡先が分からなければ記録先に質問をコメントして `needs-approval` を付けて止まる（MUST）。記録に残す問い（保留の依頼・2 周キャップ超え・PR トークン上限）は先に PR か記録先のコメントに書き、チャンネルの質問にそのコメントのフル URL を添える（MUST）。

`skills/develop/references/channel.md` の「channel の聞き方」は、develop と develop から読む文書の「interactive は AskUserQuestion で聞く」を、channel ではこの聞き方に読むと 1 か所に書き、対象の文書（`skills/develop/references/decision-criteria.md`・`skills/develop/references/epic-child-stop.md`・`skills/develop/references/fix-check.md`・`skills/develop/references/roles/spec-reviewer.md`・`skills/develop/references/roles/worker/common.md`・`skills/develop/references/roles/worker/spec.md`・`templates/escalation-tripwires.md`・`commands/develop.md`・`commands/work-issue.md`・`skills/issueify/SKILL.md`）を、`plugins/dev-workflow/` からの相対パスの 1 つの形で挙げなければならない（MUST）。`plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く。`changes/` は変更の記録で、手順として読まれない）で `AskUserQuestion` を含むファイルは、SKILL.md と `skills/develop/references/channel.md` を除いてすべて、`plugins/dev-workflow/` からの相対パスがそのまま（バッククォートで囲んだ形で）この列挙に載っていなければならず（MUST）、bats で確かめる（SHALL。読み替えを 1 か所に書く方式は、列挙が漏れると漏れた文書の本体の手順が AskUserQuestion に流れるため）。`commands/develop.md` は、引数の分岐 ②⑤ の候補の提示と issueify フォールバックの承認が channel ではチャンネルでの質問になることを、その場にも書かなければならない（MUST。入口の分岐で主に聞く場面なので、channel.md の読み替えの規則の例外としてその場にも書く）。

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

### Requirement: channel モードの保留はチャンネルの返事で再開する

channel の本体は、保留の主への案内を「このチャンネルで記録先の番号を添えて返事をすれば続ける（例: `#<記録先> 許容する`）」にしなければならない（MUST）。新しいセッションを開く案内と `/develop <記録先> 許容する` の案内を出してはならない（MUST NOT）。

返事が同じセッションに届いたら、そのセッションで続ける（MUST）。セッションが入れ替わっていたら、`#<番号>` を添えたチャンネルの返事を受けたセッションは、develop を記録先 `<番号>` で起動し（develop の手順を読み込み、本体になる）、その記録先に `引き継ぎ: 主の返事待ち` があることを確かめてから「新しいセッションでの再開」の手順で続ける（MUST）。その手順 2 の「`/develop` の引数の残り」の代わりに、そのチャンネルの返事を会話で受けた回答として扱う（MUST）。新しいセッションが develop を読み込んでいなくても返事を受けて develop を起動できるよう、住人の運用（flatmate の CLAUDE.md など）にこの起動の案内を置くことは、変更の記録（`plugins/dev-workflow/changes/1126.md`）に flatmate 側で要る設定として書く（SHALL）。

リスク許容の返事を保留の解除の G に渡すときは、返事を受けたセッションのセッション ID（`$CLAUDE_CODE_SESSION_ID`）と、そのチャンネルの発言の原文（その返事の行の、開きタグと閉じタグを外した中身。`owner-reply-check.sh` の `MATCH:` 行に出る本文と同じもの）と timestamp を、このセッションの会話ログで主の発言として数えられる行（`<channel source=` で始まる、その返事の行）から取らなければならない（MUST）。本体が要約・書き直した文や、チャンネルのメッセージの別の表示から取ってはならない（MUST NOT。`owner-reply-check.sh` は会話ログの原文と timestamp で照合するため）。番号の無い返事は、このセッションが関わった開いている引き継ぎが 1 件ならそれへの返事として扱い、0 件か 2 件以上なら、記録先の番号を添えて返すようチャンネルで聞き直す（MUST）。

この要件の守備範囲は、オーナーが開けない新しいセッションを案内して保留が解けなくなることを防ぐことである。拾いたい誤りは、channel の案内に新しいセッションや `/develop` の打ち方が出ることと、入れ替わったセッションが返事をどの記録先のものか決められずに止まること。1 時間以上あいてから同じセッションで続けるときのキャッシュの代金は防がない（住人には別の経路が無い）。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 同じセッションに返事が届く

- **WHEN** channel の本体がリスク許容の保留で止まり、主がチャンネルで `#1126 許容する` と返す
- **THEN** 本体は同じセッションで返事を受け、保留の解除の G を起こす前に要件「channel モードのリスク許容はチャンネルの返事を確かめられるときだけチャンネルで受ける」どおりに確かめる

#### Scenario: セッションが入れ替わっていた

- **WHEN** 住人のセッションが再起動され、新しいセッションがチャンネルで `#1126 許容する` を受ける
- **THEN** そのセッションは develop を記録先 #1126 で起動し、最新の引き継ぎを読み、そのチャンネルの返事を手順 2 の回答として「新しいセッションでの再開」の手順で続け、保留の解除の G には会話ログ上のその返事の行の原文と timestamp と、このセッションのセッション ID を渡す

### Requirement: channel モードのリスク許容はチャンネルの返事を確かめられるときだけチャンネルで受ける

channel の本体は、モードを決めた時点でセッションの環境に `OWNER_REPLY_CHANNEL_SENDERS` があるか（空でないか）を確かめ、値を出さずに、develop 開始コメントに `チャンネルの返事の確認: 可` か `チャンネルの返事の確認: 不可（OWNER_REPLY_CHANNEL_SENDERS が無い）` を残さなければならない（MUST）。channel の本体は、G の起動指示に、`実行モード: channel` の行と、開始コメントと同じ値の `チャンネルの返事の確認: 可` / `チャンネルの返事の確認: 不可` の行を書かなければならない（MUST。G の依頼文の書き分けは `dev-workflow-pr-review-gate` の要件「保留処理の依頼文は新しいセッションでの再開を案内する」が正本）。

可のセッションでは、リスク許容のチャンネルの返事を pr-review-gate 手順 5 の「会話で受領」として扱い、`owner-reply-check.sh` で確かめてから保留の解除の G に渡す（MUST。書式と確かめ方は pr-review-gate 手順 5 が正本）。不可のセッションでは、リスク許容の依頼に限り「末尾の PR にコメントで `許容する` と書く」と案内し、PR のフル URL を添える（MUST）。確かめられなかったときの受け直しの案内はチャンネルに送り、「ゲートと同じ PC での `/develop <記録先> 許容する`」の代わりに PR のコメントを案内する（MUST）。リスク許容以外の返事（動作確認の結果・切り出しの確認・方針の選び直し）はチャンネルの返事で進める（MAY）。

この要件の守備範囲は、チャンネルの返事で確かめられないリスク許容を主に頼み、受け直しを重ねることを防ぐことである。拾いたい誤りは、`OWNER_REPLY_CHANNEL_SENDERS` の無い住人にチャンネルで許容を求めること。設定の値が正しいか（主の ID か）は確かめない（`owner-reply-check.sh` が一致しない行を数えないので、合格しない側に倒れる）。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 設定が無い住人

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` の無い channel の本体がリスク許容の保留で止まる
- **THEN** チャンネルに送る依頼の最後の答え方の行は、末尾の PR にコメントで `許容する` と書くことを案内し、PR のフル URL が添えられている

#### Scenario: 設定がある住人

- **WHEN** `OWNER_REPLY_CHANNEL_SENDERS` のある channel の本体がリスク許容の保留で止まる
- **THEN** チャンネルに送る依頼の最後の答え方の行は、このチャンネルで返すことを案内し、返事を受けたら `owner-reply-check.sh` で確かめてから保留の解除の G に渡す

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
| 子を `route`・`launch`・`wait`（位置引数と `--watch-done`）・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt`・`child-log` に渡す | 別のリポジトリの子は `<owner>/<repo>#N` の形で渡す（同じリポジトリの子は番号だけ） |
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
- **THEN** 別のリポジトリの子を `route`・`launch`・`wait`・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt`・`child-log` に `<owner>/<repo>#N` で渡すと書いてある

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

### Requirement: channel モードの主への発言はすべてチャンネルに送り、チャンネルでする操作を答え方の行に書く

channel の本体は、主へのすべての発言を、要件「channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない」と同じ宛先のチャンネルに送らなければならない（MUST）。質問だけでなく、質問ではない報告（再開で HEAD が動いていた・前任 W の手渡し不可・`epic-dispatch.sh` などのスクリプトの失敗・レビューの周の打ち切り・完了報告・エピックの親の報告）も含む。端末に出すだけで済ませてはならない（MUST NOT。住人の画面は誰も見ていないので、端末に出しただけの報告は誰にも読まれず、主の指示を待ったまま止まる）。

それらの発言の 1 行目と最後の行は、`~/.claude/output-styles/readable.md` の節 3 が定める書き分けに従わなければならない（MUST）。主の操作も判断も要らない報告は 1 行目を `主がすること: なし` にする（主の質問への答えは正本のとおり 1 行目に答えを書く）。判断・確認・操作を求める発言は 1 行目を質問にし、最後の答え方の行に、このチャンネルで何を返すか、または末尾の PR に何を書くかを書く（MUST）。PR に書く形のときは、PR のフル URL を添える（MUST）。答え方の行に、チャンネル以外の画面・タブ・入力欄（`子のタブで`・`入力欄で` など）を書いてはならない（MUST NOT）。

この要件の守備範囲は、チャンネルだけを見ている主が、発言から自分の操作を読み取れないことを防ぐことである。拾いたい誤りは 3 つある。主への報告が端末に出るだけでチャンネルに届かないこと。答え方の行が主の見ていない画面を指すこと。主の操作が要るのに答え方の行が無いこと。2 行目以降の説明の良し悪しと、答え方の中身の正しさは、この要件では止めない。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 保留の依頼

- **WHEN** channel の本体が動作確認の保留で主に依頼する
- **THEN** チャンネルに送る発言の 1 行目は質問で、最後の答え方の行に、このチャンネルで何を返せばよいか（例: 「#1126 確認した」）が書かれている

#### Scenario: 完了報告

- **WHEN** channel の本体が PR の合格とマージ待ちを報告し、主の操作が要らない
- **THEN** 1 行目は `主がすること: なし` で、画面やタブを指していない

#### Scenario: 再開で HEAD が動いていた

- **WHEN** channel の本体が新しいセッションでの再開の手順 3 で、引き継ぎの HEAD と PR の今の HEAD が違うと分かる
- **THEN** 本体は差分の報告と続けるかの問いを、1 行目が質問で、最後の答え方の行がこのチャンネルで返すことを案内する発言としてチャンネルに送り、端末に出すだけで済ませない

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

#### Scenario: epic.md の経路の決め方に orca になる条件としての件数の下限が書かれていない
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

### Requirement: Orca 経路の既存要件は別セッション方式の共通手順として読み、部品固有の操作は部品ごとに決める

develop の既存要件のうち見出しや本文が「Orca 経路」「`回し方: Orca`」と書いているものは、起動部品が Orca でも tmux でも掛かる別セッション方式の共通手順として読まなければならない（MUST）。対象の要件は、「Orca 経路の本体は印が付いた子のワークスペースを片付ける」・「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」・「Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける」・「Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る」・「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の 5 つと、これらを参照する SKILL.md の記述である。共通手順（`--watch-done`・`--watch-stopped` を付けた `wait`、`done` で起こされたら `reap`、`stopped` の解決、`kept` の確認、マージ待ちの判断、完了の促し、再開時の `reap`）は、部品によらず同じに行い、状態は記録から読む（要件「Orca の印を正本にした既存要件を状態の記録の項目で読み替える」のとおり）。次の点だけが部品で違う。

| 既存要件の書き方 | Orca の部品 | tmux の部品 |
|---|---|---|
| `回し方: Orca` を引き継いで再開したら `launch` の前に `reap` を 1 回呼ぶ | 同じ | `回し方: tmux` でも同じに行う。`reap` は記録の `launcher` が `tmux` の子に tmux の部品の `close`・`remove` を使う |
| `kept <N> <理由>` を本体が確かめたあとで消す操作 `orca worktree rm --worktree path:<path>`（`--force` なし） | 既存のまま | `bash <epic-dispatch.sh と同じディレクトリ>/epic-launch-tmux.sh remove <path>`（`git worktree remove`。`--force` なし）。確かめる 2 点 (a)(b) と、残すときのコメント、`ambiguous`・`close-failed` で消さない扱いは同じ |
| `--watch-done`・`--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わったら Orca の親ワークツリーで開き直すよう報告する | 同じ（`not in an Orca-managed worktree` など） | 該当しない（`wait` は記録だけを読む）。stdout に何も出さず exit 1 でも、stderr が `usage:` を含むなら設定の誤りとして報告して止まる |
| 止まった子への `reply`・完了を促す返事 | `orca terminal` で端末へ送る | tmux の部品の `deliver`（`send-keys -l`。シェルだけのペインには送らない） |

この要件の守備範囲で入力として扱うのは、各既存要件が扱う入力（`reap` の `kept` の行、記録、`gh`・`git` の出力）と、記録の `launcher` の値である。拾いたい誤りは、tmux の子に `orca worktree rm` を打って失敗すること、部品の違う子の片付けを取り違えること、tmux の記録の子に Orca の親ワークツリーでの開き直しを案内することである。既存要件の中身（消す条件・残す条件）は変えず、すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。次は通してよく、この要件では止めない: Orca の子と tmux の子が混在するエピック（子ごとに記録の `launcher` の部品の操作で片付ける）／tmux の部品に画面への写し（`mirror`）が無いこと。

#### Scenario: tmux の子の kept は tmux の部品の remove で消す
- **WHEN** `回し方: tmux` のエピックで、`reap` が `kept 12 branch-open` を返した子 12 について、本体が (a)(b) を満たすと確かめた
- **THEN** 本体は `orca` を呼ばず、`epic-launch-tmux.sh remove <path>` を `--force` なしで呼び、エピックに `子 #12 のワークツリーを確かめて消した（<理由>）` とコメントして、その子を片付け待ちから外す

#### Scenario: Orca の子の kept は今までどおり orca worktree rm で消す
- **WHEN** `回し方: Orca` のエピックで、同じ条件を満たした
- **THEN** 本体は `orca worktree rm --worktree path:<path>`（`--force` なし）で消す

#### Scenario: tmux の記録の子は Orca の親ワークツリーでの開き直しを案内されない
- **WHEN** `回し方: tmux` のエピックで `wait --watch-stopped` が stdout に何も出さず exit 1 で終わる（stderr に `usage:` は無い）
- **THEN** 本体は Orca の親ワークツリーで開き直すよう案内せず、stderr を添えて主に報告して止まる

### Requirement: epic-dispatch.sh wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する

`plugins/dev-workflow/scripts/epic-dispatch.sh` の `wait` は、`--watch-done <N>` で渡された子ごとに、ポーリングごとに次の 6 つをこの順に確かめ、すべて満たした子の完了を推定しなければならない（MUST）。LLM を呼んではならない（MUST NOT）。

1. 親の見張りの照合で子の記録がちょうど 1 件読め、`status` が `running` である（`waiting`・`done` は推定しない）
2. 記録の `stop` が `stopped` でも `stopped-seen` でもない
3. 記録の `worktree` が空でなく、子のトランスクリプト（`${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}/<worktree の英数字以外を - にした名前>/*.jsonl`。置き場のディレクトリは `wait --resolve` の起動し直しの判定と同じ求め方で、置き場を求める処理は 1 つの関数を共有する（既定の置き場の変更は起動し直しの判定にも掛かる）。起動し直しの判定の「ちょうど 1 本」はその判定の側に残す）が 1 本以上ある
4. 置き場の全部の `.jsonl` と、そのセッションのサブエージェントのトランスクリプト（`<置き場>/<セッション>/subagents/*.jsonl`）を通して、`timestamp` を持つ行（種類を問わない）の最大値を最後の活動とし、今の時刻との差が `EPIC_DISPATCH_DONE_IDLE_SEC`（秒・既定 1800）以上である。`timestamp` を持つ行が 1 つも無い・読めない・`python3` が無いときは満たさない
5. 子 issue を、位置引数の子と同じ `gh` の呼び出しの形（記録の `repo` で決まる `issue_api`）で 1 回読み、`state` が `closed` で `state_reason` が `completed` である
6. 5 と同じ 1 回の `gh` で読んだ `closed_at` と今の時刻との差が `EPIC_DISPATCH_DONE_IDLE_SEC` 以上である。`closed_at` が無いときは満たさない（記録先が閉じた直後に、閉じる前から長く動いている背景のコマンドだけを走らせている子を完了としないため）

1〜4 のどれかを満たさない子について `gh` を呼んではならない（MUST NOT）。5・6 の `gh`（1 回）が失敗したときは、そのポーリングではその子を推定せず、失敗したポーリングにも数えない（MUST）。すべて満たした子は、要件「wait --watch-done は推定した完了を記録に書き、Orca の印へ写す」（dev-workflow-epic-state）のとおり記録に書き、書けたら stderr に `inferred done <N>: issue closed as completed, no transcript activity since <最後の活動>` を出し、印が付いた子として `done <N>...` の行に入れなければならない（MUST）。stdout の行の形・順・exit code は今の `--watch-done` の規定のまま変えてはならない（MUST NOT。推定の `done` を別の行にしない）。

`--watch-done` が 1 つ以上ある `wait` は、ポーリングを始める前に `EPIC_DISPATCH_DONE_IDLE_SEC` を確かめ、空か数字でなければ stderr に理由と使い方を出して exit 1 で終わり、`gh` を呼んではならない（MUST）。

この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」と要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」の「ポーリング 1 回あたりの `gh` の呼び出しは位置引数の子の数と同じ」の規定に優先し、推定の候補（1〜4 を満たした `--watch-done` の子）1 件ごとに `gh` の呼び出しが 1 回増えることを許す。

`plugins/dev-workflow/scripts/epic-dispatch.sh` の冒頭のコメントの `wait` の説明に、推定の 6 つの条件・`EPIC_DISPATCH_DONE_IDLE_SEC` とその既定・推定の `done` が同じ `done <N>` の行に出ることを書かなければならない（MUST）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、偽の `gh` とテスト用の `CLAUDE_PROJECTS_DIR` で、次を確かめなければならない（MUST）: 6 つを満たすと stdout が `done <N>` で記録の `status` が `done` になり推定の項目が付くこと／最後の活動が閾値より新しい・トランスクリプトが 0 本・2 本のうち片方だけ新しい・`status` が `waiting`・`stop` が `stopped` / `stopped-seen` のときは `gh` を呼ばずに推定しないこと／2 本とも古ければ推定すること／issue が `open`・`state_reason` が `completed` でない・閉じてから閾値より短い・`closed_at` が無いときは推定しないこと／サブエージェントのトランスクリプトにだけ閾値より新しい行があるときは推定しないこと／排他の中の確かめ直しで外れたとき（推定の `gh` の間に子が `waiting` を付けた）は推定せず Orca の印へ写さないこと／`EPIC_DISPATCH_DONE_IDLE_SEC` で閾値を変えられ、数字でない値は exit 1 で `gh` を呼ばないこと／同じ子を位置引数と `--watch-done` の両方に渡したとき、閉じたポーリングで `closed <N>` と `done <N>` の 2 行がこの順に出ること。

この要件の守備範囲で入力として扱うのは、記録の `status`・`stop`・`worktree`、子のトランスクリプト（サブエージェントのものを含む）の `timestamp`、子 issue の `state` と `state_reason` と `closed_at` である。拾いたい誤りは、主がマージして記録先が閉じたのに子が印を付けず親が待ち続けることと、まだ動いている子・主の確認待ちの印（`waiting`）を付けた子・止まった印の経路にいる子を完了とすることである。次は通ってよく、この要件では止めない: 主が閾値より長く子のタブを離れてから同じタブで追加の作業を頼もうとしたときにワークツリーが片付いていること（`reap` の確認が未コミットの変更とマージに入っていない commit を残す）／時計のずれで最後の活動が未来になり推定されないこと／記録先が閉じたあと、子が 1 回のツール呼び出しを閾値より長く動かしている（その間トランスクリプトに行が増えない）ときに推定されること（`reap` の確認は変えないので、失うのは後片付けの途中だけ）／マージ後の依頼（動作確認など）を完了報告に書いてマージを主に頼んだ子も、PR が未マージのうちは `waiting` を付けられないので推定され、主の返事の前にタブが閉じること（依頼は完了報告と記録先に残る）。この要件は、ここに挙げていない穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: 閉じて動きの止まった子は完了と推定される
- **WHEN** 子 11 の記録が `status` `running`・`stop` 空、トランスクリプトが 1 本で最後の活動が 40 分前、子 issue が `closed`・`completed` の状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** stdout は `done 11`、exit 0 で、記録の `status` は `done`、`done_inferred_at` と `done_inferred_last_activity` があり、stderr に `inferred done 11` で始まる行が出る

#### Scenario: 最後の活動が新しい子は推定しない
- **WHEN** 最後の活動が 10 分前で、ほかは直前の Scenario と同じ状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、exit 2 で、記録の `status` は `running` のまま、`gh` は呼ばれない

#### Scenario: トランスクリプトが 0 本なら推定しない
- **WHEN** 子 11 のトランスクリプトの置き場に `.jsonl` が無い状態で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま、`gh` は呼ばれない

#### Scenario: トランスクリプトが 2 本なら全部を通した最後の活動で決める
- **WHEN** 子 11 のトランスクリプトの置き場に `.jsonl` が 2 本あり、片方の最後の活動が 40 分前でもう片方が 10 分前の状態で `wait --interval 0 --timeout 0 --watch-done 11` を実行し、別に 2 本とも最後の活動が 40 分前より古い状態で `wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 前者は stdout が `timeout`、記録の `status` は `running` のまま、`gh` は呼ばれない。後者は stdout が `done 11` で、`done_inferred_last_activity` は 2 本を通した最大の `timestamp` である

#### Scenario: 閉じてから閾値より短い子は推定しない
- **WHEN** 子 11 の issue が `completed` で閉じてから 60 秒、または `closed_at` が無い状態で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま

#### Scenario: サブエージェントのトランスクリプトの新しい行も活動に数える
- **WHEN** 子 11 の本体のトランスクリプトの最後の活動は 40 分前で、`<置き場>/<セッション>/subagents/` の `.jsonl` に 10 分前の行がある状態で `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま、`gh` は呼ばれない

#### Scenario: 同じ子が位置引数と --watch-done の両方にあれば closed と done の 2 行を出す
- **WHEN** 子 11 を位置引数と `--watch-done` の両方に渡し、推定される条件のまま `wait --interval 0 --timeout 60 --watch-done 11 11` を実行する
- **THEN** stdout は `closed 11` と `done 11` の 2 行をこの順に出して exit 0 で、記録の `status` は `done` である

#### Scenario: waiting の子と止まった印の子は推定しない
- **WHEN** 子 11 の記録の `status` が `waiting`、または `stop` が `stopped` か `stopped-seen` で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録は変わらず、`gh` は呼ばれない

#### Scenario: 開いている子・completed 以外で閉じた子は推定しない
- **WHEN** 子 11 の issue が `open`、または `closed` で `state_reason` が `not_planned` で、ほかは推定される条件のまま `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `running` のまま

#### Scenario: 閾値を変えられ、誤った値は使い方を出す
- **WHEN** 最後の活動が 10 分前の子 11 で `EPIC_DISPATCH_DONE_IDLE_SEC=300` を付けて `wait --interval 0 --timeout 60 --watch-done 11` を実行し、別に `EPIC_DISPATCH_DONE_IDLE_SEC=abc` を付けて同じコマンドを実行する
- **THEN** 前者は stdout が `done 11` で、後者は exit 1 で stdout は空、stderr に使い方が出て `gh` は呼ばれない

### Requirement: 回し方の手順は推定した done も子の付けた done と同じに片付ける

develop の `references/epic.md`「エピックの扱い」→「回し方」の別セッション方式の手順は、次を書かなければならない（MUST）。

- 手順 2 の `--watch-done` の説明に、`wait` は片付け待ちの子のうち、完了の印の無いまま記録先が `completed` で閉じてから `EPIC_DISPATCH_DONE_IDLE_SEC`（既定 1800 秒）以上たち、子のトランスクリプト（サブエージェントのものを含む）の最後の活動もそれ以上前の子を、LLM なしで完了と推定して `done <N>` を返すこと（`status` が `waiting` の子・止まった印の子・トランスクリプトが無い子は推定しない）
- 手順 3 に、推定の `done` も子が付けた `done` と同じに `reap` を 1 回呼んで扱い、区別しないこと（片付けの安全確認は `reap` が行う）。同じ子が `closed` と `done` の両方の行に出たら、手順 4 を処理してから手順 3 の `reap` を呼ぶこと
- 手順 4 に、`notify-closed` が `skipped <N> not-stopped` を返した子（止まった印を付けずに見張りを終えた子。主に直接マージを頼んだ子など）は、片付け待ちとして `--watch-done` に渡しておけば、子のセッションが止まって閾値を過ぎたあとの `wait` が完了と推定すること。主に子のステータスを変えるよう頼まない（MUST NOT）

`plugins/dev-workflow/tests/epic-dispatch.bats`（または `tests/develop-skill.bats`）は、手順 2〜4 の文面に `EPIC_DISPATCH_DONE_IDLE_SEC` と推定の扱いがあることを確かめなければならない（MUST）。

この要件の入力は、`wait` が返す `done <N>` と `closed <N>` の行、`notify-closed` が返す `skipped <N> not-stopped` である。拾いたい誤りは、推定の `done` を子の付けた `done` と区別して片付けを飛ばすこと、`skipped <N> not-stopped` の子について主にステータスを変えるよう頼むことである。次は通してよく、この要件では止めない: 推定の `done` を渡した `reap` が `kept` を返し、本体が確かめて残すこと（安全確認は `reap` が行う）／`status` が `waiting` の子やトランスクリプトの無い子が推定されないこと。推定の条件の細部の食い違いを見つけるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 回し方に推定の扱いが書かれている
- **WHEN** `references/epic.md` の「エピックの扱い」の「回し方」の手順 2〜4 を読む
- **THEN** 手順 2 に `wait` が完了を推定する条件と `EPIC_DISPATCH_DONE_IDLE_SEC` が、手順 3 に推定の `done` も同じに `reap` することと、同じ子が `closed` と `done` の両方に出たら手順 4 を処理してから `reap` を呼ぶことが、手順 4 に `skipped <N> not-stopped` の子は `--watch-done` の推定で片付くことが書かれている

### Requirement: エピックの子は主にマージを頼むとき、マージ後の連絡を頼まない

develop の `SKILL.md`「ループの終わり」は、エピックの子（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested`）が PR のマージを主に頼んで（PR がマージされていないので `mark` を呼ばずに）ループを終えるとき、完了報告で「マージしたら教えてください」「ステータスを変えます」のような、マージ後に子のタブへ戻る連絡を主に頼んではならない（MUST NOT）と書き、代わりに「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くことを規定しなければならない（MUST）。親の `wait --watch-done` が完了を推定することを理由として添える（SHALL）。エピックの子でないセッションの完了報告には、この規定を当てない。

#### Scenario: ループの終わりにマージ後の連絡を頼まない規定がある
- **WHEN** SKILL.md の「ループの終わり」を読む
- **THEN** エピックの子が主にマージを頼んで終えるとき、マージ後の連絡を頼まず「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くことと、その理由（親の `wait` が完了を推定する）が書かれている

### Requirement: エピックの親は子 1 件あたりの PR トークンの権限をエピックのコメントに置く
エピックの親は、子 1 件あたりの PR トークンの権限を、エピックの issue の 1 行目が `子の PR トークン権限: <値>`（数字だけ。既定 60000000）のコメントに置かなければならない（MUST）。投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` の最新の 1 件を正とする（MUST）。主が広げたら、親が新しい値で投稿し直し、2 行目に `主の発言: <要旨>` を書く（MUST）。親の判断で広げてはならない（MUST NOT）。止まる上限（既定 30000000）は変えない（MUST NOT）。手順は `references/epic.md` に書く。

#### Scenario: 主が広げた権限を記録する
- **WHEN** 主が「1 億まで増やしていい」と言う
- **THEN** 親はエピックに 1 行目 `子の PR トークン権限: 100000000`、2 行目 `主の発言:` で始まる行のコメントを投稿し、以後この値を正とする

### Requirement: 親は権限のコメントが無ければ既定値で投稿して主に伝える
エピックの親は、次の 4 つの機会に、権限のコメントが無ければ既定値で投稿しなければならない（MUST）。最初の開始時（`回し方:` を残すとき）、エピックを再開したとき（手順 7）、手順 8 で PR トークン上限の止まりを扱うとき（照らす前）、サブエージェント方式の本体が子の記録先の exit 2 で照らすとき（照らす前）。投稿したら、interactive と channel では主に「子 1 件 6,000 万トークンで回す。広げたければ声をかけて」と伝える（MUST）。unmanned ではコメントだけを残す。

#### Scenario: 起動時に権限を置いて主に伝える
- **WHEN** interactive で `/develop <エピック番号>` を最初に始め、経路を決める
- **THEN** 親はエピックに 1 行目 `子の PR トークン権限: 60000000` のコメントを投稿し、主に「子 1 件 6,000 万トークンで回す。広げたければ声をかけて」と伝える

#### Scenario: 変更の前に起動したエピックの止まりを扱う
- **WHEN** 権限のコメントの無いエピックで、手順 8 の親が PR トークン上限の止まりを扱う
- **THEN** 親は既定値で `子の PR トークン権限: 60000000` を投稿して主に伝えてから、その値で照らす

### Requirement: エピックの子は PR トークン上限で止まるとき見込みを記録に書く
別セッション方式のエピックの子が PR トークン上限の exit 2 で止まるときは、停止の記録の `止まった理由:` を `PR トークン上限（合計 <合計> / 上限 <上限>）` で始めなければならない（MUST）。`前提:` の値の中に `終わるまでの見込み: あと約 <残り>（合計の見込み <見込み>）`・`続けるべきか: <理由つき>`・`次に絞る範囲: <残工程のうち何に絞るか>` の 3 行を書く（MUST）。記録の 7 項目の形と項目名は変えない。手順は `references/epic-child-stop.md` に書く。

#### Scenario: 記録に見込みの 3 行がある
- **WHEN** エピックの子が合計 31000000・上限 30000000 で止まる
- **THEN** 記録の `止まった理由:` は `PR トークン上限（合計 31000000 / 上限 30000000）` で始まり、`前提:` に `終わるまでの見込み:`・`続けるべきか:`・`次に絞る範囲:` の行がある

### Requirement: 親は PR トークン上限の止まりを権限に照らして続けさせる
起こされた親（`references/epic.md` 手順 8）は、`止まった理由:` が `PR トークン上限（` で始まる止まりを、`parent-pass-criteria.md` に照らし直さず権限に照らさなければならない（MUST）。通すのは、(a) 合計の見込みが権限以下、かつ (b) 記録の上限が権限より小さい、の両方を満たすときだけとする（MUST）。見込みが読めない、または投稿者の条件を満たす権限のコメントの値が数字として読めないときは主に上げる（MUST）。通すときは新しい上限を権限にして `reply --as parent` で送り、エピックに `親の判断: 子 #N 通した` を残す（MUST）。

守備範囲: 入力は権限のコメントと子の停止の記録（投稿者が OWNER・MEMBER・COLLABORATOR のもの）。拾いたい誤りは、権限を超える見込みと、権限に達して再び止まった子を通すこと。見込みが外れることと、判断のモデルがこの止まりを主に上げることは止めない。見込みの正しさの検査は完了条件としない。

#### Scenario: 見込みが権限の内なら親が続けさせる
- **WHEN** 記録が `PR トークン上限（合計 31000000 / 上限 30000000）` で、合計の見込みが 45000000、最新の権限が 60000000
- **THEN** 親は基準に照らし直さず `reply --as parent` で `続ける。新しい上限 60000000（親の権限。<権限のコメントの URL>）` を送り、エピックに `親の判断: 子 #N 通した — PR トークン上限を親の権限 60000000 まで上げた（合計の見込み 45000000） <URL>` を残す

#### Scenario: 権限に達して再び止まった子は主に上がる
- **WHEN** 上限 60000000 に上げた子が合計 60200000 で再び止まり、権限が 60000000
- **THEN** (b) を満たさないので、親は通さず主に上げる

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

### Requirement: 親が通してよい範囲の基準は、CI の見張りのやり直しの上限で止まった子の扱いを決める
`parent-pass-criteria.md` は、表でなく文章の節で、CI の見張りのやり直しの上限で止まった子を親が通すか主に上げるかを一通りに決めなければならない（MUST。条件表の 9 条件は増やさない。対象・通す場合・主に上げる場合・返事・同じ件の定義は下の場面で定める）。

この要件の守備範囲で入力として扱うのは、`stop-judge.sh` が集める子の最新の停止の記録と過去の `親の判断:`、および手順 8 で親のセッションが読む同じ記録である。拾いたい誤りは、差分に起因する失敗のやり直しを通し続けること、`job-timeout`・ランナーの確認を含む止まりを通すこと、やり直しの回数を使い切っただけの止まりを主に上げることの 3 つである。次は通ってよい: 子が差分に起因する失敗を「因果を持たない」と書き誤った記録を通すこと（損失は CI 1 周分で、再び止まれば次は主に上がる）／通してよい止まりを判断のモデルが主に上げること。すり抜けを塞ぎ切ることは完了条件としない。

#### Scenario: 基準のファイルが対象の止まりを子の停止の記録から見分けられる形で定めている
- **WHEN** `parent-pass-criteria.md` の CI の見張りのやり直しの上限の節を読む
- **THEN** 対象は、同じ HEAD のやり直しを使い切って見張りがやり直せないことが、記録のどの項目に書かれていても（`止まった理由:` は主にしてほしいことを書く欄なので、`前提:` などに書かれやすい）挙げている止まりで、`job-timeout` の `escalate`（落ちたチェックに `real` が混ざらず `job-timeout` を含むときの `escalate`）は記録にそう書かれていなくても常に対象とする（`pr-state.sh` の `decide` は、その場合に同じ HEAD のやり直しを使い切ったあとで返すため）。経路は `job-timeout` を含む失敗の `escalate` と `ci-watch.md` 7 の手順 7 で上げたものの 2 つ、修正回数の上限（3 回目の失敗）の `escalate` は対象外と書かれている

#### Scenario: 基準のファイルが通す場合と主に上げる場合を決めている
- **WHEN** 同じ節を読む
- **THEN** 手順 7 で上げた止まりは、9 条件に加えて失敗が差分と因果を持たない・推奨が再実行だけ・`cause` が `job-timeout` でない、のすべてを満たすとき通し、`job-timeout` の `escalate`・判断できないとき・確認してからの再実行は主に上げると書かれている

#### Scenario: 基準のファイルが返事の中身を決めている
- **WHEN** 同じ節を読む
- **THEN** 返事は、まず `ci-watch.md` 2 の重複の確認をし（別のセッションが見張り中なら何もせずに主に伝える）、落ちたチェックを同じ HEAD で 1 回だけ手でやり直し、次に、止まるときに付けた `needs-approval` を外すこと（手順 7 の経路で止まった子。付けたままだとやり直しが通ったあと見張りが待たずにオーナーへマージを頼んで終わるため。ただし外す前に PR の events で、最後の `needs-approval` の labeled が止まる前の最新の `CI 見張り開始:` のコメントより前なら、子が付けたものではないので外さず主に上げる）と、`CI 見張り開始:` の投稿をすること（開始の記録なしに始めると別のセッションが見張りを重ねうるため）を済ませ、そのうえで `ci-watch.md` 2 の `escalate` のあとの再開手順で見張りに戻ってよい、という内容で、`ci-watch.md` は変えないと書かれている。通すときの `理由:`（`親の判断: 子 #N 通した — <理由> <記録の URL>` の `<理由>` になる）には、PR 番号・落ちたチェック名・HEAD の短い SHA を、子の停止の記録から取って書くと定められている。記録に無い値は作らず `不明` と書き、HEAD が `不明` の過去の判断とは同じ件かを見分けられないものとして扱う（次の判断が、過去の `親の判断:` と同じ件かを見分けるため）

#### Scenario: 基準のファイルが「繰り返していない」との関係を決めている
- **WHEN** 同じ節を読む
- **THEN** 見張りの上限と「繰り返していない」が別の歯止めであること、同じ件は同じ PR の同じチェックで HEAD が変われば別の件であること、同じ HEAD で許したあとにまた止まった同じ件は主に上げること、条件表が 9 条件のままであることが書かれている

### Requirement: コンパクト直後に develop を呼んでいた会話へ SKILL.md の読み直しを差し込む hook を登録する
`plugins/dev-workflow/hooks/hooks.json` は、SessionStart に matcher `compact` のエントリを置き、`${CLAUDE_PLUGIN_ROOT}/scripts/develop-compact-reread.sh` を呼ぶ command を登録しなければならない（MUST）。スクリプトは stdin の JSON の `source` が `compact` のときだけ働き、それ以外（`startup`・`clear`・`resume`・空・`source` が無い）では、会話で develop を呼んでいても何も出さずに exit 0 で終わらなければならない（MUST）。

#### Scenario: hooks.json が compact の SessionStart に登録している
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` の `hooks.SessionStart` を読む
- **THEN** matcher を `|` で区切った値に `compact` を含み、`develop-compact-reread.sh` を呼ぶ command を持つエントリがある

#### Scenario: compact 以外の起動では何も出さない
- **WHEN** 会話記録に `dev-workflow:develop` の Skill 呼び出しがあり、`source` が `startup`・`clear`・`resume`・空文字のいずれかの入力でスクリプトを実行する
- **THEN** stdout は空で exit 0

### Requirement: develop を呼んでいたかはコンパクト前の 3 種類の記録で判定する
スクリプトは stdin の `transcript_path` が指す会話記録（jsonl）を 1 行ずつ読み、次のどれかが 1 つあれば「develop を呼んでいた」とみなさなければならない（MUST）。(a) `type` が `assistant` の行の `message.content` にある `type: tool_use`・`name: Skill` のブロックで、`input.skill` が `dev-workflow:develop`。(b) `type` が `user` の行の `message.content` が文字列か、一覧の `type: text` のブロックの `text` で、`<command-name>/dev-workflow:develop</command-name>` を含む。(c) `type` が `attachment` の行の `attachment.type` が `invoked_skills` で、`skills` の要素の `name` が `dev-workflow:develop`。

#### Scenario: Skill 呼び出しで数える
- **WHEN** 会話記録に `input.skill` が `dev-workflow:develop` の Skill の tool_use があり、`source: compact` で実行する
- **THEN** 読み直しの文を差し込む

#### Scenario: 文字列の user の発言のコマンドで数える
- **WHEN** 会話記録の user の行の `message.content` が `<command-name>/dev-workflow:develop</command-name>` を含む文字列で、`source: compact` で実行する
- **THEN** 読み直しの文を差し込む

#### Scenario: 一覧の user の発言の text のブロックのコマンドで数える
- **WHEN** user の行の `message.content` が一覧で、画像のブロックのあとの text のブロックが `<command-name>/dev-workflow:develop</command-name>` を含み、`source: compact` で実行する
- **THEN** 読み直しの文を差し込む

#### Scenario: 前のコンパクトのあとの invoked_skills で数える
- **WHEN** 会話記録に `compact_boundary` の行と、`skills` に `name: dev-workflow:develop` を持つ `invoked_skills` の attachment の行があり、`source: compact` で実行する
- **THEN** 読み直しの文を差し込む

### Requirement: 名前空間の無い develop・別のスキル・文中の言及は数えない
スクリプトは、上の 3 種類の記録の形と名前 `dev-workflow:develop` に完全に一致するものだけを数えなければならない（MUST）。次は数えてはならない（MUST NOT）: 名前空間の無い `develop`（Skill の `input.skill`・`<command-name>/develop</command-name>`・`invoked_skills` の `name`）、名前に develop を含む別のスキルやコマンド（`dev-workflow:codex-develop`・`/dev-workflow:develop-epic` など）、assistant の text のブロックや tool_result の中身で名前に触れただけのもの。develop を呼んでいない会話では何も出さない（MUST）。

#### Scenario: 名前空間の無い develop は数えない
- **WHEN** 会話記録に `input.skill` が `develop` の Skill 呼び出し、`<command-name>/develop</command-name>` の user の発言、`name: develop` の `invoked_skills` だけがあり、`source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: 名前に develop を含む別のスキルは数えない
- **WHEN** 会話記録に `dev-workflow:codex-develop` の Skill 呼び出しと `<command-name>/dev-workflow:develop-epic</command-name>` の user の発言だけがあり、`source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: 文中や tool_result で触れただけなら数えない
- **WHEN** 会話記録に、assistant の text のブロックと user の tool_result の中身に `dev-workflow:develop` や `<command-name>/dev-workflow:develop</command-name>` が書かれた行だけがあり、`source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: develop を呼んでいない会話では何も出さない
- **WHEN** 会話記録に普通の user の発言と `probe:hello` の Skill 呼び出しだけがあり、`source: compact` で実行する
- **THEN** stdout は空で exit 0

### Requirement: develop を呼んでいたかの判定の守備範囲
要件「develop を呼んでいたかはコンパクト前の 3 種類の記録で判定する」と「名前空間の無い develop・別のスキル・文中の言及は数えない」の判定は、次の範囲を超える保証をしてはならない（MUST NOT）。入力として扱うのは、Claude Code が SessionStart(compact) の hook に渡す stdin の JSON と、その `transcript_path` が指す会話記録（Claude Code が書く jsonl。この時点ではコンパクト前の記録だけ）である。拾いたい誤りは、develop を呼んでいた会話でコンパクトのあと SKILL.md を読み直さず要約の上で進むこと（差し込み漏れ）と、名前空間の無い `develop`・別のスキル・文中の言及で、呼んでいない会話に差し込むことである。通してよく、この判定では止めない入力は下の Scenario に挙げる。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: 呼び終えたあと別の作業をしていても毎回差し込む
- **WHEN** develop を呼び終えたあと、同じ会話で develop と関係のない作業を続け、コンパクトが 2 回走る
- **THEN** どちらのコンパクトのあとも読み直しの文を差し込む。この判定では止めない

#### Scenario: 手で打ったコマンドの文字列は呼び出しとして数える
- **WHEN** user が `<command-name>/dev-workflow:develop</command-name>` の文字列を手で打った発言だけがある会話で、`source: compact` で実行する
- **THEN** 呼び出しとして数え、読み直しの文を差し込む。この判定では止めない

#### Scenario: SKILL.md を Read で読んだだけの会話は数えない
- **WHEN** Skill もコマンドも使わず、SKILL.md を Read ツールで読んだだけの会話で、`source: compact` で実行する
- **THEN** 数えず、何も出さない。この判定では止めない

#### Scenario: 会話記録の形が変わって判定が外れても止めない
- **WHEN** Claude Code の更新で会話記録の形が変わり、3 種類の記録のどれにも当たらなくなった会話で、`source: compact` で実行する
- **THEN** 何も出さずに exit 0 で終わる（fail-open）。この判定では止めない

### Requirement: 差し込む文は SKILL.md の読み直しと親か子かの確かめ直しを求める
develop を呼んでいたと判定したとき、スクリプトは stdout に `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<文>"}}` の形の JSON を 1 つ出さなければならない（MUST）。`<文>` は次の 2 つの要素を含まなければならない（MUST）。(1) `${CLAUDE_PLUGIN_ROOT}/skills/develop/SKILL.md` の絶対パスを示し、それを Read ツールで offset と limit を使って分けて読み直すこと。(2) 自分がエピックの親か子かを記録先の issue から確かめ直してから続けること。

#### Scenario: 差し込む文が 2 つの要素を含む
- **WHEN** develop を呼んでいた会話記録で `source: compact` で実行する
- **THEN** exit 0 で、stdout の JSON の `hookSpecificOutput.hookEventName` が `SessionStart`、`additionalContext` が `<CLAUDE_PLUGIN_ROOT>/skills/develop/SKILL.md`・`offset`・`limit`・`親`・`子`・`記録先` を含む

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

### Requirement: hook の振る舞いを bats で確かめる
`plugins/dev-workflow/tests/develop-compact-reread.bats` は、要件「コンパクト直後に develop を呼んでいた会話へ SKILL.md の読み直しを差し込む hook を登録する」「develop を呼んでいたかはコンパクト前の 3 種類の記録で判定する」「名前空間の無い develop・別のスキル・文中の言及は数えない」「差し込む文は SKILL.md の読み直しと親か子かの確かめ直しを求める」「判定できないときは何も出さず、セッションの開始を止めない」の各 Scenario を確かめなければならない（MUST）。会話記録を使う Scenario は、偽の会話記録（fixture は SessionStart(compact) の時点の実機の形。今回のコンパクトの `compact_boundary` と `invoked_skills` はまだ無い）で確かめる。

#### Scenario: bats が通る
- **WHEN** `bats plugins/dev-workflow/tests/develop-compact-reread.bats` を実行する
- **THEN** 全件が通る

### Requirement: G の needs-carryover-judge を受けた本体の動き

`skills/develop/SKILL.md` の 1 ループの (4) は、G の Status `needs-carryover-judge` を受けた本体の動きを書かなければならない（MUST）: 本体は PR トークン上限を測ってから、pr-review-gate の `stages/hold.md` 手順 3-c の依頼の書き方で `subagent_type: dev-workflow:decider`・`model: opus` の判定役を起こし、判定の記録を PR に代理投稿し、判定と記録の URL を渡して合格処理の G を新しく起こさなければならない（MUST）。`SHARED_BUDGET_MODE=depleted` のときは判定役を起こさず、3-c の書式の `引き継ぎ判定: 判断できない` の記録を投稿して同じく合格処理の G を起こす（MUST）。本体は判定を受けて自分で宣言を投稿したり、ラベルを付けたり、主に聞いたりしてはならない（MUST NOT。引き継ぐか主に聞くかは合格処理の G が決める）。ただし、判定を受けて起こした合格処理の G が同じ前 HEAD・新しい HEAD・根拠ファイルの組で再び `needs-carryover-judge` を返したときは、判定役を起こし直してはならず（MUST NOT）、投稿した記録の URL を添えて主に聞かなければならない（MUST）。

#### Scenario: needs-carryover-judge で返った

- **WHEN** G が Status `needs-carryover-judge`・`次の段: 合格処理` で return する
- **THEN** 本体は PR トークン上限を測ってから `dev-workflow:decider`・`model: opus` の判定役を起こし、判定の記録を PR に投稿し、判定とその URL を渡して合格処理の G を新しく起こす

#### Scenario: 共有枠が depleted のとき

- **WHEN** G が `needs-carryover-judge` で返し、`SHARED_BUDGET_MODE=depleted` である
- **THEN** 本体は判定役を起こさず `引き継ぎ判定: 判断できない` の記録を投稿して合格処理の G を新しく起こし、G が手順 6 で主に聞く

#### Scenario: 判定のあとの G が同じ組で再び返した

- **WHEN** 本体が判定の記録を投稿して起こした合格処理の G が、同じ前 HEAD・新しい HEAD・根拠ファイルの組で再び `needs-carryover-judge` を返す
- **THEN** 本体は判定役を起こし直さず、投稿した記録の URL を添えて主に聞く

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

### Requirement: 親が通してよい範囲の基準は、見張りのやり直しの上限の節を通る例の CI の再実行と新しい段落より先に効かせる
`parent-pass-criteria.md` の節「CI の見張りのやり直しの上限で止まった子」は、`job-timeout` に限らず、対象の止まり全体で、通る例の「CI の再実行（…原因の切り分けを通す条件にしない）」と、ランナーの状態の確認を含む推奨の読み方の段落のどちらよりも先に効くと書かなければならない（MUST）。子の記録が原因は断定できないと書いて再実行だけを勧めた場合は、節の「通す場合」の因果の説明が無いので主に上げる。確認が先の推奨は、確認が `gh api` だけで済む場合も主に上げる。節の `job-timeout` の `escalate` を主に上げる理由は、実機操作かの分け方に依らず「ランナーの側に原因があり、PR の差分でもやり直しでも直らないため」と書く（MUST）。通る例の CI の再実行の行にも、上限で止まった子は節が先に効くと行末に添える（SHALL。行の先頭の括弧の中は変えない）。

#### Scenario: 基準のファイルが節の優先を対象の止まり全体に定めている
- **WHEN** `parent-pass-criteria.md` の CI の見張りのやり直しの上限の節を読む
- **THEN** 推奨が Mac が空いてから CI を再実行するものでも、`job-timeout` に限らず対象の止まり全体で、節が通る例の CI の再実行とランナーの状態の確認を含む推奨の読み方のどちらよりも先に効き、通る例の原因の切り分けを通す条件にしない読み方と `gh api` の確認をそのまま通す読みは対象の止まりに当てないと書かれている

#### Scenario: 原因は断定できないと書いた再実行だけの推奨の扱いが決まっている
- **WHEN** 同じ節を読む
- **THEN** 子の記録が原因は断定できないと書いて再実行だけを勧めた場合も節の対象で、因果の説明が無いので主に上げると書かれ、通る例の CI の再実行の行の行末にも節が先に効くことが添えられている

#### Scenario: 確認が先の推奨は gh api だけで済む確認でも主に上げる
- **WHEN** 同じ節を読む
- **THEN** 手順 7 で上げた止まり（`cause` が `job-timeout` でない）の推奨が `gh api` でランナーの状態を見てから再実行するものでも、確認が先なので主に上げると書かれている

#### Scenario: job-timeout の理由が実機操作の分け方に依らない
- **WHEN** 同じ節の「主に上げる場合」を読む
- **THEN** `job-timeout` で `escalate` した止まりを主に上げる理由が「ランナーの側に原因があり、PR の差分でもやり直しでも直らないため」と書かれ、「ランナーの状態確認を求めるので実機操作に当たる」は書かれていない

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

`references/epic.md` の手順 8 は、委任が有効で止まりに委任が効くときだけ、主に上げずに `epic-dispatch.sh reply --as owner` で `許容する（主の委任による。停止の記録: <URL>） [主の委任: セッション <親のセッション ID> / uuid <確認の uuid> / 記録 <委任の記録の URL>]` を送ることを書かなければならない（MUST）。送れたらエピックに `委任で送った: 子 #<N> <停止の記録の URL>` の 1 行を残す（MUST。`親の判断:` で始めない）。同じ子のこの行の URL が最新の停止の記録の URL と同じなら送り直さない（MUST）。

#### Scenario: 委任で送った件をエピックに残す

- **WHEN** 親が委任で `reply --as owner` を送り、出力が `sent` か `relaunched`
- **THEN** エピックに `委任で送った: 子 #<N> <停止の記録の URL>` の 1 行を投稿する

#### Scenario: 同じ止まりに二度送らない

- **WHEN** 手順 7 か 8 で同じ子が再び挙がり、エピックにその子の `委任で送った:` の行があって URL が最新の停止の記録と同じ
- **THEN** 親は委任で送り直さず、子の再開を待つ

### Requirement: 親が委任で送る経路の守備範囲

親が委任で送る経路は、次の守備範囲で読まなければならない（MUST）。①入力の出どころは、親の会話の主の発言、エピックと子 issue と PR のコメント・ラベル（`gh` で読む）、同じ PC の親の会話ログ。親は協力的だが、主の雑談を委任と読み違える・別の子の止まりと取り違える前提で扱う ②拾いたい誤りは、確認の無い発言での委任、範囲外の止まり（推奨が許容でない・リスク許容待ちでない・確認より前）への送信、取り消し後の送信、二重送信 ③確認に「任せる」以外の語で任せる意思が読める答えは通してよい ④穴を塞ぎ切ることは完了条件にしない（MUST NOT）。

#### Scenario: 範囲外の止まりでは送らない

- **WHEN** 有効な委任があるが、止まりに委任が効かない
- **THEN** 親は委任で送らず、手順 8 の形で主に上げる

### Requirement: 子は委任の返事を確かめてから G に渡す

`references/epic-child-stop.md` の「親から届いた返事」は、末尾が `[主の委任: セッション <ID> / uuid <uuid> / 記録 <URL>]` の返事を、止まった件がリスク許容への返事待ち（pr-review-gate 手順 3 の宣言で止まった件）のときだけ受け、子が `--delegated <ID> <uuid> <委任の記録の作成日時> <URL> <最新の停止の記録の作成日時>` を回し、exit 0 で全文から任せる意思が読め、委任が有効で止まりに委任が効くときだけ、保留の解除の G に値を渡すことを書かなければならない（MUST。記録の書式と真正性確認は pr-review-gate 手順 5 が正本）。止まった件がリスク許容への返事待ちでない（聖域の変更・破壊的な操作・マージ・実機操作などで止まった）ときと、通らないときは G を起こさず、主に子のタブでの返事を理由付きで頼む（MUST）。

#### Scenario: 確かめられない委任の返事では G を起こさない

- **WHEN** `--delegated` が exit 0 でない（`REASON=not-after` などで exit 1、または exit 2）か、委任が有効でないか、止まりに委任が効かない
- **THEN** 子は G を起こさず、止まる前の記録と印を残してから、主に子のタブでの返事を、確かめられなかった理由（`REASON=` の値か満たさなかった条件）を添えて頼む

#### Scenario: リスク許容待ちでない止まりでは委任の返事を受けない

- **WHEN** 子が聖域の変更・破壊的な操作・マージ・実機操作などで止まっていて（リスク許容への返事待ちでない）、末尾が `[主の委任: …]` の返事が届く
- **THEN** 子は委任の返事として受けず、G を起こさずに、止まる前の記録と印を残してから、主に子のタブでの返事を理由付きで頼む

#### Scenario: 確かめられた委任の返事を G に渡す

- **WHEN** `--delegated` が exit 0 で、全文から任せる意思が読め、委任が有効で止まりに委任が効く
- **THEN** 子は保留の解除の G に、親のセッション ID・確認の uuid・`MATCH:` の timestamp・委任の記録の URL・停止の記録の URL・`MATCH:` の全文を渡す

### Requirement: 子が委任の返事を受ける経路の守備範囲

子が委任の返事を受ける経路は、次の守備範囲で読まなければならない（MUST）。①入力の出どころは、子に届いた返事の頭と末尾の添え書き（親が書く）、エピック・子 issue・PR のコメントとラベル、同じ PC の親の会話ログ。親は写し間違い・別のエピックや別の記録との取り違えをする前提で扱う ②拾いたい誤りは、確認でない発言・別のエピックの記録・取り消し済みや編集済みの記録・範囲外の止まりでの委任を主の許容として G に渡すこと ③親と子が同じ PC で動き、委任の確認のあとに親が起動し直したものは通してよい ④会話ログの改変の検知と、穴を塞ぎ切ることは完了条件にしない（MUST NOT）。

#### Scenario: 別のエピックの記録を添えた返事は受けない

- **WHEN** 添え書きの記録の URL がこの子の属さないエピックのコメント
- **THEN** 子は G を起こさず、主に子のタブでの返事を頼む

### Requirement: エピックの親は報告に付ける状態表を区切りより下に置く

`references/epic.md` は、エピックの親が主に出す報告すべて（別セッション方式の「親が別セッション方式でターンを終えるときに主に出す発言すべて」と、サブエージェント方式の主への報告）に状態表を付け、表・答えが要る子の URL・「前回の報告から片付いたもの」を報告の区切りより下に置くと規定しなければならない（MUST）。区切りより上の本文の最後の行は、既存の要件「エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う」のとおり答え方のままにし、1 行目も変えない。

#### Scenario: 区切りより上の最後の行と 1 行目は変わらない
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** 表・URL・片付いたものは区切りより下に置くと書かれ、区切りより上の最後の行は答え方のまま、1 行目は今回いちばん先に答えてほしい 1 件の質問（なければ `主がすること: なし`）のままと書かれている

### Requirement: 状態表は全部の子と親自身を決まった列で並べる

状態表は、表の上に確かめた時刻（JST）を書き、行を、まだ閉じていない全部の子 issue と親自身（エピックの番号）の 1 行ずつにし、列を `issue 番号・内容・ステータス・確認内容・推奨・答え方` にしなければならない（MUST）。確認内容は主に聞いていることの中身、答え方はどの画面で何を打つかを書き、答えが要らない行は `なし` と書く。

#### Scenario: epic.md が表の列を規定する
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** 確かめた時刻（JST）・親自身の行・列 `issue 番号・内容・ステータス・確認内容・推奨・答え方` が書かれ、答えが要らない行は `なし` と書くと書かれている

### Requirement: 状態表の下に答えが要る子の URL と片付いたものを書く

状態表の下に、答えが要る子の issue の URL を 1 行 1 本で置き、子の停止の記録の URL は 1 行目で聞く 1 件にだけ書き（聞いていない子の分は並べない。MUST NOT）、その下に「前回の報告から片付いたもの」を書かなければならない（MUST）。子のタブで答え済みの件も片付いたものに含める。

#### Scenario: 表の下の 2 つ
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** 表の下に URL を 1 行 1 本で置き、その下に前回の報告から片付いたもの（子のタブで答え済みの件を含む）を書くと書かれている

### Requirement: channel モードの状態表は答え方の列をチャンネルで返す内容にする

channel モードでは、状態表の答え方の列を、チャンネルで返す内容にしなければならない（MUST）。チャンネル以外の画面・タブを書いてはならない（MUST NOT。既存の要件「channel モードの主への発言はすべてチャンネルに送り…」に従う）。

#### Scenario: channel モードの答え方の列
- **WHEN** `references/epic.md` の表の規定を channel モードについて読む
- **THEN** 答え方の列はチャンネルで返す内容にし、チャンネル以外の画面・タブを書かないと書かれている

### Requirement: 状態表の規定の守備範囲を限る

状態表の規定が入力として扱うのは `references/epic.md` の文面でなければならない（MUST）。拾いたい誤りは、主が最新の 1 通だけで、閉じていない子の状態と自分がすることを読み取れないことである。次は通ってよい: 内容・確認内容の文の良し悪し／子が 1 件も残らない報告で表が空になること。書き方の穴を見つけるたびに決まりを足して塞ぎ切ることは、この規定の完了条件としない。

#### Scenario: 表の文の良し悪しは止めない
- **WHEN** 表の内容の列の文が分かりにくいという指摘が出る
- **THEN** この規定の範囲外として扱い、読み取れない誤り（状態と自分がすることが分からない）だけを直す

### Requirement: 別セッション方式の親は表を書く前に子の会話ログの末尾を読む

`references/epic.md` は、別セッション方式（Orca・tmux）の親が状態表を書く前に、`launch` に渡した子ごとに `scripts/epic-dispatch.sh child-log` で会話ログの末尾を読み（別のリポジトリの子は `<owner>/<repo>#N` で渡す。まだ起動していない子は渡さず、ステータスを `未起動（<理由>）` と書く）、子のタブで進んだ分を表に反映すると規定しなければならない（MUST）。子のタブで主が直接答えても子は issue の停止の記録を書き直さないので、記録だけを見て書くと表が子の実際の状態とずれる。会話ログの末尾と issue の記録が食い違うときは会話ログを優先する。

#### Scenario: epic.md が会話ログの確認を表より前に置く
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** 別セッション方式では表を書く前に `child-log` で子の会話ログの末尾を読むこと、食い違えば会話ログを優先することが書かれている

### Requirement: 読めない子のステータスは確かめられなかったと書く

`child-log` が `unreadable` を返した子のステータスは `確かめられなかった` と書き、記録から推測して書いてはならない（MUST NOT）。サブエージェント方式の子には独立した会話ログが無いので、`child-log` を使わず、本体が自分の会話から子の状態を書く。

#### Scenario: 読めない子とサブエージェント方式
- **WHEN** `references/epic.md` の状態表の規定を読む
- **THEN** `unreadable` の子は `確かめられなかった` と書き、サブエージェント方式は本体の会話から書くと書かれている

### Requirement: child-log は子ごとの最後の主の発言と子の発言を 1 行で出す

`epic-dispatch.sh child-log <child>...` は、子ごとに、その子の状態の記録の `worktree` から会話ログの置き場を引き、最新の会話ログの最後の「主の発言」と最後の「子の発言」の時刻と冒頭を 1 行（タブ区切り）で出さなければならない（MUST）。列は `<child>`・主の最後の発言の時刻（JST、`YYYY-MM-DD HH:MM`）・その冒頭（改行を空白にして先頭 80 文字）・子の最後の発言の時刻・その冒頭。該当が無い列は `-`。

#### Scenario: 最後のやり取りを出す
- **WHEN** 記録のある子の会話ログに、主の発言 → 子の発言 → ツールの結果、の順の行がある
- **THEN** 主の最後の発言と子の最後の発言の時刻と冒頭が 1 行で出て、ツールの結果は主の発言に数えられない

### Requirement: child-log は最新の会話ログと子の発言を決まった規則で選ぶ

最新の会話ログは、置き場の直下の `*.jsonl`（サブエージェントのものを除く）のうち、最後の timestamp が最も新しい 1 本でなければならない（MUST）。子の発言は、type が assistant のテキスト（`isSidechain` でないもの）である。

#### Scenario: 新しい会話ログを選ぶ
- **WHEN** 置き場に最後の timestamp が違う 2 本の `*.jsonl` がある
- **THEN** 最後の timestamp が新しい 1 本のやり取りが出る

### Requirement: child-log は主の発言を決まった規則で判定する

主の発言は、type が user で、`isMeta` でも `isSidechain` でもなく、内容が文字列かテキストだけ（`tool_result` を含まない）のものでなければならない（MUST）。次は数えない（MUST NOT）: 頭が `親エピック #` で始まる親の判断の返事（`親エピック #E の判断（主の承認ではない）: `）、`/develop` の最初の指示（内容に `<command-name>` のタグがある、または頭が `/develop` のもの）。頭が `主の返事（親エピック #E 経由）:` の親が中継した主の返事は数える。

#### Scenario: 親の判断の返事は主の発言に数えない
- **WHEN** 会話ログの最後の user 行が `親エピック #33 の判断（主の承認ではない）: ...` で、その前に主の発言がある
- **THEN** 主の最後の発言はその前の発言で、親の判断の返事ではない

#### Scenario: 中継された主の返事は数える
- **WHEN** 会話ログの最後の user 行が `主の返事（親エピック #33 経由）: ...` である
- **THEN** その行が主の最後の発言として出る

### Requirement: child-log は読めない子を unreadable で出して続ける

記録が無い・読めない（要件「子 1 ファイルの記録は決まった項目を持つ」の読めない記録を含む）・記録が 2 件以上で一意に決まらない、会話ログの置き場が無い・読めない、`python3` が無い、のどれかの子について、`child-log` は `unreadable <child>` を出し、他の子を続けなければならない（MUST）。記録に由来するときは stderr にその記録のパスを出す。

#### Scenario: 読めない子は unreadable で続ける
- **WHEN** 会話ログの置き場が無い子と読める子を一緒に渡す
- **THEN** 置き場が無い子は `unreadable <child>`、読める子は通常の行が出て、exit 0 である

#### Scenario: 読めない記録の子は unreadable と記録のパス
- **WHEN** 記録が JSON として読めない子を渡す
- **THEN** `unreadable <child>` が stdout に、その記録のパスが stderr に出て、記録は書き換えられない

### Requirement: child-log は何も書き換えず LLM を呼ばない

`child-log` は記録も会話ログも書き換えてはならず（MUST NOT）、LLM を呼んではならない（MUST NOT）。`jq` が無い・今のワークツリーを読めないときは stdout 空で exit 1、それ以外は exit 0 で終わる。

#### Scenario: jq が無い
- **WHEN** `jq` の無い PATH で `child-log` を実行する
- **THEN** stdout は空で exit 1 である

### Requirement: child-log の主の発言の判定の守備範囲を限る

`child-log` の判定が入力として扱うのは、Claude Code が書く会話ログ（`*.jsonl`）の user 行と assistant 行、および `epic-state.sh` が書いた状態の記録でなければならない（MUST）。拾いたい誤りは、主が子のタブで答えた最後のやり取りを取り逃がすことと、ツールの結果や親からの機械的な送信を主の発言に数えて、主が答え済みと取り違えることである。次は通ってよい: compact の要約や hook が足した user 行を主の発言に数えること／親が中継した主の返事の真偽／冒頭 80 文字で意味が取り違えられること（親が必要なら会話ログを自分で読む）／会話ログの形式が将来変わって `unreadable` になること。判定の穴を見つけるたびに除外を足して塞ぎ切ることは、この規定の完了条件としない。

#### Scenario: hook が足した user 行は止めない
- **WHEN** hook が足した user 行が主の発言に数えられているという指摘が出る
- **THEN** この規定の範囲外として扱い、除外を足さない

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

この要件の守備範囲で入力として扱うのは、`launch`・`reply` を実行したシェルの環境変数（`EPIC_DISPATCH_CLAUDE_CMD`・`EPIC_DISPATCH_MODEL`）だけである。拾いたい誤りは、子の起動コマンドにアイドル時のコンパクトを切る指定が入らず、子がコンパクトされて `SKILL.md` の中身を持たないまま進むことと、通常の自動コンパクトまで止めて子の会話が上限を越えることである。次は通してよく、この要件では止めない: 主の起動コマンド（`cld`）が子のプロセスの環境に入れる `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`（アイドル時のコンパクトを切った子では効かない）／`EPIC_DISPATCH_CLAUDE_CMD` が `--settings` を `claude` に渡さない形で、指定が効かなかった子／Claude Code が v2.1.290 より古く、指定が効かなかった子／この変更より前に起動され、従来の閾値で動いている子／`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` が設定された環境（値を見ずに無視する）。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

### Requirement: 時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める
時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、子について次を書かなければならない（MUST）: 子は `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること（そのプロセスだけに効き通常の自動コンパクトは止めない・v2.1.290 以降が要る・`~/.claude/settings.json` に置かない）。子の表は上から、端末が無ければ起動し直す、会話量 N が `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）以上なら経過時間と compact の有無によらず起動し直す、最後のリクエストから 60 分未満ならそのまま送る、60 分以上なら compact の有無と会話量によらず起動し直す、と書く。会話量条件が時間条件に優先するよう並べる。根拠は、コンパクトされた子は `SKILL.md` の中身を持たずに進むことと、費用の差の小ささ。

#### Scenario: 規則のファイルに子の切り方と分ける条件と根拠が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 子は `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること、`settings.json` に置かないこと、子は端末が無い・会話量が新閾値以上・60 分以上のいずれかなら起動し直し、会話量が閾値未満か不明で 60 分未満ならそのまま送ること、新閾値の変数名と既定値 150000、子を起動し直す根拠（コンパクトされた子は `SKILL.md` の中身を持たない）と #1039 の決定を #1323 で覆したこと、判定に使う事実（端末の有無は `epic-dispatch.sh reply` が確かめること・最後のリクエストの時刻はトランスクリプトから読むこと・会話量は同じファイルを `subagent-context.sh --file` で測ること）が書かれている

根拠には、2026-10-23 の子のログで、コンパクトのあとに残ったのが `SKILL.md` のファイル名と `/develop` の入口だけで、再開したあとも読み直さずにゲートの実行まで進んでいたことと、起動し直しとの費用の差（1 回あたり Opus 5.5 で約 $0.5）、1 時間以上たってから返事が来る子の割合（3.2%）を書く（SHALL）。判定に使う事実は、子の端末の有無（`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）と、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻、および同じファイルを `plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>` で測った会話量 N である。事実を読めない場合は、上の自動判定の要件と同じく確認できた条件だけで決め、どちらも真と確認できなければそのまま送ると書く（MUST）。送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順（develop の `references/epic.md` の Orca 経路と `epic-dispatch.sh reply`）が書き、このファイルを参照する）。

この分類は、`epic-dispatch.sh wait --resolve` が親の代わりに通す返事を除き、スクリプトではなく本体が規則のファイルを読んで行う。`wait --resolve` が通す返事は、要件「wait --resolve は通す返事を送る前に起動し直すかを表で決める」のとおり `resolve_stopped` が同じ子の表で分類する（例外）。拾いたい誤りは、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子と、この変更より前に起動されてコンパクトされうる子を含む）にそのまま返事を送り、子が手順を外れて進むこと、大きい会話の子に時間だけを見て返事を送り続けること、会話量が閾値未満か不明で 60 分未満の子を不要に起動し直して、子が積んだ判断と起動し直しの費用を無駄にすることである。次は通してよく、この分類では止めない: 経過時間がちょうど 60 分前後で、時刻の読み方によって扱いが分かれる子／トランスクリプトが複数あってどれが子のセッションか分からず、そのまま送った子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: 子の会話量の行が短時間の行に優先する
- **WHEN** 子の表を上から読む
- **THEN** 端末が無い行の次で、`EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS` と既定値 150000 が明記された会話量の行により、60 分未満でも閾値以上なら起動し直すと分かる

#### Scenario: 閾値を選んだ根拠と限りが分かる
- **WHEN** 規則のファイルの子の説明を読む
- **THEN** #1046 の再集計の結論に合わせて 150000 を採用したことと、その集計はキャッシュ有効中の新条件の最適値を実証したものではないこと、時間条件は #1323 のまま残ることが書かれている

### Requirement: 親が長く待ったあとは親の表で続けるか起動し直すかを決める
`plugins/dev-workflow/skills/develop/references/reply-after-idle.md` は、親（エピックを回すセッション）について次を書かなければならない（MUST）: 親の閾値は 120,000 で、主の起動コマンド（例: `cld`）が値の未設定のときだけ入れ、`~/.claude/settings.json` の `env` に置かないこと（個人の設定ファイルのパスは書かない）。親の表は、最後のリクエストから 60 分未満ならそのまま続ける、60 分以上でコンパクトが走っていればそのまま続ける、走っていなければ会話量 N が 150,000 以上なら起動し直し未満なら続ける。親を子と分ける理由と、親の状態の復元元。

#### Scenario: 規則のファイルに親の値と表と復元元が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 親は 120,000 で主の起動コマンドが未設定のときだけ入れて `settings.json` に置かないこと、親の表がコンパクトの有無と N が 150,000 以上か未満で分けること、会話量を `subagent-context.sh --file` で測ること、親を子と分ける理由、親の状態の復元（親が通した判断を含む）、hook が `SKILL.md` の読み直しを差し込むこととその費用 1 回約 39k と #1264 で計算し直すこと、1〜2 週間後の再集計が書かれている

親を子と分ける理由は、親の監視の `wait` はコンパクトのあとも動き続けて通知を受けた親はそのまま作業を続けられ、起動し直すと監視が途切れることである（SHALL。書く）。親の状態のうち、回し方（`回し方:`）・終わった子（`子 #N マージ → 残り k 件` / `子 #N 見送り`）・外した子エピック（`後で別に起動するエピック:`）・残したワークツリー（`子 #N のワークツリーを残した`）・親が通した判断（`親の判断: 子 #N 通した`）はエピックのコメントから、残りの子は依存グラフと子 issue の状態から復元できると書く（SHALL）。根拠と限りとして、#1039 の集計コメントの URL と要点（返事の直前の会話の中央値、起動し直しの費用、閾値ごとの費用の増減）、実績の少なさと PC が寝ているとコンパクトが走らないこと、コンパクトのあと develop を呼んでいた会話には SessionStart の hook（`scripts/develop-compact-reread.sh`）が `SKILL.md` の読み直しを差し込むことと、その費用（1 回約 39k トークン）、両方を足した想定は計算し直しておらず #1264 で計算すること（#1217 の計算コメントの URL）を書く（SHALL）。再集計は、1〜2 週間回したあとに親の同じ集計をやり直して #1039 にコメントし、値を見直す。件数・金額は合否に使わず記録する。

この要件の守備範囲で入力として扱うのは、親のセッションのトランスクリプトの最後のリクエストの時刻とそのあとの `compact_boundary` の有無、`plugins/dev-workflow/scripts/subagent-context.sh --file` で測った会話量 N である。拾いたい誤りは、PC が寝ていてコンパクトが走らなかった 150,000 トークン以上の親の会話をそのまま続けて会話全体を書き込み直すことと、コンパクトが走った親や 60 分未満の親を起動し直して監視を途切れさせることである。次は通してよく、この要件では止めない: 経過時間が 60 分前後、N が 150,000 前後で扱いが分かれる場合／主の起動コマンドが値を入れず、既定のまま動く親。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

### Requirement: epic.md の回し方は子の起動コマンドの指定と返事の規則のファイルを指す
develop の `references/epic.md`「エピックの扱い」の「回し方」は、子セッションの起動コマンドに `--settings '{"idleCompaction":false}'` が付いて子のアイドル時のコンパクトが切られることと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で「そのまま送る」か「起動し直す」かを決めることを書かなければならない（MUST）。子の起動コマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が付く、または `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` で変えられるとは書かない（MUST NOT）。`plugins/dev-workflow/tests/epic-dispatch.bats` はこの記述と、上の 3 つの要件の規則のファイルの記述を確かめなければならない（MUST）。

#### Scenario: epic.md の回し方が起動コマンドの指定と規則のファイルを指す
- **WHEN** `references/epic.md` の「エピックの扱い」を読む
- **THEN** 子の起動コマンドに `--settings '{"idleCompaction":false}'` が付くことと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で決めることが書かれていて、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` と `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` は書かれていない

この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」の回し方の段落のうち、`references/epic.md` に `epic-dispatch.sh` が足すのは `--model` だけと書くと求める部分に優先する（足すのは `--settings '{"idleCompaction":false}'` と `--model`）。

### Requirement: 上限を明示しない wait は親の会話キャッシュの有効期限で上限を決める

`plugins/dev-workflow/scripts/epic-dispatch.sh wait` は、`--timeout` が無く `EPIC_DISPATCH_TIMEOUT` も無いか空のとき、最初のポーリングの前に `cache_ttl_of "$(git rev-parse --show-toplevel)"` を 1 回呼び、`5m` なら上限を 21600 秒、`1h` か exit 1 なら 3000 秒にしなければならない（MUST）。このとき最初のポーリングの前に stderr へ `wait limit <秒> (parent cache <5m|1h|unknown>)` の 1 行を出す（SHALL。`unknown` は exit 1 のとき）。

守備範囲: ①入力は親のワークツリーのトランスクリプト。②拾いたいのは、1 時間で書いている親が 6 時間眠ってキャッシュを切らすことと、5 分で書いている親が 45 分ごとに起きて書き直しを払い続けること。③判定できないときに短い上限になることは通してよい。

#### Scenario: 1 時間で書いている親は短い上限で待つ
- **WHEN** 親のワークツリーの置き場に、最後にキャッシュを書いた assistant の行が `ephemeral_1h_input_tokens` 正・`ephemeral_5m_input_tokens` 0 のトランスクリプトを置き、子 11 が `closed` を返すスタブ環境で、`--timeout` も `EPIC_DISPATCH_TIMEOUT` も無しに `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 3000 (parent cache 1h)` の 1 行が出て、stdout は `closed 11` の 1 行で exit 0

#### Scenario: 5 分だけで書いている親は長い上限で待つ
- **WHEN** 最後にキャッシュを書いた assistant の行が `ephemeral_5m_input_tokens` 正・`ephemeral_1h_input_tokens` 0 のトランスクリプトを置いて、同じく `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 21600 (parent cache 5m)` の 1 行が出る

#### Scenario: 判定できなければ短い上限で待つ
- **WHEN** 親のワークツリーの置き場が無い環境で `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 3000 (parent cache unknown)` の 1 行が出る

### Requirement: 上限を明示した wait は有効期限を読まない

`epic-dispatch.sh wait` は、`--timeout` か空でない `EPIC_DISPATCH_TIMEOUT` があるときはその値（`--timeout` が優先）を上限にし、`cache_ttl_of` を呼んではならず、`wait limit` の行を出してはならない（MUST NOT）。上限の決め方にかかわらず、stdout の 1 行と exit code の契約は変えない（MUST）。

守備範囲: 拾いたいのは、待ちをやめる直前の `--timeout 0` の確認で stderr に行が出て「stderr が空」の条件を壊すこと。

#### Scenario: 上限を明示したら有効期限を読まない
- **WHEN** 5 分だけで書いたトランスクリプトを置いて、`epic-dispatch.sh wait --interval 0 --timeout 0 11` と、`EPIC_DISPATCH_TIMEOUT=0 epic-dispatch.sh wait --interval 0 11` を、子 11 が `open` を返すスタブ環境で実行する
- **THEN** どちらも stdout は `timeout 11` の 1 行、stderr は空で exit 2

### Requirement: cache_ttl_of はワークツリーの会話で最後にキャッシュを書いた行を読む

`epic-dispatch.sh` の関数 `cache_ttl_of <ワークツリーの絶対パス>` が使う行は、`type` が `assistant`・`entrypoint` が `cli`・`isSidechain` が true でない・`timestamp` が ISO 8601 として読める文字列（読めない文字列の行は使わない。新しさは時刻として比べ、タイムゾーンの無い値は UTC とみなす）・`message.usage.cache_creation` の `ephemeral_5m_input_tokens` と `ephemeral_1h_input_tokens` の和が正（数でない値は 0）の行のうち、`timestamp` が最も新しい 1 行とする（MUST）。

守備範囲: ①入力は置き場の直下の jsonl（親か、順番 2 では子のもの）。②拾う誤りは、サブエージェント・`isSidechain`・書き込み 0・古い行を最新と読むことと、数でない値や壊れた行で落ちること。③`entrypoint` の扱いと通してよい入力は要件「cache_ttl_of は会話を持つ CLI のセッションの行だけを読む」に書く。④形の変化の検知とすり抜けを塞ぎ切ることは完了条件にしない。

#### Scenario: 書き込みの無い行と古い行とサブエージェントの行では決めない
- **WHEN** 置き場の 2 つの jsonl に、古い `timestamp` の 5 分だけの行、新しい `timestamp` の 1 時間の行、それより新しい書き込みが 0 の行を置き、`<セッション>/subagents/` の下にさらに新しい 5 分だけの行を置いて `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 3000 (parent cache 1h)` が出る

### Requirement: cache_ttl_of は会話を持つ CLI のセッションの行だけを読む

`cache_ttl_of` は、`entrypoint` が `cli` ちょうどの行だけを使わなければならない（MUST）。`entrypoint` が無い行と、`sdk-py`・`sdk-cli` など `cli` 以外の行は使わない（MUST NOT）。

守備範囲: ①入力は、置き場に混ざる対話のセッションの行と、会話を持たないセッション（hook が SDK で起こしたもの・`claude -p`）の行。②拾いたいのは、後者が 5 分で書いた行を最新と読み、1 時間で書く親を 6 時間眠らせること。③通してよいのは、同じワークツリーの別の `cli` のセッションの行が最新になること（同じアカウント・同じ設定なら有効期限も同じ）と、`cli` の行が無く判定できないこと（`entrypoint` の無い古い版を含む）。両方の有効期限が正の行の扱いは要件「cache_ttl_of は有効期限と時刻を 1 行で返し、判定できなければ何も出さない」に書く。④`cli` 以外の値で対話するセッションは完了条件にしない。

#### Scenario: 会話を持たないセッションの行では決めない
- **WHEN** 置き場の jsonl に `entrypoint` が `cli` で 1 時間だけの行を置き、別の jsonl にそれより新しい 5 分だけの行を、`entrypoint` が `sdk-py`・`sdk-cli`・無しの 3 行置いて `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 3000 (parent cache 1h)` が出る

### Requirement: cache_ttl_of は置き場の直下だけを読み、引数が空なら置き場を読まない

`cache_ttl_of` は、`transcript_dir <引数>` の置き場の直下の `*.jsonl` だけを読まなければならない（MUST。`<セッション>/subagents/*.jsonl` は読まない）。引数が空なら置き場を求めずに、stdout に何も出さず exit 1 で終わらなければならない（MUST）。

守備範囲: 入力・誤り・完了条件にしないものは要件「cache_ttl_of はワークツリーの会話で最後にキャッシュを書いた行を読む」のとおり。加えて拾いたいのは、`toplevel` が失敗して空を返したときに `transcript_dir ""` が置き場の親（projects の直下）を指し、どのワークツリーのものでもない jsonl から有効期限を読むこと。

#### Scenario: ワークツリーのパスが取れなければ置き場の親を読まない
- **WHEN** `git rev-parse --show-toplevel` が空を返すスタブ環境で、`$CLAUDE_PROJECTS_DIR` の直下に 5 分だけで書いた行の jsonl を置き、`epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 3000 (parent cache unknown)` が出る

### Requirement: cache_ttl_of は有効期限と時刻を 1 行で返し、判定できなければ何も出さない

`cache_ttl_of` は、使う行の `ephemeral_1h_input_tokens` が正なら `1h`、0 なら `5m` とし、stdout に `<1h|5m> <その行の timestamp の epoch 秒>` の 1 行を出して exit 0 で終わらなければならない（MUST。epoch 秒は最後にキャッシュを書いた行の時刻で、最後のリクエストの時刻ではない）。置き場に `*.jsonl` が無い・python3 が無い・使う行が無いときは、stdout に何も出さず exit 1 で終わる（MUST）。gh も LLM も呼ばず、stderr にも出さない（MUST NOT）。

守備範囲（通してよい入力）: どのセッションの行を使うかは要件「cache_ttl_of は会話を持つ CLI のセッションの行だけを読む」のとおり／両方の有効期限が正の行を `1h` と読むこと（事実でなく判定の限り。外れると 1 回分の書き直しを払うが、次の行は `5m` と読めて戻る）／該当する行が無く判定できないこと。

#### Scenario: 両方の有効期限で書いた行は 1 時間とみなす
- **WHEN** 最後にキャッシュを書いた行の `ephemeral_5m_input_tokens` と `ephemeral_1h_input_tokens` がどちらも正のトランスクリプトで `epic-dispatch.sh wait 11` を実行する
- **THEN** stderr に `wait limit 3000 (parent cache 1h)` が出る

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

`references/epic.md` は、`後で別に起動するエピック: #N` の行で子を外す確認を `closed` で起こされたときだけに書き、`needs-approval` の確認を待ちをやめる直前の確認に残さなければならない（MUST）。位置引数の子が無い `wait`（手順 4 と、手順 3・7 から手順 2 に戻って動いている子が 0 件で片付け待ちの子だけを渡すとき）には `--timeout 21600` を付けると書く（MUST）。手順 6 の、何もしない子を待つ説明は、最長の時間ではなく親が気づかずに待ち続けることとして書く（SHALL）。

守備範囲: 拾いたいのは、片付け待ちだけの待ちが 45 分でやめてしまうこと。

#### Scenario: 子エピックの行で外す確認は closed のときだけ
- **WHEN** `references/epic.md` の、`後で別に起動するエピック: #N` の行で子を外す確認の段落を読む
- **THEN** その確認を `closed` で起こされたときに行うと書かれ、`timeout` で起こされたときに行うとは書かれていない

#### Scenario: 片付け待ちだけの待ちは長い上限を明示する
- **WHEN** `references/epic.md` の手順 4 の、`kept <N> not-done` の子だけを `--watch-done` に渡して待つ文を読む
- **THEN** その `wait` に `--timeout 21600` を付けることが書かれている

#### Scenario: 手順 2 に戻る片付け待ちだけの待ちも長い上限を明示する
- **WHEN** `references/epic.md` の手順 2 の、動いている子が 0 件で片付け待ちの子だけを渡すときの文と、待ちをやめてよい条件 (d) を読む
- **THEN** その `wait` に `--timeout 21600` を付けることが書かれ、(d) は手順 2・4 の片付け待ちの子だけを待つ `wait` の `timeout` を指している

### Requirement: 規則のファイルに親の待ちの費用と使用量の超過中の扱いを書く

`references/reply-after-idle.md` は、閾値の表とそのまま送るか起動し直すかの表とは別の節に、`wait` の上限の既定 3000 秒とその理由（キャッシュの 1 時間と、アイドル時のコンパクトの約 54 分の前に起きる）、上限で起きた親は掛け直すだけであること、使用量の超過中は有効期限が 5 分に縮むので 21600 秒に戻すこと（根拠の URL を添える）、有効期限を固定した人の扱い、PC が寝ている間は効かないことを書かなければならない（MUST）。その節の外の表と文を変えてはならない（MUST NOT）。

守備範囲: #1323 が同じファイルの表を変えるので、この change は節を足すだけにする。

#### Scenario: 規則のファイルに親の待ちの費用と超過中の扱いがある
- **WHEN** `references/reply-after-idle.md` を読む
- **THEN** 親の待ちの費用の節があり、3000 と 21600、使用量の超過中に 5 分に縮むこと、https://code.claude.com/docs/en/prompt-caching 、`CLAUDE_CODE_PROMPT_CACHE_TTL`、PC が寝ている間は効かないことが書かれ、閾値の表とそのまま送るか起動し直すかの表はこの change の前と同じ
