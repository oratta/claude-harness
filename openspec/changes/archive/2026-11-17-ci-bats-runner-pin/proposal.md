# Proposal

## Why

2026-11-17 に GitHub の `ubuntu-latest` が ubuntu-26.04（runner image 20261111.196.1）に上がり、`.github/workflows/ci.yml` が `apt-get install bats=1.10.0-1` で固定していた版が apt から消えた（1.10.0-1 は ubuntu-24.04 の universe の版で、26.04 の版は 1.13.0-1）。bats を入れる手順が `E: Version '1.10.0-1' for 'bats' was not found` で落ち、テストを 1 本も走らせないまま必須チェック `bats suites` が全ブランチで赤になって、どの PR もマージできない（issue #1659。実例 https://github.com/oratta/claude-harness/actions/runs/44037505980 ）。

版を固定している理由（ランナーのイメージ更新で bats が黙って上がると、テストの落ち方が変わったときに「自分の変更か bats か」を切り分けられない）は今も有効なので、固定は外さない。固定した版が「どのランナーの apt にあるか」が `ubuntu-latest` の上がり方に左右されていたことが原因なので、bats の版とランナーの版をそろえて固定する。

## What Changes

- `ci.yml` の bats を回すジョブ（`test`。`bats shard k/4` の 4 つ）の `runs-on` を `ubuntu-latest` から `ubuntu-24.04` に固定する。bats の版は `bats=1.10.0-1` のまま変えない
- `ci.yml` の冒頭と bats を入れる手順の上のコメントを実態に合わせる（bats のジョブはランナーの版も固定していること、版を上げるときは `runs-on` と `bats=` とステップ名の 3 か所を一緒に直すこと、ubuntu-24.04 のランナーが GitHub から外されたら落ちて気づくこと）
- `lint`（`shellcheck`）と `test-result`（`bats suites`）のジョブは `ubuntu-latest` のまま変えない
- `tests/ci-bats-shards.bats` に、bats のジョブのランナーと bats の版が固定されていることを確かめるテストと、固定が外れた写しを落とすテストを足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `ci-bats-shards`: CI の bats のジョブについての capability に、「bats のジョブはランナーの版と bats の版を固定する」要件を足す（ADDED。既存の要件は変えない）

## Impact

- `.github/workflows/ci.yml`（聖域パス。マージは人間）
- `tests/ci-bats-shards.bats`
- 必須チェック名（`shellcheck` / `bats suites`）と `auto-merge.yml` の `REQUIRED_CHECKS` は変わらない
- CI のみの変更で `plugins/` のどのプラグインにも当たらないため、`plugins/<name>/changes/` の記録は書かない（CI だけを変えた #990 の PR #1010 と同じ扱い）
