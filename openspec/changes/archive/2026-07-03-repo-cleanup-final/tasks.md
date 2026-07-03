# Tasks: repo-cleanup-final

## 1. 調査（削除より先に実施）

- [x] 1.1 OpenSpec 4 系統の生成元を調査する（`.claude/skills/openspec-*` frontmatter の `author: openspec` / `generatedBy` / `compatibility` マーカー、`.agents/skills/source-command-opsx-*` の「migrated source command」表記、`which openspec` / `openspec --version` を確認）
- [x] 1.2 削除しても `openspec update` で再生成されるかを、CLI ドキュメント確認または慎重な実機観察で確定する
- [x] 1.3 調査結論（CLI 管理 / 手動管理 / 判断不能）と採用分岐（A: CLI 抑制 / B: `.claude/` 側残置削除 / C: 現状維持縮退）を `openspec/changes/repo-cleanup-final/decisions.md` に file 単位の根拠付きで記録する
- [x] 1.4 `templates/rules/` が参照ゼロであることを `grep -rn "templates/rules" plugins/ .claude-plugin/ README.md docs/`（archive・_longruns 除く）で再確認する

## 2. 削除（調査結論の確定後）

- [x] 2.1 OpenSpec 重複を分岐に応じて解決する（分岐 A: CLI 設定で抑制 / 分岐 B: `.agents/skills/openspec-*` と `.agents/skills/source-command-opsx-*` を `git rm` / 分岐 C: 現状維持し decisions.md に記録）。削除は git tracked の状態で可逆に行う
- [x] 2.2 `templates/rules/` 配下 4 ファイル（claude-code-operations.md / git-branch-and-pr.md / task-workflow.md / team-and-agent-usage.md）を `git rm` し、ディレクトリごと不存在にする
- [x] 2.3 `docs/cooking-mvp-mode-plan.md` を `git rm` する

## 3. 小修正

- [x] 3.1 `.gitignore` の「1h-cooking session output」コメントを現行の harvest 命名に更新する（`grep -n "1h-cooking" .gitignore` が 0 件になる）
- [x] 3.2 `plugins/skill-pack/skills/skill-pack/SKILL.md` に「`skillOverrides` は個人スキル対象で plugin skill（`plugin:skill` 形式）を制御しない。plugin のスキルは `enabledPlugins` で plugin 単位に扱う」旨を `on`/`off` 説明付近に明記する
- [x] 3.3 同 SKILL.md 内の cooking 言及（例示の `1h-cooking` / `cooking@1h-cooking` 等）を現行実態に合わせて掃除する
- [x] 3.4 `plugins/experience-to-skill/commands/e2s-distill.md` の `PLUGIN_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"` を `${CLAUDE_PLUGIN_ROOT}` ベースの解決に修正する（`realpath "$0"` を除去）

## 4. version bump

- [x] 4.1 `plugins/skill-pack/.claude-plugin/plugin.json` の version を bump する
- [x] 4.2 `plugins/experience-to-skill/.claude-plugin/plugin.json` の version を bump する
- [x] 4.3 infra / longrun / lr / worktree / daily-report / weekly-report の plugin.json version が本 run の編集を反映して bump 済みか横断確認し、未 bump があれば補完する

## 5. 最終同期（全プラグイン編集完了後に直列実行）

- [x] 5.1 `.claude-plugin/marketplace.json` の 8 プラグイン（infra / longrun / lr / worktree / daily-report / weekly-report / skill-pack / experience-to-skill）エントリの version を対応 plugin.json と完全一致させる
- [x] 5.2 同 8 プラグインの description を plugin.json 側を正として同期する
- [x] 5.3 obsidian-llm-session-rules / skill-aware-workflow のエントリには触れない（change-6 の責務）ことを確認する

## 6. 統合検証（受け入れ条件 5-16）

- [x] 6.1 change-7 固有条件を検証する（条件 14: `templates/rules/` 不存在・`docs/cooking-mvp-mode-plan.md` 不存在、条件 15: 全編集プラグインで plugin.json version == marketplace.json version）
- [x] 6.2 他 change 由来の条件 5-13 / 16 の grep・ls を横断実行し、逸脱があれば該当 change 担当へ差し戻す
- [x] 6.3 全 `*.json` が JSON として parse 可能であることを確認する（条件 3 の一部）
- [x] 6.4 実行した各検証コマンドと期待値を `decisions.md` または統合検証ログに残し、マージ後 main 上での再実行（条件 4）に備える
