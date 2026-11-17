# Tasks

## 1. テスト（先に書いて、ci.yml を直す前の状態で落ちることを確かめる）

- [x] 1.1 `tests/ci-bats-shards.bats` に、分けたジョブの固定を確かめる関数 `check_bats_pin <ci.yml>` を足す（`runs-on:` が `ubuntu-<数字>.<数字>` の 1 行、`apt-get install` の行に `bats=<版>`、ステップ名 `install bats (<版>)` の版が等しい。読めない形は失敗）。既存のヘルパー `job_block` / `shard_job_ids` / `rewrite_ci` を使う。確認: 直す前の `ci.yml`（`runs-on: ubuntu-latest`）に当てると失敗する。触る範囲: tests/ci-bats-shards.bats:116-205（`shard_job_ids` と `check_shard_matrix` / `check_result_job` の並び。その後ろに足す）
- [x] 1.2 「2. ci.yml の matrix と、結果をまとめるジョブ」の節に、このリポジトリの `ci.yml` が `check_bats_pin` を通るテストと、`runs-on: ubuntu-latest`・式の `runs-on`・版の無い `bats`・ステップ名と版のずれた写しがそれぞれ落ちるテストを足す。ファイル冒頭の説明（1-21 行）に固定の検査を 1 行足す。確認: `scripts/test.sh ci-bats-shards` で、写しが落ちるテストは ok、実物のテストは（2 の前なので）not ok。触る範囲: tests/ci-bats-shards.bats:1-21、tests/ci-bats-shards.bats:408-511（節 2。`ci.yml: the auto-merge invariants run exactly once` の後ろに足す）

## 2. ci.yml

- [x] 2.1 `test` ジョブの `runs-on: ubuntu-latest` を `runs-on: ubuntu-24.04` にする（`lint` と `test-result` は `ubuntu-latest` のまま）。`bats=1.10.0-1` とステップ名は変えない。確認: `scripts/test.sh ci-bats-shards` が全件 ok、`scripts/test-auto-merge-workflow.sh` が exit 0。触る範囲: .github/workflows/ci.yml:87-117
- [x] 2.2 bats を入れる手順の上のコメント（107-111 行）を、ランナーの版も固定していること・版を上げるときは `runs-on`・`bats=`・ステップ名の 3 か所を一緒に直すこと（そろっていることは `tests/ci-bats-shards.bats` が確かめる）・ubuntu-24.04 のランナーが外されたら落ちて気づくことに書き換える。冒頭の「前提パッケージ」（28-30 行）を、lint は `ubuntu-latest`、bats のジョブは `ubuntu-24.04` で、どちらも shellcheck / jq / node / python3 がプリインストール済みである旨に直す。確認: 差分を読み、コメントに `ubuntu-latest` の切り替えで版が消えた経緯（issue #1659）が書かれている。触る範囲: .github/workflows/ci.yml:28-30、.github/workflows/ci.yml:104-115

## 3. 確かめ

- [x] 3.1 `scripts/lint.sh` と `scripts/test.sh ci-bats-shards` が通ることを確かめる
- [ ] 3.2 PR の CI で、分けたジョブ 4 つの `install bats (1.10.0-1)` が成功し、`gh run view <run> --log` に `was not found` が出ず、`bats suites` が bats の結果で緑か赤になることを確かめる（AC1）

## Workflow follow-up

- マージ後の main の CI で同じこと（AC1 の main 側）を確かめる
- change を archive する（`ci-bats-shards` の spec に要件が 1 つ足される）
