# global-push-guard Specification

## Purpose
全リポジトリに効くグローバル pre-push ガード（`~/.githooks/pre-push` + `git config --global core.hooksPath`）の内容と導入手順を定める。マージ済み PR のブランチへの push を、人間の手打ちでもエージェント経由でも同じ層で止めることが目的であり、`loops-dev-agent-install` が設置するリポジトリローカル層（main 直 push 拒否込み・ローカル設定が優先される）との役割分担もここで規定する。

## Requirements
### Requirement: グローバル pre-push ガードの導入スキル

`plugins/dev-workflow/skills/push-guard-setup/SKILL.md` は、`~/.githooks/pre-push` を生成し `git config --global core.hooksPath ~/.githooks` を設定する手順を定義しなければならない (MUST)。スキルは `plugins/dev-workflow/.claude-plugin/plugin.json` の `skills` に登録されなければならない (MUST)。

#### Scenario: 導入スキルが存在し登録されている

- **WHEN** `plugins/dev-workflow/.claude-plugin/plugin.json` の `skills` を読む
- **THEN** `./skills/push-guard-setup` が含まれ、`plugins/dev-workflow/skills/push-guard-setup/SKILL.md` が存在する

#### Scenario: 導入手順がグローバル設定を含む

- **WHEN** SKILL.md の導入手順を読む
- **THEN** `~/.githooks/pre-push` の生成・`chmod +x`・`git config --global core.hooksPath` の 3 つが手順として示されている

### Requirement: グローバル層はマージ済みチェックのみを持つ

グローバルフックのテンプレートは、マージ済み PR ブランチへの push 拒否のみを実装しなければならない (MUST)。main / master への直接 push 拒否を含めてはならない (MUST NOT)。「ローカル main 運用」のリポジトリでは承認後の main への push が正常系であり、全リポジトリで拒否すると正当な操作を壊すためである。この理由を SKILL.md に明記しなければならない (MUST)。

#### Scenario: グローバルテンプレートが main 直 push を拒否しない

- **WHEN** `refs/heads/main` を remote_ref とする push をグローバルフックに与える
- **THEN** フックは exit 0 で push を通す

#### Scenario: グローバル層に main 拒否を入れない理由が明記されている

- **WHEN** SKILL.md の設計方針を読む
- **THEN** ローカル main 運用のリポジトリを壊さないためである旨が説明されている

### Requirement: グローバル層のマージ済み判定はローカル層と同一条件

グローバルフックは、ローカル層と同じく「merged な PR が 1 件以上 ∧ open な PR が 0 件」のときのみ exit 1 で拒否しなければならない (MUST)。ブランチ削除 push（`local_sha` が全ゼロ）の許可、`PREPUSH_ALLOW_MERGED=1` によるバイパス、拒否メッセージでのバイパス案内も同様に備えなければならない (MUST)。`gh` の呼び出しは 1 回に統合し、3 秒のタイムアウトで fail-open しなければならない (MUST)。

#### Scenario: マージ済みブランチへの push が拒否される

- **WHEN** merged PR が 1 件あり open PR が 0 件のブランチへ push する
- **THEN** グローバルフックは exit 1 を返す

#### Scenario: 初回 push と PR 開き直しは通る

- **WHEN** PR が存在しないブランチ、または open PR が存在するブランチへ push する
- **THEN** グローバルフックは exit 0 を返す

#### Scenario: バイパスと削除 push が許可される

- **WHEN** `PREPUSH_ALLOW_MERGED=1` を設定して push する、またはブランチ削除 push を行う
- **THEN** グローバルフックは exit 0 を返す

#### Scenario: gh が応答しないときタイムアウトして通る

- **WHEN** `gh` がハングする状態で push する
- **THEN** グローバルフックは 3 秒程度で諦め exit 0 を返す

### Requirement: 層の優先関係と副作用の明文化

SKILL.md は次の 3 点を明記しなければならない (MUST): (1) リポジトリローカルの `core.hooksPath` はグローバル設定より優先されるため、`loops-dev-agent-install` 導入済み repo は従来どおりローカル層（main 拒否込み）が使われること、(2) グローバル `core.hooksPath` の設定は、自前で `core.hooksPath` を設定していないリポジトリの `.git/hooks/` 直置きフックを無効化すること、(3) その回避方法が当該リポジトリでの `git config core.hooksPath .git/hooks` であること。

#### Scenario: 優先関係が説明されている

- **WHEN** SKILL.md を読む
- **THEN** ローカル設定がグローバルより優先されることと、その帰結（導入済み repo は厳しい方が使われる）が説明されている

#### Scenario: .git/hooks 無効化の副作用と回避方法が示されている

- **WHEN** SKILL.md の注意事項を読む
- **THEN** `.git/hooks/` 直置きフックが無効化されること、および `git config core.hooksPath .git/hooks` で回避できることが示されている

### Requirement: 導入の冪等性と既存設定の保護

導入手順は 2 回以上実行しても壊れてはならない (MUST NOT)。`git config --global core.hooksPath` に既に別の値が設定されている場合、上書きする前に利用者へ確認しなければならない (MUST)。無断で他ツールのフック設定を置き換えてはならない (MUST NOT)。

#### Scenario: 既存のグローバル設定がある場合は確認する

- **WHEN** SKILL.md の導入手順を読む
- **THEN** `git config --global --get core.hooksPath` で既存値を確認し、別の値が入っている場合は上書き前に利用者へ確認する手順が示されている

#### Scenario: 再実行しても壊れない

- **WHEN** SKILL.md の導入手順を読む
- **THEN** フックファイルの上書きと設定の再設定のみで完結し、冪等である旨が示されている

### Requirement: プラグインバージョンの更新

`plugins/dev-workflow/.claude-plugin/plugin.json` と `plugins/loops/.claude-plugin/plugin.json` の `version` は本変更に伴い更新前より大きい値へ上げ、`.claude-plugin/marketplace.json` の対応するエントリと一致させなければならない (MUST)。

#### Scenario: 両プラグインのバージョンが上がり marketplace と一致する

- **WHEN** 2 つの plugin.json と marketplace.json の該当エントリを比較する
- **THEN** それぞれ変更前より大きい値であり、marketplace.json の値と一致している

