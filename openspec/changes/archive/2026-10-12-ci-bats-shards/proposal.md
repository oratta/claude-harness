## Why

CI の `bats suites` ジョブは、追跡下の全 `*.bats`（133 ファイル・約 3,100 件）を bats 1 回の呼び出しで順番に実行しており、PR を出してから結果が出るまで 9〜11 分かかる（2026-10-12 の run 38197344175 ではテストの実行だけで 8 分 53 秒）。遅いテストに偏りが無く個別に直しても縮まないうえ、テストは増え続けている（2026-09-03 の 990 件から 3 倍）。記録先は issue #990。

## What Changes

- `scripts/test.sh` に「全体を N 個に分けたうちの k 番目だけ実行する」指定（環境変数 `TEST_SHARD=k/N`）を足す。未指定なら今と同じ全件を実行する
- `.github/workflows/ci.yml` の bats のジョブを、`TEST_SHARD` を変えた複数のジョブ（matrix。出発点は 4）に分けて同時に走らせる
- 分けたジョブの結果をまとめ、`bats suites` という名前で報告するジョブを 1 つ置く。分けたジョブが 1 つでも成功以外（失敗・取り消し・スキップ）なら、このジョブは失敗する。`auto-merge.yml` の `REQUIRED_CHECKS`（`shellcheck` / `bats suites`）は変えない
- `scripts/test-auto-merge-workflow.sh` の「`REQUIRED_CHECKS` と `ci.yml` の全ジョブ名が完全一致する」検査を、「`ci.yml` のどのジョブも、必須チェックそのものか、必須チェックのジョブが `needs` で待つジョブである」に置き換える（分けたジョブを足すと今の検査は落ちる）
- いま bats のジョブの中で走っている `auto-merge workflow invariants` のステップ（`scripts/test-auto-merge-workflow.sh`）を `shellcheck` のジョブへ移す（分けたジョブごとに重ねて走らせない）
- 分け方に漏れと重なりが無いこと、`ci.yml` の分割数の整合、置き換えた検査の振る舞いを確かめる bats スイートを足す

## Capabilities

### New Capabilities

- `ci-bats-shards`: `scripts/test.sh` の分割指定、CI で bats を複数ジョブに分けて走らせる構成、結果をまとめるジョブ、必須チェックと `ci.yml` のジョブの対応の検査

### Modified Capabilities

（なし。`test-runner-python-suites` は「job 名 `bats suites` を変えない」ことを求めており、まとめるジョブがその名前を引き継ぐので要件は変わらない。`dev-workflow-automerge-templates` は配布テンプレートの要件で、今回はテンプレートに触れない）

## Impact

- `.github/workflows/ci.yml`（聖域パス。この PR は自動マージの対象外で、人間がマージする）
- `scripts/test.sh`、`scripts/test-auto-merge-workflow.sh`（このリポジトリの写し。`plugins/dev-workflow/templates/auto-merge/` のテンプレートは既にこのリポジトリの写しと内容が異なり、今回は変えない）
- `tests/ci-bats-shards.bats`（新規）、`docs/auto-merge.md`（`ci.yml` を変えるときの注意の書き換え）
- ローカルで `scripts/test.sh` を使う手順は変わらない
- チェックの一覧に分けたジョブのぶんの行が増える。必須チェックの名前は変わらない
