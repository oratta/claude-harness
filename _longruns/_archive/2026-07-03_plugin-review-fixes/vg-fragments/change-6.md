## change-6: plugin-retirement

### S1: [llm-log-relocation] Snapshot recorded before the first move
- WHEN: 退避直前、`LLM/*` のファイル数・ファイル名一覧をスナップショットとして記録する
- THEN: 最初の `mv` 実行前にスナップショットが永続化されており、後続の照合はこのスナップショット件数を基準にする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [llm-log-relocation] Every snapshotted filename is accounted for
- WHEN: 退避処理が完了する
- THEN: スナップショットに記録された各ファイル名は `$LLM_LOG_DIR` へ移動済みか、衝突スキップとしてリポジトリ直下 `LLM/` に残置されているかのいずれかであり、両方から消失しているファイルがあれば失敗として扱われる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [llm-log-relocation] Collision detected and skipped
- WHEN: スナップショット済みのファイル名が `$LLM_LOG_DIR` に既に存在する
- THEN: そのファイルの `mv` はスキップされ、移動先ファイルは変更されず、元ファイルはリポジトリ直下 `LLM/` に残置され、ファイル名が衝突リストに追加される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [llm-log-relocation] Snapshot-based arithmetic passes despite hook activity
- WHEN: 全 `mv` 完了後の照合時に、リポジトリ直下 `LLM/` にスナップショット外のファイル（`auto-save.py` hook による退避作業中の新規発生分）が存在する
- THEN: 照合算式（移動成功件数 + 衝突スキップ件数 = スナップショット件数）はスナップショット済みファイルのみで成立し、スナップショット外の新規ファイルはこの算式から除外され hook 起因として別記される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [llm-log-relocation] Reconciliation fails loudly on genuine loss
- WHEN: スナップショットに記録されたファイル名が `$LLM_LOG_DIR` にもリポジトリ直下 `LLM/` にも存在せず、衝突スキップとしても記録されていない
- THEN: 照合は失敗として報告され、解決されるまで退避完了とはみなされない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [llm-log-relocation] post-merge-steps.md documents the evacuation outcome
- WHEN: 退避と照合が完了する
- THEN: `{longrun-dir}/post-merge-steps.md` に衝突スキップされた全ファイル名（または「衝突ゼロ」の明記）と、hook 起因のスナップショット外新規ファイル（または「発生なし」の明記）が記録される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [llm-log-relocation] Zero-collision case leaves LLM/ empty or absent
- WHEN: 退避が衝突ゼロで完了する
- THEN: リポジトリ直下 `LLM/` は空または不存在になる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [llm-log-relocation] Collision case leaves only the collided files
- WHEN: 退避が1件以上の衝突を伴って完了する
- THEN: リポジトリ直下 `LLM/` には衝突スキップされたファイル名のみが残っており、移動成功したファイルも衝突リスト外のファイルも残っていない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [plugin-retirement-cleanup] Plugin directories are absent
- WHEN: `plugins/` を一覧する
- THEN: `plugins/obsidian-llm-session-rules/` と `plugins/skill-aware-workflow/` が存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [plugin-retirement-cleanup] Deletion is git-tracked
- WHEN: `git log --diff-filter=D -- plugins/obsidian-llm-session-rules plugins/skill-aware-workflow` を実行する
- THEN: 両ディレクトリの内容削除が tracked commit として履歴に現れる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [plugin-retirement-cleanup] plugins[] array excludes both entries
- WHEN: `.claude-plugin/marketplace.json` の `plugins[]` をパースする
- THEN: `name: "obsidian-llm-session-rules"` または `name: "skill-aware-workflow"` のエントリが存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [plugin-retirement-cleanup] "all" bundle no longer lists retired plugins
- WHEN: `.claude-plugin/marketplace.json` の `bundles[]` 内 `"all"` エントリをパースする
- THEN: その `plugins[]` リストに `"obsidian-llm-session-rules"` または `"skill-aware-workflow"` が含まれない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [plugin-retirement-cleanup] Only entry removal appears in the diff
- WHEN: `.claude-plugin/marketplace.json` の変更前後を diff する
- THEN: 差分は両プラグインの `plugins[]` エントリと `bundles[].all.plugins[]` 名の除去のみであり、top-level `version` と残存プラグインの `version`/`description` は変更前と同一である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [plugin-retirement-cleanup] Zero plugin-name references outside archive/_longruns
- WHEN: `grep -rln "obsidian-llm-session-rules\|skill-aware-workflow" plugins/ README.md docs/` をリポジトリルートから実行する
- THEN: 結果が0件である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [plugin-retirement-cleanup] Zero skill-name references outside archive/_longruns/this-change
- WHEN: 旧 Skill 名9個の grep（`session-logger|context-reader|research-workflow|pre-task-orchestrator|task-analyzer|skill-inventory|skill-finder|execution-tracker|skill-proposer`）を `openspec/changes/archive/`・`_longruns/`・`openspec/changes/plugin-retirement/` を除いてリポジトリ全体に実行する
- THEN: 結果が0件である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [plugin-retirement-cleanup] Illustrative examples use generic names
- WHEN: `CONTRIBUTING.md` の「NGパターン」例示を読む
- THEN: 例示名は旧 Skill 名9個のいずれも含まず、実在した/現存するスキルに紐付かない汎用架空名になっている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [plugin-retirement-cleanup] Quickstart install commands cleaned
- WHEN: `README.md` の `## クイックスタート` 節を読む
- THEN: `/plugin install skill-aware-workflow@oratta-claude-harness` も `/plugin install obsidian-llm-session-rules@oratta-claude-harness` も含まれない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [plugin-retirement-cleanup] Plugin catalog sections removed
- WHEN: `README.md` の `## プラグイン一覧` 節を読む
- THEN: `### skill-aware-workflow` も `### obsidian-llm-session-rules` サブセクションも存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [plugin-retirement-cleanup] Local development examples cleaned
- WHEN: `README.md` の `## ローカル開発` 節を読む
- THEN: `/plugin add ./plugins/skill-aware-workflow` も `/plugin add ./plugins/obsidian-llm-session-rules` も含まれない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [retirement-handoff-docs] Section is resolved, not left dangling
- WHEN: 本 change 適用後に `openspec/backlog.md` を読む
- THEN: `## Skill 命名規則リファクタリング` 節が完全に不存在であるか、旧 Skill 名9個を個別に列挙しない単一行の解消済みノートに縮小されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [retirement-handoff-docs] No orphaned rename-target table remains
- WHEN: 本 change 適用後に `openspec/backlog.md` を読む
- THEN: 旧 Skill 名9個をリネーム先候補にマッピングする対象表が存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [retirement-handoff-docs] Uninstall and reload commands present
- WHEN: `{longrun-dir}/post-merge-steps.md` を開く
- THEN: `/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness`、`/plugin uninstall skill-aware-workflow@oratta-claude-harness`、`/reload-plugins` の3コマンドが記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [retirement-handoff-docs] enabledPlugins cleanup guidance present
- WHEN: `{longrun-dir}/post-merge-steps.md` を開く
- THEN: 各プロジェクトの `settings.local.json` の `enabledPlugins` から `obsidian-llm-session-rules@oratta-claude-harness` と `skill-aware-workflow@oratta-claude-harness` の両キーを削除する手順が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [retirement-handoff-docs] Evacuation report and uninstall instructions share one file
- WHEN: `{longrun-dir}/post-merge-steps.md` を開く
- THEN: 同一ファイル内に `/plugin uninstall` 手順と LLM/ 退避の衝突レポート（または「衝突ゼロ」の明記）の両方が含まれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了
