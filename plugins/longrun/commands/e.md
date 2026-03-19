---
name: e
description: "[alias: exec] instruction.mdに基づいてロングラン自律実行を開始する"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
---

longrun-orchestrator スキルを使用して、ロングラン自律実行を開始してください。

**このコマンドは `/longrun:exec` のエイリアスです。** 全く同じ動作をします。

## 実行前チェック

1. 実行対象のランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_longrun/` 内の最新サブディレクトリ（`ls -1d _longrun/20*/ | sort | tail -1`）を使用
   - `instruction.md` が見つからない場合: `/longrun:instruction` コマンドで先に作成するよう案内
2. ランディレクトリ内に既に `progress.md` がある場合:
   - 続行するか新規開始するか確認

## 実行

ランディレクトリのパスを引数として longrun-orchestrator スキルに渡す。
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 の順で自律的に実装を進める。
