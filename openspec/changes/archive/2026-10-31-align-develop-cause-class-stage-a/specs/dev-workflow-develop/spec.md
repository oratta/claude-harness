## MODIFIED Requirements

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

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker/`（W の指示書。`common.md`・`spec.md`・`implement.md`・`finish.md` の 4 本）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker/spec.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）を、`worker/common.md` は仕様レビュー結果の記録書式を、`references/pre-classification.md` は「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。事前分類表の「1 周目」列は**実行役（W）の上限を `opus` とし、`fable` 行を持ってはならない**（MUST NOT。4 分類のいずれに当たっても W は `opus` 止まりで、聖域パスの `opus` は据え置き）。表には、読んで判断する役（R1・G が要求するレビュアー）が `fable` 相当の分類に当たるときは `subagent_type: dev-workflow:decider` で spawn し、`general-purpose` に `model: fable` を付けないことを明記しなければならない（MUST）。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担うことを書く（SHALL）。`worker/common.md` の return には「指示のどこまでやって、どこで何が起きたか」を含める義務を書かなければならない（MUST。決める役の入力契約になるため）。

`spec-reviewer.md` は 6 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合・守備範囲の明記）と、既定 2 周と 2 周目以降の周の終わりに直し方の判定を通して続ける規則を含む（MUST。判定役・入力・書式の正本は `references/fix-check.md` で、`spec-reviewer.md` は規則を書いて正本を指す）。観点の中身の正本は `dev-workflow-spec-review` とする（SHALL）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出／段 A だけ（昇格なし））を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

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

