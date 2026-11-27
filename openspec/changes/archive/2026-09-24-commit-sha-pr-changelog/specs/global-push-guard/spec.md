## REMOVED Requirements

### Requirement: プラグインバージョンの更新
**Reason**: issue #447 で plugin.json と marketplace.json から `version` を撤去し、版は commit SHA から決まるようになった
**Migration**: 版は上げない。`plugins/dev-workflow/tests/push-guard-setup.bats` の版の検査は削除する
