## 1. 雛形

- [ ] 1.1 `ci.yml.template` の `test` ジョブに `timeout-minutes: 10` と決め方のコメントを足す 触る範囲: plugins/infra/templates/workflows/ci.yml.template:46-52（`jobs.test`）
- [ ] 1.2 `weekly-full.yml.template` の `full` ジョブに `timeout-minutes: 30` と決め方のコメントを足す 触る範囲: plugins/infra/templates/workflows/weekly-full.yml.template:26-30（`jobs.full`）

## 2. SKILL.md

- [ ] 2.1 「CI/CD 構成の 2 軸」節に、上限時間の決め方と既存リポジトリへの反映のしかた（手で書き足す推奨・再実行の注意）を足す 触る範囲: plugins/infra/skills/infra-setup/SKILL.md:257-270

## 3. テスト

- [ ] 3.1 両雛形の `timeout-minutes` が正の整数であること、直上に「2 倍」のコメントがあること、SKILL.md に決め方と反映のしかたがあることを検査する bats を足す 触る範囲: plugins/infra/tests/infra-fixes.bats（末尾に追記。または新規 plugins/infra/tests/ci-timeout.bats）
- [ ] 3.2 `scripts/test.sh infra` が exit 0 になることを確かめる
