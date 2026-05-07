---
name: exec
description: plan.mdに基づいて自律実行を開始する
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

longrun-orchestrator の手順をメインセッションでインライン実行して、自律実行を開始してください。

**重要: Skill tool / Agent tool は使わないこと。** longrun-orchestrator の SKILL.md には `disable-model-invocation: true` が指定されており、Skill tool 経由で呼ぶと `cannot be used with Skill tool due to disable-model-invocation` エラーで失敗する。これは設計上の意図で、orchestrator はメインセッションでインライン実行されないとサブエージェント（longrun-reviewer / longrun-builder / longrun-verifier）を Agent ツールで生成できないため（サブエージェントはサブエージェントを生成できないという Claude Code の仕様）。Agent tool で起動するのも同じ理由で禁止。

## 手順

### Step 1: SKILL.md を読み込む

orchestrator の本体は以下にある:
```
${CLAUDE_PLUGIN_ROOT}/skills/longrun-orchestrator/SKILL.md
```

`CLAUDE_PLUGIN_ROOT` が解決できない環境では bash で探索:
```bash
for dir in \
  ~/.claude/plugins/marketplaces/*/plugins/longrun/skills/longrun-orchestrator \
  ~/.claude/plugins/installed/*/longrun/skills/longrun-orchestrator; do
  [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
done
```

特定した絶対パスを Read tool で読み込む。

### Step 2: 実行前チェック

1. 実行対象のランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_longruns/` 内の最新サブディレクトリ（`ls -1d _longruns/20*/ | sort | tail -1`）を使用
   - `plan.md` が見つからない場合: `/longrun:plan` コマンドで先に作成するよう案内
2. ランディレクトリ内に既に `checkpoint.md` がある場合:
   - 続行するか新規開始するか確認

### Step 3: インライン実行

ランディレクトリのパスを引数として、SKILL.md の手順をメインセッションでインライン実行する。
Setup → Build Contract → Build → Verify → Feedback → Archive の順で自律的に実装を進める。

引数: `$ARGUMENTS`

## 実行中の進捗確認

`/longrun:status` コマンドで現在の状態を確認できます。
各changeの進捗は `openspec list` で確認できます。
