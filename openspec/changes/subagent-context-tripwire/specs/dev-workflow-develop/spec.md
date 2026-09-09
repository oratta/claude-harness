## ADDED Requirements

### Requirement: コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く

コンテキスト計測の規則の本文——2 経路（本体が再開前に測る／起動の途中で hook が測る）・閾値の環境変数（`DEV_WORKFLOW_CONTEXT_CAP`＝通知、`DEV_WORKFLOW_CONTEXT_HARD_CAP`＝強制停止、`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`＝全解除）・通知を受けたときの振る舞い・強制停止中にできること・return の 1 行目の書き分け——は、`references/decision-criteria.md`「コンテキスト上限」の節に置かなければならない（MUST）。

`skills/develop/SKILL.md`、`references/roles/worker.md`、`references/roles/gate-runner.md`、`templates/escalation-tripwires.md` は、その節への**ポインタと、その役割固有の動作だけ**を書かなければならない（MUST）。閾値の数値・環境変数名・通知や強制停止の振る舞いを言い換えて再掲してはならない（MUST NOT）。同じ規則を複数のファイルに言い換えて置くと、次に閾値や振る舞いが変わったときにどれかが取り残されるためである。

#### Scenario: 規則の本文が decision-criteria.md にある

- **WHEN** `references/decision-criteria.md` のコンテキスト上限の節を読む
- **THEN** 2 経路・3 つの環境変数・通知時と強制停止時の振る舞い・return の 1 行目の書き分けが、そこだけで完結して書かれている

#### Scenario: 他の面はポインタだけ

- **WHEN** `SKILL.md` / `references/roles/worker.md` / `references/roles/gate-runner.md` / `templates/escalation-tripwires.md` を読む
- **THEN** `references/decision-criteria.md`「コンテキスト上限」への参照があり、閾値の数値や環境変数名の再掲が無い

### Requirement: 途中停止したときの return の 1 行目

途中計測で工程を締めるとき、W / G が return の 1 行目に書く申告（#253 の規約）は次のとおりでなければならない（MUST）。

- **強制停止**（`DEV_WORKFLOW_CONTEXT_HARD_CAP` 超でツールを拒否された）で止まった場合は、成果を書いていても必ず `工程中断:` とする（MUST）。拒否された時点で予定していた作業が残っているため。
- **通知**（`DEV_WORKFLOW_CONTEXT_CAP` 超）を受けて締める場合は、そのとき進めていた tasks グループの項目がすべて完了していれば `工程完了:`、1 つでも残っていれば `工程中断:` とする（MUST）。

この区別が要るのは、`工程完了:` が手渡しの条件として使われており、手渡し先の W / G が未コミット差分と残作業を先に確認しなければならないのは中断のときだけだからである。判定は「そのとき進めていた tasks グループの項目がすべて済んでいるか」だけで行い、他の材料を要求してはならない（MUST NOT）。

#### Scenario: 強制停止は常に工程中断

- **WHEN** `references/decision-criteria.md` のコンテキスト上限の節を読む
- **THEN** 強制停止で止まった場合は成果があっても `工程中断:` にする、と書かれている

#### Scenario: 通知は tasks の残りで決める

- **WHEN** 同じ節を読む
- **THEN** 通知を受けて締める場合は、そのとき進めていた tasks グループが全部済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:` にする、と書かれている

### Requirement: 手渡し先は未コミット差分を先に確認する

手渡しで起こされた W / G の指示書は、前任が途中停止で return した可能性があるため、再出発の前に作業ツリーの未コミット差分（`git status` / `git diff`）を確認しなければならない（MUST）と書かなければならない。これは `references/roles/worker.md` の手渡しの節に置く役割固有の動作であり、閾値や振る舞いの再掲ではない。

#### Scenario: 手渡し先が未コミット差分を先に見る

- **WHEN** `references/roles/worker.md` の手渡しの節を読む
- **THEN** 前任が途中停止した可能性があるので `git status` / `git diff` で未コミット差分を先に確認する、と書かれている

### Requirement: 強制停止に当たった G のレビュー結果は本体が代理投稿する

強制停止中は `Bash` が許可した git サブコマンドだけに絞られるため `gh pr comment` も拒否され、G（ゲート実行者）が強制停止に当たるとレビュー結果を記録先に投稿できないまま return することになる。この経路を手順書に書いておかなければならない（MUST）。

`references/roles/gate-runner.md` は、この場合に G がレビュー結果を return の本文に含めて `工程中断:` で返すことを書かなければならない（MUST）。`skills/develop/SKILL.md` は、本体が `工程中断:` の return を受け取ったとき、そこに含まれるレビュー結果を**本体が記録先に代理投稿する**ことを書かなければならない（MUST）。R1 の仕様レビューを本体が代理投稿している（`subagent_type: dev-workflow:decider` は `gh` を実行できない）のと同じ経路である。

#### Scenario: G は結果を return に載せて返す

- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** 強制停止で `gh pr comment` が拒否されたらレビュー結果を return の本文に含めて `工程中断:` で返す、と書かれている

#### Scenario: 本体が代理投稿する

- **WHEN** `skills/develop/SKILL.md` の本体の手順を読む
- **THEN** `工程中断:` の return にレビュー結果が含まれていたら本体が記録先に代理投稿する、と書かれている
