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

廃止済みの `docs/cooking-mvp-mode-plan.md` を削除し、`.gitignore` 内の「1h-cooking session output」コメントを現行の harvest 命名に更新しなければならない（MUST）。

#### Scenario: docs/cooking-mvp-mode-plan.md の削除

- **WHEN** 削除完了後に `docs/cooking-mvp-mode-plan.md` の存在を確認する
- **THEN** `docs/cooking-mvp-mode-plan.md` が存在しない（受け入れ条件 14 の後半）

#### Scenario: .gitignore の cooking コメント更新

- **WHEN** `.gitignore` を読む
- **THEN** 「1h-cooking session output」という旧命名のコメントが残っておらず、現行の harvest 命名に更新されている（`grep -n "1h-cooking" .gitignore` が 0 件）

