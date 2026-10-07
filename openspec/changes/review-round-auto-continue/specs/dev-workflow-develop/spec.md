## MODIFIED Requirements

### Requirement: 1 ループは W→R1→W→G の順で回る
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 → (1) W が仕様化判断の記録・分割判定・openspec CLI による change の作成（`openspec new change` と artifact の直書き）まで行い return（仕様化しない判定なら (3) へ直行）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりに BLOCKER が残れば、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の直し方の判定を通し、「決まっている」で PR トークン上限の内側なら主に聞かず次の周を回し、そうでなければ `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) 実装（`tasks.md` を TDD で。直行なら TDD）・verify（`openspec validate --strict`）まで行って return、本体が計測し、W の return の `画面確認:` の行が `要る` なら画面確認役 V を起こしてから（下の「画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす」Requirement）、(3b) `openspec archive`・PR を Draft のまま用意（無ければ Draft で作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → (4) G が pr-review-gate の手順 1〜5 を実行し `passed` / `failed` / `保留` / `needs-reviewer` / `needs-decider` / `needs-fix-check` / `review-incomplete` のいずれかを return。PR の Ready 化は G が手順 5 の合格処理で行い（Draft なら Ready にしてから `agent-review:passed` を付ける）、W は行ってはならない（MUST NOT）。

G が `review-incomplete` を return したとき、本体は新しい reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止めなければならない（MUST）。`needs-reviewer` が一周目照合の補足要求である場合、本体は fresh reviewer に固定 HEAD・元の三表・残差・補足済み回数を渡し、同じレビューの不足分だけを補わせなければならず（MUST）、レビューを最初からやり直させてはならない（MUST NOT）。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら実行役を `opus` に上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く。**W を `fable` で再開してはならない**（MUST NOT。実行役の上限は `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。修正後は G を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりの扱いは pr-review-gate の収束ルールと、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement に従う）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

worktree は本体が用意する（SHALL）: 本体が既に対象専用の worktree にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。W は自分で worktree を切らない（MUST NOT。セットアップは worktree プラグインの hooks が担い、`.worktreeinclude` が無いときの `/wt-setup` は本体が行う）。**W / G を `isolation: "remote"` で起こしてはならない**（MUST NOT）。強制停止に当たったサブエージェントの未コミット差分は本体が確認して commit する設計（下の「強制停止で止まった作業ツリーは本体が引き取る」Requirement）だが、`remote` 隔離は本体から見えない環境で動くため、そこで強制停止に当たると作業がそのまま失われる。

`/opsx:*` のスラッシュコマンドは、本体や主が対話で change を作る場面の道具として SKILL.md に書いてよい（MAY）が、W が実行する工程として 1 ループに書いてはならない（MUST NOT。W の種別 `dev-workflow:worker` は `Skill` を持たない）。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、(1) の W の工程に `openspec new change` があり、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ既定 2 周と、2 周目以降の周の終わりに直し方の判定を通す続行がある

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

`spec-reviewer.md` は 6 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合・守備範囲の明記）と、既定 2 周と 2 周目以降の周の終わりに直し方の判定を通して続ける規則を含む（MUST。判定役・入力・書式の正本は SKILL.md で、`spec-reviewer.md` は規則を書いて正本を指す）。観点の中身の正本は `dev-workflow-spec-review` とする（SHALL）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

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

## ADDED Requirements

### Requirement: レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける

`skills/develop/SKILL.md` は、節「レビューの周を主に聞かずに続ける（直し方の判定）」を 1 か所だけ持ち、仕様レビュー（R1）と PR のレビュー（G）の両方について、2 周目以降の周の終わりに止める指摘が残ったときの本体の手順の正本としなければならない（MUST）。`references/roles/spec-reviewer.md` と `skills/pr-review-gate/stages/triage.md` は規則を短く書いてこの節を指し、判定の記録と事後報告の書式を再掲してはならない（MUST NOT）。

**規則**: 2 周目以降の周の終わりに残った止める指摘（仕様レビューは R1 の `REQUEST_CHANGES` の BLOCKER、PR のレビューは G が `needs-fix-check` で渡した指摘）がすべて直し方の決まったもので、PR トークン上限の計測が exit 2 でなければ、本体は主に聞かず次の周を回し、記録先に事後報告を残す（MUST）。主に聞くのは、直し方の判定が「選び直しが要る」とき（入力不足で判定が出なかったときを含む）と、PR トークン上限の計測が exit 2 のときの 2 つだけとする（MUST）。interactive と unmanned で同じに扱う（MUST）。主に聞かずに回す周の回数に上限を置かない（MUST NOT。止めるのは PR トークン上限、直し方の判定、PR 側の順 6 の「PR ごとに 1 回まで」）。

