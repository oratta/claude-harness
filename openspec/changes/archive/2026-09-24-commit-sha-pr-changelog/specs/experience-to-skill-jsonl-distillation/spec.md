## REMOVED Requirements

### Requirement: plugin.json and marketplace.json versions MUST be bumped consistently
**Reason**: issue #447 で plugin.json と marketplace.json から `version` を撤去し、版は commit SHA から決まるようになった
**Migration**: 版は上げない。両方に `version` が無いことは capability `marketplace-plugin-sync` が検査する
