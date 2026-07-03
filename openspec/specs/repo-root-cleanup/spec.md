# repo-root-cleanup Specification

## Purpose
TBD - created by archiving change repo-cleanup-final. Update Purpose after archive.
## Requirements
### Requirement: 参照ゼロの templates/rules/ を削除する

`templates/rules/` 配下の 4 ファイル（`claude-code-operations.md` / `git-branch-and-pr.md` / `task-workflow.md` / `team-and-agent-usage.md`）はどのプラグインからも参照されていない（grep 確認済み）。これらを削除し、削除後に `templates/rules/` ディレクトリが存在しない状態にしなければならない（MUST）。削除前に参照ゼロを再確認しなければならない（MUST）。

#### Scenario: 参照ゼロの再確認

- **WHEN** builder が `templates/rules/` の削除に着手する
- **THEN** `grep -rn "templates/rules" plugins/ .claude-plugin/ README.md docs/`（archive・_longruns 除く）が 0 件であることを確認してから削除する

#### Scenario: templates/rules ディレクトリの不存在

- **WHEN** 削除完了後に `templates/rules/` の存在を確認する
- **THEN** `templates/rules/` ディレクトリおよびその配下 4 ファイルが存在しない（受け入れ条件 14 の前半）

### Requirement: cooking 残骸を掃除する

廃止済みの `docs/cooking-mvp-mode-plan.md` を削除し、`.gitignore` 内の「1h-cooking session output」コメントを現行の harvest 命名に更新し、`plugins/skill-pack/skills/skill-pack/SKILL.md` 内の cooking 言及を現行実態に合わせて掃除しなければならない（MUST）。

#### Scenario: docs/cooking-mvp-mode-plan.md の削除

- **WHEN** 削除完了後に `docs/cooking-mvp-mode-plan.md` の存在を確認する
- **THEN** `docs/cooking-mvp-mode-plan.md` が存在しない（受け入れ条件 14 の後半）

#### Scenario: .gitignore の cooking コメント更新

- **WHEN** `.gitignore` を読む
- **THEN** 「1h-cooking session output」という旧命名のコメントが残っておらず、現行の harvest 命名に更新されている（`grep -n "1h-cooking" .gitignore` が 0 件）

#### Scenario: skill-pack SKILL.md の cooking 言及掃除

- **WHEN** `plugins/skill-pack/skills/skill-pack/SKILL.md` を読む
- **THEN** cooking を例示・言及する箇所が現行実態に即した表現へ更新され、`1h-cooking` / `cooking@1h-cooking` のような旧命名の残骸が実例説明として残っていない

### Requirement: skill-pack に skillOverrides の適用範囲注記を追加する

`plugins/skill-pack/skills/skill-pack/SKILL.md` の `on` / `off` 操作説明付近に、「`skillOverrides` は plugin skill（`plugin:skill` 形式）を制御しない。plugin のスキル群は `enabledPlugins` 側で plugin 単位に扱う」旨を明記しなければならない（MUST）。既存の `enabledPlugins` 側で plugin を扱う設計が正しい旨も残す（MUST）。

#### Scenario: skillOverrides 適用範囲の明記

- **WHEN** `plugins/skill-pack/skills/skill-pack/SKILL.md` を読む
- **THEN** `skillOverrides` が個人スキル（`~/.claude/skills/`）を対象とし plugin skill を制御しないこと、plugin のスキルは `enabledPlugins` で plugin 単位に ON/OFF する旨が、`on`/`off` 説明付近に明記されている

### Requirement: e2s の $0 ベースのパス解決を CLAUDE_PLUGIN_ROOT に修正する

`plugins/experience-to-skill/commands/e2s-distill.md` の `PLUGIN_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"` は、command 実行時に `$0` が command ファイル自身を指す保証がなく脆い。これを `${CLAUDE_PLUGIN_ROOT}` ベースの解決に修正しなければならない（MUST）。

#### Scenario: realpath "$0" の除去と CLAUDE_PLUGIN_ROOT 化

- **WHEN** `plugins/experience-to-skill/commands/e2s-distill.md` を読む
- **THEN** `realpath "$0"` を用いた `PLUGIN_ROOT` 導出が存在せず、plugin ルートの解決が `${CLAUDE_PLUGIN_ROOT}` を基点に行われている（`grep -n 'realpath "\$0"' plugins/experience-to-skill/commands/e2s-distill.md` が 0 件）