**判定役**: 本体が決める役を `subagent_type: dev-workflow:decider` で起こす（MUST）。モデルは仕分け表の順 6 の決める役と同じく残量モードどおりとし、`model` を明示する（MUST）。description には記録先番号 `#N` を入れる（MUST。PR トークン上限の計測に含めるため）。起こす前に PR トークン上限を計測し、exit 2 なら起こさずに exit 2 の手順で止まる（MUST）。G・本体・レビュアーの申告を判定の代わりにしてはならない（MUST NOT）。

**「直し方が決まっている」の定義**: 指摘ごとに、①直し方が 1 つに決まる（設計の選択肢から選ぶ必要が無い）②記録先の範囲（受け入れ条件・issue の範囲）を変えない ③前の周で「決まっている」と判定した直し方を当てたのに閉じなかった指摘ではない、の 3 つをすべて満たすとき「決まっている」とする（MUST）。1 件でも満たさなければ、その周の判定は「選び直しが要る」とする（MUST）。

**入力**: 決める役は `Bash` を持たないので、本体が次を入力文に貼る（MUST）: 記録先の本文と関連コメント（受け入れ条件・`仕様化判断:` の記録・それまでの `直し方の判定:` の記録）、残った指摘の原文（仕様レビューは最新の `仕様レビュー: REQUEST_CHANGES` のコメント、PR のレビューは G の仕分けの PR コメントとレビュアーの要約）、前の周の指摘の原文、対象ファイルのパス（change の artifact、または PR の変更ファイル）、W の直近の return。

**返答の 1 行目**: 依頼文で返答の 1 行目を `裁定: 可`（すべて決まっている）・`裁定: 否`（1 件でも選び直しが要る）・`不足: <足りないもの>` のどれかちょうどに指定し、2 行目以降に指摘ごとの直し方（1 行）か選び直しが要る理由（選択肢、または変わる範囲）を書かせる（MUST）。本体は 1 行目だけで分岐する（MUST。本文の読み取りで分岐しない）。1 行目が `不足:` か 3 形のどれにも一致しなければ、足りないものを補って同じ問いで 1 回だけ依頼し直し、2 回目も同じなら「選び直しが要る」として扱う（MUST）。

**判定の記録**: 本体は返答を受け取ったら、記録先に判定の記録のコメントを投稿する（MUST。決める役は投稿できないので代理投稿する。PR のレビューでも G ではなく本体が投稿する）。1 行目は正規表現 `^直し方の判定: (決まっている|選び直しが要る)$` に完全一致させ（MUST。太字・全角コロン・末尾句点を付けない）、2 行目以降に次を `項目名: 値` で書く（MUST）: `対象:`（`仕様レビュー` または `PR レビュー（PR #N）`）、`周:`（何周目の終わりか）、`判定役:`（`dev-workflow:decider`・モデル・本体が代理投稿）、`指摘ごとの判定:`（続く行に 1 行 1 件で、指摘の要約と原文の URL、直し方か選び直しの理由）、`入力不足:`（`なし`、または 2 回目も不足で「選び直しが要る」とした場合の足りなかったもの）。

**続行と事後報告**: 判定が「決まっている」なら、本体は仕様レビューでは W を `段: spec` で再開して artifact を直させ R1 に次の周の差分再レビューをさせ、PR のレビューでは判定の記録の URL と裁定を渡して照合と振り分けの G を新しく起こす（MUST）。各 spawn・再開の前の PR トークン上限の計測は省かない（MUST）。主に聞かずに回した周の結果を本体が受け取ったら（仕様レビューは R1 の結果、PR のレビューはその周の照合と振り分けの G の return）、記録先に事後報告のコメントを投稿する（MUST）。1 行目は正規表現 `^主に聞かずに回した周: [0-9]+ 周目$` に完全一致させ（MUST）、2 行目以降に `対象:`・`残っていた指摘:`（前の周の終わりに残った指摘の要約を 1 行 1 件、またはそれを載せたコメントの URL）・`判定の根拠:`（判定の記録のコメント URL）・`使ったトークン:`（周の前の合計 → 周のあとの合計、その差、上限）・`周の結果:`（その周のレビュー結果）を書く（MUST）。`使ったトークン:` の 2 つの値は、本体が spawn・再開の前に毎回とる PR トークン上限の計測の値を使う（周の前は直し方の判定の決める役を起こす前の計測、周のあとは周の結果を受け取ったあと最初の計測。MUST。新しい計測の仕組みを足さない）。

