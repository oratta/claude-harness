---
name: exec
description: plan.mdに基づいて自律実行を開始する
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, Task
---

run-orchestrator エージェントを起動して、自律実行を開始してください。

## 実行前チェック

1. 実行対象のランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_runs/` 内の最新サブディレクトリ（`ls -1d _runs/20*/ | sort | tail -1`）を使用
   - `plan.md` が見つからない場合: `/run:plan` コマンドで先に作成するよう案内
2. ランディレクトリ内に既に `checkpoint.md` がある場合:
   - 続行するか新規開始するか確認

## 実行

ランディレクトリのパスを引数として run-orchestrator エージェントに渡す。
Setup → Build Contract → Build → Verify → Feedback → Archive の順で自律的に実装を進める。

## 実行中の進捗確認

`/run:status` コマンドで現在の状態を確認できます。
各changeの進捗は `openspec list` で確認できます。
