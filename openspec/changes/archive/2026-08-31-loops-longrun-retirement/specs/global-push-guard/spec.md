## MODIFIED Requirements

### Requirement: 層の優先関係と副作用の明文化

SKILL.md は次の 3 点を明記しなければならない (MUST): (1) リポジトリローカルの `core.hooksPath` はグローバル設定より優先されるため、loop-dev-agent 導入済み repo（flatmate の `new-resident` が `<repo>/.githooks/pre-push` を設置する）は従来どおりローカル層（main 拒否込み）が使われること、(2) グローバル `core.hooksPath` の設定は、自前で `core.hooksPath` を設定していないリポジトリの `.git/hooks/` 直置きフックを無効化すること、(3) その回避方法が当該リポジトリでの `git config core.hooksPath .git/hooks` であること。ローカル層の設置者として解散した `loops-dev-agent-install` を名指ししてはならない (MUST NOT)。

#### Scenario: 優先関係が説明されている

- **WHEN** SKILL.md を読む
- **THEN** ローカル設定がグローバルより優先されることと、その帰結（loop-dev-agent 導入済み repo は厳しい方が使われる）が説明され、`loops-dev-agent-install` の文字列は無い

#### Scenario: .git/hooks 無効化の副作用と回避方法が示されている

- **WHEN** SKILL.md の注意事項を読む
- **THEN** `.git/hooks/` 直置きフックが無効化されること、および `git config core.hooksPath .git/hooks` で回避できることが示されている

### Requirement: プラグインバージョンの更新

`plugins/dev-workflow/.claude-plugin/plugin.json` の `version` は本変更に伴い更新前より大きい値へ上げ、`.claude-plugin/marketplace.json` の対応するエントリと一致させなければならない (MUST)。（旧 loops プラグインは解散したため対象外）

#### Scenario: バージョンが上がり marketplace と一致する

- **WHEN** dev-workflow の plugin.json と marketplace.json の該当エントリを比較する
- **THEN** 変更前より大きい値であり、marketplace.json の値と一致している
