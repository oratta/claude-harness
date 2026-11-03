## Why

infra-setup が配る CI の雛形（`plugins/infra/templates/workflows/ci.yml.template`）には、ジョブの上限時間（`timeout-minutes`）が無い。上限が無いと固まったジョブが 1 本 360 分まで走る。flatmate では 2026-10-01 に 5 本が 1〜3 時間走り続け、`timeout-minutes: 40` を足して対処した（genetta-inc/flatmate#1186）。雛形から CI を入れたリポジトリ（suimei など）は同じ Mac のランナーを共有しており、同じ事故が起こりうる。

## What Changes

- `ci.yml.template` の `test` ジョブに `timeout-minutes` を置く。値は雛形に数値で直書きし、利用者が書き換える。コメントで決め方（普段の所要時間の約 2 倍）を書く
- `weekly-full.yml.template` の `full` ジョブにも `timeout-minutes` を置く（テストと audit を走らせるため）
- `infra-setup` の `SKILL.md` に、上限時間の決め方と、既に雛形から CI を入れたリポジトリへの反映のしかたを書く
- `plugins/infra/tests/` の bats に、両雛形の上限時間を検査するテストを足す

範囲外: セルフホスト時の取り残しの掃除（#994）、既存リポジトリへの反映そのもの。

## Capabilities

### New Capabilities
- `infra-ci-job-timeout`: infra の CI 雛形が、ジョブの上限時間を持ち、その決め方と既存リポジトリへの反映のしかたを案内する要件

### Modified Capabilities

なし

## Impact

- `plugins/infra/templates/workflows/ci.yml.template`
- `plugins/infra/templates/workflows/weekly-full.yml.template`
- `plugins/infra/skills/infra-setup/SKILL.md`
- `plugins/infra/tests/infra-fixes.bats`（または同ディレクトリの新規 bats）
- 常時注入の予算に効く `description` などの増減: なし
