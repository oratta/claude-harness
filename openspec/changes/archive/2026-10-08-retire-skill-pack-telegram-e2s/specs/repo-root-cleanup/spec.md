## MODIFIED Requirements

### Requirement: cooking 残骸を掃除する

廃止済みの `docs/cooking-mvp-mode-plan.md` を削除し、`.gitignore` 内の「1h-cooking session output」コメントを現行の harvest 命名に更新しなければならない（MUST）。

#### Scenario: docs/cooking-mvp-mode-plan.md の削除

- **WHEN** 削除完了後に `docs/cooking-mvp-mode-plan.md` の存在を確認する
- **THEN** `docs/cooking-mvp-mode-plan.md` が存在しない（受け入れ条件 14 の後半）

#### Scenario: .gitignore の cooking コメント更新

- **WHEN** `.gitignore` を読む
- **THEN** 「1h-cooking session output」という旧命名のコメントが残っておらず、現行の harvest 命名に更新されている（`grep -n "1h-cooking" .gitignore` が 0 件）

## REMOVED Requirements

### Requirement: skill-pack に skillOverrides の適用範囲注記を追加する
**Reason**: 対象の `plugins/skill-pack/` を解散して削除した（PR #841）。注記を書く先が無い。
**Migration**: `skillOverrides` の扱いは Claude Code 本体の `/skills` 画面と公式ドキュメントに従う。

### Requirement: e2s の $0 ベースのパス解決を CLAUDE_PLUGIN_ROOT に修正する
**Reason**: 対象の `plugins/experience-to-skill/commands/e2s-distill.md` を、プラグインごと解散して削除した（PR #841）。
**Migration**: 蒸留による SKILL.md づくりは公式の skill-creator スキルを使う。
