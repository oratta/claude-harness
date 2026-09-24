## MODIFIED Requirements

### Requirement: marketplace.json から discord のエントリを外す
`.claude-plugin/marketplace.json` の `plugins[]` は `name` が `discord` のエントリを持ってはならない（MUST NOT）。`bundles[]` のどの `plugins[]` にも `discord` を含めてはならない（MUST NOT）。他のプラグインのエントリ（`description` を含む）は変えてはならない（MUST NOT）。

#### Scenario: plugins[] に discord が無い
- **WHEN** `jq -e '[.plugins[].name] | index("discord") == null' .claude-plugin/marketplace.json` を実行する
- **THEN** exit 0 で終わる

#### Scenario: どのバンドルにも discord が無い
- **WHEN** `jq -e '[.bundles[]?.plugins[]?] | index("discord") == null' .claude-plugin/marketplace.json` を実行する
- **THEN** exit 0 で終わる

#### Scenario: 整合テストが通る
- **WHEN** `bats tests/marketplace-sync.bats` を実行する
- **THEN** 全件 pass する
