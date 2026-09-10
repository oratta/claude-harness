## MODIFIED Requirements

### Requirement: 1 ループは W→R1→W→G の順で回る
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 → (1) W が仕様化判断の記録・分割判定・`/opsx:ff` まで行い return（仕様化しない判定なら (3) へ直行）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（2 周キャップ。超えたら `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) apply（TDD）・verify まで行って return、本体が計測してから (3b) archive・PR を Ready に（または作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → (4) G が pr-review-gate の手順 1〜5 を実行し passed / failed / 保留を return。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら実行役を `opus` に上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く。**W を `fable` で再開してはならない**（MUST NOT。実行役の上限は `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。修正後は G を再開して差分再レビュー（2 周）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

worktree は本体が用意する（SHALL）: 本体が既に対象専用の worktree にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。W は自分で worktree を切らない（MUST NOT。セットアップは worktree プラグインの hooks が担う）。**W / G を `isolation: "remote"` で起こしてはならない**（MUST NOT）。強制停止に当たったサブエージェントの未コミット差分は本体が確認して commit する設計（下の「強制停止で止まった作業ツリーは本体が引き取る」Requirement）だが、`remote` 隔離は本体から見えない環境で動くため、そこで強制停止に当たると作業がそのまま失われる。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ 2 周キャップがある

#### Scenario: (3) は 2 段に分かれて書かれている
- **WHEN** SKILL.md の 1 ループの (3) を読む
- **THEN** (3a) と (3b) が別々の return として並び、(3a) に apply（TDD）と verify が、(3b) に archive・PR・仕様宣言が入っている

#### Scenario: W / G は remote 隔離で起こさない
- **WHEN** SKILL.md の spawn の記述を読む
- **THEN** W / G を `isolation: "remote"` で起こしてはならないと書かれている

#### Scenario: G の failed は片方だけ上げて W の再開に戻る
- **WHEN** G が failed を return する
- **THEN** SKILL.md は実装品質起因のときだけ原因分類に応じて実行役を `opus` に上げるか決める役を `dev-workflow:decider` で立てるかの一方だけを行い、仕様が曖昧・レビュアーの誤検出ではモデルを上げず、W を `fable` にはせず、G を再開して差分再レビューするよう指示している

#### Scenario: decider として起こした R1 の結果は本体が投稿する
- **WHEN** SKILL.md の (2) の記述を読む
- **THEN** R1 が `dev-workflow:decider` の場合は本体が return を同じ書式で記録先に代理投稿すると書かれている

## ADDED Requirements

### Requirement: W の (3) は 2 回の return に分かれる
本体がサブエージェントのコンテキスト量を測れるのは、W を SendMessage で再開する直前（＝ W が return した直後）だけである。したがって return の区切りの数がそのまま計測点の数になる。W の実装以降の工程 (3) は、次の 2 つの return に分けなければならない（MUST）。

- **(3a) 実装＋verify**: `/opsx:apply`（または直叩きの TDD）と `/opsx:verify` までを行い、`工程完了: 実装＋verify` を 1 行目にして return する
- **(3b) archive＋PR＋仕様宣言**: `/opsx:archive`（仕様化した場合）・PR を Ready に切り替えるか作成すること・仕様宣言を PR コメントに書くことを行い、`工程完了: archive＋PR＋仕様宣言` を 1 行目にして return する

境界は archive の手前に置き、verify は (3a) 側に含めなければならない（MUST）。verify の失敗は実装への巻き戻しであり、実装と verify を別の担い手に割ると手渡し直後に巻き戻しが起きるためである。

**(3) をこれより細かく（`tasks.md` の項目単位・「実装／verify／archive／PR／仕様宣言」の 5 段など）分割してはならない（MUST NOT）。** 手渡しが 1 回起きるたびに、後任は指示書と正本の節を読み直し、記録先を取り直し、`git status` / `git diff` でファイルの現状を確認する固定分を払う。この固定分は工程の大きさに依存しないため、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。また区切りが実装の途中に落ちると、後任は Red のまま止まったテストから再出発することになり、前任の設計意図を再発明する危険が最も高い地点で交代する。

`references/roles/worker.md` は (3a) と (3b) それぞれの return に何を書くかを列挙しなければならない（MUST）。**(3a) の return には、実行したテストコマンドと exit code を含めなければならない（MUST）**。(3b) の担い手は pr-review-gate 手順 5 が照合する動作確認の証拠を書く必要があり、手渡しが起きた場合その証拠は前任の return からしか得られない（後任は前任の履歴を読めない）ためである。

`skills/develop/SKILL.md` は、(3a) の return を受けてから (3b) を指示する SendMessage を送るまでのあいだに、本体が `scripts/subagent-context.sh <W の名前>` を実行してコンテキスト量を測ることを書かなければならない（MUST）。上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本であり、SKILL.md と `worker.md` はその本文を再掲してはならない（MUST NOT）。

#### Scenario: worker.md が (3a) / (3b) の return 内容を列挙している
- **WHEN** `references/roles/worker.md` の実装以降の節を読む
- **THEN** (3a) と (3b) がそれぞれ別の見出し（または別の箇条）として立っており、(3a) の return に実行したテストコマンドと exit code を含める義務が書かれ、(3b) の return に PR 番号と仕様宣言のコメント URL を含める義務が書かれている

#### Scenario: worker.md の工程名が 3 つになっている
- **WHEN** `references/roles/worker.md` のコンテキスト上限と手渡しの節を読む
- **THEN** W が return する工程の単位が「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つとして列挙されている

#### Scenario: SKILL.md が (3a) と (3b) のあいだの計測を指示している
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** (3a) の return のあと (3b) を指示する前に `scripts/subagent-context.sh` で測ると書かれており、上限超のときの扱いは `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を正本として参照している

#### Scenario: タスク単位のさらなる分割は禁止されている
- **WHEN** `references/roles/worker.md` または `skills/develop/SKILL.md` の (3) の記述を読む
- **THEN** (3) を (3a)/(3b) より細かく切らないことと、その理由（手渡しごとの固定分と再オリエンテーションの費用）が書かれている
