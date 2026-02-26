---
name: exec
description: instruction.mdに基づいてロングラン自律実行を開始する
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
---

longrun-orchestrator スキルを使用して、ロングラン自律実行を開始してください。

## 実行前チェック

1. `_longrun/instruction.md` が存在するか確認
   - 存在しない場合: `/instruction` コマンドで先に作成するよう案内
2. 引数が渡された場合はそのファイルをinstruction.mdとして使用
3. `_longrun/` ディレクトリの状態を確認
   - 前回の実行結果が残っている場合: 続行するか新規開始するか確認

## 実行

longrun-orchestrator スキルのプロトコルに従い、Phase 0 → Phase 1 → Phase 2（ループ）→ Phase 3 の順で自律的に実装を進めてください。

## 実行中の進捗確認

実行中は `_longrun/progress.md` が随時更新されます。
別ターミナルから以下のコマンドで進捗を確認できます:

```bash
cat _longrun/progress.md
```

または `/status` コマンドで現在の状態を確認できます。
