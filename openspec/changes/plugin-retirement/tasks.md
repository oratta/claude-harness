# Tasks: plugin-retirement

## 1. LLM/ 退避（llm-log-relocation）

- [ ] 1.1 退避直前のスナップショットを取得する: リポジトリ直下 `LLM/*` のファイル数とファイル名一覧を記録する（`decisions.md` または run ディレクトリ内のスナップショットファイルに残す）。この時点の件数を後続の照合基準とする
- [ ] 1.2 `$LLM_LOG_DIR` の値を確認する（設定済み: Obsidian Vault の `90 - LLM`）。未設定の場合はユーザーに確認し、デフォルトパスを勝手に決めない
- [ ] 1.3 スナップショット済みの各ファイルを `$LLM_LOG_DIR` へ `mv` する。移動先に同名ファイルが既に存在する場合はその1ファイルのみスキップし（上書き禁止）、衝突ファイル名をリストに追記する
- [ ] 1.4 mv 完了後、スナップショット件数 = 移動成功件数 + 衝突スキップ件数 であることを照合する。照合が一致するまで次のステップ（プラグイン削除）に進まない
- [ ] 1.5 mv 完了後にリポジトリ直下 `LLM/` へスナップショット外の新規ファイルが存在する場合（`auto-save.py` hook が退避作業中に稼働した場合）、それらをエラー扱いせず hook 起因の新規発生分として記録する（1.4 の照合対象からは除外）
- [ ] 1.6 退避完了後のリポジトリ直下 `LLM/` の状態を確認する: 衝突ゼロなら空または不存在、衝突ありならそのファイルのみが残っていること

## 2. プラグインディレクトリ削除（plugin-retirement-cleanup）

- [ ] 2.1 `git rm -r plugins/obsidian-llm-session-rules/` を実行する（10ファイル、git tracked 削除）
- [ ] 2.2 `git rm -r plugins/skill-aware-workflow/` を実行する（21ファイル、plugin.json 未登録の孤児 `skills/n8n-workflow-git/` を含む。git tracked 削除）

## 3. `marketplace.json` エントリ除去（plugin-retirement-cleanup）

- [ ] 3.1 `.claude-plugin/marketplace.json` の `plugins[]` から `name: "skill-aware-workflow"` と `name: "obsidian-llm-session-rules"` のエントリを削除する
- [ ] 3.2 `.claude-plugin/marketplace.json` の `bundles[]` 内 `"all"` バンドルの `plugins[]` リストから `"skill-aware-workflow"` と `"obsidian-llm-session-rules"` を削除する
- [ ] 3.3 top-level `version` と、残存する他プラグインの `version`/`description` フィールドには一切手を触れない（変更禁止。change-7 の責務）
- [ ] 3.4 `jq . .claude-plugin/marketplace.json` で JSON 構文が壊れていないことを確認する

## 4. プラグイン名・旧 Skill 名9個の参照掃除（plugin-retirement-cleanup）

- [ ] 4.1 `README.md`: クイックスタートの `/plugin install skill-aware-workflow@oratta-claude-harness` / `/plugin install obsidian-llm-session-rules@oratta-claude-harness`、`### skill-aware-workflow` セクション全体（末尾 `---` 込み）、`### obsidian-llm-session-rules` セクション全体（末尾 `---` 込み）、ローカル開発の `/plugin add ./plugins/skill-aware-workflow` / `/plugin add ./plugins/obsidian-llm-session-rules` を削除する。他セクション（longrun 等）は触らない
- [ ] 4.2 `AGENTS.md` と `CLAUDE.md` の「LLM ログ保存先」節にある `` `session-logger` / `daily-report` / `weekly-report` など `` から `` `session-logger` / `` 部分のみ除去し `` `daily-report` / `weekly-report` など `` に短縮する
- [ ] 4.3 `CONTRIBUTING.md`: NGパターンの「悪い」例示（`longrun-orchestrator`, `session-logger`, `skill-finder`）を実在しない汎用架空名（例: `data-fetcher`, `image-processor`）に入れ替える。「既存の不整合」段落（`pre-task-orchestrator` 等を挙げる箇所）を削除する
- [ ] 4.4 `plugins/skill-pack/skills/skill-pack/SKILL.md`: サンプル JSON 内の `"obsidian-llm-session-rules@oratta-claude-harness": false` を現存する他プラグインの disable 例（例: `"worktree@oratta-claude-harness": false`）に入れ替える。同一サンプル内の `"cooking@1h-cooking": false` 行は変更しない（change-7 の担当）
- [ ] 4.5 上記以外に `grep -rln "obsidian-llm-session-rules\|skill-aware-workflow" plugins/ README.md docs/` および `grep -rlnE "session-logger|context-reader|research-workflow|pre-task-orchestrator|task-analyzer|skill-inventory|skill-finder|execution-tracker|skill-proposer" .`（`openspec/changes/archive/`, `_longruns/`, `openspec/changes/plugin-retirement/` を除く）でヒットしたファイルがあれば個別に確認して掃除する

## 5. `openspec/backlog.md` 消込み（retirement-handoff-docs）

- [ ] 5.1 `openspec/backlog.md` の `## Skill 命名規則リファクタリング` 節（33-79行目相当。対象7スキルの表を含む）を、全削除するか単一行の解消済みノート（対象7スキルを個別に列挙しない総称表現）に置き換えるかを判断し、適用する
- [ ] 5.2 前後の `---` セパレータ構造が崩れていないことを確認する（隣接セクション間に単一の `---` が残ること）

## 6. `post-merge-steps.md` 書き出し（retirement-handoff-docs）

- [ ] 6.1 `_longruns/2026-07-03_plugin-review-fixes/post-merge-steps.md` を新規作成する
- [ ] 6.2 ユーザー向け後始末手順を記載する: `/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness`、`/plugin uninstall skill-aware-workflow@oratta-claude-harness`、`/reload-plugins`、各プロジェクト `settings.local.json` の `enabledPlugins` から両プラグインキーを削除する手順（skill-pack の `enabledPlugins` 編集パターンを参照）
- [ ] 6.3 タスク1（LLM/ 退避）の結果を同ファイルに記載する: 衝突ファイルリスト（またはその「衝突ゼロ」の明記）、hook 起因のスナップショット外新規ファイル（またはその「発生なし」の明記）

## 7. 検証

- [ ] 7.1 `ls plugins/obsidian-llm-session-rules plugins/skill-aware-workflow` が両方とも存在しないことを確認する
- [ ] 7.2 `jq . .claude-plugin/marketplace.json` が通り、`plugins[]` と `bundles[].all.plugins[]` に両エントリが存在しないことを確認する
- [ ] 7.3 `grep -rln "obsidian-llm-session-rules\|skill-aware-workflow" plugins/ README.md docs/` が0件であることを確認する（受け入れ条件12）
- [ ] 7.4 `grep -rlnE "session-logger|context-reader|research-workflow|pre-task-orchestrator|task-analyzer|skill-inventory|skill-finder|execution-tracker|skill-proposer" .`（`openspec/changes/archive/`, `_longruns/`, `openspec/changes/plugin-retirement/` を除く）が0件であることを確認する
- [ ] 7.5 リポジトリ直下 `LLM/` の最終状態が「衝突分のみ残置（またはゼロ）」であり、`post-merge-steps.md` に退避結果が記録されていることを確認する（受け入れ条件13）
- [ ] 7.6 `openspec validate plugin-retirement` を実行し PASS することを確認する
