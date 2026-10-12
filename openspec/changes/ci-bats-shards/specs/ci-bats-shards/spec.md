## ADDED Requirements

### Requirement: scripts/test.sh は TEST_SHARD で全体を分けた 1 組だけを実行できる

`scripts/test.sh` は、環境変数 `TEST_SHARD=k/N`（k と N は 1 以上の整数で k ≦ N）が与えられたとき、`git ls-files -- '*.bats' ':(exclude)_longruns/'` の一覧の i 番目（1 始まり）のうち `(i − 1) mod N + 1` が k に等しいものだけを対象にしなければならない（MUST）。組の割り当ては、位置引数のフィルタと `TEST_EXCLUDE` を当てる前の一覧に対して決めなければならない（MUST）。割り当てのあとの対象には、既存のフィルタと `TEST_EXCLUDE` をそのまま当てる。

`TEST_SHARD` が未設定か空文字のとき、`scripts/test.sh` は分割せず、この変更の前と同じ対象を実行しなければならない（MUST）。

`TEST_SHARD` が指定されたとき、`scripts/test.sh` は実行前の表示に、どの組を実行しているか（k と N）を含めなければならない（MUST）。

#### Scenario: 全部の組を合わせると全件と一致する

- **WHEN** 追跡下の `.bats` が 7 本ある使い捨てリポジトリで、`TEST_SHARD=1/3`・`2/3`・`3/3` のそれぞれで `scripts/test.sh` を実行し、表示された対象スイートを集める
- **THEN** 集めた一覧に重複が無く、`git ls-files -- '*.bats' ':(exclude)_longruns/'` の 7 本と一致する

#### Scenario: 割り当ては一覧の順番で決まる

- **WHEN** 追跡下の `.bats` が `s1.bats` 〜 `s7.bats` の 7 本ある使い捨てリポジトリで `TEST_SHARD=2/3 scripts/test.sh` を実行する
- **THEN** 対象として表示されるのは `git ls-files` の 2 番目と 5 番目（`s2.bats` と `s5.bats`）だけで、どの組を実行しているか（2 と 3）が表示される

#### Scenario: 未指定なら全件を実行する

- **WHEN** 同じ使い捨てリポジトリで `TEST_SHARD` を設定せずに `scripts/test.sh` を実行する
- **THEN** 7 本すべてが対象として表示され、exit code は 0 になる

#### Scenario: フィルタと組み合わせても割り当ては変わらない

- **WHEN** 同じ使い捨てリポジトリで `TEST_SHARD=2/3 scripts/test.sh s5` を実行する
- **THEN** 対象は `s5.bats` だけになる（フィルタに一致する `s5.bats` は、フィルタなしのときと同じ 2 番目の組に入っている）

#### Scenario: 除外されたスイートは属する組でだけ数えられる

- **WHEN** 同じ使い捨てリポジトリで `TEST_EXCLUDE=s2` を付けて `TEST_SHARD=1/3`・`2/3`・`3/3` のそれぞれを実行する
- **THEN** `skipped by TEST_EXCLUDE` の件数は `2/3` の実行で 1、ほかの 2 つの実行で 0 になる

### Requirement: 不正な TEST_SHARD と空の組は成功にしない

`TEST_SHARD` が `k/N` の形でないとき、k か N が 1 以上の整数でないとき、k が N より大きいとき、`scripts/test.sh` は bats を実行せずに 0 以外の exit code で終わり、受け取った値を含むメッセージを標準エラーに出さなければならない（MUST）。全件の実行に切り替えてはならない（MUST NOT）。

分割の結果、その組の対象が 1 件も無いとき、`scripts/test.sh` は 0 以外の exit code で終わらなければならない（MUST）。

#### Scenario: 形式が不正な値を拒否する

- **WHEN** `TEST_SHARD` に `0/4`・`5/4`・`2`・`a/4`・`1/0`・`1/4/2` のそれぞれを設定して `scripts/test.sh` を実行する
- **THEN** どの場合も exit code が 0 以外で、標準エラーに受け取った値が出て、対象スイートの一覧（`▶ bats suites:`）は表示されない

#### Scenario: 対象が無い組は失敗する

- **WHEN** 追跡下の `.bats` が 2 本の使い捨てリポジトリで `TEST_SHARD=3/3 scripts/test.sh` を実行する
- **THEN** exit code が 0 以外になる

### Requirement: CI は bats を複数のジョブに分け、全部の組で全件を実行する

`.github/workflows/ci.yml` は、`scripts/test.sh` を `TEST_SHARD` の異なる複数のジョブ（matrix）で実行しなければならない（MUST）。matrix の組の番号はちょうど 1 から N までの整数で、各ジョブに渡す `TEST_SHARD` の分母は N に等しくなければならない（MUST）。分けたジョブは、1 つが失敗しても残りを最後まで実行しなければならない（MUST。`fail-fast: false`）。

`ci.yml` が実行する全部の組の対象スイートを合わせたものは、`git ls-files -- '*.bats' ':(exclude)_longruns/'` と重複なく一致しなければならない（MUST）。これを確かめるテストが `scripts/test.sh` の全件実行に含まれなければならない（MUST）。

