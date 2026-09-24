## MODIFIED Requirements

### Requirement: marketplace.json から 3 プラグインを外す
`.claude-plugin/marketplace.json` の `plugins[]` に `name` が `loops`・`longrun`・`lr` のエントリが存在してはならず（MUST NOT）、`bundles[]` の `all` の `plugins[]` にも 3 名が含まれてはならない（MUST NOT）。残るエントリの `description` は本 change で意図して更新したもの（dev-workflow と参照を直したプラグイン）以外は変えない（エントリの `version` は issue #447 で撤去済み）。

#### Scenario: plugins[] と bundle から 3 名が消えている
- **WHEN** `.claude-plugin/marketplace.json` をパースする
- **THEN** `plugins[].name` にも `bundles[] | select(.name=="all") | .plugins[]` にも `loops`・`longrun`・`lr` が現れない

#### Scenario: plugins/ 配下と marketplace の登録が一致する
- **WHEN** `tests/marketplace-sync.bats` の「全ディレクトリが登録されている」検査（capability `marketplace-plugin-sync`）を実行する
- **THEN** pass する（`plugins/` 直下のディレクトリ名一覧と `plugins[].name` の一覧が完全一致し、片側だけにある名前が無い）

## REMOVED Requirements

### Requirement: 参照を直したプラグインの version を上げる
**Reason**: issue #447 で plugin.json と marketplace.json から `version` を撤去し、版は commit SHA から決まるようになった
**Migration**: 版は上げない。`plugins/dev-workflow/tests/retirement.bats` の版の検査は削除する
