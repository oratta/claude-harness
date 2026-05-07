---
name: skill-pack
description: プロジェクトごとに skillOverrides / enabledPlugins を対話的に編集して必要なスキルだけ ON にする
argument-hint: "[init|list|on <name>|off <name>|suggest]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

skill-pack スキル本体に従って実行する。詳細手順は `skills/skill-pack/SKILL.md` を参照。

引数 (`$ARGUMENTS`) の最初のトークンで動作分岐:

- `init` または引数なし: 全スキル/プラグインを一覧して、ON にするものを対話で選択。残りを `"off"` / `false` で settings に書き込む
- `list`: 現在の skillOverrides / enabledPlugins 状態を表示
- `on <name>`: 指定スキル/プラグインを有効化
- `off <name>`: 指定スキル/プラグインを無効化
- `suggest`: package.json 等から推奨スキルを提示

引数の内容: $ARGUMENTS

## 重要事項

- 設定書き込み先のスコープ判定:
  - チーム共有 (commit) → `.claude/settings.json`
  - 個人専用 (gitignore) → `.claude/settings.local.json`
  - デフォルトは個人専用
- 公式仕様準拠: `skillOverrides` は user-level skill 用、`enabledPlugins` は plugin 用
- 既存の settings キー（permissions, hooks 等）は絶対に壊さない
- 編集後は Claude Code 再起動が必要な旨を案内

詳細フロー、設定ファイル例、エラーハンドリングは SKILL.md を参照すること。
