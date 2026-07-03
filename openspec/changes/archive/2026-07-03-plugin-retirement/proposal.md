# Proposal: plugin-retirement — 遺物2プラグインの完全削除

## Why

2026-07-03 実施の全面レビューで、`plugins/obsidian-llm-session-rules/` と `plugins/skill-aware-workflow/` の2プラグインが廃止根拠を満たすと確定した。

- **obsidian-llm-session-rules**: `hooks/hooks.json:3-14` の Stop hook（`auto-save.py`）が native transcript の劣化コピーを毎ターン全文再書込（`auto-save.py:119-122`）しており、保存先が `Path(cwd)/'LLM'` にハードコード（`auto-save.py:110`）されている。これはこのリポジトリの CLAUDE.md が定める LLM_LOG_DIR 規約（marketplace dir 外に保存）に違反する。`research-workflow` skill は `research-with-fallback` と機能重複し、かつ tool ID が壊れている（`SKILL.md:17-18` の `mcp__context7__*` は現行 `mcp__plugin_context7_context7__*` と不一致で動作しない）。`context-reader` / `session-logger` は native memory / `/export` の下位互換にすぎない。
- **skill-aware-workflow**: タスク前スキル探索はネイティブのスキル自動発見機構と冗長かつ衝突する。`hooks/hooks.json:3-13` の PostToolUse matcher `"*"` が全ツール呼び出しで bash+jq を起動しコストがかかる。Stop フックが前提とする「1タスク完了」単位が実際の発火単位（毎ターン、`finalize_log.sh:59`）と不整合。`/mnt/skills/` 前提（`skill-inventory/SKILL.md:22-24` 等）はローカル CLI 環境に存在しない。plugin.json に未登録の孤児 `skills/n8n-workflow-git/` が同梱されている。

両プラグイン配下の Skill 7個（`session-logger` / `context-reader` / `research-workflow` / `pre-task-orchestrator` / `task-analyzer` / `skill-inventory` / `skill-finder` / `execution-tracker` / `skill-proposer`）はいずれも `-er` / `-or` 終わりの命名規則違反として `openspec/backlog.md` の「Skill 命名規則リファクタリング」項目に記録済みだったが、リネームではなく削除で自然消化する。

リポジトリ直下 `LLM/` には `auto-save.py` の稼働実績として54ファイルが untracked のまま蓄積しており、プラグイン削除前に安全に退避する必要がある（削除ではなく退避。git tracked のプラグイン本体とは異なり untracked のため、通常の git 履歴では復元できない）。

## What Changes

- **BREAKING**: `plugins/obsidian-llm-session-rules/` と `plugins/skill-aware-workflow/` を git tracked 削除する。両プラグインが提供していたコマンド（`/save-session` `/update-context` `/reflect` `/find-skill` `/plan`）と Skill 9個は今後一切使用できなくなる
- リポジトリ直下 `LLM/` 配下の全ファイル（退避直前スナップショット基準）を `$LLM_LOG_DIR`（設定済み: Obsidian Vault の `90 - LLM`）へ mv で退避する。削除は行わない。件数照合を snapshot 基準で行い、同名衝突はスキップしてリスト化する
- `.claude-plugin/marketplace.json` の `plugins[]` と `bundles[].all.plugins[]` から両エントリを除去する（version/description の最終同期は change-7 の責務であり、本 change では触らない）
- 両プラグイン名・旧 Skill 名9個への参照を、`openspec/changes/archive/` と `_longruns/` を除く全ファイル（README.md / AGENTS.md / CLAUDE.md / CONTRIBUTING.md / `plugins/skill-pack/skills/skill-pack/SKILL.md` 等）から掃除する
- `openspec/backlog.md` の「Skill 命名規則リファクタリング」項目を消込む（対象7スキル全てが本 change の削除で消滅するため）
- `{longrun-dir}/post-merge-steps.md` にユーザー向け後始末手順（`/plugin uninstall` ×2、`/reload-plugins`、各プロジェクト `settings.local.json` の `enabledPlugins` 掃除）と LLM/ 退避結果（衝突リスト等）を書き出す

## Capabilities

### New Capabilities

- `llm-log-relocation`: リポジトリ直下 `LLM/` から `$LLM_LOG_DIR` への安全な退避（削除禁止・snapshot 基準の件数照合・同名衝突時のスキップとリスト報告・post-merge-steps.md への記録）を定義する
- `plugin-retirement-cleanup`: 両プラグインディレクトリの削除、`marketplace.json` エントリ除去（version/description 同期は対象外）、プラグイン名・旧Skill名9個の参照掃除を定義する
- `retirement-handoff-docs`: `openspec/backlog.md` の該当項目消込みと、`post-merge-steps.md` へのユーザー向け後始末手順・退避結果の書き出しを定義する

## Impact

- `plugins/obsidian-llm-session-rules/`（削除、10ファイル）
- `plugins/skill-aware-workflow/`（削除、21ファイル。plugin.json 未登録の孤児 `skills/n8n-workflow-git/` を含む）
- リポジトリ直下 `LLM/`（全ファイル退避、削除しない。衝突分のみ残置あり得る）
- `.claude-plugin/marketplace.json`（`plugins[]` 2エントリ除去、`bundles[].all.plugins[]` 2エントリ除去。version/description は不変）
- `README.md`（クイックスタート・プラグイン一覧・バンドル・ローカル開発の各セクションから両プラグイン言及を除去）
- `AGENTS.md` / `CLAUDE.md`（`session-logger` 例示の除去）
- `CONTRIBUTING.md`（NGパターン例示の入れ替え、「既存の不整合」節の除去）
- `plugins/skill-pack/skills/skill-pack/SKILL.md`（sample JSON 内 `obsidian-llm-session-rules@oratta-claude-harness` の入れ替え。同ファイル内の `cooking@1h-cooking` 言及は change-7 の担当のため触らない）
- `openspec/backlog.md`（「Skill 命名規則リファクタリング」節、33-79行目相当を消込み）
- `_longruns/2026-07-03_plugin-review-fixes/post-merge-steps.md`（新規書き出し）
- 依存: change-5（weekly-report が `{source_path}/LLM/*.md` 参照を断つことが前提）マージ後に着手
