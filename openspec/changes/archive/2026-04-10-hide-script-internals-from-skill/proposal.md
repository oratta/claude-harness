## Why

wt-setup SKILL.mdにスクリプト内部実装の詳細（symlink作成手法、`-sfn`フラグ、`.claude/`のgit追跡判定ロジック等）が記載されており、LLMがスクリプト実行をスキップして手動で処理を行う事故が繰り返し発生している（少なくとも4回確認済み）。スクリプト自体のロジックは正しいが、SKILL.mdから実装詳細が漏れることでLLMが「自分で実行できる」と判断しバイパスする。

## What Changes

- SKILL.md の description から `.claude/のsymlink作成` の文言を削除
- Step 1 の説明から `symlink作成` 等のスクリプト内部処理の記述を削除
- エラーハンドリングセクションからsymlink関連の記述を削除
- SKILL.md全体を「スクリプトを実行し、その出力に基づいてLLM判断が必要な処理のみ記述」という構造に再編

## Capabilities

### New Capabilities

- `skill-script-separation`: SKILL.mdとスクリプト間の責務分離ポリシー。機械的判定はスクリプトに閉じ込め、SKILL.mdにはLLM判断が必要な処理のみ記述する。

### Modified Capabilities


## Impact

- `plugins/worktree/skills/wt-setup/SKILL.md` — 記述の大幅削減
- スクリプト (`wt-setup.sh`) は変更なし
- 他のworktreeスキル（wt-clean等）への波及なし
