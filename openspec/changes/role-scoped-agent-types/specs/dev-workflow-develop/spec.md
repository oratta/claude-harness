## ADDED Requirements

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

## MODIFIED Requirements

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

### Requirement: 前提環境を明記する
SKILL.md は「前提」節として、Agent ツール（`model` 明示・名前付き spawn・`isolation: "worktree"`・W は `subagent_type: dev-workflow:worker`、G は `subagent_type: dev-workflow:gate-runner`）と SendMessage、`gh`（issue / PR コメントとラベル、issue dependencies API）、openspec CLI（W は CLI だけで仕様化経路を進め、経路の有無は `openspec --version` で決める。opsx コマンドは本体や主が対話で使う道具で、W の経路の有無を決めない。CLI が無ければ仕様化経路が発生しない）、Codex CLI（無ければ G が `needs-reviewer` に縮退）、`orca` コマンド（エピックの子を Orca の子ワークツリーで独立セッションとして起動する。無いとき、または本体が Orca 管理外のワークツリーにいるときは、エピックをサブエージェント方式で回す）を列挙しなければならない（MUST）。

#### Scenario: 前提節がある
- **WHEN** SKILL.md の「前提」節を読む
- **THEN** Agent / SendMessage / gh / openspec CLI / Codex CLI / orca とそれぞれ無いときの縮退が書かれ、Agent の行に W と G の種別が書かれ、openspec の行に W の経路の有無を `openspec --version` で決めることが書かれ、orca の行には Orca 管理外のワークツリーにいるときもサブエージェント方式になることが書かれている

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
