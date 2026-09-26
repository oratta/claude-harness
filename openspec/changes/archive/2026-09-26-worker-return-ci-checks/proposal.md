## Why

PR #489 では、G がゲートを合格にしたあとで CI の shellcheck が落ち、W・レビュー・G をもう 1 周回した（W と G の組で 3〜5 ドルと数十分のコスト）。`worker.md` の (3a)「コード直行する場合」手順 5 だけが「テスト・lint・ビルドを実行し」と書き、opsx / openspec CLI の 2 経路には検査を流す手順が無いため、`scripts/test.sh` が shellcheck を含まないこのリポジトリでは W が CI の一部を素通りしていた。develop は他リポジトリでも使うため、コマンド名を固定せず、W が CI の workflow 定義を読んで検査コマンドを拾う形にする。

## What Changes

- `worker.md` の「全経路共通の大原則」（opsx / openspec CLI / コード直行の 3 経路すべてに効く節）に、PR・push で起動する `.github/workflows/*.yml` / `*.yaml` の `run:` ステップを読み、検査コマンドと環境セットアップを判別してすべての検査コマンドを実行する指示を追加する
- `worker.md` の (3a) の return に書くことに、拾った検査コマンド一覧・各 exit code（未導入の検査は未導入と明記）を含める義務を追加する（既存の「実行したテストコマンドと exit code」の記述を、CI 由来のコマンド収集に具体化する）
- 拾った検査結果を `gate-runner.md` の照合（pr-review-gate 手順）に組み込むかどうかは design で判断する（Non-Goal とする）

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `dev-workflow-develop`: `references/roles/worker.md` の (3a) 手順 5 と (3a) の return の要件を、CI workflow 定義からの検査コマンド収集・全件実行・exit code 記録に変更する

## Impact

- `plugins/dev-workflow/skills/develop/references/roles/worker.md`
- 場合により `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`
- `openspec/specs/dev-workflow-develop/spec.md`（Modified Capability の delta spec）
