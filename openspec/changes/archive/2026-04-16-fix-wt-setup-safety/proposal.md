## Why

wt-setup スキル実行時に LLM がスクリプトをバイパスして `rm -rf .claude && ln -s ...` を独自実行し、worktree 内の `.claude/` を丸ごと削除しようとする事故が発生した。スクリプトはサブディレクトリ単位でシンボリンクする設計だが、LLM が「最適化」して危険なコマンドを生成している。また `.worktreeinclude` のパターン選択で毎回 AskUserQuestion が発生し、自明な判断でユーザーを煩わせている。

## What Changes

- SKILL.md に `.claude/` 操作の禁止ルールを追加（LLM がスクリプト外で `rm -rf .claude` 等を実行することを明示的に禁止）
- wt-setup.sh にガード処理を追加（`.claude/` が既存ディレクトリの場合に `rm -rf` を防ぐ防御コード）
- SKILL.md の Step 2 から AskUserQuestion を削除し、`.gitignore` ベースの自動判定ルールに置き換え

## Capabilities

### New Capabilities

- `wt-setup-guardrails`: LLM による危険なファイル操作の禁止ルールとスクリプト側の防御ガード

### Modified Capabilities

- `skill-script-separation`: SKILL.md に禁止事項セクションを追加し、スクリプトバイパスをより明確に禁止する要件を追加
- `skill-execution-isolation`: .worktreeinclude 生成時の AskUserQuestion 削除と自動判定ルール化の要件を追加

## Impact

- `plugins/worktree/skills/wt-setup/SKILL.md` — 禁止ルール追加、Step 2 の AskUserQuestion 削除
- `plugins/worktree/scripts/wt-setup.sh` — `.claude/` ガード処理追加
- 既存 worktree の動作に影響なし（防御的追加のみ）
