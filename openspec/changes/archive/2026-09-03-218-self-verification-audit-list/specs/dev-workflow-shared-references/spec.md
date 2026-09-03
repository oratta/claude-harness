## MODIFIED Requirements

### Requirement: 自己検証の共通原則は解散プラグインの記述を除いて引き継ぐ
`plugins/dev-workflow/references/self-verification.md` は、旧 `plugins/loops/references/self-verification.md` の中核原則（完了は主張であり証明ではない。evidence を提示してから完了を宣言する）・evidence の 4 種別・スキル側への記載ルール（本リファレンスへの 1 行参照 + 固有手順のみ。共通原則の本文をコピーしない）を維持しなければならない（MUST）。「スキル側への記載ルール」の参照パスは新パス `plugins/dev-workflow/references/self-verification.md` を示す。対象スキル一覧は解散プラグインのスキル（`longrun-plan`・`longrun-feedback`・`longrun-mvp-plan`・`loops-design`・`loops-goalify`）の行を持ってはならず（MUST NOT）、対象は `wt-setup`・`wt-clean`・`daily-report`・`weekly-report`・`infra-setup`・`experience-to-skill`・`push-guard-setup` の 7 スキルとする（`push-guard-setup` は #218 の棚卸しで追加。成果物 `~/.githooks/pre-push` を出し、既に `## 自己検証` 節を持つため）。

#### Scenario: 中核原則と evidence 4 種が残っている
- **WHEN** `plugins/dev-workflow/references/self-verification.md` を読む
- **THEN** 「完了は主張であり証明ではない」の原則と、テスト出力・exit code・生成物の実在と形式チェック・実行結果ログの 4 種別が記載されている

#### Scenario: 対象スキル一覧に解散プラグインが無い
- **WHEN** 対象スキル一覧の表を読む
- **THEN** `plugins/longrun/`・`plugins/loops/` を含む実パスは 1 行も無く、7 スキルの実パスが並ぶ

#### Scenario: 参照元 8 か所が新パスを指す
- **WHEN** `plugins/infra/skills/infra-setup/SKILL.md`・`plugins/weekly-report/skills/weekly-report/SKILL.md`・`plugins/daily-report/skills/daily-report/SKILL.md`・`plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`・`plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/skills/wt-clean/SKILL.md`・`plugins/worktree/references/wt-clean-verification.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md` で `self-verification.md` を grep する
- **THEN** 8 ファイルすべてが `plugins/dev-workflow/references/self-verification.md` を指し、`plugins/loops/references/self-verification.md` は 0 件である