**主に聞くとき**: 判定が「選び直しが要る」なら、仕様レビューでは `needs-approval` を付けて主に聞き（`dev-workflow-spec-review` の「仕様レビューは 2 周で確定し結果を issue に記録する」Requirement）、PR のレビューでは判定の記録の URL と裁定を渡して照合と振り分けの G を新しく起こし、G が順 5 に当てる（MUST）。仕様レビューで主に聞くときの引き継ぎのコメントは「保留で止まるときは記録先に引き継ぎのコメントを 1 種類の書式で残す」Requirement の場面「レビューの 2 周キャップ超え」として書き、待ち理由は `2 周キャップ超え` とする（MUST）。

この判定の守備範囲は、レビューの 2 周目以降の周の終わりに残った指摘（仕様レビューの R1 の BLOCKER、PR のレビューで G が `needs-fix-check` で渡した指摘）について、主の判断が要る指摘を主に聞かずに進めてしまうことを防ぐことである。拾いたいのは、設計の選択肢から選ぶ必要がある指摘・記録先の範囲を変える指摘・前の周で決まっているとした直し方で閉じなかった指摘で、これらは主に上げる。直し方が 1 つに決まる指摘（例: 受け入れ条件の文と artifact の 1 文が食い違い、artifact 側を受け入れ条件に合わせれば閉じる BLOCKER。同じ文言が別の場所に残っている指摘）は主に聞かずに通す。判定が「決まっている」とした直し方が外れることは防がない（次の周の終わりの判定の ③ で拾う）ので、判定の誤りが 1 件も無いことをこの手順の完了条件にしない。

#### Scenario: 正本の節が 1 か所にある
- **WHEN** `skills/develop/SKILL.md`・`references/roles/spec-reviewer.md`・`skills/pr-review-gate/stages/triage.md` を読む
- **THEN** 判定役・定義・入力・返答の 1 行目・判定の記録と事後報告の書式は SKILL.md の節「レビューの周を主に聞かずに続ける（直し方の判定）」にだけあり、ほかの 2 つはその節を指している

#### Scenario: 主に聞く条件が 2 つだけ書かれている
- **WHEN** SKILL.md の節「レビューの周を主に聞かずに続ける（直し方の判定）」を読む
- **THEN** 主に聞くのは「方針の選び直しが要る」と「PR トークン上限を超える（`pr-token-budget.sh` が exit 2）」の 2 つだけと書かれている

#### Scenario: 2 回とも入力不足
- **WHEN** 決める役の返答の 1 行目が 2 回続けて `不足:` で始まる
- **THEN** 本体は「選び直しが要る」として判定の記録を投稿し（`入力不足:` に足りなかったものを書く）、主に聞く経路に進む

#### Scenario: 前の周で決まっているとした直し方で閉じなかった
- **WHEN** 3 周目の終わりに、2 周目の終わりの判定で「決まっている」とされた BLOCKER が閉じずに残る
- **THEN** 決める役はその指摘を「選び直しが要る」とし、本体は主に聞く

#### Scenario: 主に聞かずに回した周の事後報告
- **WHEN** 直し方の判定で開いた 3 周目の R1 の結果を本体が受け取る
- **THEN** 本体は 1 行目 `主に聞かずに回した周: 3 周目` のコメントを記録先に投稿し、残っていた指摘・判定の記録の URL・周の前とあとのトークンの合計とその差と上限・周の結果を書く

### Requirement: G の needs-fix-check を受けた本体の動き

`skills/develop/SKILL.md` の 1 ループの (4) は、G の Status `needs-fix-check` を受けた本体の動きを書かなければならない（MUST）: 本体は「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の手順で決める役を起こして判定を受け取り、判定の記録を記録先に投稿し、判定（「決まっている」または「選び直しが要る」）と判定の記録の URL を渡して照合と振り分けの G を新しく起こす（MUST）。本体は判定を受けて自分で `agent-review:failed` を付けたり W を再開したりしてはならない（MUST NOT。ラベルの付け替えと W に戻す指摘の一覧は G が決める）。

#### Scenario: needs-fix-check で返った
- **WHEN** G が Status `needs-fix-check`・`次の段: 照合と振り分け` で return する
- **THEN** 本体は PR トークン上限を測ってから決める役を起こし、判定の記録を記録先に投稿し、判定とその URL を渡して照合と振り分けの G を新しく起こす
