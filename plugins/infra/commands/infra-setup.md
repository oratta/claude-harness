---
name: infra-setup
description: Vercel + Supabase + GitHub Actions のインフラを対話的に一括セットアップする
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

`infra-setup` **スキル**を使って、現在のプロジェクトのインフラセットアップを開始してください。

**重要: `infra-setup` はエージェントではなくスキルである。** Agent ツールで起動してはならない。Skill ツールで呼び出すこと。これによりオーケストレータがメインセッションで実行され、各 Phase のサブエージェント（`infra-phase-1-hearing` 〜 `infra-phase-5-finalize`）を Agent ツールで生成できる。

## 実行前チェック

1. 現在のディレクトリがインフラを構築する対象プロジェクトのルートであることを確認する
2. `git status` を実行し、未コミットの大きな変更がある場合は「ステージしていない変更があります。`/infra-setup` を続けますか？」をユーザーに確認
3. `/tmp/infra-setup-state.md` が存在する場合は、スキルが再開判定を行う（ユーザーに続行/やり直しを尋ねる）

## 実行

`infra-setup` スキルを呼び出して Phase 0（前提条件チェック）→ Phase 1〜5 を順に進める。各 Phase 完了時に必ずユーザー確認を挟む。
