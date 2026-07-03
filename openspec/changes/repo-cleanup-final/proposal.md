# Proposal: repo-cleanup-final — リポジトリルート掃除と marketplace 最終同期

## Why

全面レビュー（付録 G）で、リポジトリルートに 3 種類の掃除対象が確定した。(1) OpenSpec スキルが 4 系統・計 40 ファイル重複しており（`.claude/skills/openspec-*` ×10 / `.claude/commands/opsx/` ×10 / `.agents/skills/openspec-*` ×10 / `.agents/skills/source-command-opsx-*` ×10）、スキル一覧に `openspec-apply-change` と `opsx:apply` が二重掲載されコンテキストを汚染している。(2) どのプラグインからも参照されない `templates/rules/*.md` 4 ファイルと、廃止済みの `docs/cooking-mvp-mode-plan.md` が残骸として残っている。(3) e2s の `commands/e2s-distill.md` が `$0` ベースの脆いパス解決を使い、skill-pack の SKILL.md に `skillOverrides` が plugin skill を制御しない旨の注記が無く cooking 命名の残骸がある。

加えて本 run（change-1〜6）で編集した全プラグインの `plugin.json` version bump と `.claude-plugin/marketplace.json` の version・description 同期は、複数 change が同一ファイル（marketplace.json）に触る競合を避けるため、全 change 完了後に本 change が最後に直列で担う責務として切り出されている（付録 F-6 の reviewer NOTE）。この change を最後に置くことで、marketplace 全体を「公式機能と重複せず、参照が全て生きている」完成状態に到達させる。

OpenSpec 重複だけは調査結果次第で「現状維持 + 文書化」への縮退を許容する（意思決定ガイドライン）。

## What Changes

- **OpenSpec 4 重複の生成元調査と解決**: 4 系統が openspec CLI（`openspec init --tools claude`）の生成物か手動管理かを調査し、CLI 管理なら設定で 1 系統に抑制、手動管理なら `.claude/` 側 1 系統を残して削除、判断がつかない場合は現状維持 + `decisions.md` 文書化に縮退する。いずれの分岐でも `decisions.md` に調査結論を残す
- **templates/rules 削除**: 参照ゼロの `templates/rules/*.md` 4 ファイルを削除
- **cooking 残骸掃除**: `docs/cooking-mvp-mode-plan.md` を削除、`.gitignore` の「1h-cooking session output」コメントを現行の harvest 命名に更新
- **skill-pack 小修正**: SKILL.md に「`skillOverrides` は plugin skill（`plugin:skill` 形式）を制御しない（`enabledPlugins` 側で扱う）」旨の注記を追加し、cooking 言及を掃除
- **e2s 修正**: `commands/e2s-distill.md` の `$0`/`realpath` ベースのパス解決を `${CLAUDE_PLUGIN_ROOT}` ベースに修正
- **marketplace 最終同期**: 本 run で編集した全プラグイン（infra / longrun / lr / worktree / daily-report / weekly-report / skill-pack / experience-to-skill）の plugin.json version bump を確認し、marketplace.json の version・description をそれぞれの plugin.json と完全一致させる
- **統合検証**: 受け入れ条件 5-16 の grep / ls 機械検証一式を実行し全 PASS を確認する
- **やらないこと**: `openspec/changes/archive/` と `_longruns/_archive/` は履歴のため一切触らない。change-6 が担う obsidian-llm-session-rules / skill-aware-workflow のエントリ除去には手を出さない（本 change は残る全プラグインの version/description 同期のみ）

破壊的変更なし（削除と整合同期のみ。削除は全て git tracked の状態で行い履歴から復元可能）。

## Capabilities

### New Capabilities
- `openspec-dedup-resolution`: OpenSpec 4 系統重複（計 40 ファイル）の生成元調査と、CLI 抑制 / 手動削除 / 現状維持縮退の三分岐、および調査結論の `decisions.md` 記録
- `repo-root-cleanup`: 参照ゼロ `templates/rules/` 削除、cooking 残骸（`docs/cooking-mvp-mode-plan.md` / `.gitignore` コメント / skill-pack 言及）掃除、skill-pack 注記追加、e2s の `$0` → `${CLAUDE_PLUGIN_ROOT}` 修正
- `marketplace-final-sync`: 全編集プラグインの plugin.json version bump 確認と marketplace.json の version・description 完全一致、受け入れ条件 5-16 の統合 grep 検証一式の実行

## Impact

- **`.claude/skills/openspec-*` / `.claude/commands/opsx/` / `.agents/skills/openspec-*` / `.agents/skills/source-command-opsx-*`**: 調査結論に応じて 1 系統へ抑制・削除、または現状維持
- **`templates/rules/claude-code-operations.md` ほか 3 ファイル**: 削除
- **`docs/cooking-mvp-mode-plan.md`**: 削除
- **`.gitignore`**: cooking コメントの harvest 命名への更新
- **`plugins/skill-pack/skills/skill-pack/SKILL.md`**: skillOverrides 注記追加 + cooking 言及掃除
- **`plugins/experience-to-skill/commands/e2s-distill.md`**: `$0` → `${CLAUDE_PLUGIN_ROOT}` 修正 + plugin.json version bump
- **`.claude-plugin/marketplace.json`**: 全編集プラグインの version・description 同期
- **`openspec/changes/repo-cleanup-final/decisions.md`**: OpenSpec 調査結論の記録（本 change の成果物）
- **触らないもの**: `openspec/changes/archive/`、`_longruns/_archive/`、change-6 が扱う廃止 2 プラグインのエントリ
