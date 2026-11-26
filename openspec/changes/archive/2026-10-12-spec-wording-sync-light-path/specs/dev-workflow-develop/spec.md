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

### Requirement: 実行モードと unmanned の責務分割
SKILL.md は実行モード表（interactive / unmanned）を持ち、unmanned（`--unmanned`。loop-dev-agent の憲法 Step 3 から呼ばれる）では次を規定しなければならない（MUST）: develop の本体は憲法のメイン自身が務め、W / R1 をメインが spawn する。worktree は憲法側が用意したものを使う。1 ループのうち (0)〜(3) を回し、(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。(4) の G は unmanned では起こさず、憲法 Step 1（レビューモード）が次サイクル以降で担う（1 サイクル 1 仕事を維持）。複数 change に割れた場合は子 issue を作って `blocked_by` で順序付けし、そのサイクルを終える。仕様化判断の記録と仕様レビューは unmanned でも免除しない（MUST）。文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）で R1 を起こさないのは、モードによる免除ではなく、interactive と同じ対象・同じ当てる条件で unmanned にも当てる（SHALL）。

#### Scenario: unmanned でも文言合わせの通し方は同じ条件で当たる
- **WHEN** SKILL.md の実行モードの節を読む
- **THEN** 仕様化判断の記録と仕様レビューを unmanned でも免除しないことと、文言合わせの通し方は interactive と同じ条件で unmanned にも当てることが書かれている

#### Scenario: unmanned では G を起こさない
- **WHEN** SKILL.md の実行モード表を読む
- **THEN** unmanned では憲法のメインが本体を務めて W / R1 を spawn し、(3) で Draft PR と `agent-review:pending` まで W が行い、G は憲法 Step 1 に委ねると書かれている

### Requirement: W の仕様化経路は openspec CLI だけで進める
`dev-workflow:worker` は `Skill` を持たないので、W は仕様化・実装の検証・archive を openspec CLI で行わなければならない（MUST）。仕様化は `openspec new change` と artifact の直書き（雛形と書き方の指示は `openspec instructions <artifact> --change <name>`、依存順は `openspec status --change <name>` で得る）、実装の検証は `openspec validate <change> --strict` と `tasks.md` のチェックボックスの確認、archive は `openspec archive <change>` で行う（SHALL）。工程の区切り（(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言）は変えない（SHALL）。R1 の仕様レビューも、文言合わせの通し方（次の段落）を除いて変えない（SHALL）。

文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）では、change に proposal.md が無いので、W は実装の検証を `openspec validate <change> --type change --strict` で行わなければならない（MUST。`--type change` を付けない形は change を見つけられず `Unknown item` で終了コード 1 になり、`openspec validate --changes --strict` はこの change を検査せずに終了コード 0 を返す）。`tasks.md` が無いのでチェックボックスの確認は行わない（SHALL）。`openspec archive <change>` は見出しが既存の要件名と一致しないとき、何も変えずに終了コード 0 で終わるので、W は archive のあと `openspec/changes/archive/` に change のディレクトリがあることを確かめる（MUST）。`references/roles/worker/implement.md` と `references/roles/worker/finish.md` はこの 2 点を書かなければならない（MUST）。

W の仕様化経路があるかどうかは `openspec --version` が成功するかだけで決めなければならない（MUST）。`.claude/commands/opsx/` の有無で決めてはならない（MUST NOT）。opsx コマンドがあっても openspec CLI が無ければ、W は `仕様化判断: しない` の理由に「openspec 不在」と書いてコード直行する（SHALL）。

`references/roles/worker.md` で `/opsx:` のスラッシュコマンドが出てよいのは、本体や主が対話で `/opsx:*` を使う場面（例: W が来る前に本体や主が `/opsx:ff` で change を作っていた場合）を述べる行だけで、その行は `本体` か `主` の語を含まなければならない（MUST）。W が `/opsx:*` を実行する指示を書いてはならない（MUST NOT）。

#### Scenario: worker.md が CLI の経路で書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/roles/worker.md` を読む
- **THEN** `openspec new change`・`openspec validate`・`openspec archive` を使う手順があり、(3a) の節と (3b) の節に `/opsx:` の文字列が無く、`/opsx:` を含む行はどれも `本体` か `主` の語を含む

#### Scenario: 文言合わせの通し方の検証コマンドが書かれている
- **WHEN** `references/roles/worker/implement.md` の実装と verify の記述と、`references/roles/worker/finish.md` の archive の記述を読む
- **THEN** `implement.md` に文言合わせの通し方では `openspec validate <change-name> --type change --strict` を使うことが書かれ、`finish.md` に archive のあと `openspec/changes/archive/` に change のディレクトリがあることを確かめることが書かれている

#### Scenario: proposal.md の無い change を名前だけで検証する
- **WHEN** `specs/<capability>/spec.md` だけを持つ change に `openspec validate <change> --strict` を実行する
- **THEN** `Unknown item` と出て終了コード 1 で終わり、`--type change` を付けると差分が検査されて正しい差分なら終了コード 0 で終わる

#### Scenario: 経路の有無を CLI だけで決める
- **WHEN** `worker.md` の仕様化判断の節と、`develop/SKILL.md` の前提の表の openspec の行を読む
- **THEN** W の経路の有無を `openspec --version` で決めることが書かれ、`worker.md` に `ls .claude/commands/opsx/` による検出が無い

