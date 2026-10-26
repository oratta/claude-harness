## MODIFIED Requirements

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

#### Scenario: worker.md に記録書式と事前分類表がある
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

#### Scenario: worker.md が (3a) / (3b) の return 内容を列挙している
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

#### Scenario: worker.md の工程名が 3 つになっている
- **WHEN** `references/roles/worker/common.md` のコンテキスト上限と手渡しの節を読む
- **THEN** W が return する工程の単位が「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つとして列挙されている

#### Scenario: SKILL.md が (3a) と (3b) のあいだの計測を指示している
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** (3a) の return のあと (3b) を指示する前に `scripts/subagent-context.sh` で測ると書かれており、上限超のときの扱いは `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を正本として参照している

#### Scenario: タスク単位のさらなる分割は禁止されている
- **WHEN** `skills/develop/SKILL.md` の (3) を読む
- **THEN** (3) を (3a)/(3b) より細かく切らないことと、その理由（手渡しごとに払う固定分と、実装の途中で切ると後任が Red のまま止まったテストから再出発すること）が書かれている

### Requirement: W の (3b) は宣言の書式ファイルを指す

`plugins/dev-workflow/skills/develop/references/roles/worker/finish.md` の (3b) の仕様宣言は、書式と `対象 HEAD:` 規約の正本として `skills/pr-review-gate/declarations.md` を指さなければならない（MUST）。`skills/develop/SKILL.md` の「仕様宣言は記録先ではなく常に PR コメントに置く」の書式の正本の参照も同じファイルを指す（MUST）。

#### Scenario: W の参照先

- **WHEN** `worker/finish.md` の (3b) を読む
- **THEN** 仕様宣言の書式の正本として `skills/pr-review-gate/declarations.md` が書かれている

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

#### Scenario: worker.md が CLI の経路で書かれている
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

### Requirement: W の return は読んだコードの要点を持つ

`references/roles/worker/common.md` は、W の return の成果一覧（この欄は W の場合のみ必須で、G の return の契約は変えない。工程の終わりの return、途中で締めた return、昇格トリップワイヤーで止まったときの return のいずれも）に「読んだコードの要点」欄を含めることを書かなければならない（MUST）。欄の書式は 1 行 1 件の `<リポジトリ相対パス>:<開始行>-<終了行> — <そこから分かったこと>` とし、上限を 20 行とし、超えるときは次の工程で読む必要が高いものを残すと書かなければならない（MUST）。

`worker/common.md` の「コンテキスト上限と手渡し」の節は、手渡しで起こされた W に向けて、前任の要点は読む場所の案内であり、編集する前には該当範囲を自分で読んで確かめることを書かなければならない（MUST）。要点を判断の根拠として読み替えてよいと書いてはならない（MUST NOT）。

`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の節が成果一覧を列挙する箇所（`工程完了:` の説明と、通知を受けたときの振る舞い）は W / G 共通の定義なので、「読んだコードの要点」を「W の場合のみ必須」という条件付きで含まなければならない（MUST）。G に必須と読める無条件の追記をしてはならない（MUST NOT。G は段ごとに新しく起こされ、`工程中断:` の return を同じ段の新しい G に渡す既存の経路はこの欄を前提にしないため）。書式（1 行の形・上限行数）は `worker/common.md` を正本とし、`decision-criteria.md` に再掲してはならない（MUST NOT。上限を変えたときに片方が取り残されるため）。

#### Scenario: worker.md の手渡しの節に欄と書式がある
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

### Requirement: 事前分類表は W が読まないファイルに置く

重要実装の事前分類（聖域パス・マージ権限・層間契約・課金/法務の表と、W の上限・読んで判断する役の種別・残量モードの優先の説明）は、`plugins/dev-workflow/skills/develop/references/pre-classification.md` に置かなければならない（MUST）。このファイルが事前分類の正本であり、`worker/` の 4 本と索引に表を再掲してはならない（MUST NOT）。

事前分類を参照する次の箇所は `references/pre-classification.md` を指さなければならず（MUST）、事前分類について索引 `references/roles/worker.md` や `references/roles/worker/` の指示書を指してはならない（MUST NOT）: develop の `SKILL.md` の (1) の spawn の行と「モデル」の役割表・`references/roles/spec-reviewer.md`・`references/decision-criteria.md` の残量モード表・pr-review-gate の `stages/triage.md`・`plugins/dev-workflow/references/model-tiers.md`・`plugins/dev-workflow/README.md`。

#### Scenario: 表が 1 か所にある

- **WHEN** `references/pre-classification.md` と `worker/` の 4 本と索引を読む
- **THEN** 事前分類表の 4 行は `pre-classification.md` にだけある

#### Scenario: 参照元が新しい置き場所を指す

- **WHEN** 上に挙げた参照元の、事前分類に触れる行を読む
- **THEN** どれも `pre-classification.md` を指し、事前分類について `roles/worker.md` や `roles/worker/` の指示書を指す行が無い

## REMOVED Requirements

### Requirement: 既存要件が worker.md に置いた内容は移し先のファイルを指す

**Reason**: 他の要件の「worker.md」の名指しを移し先のファイル名で直接書き直したため、読み替えの対応表の正本は要らない。否定の形の要件（特定の記述が無いこと）が掛かる範囲は、各要件が `references/roles/worker/` の 4 本などと直接書く

**Migration**: 他の要件が移し先のファイル名で直接書き直されたので、読み替えの規則は要らない。
