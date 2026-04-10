## Why

SKILL.mdから実装詳細を除去しても（hide-script-internals-from-skill）、LLMがスクリプト実行をスキップして手動で処理する問題が再発した。原因は2つ: (1) modelフィールド未設定によりセッションモデルを継承し、弱いモデルが指示を無視する、(2) context未設定により会話コンテキストがスキル指示と競合し、LLMが「まず状態を調べよう」という汎用パターンに入る。

## What Changes

- SKILL.md frontmatterに `model: sonnet` を追加（モデル能力の保証）
- SKILL.md frontmatterに `context: fork` を追加（会話コンテキストからの隔離）
- コマンドファイル（commands/wt-setup.md）のdescriptionから実装詳細（`.claude/ symlink`）を除去
- `context: fork` 環境でのAskUserQuestion動作を検証し、必要なら.worktreeinclude生成フローを調整

## Capabilities

### New Capabilities

- `skill-execution-isolation`: スキルのfrontmatter設定によるモデル指定と実行コンテキスト隔離のポリシー

### Modified Capabilities

- `skill-script-separation`: context: fork環境でのスクリプト出力ベース分岐の動作要件を追加

## Impact

- `plugins/worktree/skills/wt-setup/SKILL.md` — frontmatter変更
- `plugins/worktree/commands/wt-setup.md` — description変更
- .worktreeinclude生成フロー — fork環境でのAskUserQuestion動作次第で調整が必要な可能性
