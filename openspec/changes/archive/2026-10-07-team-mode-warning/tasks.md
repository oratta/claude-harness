## 1. 実装

- [x] 1.1 `scripts/team-mode-warning.sh` を作る。無効値（未設定・空・0・false）は無出力、それ以外は systemMessage と additionalContext の JSON を出し、常に exit 0 触る範囲: plugins/dev-workflow/scripts/team-mode-warning.sh（新規）
- [x] 1.2 SessionStart に別エントリで登録する（引用符付きの `"\"${CLAUDE_PLUGIN_ROOT}/scripts/team-mode-warning.sh\""`） 触る範囲: plugins/dev-workflow/hooks/hooks.json:3-14

## 2. テスト

- [x] 2.1 `tests/team-mode-warning.bats`: 1 / true で警告、未設定・空・0・false で無出力、hooks.json への登録を検証する 触る範囲: tests/team-mode-warning.bats（新規）
- [x] 2.2 `./scripts/test.sh` が exit 0 になることを確かめる（予算ファイルは動かさない）

## 3. 記録

- [x] 3.1 変更の記録を書く 触る範囲: plugins/dev-workflow/changes/591.md（新規）
