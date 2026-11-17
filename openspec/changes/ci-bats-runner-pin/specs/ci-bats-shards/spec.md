## ADDED Requirements

### Requirement: bats のジョブはランナーの版と bats の版をそろえて固定する

`.github/workflows/ci.yml` の分けた bats のジョブは、`runs-on:` に `ubuntu-<数字>.<数字>` の形でランナーの版を 1 行で書き、`ubuntu-latest` や式を使ってはならない（MUST NOT）。bats は `apt-get install` に `bats=<版>` の形で版を書いて入れ、そのステップ名は `install bats (<版>)` で同じ版を示さなければならない（MUST）。書く版は、そのランナーの apt にある版でなければならない（MUST）。

#### Scenario: このリポジトリの ci.yml の固定がそろっている

- **WHEN** `scripts/test.sh ci-bats-shards` を実行する
- **THEN** 分けたジョブの `runs-on:` が `ubuntu-<数字>.<数字>` の形で、`bats=<版>` の版とステップ名 `install bats (<版>)` の版が等しいことを確かめるテストが `ok` になる

#### Scenario: ランナーの版を固定しない写しは検知される

- **WHEN** 分けたジョブの `runs-on:` を `ubuntu-latest` にした `ci.yml` の写しと、`${{ vars.CI_RUNNER }}` のような式にした写しのそれぞれに、固定を確かめる検査を当てる
- **THEN** どちらも検査が失敗する

#### Scenario: bats の版を書かない写しと、ステップ名の版がずれた写しは検知される

- **WHEN** `bats=<版>` を `bats` だけにした `ci.yml` の写しと、`bats=<版>` だけを別の版に書き換えてステップ名をそのままにした写しのそれぞれに、固定を確かめる検査を当てる
- **THEN** どちらも検査が失敗する

#### Scenario: CI で bats を入れる手順が通る

- **WHEN** この変更の PR と、マージ後の main で CI が走る
- **THEN** 分けたジョブ 4 つの `install bats` の手順が成功し、`gh run view <run> --log` に `was not found` が出ず、`bats suites` のチェックが bats の結果で決まる