bats の `--jobs` を使ってはならない（MUST NOT）。

#### Scenario: ci.yml の組の番号と分母がそろっている

- **WHEN** `scripts/test.sh ci-bats-shards` を実行する
- **THEN** `ci.yml` の matrix の組の番号がちょうど 1〜N で、`TEST_SHARD` の分母が N に等しいことを確かめるテストが `ok` になる

#### Scenario: 実物のリポジトリで合計が全件と一致する

- **WHEN** `ci.yml` から読んだ N について、何も実行せず exit 0 する `bats` の代役を PATH の先頭に置き、このリポジトリの `scripts/test.sh` を `TEST_SHARD=1/N` 〜 `N/N` で実行して、表示された対象スイートを集める
- **THEN** 集めた一覧の行数が `git ls-files -- '*.bats' ':(exclude)_longruns/' | wc -l` と等しく、重複が無く、内容が一致する

#### Scenario: 組の番号が欠けた ci.yml は検知される

- **WHEN** matrix の組の番号を 1〜3 にしたまま `TEST_SHARD` の分母を 4 にした `ci.yml` の写しに対して、組の番号と分母を確かめる検査を当てる
- **THEN** 検査が失敗する

### Requirement: 分けたジョブの結果は bats suites という名前のジョブにまとめて報告される

`ci.yml` は、分けたジョブをすべて `needs` で待つジョブを 1 つ持ち、その `name:` は `bats suites` でなければならない（MUST）。このジョブは分けたジョブの結果にかかわらず実行され（`if: always()`）、`needs` のジョブの result がすべて `success` のときだけ成功し、1 つでも `failure`・`cancelled`・`skipped` があれば失敗しなければならない（MUST）。

`.github/workflows/auto-merge.yml` の `REQUIRED_CHECKS` は `shellcheck` と `bats suites` のまま変えてはならない（MUST NOT）。分けたジョブの `name:` は `bats suites` と異なる名前でなければならない（MUST）。

#### Scenario: まとめるジョブの構造

- **WHEN** `scripts/test.sh ci-bats-shards` を実行する
- **THEN** `ci.yml` に `name: bats suites` のジョブがちょうど 1 つあり、そのジョブが分けたジョブを `needs` に持ち、`if: always()` を持ち、`needs` の result を `success` と比べて失敗させるステップを持つことを確かめるテストが `ok` になる

#### Scenario: 1 つの組でテストが落ちると bats suites が失敗する

- **WHEN** 分けたジョブのうち 1 つに入るスイートのテストを 1 件わざと失敗させた PR を作り、CI を走らせる
- **THEN** その組のジョブが failure になり、ほかの組は最後まで走り、`bats suites` のチェックの conclusion が `failure` になって、その PR は自動マージされない

### Requirement: ci.yml の全ジョブは必須チェックか、必須チェックが待つジョブである

`scripts/test-auto-merge-workflow.sh` は、`REQUIRED_CHECKS` と `ci.yml` について次の 3 つをすべて確かめ、1 つでも満たさなければ 0 以外の exit code で終わらなければならない（MUST）。

1. `REQUIRED_CHECKS` の名前それぞれが、`ci.yml` のちょうど 1 つのジョブの `name:` に一致する
2. `ci.yml` のすべてのジョブに `name:` がある
3. `ci.yml` のジョブのうち `name:` が `REQUIRED_CHECKS` に無いものは、`REQUIRED_CHECKS` に名前があるジョブの `needs:` にジョブ ID が挙がっている

`needs:` は 1 行の形（`needs: <id>` か `needs: [<id>, ...]`）で読み、それ以外の形で書かれているときは検査を失敗にしなければならない（MUST）。

`ci.yml` は `scripts/test-auto-merge-workflow.sh` を 1 回の CI につき 1 回だけ、必須チェックのジョブ（`shellcheck`）の中で実行しなければならない（MUST）。

#### Scenario: このリポジトリの ci.yml が通る

- **WHEN** このリポジトリで `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 になる

#### Scenario: 必須チェックにも needs にも入っていないジョブは検知される

- **WHEN** このリポジトリのワークフローと docs を写した木の `ci.yml` に、`name:` が `REQUIRED_CHECKS` に無く、どの必須チェックのジョブの `needs:` にも挙がっていないジョブを 1 つ足し、`AUTOMERGE_TEST_ROOT` をその木に向けて `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 以外になり、出力に足したジョブが分かる情報（ジョブ ID か名前）が含まれる

#### Scenario: 必須チェックの名前に一致するジョブが無いと検知される

- **WHEN** 同じ写しの `ci.yml` で、まとめるジョブの `name:` を `bats suites` 以外に変えて `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 以外になる

#### Scenario: name の無いジョブは検知される

- **WHEN** 同じ写しの `ci.yml` で、分けたジョブの `name:` の行を消して `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 以外になる

#### Scenario: 不変条件の検査は 1 回だけ走る

- **WHEN** `ci.yml` を確認する
- **THEN** `scripts/test-auto-merge-workflow.sh` を実行するステップは `name: shellcheck` のジョブにちょうど 1 つあり、matrix で分けたジョブには無い
