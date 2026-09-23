## MODIFIED Requirements

### Requirement: 実モデル受け入れと回帰を残す
実装は `codex-standard`、`codex-economy`、`hybrid-standard` の各組み込みセットで仕様作成、独立仕様レビュー、実装、独立実装レビューを実モデルで一件完走し、各役割の要求と取得できた実効 model/effort、account、executor、job/thread/turn ID、対象 HEAD を PR gate の動作確認に記録しなければならない（MUST）。未観測の実効設定や失敗を成功と扱ってはならない（MUST NOT）。

#### Scenario: 三つの組み込みセットの実機証拠を検査する
- **WHEN** coordinator が各組み込みセットの実行証跡を回収する
- **THEN** 別 job/thread の独立レビューと実効設定の観測元を確認でき、実効値が未観測または要求と異なる場合はその受け入れを未達と報告する

#### Scenario: ローカル回帰を実行する
- **WHEN** `scripts/test.sh` を引数なしで実行する
- **THEN** worker の開始前拒否/両RPC、develop の工程不変/pending固定/旧retry/継続v1-v2を fixture で検証し、Python 回帰はリポジトリ直下の `tests/python-suites.bats` 経由でファイル名を絞らずに全件検出される
