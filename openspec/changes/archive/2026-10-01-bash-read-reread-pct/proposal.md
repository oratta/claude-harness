## Why

`subagent-context-audit.sh --by-role` の `reread_pct` は Read ツールの `file_path` だけを数える。作業担当（W）はファイルをほぼ Bash（`sed -n` / `cat` / `head` / `tail`）で読むため、値が常に 0.0 になり、#555（読んだコードの要点の引き継ぎ）の効果を判断できない。手で Bash の読みまで数え直した中央値は 37.5% だった（https://github.com/oratta/claude-harness/issues/511#issuecomment-5924313663）。

## What Changes

- `reread_pct` の「読んだファイル」に、Bash の `sed -n` / `cat` / `head` / `tail` の引数のファイルを加える（前任・後任の両方）。照合は従来どおりベースネーム一致
- Read だけのトランスクリプトでは値を変えない
- `plugins/dev-workflow/docs/usage-audit.md` の `reread_pct` の説明を更新する

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-execution-strategy`: Requirement「`reread_pct`（作業担当 W の読み直し割合）」の「読んだファイル」の定義に Bash の読みを加える

## Impact

- `plugins/dev-workflow/scripts/subagent-context-audit.sh`（`scan_full` の reads 収集）
- `plugins/dev-workflow/tests/subagent-context-audit.bats`
- `plugins/dev-workflow/docs/usage-audit.md`
- `plugins/dev-workflow/changes/651.md`（変更記録）
