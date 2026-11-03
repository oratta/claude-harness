## 1. 雛形

- [x] 1.1 `ci.yml.template` の `test` ジョブに `timeout-minutes: 10` と決め方のコメントを足す 触る範囲: plugins/infra/templates/workflows/ci.yml.template:44-49（`jobs.test`）
- [x] 1.2 `weekly-full.yml.template` の `full` ジョブに `timeout-minutes: 30` と決め方のコメントを足す 触る範囲: plugins/infra/templates/workflows/weekly-full.yml.template:29-31（`jobs.full`）

## 2. SKILL.md

- [x] 2.1 「CI/CD 構成の 2 軸」節に、上限時間の決め方と既存リポジトリへの反映のしかた（`ci.yml` の `test` ジョブと `weekly-full.yml` の `full` ジョブの両方に手で書き足すことを推奨。再実行では確認が出るのは `ci.yml` など 5 ファイルで、`weekly-full.yml` は確認なしで書き直されるので、再実行するなら事前に控えを取るか、実行後に `git diff` で確かめる、と注意する）を足す 触る範囲: plugins/infra/skills/infra-setup/SKILL.md:255-270

## 3. テスト

- [x] 3.1 両雛形の `timeout-minutes` が正の整数であること、`timeout-minutes` の行の直前に連続するコメント行のどれかに「約 2 倍」があること（YAML の読み込みは既存の S17 と同じ `ruby -ryaml` で行う）、SKILL.md の `timeout-minutes` を含む節に「約 2 倍」・`weekly-full.yml`・「確認なし」があることを検査する bats を足す 触る範囲: plugins/infra/tests/infra-fixes.bats（末尾に追記。または新規 plugins/infra/tests/ci-timeout.bats）
- [x] 3.2 `scripts/test.sh infra` が exit 0 になることを確かめる
