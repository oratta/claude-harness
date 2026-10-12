## ADDED Requirements

### Requirement: CI 雛形のジョブは上限時間を持たなければならない

`plugins/infra/templates/workflows/ci.yml.template` の `test` ジョブと、`plugins/infra/templates/workflows/weekly-full.yml.template` の `full` ジョブは、正の整数の `timeout-minutes` を持たなければならない。`timeout-minutes` の行の直前に連続するコメント行のどれかに、決め方として「約 2 倍」（普段の所要時間の約 2 倍）を書かなければならない。This requirement MUST be satisfied.

#### Scenario: ci.yml.template の test ジョブに上限がある

- **WHEN** `ci.yml.template` の `jobs.test` を YAML として読む
- **THEN** `timeout-minutes` は正の整数でなければならない

#### Scenario: weekly-full.yml.template の full ジョブに上限がある

- **WHEN** `weekly-full.yml.template` の `jobs.full` を YAML として読む
- **THEN** `timeout-minutes` は正の整数でなければならない

#### Scenario: 決め方がコメントにある

- **WHEN** 両雛形で `timeout-minutes` の行の直前に連続するコメント行を読む
- **THEN** そのどれかに「約 2 倍」の文字列がなければならない

### Requirement: infra-setup の SKILL.md は上限時間の決め方と既存リポジトリへの反映のしかたを書かなければならない

`plugins/infra/skills/infra-setup/SKILL.md` は、上限時間の決め方（普段の所要時間の約 2 倍）と、既に雛形から CI を入れたリポジトリへ上限時間を反映する手順（手で `timeout-minutes` を書き足すか、infra-setup を再実行するか、どちらを勧めるか）を書かなければならない。This requirement MUST be satisfied.

#### Scenario: SKILL.md に決め方と反映のしかたがある

- **WHEN** `SKILL.md` の `timeout-minutes` を含む節を読む
- **THEN** その節に、「約 2 倍」と、`ci.yml` と `weekly-full.yml` の両方へ手で書き足すことを勧める文と、再実行で `weekly-full.yml` が確認なしで書き直される旨の文（「確認なし」を含む）がなければならない
